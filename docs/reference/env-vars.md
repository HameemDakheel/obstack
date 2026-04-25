# Environment variables

> Source of truth: [`.env.example`](https://github.com/HameemDakheel/OTel-jps/blob/main/.env.example)

All variables shown with their Simple-profile defaults. Override by editing `.env` (which is git-ignored).

---

## Domain & TLS

| Variable | Default | What it does |
|----------|---------|-------------|
| `DOMAIN` | `localhost` | Public hostname for Caddy. Use a real domain to enable Let's Encrypt auto-TLS; `localhost` causes Caddy to issue a self-signed cert. |
| `ACME_EMAIL` | `admin@example.com` | Email reported to Let's Encrypt during cert issuance. Required for non-localhost `DOMAIN`. |

---

## Authentication

| Variable | Default | What it does |
|----------|---------|-------------|
| `GRAFANA_ADMIN_USER` | `admin` | Grafana login username. |
| `GRAFANA_ADMIN_PASSWORD` | `changeme` | Grafana admin password. **Change before exposing publicly.** |
| `BASIC_AUTH_USER` | `ingest` | Username apps use for OTLP ingestion via Caddy. |
| `BASIC_AUTH_HASH` | (placeholder) | bcrypt hash of the ingestion password. Generate with: `docker run --rm caddy:2-alpine caddy hash-password --plaintext '<password>'` |

---

## Retention

| Variable | Default | What it does |
|----------|---------|-------------|
| `PROMETHEUS_RETENTION` | `7d` | How long Prometheus keeps metrics. Format: `<n>d`, `<n>h`. |
| `VICTORIALOGS_RETENTION` | `7d` | How long VictoriaLogs keeps logs. Same format. |
| `TEMPO_RETENTION_HOURS` | `72` | Tempo trace block retention in hours. |
| `PYROSCOPE_RETENTION_HOURS` | `336` | Pyroscope profile retention in hours (default 14 d). |

---

## Alerting

| Variable | Default | What it does |
|----------|---------|-------------|
| `ALERT_WEBHOOK_URL` | `https://example.invalid/alert` | Webhook endpoint for default contact point. Replace with your Slack / Discord / PagerDuty webhook URL. |

---

## Profile

| Variable | Default | What it does |
|----------|---------|-------------|
| `STACK_PROFILE` | `simple` | Advisory marker (informational only — overlay file selection is via `make` target or `docker compose -f` flags). |

---

## How variables flow

1. `.env` is read by Docker Compose at `docker compose up` time.
2. Compose substitutes `${VAR}` and `${VAR:-default}` in service definitions.
3. The substituted values are passed to containers as their environment.
4. Some configs (Tempo, Pyroscope) use shell-style env-var expansion *inside* their YAML files — this requires `-config.expand-env=true` (see Tempo's `command:` for an example).
5. Grafana provisioning files use **plain `$VAR`** (no `${VAR:-default}` syntax) — see [ADR 0006](../decisions/0006-self-monitoring-not-seeder.md) and the alerting provisioning files.

---

## See also

- [Quickstart](../quickstart.md) — minimum env you need to set
- [`.env.example`](https://github.com/HameemDakheel/OTel-jps/blob/main/.env.example) — authoritative source
