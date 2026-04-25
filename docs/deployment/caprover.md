# Deploy on CapRover

> **What you'll need:** a working CapRover ≥ 1.13 instance, a wildcard subdomain pointed at the host (`*.example.com`), a basic-auth bcrypt hash you'll generate in Step 2.
> **Time to complete:** ~15 minutes (more setup than Coolify/Dokploy because CapRover deploys each service as its own app).

[CapRover](https://caprover.com) is a self-hosted, multi-app PaaS with an opinionated "one-click apps" pattern. Multi-service stacks like OTel-jps map to CapRover via the One-Click App YAML schema (8 separate CapRover apps that share an internal network).

---

## Step 1 — Prerequisites

You need:

- A CapRover instance running. Install per [caprover.com/docs/getting-started.html](https://caprover.com/docs/getting-started.html).
- A wildcard subdomain configured in CapRover (e.g. `*.caprover.example.com`) so each app gets its own auto-issued HTTPS subdomain.
- **At least 4 GB RAM and ~10 GB free disk** on the CapRover host.

---

## Step 2 — Generate the OTLP basic-auth hash

```bash
docker run --rm caddy:2-alpine caddy hash-password --plaintext 'YOUR_OTLP_PASSWORD'
```

Save the `$2a$14$...` output. Save the plaintext too.

---

## Step 3 — Install via the One-Click Apps mechanism

In CapRover:

1. Go to **Apps → One-Click Apps/Databases**.
2. Scroll to the bottom — there's a field for **"Insert any link/yaml here"** for custom apps.
3. Paste the entire contents of [`templates/caprover/caprover-one-click-app.yml`](https://github.com/HameemDakheel/OTel-jps/blob/main/templates/caprover/caprover-one-click-app.yml).
4. Click **Next**.
5. CapRover prompts for the variables defined in the YAML:
   - `cap_grafana_password` — let CapRover auto-generate (it uses `cap_gen_random_hex(16)` by default).
   - `cap_basic_auth_user` — `ingest` (or your choice).
   - `cap_basic_auth_hash` — paste your `$2a$14$...` from Step 2.
   - Retention values — accept defaults.
   - `cap_alert_webhook_url` — your Slack/Discord webhook (optional).
6. Choose a **base app name** (e.g. `obs`). CapRover prefixes all 8 apps with this name.
7. Click **Deploy**. ~3-5 minutes.

CapRover deploys 8 separate apps:

- `obs-grafana` (HTTPS exposed via CapRover)
- `obs-otelcol` (internal)
- `obs-prometheus` (internal)
- `obs-victorialogs` (internal)
- `obs-tempo` (internal)
- `obs-pyroscope` (internal)
- `obs-cadvisor` (internal)
- `obs-caddy` (HTTPS exposed via CapRover, for OTLP ingestion)

---

## Step 4 — Add config-file mounts to each app

The One-Click App YAML uses upstream images directly, but several services need their config files mounted in (Caddyfile, prometheus.yml, etc.). For each, use CapRover's **Persistent Directories** UI:

| App | Mount the file at | Source |
|-----|-------------------|--------|
| `obs-caddy` | `/etc/caddy/Caddyfile` | `configs/caddy/Caddyfile` |
| `obs-otelcol` | `/etc/otelcol-contrib/config.yaml` | `configs/otel-collector/config.yaml` |
| `obs-prometheus` | `/etc/prometheus/prometheus.yml` | `configs/prometheus/prometheus.yml` |
| `obs-prometheus` | `/etc/prometheus/rules/` | `alerts/` |
| `obs-tempo` | `/etc/tempo/tempo.yaml` | `configs/tempo/tempo.yaml` |
| `obs-pyroscope` | `/etc/pyroscope/pyroscope.yaml` | `configs/pyroscope/pyroscope.yaml` |
| `obs-grafana` | `/etc/grafana/provisioning/` | `configs/grafana/provisioning/` |
| `obs-grafana` | `/etc/grafana/dashboards/` | `configs/grafana/dashboards/` |

Easiest path: SSH into the CapRover host, clone the repo, and copy each file into CapRover's app data directory:

```bash
ssh <caprover-host>
sudo git clone --branch v1.0.0-alpha.4 https://github.com/HameemDakheel/OTel-jps.git /tmp/otel-jps
# For each app:
sudo cp /tmp/otel-jps/configs/caddy/Caddyfile /captain/data/<app-name-prefix>-caddy/
# ... etc
```

---

## Step 5 — Wire internal service-to-service URLs

CapRover apps reach each other over its internal network at hostnames like `srv-captain--<app-name>`. Update the OTel Collector config and Grafana datasources to use these:

In `obs-otelcol`'s mounted config (`/etc/otelcol-contrib/config.yaml`), endpoints become:
- `prometheusremotewrite.endpoint` → `http://srv-captain--obs-prometheus:9090/api/v1/write`
- `otlphttp/logs.endpoint` → `http://srv-captain--obs-victorialogs:9428/insert/opentelemetry`
- `otlphttp/tempo.endpoint` → `http://srv-captain--obs-tempo:4318`

In `obs-grafana`'s datasource provisioning (`/etc/grafana/provisioning/datasources/all.yaml`), URLs become:
- Prometheus → `http://srv-captain--obs-prometheus:9090`
- VictoriaLogs → `http://srv-captain--obs-victorialogs:9428`
- Tempo → `http://srv-captain--obs-tempo:3200`
- Pyroscope → `http://srv-captain--obs-pyroscope:4040`

In `obs-caddy`'s Caddyfile, reverse_proxy targets become:
- `reverse_proxy srv-captain--obs-grafana:3000`
- `reverse_proxy srv-captain--obs-otelcol:4318`

After editing the configs, restart each affected app from CapRover's dashboard.

---

## Step 6 — Verify

Open `https://obs-grafana.<your-caprover-domain>/`. Login with `admin` and the auto-generated password (visible in CapRover's `obs-grafana` app's env-vars).

Check the OTel-jps folder for 4 dashboards.

---

## Step 7 — Send telemetry from your apps

The OTLP entry point on CapRover is `obs-caddy`:

```
https://obs-caddy.<your-caprover-domain>/v1/traces
https://obs-caddy.<your-caprover-domain>/v1/metrics
https://obs-caddy.<your-caprover-domain>/v1/logs
```

For OTLP gRPC, you need to enable raw TCP forwarding at the CapRover level (port 4317) — see CapRover docs for "TCP traffic" rules.

Authentication: HTTP Basic with your `BASIC_AUTH_USER` and the plaintext password from Step 2.

---

## Day-2 ops

| Task | How |
|------|-----|
| Restart a single component | CapRover dashboard → app → **Restart** |
| Pull a new image | App → **Deployment** tab → re-deploy from same image tag (forces pull) |
| View logs | App → **App Logs** tab |
| Backups | CapRover's volume backup or your own host-level cron |

---

## Troubleshooting (CapRover-specific)

- **Apps failing to talk to each other** — check that you used `srv-captain--<name>` hostnames, not `localhost`. CapRover's internal DNS uses these prefixed names.
- **HTTPS not issued for `obs-grafana` or `obs-caddy`** — your wildcard DNS isn't set up. Verify `dig +short obs-grafana.example.com` returns the CapRover host IP.
- **OTLP gRPC port not reachable** — CapRover doesn't proxy raw gRPC by default. Add a TCP forwarding rule via NetData or expose via a custom Nginx config.
- **App restart after config change doesn't pick up new file** — CapRover caches mounted files. Restart the app via the dashboard, not `docker restart`.

---

## See also

- [Quickstart](../quickstart.md)
- [Architecture](../architecture.md)
- [CapRover One-Click Apps documentation](https://caprover.com/docs/one-click-apps.html)
- [CapRover template README](https://github.com/HameemDakheel/OTel-jps/blob/main/templates/caprover/README.md)
