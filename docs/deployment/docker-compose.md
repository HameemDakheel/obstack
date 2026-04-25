# Deploy with Docker Compose

> **Audience:** anyone deploying OTel-jps directly on a Linux host (not a managed PaaS).
> **What you'll need:** root or sudo, Docker 24+, Docker Compose v2, ≥4 GB RAM.
> **Time to complete:** ~15 minutes (most of which is the first image pull).

This is the canonical "fresh VPS" install. PaaS-specific guides (Coolify, Dokploy, CapRover, Jelastic) are forthcoming in [Phase 4](../superpowers/plans/2026-04-25-otel-jps-redesign-INDEX.md) and reuse this stack underneath.

---

## Step 1 — Provision a host

Recommended specs:

| Use case | RAM | Disk | CPU |
|----------|-----|------|-----|
| Hobby / dev (Simple) | 4 GB | 20 GB | 2 vCPU |
| Small production (Simple) | 8 GB | 40 GB | 2-4 vCPU |
| Multi-app production (future Standard) | 16 GB | 100 GB | 4 vCPU |

Tested on Ubuntu 22.04 / 24.04. Should work on any modern Linux with Docker 24+.

Open these ports at the cloud provider firewall:

- `22` (SSH) — restrict to your IP / VPN
- `80` (HTTP for Caddy + Let's Encrypt ACME) — public
- `443` (HTTPS) — public
- `4317` (OTLP gRPC) — restrict to your application networks

---

## Step 2 — Install Docker

Follow the official Docker docs for your distro: <https://docs.docker.com/engine/install/>

Quickstart for Ubuntu:

```bash
# Remove old versions if any
sudo apt-get remove docker docker-engine docker.io containerd runc

# Add Docker's official repo
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release; echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Allow your user to run docker without sudo (logout/in after this)
sudo usermod -aG docker $USER
```

Verify:

```bash
docker version
docker compose version
```

---

## Step 3 — Clone OTel-jps

```bash
sudo mkdir -p /opt && sudo chown $USER /opt
cd /opt
git clone https://github.com/HameemDakheel/OTel-jps.git
cd OTel-jps
```

---

## Step 4 — Configure

```bash
cp .env.example .env
nano .env   # or your editor of choice
```

Set at minimum:

- `DOMAIN` — your real domain (e.g. `obs.example.com`) for production. Caddy auto-provisions Let's Encrypt. Use `localhost` for testing only.
- `ACME_EMAIL` — your contact email for Let's Encrypt notifications.
- `GRAFANA_ADMIN_PASSWORD` — change from the default `changeme`.
- `BASIC_AUTH_HASH` — generate the bcrypt hash:

  ```bash
  docker run --rm caddy:2-alpine caddy hash-password --plaintext 'YOUR_INGEST_PASSWORD'
  ```

  Copy the `$2a$14$...` output into `BASIC_AUTH_HASH=`.

Optional:

- `ALERT_WEBHOOK_URL` — Slack / Discord / PagerDuty webhook for default alerts.
- Retention values — see [`docs/reference/env-vars.md`](../reference/env-vars.md).

Make DNS point your domain at the host's public IP **before** you run `make simple`, otherwise Caddy can't issue the cert. Wait for DNS propagation (use `dig +short <DOMAIN>`).

---

## Step 5 — Bring up the stack

```bash
make simple
```

First run pulls ~1 GB of images and starts 8 containers. After ~30 seconds, run:

```bash
make verify
```

Expected output:

```
── 7 passed, 0 failed ─────────────────────────
✅ All checks passed.
```

If any service fails, see [Troubleshooting](../operations/troubleshooting.md).

---

## Step 6 — Open Grafana

Visit `https://<YOUR_DOMAIN>/`. Login with `admin` / your `GRAFANA_ADMIN_PASSWORD`. Browse the four pre-loaded dashboards in the **OTel-jps** folder.

---

## Step 7 — Point your apps at OTel-jps

Apps emit OTLP to:

- `https://<YOUR_DOMAIN>/v1/traces`
- `https://<YOUR_DOMAIN>/v1/metrics`
- `https://<YOUR_DOMAIN>/v1/logs`
- `<YOUR_DOMAIN>:4317` (gRPC)

Authentication via HTTP Basic auth. Pick your language:

- [Node.js](../instrumentation/nodejs.md)
- [Python](../instrumentation/python.md)
- [Go](../instrumentation/go.md)
- [Java](../instrumentation/java.md)
- [Ruby](../instrumentation/ruby.md)

---

## Step 8 — Day-2 operations

Common tasks:

```bash
make logs              # tail logs from all services
make verify            # health check
make update            # pull latest images and recreate containers
make demo              # additional: bring up the OTel demo overlay (8+ GB RAM)
make stop              # stop the stack (keeps data)
make clean             # destructive: stop + delete all volumes
```

Routine maintenance:

- **Backups** — see [Backup & Restore](../operations/backup-restore.md).
- **Upgrades** — see [Upgrade](../operations/upgrade.md).
- **Cert renewal** — automatic. See [cert renewal runbook](../operations/runbooks/cert-renewal.md) only if it fails.

---

## Reverse proxies in front of OTel-jps

Caddy already terminates TLS for the stack — putting another reverse proxy in front (Cloudflare, Nginx, Traefik) is **not necessary** and complicates Let's Encrypt issuance.

If you must (e.g. corporate reverse-proxy mandates):
- Set Cloudflare to "Full (Strict)" mode and let Caddy keep its own cert.
- Disable Cloudflare for `:4317` (gRPC isn't proxied well by most CDNs).

---

## See also

- [Quickstart](../quickstart.md) — minimal walkthrough
- [Architecture](../architecture.md) — what's inside the stack
- [Troubleshooting](../operations/troubleshooting.md)
- PaaS deploys (Phase 4): Coolify, Dokploy, CapRover, Jelastic
