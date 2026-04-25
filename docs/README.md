# obstack Documentation

Welcome. obstack is production observability for your $20/month VPS — all 5 signals, one command.

If you got here from the repo root, the project [README](https://github.com/HameemDakheel/obstack#readme) has the elevator pitch and quick install. This page is the **docs index** — everything else.

---

## Get started

- **[Quickstart](quickstart.md)** — go from zero to populated dashboards in 5 minutes
- **[Architecture](architecture.md)** — what's inside the stack and how data flows through it
- **[Profiles](profiles.md)** — Simple / Standard / Scale / Enterprise (only Simple ships at v1)

---

## Browse by audience

### "I want to install it"

- [Quickstart](quickstart.md) — the 5-minute walkthrough
- [Deploy with Docker Compose](deployment/docker-compose.md) — full production install
- Instrumentation guides:
  - [Node.js](instrumentation/nodejs.md)
  - [Python](instrumentation/python.md)
  - [Go](instrumentation/go.md)
  - [Java](instrumentation/java.md)
  - [Ruby](instrumentation/ruby.md)

### "I want to operate it"

- [Backup & Restore](operations/backup-restore.md)
- [Upgrade](operations/upgrade.md)
- [Troubleshooting](operations/troubleshooting.md)
- Runbooks:
  - [Disk full](operations/runbooks/disk-full.md)
  - [Service down](operations/runbooks/service-down.md)
  - [Cert renewal](operations/runbooks/cert-renewal.md)
  - [High cardinality](operations/runbooks/high-cardinality.md)
- Reference:
  - [Environment variables](reference/env-vars.md)
  - [Ports](reference/ports.md)
  - [Volumes](reference/volumes.md)
  - [Default alerts](reference/default-alerts.md)
  - [Default dashboards](reference/default-dashboards.md)

### "I want to understand the design"

- [Architecture](architecture.md)
- [Profiles](profiles.md)
- Architecture Decision Records (ADRs):
  - [0001 — Hybrid stack (Prometheus + VictoriaLogs + Tempo + Pyroscope + Grafana)](decisions/0001-hybrid-stack.md)
  - [0002 — OTel Collector contrib over Grafana Alloy](decisions/0002-otel-collector-not-alloy.md)
  - [0003 — Caddy over Nginx](decisions/0003-caddy-not-nginx.md)
  - [0004 — No MinIO at Simple profile](decisions/0004-no-minio-for-simple.md)
  - [0005 — Prometheus over Mimir at Simple profile](decisions/0005-prometheus-not-mimir-for-simple.md)
  - [0006 — Self-monitoring over synthetic seeder](decisions/0006-self-monitoring-not-seeder.md)

---

## Demo

Want to see what the stack looks like with real microservice traces flowing through it? See the [Demo overlay](https://github.com/HameemDakheel/obstack/blob/main/demo/README.md). One command:

```bash
make demo
```

(Requires ~8 GB RAM total — use a bigger machine than your production target.)

---

## Contributing

obstack is MIT-licensed and accepts contributions. Common ways to help:

- File issues for bugs you hit
- Send PRs for documentation improvements (typos, clarifications, missing examples)
- Share your dashboards via PR (drop a JSON into `configs/grafana/dashboards/`)
- Suggest alert rules via PR (add to `alerts/`)

Repo: <https://github.com/HameemDakheel/obstack>

---

## What's next on the roadmap?

- **Phase 4** — PaaS one-click templates (Coolify, Dokploy, CapRover, Jelastic) + per-PaaS deployment guides.
- **Phase 5** — CI/CD pipeline, polished README, screenshots, `v1.0.0` release.

See the [Phase index](superpowers/plans/2026-04-25-obstack-redesign-INDEX.md) for the full plan.
