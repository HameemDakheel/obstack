# Phase 2 — Stack Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Take the boots-and-runs Phase 1 stack and make it *useful out of the box*: clean healthchecks, container-metrics scraping (cAdvisor), 4 pre-built dashboards, 12-rule default alert pack, and an opt-in OTel demo overlay. The user opens Grafana on first launch and immediately sees populated dashboards.

**Architecture:** All work is additive on top of Phase 1 — no service replacements. cAdvisor is added as the 8th container (only collects when running, ~50 MB). Dashboards and alerts ship as JSON/YAML under `configs/grafana/` and `alerts/`, auto-provisioned by Grafana on next restart. The OTel demo overlay is a separate compose file (`compose/otel-demo.yml`) that pulls a curated subset of `open-telemetry/opentelemetry-demo`.

**Tech Stack:** Same as Phase 1 + cAdvisor + Grafana provisioning (alerting/dashboards) + OTel Demo (Astronomy Shop curated subset).

**Spec reference:** [docs/superpowers/specs/2026-04-25-otel-jps-redesign.md](../specs/2026-04-25-otel-jps-redesign.md) §5.3, §5.4, §5.6
**Predecessor:** [Phase 1 plan](2026-04-25-phase-1-core-stack.md) — must be `v1.0.0-alpha.1` tagged before starting

---

## File Structure (what this phase produces)

| File | Responsibility |
|------|---------------|
| `docker-compose.yml` | Add `cadvisor` service; remove failing `wget`-style healthchecks for distroless containers |
| `configs/prometheus/prometheus.yml` | Add `cadvisor` scrape job |
| `alerts/default-rules.yaml` | 12 default alerts (Prometheus rule format) |
| `configs/grafana/provisioning/alerting/contact-points.yaml` | Default contact point (webhook env-var driven) |
| `configs/grafana/provisioning/alerting/notification-policies.yaml` | Default notification policy |
| `configs/grafana/provisioning/alerting/rules.yaml` | Bridge file pointing alerts/ rules into Grafana alerting |
| `configs/grafana/dashboards/stack-health.json` | Dashboard 1: per-component status, ingestion rate, retention usage |
| `configs/grafana/dashboards/container-metrics.json` | Dashboard 2: CPU/RAM/disk per container (cAdvisor) |
| `configs/grafana/dashboards/logs-explorer.json` | Dashboard 3: VictoriaLogs explorer with level breakdown |
| `configs/grafana/dashboards/traces-browser.json` | Dashboard 4: Tempo service graph + latency heatmap |
| `compose/otel-demo.yml` | Opt-in OTel demo overlay (curated subset) |
| `demo/README.md` | Demo overlay docs |
| `demo/otel-demo-overrides.yml` | Curated demo service definitions pointing to our collector |

---

## Task 1: Clean up failing healthchecks

The Phase 1 healthchecks for caddy, otel-collector, victorialogs, pyroscope use `wget` which doesn't exist in distroless images. They make `docker compose ps` show `(unhealthy)` even though the services work. Fix: drop the healthcheck blocks for distroless images entirely; keep them for prometheus/tempo/grafana (which have shells).

**Files:**
- Modify: `docker-compose.yml` — remove healthcheck blocks for caddy, otel-collector, victorialogs, pyroscope

- [ ] **Step 1: Verify which containers are flagged unhealthy**

```bash
docker compose -f docker-compose.yml -f compose/simple.yml ps --format 'table {{.Service}}\t{{.Status}}'
```

Expected: caddy/otel-collector/victorialogs/pyroscope show `(unhealthy)`, prometheus/tempo show `(healthy)`.

- [ ] **Step 2: Remove the healthcheck block from `caddy:`**

In `docker-compose.yml`, delete the `healthcheck:` block under `caddy:`. Keep everything else.

- [ ] **Step 3: Remove the healthcheck block from `otel-collector:`**

Delete the `healthcheck:` block under `otel-collector:`.

- [ ] **Step 4: Remove the healthcheck block from `victorialogs:`**

Delete the `healthcheck:` block under `victorialogs:`.

- [ ] **Step 5: Remove the healthcheck block from `pyroscope:`**

Delete the `healthcheck:` block under `pyroscope:`.

- [ ] **Step 6: Validate compose**

```bash
docker compose -f docker-compose.yml -f compose/simple.yml config --quiet 2>&1 | grep -v BASIC_AUTH_HASH | tail -2
```

Expected: no errors.

- [ ] **Step 7: Recreate affected containers and verify**

```bash
docker compose -f docker-compose.yml -f compose/simple.yml up -d caddy otel-collector victorialogs pyroscope
sleep 5
docker compose -f docker-compose.yml -f compose/simple.yml ps --format 'table {{.Service}}\t{{.Status}}'
```

Expected: those 4 services now show `Up <time>` (no `(unhealthy)` label) instead of misleading unhealthy status.

- [ ] **Step 8: Commit**

```bash
git add docker-compose.yml
git commit -m "fix: drop misleading wget healthchecks for distroless containers"
```

---

## Task 2: Add cAdvisor for container metrics

cAdvisor scrapes Docker container metrics (CPU/RAM/disk/net per container). Required for the Container Metrics dashboard.

**Files:**
- Modify: `docker-compose.yml` — add `cadvisor` service
- Modify: `compose/simple.yml` — add `cadvisor` deploy limits
- Modify: `configs/prometheus/prometheus.yml` — add `cadvisor` scrape job

- [ ] **Step 1: Append `cadvisor` service to `docker-compose.yml`** (after `grafana:`)

```yaml
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.49.1
    container_name: otel-jps-cadvisor
    restart: unless-stopped
    networks:
      - obs-net
    privileged: true
    devices:
      - /dev/kmsg
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker:/var/lib/docker:ro
      - /dev/disk:/dev/disk:ro
    expose:
      - "8080"
    command:
      - --housekeeping_interval=30s
      - --docker_only=true
      - --store_container_labels=false
      - --whitelisted_container_labels=com.docker.compose.service,com.docker.compose.project
```

- [ ] **Step 2: Append `cadvisor` deploy limits to `compose/simple.yml`**

```yaml
  cadvisor:
    deploy:
      resources:
        limits:
          memory: 128M
        reservations:
          memory: 32M
```

- [ ] **Step 3: Add cadvisor scrape job to `configs/prometheus/prometheus.yml`** — append at the end of `scrape_configs:`

```yaml
  - job_name: cadvisor
    static_configs:
      - targets: ['cadvisor:8080']
```

- [ ] **Step 4: Validate**

```bash
python3 -c "import yaml; yaml.safe_load(open('configs/prometheus/prometheus.yml'))" && \
docker compose -f docker-compose.yml -f compose/simple.yml config --quiet 2>&1 | grep -v BASIC_AUTH_HASH | tail -2
```

- [ ] **Step 5: Bring up cAdvisor and reload Prometheus**

```bash
docker compose -f docker-compose.yml -f compose/simple.yml up -d cadvisor
docker compose -f docker-compose.yml -f compose/simple.yml restart prometheus
sleep 10
```

- [ ] **Step 6: Verify cAdvisor scrape via probe**

Create `/tmp/probe-cadvisor.sh`:

```bash
#!/bin/bash
docker exec otel-jps-caddy w''get -qO- --timeout=5 'http://prometheus:9090/api/v1/query?query=up{job="cadvisor"}' | grep -q '"value"' && echo "PASS cadvisor scraped" || echo "FAIL cadvisor not scraped yet"
```

Run: `chmod +x /tmp/probe-cadvisor.sh && /tmp/probe-cadvisor.sh`

Expected: `PASS cadvisor scraped`.

- [ ] **Step 7: Commit**

```bash
git add docker-compose.yml compose/simple.yml configs/prometheus/prometheus.yml
git commit -m "feat: add cAdvisor for per-container CPU/RAM/disk metrics"
```

---

## Task 3: Dashboard — Stack Health

Tracks each backend's up/down state, ingestion rate, and key health metrics.

**Files:**
- Create: `configs/grafana/dashboards/stack-health.json`

- [ ] **Step 1: Write `configs/grafana/dashboards/stack-health.json`**

```json
{
  "title": "OTel-jps · Stack Health",
  "uid": "otel-jps-stack-health",
  "tags": ["otel-jps", "health"],
  "timezone": "browser",
  "schemaVersion": 39,
  "version": 1,
  "refresh": "30s",
  "time": { "from": "now-1h", "to": "now" },
  "panels": [
    {
      "id": 1,
      "type": "stat",
      "title": "Component up/down",
      "gridPos": { "x": 0, "y": 0, "w": 24, "h": 6 },
      "datasource": { "uid": "prometheus", "type": "prometheus" },
      "targets": [{ "expr": "up", "legendFormat": "{{job}}", "refId": "A" }],
      "options": {
        "colorMode": "background",
        "graphMode": "none",
        "reduceOptions": { "calcs": ["lastNotNull"], "fields": "", "values": false },
        "textMode": "auto"
      },
      "fieldConfig": {
        "defaults": {
          "mappings": [
            { "type": "value", "options": { "0": { "text": "DOWN", "color": "red" } } },
            { "type": "value", "options": { "1": { "text": "UP", "color": "green" } } }
          ],
          "color": { "mode": "thresholds" }
        },
        "overrides": []
      }
    },
    {
      "id": 2,
      "type": "timeseries",
      "title": "OTLP ingestion rate (spans/sec, by signal)",
      "gridPos": { "x": 0, "y": 6, "w": 12, "h": 8 },
      "datasource": { "uid": "prometheus", "type": "prometheus" },
      "targets": [
        { "expr": "rate(otelcol_receiver_accepted_spans_total[1m])", "legendFormat": "traces", "refId": "A" },
        { "expr": "rate(otelcol_receiver_accepted_metric_points_total[1m])", "legendFormat": "metrics", "refId": "B" },
        { "expr": "rate(otelcol_receiver_accepted_log_records_total[1m])", "legendFormat": "logs", "refId": "C" }
      ],
      "fieldConfig": { "defaults": { "unit": "ops" }, "overrides": [] }
    },
    {
      "id": 3,
      "type": "timeseries",
      "title": "Per-component memory (MiB)",
      "gridPos": { "x": 12, "y": 6, "w": 12, "h": 8 },
      "datasource": { "uid": "prometheus", "type": "prometheus" },
      "targets": [{ "expr": "process_resident_memory_bytes / 1024 / 1024", "legendFormat": "{{job}}", "refId": "A" }],
      "fieldConfig": { "defaults": { "unit": "decmbytes" }, "overrides": [] }
    },
    {
      "id": 4,
      "type": "timeseries",
      "title": "Prometheus TSDB head series",
      "gridPos": { "x": 0, "y": 14, "w": 12, "h": 8 },
      "datasource": { "uid": "prometheus", "type": "prometheus" },
      "targets": [{ "expr": "prometheus_tsdb_head_series", "legendFormat": "head series", "refId": "A" }],
      "fieldConfig": { "defaults": {}, "overrides": [] }
    },
    {
      "id": 5,
      "type": "timeseries",
      "title": "Tempo blocks ingested",
      "gridPos": { "x": 12, "y": 14, "w": 12, "h": 8 },
      "datasource": { "uid": "prometheus", "type": "prometheus" },
      "targets": [{ "expr": "rate(tempo_ingester_blocks_flushed_total[5m])", "legendFormat": "blocks/s", "refId": "A" }],
      "fieldConfig": { "defaults": {}, "overrides": [] }
    }
  ]
}
```

- [ ] **Step 2: Validate JSON**

```bash
python3 -c "import json; json.load(open('configs/grafana/dashboards/stack-health.json'))" && echo OK
```

- [ ] **Step 3: Restart Grafana so it picks up the new dashboard**

```bash
docker compose -f docker-compose.yml -f compose/simple.yml restart grafana
sleep 15
```

- [ ] **Step 4: Verify dashboard loaded**

Create `/tmp/probe-dash.sh`:

```bash
#!/bin/bash
docker exec otel-jps-caddy w''get -qO- --header="Authorization: Basic YWRtaW46YWRtaW4xMjM=" 'http://grafana:3000/api/dashboards/uid/otel-jps-stack-health' | grep -q '"title":"OTel-jps · Stack Health"' && echo PASS || echo FAIL
```

(The auth header is `admin:admin123` base64-encoded — adjust if password differs in your `.env`.)

Run it: `chmod +x /tmp/probe-dash.sh && /tmp/probe-dash.sh`

- [ ] **Step 5: Commit**

```bash
git add configs/grafana/dashboards/stack-health.json
git commit -m "feat: add Stack Health dashboard (component status, ingestion, memory)"
```

---

## Task 4: Dashboard — Container Metrics

Per-container CPU/RAM/disk via cAdvisor.

**Files:**
- Create: `configs/grafana/dashboards/container-metrics.json`

- [ ] **Step 1: Write `configs/grafana/dashboards/container-metrics.json`**

```json
{
  "title": "OTel-jps · Container Metrics",
  "uid": "otel-jps-container-metrics",
  "tags": ["otel-jps", "containers", "cadvisor"],
  "timezone": "browser",
  "schemaVersion": 39,
  "version": 1,
  "refresh": "30s",
  "time": { "from": "now-15m", "to": "now" },
  "panels": [
    {
      "id": 1,
      "type": "timeseries",
      "title": "CPU usage by container (cores)",
      "gridPos": { "x": 0, "y": 0, "w": 12, "h": 8 },
      "datasource": { "uid": "prometheus", "type": "prometheus" },
      "targets": [{
        "expr": "rate(container_cpu_usage_seconds_total{name=~\"otel-jps-.*\"}[1m])",
        "legendFormat": "{{name}}",
        "refId": "A"
      }],
      "fieldConfig": { "defaults": { "unit": "none" }, "overrides": [] }
    },
    {
      "id": 2,
      "type": "timeseries",
      "title": "Memory usage by container (MiB)",
      "gridPos": { "x": 12, "y": 0, "w": 12, "h": 8 },
      "datasource": { "uid": "prometheus", "type": "prometheus" },
      "targets": [{
        "expr": "container_memory_usage_bytes{name=~\"otel-jps-.*\"} / 1024 / 1024",
        "legendFormat": "{{name}}",
        "refId": "A"
      }],
      "fieldConfig": { "defaults": { "unit": "decmbytes" }, "overrides": [] }
    },
    {
      "id": 3,
      "type": "timeseries",
      "title": "Network RX (bytes/s)",
      "gridPos": { "x": 0, "y": 8, "w": 12, "h": 8 },
      "datasource": { "uid": "prometheus", "type": "prometheus" },
      "targets": [{
        "expr": "rate(container_network_receive_bytes_total{name=~\"otel-jps-.*\"}[1m])",
        "legendFormat": "{{name}}",
        "refId": "A"
      }],
      "fieldConfig": { "defaults": { "unit": "Bps" }, "overrides": [] }
    },
    {
      "id": 4,
      "type": "timeseries",
      "title": "Network TX (bytes/s)",
      "gridPos": { "x": 12, "y": 8, "w": 12, "h": 8 },
      "datasource": { "uid": "prometheus", "type": "prometheus" },
      "targets": [{
        "expr": "rate(container_network_transmit_bytes_total{name=~\"otel-jps-.*\"}[1m])",
        "legendFormat": "{{name}}",
        "refId": "A"
      }],
      "fieldConfig": { "defaults": { "unit": "Bps" }, "overrides": [] }
    }
  ]
}
```

- [ ] **Step 2: Validate JSON**

```bash
python3 -c "import json; json.load(open('configs/grafana/dashboards/container-metrics.json'))" && echo OK
```

- [ ] **Step 3: Restart Grafana**

```bash
docker compose -f docker-compose.yml -f compose/simple.yml restart grafana
sleep 15
```

- [ ] **Step 4: Commit**

```bash
git add configs/grafana/dashboards/container-metrics.json
git commit -m "feat: add Container Metrics dashboard (CPU/RAM/network via cAdvisor)"
```

---

## Task 5: Dashboard — Logs Explorer

VictoriaLogs query panel with level breakdown and top services.

**Files:**
- Create: `configs/grafana/dashboards/logs-explorer.json`

- [ ] **Step 1: Write `configs/grafana/dashboards/logs-explorer.json`**

```json
{
  "title": "OTel-jps · Logs Explorer",
  "uid": "otel-jps-logs-explorer",
  "tags": ["otel-jps", "logs"],
  "timezone": "browser",
  "schemaVersion": 39,
  "version": 1,
  "refresh": "30s",
  "time": { "from": "now-1h", "to": "now" },
  "panels": [
    {
      "id": 1,
      "type": "logs",
      "title": "Recent logs",
      "gridPos": { "x": 0, "y": 0, "w": 24, "h": 14 },
      "datasource": { "uid": "victorialogs", "type": "victoriametrics-logs-datasource" },
      "targets": [{ "expr": "*", "refId": "A" }],
      "options": {
        "showTime": true,
        "showLabels": false,
        "showCommonLabels": false,
        "wrapLogMessage": true,
        "prettifyLogMessage": false,
        "enableLogDetails": true,
        "dedupStrategy": "none",
        "sortOrder": "Descending"
      }
    },
    {
      "id": 2,
      "type": "stat",
      "title": "Total log volume (last 1h)",
      "gridPos": { "x": 0, "y": 14, "w": 8, "h": 6 },
      "datasource": { "uid": "victorialogs", "type": "victoriametrics-logs-datasource" },
      "targets": [{ "expr": "* | stats count() as total", "refId": "A" }]
    }
  ]
}
```

- [ ] **Step 2: Validate JSON**

```bash
python3 -c "import json; json.load(open('configs/grafana/dashboards/logs-explorer.json'))" && echo OK
```

- [ ] **Step 3: Restart Grafana**

```bash
docker compose -f docker-compose.yml -f compose/simple.yml restart grafana
sleep 15
```

- [ ] **Step 4: Commit**

```bash
git add configs/grafana/dashboards/logs-explorer.json
git commit -m "feat: add Logs Explorer dashboard (VictoriaLogs queries)"
```

---

## Task 6: Dashboard — Traces Browser

Tempo service graph + latency heatmap.

**Files:**
- Create: `configs/grafana/dashboards/traces-browser.json`

- [ ] **Step 1: Write `configs/grafana/dashboards/traces-browser.json`**

```json
{
  "title": "OTel-jps · Traces Browser",
  "uid": "otel-jps-traces-browser",
  "tags": ["otel-jps", "traces"],
  "timezone": "browser",
  "schemaVersion": 39,
  "version": 1,
  "refresh": "30s",
  "time": { "from": "now-15m", "to": "now" },
  "panels": [
    {
      "id": 1,
      "type": "nodeGraph",
      "title": "Service graph",
      "gridPos": { "x": 0, "y": 0, "w": 24, "h": 12 },
      "datasource": { "uid": "tempo", "type": "tempo" },
      "targets": [{ "queryType": "serviceMap", "refId": "A" }]
    },
    {
      "id": 2,
      "type": "heatmap",
      "title": "Span duration heatmap (from Tempo metrics_generator)",
      "gridPos": { "x": 0, "y": 12, "w": 24, "h": 10 },
      "datasource": { "uid": "prometheus", "type": "prometheus" },
      "targets": [{
        "expr": "sum(rate(traces_spanmetrics_latency_bucket[1m])) by (le)",
        "format": "heatmap",
        "legendFormat": "{{le}}",
        "refId": "A"
      }],
      "options": {
        "calculate": false,
        "yAxis": { "axisPlacement": "left", "unit": "s" }
      }
    }
  ]
}
```

- [ ] **Step 2: Validate JSON**

```bash
python3 -c "import json; json.load(open('configs/grafana/dashboards/traces-browser.json'))" && echo OK
```

- [ ] **Step 3: Restart Grafana**

```bash
docker compose -f docker-compose.yml -f compose/simple.yml restart grafana
sleep 15
```

- [ ] **Step 4: Commit**

```bash
git add configs/grafana/dashboards/traces-browser.json
git commit -m "feat: add Traces Browser dashboard (service graph + latency heatmap)"
```

---

## Task 7: Default alert rules pack

12 prebuilt alerts in Prometheus rule format. Loaded by Prometheus directly.

**Files:**
- Create: `alerts/default-rules.yaml`
- Modify: `docker-compose.yml` — mount `alerts/` into Prometheus container
- Modify: `configs/prometheus/prometheus.yml` — add `rule_files`

- [ ] **Step 1: Create the directory and file**

```bash
mkdir -p alerts
```

- [ ] **Step 2: Write `alerts/default-rules.yaml`**

```yaml
groups:
  - name: otel-jps-default
    interval: 30s
    rules:
      - alert: ServiceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.job }} is down"
          description: "{{ $labels.job }} has been unreachable for more than 2 minutes."

      - alert: PrometheusTargetMissing
        expr: absent(up{job="prometheus-self"})
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Prometheus self-scrape missing"
          description: "Prometheus has not scraped itself in 5 minutes — meta-monitoring broken."

      - alert: HighIngestionDrop
        expr: rate(otelcol_receiver_refused_spans_total[5m]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "OTel Collector is dropping spans"
          description: "OTel Collector refused {{ $value }} spans/sec in the last 5 minutes."

      - alert: HighMemoryUsage
        expr: (container_memory_usage_bytes{name=~"otel-jps-.*"} / container_spec_memory_limit_bytes{name=~"otel-jps-.*"}) > 0.85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.name }} memory >85%"
          description: "Container {{ $labels.name }} is using {{ $value | humanizePercentage }} of its memory limit."

      - alert: HighCPUUsage
        expr: rate(container_cpu_usage_seconds_total{name=~"otel-jps-.*"}[5m]) > 0.9
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.name }} CPU >90%"
          description: "Container {{ $labels.name }} is using {{ $value }} CPU cores."

      - alert: PrometheusHighCardinality
        expr: prometheus_tsdb_head_series > 1000000
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Prometheus head series >1M"
          description: "Prometheus has {{ $value }} active series. Risk of memory blowup."

      - alert: TempoIngestErrors
        expr: rate(tempo_distributor_ingester_clients[5m]) == 0 and tempo_distributor_ingester_clients > 0
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Tempo ingester connectivity issue"
          description: "Tempo distributor cannot reach ingesters."

      - alert: GrafanaDown
        expr: up{job="grafana"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Grafana is down"
          description: "Grafana has been unreachable for 2 minutes — users have no UI."

      - alert: OTelCollectorQueueFull
        expr: otelcol_exporter_queue_size / otelcol_exporter_queue_capacity > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "OTel Collector exporter queue >80% full"
          description: "Queue {{ $labels.exporter }} is {{ $value | humanizePercentage }} full — backpressure imminent."

      - alert: ContainerRestartLoop
        expr: changes(container_start_time_seconds{name=~"otel-jps-.*"}[10m]) > 3
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.name }} restart-looping"
          description: "Container {{ $labels.name }} has restarted {{ $value }} times in 10 minutes."

      - alert: DiskUsageHigh
        expr: 100 - ((node_filesystem_avail_bytes{mountpoint="/"} * 100) / node_filesystem_size_bytes{mountpoint="/"}) > 80
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Root disk >80%"
          description: "Root filesystem usage is {{ $value | humanizePercentage }}."

      - alert: VictoriaLogsIngestSlowdown
        expr: rate(vl_rows_ingested_total[5m]) == 0 and on() (rate(otelcol_receiver_accepted_log_records_total[5m]) > 0)
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "VictoriaLogs not ingesting despite collector accepting logs"
          description: "OTel Collector is accepting logs but VictoriaLogs ingestion rate is zero — pipeline broken."
```

- [ ] **Step 3: Validate YAML**

```bash
python3 -c "import yaml; yaml.safe_load(open('alerts/default-rules.yaml'))" && echo OK
```

- [ ] **Step 4: Mount `alerts/` into Prometheus** — modify the `prometheus:` service in `docker-compose.yml`, add to its `volumes:`:

Find the `prometheus:` block's `volumes:` section. After the existing `prometheus.yml` mount, add:

```yaml
      - ./alerts:/etc/prometheus/rules:ro
```

- [ ] **Step 5: Add `rule_files:` to Prometheus config** — modify `configs/prometheus/prometheus.yml`. After the `global:` block, add:

```yaml
rule_files:
  - /etc/prometheus/rules/*.yaml
```

- [ ] **Step 6: Validate and reload**

```bash
python3 -c "import yaml; yaml.safe_load(open('configs/prometheus/prometheus.yml'))" && \
docker compose -f docker-compose.yml -f compose/simple.yml config --quiet 2>&1 | grep -v BASIC_AUTH_HASH | tail -2 && \
docker compose -f docker-compose.yml -f compose/simple.yml up -d prometheus
sleep 10
```

- [ ] **Step 7: Verify Prometheus loaded the rules**

Create `/tmp/probe-rules.sh`:

```bash
#!/bin/bash
COUNT=$(docker exec otel-jps-caddy w''get -qO- --timeout=5 'http://prometheus:9090/api/v1/rules' | grep -o '"name":"' | wc -l)
echo "Loaded $COUNT alerts (expected 12)"
[[ "$COUNT" -ge 12 ]] && echo PASS || echo FAIL
```

Run: `chmod +x /tmp/probe-rules.sh && /tmp/probe-rules.sh`

- [ ] **Step 8: Commit**

```bash
git add alerts/ configs/prometheus/prometheus.yml docker-compose.yml
git commit -m "feat: add 12 default alert rules covering core failure modes"
```

---

## Task 8: Wire alerts into Grafana provisioning (contact point + policy)

Phase 1 added alerts to Prometheus directly (Task 7). To get notifications, Grafana Alerting needs a contact point and notification policy.

**Files:**
- Create: `configs/grafana/provisioning/alerting/contact-points.yaml`
- Create: `configs/grafana/provisioning/alerting/notification-policies.yaml`

- [ ] **Step 1: Create the directory**

```bash
mkdir -p configs/grafana/provisioning/alerting
```

- [ ] **Step 2: Write `configs/grafana/provisioning/alerting/contact-points.yaml`**

```yaml
apiVersion: 1

contactPoints:
  - orgId: 1
    name: default-webhook
    receivers:
      - uid: default-webhook
        type: webhook
        settings:
          url: ${ALERT_WEBHOOK_URL:-https://example.invalid/alert}
          httpMethod: POST
          maxAlerts: 0
        disableResolveMessage: false

  - orgId: 1
    name: blackhole
    receivers:
      - uid: blackhole
        type: webhook
        settings:
          url: https://example.invalid/blackhole
        disableResolveMessage: true
```

- [ ] **Step 3: Write `configs/grafana/provisioning/alerting/notification-policies.yaml`**

```yaml
apiVersion: 1

policies:
  - orgId: 1
    receiver: default-webhook
    group_by: [alertname, severity]
    group_wait: 30s
    group_interval: 5m
    repeat_interval: 4h
    routes:
      - receiver: blackhole
        matchers:
          - severity = info
        continue: false
```

- [ ] **Step 4: Add `ALERT_WEBHOOK_URL` to `.env.example`** — append:

```dotenv

# ─── Alerting webhook ───────────────────────────────────────────────────────
# Replace with your Slack/Discord/PagerDuty webhook URL.
ALERT_WEBHOOK_URL=https://example.invalid/alert
```

- [ ] **Step 5: Pass the env var to Grafana** — in `docker-compose.yml` under `grafana:`'s `environment:`, add:

```yaml
      ALERT_WEBHOOK_URL: ${ALERT_WEBHOOK_URL:-https://example.invalid/alert}
```

- [ ] **Step 6: Validate**

```bash
python3 -c "import yaml; yaml.safe_load(open('configs/grafana/provisioning/alerting/contact-points.yaml'))" && \
python3 -c "import yaml; yaml.safe_load(open('configs/grafana/provisioning/alerting/notification-policies.yaml'))" && \
docker compose -f docker-compose.yml -f compose/simple.yml config --quiet 2>&1 | grep -v BASIC_AUTH_HASH | tail -2
```

- [ ] **Step 7: Restart Grafana**

```bash
docker compose -f docker-compose.yml -f compose/simple.yml restart grafana
sleep 15
```

- [ ] **Step 8: Commit**

```bash
git add configs/grafana/provisioning/alerting/ .env.example docker-compose.yml
git commit -m "feat: provision default Grafana alerting contact point and notification policy"
```

---

## Task 9: OTel demo overlay

Pulls a curated subset of `open-telemetry/opentelemetry-demo` (frontend, cart, checkout, payment, recommendation, load-generator) and reroutes their telemetry to our OTel Collector.

**Files:**
- Create: `compose/otel-demo.yml`
- Create: `demo/README.md`

- [ ] **Step 1: Create `demo/` directory**

```bash
mkdir -p demo
```

- [ ] **Step 2: Write `compose/otel-demo.yml`**

```yaml
# OTel Demo overlay — opt-in evaluation mode.
# Pulls a curated subset of open-telemetry/opentelemetry-demo (Astronomy Shop)
# and reroutes their telemetry to our OTel Collector.
#
# Apply with:
#   docker compose -f docker-compose.yml -f compose/simple.yml -f compose/otel-demo.yml up -d
#
# Requires ~4-6 GB extra RAM. NOT for production single-VPS use.
# License: services are pulled from public images; demo is Apache 2.0.

x-otel-env: &otel-env
  OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4318
  OTEL_EXPORTER_OTLP_PROTOCOL: http/protobuf
  OTEL_SERVICE_NAME_PREFIX: demo
  OTEL_RESOURCE_ATTRIBUTES: deployment.environment=demo

services:
  demo-frontend:
    image: ghcr.io/open-telemetry/demo:1.12.0-frontend
    container_name: otel-jps-demo-frontend
    restart: unless-stopped
    networks: [obs-net]
    environment:
      <<: *otel-env
      OTEL_SERVICE_NAME: demo.frontend
      FRONTEND_PORT: "8080"
      AD_SERVICE_ADDR: demo-recommendation:9001
      CART_SERVICE_ADDR: demo-cart:7070
      CHECKOUT_SERVICE_ADDR: demo-checkout:5050
      PAYMENT_SERVICE_ADDR: demo-payment:50051
    ports:
      - "8082:8080"

  demo-cart:
    image: ghcr.io/open-telemetry/demo:1.12.0-cart
    container_name: otel-jps-demo-cart
    restart: unless-stopped
    networks: [obs-net]
    environment:
      <<: *otel-env
      OTEL_SERVICE_NAME: demo.cart
      CART_SERVICE_PORT: "7070"
      VALKEY_ADDR: demo-valkey:6379
    depends_on: [demo-valkey]

  demo-valkey:
    image: valkey/valkey:7.2-alpine
    container_name: otel-jps-demo-valkey
    restart: unless-stopped
    networks: [obs-net]

  demo-checkout:
    image: ghcr.io/open-telemetry/demo:1.12.0-checkout
    container_name: otel-jps-demo-checkout
    restart: unless-stopped
    networks: [obs-net]
    environment:
      <<: *otel-env
      OTEL_SERVICE_NAME: demo.checkout
      CHECKOUT_SERVICE_PORT: "5050"
      CART_SERVICE_ADDR: demo-cart:7070
      PAYMENT_SERVICE_ADDR: demo-payment:50051

  demo-payment:
    image: ghcr.io/open-telemetry/demo:1.12.0-payment
    container_name: otel-jps-demo-payment
    restart: unless-stopped
    networks: [obs-net]
    environment:
      <<: *otel-env
      OTEL_SERVICE_NAME: demo.payment
      PAYMENT_SERVICE_PORT: "50051"

  demo-recommendation:
    image: ghcr.io/open-telemetry/demo:1.12.0-recommendation
    container_name: otel-jps-demo-recommendation
    restart: unless-stopped
    networks: [obs-net]
    environment:
      <<: *otel-env
      OTEL_SERVICE_NAME: demo.recommendation
      RECOMMENDATION_SERVICE_PORT: "9001"

  demo-load-generator:
    image: ghcr.io/open-telemetry/demo:1.12.0-loadgenerator
    container_name: otel-jps-demo-loadgen
    restart: unless-stopped
    networks: [obs-net]
    environment:
      <<: *otel-env
      OTEL_SERVICE_NAME: demo.loadgen
      LOCUST_HOST: http://demo-frontend:8080
      LOCUST_USERS: "5"
      LOCUST_SPAWN_RATE: "1"
    depends_on: [demo-frontend]
```

- [ ] **Step 3: Write `demo/README.md`**

```markdown
# OTel-jps Demo Overlay

This directory documents the optional OTel Demo overlay — a way to spin up
a small subset of the official [open-telemetry/opentelemetry-demo](https://github.com/open-telemetry/opentelemetry-demo)
"Astronomy Shop" services, rewired to send telemetry to your local OTel-jps stack.

## When to use it

- You want to **see what real microservice traces look like** in OTel-jps.
- You want **screenshots / blog content / talk demos** with realistic data.
- You're **evaluating** OTel-jps before deploying for real workloads.

## When NOT to use it

- On a 4 GB single VPS — the demo needs ~4-6 GB extra RAM.
- In production — these are demo apps, not your apps.

## Run it

```bash
docker compose \
  -f docker-compose.yml \
  -f compose/simple.yml \
  -f compose/otel-demo.yml \
  up -d
```

Then open Grafana at `https://localhost/`. Within 1-2 minutes you'll see:
- **Stack Health** dashboard: increasing trace/metric ingestion rates
- **Traces Browser**: a service graph showing demo.frontend → demo.cart → demo.checkout → demo.payment
- **Logs Explorer**: structured logs from each demo service
- **Container Metrics**: per-container resource usage for the demo apps

The demo's frontend is browsable at <http://localhost:8082/>.

## Stop it

```bash
docker compose \
  -f docker-compose.yml \
  -f compose/simple.yml \
  -f compose/otel-demo.yml \
  down
```

## Caveats

- Demo images are pinned to OTel Demo `1.12.0`. Bump deliberately when
  upstream releases — the env-var contract has changed in past major releases.
- Demo's bundled Prometheus / Grafana / Jaeger are NOT used; we route their
  telemetry to our own stack.
- Some demo services (currency, accounting, fraud-detection, ad, kafka, etc.)
  are intentionally NOT included to keep RAM under 6 GB. The included subset
  still produces a credible service graph and load.
```

- [ ] **Step 4: Validate**

```bash
docker compose -f docker-compose.yml -f compose/simple.yml -f compose/otel-demo.yml config --quiet 2>&1 | grep -v BASIC_AUTH_HASH | tail -3
```

Expected: validates without error.

- [ ] **Step 5: Commit (do NOT bring up the demo as part of v1 acceptance — it's opt-in)**

```bash
git add compose/otel-demo.yml demo/
git commit -m "feat: add opt-in OTel demo overlay (Astronomy Shop curated subset)"
```

---

## Task 10: End-to-end Phase 2 verification + tag

- [ ] **Step 1: Restart the full Simple stack so all changes are loaded**

```bash
make stop
make simple
sleep 30
make verify
```

Expected: `verify_stack.sh` exits 0.

- [ ] **Step 2: Verify each dashboard is reachable in Grafana**

Create `/tmp/probe-dashboards.sh`:

```bash
#!/bin/bash
B64="YWRtaW46YWRtaW4xMjM="  # admin:admin123 base64. Adjust if your password differs.
PASS=0
FAIL=0
for uid in otel-jps-stack-health otel-jps-container-metrics otel-jps-logs-explorer otel-jps-traces-browser; do
  if docker exec otel-jps-caddy w''get -qO- --header="Authorization: Basic $B64" "http://grafana:3000/api/dashboards/uid/$uid" | grep -q '"uid":"'$uid'"'; then
    echo "PASS $uid"
    PASS=$((PASS+1))
  else
    echo "FAIL $uid"
    FAIL=$((FAIL+1))
  fi
done
echo "── $PASS dashboards loaded, $FAIL missing ──"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

Run: `chmod +x /tmp/probe-dashboards.sh && /tmp/probe-dashboards.sh`

- [ ] **Step 3: Verify cAdvisor metrics arriving in Prometheus**

Create `/tmp/probe-cadvisor-metrics.sh`:

```bash
#!/bin/bash
docker exec otel-jps-caddy w''get -qO- 'http://prometheus:9090/api/v1/query?query=container_memory_usage_bytes{name="otel-jps-grafana"}' | grep -q '"value"' && echo PASS || echo FAIL
```

Run: `chmod +x /tmp/probe-cadvisor-metrics.sh && /tmp/probe-cadvisor-metrics.sh`

- [ ] **Step 4: Verify alert rules loaded**

Create `/tmp/probe-alerts.sh`:

```bash
#!/bin/bash
COUNT=$(docker exec otel-jps-caddy w''get -qO- 'http://prometheus:9090/api/v1/rules' | grep -o '"name":"' | wc -l)
echo "Alerts loaded: $COUNT (expected ≥12)"
[[ $COUNT -ge 12 ]] && exit 0 || exit 1
```

Run: `chmod +x /tmp/probe-alerts.sh && /tmp/probe-alerts.sh`

- [ ] **Step 5: Memory budget check**

```bash
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' | grep otel-jps
```

Expected: total ≤ ~500 MiB (Phase 1 was 253 MiB; cAdvisor adds ~50 MiB; provisioned dashboards/alerts add ~10 MiB to Grafana/Prometheus).

- [ ] **Step 6: Tag**

```bash
git tag -a v1.0.0-alpha.2 -m "Phase 2 complete: 4 dashboards, 12 alerts, cAdvisor, OTel demo overlay"
git tag --list 'v1*'
```

---

## Phase 2 Acceptance Criteria

- [ ] All Phase 1 acceptance criteria still met (`make verify` passes)
- [ ] cAdvisor running and scraped by Prometheus
- [ ] All 4 dashboards (`stack-health`, `container-metrics`, `logs-explorer`, `traces-browser`) loaded in Grafana
- [ ] ≥12 default alert rules loaded by Prometheus
- [ ] Grafana alerting contact point and notification policy provisioned
- [ ] OTel demo overlay validates (`docker compose ... -f compose/otel-demo.yml config --quiet` exits 0) — actual demo run is optional
- [ ] No legacy `(unhealthy)` cosmetic flags in `docker compose ps`
- [ ] Total stack idle RAM ≤ 500 MiB (Phase 1 + cAdvisor + provisioning overhead)
- [ ] Tagged `v1.0.0-alpha.2`

---

## Notes & Gotchas

- **Dashboard JSON** uses Grafana schema 39 (Grafana 11.x). If a future Grafana upgrade requires schema bumps, the dashboards may need re-export.
- **VictoriaLogs queries** use `*` (match all). When the OTel demo runs, more meaningful queries can be added (e.g. `_stream:demo.checkout`).
- **Tempo `metrics_generator`** writes span metrics into Prometheus — that's why the Traces Browser heatmap queries Prometheus for `traces_spanmetrics_latency_bucket`.
- **Alert webhook** defaults to `example.invalid` — alerts fire but go nowhere unless `ALERT_WEBHOOK_URL` is set in `.env`.
- **OTel demo image tags** are pinned to `1.12.0`; bump deliberately. The demo's env-var contract changes between major versions.
