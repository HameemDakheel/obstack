# Troubleshooting

> **Audience:** anyone running OTel-jps and hitting a problem. Lookup table first; deep-dive sections below.

---

## Quick lookup

| Symptom | Likely cause | Where to look |
|---------|-------------|---------------|
| `make verify` fails on a service | Container crashed or healthcheck failed | `docker logs otel-jps-<service>` |
| Browser warns about untrusted cert | `DOMAIN=localhost` (self-signed) | Expected for dev — accept and proceed |
| Browser cert error at real domain | Caddy can't reach Let's Encrypt | Check ports 80/443 firewall |
| Grafana login fails | `GRAFANA_ADMIN_PASSWORD` mismatch | Update `.env`, restart Grafana |
| OTLP requests get HTTP 401 | Basic auth header wrong | Re-encode `user:pass` as base64 |
| Spans appear empty / no service name | `OTEL_SERVICE_NAME` missing | Set in app env before SDK init |
| Spans not appearing in Grafana | OTel SDK batch not flushed | Add SDK `shutdown()` on app exit |
| Container restart-loops | Bad config file | See [service-down runbook](runbooks/service-down.md) |
| Disk fills up | Retention too long | See [disk-full runbook](runbooks/disk-full.md) |
| Prometheus OOMs | Cardinality explosion | See [high-cardinality runbook](runbooks/high-cardinality.md) |
| Cert about to expire | Auto-renewal failed | See [cert-renewal runbook](runbooks/cert-renewal.md) |
| Datasource shows red in Grafana | Backend unreachable from Grafana | `make verify` from host, then check Docker network |
| VictoriaLogs is empty | OTel Collector not exporting | `docker logs otel-jps-otelcol \| grep -i error` |

---

## OTLP traffic refused (401, 403)

**Symptom:** your app sends OTLP and gets a 401 from `https://<DOMAIN>/v1/traces`.

**Diagnose:**

```bash
# Verify Caddy basic auth config
docker exec otel-jps-caddy cat /etc/caddy/Caddyfile | grep -A 3 basic_auth

# Test auth manually with the credentials you're using
echo -n 'ingest:YOUR_PASSWORD' | base64
# Use that base64 string in the Authorization header
```

**Common fixes:**
- The `BASIC_AUTH_HASH` in `.env` was generated for a *different* password than the one your app sends. Re-generate: `docker run --rm caddy:2-alpine caddy hash-password --plaintext 'YOUR_PASSWORD'`.
- The header format is wrong. OTLP SDK env var: `OTEL_EXPORTER_OTLP_HEADERS="authorization=Basic <base64>"` — `key=value` (note `=`, not `:`), comma-separated for multiple.
- The username (`BASIC_AUTH_USER`) doesn't match what's in the header.

---

## Grafana datasource shows "Bad gateway" or "Connection refused"

**Symptom:** in Grafana, a datasource (Prometheus, VictoriaLogs, Tempo, Pyroscope) shows red/error.

**Diagnose:**

```bash
make verify
```

If verify passes, the backend is healthy *from inside the network* — Grafana should reach it. Try:

```bash
docker exec otel-jps-grafana wget -qO- http://prometheus:9090/-/ready
```

(replace `prometheus:9090` with the failing datasource's URL).

**Common fixes:**
- Datasource URL points to `localhost` instead of the container hostname (`prometheus`, `tempo`, etc.). Check `configs/grafana/provisioning/datasources/all.yaml`.
- The backend just restarted and Grafana cached the failure. Wait ~30 s or restart Grafana: `docker compose -f docker-compose.yml -f compose/simple.yml restart grafana`.

---

## VictoriaLogs is empty (no logs visible)

**Symptom:** Logs Explorer dashboard shows no logs even though apps are sending OTLP.

**Diagnose:**

```bash
# Is OTel Collector accepting logs?
docker exec otel-jps-caddy wget -qO- 'http://prometheus:9090/api/v1/query?query=otelcol_receiver_accepted_log_records_total' | grep value

# Is VictoriaLogs ingesting?
docker exec otel-jps-caddy wget -qO- 'http://prometheus:9090/api/v1/query?query=vl_rows_ingested_total' | grep value

# Is the VictoriaLogs export pipeline working?
docker logs otel-jps-otelcol 2>&1 | grep -i 'logs\|error' | tail -20
```

**Common fixes:**
- VictoriaLogs OTLP endpoint URL changed in a version bump. Should be `http://victorialogs:9428/insert/opentelemetry`. Check `configs/otel-collector/config.yaml`.
- VictoriaLogs version mismatch. Stack pins to a tested version; if you changed the image tag, try the original.
- App is sending in protobuf when collector expects JSON or vice versa. Check `OTEL_EXPORTER_OTLP_PROTOCOL` (default: `http/protobuf`).

---

## Prometheus OOMs (out of memory) repeatedly

**Symptom:** Prometheus container crashes with OOM, restart-loops.

**Diagnose:**

```bash
docker exec otel-jps-caddy wget -qO- 'http://prometheus:9090/api/v1/query?query=prometheus_tsdb_head_series' | grep value
```

If the value is >1M, you have cardinality explosion. See [high-cardinality runbook](runbooks/high-cardinality.md).

If <1M but still OOMs, the memory limit in `compose/simple.yml` (384 MB) may be too low for your workload. Bump to 768 MB temporarily and investigate.

---

## Container restart loop

See [service-down runbook](runbooks/service-down.md).

---

## "I just want to start over"

```bash
make clean   # interactive, asks for confirmation
make simple
```

`make clean` stops the stack and **removes all volumes** — every byte of telemetry data is gone. Use when the dev state has gotten too messy to debug.

---

## Reporting bugs

If a problem isn't covered here:

1. Capture state:

   ```bash
   docker compose -f docker-compose.yml -f compose/simple.yml ps > /tmp/ps.txt
   for c in caddy otel-collector prometheus victorialogs tempo pyroscope grafana cadvisor; do
     docker logs otel-jps-$c --tail 100 > /tmp/${c}.log 2>&1
   done
   make verify > /tmp/verify.txt 2>&1
   ```

2. Check existing GitHub issues: <https://github.com/HameemDakheel/OTel-jps/issues>

3. If new, file an issue with:
   - Output of `make verify`
   - Relevant `docker logs`
   - The version (git commit hash or tag)
   - What you were doing when it broke

---

## See also

- [Runbooks](runbooks/) — step-by-step incident playbooks
- [Reference docs](../reference/) — env vars, ports, volumes
- [Architecture](../architecture.md) — what each component does
