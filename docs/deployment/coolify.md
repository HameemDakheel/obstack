# Deploy on Coolify

> **What you'll need:** a working Coolify ≥ 4.0 instance with a server attached, a domain (auto-provisioned by Coolify works fine), and the basic-auth bcrypt hash you'll generate in Step 3.
> **Time to complete:** ~10 minutes.

[Coolify](https://coolify.io) is a self-hostable Heroku/Vercel alternative. It's *the* common way our beachhead audience runs production workloads on a single VPS — perfect fit for OTel-jps.

This guide deploys OTel-jps as a Custom Compose resource inside Coolify so it gets the auto-issued domain, Let's Encrypt cert, and one-click upgrade workflow.

---

## Step 1 — Prerequisites

You need:

- A Coolify ≥ 4.0 instance running. Install per [coolify.io/docs](https://coolify.io/docs/installation).
- A server registered in Coolify (your own VPS or a Coolify-managed one) with **at least 4 GB RAM and ~10 GB free disk**.
- A domain pointed at the server. Coolify can also auto-issue subdomains under its wildcard if you've configured one.

---

## Step 2 — Create the resource

1. In Coolify, navigate to your project (or create one).
2. Click **+ Add resource → Docker Compose Empty**.
3. Coolify creates an empty service.

---

## Step 3 — Generate the OTLP basic-auth hash

The OTLP ingestion endpoints are protected by HTTP Basic auth via Caddy. You need a bcrypt hash of the password your apps will use.

On any machine with Docker:

```bash
docker run --rm caddy:2-alpine caddy hash-password --plaintext 'YOUR_OTLP_PASSWORD'
```

Copy the `$2a$14$...` output. Keep your plaintext password too — your apps need it.

---

## Step 4 — Paste the compose file

1. In the Coolify resource UI, find the **Docker Compose** field.
2. Paste the contents of [`templates/coolify/docker-compose.yml`](https://github.com/HameemDakheel/OTel-jps/blob/main/templates/coolify/docker-compose.yml) from the OTel-jps repo.

The compose file uses `${SERVICE_FQDN_GRAFANA}` — Coolify substitutes this automatically with the domain it issues for your service.

---

## Step 5 — Configure environment variables

In the resource's **Environment Variables** tab, add:

| Variable | Value | Notes |
|----------|-------|-------|
| `BASIC_AUTH_USER` | `ingest` | or any username |
| `BASIC_AUTH_HASH` | `$2a$14$...` | from Step 3 |
| `GRAFANA_ADMIN_USER` | `admin` | |
| `GRAFANA_ADMIN_PASSWORD` | (let Coolify generate) | tick "Generate value" |
| `PROMETHEUS_RETENTION` | `7d` | optional |
| `VICTORIALOGS_RETENTION` | `7d` | optional |
| `TEMPO_RETENTION_HOURS` | `72` | optional |
| `PYROSCOPE_RETENTION_HOURS` | `336` | optional |
| `ALERT_WEBHOOK_URL` | (your Slack/Discord webhook) | optional |

---

## Step 6 — Pull config files into the resource

The compose file references several config files (Caddyfile, prometheus.yml, etc.) by relative path. Coolify needs to know where to find them. Two options:

### Option A — Use Coolify's "Custom Mount" feature

For each `./xxx.yaml` reference in the compose file, add a Custom Mount that points to the file. The mapping:

| In compose | Pull from OTel-jps repo path |
|------------|------------------------------|
| `./Caddyfile` | `configs/caddy/Caddyfile` |
| `./otel-collector-config.yaml` | `configs/otel-collector/config.yaml` |
| `./prometheus.yml` | `configs/prometheus/prometheus.yml` |
| `./tempo.yaml` | `configs/tempo/tempo.yaml` |
| `./pyroscope.yaml` | `configs/pyroscope/pyroscope.yaml` |
| `./alerts/` | `alerts/` |
| `./grafana-provisioning/` | `configs/grafana/provisioning/` |
| `./grafana-dashboards/` | `configs/grafana/dashboards/` |

### Option B — Clone-then-deploy

SSH into the Coolify server, clone the OTel-jps repo into Coolify's resource working directory, and let Coolify pick up the files. Heavier but simpler if you're comfortable with shell:

```bash
ssh <coolify-server>
cd /data/coolify/applications/<resource-uuid>/
sudo git clone --branch v1.0.0-alpha.4 https://github.com/HameemDakheel/OTel-jps.git tmp
sudo cp -r tmp/configs/caddy/Caddyfile ./Caddyfile
# ... repeat for each file
sudo rm -rf tmp
```

Then deploy from Coolify UI.

---

## Step 7 — Deploy

Click **Deploy**. Coolify pulls images (~1 GB first time), starts the 8 containers, and binds the auto-issued domain to Grafana.

---

## Step 8 — Verify

In Coolify's resource view, **Deployments** tab — wait for "Running."

Open the auto-issued domain (Coolify shows it at the top of the resource UI). Login: `admin` / your `GRAFANA_ADMIN_PASSWORD` (visible in Coolify's env-vars tab if Coolify generated it).

You should see 4 dashboards in the OTel-jps folder, populated with live data.

---

## Step 9 — Send telemetry from your apps

OTLP HTTP endpoint:

```
https://<coolify-domain>/v1/traces
https://<coolify-domain>/v1/metrics
https://<coolify-domain>/v1/logs
```

Authentication: HTTP Basic auth with your `BASIC_AUTH_USER` (default `ingest`) and the plaintext password you used in Step 3.

For OTel SDKs, set:

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=https://<coolify-domain>
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_HEADERS="authorization=Basic $(echo -n 'ingest:YOUR_OTLP_PASSWORD' | base64)"
```

See the [instrumentation guides](../instrumentation/nodejs.md) for language-specific examples.

---

## Day-2 ops

| Task | How |
|------|-----|
| Pull latest images | Coolify resource → **Pull and restart** |
| View logs | Coolify resource → **Logs** tab |
| Adjust retention | Update env vars → **Restart** |
| Backups | Coolify Backups feature on each volume |

---

## Troubleshooting (Coolify-specific)

- **Resource won't start with "no such file" errors** — config file mounts (Step 6) are missing. Check the Custom Mount table or your Option B clone.
- **Grafana shows blank dashboards** — wait 30 s; Prometheus needs to scrape at least once. If still empty after 60 s, check that the OTel Collector container is running.
- **OTLP gRPC port 4317 unreachable** — Coolify's proxy doesn't proxy raw gRPC. The compose publishes 4317 directly on the host; ensure your firewall allows inbound 4317.
- **TLS errors when apps connect** — the Coolify-issued cert covers HTTPS on the domain (Grafana). The OTLP gRPC port 4317 has Caddy's own cert; if your client doesn't validate, use the same domain so SNI works.

---

## See also

- [Quickstart](../quickstart.md) — minimum walkthrough
- [Architecture](../architecture.md)
- [Coolify documentation](https://coolify.io/docs/)
- [Coolify template README](https://github.com/HameemDakheel/OTel-jps/blob/main/templates/coolify/README.md)
