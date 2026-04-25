# OTel-jps Redesign — Implementation Plan Index

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement each phase plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the OTel-jps v1 redesign per the approved spec, in five sequenced phases that each produce a working, releasable increment.

**Architecture:** One product, multiple profiles (Simple at v1; Standard/Scale/Enterprise as placeholders). Stack: Prometheus + VictoriaLogs + Tempo + Pyroscope + Grafana + OpenTelemetry Collector contrib + Caddy + filesystem storage. Docker-compose with overlay files for profile selection. Documentation as SSOT under `docs/`.

**Tech Stack:** Docker, Docker Compose, Prometheus, VictoriaLogs, Grafana Tempo, Pyroscope, Grafana, OpenTelemetry Collector contrib, Caddy, MkDocs Material, GitHub Actions, Bash, Make.

**Spec reference:** [docs/superpowers/specs/2026-04-25-otel-jps-redesign.md](../specs/2026-04-25-otel-jps-redesign.md)

---

## Phase Overview

Each phase is a separate plan file. Execute phases in order — each builds on the previous one's artifacts.

| # | Phase | Plan file | What it produces | Done when |
|---|-------|-----------|------------------|-----------|
| 1 | **Core Stack** | `2026-04-25-phase-1-core-stack.md` | A docker-compose stack that boots, accepts OTLP, and serves Grafana with all 4 datasources connected | `make simple && ./scripts/verify_stack.sh` exits 0 on a clean Ubuntu 24.04 VPS with 4 GB RAM; idle ≤ 2.2 GB |
| 2 | **Stack Polish** | `2026-04-25-phase-2-stack-polish.md` *(to be written before Phase 2 starts)* | Self-monitoring across all components, 4 default dashboards, 12+ pre-tuned alerts, OTel demo overlay | Grafana opens with populated dashboards in 30 s; alerts fire on simulated failures; demo overlay runs |
| 3 | **Documentation** | `2026-04-25-phase-3-documentation.md` *(to be written before Phase 3 starts)* | MkDocs Material site, README rewrite, quickstart, architecture, profiles docs, 6 ADRs, instrumentation guides for 5 languages | `mkdocs serve` works locally; GitHub Pages deploys; all internal links resolve |
| 4 | **PaaS Templates** | `2026-04-25-phase-4-paas-templates.md` *(to be written before Phase 4 starts)* | Coolify/Dokploy/Jelastic/CapRover templates + 4 deployment guides | Each template installs a working stack on its target PaaS |
| 5 | **CI/CD + Launch** | `2026-04-25-phase-5-cicd-launch.md` *(to be written before Phase 5 starts)* | GitHub Actions validate.yml + deploy.yml, Makefile, CHANGELOG, README polish, tag v1.0.0 | All v1 acceptance criteria from spec §8.1 met; release tagged |

---

## Phase Dependencies

```
Phase 1 (Core Stack)
   ↓
   ├── Phase 2 (Stack Polish) ──┐
   ├── Phase 3 (Documentation) ─┤
   ├── Phase 4 (PaaS Templates) ┤
   │                            ↓
   └─────────────────────────── Phase 5 (CI/CD + Launch)
```

Phases 2, 3, and 4 can be worked in parallel after Phase 1 ships, but Phase 5 requires all four to be complete.

---

## Cross-Cutting Conventions (apply to all phases)

### Commit message format
Per global git workflow: `<type>: <description>` where type is one of `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`. One commit = one logical change. No `--no-verify`. No skipping signing.

### File organization
- Configs grouped by component under `configs/<component>/`
- Compose overlays under `compose/`
- All docs under `docs/`
- Scripts under `scripts/`
- ADRs follow canonical Context → Decision → Consequences format

### Validation tools used in plans
- `docker compose config --quiet` — validates compose files
- `python3 -c "import yaml; yaml.safe_load(open('<file>'))"` — validates YAML configs
- `caddy validate --config <file> --adapter caddyfile` — validates Caddyfile
- `otelcol-contrib validate --config=<file>` — validates OTel Collector config (run inside container)
- Component health endpoints: `/ready`, `/-/ready`, `/-/healthy`
- `./scripts/verify_stack.sh` — end-to-end smoke test

### TDD adapted for infrastructure
Traditional unit tests do not exist for most config files. The "RED → GREEN" pattern in this plan adapts as:
- **RED**: run a validation step that fails because the config file/service does not exist
- **GREEN**: write the minimal config, validation passes
- **Refactor**: tune the config (e.g., set retention, add alerts) and re-validate
- **Commit**: stage and commit the change

### Ground rules from spec
- v1 ships **Simple profile only** — Standard/Scale/Enterprise compose overlays remain stubs
- v1 does **not** include MinIO, Helm chart, custom UI, Datadog importer, or telemetry that isn't opt-in
- All commits made via local edit → local commit → push (no SSH-edit on remote per global rules)
- Auto-TLS via Caddy; basic auth on OTLP ingestion endpoints; Grafana login on UI

---

## How to Run

The user (or an agent assigned to this plan) executes phases in order. After Phase 1 ships, the writing-plans skill should be invoked again to produce the full Phase 2 plan; same for Phases 3, 4, 5. Each phase plan is meant to be self-contained and bite-sized once written.

To start now: open `2026-04-25-phase-1-core-stack.md` and follow the tasks in order.
