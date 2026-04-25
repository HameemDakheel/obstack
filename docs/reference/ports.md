# Ports

> Source of truth: [`docker-compose.yml`](https://github.com/HameemDakheel/obstack/blob/main/docker-compose.yml)

---

## Exposed externally (host network)

These ports are bound to the host and reachable from outside Docker.

| Port | Container | Purpose | Auth |
|------|-----------|---------|------|
| `80` | `obstack-caddy` | HTTP — redirects to HTTPS, ACME challenge | none (redirect/challenge) |
| `443` | `obstack-caddy` | HTTPS — Grafana UI, OTLP HTTP ingestion | Grafana login (UI) / Caddy basic auth (`/v1/*`) |
| `4317` | `obstack-caddy` (proxies to OTel Collector) | OTLP gRPC ingestion | TLS + (auth via gRPC metadata header — caller responsibility) |

---

## Internal only (obs-net Docker bridge)

These ports are reachable **only** from other containers in `obs-net`. They are **not** bound to the host.

| Port | Container | Endpoint | Purpose |
|------|-----------|----------|---------|
| `2019` | `obstack-caddy` | `/config/`, `/load`, etc. | Caddy admin API (localhost-only) |
| `4318` | `obstack-otelcol` | `/v1/traces`, `/v1/metrics`, `/v1/logs` | OTLP HTTP receiver (Caddy proxies to here) |
| `4317` | `obstack-otelcol` | (gRPC) | OTLP gRPC receiver (Caddy proxies to here) |
| `8888` | `obstack-otelcol` | `/metrics` | Self-metrics (Prometheus scrapes this) |
| `13133` | `obstack-otelcol` | `/` | health_check extension |
| `9090` | `obstack-prometheus` | `/-/ready`, `/api/v1/*`, `/metrics` | Prometheus HTTP API + UI |
| `9428` | `obstack-victorialogs` | `/health`, `/insert/opentelemetry`, `/select/logsql/*` | VictoriaLogs API |
| `3200` | `obstack-tempo` | `/ready`, `/api/*` | Tempo HTTP query API |
| `4318` | `obstack-tempo` | `/v1/traces` | Tempo OTLP HTTP receiver (Collector pushes here) |
| `9095` | `obstack-tempo` | (gRPC) | Tempo native gRPC |
| `4040` | `obstack-pyroscope` | `/`, `/ready`, `/ingest`, `/api/*` | Pyroscope HTTP API |
| `3000` | `obstack-grafana` | `/`, `/api/*`, `/login` | Grafana UI (Caddy proxies `/` to here) |
| `8080` | `obstack-cadvisor` | `/metrics`, `/api/*` | cAdvisor (Prometheus scrapes this) |

---

## Demo overlay (additional, opt-in)

When `make demo` is active, these ports are also bound:

| Port | Container | Purpose |
|------|-----------|---------|
| `8082` | `obstack-demo-frontend` | Astronomy Shop frontend UI |

The other demo services (cart, checkout, payment, recommendation, valkey, loadgen) are internal-only.

---

## Firewall recommendations

For a production VPS:

| Port | Open from | Why |
|------|-----------|-----|
| `22` (SSH) | Your office IP / VPN | Admin access |
| `80` | Anywhere | Caddy HTTPS redirect + Let's Encrypt ACME |
| `443` | Anywhere (or app subnets) | UI + OTLP HTTP ingestion |
| `4317` | App subnets only | OTLP gRPC ingestion (sensitive to firewalling) |

Block everything else, including Docker-internal ports — they should never be reachable from the internet.

---

## See also

- [Architecture](../architecture.md) — data flow diagram
- [Caddyfile](https://github.com/HameemDakheel/obstack/blob/main/configs/caddy/Caddyfile) — reverse-proxy routes
