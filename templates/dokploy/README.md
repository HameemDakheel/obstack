# OTel-jps for Dokploy

This template lets [Dokploy](https://dokploy.com) users deploy OTel-jps with one click via Dokploy's Templates marketplace.

## Files

| File | Purpose |
|------|---------|
| `template.json` | Dokploy template metadata (name, description, env-var prompts, logo, links) |
| `docker-compose.yml` | Self-contained compose, all services + resource limits in one file |

## Why Dokploy is a great fit for OTel-jps

Dokploy's template format supports:
- **`${randomPassword}`** — auto-generates strong random passwords (we use this for `GRAFANA_ADMIN_PASSWORD`)
- **`${input}`** — prompts the user during install (we use this for `BASIC_AUTH_HASH`)

This gives a much smoother first-run UX than systems where every secret has to be set manually.

## Two install paths

### Path A — Custom template (immediate)

1. In Dokploy, go to your project → **+ Create Service** → **Compose** → **Custom Template**.
2. Paste the contents of `template.json` from this directory.
3. Dokploy reads the env-var prompts and walks you through them.
4. Click **Deploy**. Dokploy clones the repo, generates passwords, runs compose.

### Path B — Submit to the Dokploy Templates marketplace

The Dokploy Templates marketplace at <https://github.com/Dokploy/templates> accepts community-contributed templates via PR. See the marketplace's contribution guide for the exact format.

When approved, OTel-jps shows up in **Create Service → Browse templates** and installs in two clicks.

## Sibling files needed

The compose file references several config files (`Caddyfile`, `prometheus.yml`, etc.) by path. Dokploy's template install pulls these from the repo automatically. If you're using **Path A** (custom template), make sure to also pull the relevant config files into the same Dokploy project:

| In compose | Source path in repo |
|------------|---------------------|
| `./Caddyfile` | `configs/caddy/Caddyfile` |
| `./otel-collector-config.yaml` | `configs/otel-collector/config.yaml` |
| `./prometheus.yml` | `configs/prometheus/prometheus.yml` |
| `./tempo.yaml` | `configs/tempo/tempo.yaml` |
| `./pyroscope.yaml` | `configs/pyroscope/pyroscope.yaml` |
| `./alerts/` | `alerts/` |
| `./grafana-provisioning/` | `configs/grafana/provisioning/` |
| `./grafana-dashboards/` | `configs/grafana/dashboards/` |

## Persistent storage

Dokploy stores volumes under `/etc/dokploy/<project>/files/<volume_name>` on the host. They survive image upgrades; backed up via Dokploy's Backups feature or your own tarball cron.

## TLS

The compose file's Caddy service handles its own TLS via Let's Encrypt for `${DOMAIN}` and the `:4317` gRPC port. Dokploy doesn't need to front it. Make sure DNS points to the host before deploying — Caddy needs port 80 reachable to complete the ACME challenge.

## Upgrade

Use Dokploy's "Pull and restart" action on the service. Equivalent to running `make update` on the host. Volumes persist.

## See also

- [Dokploy deployment guide](https://github.com/HameemDakheel/OTel-jps/blob/main/docs/deployment/dokploy.md) — full step-by-step
- [Dokploy documentation](https://docs.dokploy.com)
- [Architecture](https://github.com/HameemDakheel/OTel-jps/blob/main/docs/architecture.md)
