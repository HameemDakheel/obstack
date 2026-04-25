# Runbook: High cardinality

**Severity:** warning → critical (Prometheus OOM)
**Likely alert:** `PrometheusHighCardinality` (head series >1M)
**Time to remediate:** ~15–30 minutes

"Cardinality" = the number of unique label-value combinations Prometheus tracks. **Every unique combination is a distinct time series.** A single noisy label (e.g. user ID, request ID, full URL path) can multiply cardinality by 1000× and OOM Prometheus.

## Symptoms

- `PrometheusHighCardinality` alert fires (head series >1M).
- Prometheus container memory steadily climbs, then OOMs and restarts.
- Queries get slow or time out.
- `/metrics` endpoints from your apps look enormous (MB-scale instead of KB-scale).

## Root causes

- An app emits a metric with a high-cardinality label (user ID, trace ID, full URL with query string, customer ID).
- Auto-instrumentation captured a label that's fine for traces but explosive in metrics (HTTP path with IDs in it, e.g. `/users/12345/posts/67890`).
- A misconfigured client emits a unique `instance` label per request.

## Triage

```bash
# How many head series?
docker exec otel-jps-caddy wget -qO- 'http://prometheus:9090/api/v1/query?query=prometheus_tsdb_head_series' \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print('series:', d['data']['result'][0]['value'][1] if d['data']['result'] else 'none')"

# Which metric names have the most series?
docker exec otel-jps-caddy wget -qO- 'http://prometheus:9090/api/v1/query?query=topk(10,count(count(group by(__name__){__name__!=""})by(__name__)))' \
  | python3 -m json.tool | head -50

# Which labels on a specific metric?
docker exec otel-jps-caddy wget -qO- 'http://prometheus:9090/api/v1/query?query=count(group by(<offending_label>) (<metric_name>))'
```

The Prometheus UI has a built-in cardinality explorer at `/api/v1/status/tsdb` (also via Grafana → Explore → datasource:Prometheus → Status menu).

## Remediate

### Step 1 — Identify the noisy label

From the triage queries, find the metric with the most series. Then find which label is exploding:

```promql
topk(10, count(group by(<label_name>)(<metric_name>)))
```

Try each label name on the offending metric. The one returning the largest number is the culprit.

### Step 2 — Drop the noisy label at the OTel Collector

Edit `configs/otel-collector/config.yaml`. Add or extend a `transform` processor:

```yaml
processors:
  transform/drop-noisy-labels:
    metric_statements:
      - context: datapoint
        statements:
          - delete_key(attributes, "user.id")
          - delete_key(attributes, "request.id")
          - replace_pattern(attributes["http.target"], "/[0-9]+", "/{id}")  # collapse IDs in paths
```

Add it to the `metrics` pipeline:

```yaml
service:
  pipelines:
    metrics:
      receivers: [otlp, prometheus/self]
      processors: [memory_limiter, resourcedetection, transform/drop-noisy-labels, batch]
      exporters: [prometheusremotewrite]
```

Reload:

```bash
docker compose -f docker-compose.yml -f compose/simple.yml restart otel-collector
```

This affects only **new** metrics; existing series remain in Prometheus until retention rolls them off (default 7 days).

### Step 3 — Force-clear existing series (optional, aggressive)

If you can't wait for retention to drop the old series, restart Prometheus with a fresh TSDB:

```bash
docker compose -f docker-compose.yml -f compose/simple.yml stop prometheus
docker volume rm otel-jps_prometheus_data
docker compose -f docker-compose.yml -f compose/simple.yml up -d prometheus
```

**You lose all historical metrics.** Only do this if the cardinality explosion is severe enough to OOM the container repeatedly.

### Step 4 — Update your app

The OTel Collector workaround is a stopgap. Long-term: stop emitting the noisy label at the source.

- For HTTP path labels, normalize at the SDK layer (replace path params with `:id` placeholders).
- For user/request IDs, push them into trace attributes (Tempo) and structured logs (VictoriaLogs), **not** metric labels.
- Document this in your team's instrumentation guidelines.

## Verify recovery

```bash
docker exec otel-jps-caddy wget -qO- 'http://prometheus:9090/api/v1/query?query=prometheus_tsdb_head_series'
```

After the OTel Collector workaround takes effect plus the retention window, head series should drop and stay below 1M.

## Prevention

- **Default rule for new instrumentation: every label must have low cardinality** (think dozens to hundreds, not thousands or millions).
- Use traces (Tempo) and logs (VictoriaLogs) for high-cardinality data — that's their job.
- Set up `PrometheusHighCardinality` alert with a tighter threshold for early warning (e.g. 500K) once you understand your steady-state series count.
- For Scale profile: VictoriaMetrics handles cardinality much better than Prometheus, and Mimir adds tenant-level limits. Worth the upgrade if cardinality is a recurring fight.

## See also

- [OpenTelemetry Collector `transform` processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor)
- [Prometheus cardinality docs](https://prometheus.io/docs/practices/naming/#labels)
- [Troubleshooting](../troubleshooting.md)
- [Architecture / Profiles upgrade](../../profiles.md)
