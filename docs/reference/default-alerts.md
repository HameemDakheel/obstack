# Default alerts

> Source of truth: [`alerts/default-rules.yaml`](https://github.com/HameemDakheel/OTel-jps/blob/main/alerts/default-rules.yaml)

OTel-jps ships with 12 pre-tuned alerts covering the most common production failures. Loaded by Prometheus on startup and routed via Grafana Alerting to the configured webhook.

---

## Alerts

| Alert | Severity | Expression | Fires after | What it means | Runbook |
|-------|----------|-----------|------------|---------------|---------|
| `ServiceDown` | critical | `up == 0` | 2 m | A scrape target is unreachable | [service-down](../operations/runbooks/service-down.md) |
| `PrometheusTargetMissing` | critical | `absent(up{job="prometheus-self"})` | 5 m | Prometheus isn't scraping itself — meta-monitoring broken | [service-down](../operations/runbooks/service-down.md) |
| `HighIngestionDrop` | warning | `rate(otelcol_receiver_refused_spans_total[5m]) > 0` | 5 m | OTel Collector is refusing spans (backpressure, queue full) | [troubleshooting](../operations/troubleshooting.md) |
| `HighMemoryUsage` | warning | `container_memory / limit > 0.85` | 5 m | A container is approaching its memory limit | [service-down](../operations/runbooks/service-down.md) (if OOM follows) |
| `HighCPUUsage` | warning | `rate(container_cpu_seconds[5m]) > 0.9` | 10 m | A container is sustained at >90% of one core | — |
| `PrometheusHighCardinality` | warning | `prometheus_tsdb_head_series > 1000000` | 10 m | Cardinality explosion — Prometheus memory at risk | [high-cardinality](../operations/runbooks/high-cardinality.md) |
| `TempoIngestErrors` | warning | Tempo distributor can't reach ingesters | 10 m | Trace ingestion path broken | [troubleshooting](../operations/troubleshooting.md) |
| `GrafanaDown` | critical | `up{job="grafana"} == 0` | 2 m | UI is down — users have no access | [service-down](../operations/runbooks/service-down.md) |
| `OTelCollectorQueueFull` | warning | `otelcol_exporter_queue_size / capacity > 0.8` | 5 m | Collector exporter queue >80% full — drops imminent | [troubleshooting](../operations/troubleshooting.md) |
| `ContainerRestartLoop` | critical | `changes(container_start_time_seconds[10m]) > 3` | 0 m | Container has restarted >3× in 10 m | [service-down](../operations/runbooks/service-down.md) |
| `DiskUsageHigh` | warning | Root disk usage >80% | 10 m | Disk filling up | [disk-full](../operations/runbooks/disk-full.md) |
| `VictoriaLogsIngestSlowdown` | warning | Collector accepts logs but VictoriaLogs ingestion is zero | 5 m | Logs pipeline broken | [troubleshooting](../operations/troubleshooting.md) |

---

## Adding your own alerts

Drop a new YAML file into `alerts/` (any filename, valid Prometheus rule format). Prometheus will pick it up automatically — its `rule_files` glob is `/etc/prometheus/rules/*.yaml`.

After adding a file:

```bash
docker compose -f docker-compose.yml -f compose/simple.yml restart prometheus
```

Verify the new rule loaded:

```bash
docker exec otel-jps-caddy wget -qO- 'http://prometheus:9090/api/v1/rules' | grep -o '"name":"<your_alert>"'
```

---

## Routing & notifications

Default routing in [`configs/grafana/provisioning/alerting/notification-policies.yaml`](https://github.com/HameemDakheel/OTel-jps/blob/main/configs/grafana/provisioning/alerting/notification-policies.yaml):

- `severity = info` → blackhole receiver (silently dropped)
- everything else → `default-webhook` (configurable via `ALERT_WEBHOOK_URL` env var)

Group settings:
- `group_by: [alertname, severity]`
- `group_wait: 30s`
- `group_interval: 5m`
- `repeat_interval: 4h`

---

## See also

- [`alerts/default-rules.yaml`](https://github.com/HameemDakheel/OTel-jps/blob/main/alerts/default-rules.yaml)
- [Default dashboards](default-dashboards.md)
- [Operations / Troubleshooting](../operations/troubleshooting.md)
