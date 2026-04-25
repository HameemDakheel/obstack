# Changelog

All notable changes to OTel-jps are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Real screenshots in README and docs (manual capture post-launch)
- First push of `v1.0.0` tag to origin
- Submission of OTel-jps templates to Coolify Templates / Dokploy Templates / CapRover One-Click Apps registries

---

## [v1.0.0] — 2026-04-25

The first production release. Combines the work from all alpha milestones (`alpha.1` through `alpha.4`) plus CI/CD and launch readiness from Phase 5.

### Added
- `LICENSE` file (MIT).
- `.github/workflows/validate.yml` — CI on every push: validates YAML/JSON configs, docker-compose merges, Caddyfile, OTel Collector config, Prometheus alert rules, bash scripts, MkDocs strict build, and shellcheck.
- `.github/workflows/deploy-docs.yml` — CD that builds the MkDocs site and deploys to GitHub Pages on push to `main` when `docs/` or `mkdocs.yml` change.
- `CHANGELOG.md` (this file).
- `launch/` directory with launch announcement drafts (Show HN, r/selfhosted, Twitter).
- `assets/screenshots/README.md` — capture instructions for the 4 dashboards plus terminal output.

### Changed
- README polish — acknowledgements section, status badge, version badge bumped to `v1.0.0`.

### Removed
- Legacy `.github/workflows/deploy.yml` (LGTM-stack era; references defunct components).

---

## [v1.0.0-alpha.4] — 2026-04-25

**Phase 4: PaaS templates and deployment guides.**

### Added
- `templates/coolify/` — Coolify-tuned compose, template metadata JSON, README.
- `templates/dokploy/` — Dokploy template with `${randomPassword}` and `${input}` env-var prompting, compose, README.
- `templates/caprover/` — Multi-service One-Click App YAML (8 separate CapRover apps), captain-definition stub, README.
- `docs/deployment/coolify.md` — Coolify deployment guide.
- `docs/deployment/dokploy.md` — Dokploy deployment guide.
- `docs/deployment/caprover.md` — CapRover deployment guide (most complex due to multi-app pattern).
- `docs/deployment/jelastic.md` — Jelastic deployment guide.
- `mkdocs.yml` — Coolify, Dokploy, CapRover, Jelastic added to deployment nav.

### Changed
- `templates/jelastic/manifest.jps` — completely rewritten for the new hybrid stack. Removed all MinIO/Mimir/Loki/Alloy references. Now delegates installation to `make simple` and verification to `./scripts/verify_stack.sh`.
- `templates/jelastic/linker.jps` — updated to inject OTLP env vars pointing at the Caddy-fronted public domain with HTTP Basic auth headers (instead of the old direct-to-Alloy port 4317 path).

---

## [v1.0.0-alpha.3] — 2026-04-25

**Phase 3: Documentation site, ADRs, instrumentation guides, runbooks.**

### Added
- 6 ADRs in `docs/decisions/` — hybrid stack, OTel Collector vs Alloy, Caddy vs Nginx, no MinIO at Simple, Prometheus vs Mimir at Simple, self-monitoring vs synthetic seeder.
- Foundation docs: `docs/quickstart.md`, `docs/architecture.md`, `docs/profiles.md`.
- 5 instrumentation guides under `docs/instrumentation/`: Node.js, Python, Go, Java, Ruby.
- Operations docs: `docs/operations/backup-restore.md`, `upgrade.md`, `troubleshooting.md`.
- 4 incident runbooks: `disk-full.md`, `service-down.md`, `cert-renewal.md`, `high-cardinality.md`.
- 5 reference docs in `docs/reference/`: `env-vars.md`, `ports.md`, `volumes.md`, `default-alerts.md`, `default-dashboards.md`.
- `docs/deployment/docker-compose.md` — canonical "fresh VPS" install guide.
- `docs/README.md` — documentation site index.
- `mkdocs.yml` — MkDocs Material site configuration.

### Changed
- `README.md` — fully rewritten with the wedge pitch, comparison table vs SigNoz/OpenObserve/LGTM-DIY/Datadog, and links into the new docs tree.

---

## [v1.0.0-alpha.2] — 2026-04-25

**Phase 2: Stack polish — dashboards, alerts, demo, observability.**

### Added
- `cadvisor` service — per-container CPU/RAM/network metrics, scraped by Prometheus.
- 4 default Grafana dashboards in `configs/grafana/dashboards/`: Stack Health, Container Metrics, Logs Explorer, Traces Browser. Auto-provisioned into the "OTel-jps" folder.
- 12 default Prometheus alert rules in `alerts/default-rules.yaml` covering service down, high error rate, cardinality explosion, disk usage, and more.
- Grafana alerting provisioning: contact point + notification policy (`configs/grafana/provisioning/alerting/`).
- `compose/otel-demo.yml` — opt-in OTel demo overlay (curated 7-service Astronomy Shop subset) for evaluation and screenshots.
- `demo/README.md` — instructions for running the OTel demo overlay.
- Makefile shortcuts: `make demo`, `make demo-stop`, `make demo-logs`.
- `ALERT_WEBHOOK_URL` env var (configurable Slack/Discord/PagerDuty webhook).

### Changed
- `Makefile`: `make simple` now prints the Grafana URL hint after starting.
- `configs/grafana/provisioning/dashboards/dashboards.yaml`: `foldersFromFilesStructure` set to `false` so the named "OTel-jps" folder takes effect (was previously `true`, which silently overrode the named folder).

### Fixed
- Removed misleading `wget` healthchecks for distroless containers (Caddy, OTel Collector, VictoriaLogs, Pyroscope) — they showed `(unhealthy)` in `docker compose ps` even when services were working. Healthcheck-as-truth replaced by `verify_stack.sh` probing through the Caddy container.
- Grafana provisioning files now use `$VAR` (plain) instead of `${VAR:-default}` (Bash-style) — the latter was silently breaking provisioning under strict validation.

---

## [v1.0.0-alpha.1] — 2026-04-25

**Phase 1: Replace the legacy LGTM+MinIO prototype with the hybrid stack.**

### Added
- New `docker-compose.yml` declaring the 7-component stack: Caddy, OTel Collector contrib, Prometheus, VictoriaLogs, Tempo, Pyroscope, Grafana.
- `compose/simple.yml` — Simple-profile overlay with resource limits.
- `compose/standard.yml`, `compose/scale.yml` — placeholder stubs for future profiles.
- `configs/caddy/Caddyfile` — TLS, basic auth on `/v1/*`, reverse proxy.
- `configs/otel-collector/config.yaml` — OTLP receivers, batch/memory-limit processors, fan-out to all 4 backends.
- `configs/prometheus/prometheus.yml` — self-scraping + remote-write receiver enabled.
- `configs/tempo/tempo.yaml` — monolithic mode, filesystem storage, metrics_generator with span-graphs.
- `configs/pyroscope/pyroscope.yaml` — filesystem storage.
- `configs/grafana/provisioning/datasources/all.yaml` — 4 datasources auto-provisioned with logs↔traces↔profiles correlations.
- `configs/grafana/provisioning/dashboards/dashboards.yaml` — auto-load JSON dashboards from `configs/grafana/dashboards/`.
- `scripts/verify_stack.sh` — parameterized health check probing all 7 components.
- `Makefile` with shortcuts: `simple`, `stop`, `restart`, `logs`, `verify`, `update`, `config`, `clean`.
- `templates/jelastic/manifest.jps` and `linker.jps` (relocated from repo root + `addons/`).

### Changed
- `.env.example` — variables renamed for the new stack: `BASIC_AUTH_HASH`, `GRAFANA_ADMIN_PASSWORD`, retention overrides per-backend.
- `.gitignore` — refreshed to cover `volumes/`, `.cache/`, common editor temps.

### Removed
- `INTEGRATION.md` (folded into `docs/instrumentation/` in Phase 3).
- `logs.txt` (1 MB debug artifact).
- `scripts/init_buckets.sh` (no MinIO at Simple profile).
- The original `nginx/`, `configs/alloy/`, `configs/mimir.yaml`, `configs/loki.yaml` from the LGTM-era prototype.

### Fixed
- Tempo: added `-config.expand-env=true` flag so `${TEMPO_RETENTION_HOURS}` actually expands in the YAML.
- Pyroscope: removed `limits.retention_period` field (deprecated/moved in Pyroscope 1.10).
- Grafana: removed `grafana-pyroscope-datasource` from `GF_INSTALL_PLUGINS` — it's a core plugin in Grafana 11.x and can't be installed separately.
- Grafana datasource provisioning: removed legacy `datasources.yml` that was conflicting with the new `all.yaml` (caused "only one default datasource" errors).

---

## Versioning

OTel-jps follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html):
- **Major** version (`v2.0.0`) — breaking changes (e.g. config format change, removed component).
- **Minor** version (`v1.1.0`) — new features (e.g. new profile, new dashboard, new alert).
- **Patch** version (`v1.0.1`) — bug fixes.

Pre-release versions (`v1.0.0-alpha.N`) are used during phased development. Once `v1.0.0` ships, alphas end.

[Unreleased]: https://github.com/HameemDakheel/OTel-jps/compare/v1.0.0...HEAD
[v1.0.0]: https://github.com/HameemDakheel/OTel-jps/releases/tag/v1.0.0
[v1.0.0-alpha.4]: https://github.com/HameemDakheel/OTel-jps/releases/tag/v1.0.0-alpha.4
[v1.0.0-alpha.3]: https://github.com/HameemDakheel/OTel-jps/releases/tag/v1.0.0-alpha.3
[v1.0.0-alpha.2]: https://github.com/HameemDakheel/OTel-jps/releases/tag/v1.0.0-alpha.2
[v1.0.0-alpha.1]: https://github.com/HameemDakheel/OTel-jps/releases/tag/v1.0.0-alpha.1
