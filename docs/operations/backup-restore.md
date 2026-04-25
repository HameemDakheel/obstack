# Backup & Restore

> **Audience:** anyone running obstack in production. Read after [Quickstart](../quickstart.md).

At Simple profile, obstack stores all telemetry data in **named Docker volumes** on the local host. Backup is a one-liner; restore is a one-liner; offsite copy is your responsibility.

---

## What gets backed up

| Volume | Container | What it holds |
|--------|-----------|---------------|
| `prometheus_data` | `obstack-prometheus` | Metrics (TSDB blocks) |
| `victorialogs_data` | `obstack-victorialogs` | Logs |
| `tempo_data` | `obstack-tempo` | Traces (blocks + WAL) |
| `pyroscope_data` | `obstack-pyroscope` | Profiles + Pyroscope DB |
| `grafana_data` | `obstack-grafana` | Dashboards (custom), users, sessions, plugins |
| `caddy_data` | `obstack-caddy` | Let's Encrypt certs |
| `caddy_config` | `obstack-caddy` | Caddy config cache |

**Not in the volumes (in git):**
- Configs (Caddyfile, prometheus.yml, datasources YAML, dashboard JSON, alert rules) — version-controlled, restorable from `git clone`
- `.env` — handle separately (sensitive)

---

## Manual backup (one-shot)

Stop the stack first to ensure consistent on-disk state:

```bash
make stop
sudo tar czf obstack-backup-$(date +%F).tar.gz -C /var/lib/docker/volumes/ \
  obstack_prometheus_data \
  obstack_victorialogs_data \
  obstack_tempo_data \
  obstack_pyroscope_data \
  obstack_grafana_data \
  obstack_caddy_data \
  obstack_caddy_config
make simple
```

Result: a tarball you copy offsite (rsync, S3, restic, BorgBackup — your choice).

---

## Live backup (without stopping the stack)

For Prometheus, VictoriaLogs, Tempo, and Pyroscope, hot copies of their data dirs may be inconsistent (a write may be in flight). For Simple-profile telemetry data, this is usually acceptable — losing the last few seconds of metrics on a recovery is rarely critical.

```bash
sudo tar czf obstack-backup-$(date +%F).tar.gz -C /var/lib/docker/volumes/ \
  obstack_prometheus_data \
  obstack_victorialogs_data \
  obstack_tempo_data \
  obstack_pyroscope_data \
  obstack_grafana_data
```

**Caddy data should be backed up cold** — losing the Let's Encrypt cert state mid-renewal can cause issues. Stop the stack just for that:

```bash
docker compose -f docker-compose.yml -f compose/simple.yml stop caddy
sudo tar czf caddy-backup-$(date +%F).tar.gz -C /var/lib/docker/volumes/ \
  obstack_caddy_data obstack_caddy_config
docker compose -f docker-compose.yml -f compose/simple.yml start caddy
```

---

## Restore

On a fresh host:

1. Install Docker, clone repo, configure `.env` per [Quickstart](../quickstart.md).
2. **Don't run `make simple` yet.** Volumes need data first.
3. Create the volumes (without starting containers) and extract:

```bash
docker compose -f docker-compose.yml -f compose/simple.yml create
sudo tar xzf obstack-backup-2026-04-25.tar.gz -C /var/lib/docker/volumes/
make simple
```

4. Verify:

```bash
make verify
```

5. Open Grafana — your historical data should be queryable.

---

## Frequency recommendations

Match retention. Default Simple profile retentions:

| Backend | Retention | Suggested backup cadence |
|---------|-----------|--------------------------|
| Prometheus | 7 d | Weekly |
| VictoriaLogs | 7 d | Weekly |
| Tempo | 3 d | Twice weekly |
| Pyroscope | 14 d | Weekly |

A weekly tarball is enough for most users. Disaster-recovery scenarios (host loss) typically lose ≤7 days of data, which matches the retention.

---

## Cron example (weekly Sunday backup at 03:00)

```bash
# /etc/cron.d/obstack-backup
0 3 * * 0 root cd /opt/obstack && make stop && tar czf /backups/obstack-$(date +\%F).tar.gz -C /var/lib/docker/volumes/ obstack_prometheus_data obstack_victorialogs_data obstack_tempo_data obstack_pyroscope_data obstack_grafana_data obstack_caddy_data obstack_caddy_config && make simple
```

Pair with `find /backups -name 'obstack-*.tar.gz' -mtime +30 -delete` to retain ~30 days locally.

---

## What about backing up to S3?

At Simple profile, telemetry data is on the filesystem (no MinIO). To push backups offsite:

```bash
aws s3 cp obstack-backup-$(date +%F).tar.gz s3://my-backups/obstack/
```

Or use `restic`, `borgbackup`, `kopia` — any backup tool that takes a directory works.

At **Scale profile** (v2), MinIO/S3 is the live storage tier and you'll use `mc mirror` or S3 cross-region replication instead.

---

## See also

- [Upgrade](upgrade.md) — preserves data across version bumps
- [Disk full runbook](runbooks/disk-full.md) — what to do when retention isn't keeping up
- [Profiles](../profiles.md) — Standard/Scale upgrade paths change the backup model
