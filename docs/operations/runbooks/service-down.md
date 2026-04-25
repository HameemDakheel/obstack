# Runbook: Service down

**Severity:** critical
**Likely alert:** `ServiceDown` (any backend `up == 0` for 2 m)
**Time to remediate:** ~5–15 minutes depending on cause

## Symptoms

- `ServiceDown` alert fires for `prometheus`, `tempo`, `pyroscope`, `grafana`, `cadvisor`, `otel-collector`, or `victorialogs`.
- `make verify` reports the service as failing.
- `docker compose ps` shows the container in `Restarting (N)` or `Exited` state.

## Root causes

- Bad config file (YAML syntax, missing field, deprecated option after a version bump).
- Resource limit too low → OOM-killed.
- Port collision on the host (rare; only Caddy/cAdvisor expose host ports).
- Image pull failed (registry outage, networking, disk full).
- Volume permissions issue.
- Missing env var that the container requires.

## Triage (read-only)

```bash
# 1. Identify the failing service
docker compose -f docker-compose.yml -f compose/simple.yml ps

# 2. Read the most recent logs
docker logs otel-jps-<service> --tail 50

# 3. Did it OOM?
docker inspect otel-jps-<service> | grep -i 'oomkilled\|exitcode'

# 4. Compose config valid?
docker compose -f docker-compose.yml -f compose/simple.yml config --quiet
```

The first 50 log lines almost always tell you the cause — config parse errors, missing env vars, and OOM messages are obvious.

## Remediate

### Cause: bad config file

Logs say something like `failed parsing config: yaml: unmarshal errors`.

1. Validate the YAML directly:

   ```bash
   python3 -c "import yaml; yaml.safe_load(open('configs/prometheus/prometheus.yml'))"
   ```

2. Compare against the version-controlled template (`git diff` the file).
3. Fix the config; then:

   ```bash
   docker compose -f docker-compose.yml -f compose/simple.yml up -d <service>
   ```

### Cause: OOM-killed

`docker inspect` shows `OOMKilled: true`.

1. Bump the memory limit in `compose/simple.yml`:

   ```yaml
   <service>:
     deploy:
       resources:
         limits:
           memory: 768M       # was 384M
   ```

2. Recreate:

   ```bash
   docker compose -f docker-compose.yml -f compose/simple.yml up -d <service>
   ```

3. Investigate *why* RAM was exceeded — usually cardinality (Prometheus) or trace volume (Tempo). See [high-cardinality runbook](high-cardinality.md).

### Cause: port collision (Caddy)

Logs say `bind: address already in use` for ports 80, 443, 4317.

```bash
sudo ss -tlnp | grep -E ':80|:443|:4317'
```

Stop whatever else is using the port (another nginx? another stack?), then `make simple`.

### Cause: image pull failed

Logs say `failed to pull image`.

```bash
# Test network
docker pull <image>
# If that fails, check DNS, firewall, registry status
```

### Cause: volume permissions

Rare but happens when host is restored from backup and UIDs differ.

```bash
sudo chown -R 472:472 /var/lib/docker/volumes/otel-jps_grafana_data/_data
# (Grafana's UID inside container is 472)
```

## Verify recovery

```bash
make verify
docker compose -f docker-compose.yml -f compose/simple.yml ps
```

`ServiceDown` alert should clear within 2 minutes after the container is healthy.

## Prevention

- Pin every image to an exact tag (already done).
- Run `docker compose config --quiet` in CI before merging config changes (Phase 5 sets this up).
- Set up host-level monitoring outside OTel-jps so you find out about service-down even when *Prometheus itself* is the failed service.
- Capacity-plan memory limits — the defaults work for low-volume; double them for moderate production.

## See also

- [Troubleshooting](../troubleshooting.md)
- [Reference / Env vars](../../reference/env-vars.md)
- [High cardinality runbook](high-cardinality.md)
