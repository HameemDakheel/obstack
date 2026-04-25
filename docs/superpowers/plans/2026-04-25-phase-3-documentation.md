# Phase 3 — Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a complete `docs/` documentation tree (~30 files), an MkDocs Material site, 6 ADRs, 5 instrumentation guides, operations runbooks, reference docs, and a rewritten README that opens with the wedge pitch.

**Architecture:** All docs live under `docs/`. The MkDocs Material site builds from `docs/` with a `mkdocs.yml` at the repo root. Markdown is the format; no JS toolchain. Internal cross-doc links use relative paths so both GitHub and the rendered site resolve correctly. ADRs follow Context → Decision → Consequences. Each doc has a "What you'll need" + "Time to complete" header.

**Tech Stack:** MkDocs Material (Python), Markdown, GitHub Pages (deploy in Phase 5).

**Spec reference:** [docs/superpowers/specs/2026-04-25-otel-jps-redesign.md](../specs/2026-04-25-otel-jps-redesign.md) §7
**Predecessor:** Phase 2 — `v1.0.0-alpha.2` must be tagged before starting.

---

## File Structure (Phase 3 deliverables)

```
otel-jps/
├── README.md                          # ← REWRITTEN: hero pitch + screenshots + comparison
├── mkdocs.yml                         # NEW: MkDocs Material config
├── docs/
│   ├── README.md                      # NEW: docs index (links to everything)
│   ├── quickstart.md                  # NEW: 5-minute install guide
│   ├── architecture.md                # NEW: system overview, components, data flow
│   ├── profiles.md                    # NEW: Simple/Standard/Scale/Enterprise
│   │
│   ├── deployment/
│   │   └── docker-compose.md          # NEW: plain Docker deploy guide (PaaS guides → Phase 4)
│   │
│   ├── instrumentation/
│   │   ├── nodejs.md
│   │   ├── python.md
│   │   ├── go.md
│   │   ├── java.md
│   │   └── ruby.md
│   │
│   ├── operations/
│   │   ├── backup-restore.md
│   │   ├── upgrade.md
│   │   ├── troubleshooting.md
│   │   └── runbooks/
│   │       ├── disk-full.md
│   │       ├── service-down.md
│   │       ├── cert-renewal.md
│   │       └── high-cardinality.md
│   │
│   ├── reference/
│   │   ├── env-vars.md
│   │   ├── ports.md
│   │   ├── volumes.md
│   │   ├── default-alerts.md
│   │   └── default-dashboards.md
│   │
│   └── decisions/                     # ADRs
│       ├── 0001-hybrid-stack.md
│       ├── 0002-otel-collector-not-alloy.md
│       ├── 0003-caddy-not-nginx.md
│       ├── 0004-no-minio-for-simple.md
│       ├── 0005-prometheus-not-mimir-for-simple.md
│       └── 0006-self-monitoring-not-seeder.md
```

**Total:** ~30 markdown files + `mkdocs.yml`. PaaS-specific deployment guides (`coolify.md`, `dokploy.md`, etc.) intentionally deferred to Phase 4 since they depend on the templates created there.

---

## Task 1: ADRs (Architecture Decision Records)

ADRs go first because they're short, anchoring (future contributors and reviewers will reference them), and the rest of the docs link into them. Each ADR follows: **Context → Decision → Consequences → References**.

**Files:**
- Create: `docs/decisions/0001-hybrid-stack.md`
- Create: `docs/decisions/0002-otel-collector-not-alloy.md`
- Create: `docs/decisions/0003-caddy-not-nginx.md`
- Create: `docs/decisions/0004-no-minio-for-simple.md`
- Create: `docs/decisions/0005-prometheus-not-mimir-for-simple.md`
- Create: `docs/decisions/0006-self-monitoring-not-seeder.md`

Each ADR is ~50–80 lines. Content during execution:
- **0001 Hybrid stack** — Context: LGTM is RAM-hostile on 4 GB. Decision: Prom + VictoriaLogs + Tempo + Pyroscope + Grafana. Consequences: lose pure LGTM brand; gain ~3× lower idle RAM. References: research benchmarks.
- **0002 OTel Collector vs Alloy** — Decision: upstream `otelcol-contrib`. Consequence: copy-paste from official docs works.
- **0003 Caddy vs Nginx** — Decision: Caddy. Consequence: auto-TLS in 3-line config.
- **0004 No MinIO at Simple** — Decision: filesystem storage. Consequence: saves ~1 GB; reintroduce at Scale.
- **0005 Prometheus vs Mimir at Simple** — Decision: Prometheus. Consequence: brand recognition; clean upgrade via remote_write.
- **0006 Self-monitoring vs synthetic seeder** — Decision: stack monitors itself. Consequence: real data day 1, zero extra components.

- [ ] **Step 1: Create the directory**

```bash
mkdir -p docs/decisions
```

- [ ] **Step 2: Write each ADR using the canonical template**

Template (used by every ADR):

```markdown
# ADR 000N: <Title>

**Status:** Accepted
**Date:** 2026-04-25

## Context

<2-4 paragraphs describing the situation, constraints, and what was at stake.>

## Decision

<1 paragraph stating the choice clearly.>

## Consequences

<Bulleted list of positive, negative, and neutral consequences.>

## References

<Bullets: external links, related ADRs, spec sections.>
```

Write all 6 ADRs in this format. Each captures the WHY for a Phase 1/2 decision.

- [ ] **Step 3: Validate each markdown parses (no broken frontmatter, lists, etc.)**

```bash
for f in docs/decisions/*.md; do python3 -c "with open('$f') as fp: assert fp.read().count('## Decision') == 1, '$f missing Decision section'" || exit 1; done && echo "all 6 ADRs valid"
```

- [ ] **Step 4: Commit**

```bash
git add docs/decisions/
git commit -m "docs: add 6 ADRs for Phase 1/2 architectural decisions"
```

---

## Task 2: Foundation docs — quickstart, architecture, profiles

The three docs every new user reads first.

**Files:**
- Create: `docs/quickstart.md`
- Create: `docs/architecture.md`
- Create: `docs/profiles.md`

### `docs/quickstart.md` — 5-minute install
Sections (in order):
1. **What you'll need** (Docker 24+, 4 GB RAM, optional domain)
2. **Time to complete** (~5 minutes)
3. **Step 1 — Clone and configure** (`git clone`, `cp .env.example .env`)
4. **Step 2 — Set basic auth hash** (one-liner using Caddy)
5. **Step 3 — Start the stack** (`make simple`)
6. **Step 4 — Verify** (`make verify`)
7. **Step 5 — Open Grafana** (login, look at dashboards)
8. **What to do next** (link to instrumentation guides, profiles doc)
9. **Troubleshooting** (link to runbooks)

### `docs/architecture.md` — system overview
Sections:
1. **At a glance** (1 paragraph)
2. **Component diagram** (ASCII art of data flow)
3. **Components** (table — what each does, why it was chosen, link to ADR)
4. **Signal flow** (per-signal: how a trace/log/metric travels app → Grafana)
5. **Storage** (filesystem at Simple; mention upgrade path)
6. **Authentication** (Caddy basic auth on ingestion; Grafana login on UI)
7. **Self-monitoring** (the stack scrapes itself)
8. **Resource budget** (Phase 1 measurements: ~311 MB idle)

### `docs/profiles.md` — Simple/Standard/Scale/Enterprise
Sections:
1. **Why profiles?** (1 paragraph)
2. **Comparison table** (RAM target, retention, HA, auth, status)
3. **How profiles work mechanically** (compose overlays, Makefile shortcuts)
4. **Choosing a profile**
5. **Upgrading between profiles** (data migration notes, deferred to v1.x)

- [ ] **Step 1: Write `docs/quickstart.md` (300–400 lines)**
- [ ] **Step 2: Write `docs/architecture.md` (300–400 lines)**
- [ ] **Step 3: Write `docs/profiles.md` (200–300 lines)**

- [ ] **Step 4: Validate** (each file ≥ 50 lines, has at least 3 H2 sections)

```bash
for f in docs/quickstart.md docs/architecture.md docs/profiles.md; do
  lines=$(wc -l < "$f"); h2=$(grep -c "^## " "$f")
  echo "$f: $lines lines, $h2 H2 sections"
  [[ $lines -ge 50 && $h2 -ge 3 ]] || { echo FAIL; exit 1; }
done
```

- [ ] **Step 5: Commit**

```bash
git add docs/quickstart.md docs/architecture.md docs/profiles.md
git commit -m "docs: add foundation docs (quickstart, architecture, profiles)"
```

---

## Task 3: Instrumentation guides (5 languages)

Each guide is ~150 lines: install SDK, set OTLP endpoint, send a test trace/metric/log, link to language SDK docs.

**Files:**
- Create: `docs/instrumentation/nodejs.md`
- Create: `docs/instrumentation/python.md`
- Create: `docs/instrumentation/go.md`
- Create: `docs/instrumentation/java.md`
- Create: `docs/instrumentation/ruby.md`

Each guide structure:
1. **What you'll need** (language version, OTel SDK version, OTLP endpoint URL)
2. **Time to complete** (~10 minutes)
3. **Step 1 — Install** (package manager command)
4. **Step 2 — Configure** (env vars: `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_SERVICE_NAME`, basic auth header)
5. **Step 3 — Send a span** (minimal code sample, ~20 LOC)
6. **Step 4 — Verify in Grafana** (where to look, expected service name)
7. **Auto-instrumentation** (if available — Node/Java/Python have it; Go/Ruby need manual)
8. **Common pitfalls** (HTTPS cert verify, basic auth header format, batch flushing on exit)

- [ ] **Step 1: Create `docs/instrumentation/` directory**

```bash
mkdir -p docs/instrumentation
```

- [ ] **Step 2: Write `nodejs.md`** (Node 18+, `@opentelemetry/auto-instrumentations-node`)
- [ ] **Step 3: Write `python.md`** (Python 3.10+, `opentelemetry-distro`)
- [ ] **Step 4: Write `go.md`** (Go 1.21+, manual via `go.opentelemetry.io/otel`)
- [ ] **Step 5: Write `java.md`** (JDK 17+, javaagent auto-instrumentation)
- [ ] **Step 6: Write `ruby.md`** (Ruby 3.2+, `opentelemetry-sdk` + `opentelemetry-instrumentation-all`)

- [ ] **Step 7: Validate**

```bash
for f in docs/instrumentation/*.md; do
  lines=$(wc -l < "$f"); h2=$(grep -c "^## " "$f")
  echo "$f: $lines lines, $h2 H2 sections"
  [[ $lines -ge 80 && $h2 -ge 4 ]] || { echo FAIL; exit 1; }
done
```

- [ ] **Step 8: Commit**

```bash
git add docs/instrumentation/
git commit -m "docs: add 5 instrumentation guides (Node, Python, Go, Java, Ruby)"
```

---

## Task 4: Operations docs

**Files:**
- Create: `docs/operations/backup-restore.md`
- Create: `docs/operations/upgrade.md`
- Create: `docs/operations/troubleshooting.md`

### `backup-restore.md`
1. What gets backed up (volumes: prometheus_data, victorialogs_data, tempo_data, pyroscope_data, grafana_data, caddy_data)
2. `make stop` → tar of `/var/lib/docker/volumes/otel-jps_*` → store offsite
3. Restore by extracting to same volume paths and `make simple`
4. Frequency recommendation based on retention (e.g. weekly tar)
5. Phase 4+ note: managed backup is a Standard-profile feature

### `upgrade.md`
1. Pinning policy (digests over tags)
2. `make update` for in-place upgrade
3. Roll-back procedure (revert image tag, `make simple`)
4. CHANGELOG link
5. Breaking-change protocol (always documented before bump)

### `troubleshooting.md`
1. **Container restart loop** → check `docker logs <name>` (link to relevant runbook)
2. **OTLP traffic refused** → check basic auth hash, Caddy's `/v1/*` route
3. **Grafana login fails** → check `.env` `GRAFANA_ADMIN_PASSWORD`
4. **Datasource 404** → ensure backend is healthy via `make verify`
5. **VictoriaLogs is empty** → check OTel Collector exporter `/insert/opentelemetry` URL
6. **High RAM** → check Prometheus head series; link to high-cardinality runbook

- [ ] **Step 1: Create directories**

```bash
mkdir -p docs/operations
```

- [ ] **Step 2: Write all 3 files**

- [ ] **Step 3: Validate + commit**

```bash
git add docs/operations/backup-restore.md docs/operations/upgrade.md docs/operations/troubleshooting.md
git commit -m "docs: add operations guides (backup, upgrade, troubleshooting)"
```

---

## Task 5: Runbooks (4 incident playbooks)

**Files:**
- Create: `docs/operations/runbooks/disk-full.md`
- Create: `docs/operations/runbooks/service-down.md`
- Create: `docs/operations/runbooks/cert-renewal.md`
- Create: `docs/operations/runbooks/high-cardinality.md`

Runbook template (every file follows this):

```markdown
# Runbook: <Incident name>

**Severity:** <critical | warning>
**Likely alert:** `<AlertName>` (from `alerts/default-rules.yaml`)
**Time to remediate:** ~<N> minutes

## Symptoms
- <bulleted observable signs>

## Root cause(s)
- <bullets>

## Triage (read-only checks)
1. <commands>

## Remediate
1. <commands>

## Verify recovery
1. <commands>

## Prevention
- <bullets — what to change so this doesn't recur>
```

Content per runbook:
- **disk-full.md** — symptom: `DiskUsageHigh` alert fires, ingestion stalls. Triage: `df -h` on host, check biggest volume. Remediate: lower retention env vars, restart, or `make clean` if disposable.
- **service-down.md** — symptom: `ServiceDown` alert fires. Triage: `docker compose ps`, `docker logs <name>`. Remediate: check config validation, common causes (env var missing, port bind failure).
- **cert-renewal.md** — symptom: certificate expiring. Caddy auto-renews; check Caddy logs. Manual renewal via `docker exec otel-jps-caddy caddy reload`.
- **high-cardinality.md** — symptom: `PrometheusHighCardinality` alert fires (`prometheus_tsdb_head_series > 1M`). Triage: query top labels by cardinality. Remediate: drop noisy labels via OTel Collector `transform` processor.

- [ ] **Step 1: mkdir and write all 4 files**
- [ ] **Step 2: Commit**

```bash
git add docs/operations/runbooks/
git commit -m "docs: add 4 incident runbooks (disk full, service down, cert renewal, high cardinality)"
```

---

## Task 6: Reference docs

Concise factual reference material — no narrative.

**Files:**
- Create: `docs/reference/env-vars.md` (table of every env var, default, what it controls)
- Create: `docs/reference/ports.md` (table: port, container, exposed externally?, purpose)
- Create: `docs/reference/volumes.md` (table: named volume, container, retention impact)
- Create: `docs/reference/default-alerts.md` (table: alert name, expression, severity, runbook link)
- Create: `docs/reference/default-dashboards.md` (table: dashboard, UID, datasources used, what it shows)

Content sourced directly from existing files:
- env-vars from `.env.example`
- ports from `docker-compose.yml`
- volumes from `docker-compose.yml` `volumes:` section
- alerts from `alerts/default-rules.yaml`
- dashboards from `configs/grafana/dashboards/*.json`

- [ ] **Step 1: mkdir and write all 5 files**
- [ ] **Step 2: Commit**

```bash
git add docs/reference/
git commit -m "docs: add reference docs (env-vars, ports, volumes, alerts, dashboards)"
```

---

## Task 7: Docker Compose deployment guide

**Files:**
- Create: `docs/deployment/docker-compose.md`

Covers the canonical "fresh Ubuntu 24.04 VPS" install:
1. Install Docker (link to docs.docker.com)
2. Clone repo, configure `.env`
3. `make simple`
4. Reverse-proxy/firewall considerations
5. Sizing notes (4 GB minimum, 8 GB recommended)
6. Other PaaS deployments → Phase 4 (link)

- [ ] **Step 1: mkdir and write the file**
- [ ] **Step 2: Commit**

```bash
mkdir -p docs/deployment
git add docs/deployment/docker-compose.md
git commit -m "docs: add Docker Compose deployment guide"
```

---

## Task 8: docs/README.md (docs index)

The landing page when someone navigates to the `docs/` folder on GitHub or to `/` on the rendered site.

**Files:**
- Create: `docs/README.md`

Sections:
1. **Welcome** (1 paragraph: what OTel-jps is, link back to repo README)
2. **Get started** (link to quickstart)
3. **Browse by audience**:
   - "I want to install" → quickstart, deployment, instrumentation
   - "I want to operate" → operations, runbooks, reference
   - "I want to understand" → architecture, profiles, decisions (ADRs)
4. **Full TOC** (alphabetical)

- [ ] **Step 1: Write the file**
- [ ] **Step 2: Commit**

```bash
git add docs/README.md
git commit -m "docs: add docs index landing page"
```

---

## Task 9: MkDocs Material site config

**Files:**
- Create: `mkdocs.yml`

Content (full):

```yaml
site_name: OTel-jps
site_description: Production observability for your $20/month VPS — all 5 signals, one command
site_url: https://otel-jps.dev
repo_url: https://github.com/HameemDakheel/OTel-jps
repo_name: HameemDakheel/OTel-jps

theme:
  name: material
  features:
    - navigation.tabs
    - navigation.sections
    - navigation.expand
    - navigation.top
    - search.highlight
    - search.suggest
    - content.code.copy
    - content.code.annotate
    - toc.follow
  palette:
    - media: "(prefers-color-scheme: light)"
      scheme: default
      primary: indigo
      accent: indigo
      toggle:
        icon: material/weather-night
        name: Dark mode
    - media: "(prefers-color-scheme: dark)"
      scheme: slate
      primary: indigo
      accent: indigo
      toggle:
        icon: material/weather-sunny
        name: Light mode

markdown_extensions:
  - admonition
  - pymdownx.details
  - pymdownx.superfences
  - pymdownx.tabbed:
      alternate_style: true
  - pymdownx.highlight:
      anchor_linenums: true
  - pymdownx.inlinehilite
  - pymdownx.snippets
  - tables
  - toc:
      permalink: true

nav:
  - Home: README.md
  - Get started:
      - Quickstart: quickstart.md
      - Architecture: architecture.md
      - Profiles: profiles.md
  - Deployment:
      - Docker Compose: deployment/docker-compose.md
  - Instrumentation:
      - Node.js: instrumentation/nodejs.md
      - Python: instrumentation/python.md
      - Go: instrumentation/go.md
      - Java: instrumentation/java.md
      - Ruby: instrumentation/ruby.md
  - Operations:
      - Backup & Restore: operations/backup-restore.md
      - Upgrade: operations/upgrade.md
      - Troubleshooting: operations/troubleshooting.md
      - Runbooks:
          - Disk full: operations/runbooks/disk-full.md
          - Service down: operations/runbooks/service-down.md
          - Cert renewal: operations/runbooks/cert-renewal.md
          - High cardinality: operations/runbooks/high-cardinality.md
  - Reference:
      - Environment variables: reference/env-vars.md
      - Ports: reference/ports.md
      - Volumes: reference/volumes.md
      - Default alerts: reference/default-alerts.md
      - Default dashboards: reference/default-dashboards.md
  - Decisions (ADRs):
      - 0001 Hybrid stack: decisions/0001-hybrid-stack.md
      - 0002 OTel Collector vs Alloy: decisions/0002-otel-collector-not-alloy.md
      - 0003 Caddy vs Nginx: decisions/0003-caddy-not-nginx.md
      - 0004 No MinIO at Simple: decisions/0004-no-minio-for-simple.md
      - 0005 Prometheus vs Mimir at Simple: decisions/0005-prometheus-not-mimir-for-simple.md
      - 0006 Self-monitoring vs seeder: decisions/0006-self-monitoring-not-seeder.md
```

- [ ] **Step 1: Write `mkdocs.yml`** (use the full content above)

- [ ] **Step 2: Validate site builds locally** (run via Docker — no Python install required)

```bash
docker run --rm -v "$(pwd):/docs" -w /docs squidfunk/mkdocs-material:9.5.39 build --strict --site-dir /tmp/site 2>&1 | tail -20
```

Expected: build succeeds with no warnings under `--strict`.

- [ ] **Step 3: Commit**

```bash
git add mkdocs.yml
git commit -m "feat: add MkDocs Material site config"
```

---

## Task 10: README rewrite — hero pitch + screenshots + comparison

The repo root `README.md` is the highest-impact doc. Currently still pre-redesign. Full rewrite with the wedge pitch.

**Files:**
- Modify: `README.md` (full replace)

Structure:
1. **Hero** (logo placeholder, badges: license, stars, ci, version)
2. **One-line pitch** (Production observability for your $20/month VPS)
3. **30-second pitch** (3 paragraphs — what + who + why)
4. **Quick install** (5-line bash block)
5. **What you get** (4-dashboard screenshots — placeholder paths, real screenshots in Phase 5)
6. **Comparison table** (vs SigNoz / OpenObserve / DIY LGTM / Datadog)
7. **Architecture sketch** (link to docs/architecture.md)
8. **Profiles** (link to docs/profiles.md)
9. **Demo** (`make demo` instructions)
10. **Documentation** (link to docs site)
11. **Contributing** (open issues, PRs welcome)
12. **License** (MIT)

- [ ] **Step 1: Write the new `README.md`**

- [ ] **Step 2: Verify GitHub-flavor markdown renders** (manually inspect on push, or use:)

```bash
docker run --rm -v "$(pwd):/data" tmaier/markdown-spellcheck:latest --report --en-us README.md 2>&1 | head -20 || true
# Spelling errors are warnings, not failures
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README with hero pitch, comparison table, and quickstart"
```

---

## Task 11: End-to-end Phase 3 verification + tag

- [ ] **Step 1: Verify all docs files exist and are non-empty**

```bash
COUNT=$(find docs -name "*.md" -not -path "docs/superpowers/*" | wc -l)
echo "Doc files: $COUNT"
[[ $COUNT -ge 28 ]] || { echo "expected ≥28 doc files"; exit 1; }
```

- [ ] **Step 2: Verify `mkdocs build --strict` succeeds (no broken internal links)**

```bash
docker run --rm -v "$(pwd):/docs" -w /docs squidfunk/mkdocs-material:9.5.39 build --strict --site-dir /tmp/site 2>&1 | tail -5
```

- [ ] **Step 3: Verify README starts with the hero pitch**

```bash
head -15 README.md | grep -q "Production observability" && echo "PASS hero pitch present"
```

- [ ] **Step 4: Tag**

```bash
git tag -a v1.0.0-alpha.3 -m "Phase 3 complete: 30 docs, 6 ADRs, 5 instrumentation guides, MkDocs site, README rewrite"
git tag --list 'v1*'
```

---

## Phase 3 Acceptance Criteria

- [ ] ≥28 markdown files exist under `docs/` (excluding `docs/superpowers/`)
- [ ] All 6 ADRs follow Context → Decision → Consequences format
- [ ] All 5 instrumentation guides have working code samples (Node, Python, Go, Java, Ruby)
- [ ] All 4 runbooks follow Symptoms → Root cause → Triage → Remediate → Verify → Prevention
- [ ] All 5 reference docs are tables sourced from authoritative files
- [ ] `mkdocs build --strict` passes
- [ ] `README.md` opens with the wedge pitch (matches "Production observability" within first 15 lines)
- [ ] Total stack RAM and runtime behavior unchanged (Phase 2 verify still passes)
- [ ] Tagged `v1.0.0-alpha.3`

---

## Notes & Gotchas

- **No screenshots yet** — Phase 5 captures real screenshots from the running stack and embeds them into the README. For Phase 3, use placeholder paths (`assets/screenshot-stack-health.png`) that 404 gracefully on GitHub but won't break anything.
- **Internal links** must be relative (`../decisions/0001-hybrid-stack.md`, not `https://...`). MkDocs and GitHub both render relative paths correctly.
- **Code blocks in instrumentation guides** must be copy-paste runnable — no `<placeholder>` traps. Use env-var defaults like `${OTEL_EXPORTER_OTLP_ENDPOINT:-https://localhost/v1/traces}`.
- **Markdown frontmatter** is *not* used for these docs (would conflict with GitHub rendering). MkDocs Material derives titles from the first H1.
- **No breaking-change to running stack** — Phase 3 is pure docs. The stack from Phase 2 keeps running unchanged.
- **License headers** are not added to markdown files — repo-level LICENSE applies.
