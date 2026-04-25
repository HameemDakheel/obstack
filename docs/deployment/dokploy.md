# Deploy on Dokploy

> **What you'll need:** a working Dokploy ≥ 0.7 instance, a domain pointed at the host, and the basic-auth bcrypt hash you'll generate in Step 2.
> **Time to complete:** ~10 minutes.

[Dokploy](https://dokploy.com) is a self-hostable Vercel/Netlify alternative with first-class support for Compose-based templates. Its env-var prompting (`${randomPassword}`, `${input}`) makes the install UX smoother than most PaaS platforms.

---

## Step 1 — Prerequisites

You need:

- A Dokploy instance running. Install per [docs.dokploy.com](https://docs.dokploy.com).
- A server with **at least 4 GB RAM and ~10 GB free disk**.
- A domain pointed at the server (used by Caddy for Let's Encrypt).

---

## Step 2 — Generate the OTLP basic-auth hash

```bash
docker run --rm caddy:2-alpine caddy hash-password --plaintext 'YOUR_OTLP_PASSWORD'
```

Save the `$2a$14$...` output and the plaintext password.

---

## Step 3 — Create the service from the template

In Dokploy:

1. Go to your project → **+ Create Service**.
2. Choose **Compose**.
3. Pick the **Custom Template** option.
4. Paste the contents of [`templates/dokploy/template.json`](https://github.com/HameemDakheel/obstack/blob/main/templates/dokploy/template.json).
5. Dokploy parses the env-var prompts and walks you through them:
   - `DOMAIN` — your real domain (Caddy will issue Let's Encrypt for it).
   - `ACME_EMAIL` — your contact email.
   - `GRAFANA_ADMIN_PASSWORD` — Dokploy auto-generates.
   - `BASIC_AUTH_HASH` — paste your hash from Step 2.
   - Retention values — accept defaults or override.
   - `ALERT_WEBHOOK_URL` — optional Slack/Discord webhook.

---

## Step 4 — Pull config files into the project

Dokploy's templates feature pulls the compose file but doesn't auto-fetch sibling config files. You have two options:

### Option A — Clone the repo into Dokploy's project directory

SSH into the Dokploy host:

```bash
ssh <dokploy-host>
cd /etc/dokploy/<project-name>/files/
sudo git clone --branch v1.0.0-alpha.4 https://github.com/HameemDakheel/obstack.git tmp
sudo cp tmp/configs/caddy/Caddyfile ./
sudo cp tmp/configs/otel-collector/config.yaml ./otel-collector-config.yaml
sudo cp tmp/configs/prometheus/prometheus.yml ./
sudo cp tmp/configs/tempo/tempo.yaml ./
sudo cp tmp/configs/pyroscope/pyroscope.yaml ./
sudo cp -r tmp/alerts ./
sudo cp -r tmp/configs/grafana/provisioning ./grafana-provisioning
sudo cp -r tmp/configs/grafana/dashboards ./grafana-dashboards
sudo rm -rf tmp
```

### Option B — Use Dokploy's File Manager

For each path in the compose's volume mounts, upload the file via Dokploy's File Manager UI.

---

## Step 5 — Deploy

Click **Deploy** in the Dokploy service UI. Dokploy:

1. Pulls images (~1 GB first time)
2. Starts the 8 containers
3. Caddy auto-provisions Let's Encrypt for `${DOMAIN}` (assumes your DNS A record points here)

---

## Step 6 — Verify

Open `https://<DOMAIN>/` in your browser. Login: `admin` / value of the auto-generated `GRAFANA_ADMIN_PASSWORD` (visible in Dokploy's env-vars tab).

Check the 4 dashboards in the obstack folder.

---

## Step 7 — Send telemetry from your apps

OTLP HTTP:

```
https://<DOMAIN>/v1/traces
https://<DOMAIN>/v1/metrics
https://<DOMAIN>/v1/logs
```

OTLP gRPC: `<DOMAIN>:4317` (the compose file publishes this port directly).

Authentication: HTTP Basic with `BASIC_AUTH_USER` / your plaintext password from Step 2.

OTel SDK config:

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=https://<DOMAIN>
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_HEADERS="authorization=Basic $(echo -n 'ingest:YOUR_OTLP_PASSWORD' | base64)"
```

Per-language examples: [instrumentation guides](../instrumentation/nodejs.md).

---

## Day-2 ops

| Task | How |
|------|-----|
| Pull latest images and restart | Dokploy service → **Pull and Restart** |
| View logs | Dokploy service → **Logs** tab (live tail) |
| Adjust retention | Update env vars → **Restart** |
| Backups | Dokploy's Backups feature on each volume |
| Upgrade obstack version | Pull updated `template.json` from the repo, redeploy |

---

## Troubleshooting (Dokploy-specific)

- **Service stuck in "Building"** — Dokploy is pulling images. First-run pull is ~1 GB. Wait 2-5 minutes.
- **Caddy says "TLS handshake failed"** — DNS isn't pointing to the host yet. Verify `dig +short <DOMAIN>` returns the host IP. Wait for DNS propagation (TTL).
- **No data in dashboards after 60 s** — check the OTel Collector logs in Dokploy's **Logs** tab. Most often it's a config file mount missing (Step 4).
- **Persistent volume permission errors** — Dokploy stores volumes under `/etc/dokploy/<project>/files/`. Some images (Grafana UID 472) need explicit ownership. The compose file uses named volumes, which Docker sets up correctly by default.

---

## See also

- [Quickstart](../quickstart.md)
- [Architecture](../architecture.md)
- [Dokploy documentation](https://docs.dokploy.com)
- [Dokploy template README](https://github.com/HameemDakheel/obstack/blob/main/templates/dokploy/README.md)
