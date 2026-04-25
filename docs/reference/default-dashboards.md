# Default dashboards

> Source of truth: [`configs/grafana/dashboards/`](https://github.com/HameemDakheel/OTel-jps/tree/main/configs/grafana/dashboards)

Four dashboards ship with OTel-jps and are auto-provisioned into Grafana's "OTel-jps" folder on first launch.

---

## Dashboards

| Dashboard | UID | Datasources | What it shows |
|-----------|-----|-------------|---------------|
| **Stack Health** | `otel-jps-stack-health` | Prometheus | Per-component up/down state, OTLP ingestion rate (traces/metrics/logs), per-component memory, Prometheus head series, Tempo blocks flushed |
| **Container Metrics** | `otel-jps-container-metrics` | Prometheus (cAdvisor) | CPU usage by container, memory usage by container, network RX/TX |
| **Logs Explorer** | `otel-jps-logs-explorer` | VictoriaLogs | Recent logs (live tail), total log volume |
| **Traces Browser** | `otel-jps-traces-browser` | Tempo + Prometheus | Service graph (from Tempo `metrics_generator`), span duration heatmap |

---

## Adding your own dashboards

Drop a Grafana JSON dashboard file into `configs/grafana/dashboards/` (no subfolders required). Grafana picks it up via the provisioning loop (refreshes every 30 s). The dashboard appears in the "OTel-jps" folder automatically.

To export an existing dashboard from Grafana for version control:
1. Open the dashboard.
2. Click the share icon → "Export" → "Save to file" (toggle "Export for sharing externally" off if you want to keep references to your specific datasource UIDs).
3. Save to `configs/grafana/dashboards/<name>.json`.
4. Commit and push.

After committing, the dashboard is preserved across `make clean` (the JSON lives in git, not in `grafana_data` volume).

---

## Dashboard provisioning config

[`configs/grafana/provisioning/dashboards/dashboards.yaml`](https://github.com/HameemDakheel/OTel-jps/blob/main/configs/grafana/provisioning/dashboards/dashboards.yaml) tells Grafana to load every JSON in the dashboards directory into the "OTel-jps" folder. Key settings:

```yaml
apiVersion: 1
providers:
  - name: 'OTel-jps default dashboards'
    orgId: 1
    folder: 'OTel-jps'                     # destination folder in Grafana UI
    type: file
    disableDeletion: false                  # users can delete via UI; provisioning recreates on restart
    editable: true                          # users can save edits in Grafana
    updateIntervalSeconds: 30               # how often to scan for changes
    options:
      path: /etc/grafana/dashboards
      foldersFromFilesStructure: false      # MUST be false; true overrides the `folder:` field above
```

The `foldersFromFilesStructure: false` setting is critical — see [ADR 0006](../decisions/0006-self-monitoring-not-seeder.md) for context.

---

## Datasource UIDs (used in dashboard JSON)

| Datasource | UID (referenced in panels) | Type |
|------------|----------------------------|------|
| Prometheus | `prometheus` | `prometheus` |
| VictoriaLogs | `victorialogs` | `victoriametrics-logs-datasource` |
| Tempo | `tempo` | `tempo` |
| Pyroscope | `pyroscope` | `grafana-pyroscope-datasource` |

When writing custom dashboards, use these UIDs in panel `datasource` fields so they resolve correctly across fresh installs.

---

## See also

- [`configs/grafana/dashboards/`](https://github.com/HameemDakheel/OTel-jps/tree/main/configs/grafana/dashboards) — the JSON files
- [Default alerts](default-alerts.md)
- [Architecture](../architecture.md)
