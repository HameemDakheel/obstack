# Demo tutorial — testing obstack with Astronomy Shop

> **Audience:** anyone evaluating obstack who wants to confirm it works end-to-end with realistic microservice telemetry. Read after [Quickstart](../quickstart.md).

This tutorial walks you through running the official OpenTelemetry [Astronomy Shop demo](https://github.com/open-telemetry/opentelemetry-demo) (17 microservices) against your obstack instance and verifying that **traces, metrics, and logs all flow through obstack's public OTLP endpoint** — exactly the path a real production application takes.

End state: a populated Grafana with a service graph, latency dashboards, error rates, and structured logs from a real distributed system you can click around in.

---

## What you'll learn

By the end of this tutorial you'll be able to answer:

1. Is obstack ingesting OTLP correctly over HTTPS+Basic auth?
2. Are traces, metrics, and logs all reaching the right backends (Tempo, Prometheus, VictoriaLogs)?
3. Do dashboards populate with realistic, multi-service data?
4. Can I drill from a span in a dashboard to its full trace, then to the underlying logs?

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| obstack running | `make simple` in repo root. Verify with `make verify` (expect "7 passed, 0 failed"). |
| 12+ GB free RAM | Demo alone needs ~6 GB; obstack adds ~1 GB; OS overhead ~500 MB. |
| 60+ GB free disk | Demo uses ~10 GB of images. Obstack volumes grow with retention. |
| `make`, `git`, `docker compose` | All standard. |
| The plaintext basic-auth password | The string whose bcrypt hash is stored in obstack's `.env` as `BASIC_AUTH_HASH`. If you don't know it, see "Reset basic auth" below. |

---

## Step 1 — Configure demo credentials

```bash
cd examples/otel-demo
cp .env.example .env
```

Open `.env` and set:

```dotenv
DEMO_OBSTACK_ENDPOINT=https://caddy
DEMO_OBSTACK_INSECURE=true                # leave true for self-signed local cert
DEMO_BASIC_AUTH_USER=ingest                # default obstack BASIC_AUTH_USER
DEMO_BASIC_AUTH_PASSWORD=<plaintext>       # the password matching obstack's BASIC_AUTH_HASH
DEMO_FRONTEND_PORT=8080
```

`DEMO_OBSTACK_BASIC_AUTH=` stays blank — `scripts/demo-up.sh` computes it at startup.

### Reset basic auth (only if you don't know the password)

```bash
# Pick a fresh password
NEW_PASS="$(openssl rand -base64 18 | tr -d '/+=' | head -c20)"
echo "new password: $NEW_PASS"

# Hash it
NEW_HASH="$(docker run --rm caddy:2-alpine caddy hash-password --plaintext "$NEW_PASS")"

# Replace BASIC_AUTH_HASH in obstack's .env
sed -i "s|^BASIC_AUTH_HASH=.*|BASIC_AUTH_HASH=$NEW_HASH|" .env

# Restart Caddy so it picks up the new hash
docker compose -f docker-compose.yml -f compose/simple.yml up -d caddy

# Put plaintext into demo .env
sed -i "s|^DEMO_BASIC_AUTH_PASSWORD=.*|DEMO_BASIC_AUTH_PASSWORD=$NEW_PASS|" examples/otel-demo/.env
```

---

## Step 2 — Start the demo

From the repo root:

```bash
make demo-up
```

First-run timeline (~5 min):

| Time | What's happening |
|------|------------------|
| 0:00 | `scripts/demo-up.sh` clones upstream demo v2.2.0 into `examples/otel-demo/upstream/` |
| 0:30 | `docker compose pull` starts (16+ images) |
| 4:00 | All images cached; containers create |
| 4:30 | Kafka becomes healthy; downstream services start |
| 5:00 | `frontend-proxy` starts; load-generator begins issuing browser-emulated traffic |

If the pull stalls on flaky DNS, just re-run `make demo-up` — partial pulls resume.

Verify everything is up:

```bash
docker ps --filter 'label=com.docker.compose.project=obstack-demo' --format '{{.Names}}: {{.Status}}'
```

You should see ~24 containers all `Up` (some say `(healthy)` after warm-up).

---

## Step 3 — Verify telemetry is flowing

### A. Use the Astronomy Shop UI

Open <http://localhost:8080/> in a browser. Click around, add a telescope to your cart, "Place Order". Each click is one or more spans landing in obstack within seconds.

### B. Quick probes

```bash
# 1. Auth header
B64="Basic $(printf '%s:%s' ingest "$DEMO_BASIC_AUTH_PASSWORD" | base64 -w0)"

# 2. Demo trace count in Tempo
docker exec obstack-caddy sh -c "wget -qO- --header='Authorization: $B64' \
  'http://tempo:3200/api/search?tags=service.namespace%3Dopentelemetry-demo&limit=50'" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('traces:', len(d.get('traces',[])))"

# 3. Demo metric series count in Prometheus
docker exec obstack-caddy sh -c "wget -qO- 'http://prometheus:9090/api/v1/query?\
query=count(%7Bservice_namespace%3D%22opentelemetry-demo%22%7D)'" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); r=d['data']['result']; print('series:', r[0]['value'][1] if r else 0)"
```

Expected within 90s: ≥10 traces, ≥500 metric series.

If both are 0, jump to "Troubleshooting" below.

### C. Open the Astronomy Shop dashboard

1. Go to <https://localhost/> (accept the self-signed cert prompt).
2. Log into Grafana (admin / password from obstack's `.env`).
3. Navigate to **Dashboards → obstack → Astronomy Shop (demo)**.

You should see populated panels:
- 17+ "Services emitting telemetry"
- Live request rate, error rate, p95/p99 latency by service
- Top slowest spans table (sortable)
- Top erroring spans table
- Demo logs panel at the bottom

The default time window is `now-15m`. If you just started the demo, change it to `now-5m`.

---

## Step 4 — Drill from dashboard to a single trace

This is the killer feature obstack gives you out of the box. Try it:

1. In **Astronomy Shop (demo)** dashboard, find the **Top 15 slowest spans** table.
2. Click any row's **Service** value (e.g. `frontend`).
3. Grafana opens a new panel filtered to that service's traces.
4. Click any trace ID → opens **Tempo** trace view → see the full waterfall (frontend → cart → checkout → payment → …).
5. In the trace view, click any span → side panel shows attributes (HTTP method, status, route, etc.).
6. Right-click the span → **"Logs for this span"** → opens **VictoriaLogs** filtered by that span's `trace.id`. You see the application logs that ran during that exact span.

That trace → log correlation working out of the box is the entire point of LGTM-stack observability. You just verified it works.

---

## Step 5 — Test failure injection

> **Tip:** for a complete catalogue of the 15 demo feature flags and 8 ready-made scenarios (load spikes, slow traces, memory leaks, kafka backpressure, etc.), see **[Demo recipes](demo-recipes.md)**.


The OTel demo has built-in feature flags that cause specific services to fail or slow down. The demo's load-generator hits them periodically — but you can flip them yourself:

1. Browse to <http://localhost:8080/feature/> (the flag UI).
2. Toggle `productCatalogFailure` to `on`.
3. Within ~30 seconds, the **Astronomy Shop** dashboard's "Error rate by service" panel will show `product-catalog` errors climbing.
4. Drill into a failed span: the trace view will show the exact gRPC error, and the linked logs will show the panic stack trace.
5. Toggle the flag back to `off`. Errors stop.

Other flags worth trying:
- `cartFailure` — empties the cart on checkout (frontend handles gracefully but trace shows the failure path).
- `paymentFailure` — payment service returns errors.
- `recommendationCacheFailure` — recommendation service grows unbounded memory. Watch it on the **Container Metrics** dashboard.
- `loadgeneratorFloodHomepage` — synthetic traffic spike. Watch frontend's request rate.

---

## Step 6 — Run an alert pack against the demo

While the demo is running, activate an alert pack and trigger something:

```bash
# In repo root
cp alerts/optional/host.yaml alerts/
docker compose -f docker-compose.yml -f compose/simple.yml restart prometheus
```

Open Grafana → **Alerts → Alert rules**. The new "obstack-host" group is loaded.

Now stress the host:

```bash
# generate CPU load
docker run --rm --name stress alpine:3 sh -c "while true; do :; done" &
sleep 30  # wait for the rule to evaluate
docker kill stress
```

Within 10 minutes the `HostHighCPULoad` alert fires (visible in Grafana → Alerts). Configure a notification policy to actually receive these somewhere.

When done:

```bash
rm alerts/host.yaml
docker compose -f docker-compose.yml -f compose/simple.yml restart prometheus
```

---

## Step 7 — Stop and clean up

```bash
make demo-down
```

This stops all 17 demo containers but keeps the obstack stack running and your telemetry data preserved. Restart later with `make demo-up`.

To completely remove demo state:

```bash
docker compose --env-file examples/otel-demo/upstream/.env --env-file examples/otel-demo/.env \
  -f examples/otel-demo/upstream/docker-compose.yml \
  -f examples/otel-demo/docker-compose.override.yml \
  -p obstack-demo down -v
rm -rf examples/otel-demo/upstream
```

---

## Troubleshooting

**Demo containers up but Tempo shows 0 traces:**
- Check the demo otelcol's logs:
  ```bash
  docker logs --tail 30 obstack-demo-otelcol | grep -iE "error|denied|401"
  ```
- HTTP 401 → password mismatch. Re-run Step 1's "Reset basic auth" and `make demo-up` again.
- "remote error: tls: internal error" → Caddy doesn't have a cert for the SNI. Should be auto-fixed since obstack v1.1; if you're on older obstack pull latest.
- "no such host" / connection refused → demo otelcol isn't on `obs-net`. Verify with: `docker inspect obstack-demo-otelcol --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool`.

**Dashboard panels show "No data":**
- Wait 60s — spanmetrics aggregation needs warmup.
- Check the dashboard's time window — default is `now-15m`. If demo started <15m ago, narrow to `now-5m`.
- Verify `traces_span_metrics_calls_total` exists: `docker exec obstack-caddy sh -c "wget -qO- 'http://prometheus:9090/api/v1/query?query=count(traces_span_metrics_calls_total)'"`.

**Demo apps in restart loops:**
```bash
docker compose --env-file examples/otel-demo/upstream/.env --env-file examples/otel-demo/.env \
  -f examples/otel-demo/upstream/docker-compose.yml \
  -f examples/otel-demo/docker-compose.override.yml \
  -p obstack-demo ps
```
Find the unhealthy one, then `docker logs <name>` for the cause. Most commonly: out-of-memory (raise Docker Desktop's memory or stop heavy services like `kafka`).

**Frontend (`http://localhost:8080`) returns 502/503:**
- One of `frontend`, `frontend-proxy`, `cart`, `checkout`, `currency`, `productcatalog` failed. See above.
- `feature_flag.recommendationCacheFailure` is on — toggle it off at <http://localhost:8080/feature/>.

---

## What's next

- Read [Profiles](../profiles.md) to plan a Standard or Scale deployment.
- Read [Default alerts](../reference/default-alerts.md) and `alerts/optional/README.md` for production alerting.
- Read [Backup & Restore](backup-restore.md) before you put real data into obstack.

---

## See also

- [`examples/otel-demo/README.md`](https://github.com/HameemDakheel/obstack/blob/main/examples/otel-demo/README.md) — architectural details, file layout.
- [Upstream OpenTelemetry demo](https://github.com/open-telemetry/opentelemetry-demo) — what each of the 17 services does.
- [Architecture](../architecture.md) — what's inside obstack itself.
