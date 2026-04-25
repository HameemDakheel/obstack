# Runbook: Disk full

**Severity:** warning → critical
**Likely alert:** `DiskUsageHigh` (root disk >80%)
**Time to remediate:** ~5 minutes

## Symptoms

- `DiskUsageHigh` Prometheus alert fires.
- Ingestion slows or stalls — apps see 503s on OTLP endpoints.
- `docker logs` shows write errors from Prometheus / VictoriaLogs / Tempo.
- `df -h /var/lib/docker` shows >80% utilisation.

## Root causes

- Retention configured higher than disk capacity allows.
- A traffic spike pushed ingestion above the steady-state.
- Old container images / layers consuming disk.
- A volume from a previous OTel-jps version not cleaned up.

## Triage (read-only)

```bash
# Overall disk usage
df -h /

# Largest directories under Docker
sudo du -sh /var/lib/docker/volumes/* | sort -hr | head -10

# Per-volume usage
sudo du -sh /var/lib/docker/volumes/otel-jps_*

# Image bloat
docker system df
```

## Remediate

### Option A — Lower retention (preferred when data isn't critical)

Edit `.env`:

```dotenv
PROMETHEUS_RETENTION=3d           # was 7d
VICTORIALOGS_RETENTION=3d         # was 7d
TEMPO_RETENTION_HOURS=24          # was 72
PYROSCOPE_RETENTION_HOURS=72      # was 336
```

Restart affected services:

```bash
docker compose -f docker-compose.yml -f compose/simple.yml up -d \
  prometheus victorialogs tempo pyroscope
```

Backends will purge old data on their next compaction cycle (~10–60 minutes).

### Option B — Prune Docker

```bash
docker system prune -a -f
```

Removes unused images, containers, networks. **Does not** remove named volumes (your data stays safe).

To remove dangling volumes from previous versions:

```bash
docker volume ls
# Delete any without otel-jps_ prefix that you recognise as old
docker volume rm <name>
```

### Option C — Move volumes to a larger disk

If retention is correct and the host disk is genuinely too small:

```bash
# 1. Stop the stack
make stop

# 2. Mount a bigger disk at /mnt/otel-data
# 3. Move volume data
sudo mv /var/lib/docker/volumes/otel-jps_* /mnt/otel-data/

# 4. Symlink (or remount Docker's data dir)
sudo ln -s /mnt/otel-data/otel-jps_* /var/lib/docker/volumes/

# 5. Restart
make simple
```

## Verify recovery

```bash
make verify
df -h /
```

`DiskUsageHigh` alert should clear within ~10 minutes. Disk usage should drop after compaction completes (depends on retention; up to 30 minutes for Tempo).

## Prevention

- Match retention to your disk size. Rule of thumb: budget ~1 GB/day per signal at moderate volume.
- Set up `df` monitoring outside OTel-jps (the alert only fires when you can still query Prometheus).
- For production, mount a dedicated volume for `/var/lib/docker` with monitoring + extension capability.
- Phase 2's `DiskUsageHigh` alert needs node_exporter to populate `node_filesystem_*` metrics. If you don't run node_exporter on the host, this alert is silent — add it via `host_metrics` in OTel Collector contrib (Phase 2-tier polish).

## See also

- [Backup & Restore](../backup-restore.md)
- [Architecture / Storage](../../architecture.md#storage)
- [Profiles](../../profiles.md) — retention defaults per profile
