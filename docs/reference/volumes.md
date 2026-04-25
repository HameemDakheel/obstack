# Volumes

> Source of truth: [`docker-compose.yml`](https://github.com/HameemDakheel/obstack/blob/main/docker-compose.yml) `volumes:` section.

obstack uses **named Docker volumes** for all persistent data. No host bind-mounts for data (only for read-only configs).

---

## Volume map

| Volume | Container | Mounted at | Backend | Retention impact |
|--------|-----------|------------|---------|------------------|
| `prometheus_data` | `obstack-prometheus` | `/prometheus` | TSDB | Holds all metric blocks; sized by `PROMETHEUS_RETENTION` |
| `victorialogs_data` | `obstack-victorialogs` | `/vlogs` | VictoriaLogs storage | Holds all log data; sized by `VICTORIALOGS_RETENTION` |
| `tempo_data` | `obstack-tempo` | `/var/tempo` | Trace blocks + WAL | Sized by `TEMPO_RETENTION_HOURS` |
| `pyroscope_data` | `obstack-pyroscope` | `/data` | Profile DB + filesystem store | Pyroscope retention default (built-in) |
| `grafana_data` | `obstack-grafana` | `/var/lib/grafana` | SQLite DB + plugins + sessions | Grows with custom dashboards / plugin installs |
| `caddy_data` | `obstack-caddy` | `/data` | Let's Encrypt certs + ACME state | Tiny (a few MB); critical for cert renewal |
| `caddy_config` | `obstack-caddy` | `/config` | Caddy config cache | Tiny |

---

## Read-only mounts (configs from the repo)

| Source on host | Mounted at | Container |
|----------------|-----------|-----------|
| `./configs/caddy/Caddyfile` | `/etc/caddy/Caddyfile` | caddy |
| `./configs/otel-collector/config.yaml` | `/etc/otelcol-contrib/config.yaml` | otel-collector |
| `./configs/prometheus/prometheus.yml` | `/etc/prometheus/prometheus.yml` | prometheus |
| `./alerts` | `/etc/prometheus/rules` | prometheus |
| `./configs/tempo/tempo.yaml` | `/etc/tempo/tempo.yaml` | tempo |
| `./configs/pyroscope/pyroscope.yaml` | `/etc/pyroscope/pyroscope.yaml` | pyroscope |
| `./configs/grafana/provisioning` | `/etc/grafana/provisioning` | grafana |
| `./configs/grafana/dashboards` | `/etc/grafana/dashboards` | grafana |

These are **bind mounts** (host paths) — when you edit a config file in the repo and restart the relevant service, the new config is picked up.

---

## Special mounts (cAdvisor only)

cAdvisor needs broad host access to read container metrics:

| Source on host | Mounted at | Mode |
|----------------|-----------|------|
| `/` | `/rootfs` | ro |
| `/var/run` | `/var/run` | ro |
| `/sys` | `/sys` | ro |
| `/var/lib/docker` | `/var/lib/docker` | ro |
| `/dev/disk` | `/dev/disk` | ro |

`cadvisor` runs `privileged: true` for kernel namespace access. This is standard for cAdvisor and is the only `privileged` container in obstack.

---

## Backup considerations

| Volume | Backup priority | Why |
|--------|-----------------|-----|
| `prometheus_data` | Medium | Reproducible from re-instrumentation if needed |
| `victorialogs_data` | Medium | Same |
| `tempo_data` | Medium | Same |
| `pyroscope_data` | Medium | Same |
| `grafana_data` | **High** | Custom dashboards, users, plugins are here |
| `caddy_data` | **High** | Let's Encrypt cert state; losing it triggers re-issuance and may hit rate limits |
| `caddy_config` | Low | Cache; safe to discard |

See [Backup & Restore](../operations/backup-restore.md) for the full procedure.

---

## Disk space planning

Rough order-of-magnitude per day at moderate volume (≈ 1 service, 10 req/s, 30-day retention):

| Volume | ~Daily growth | 7-day footprint |
|--------|--------------|-----------------|
| `prometheus_data` | 100 MB | 700 MB |
| `victorialogs_data` | 50 MB | 350 MB |
| `tempo_data` | 200 MB | 600 MB (3-day default retention) |
| `pyroscope_data` | 50 MB | 700 MB (14-day default retention) |
| `grafana_data` | minimal | <100 MB |
| `caddy_data`, `caddy_config` | minimal | <10 MB |

**Total at default Simple retention: ~2.5 GB.** A 4 GB disk is tight; 8+ GB recommended for extended use.

---

## See also

- [Backup & Restore](../operations/backup-restore.md)
- [Disk full runbook](../operations/runbooks/disk-full.md)
- [Architecture / Storage](../architecture.md#storage)
