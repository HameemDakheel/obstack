# obstack OTel Demo (Astronomy Shop)

Runs the [official OpenTelemetry demo](https://github.com/open-telemetry/opentelemetry-demo) (a 17-service "Astronomy Shop" microservices app) and routes its telemetry into your obstack instance — exercising obstack's **public OTLP path** (HTTPS + HTTP Basic auth), exactly the way real customer applications would.

## Why this exists

obstack ships with no pre-instrumented application of its own. Right after `make simple` the dashboards are mostly empty, you can't explore traces, and you can't tell whether the public ingest path actually works end-to-end. This demo:

- **Validates the production OTLP path** — TLS (Caddy), basic auth, otelcol routing, all of it.
- **Populates every dashboard** with realistic microservice telemetry within ~2 minutes.
- **Doubles as a smoke test.** If `make verify` passes but the demo's traces don't show up in Grafana, something is broken in the public-facing path.

## Architecture

```
┌──────────────────────────────────────────┐    HTTPS + Basic auth    ┌──────────────────────┐
│ obstack-demo (this directory)            │ ──────────────────────→  │  obstack             │
│                                          │  https://caddy/v1/...    │  (your stack)        │
│  17 demo services (frontend, cart, ...)  │                          │                      │
│      │ OTLP gRPC                         │                          │   Caddy              │
│      ▼                                   │                          │     │ basic-auth +   │
│  bundled otel-collector                  │                          │     ▼ /v1/* route    │
│      │                                   │                          │   otel-collector     │
│      │ OTLP HTTP (forwarding extras)     │                          │     │                │
│      └──────────────────────────────────→│                          │     ├→ Tempo (traces)│
│                                                                     │     ├→ Prometheus    │
│  bundled jaeger / grafana / prometheus / opensearch are DISABLED    │     ├→ VictoriaLogs  │
│  (obstack handles all four backends).                               │     └→ Pyroscope     │
└──────────────────────────────────────────┘                          └──────────────────────┘
```

The two compose projects share **only obstack's docker network** (`otel-jps_obs-net`) so the demo's bundled otel-collector can resolve `caddy` to obstack's edge proxy — no exposure of internal collector ports, no ad-hoc port forwarding.

## Files in this directory

| File | Purpose |
|------|---------|
| `docker-compose.override.yml` | Layered on top of upstream's compose. Disables jaeger/grafana/prometheus/opensearch (obstack does those), reroutes the bundled otel-collector to obstack via OTLP/HTTP+Basic-auth, joins the obstack network, and applies a few env-var fixes (memory limits, missing knobs). |
| `otelcol-config.obstack.yml` | Replaces the upstream collector config. Receivers + processors stay the same; exporters are simplified to a single `otlphttp/obstack` sender targeting Caddy. |
| `otelcol-config-extras.obstack.yml` | No-op — kept because the upstream entrypoint expects this path. |
| `.env` | Demo runtime credentials (gitignored). Created from `.env.example` on first run. |
| `.env.example` | Template — copy to `.env` and fill in. |
| `upstream/` | Shallow git clone of `open-telemetry/opentelemetry-demo` at v2.2.0. Cloned automatically by `scripts/demo-up.sh`. **gitignored.** |

## Prerequisites

- obstack running locally (`make simple` or `make standard`).
- The plaintext basic-auth password (the one whose bcrypt hash is in obstack's `.env` as `BASIC_AUTH_HASH`). If you don't know it, rotate: pick a new password, run `docker run --rm caddy:2-alpine caddy hash-password --plaintext '<new>'`, paste the result into obstack's `.env` as `BASIC_AUTH_HASH=…`, restart Caddy with `docker compose -f docker-compose.yml -f compose/simple.yml up -d caddy`.
- A machine with **at least 6 GB RAM free** for the demo on top of obstack. Combined: budget ≥12 GB.

## Run it

From the **repo root**:

```bash
make demo-up
```

That helper:

1. Clones upstream demo v2.2.0 into `examples/otel-demo/upstream/` if missing.
2. Reads `examples/otel-demo/.env`, base64-encodes the basic-auth credentials.
3. Runs `docker compose --env-file upstream/.env --env-file .env -f upstream/docker-compose.yml -f docker-compose.override.yml -p obstack-demo up -d`.

First-time bring-up takes ~5 min (image pulls). Subsequent runs are ~30s.

Manual equivalent (if `make` isn't available):

```bash
cd examples/otel-demo
git clone --depth 1 --branch 2.2.0 https://github.com/open-telemetry/opentelemetry-demo upstream
cp .env.example .env  # then edit credentials
../../scripts/demo-up.sh
```

## Driving traffic and failures

The demo ships with a feature-flag UI (<http://localhost:8080/feature/>) and a Locust web UI (<http://localhost:8080/loadgen/>) that let you inject specific failure scenarios — cart errors, slow images, memory leaks, kafka backpressure, traffic floods, and more.

See **[Demo recipes](../../docs/operations/demo-recipes.md)** for 8 hands-on scenarios covering all 15 demo feature flags plus how to drive Locust at custom user counts.

## What you should see

Within ~90 seconds:

| Where | What |
|-------|------|
| Astronomy Shop UI | <http://localhost:8080/> — click around, add things to cart, check out. |
| obstack Grafana | <https://localhost/> (admin / from `.env`) → **Dashboards → obstack → Astronomy Shop (demo)**. Service request rates, error rates, p95/p99 latencies, top slow spans, top error spans, demo logs panel — all populated. |
| Traces Browser | Search service.namespace = `opentelemetry-demo`. You should see ~17 service nodes in the service map and end-to-end traces from `frontend-proxy → frontend → cart → checkout → payment`. |
| Logs Explorer | Filter `service.namespace:="opentelemetry-demo"` to see structured logs from every demo service. |

## Stop / restart / inspect

```bash
make demo-down                # stop demo, keep volumes
make demo-logs                # tail logs from all 17 demo containers
docker compose --env-file examples/otel-demo/upstream/.env --env-file examples/otel-demo/.env \
  -f examples/otel-demo/upstream/docker-compose.yml \
  -f examples/otel-demo/docker-compose.override.yml -p obstack-demo ps
```

## Troubleshooting

**Auth errors (401) in `obstack-demo-otelcol` logs**: the basic-auth password in `examples/otel-demo/.env` doesn't match obstack's `BASIC_AUTH_HASH`. Either rotate (see Prerequisites) or re-set `DEMO_BASIC_AUTH_PASSWORD` in `examples/otel-demo/.env` and run `make demo-up` again to recreate the collector with fresh credentials.

**TLS errors**: `DEMO_OBSTACK_INSECURE=true` is required when obstack uses Caddy's self-signed local cert (default for `DOMAIN=localhost`). For production deployments with a real cert, set it to `false`.

**Demo UI returns 500/503**: a microservice crashed. `docker logs <name>` to see why. Common causes:
- Out of memory: increase Docker's memory allocation.
- Port collision: something else is on `:8080`. Change `DEMO_FRONTEND_PORT` in `.env`.

**Some traces missing from Tempo**: traces and spanmetrics arrive within seconds, but the demo's load-generator runs synthetic browser flows that include intentionally failing operations (the `*Failure` feature flags). That's by design — the dashboard's "error rate" panel will be non-zero and you can drill into those failures.

**Demo is consuming all my RAM**: stop heavy demo services manually:
```bash
docker stop accounting fraud-detection kafka opensearch  # frees ~2 GB; demo still works
```
(opensearch is already disabled in our override; the rest are part of the full demo.)

## Caveats

- Demo images pinned to **v2.2.0**. Bumping requires re-testing — the demo's env-var contract has changed across major releases (1.x used JSON file products, 2.x added postgres, etc.). The override file may need updates.
- The **bundled otel-collector** in the demo continues to run; we just rewrote its config to forward to obstack instead of jaeger/prometheus/opensearch. Its postgres-receiver, redis-receiver, and docker-stats-receiver are still active and emit their own metrics into obstack — convenient bonus.
- Obstack's `Caddyfile` includes a second site block matching the internal Docker hostnames `caddy` / `obstack-caddy` with `tls internal`. This is what lets the demo's collector (on `obs-net`) reach Caddy without Host-header tricks. It's never exposed publicly.

## License

The OTel demo images and source are Apache 2.0 (upstream). This directory's wiring is MIT, matching obstack.
