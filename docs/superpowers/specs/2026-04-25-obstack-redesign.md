# OTel-jps Redesign Specification

**Date:** 2026-04-25
**Status:** Approved (pending implementation plan)
**Supersedes:** `~/.claude/plans/rippling-swimming-river.md` (original 5-stage strategic plan)
**Authors:** Hameem (product), Claude (research/synthesis)

---

## 1. Executive Summary

OTel-jps is being redesigned from a **"sovereign observability stack via Jelastic"** into a **"production observability for your $20/month VPS"** product. The redesign is driven by adoption (not revenue) and grounded in two pieces of competitive research conducted during the brainstorming session.

The single most important finding: **Grafana already ships `grafana/docker-otel-lgtm`** — an official one-shot LGTM image that solves "pre-assembled LGTM+P with one-click deploy." The original positioning was redundant with the upstream vendor. The redesign pivots to a non-obvious wedge: **fitting all 5 signals on a 4 GB VPS with no operational headache**, achievable only by replacing the LGTM data plane with lighter components while keeping the Grafana UI.

Key decisions locked during brainstorming:

1. **Goal:** community adoption, not revenue
2. **Beachhead:** Docker self-hosters (solo devs + indie SaaS founders), single VPS or small cluster
3. **Wedge:** *"Production observability for your $20/month VPS. All 5 signals. One command. No headache."*
4. **Architecture pattern:** one product, multiple profiles (Simple → Standard → Scale → Enterprise). Ship Simple first.
5. **Stack:** Prometheus (metrics) + VictoriaLogs (logs) + Tempo (traces) + Pyroscope (profiles) + Grafana (UI) + OpenTelemetry Collector contrib (ingest) + Caddy (TLS/auth/routing) + filesystem storage (no MinIO in Simple profile)
6. **Profile mechanism:** docker-compose overlay files (`compose/simple.yml`, etc.)
7. **Demo strategy:** self-monitoring by default + opt-in OTel demo overlay using the official `open-telemetry/opentelemetry-demo` project for evaluation/marketing
8. **Documentation:** new `docs/` tree with quickstart, deployment guides per PaaS, instrumentation guides per language, runbooks, and ADRs

---

## 2. Problem Validation & Competitive Landscape

### 2.1 Is the problem real?

Yes — but the niche is crowded. SaaS observability cost shock, data sovereignty pressure, and OpenTelemetry standardization are all real and documented. However, "self-hosted observability that's easy to deploy" is contested by well-funded competitors.

### 2.2 Competitive landscape (April 2026)

| Tool | Stars | Architecture | Pitch | Where they win |
|------|-------|--------------|-------|----------------|
| SigNoz | 26.7K | ClickHouse all-in-one | "Open-source Datadog" | Brand, hosted SaaS, single DB |
| OpenObserve | 18.6K | Rust + S3 | "140x cheaper than ELK" | Single binary, marketing |
| VictoriaMetrics suite | 16.9K | Best-of-breed per signal | Lowest footprint, Prom drop-in | RAM efficiency |
| Pyroscope (Grafana) | 11.4K | Profiles backend | Profile leader | Native Grafana integration |
| HyperDX / ClickStack | 9.5K | ClickHouse-based | Dev UX + session replay | Acquired by ClickHouse 2025 |
| Coroot | 7.6K | eBPF | Zero-instrumentation + AI RCA | Auto-instrumentation |
| Grafana LGTM (DIY) | — | Best-of-breed | What `grafana/docker-otel-lgtm` ships | Brand, ecosystem |

### 2.3 Top user pain points (from research)

1. **Resource cost is brutal.** SigNoz documents 56 CPU / 152 GB RAM for production. LGTM components each scale separately.
2. **Loki query performance** is worse than ClickHouse for log search — recurring complaint in HN/issues.
3. **Tool sprawl** — metrics, logs, traces in different UIs is the #1 gripe.
4. **OTel Collector configuration** is intimidating — receivers/processors/exporters YAML maze.
5. **No auto-instrumentation by default** — Coroot wins attention purely on eBPF "no code changes."
6. **Onboarding friction** — multiple compose files, three query languages (LogQL/PromQL/TraceQL).
7. **No migration tooling from Datadog/New Relic** — biggest reason teams stay paying.

### 2.4 Adoption gap OTel-jps targets

The space lacks **a polished, resource-frugal, OpenTelemetry-native stack designed from day one for a single small VPS**. Existing options either:
- Optimize for scale and crush small servers (LGTM, SigNoz)
- Optimize for storage cost but lack profiling and full Grafana ecosystem (OpenObserve)
- Optimize for auto-instrumentation but require K8s and eBPF kernels (Coroot)

OTel-jps fills the gap: *"the lightest production-grade observability stack with all 5 signals viewable in Grafana, deployable on any Linux box in one command."*

---

## 3. Beachhead Persona & Wedge

### 3.1 Beachhead

**Docker self-hosters** — solo devs, indie SaaS founders, small teams running on:
- Single VPS (Hetzner, DigitalOcean, Vultr, Linode, OVH, AWS Lightsail)
- Self-host PaaS (Coolify, Dokploy, CapRover)
- Jelastic (preserved as a deployment target, not a launch wedge)

These users:
- Are RAM-constrained (4-8 GB typical)
- Are cost-allergic ($20/mo VPS, not $500/mo Datadog)
- Already use Grafana or want to
- Read r/selfhosted, IndieHackers, HN
- Will star, deploy, and evangelize a tool that solves their pain

**Adjacent personas served as natural follow-on (no extra effort):**
- Homelab community (r/homelab, r/HomeServer)
- Existing Grafana DIY-LGTM users tired of self-assembly
- Hosting/PaaS providers wanting a white-label observability template

### 3.2 Wedge (one-line pitch)

> **"Production observability for your $20/month VPS. All 5 signals. One command on Coolify, Dokploy, Jelastic, or plain Docker. Pre-tuned alerts. MIT licensed."**

### 3.3 Anti-personas (explicitly NOT serving at v1)

- Enterprise compliance buyers requiring SAML/audit logs/multi-tenancy → served by future Enterprise profile
- Kubernetes-native teams → not v1 (no Helm chart at launch; community-contributed later)
- Fortune-500 with petabyte-scale telemetry → wrong tool, send them to managed services

---

## 4. Architecture: Stack Components

### 4.1 Stack selection (Simple profile)

| Layer | Component | License | Idle RAM | Rationale |
|-------|-----------|---------|----------|-----------|
| **Metrics** | Prometheus (single-binary) | Apache 2.0 | 150–200 MB | Universal recognition, the standard. Lower mental friction than VictoriaMetrics for newcomers. PromQL is the recognized pattern. Scales via `remote_write` to VM/Mimir at Scale profile. |
| **Logs** | VictoriaLogs | Apache 2.0 | 100–200 MB | 87% less RAM than Loki, 94% lower query latency, 40% smaller storage (independent benchmarks). Loki's documented multi-GB query spikes disqualify it on 4 GB. |
| **Traces** | Grafana Tempo (monolithic, filesystem) | AGPL-3.0 | 250–400 MB | Object-store-native, no full-text indexing overhead. Native Grafana integration. ClickHouse-based alternatives carry 1–2 GB ClickHouse cost. |
| **Profiles** | Pyroscope | AGPL-3.0 | 200–300 MB | Pyroscope 2.0 GA April 2025, healthy maintenance, native Grafana panel. Profiling is a real differentiator vs SigNoz/OpenObserve. |
| **OTel ingest** | OpenTelemetry Collector (contrib) | Apache 2.0 | 80–150 MB | Upstream standard. Alloy's River syntax hurts SEO, copy-paste from docs, AI-assistant familiarity. The wedge is "OTel-native" — lead with the standard. |
| **UI** | Grafana | AGPL-3.0 | 150–200 MB | The brand. The moat. Non-negotiable. |
| **Reverse proxy** | Caddy | Apache 2.0 | 30–50 MB | Auto-TLS in 3-line Caddyfile. What r/selfhosted uses. Replaces Nginx + Certbot complexity. |
| **Object storage** | filesystem (no MinIO at v1) | — | 0 MB | MinIO preallocates ~1 GB on single-node — 25% of a 4 GB VPS for zero benefit. All backends support filesystem natively. MinIO returns at Scale profile. |

### 4.2 RAM budget (Simple profile)

```
Component              Idle RAM
─────────────────────────────────
Prometheus             150–200 MB
VictoriaLogs           100–200 MB
Tempo (monolithic)     250–400 MB
Pyroscope              200–300 MB
OTel Collector         80–150 MB
Grafana                150–200 MB
Caddy                  30–50 MB
─────────────────────────────────
Stack subtotal         ~960–1500 MB
OS + Docker overhead   ~700 MB
─────────────────────────────────
System idle total      ~1.7–2.2 GB
4 GB VPS headroom      ~1.8–2.3 GB (queries + bursts)
```

### 4.3 Data flow

```
Application
  ↓ OTLP (gRPC :4317 / HTTP :4318)
Caddy (TLS termination, basic auth on ingestion endpoints)
  ↓
OpenTelemetry Collector contrib (batching, memory limiting, fan-out)
  ↓        ↓        ↓        ↓
Prometheus  VictoriaLogs  Tempo  Pyroscope
  ↓        ↓        ↓        ↓
filesystem  filesystem  filesystem  filesystem
                       ↓
Grafana (queries all four, correlations enabled)
  ↑
Caddy (TLS + basic auth on UI)
  ↑
User browser (https://<DOMAIN>/)
```

### 4.4 Self-monitoring (built into all profiles)

Every component emits its own metrics, logs, and (where applicable) traces. The OTel Collector scrapes all of them. From the second the stack starts, dashboards have real data — the stack monitoring itself. **No synthetic data seeder needed for first-run "wow" experience.**

### 4.5 Routing & ports (Caddy)

| Path | Backend | Auth |
|------|---------|------|
| `/` | Grafana | Grafana login |
| `/v1/traces` | OTel Collector OTLP HTTP | Basic auth |
| `/v1/metrics` | OTel Collector OTLP HTTP | Basic auth |
| `/v1/logs` | OTel Collector OTLP HTTP | Basic auth |
| `:4317` (gRPC) | OTel Collector OTLP gRPC | Basic auth via metadata |

Internal-only (not exposed via Caddy):
- Prometheus UI/API
- VictoriaLogs UI/API
- Tempo API
- Pyroscope UI

### 4.6 Profile system

**Mechanism:** docker-compose overlay files. Base `docker-compose.yml` declares all services; profile overlays in `compose/<profile>.yml` set resource limits, retention, replicas, and toggles.

**v1 ships only Simple.** Other profiles are placeholders; actual configs ship in later releases.

| Profile | Target | RAM target | Retention | HA | Auth | Status |
|---------|--------|-----------|-----------|----|----|--------|
| **Simple** | Solo dev / indie SaaS, single VPS | ≤2 GB idle, ≤4 GB peak | 7 days | No | Caddy basic auth + Grafana login | ✅ v1.0 |
| **Standard** | Small team, single beefy server (8 GB) | ≤4 GB idle | 30 days | No | OAuth | 🔜 v1.1 |
| **Scale** | Multi-node, growing team | 16 GB+ | 90 days | Mimir/Loki HA or VM cluster | OAuth + SSO | 🔜 v2 |
| **Enterprise** | Regulated / compliance | Sized | 1+ year | Full HA + DR | SAML, audit logs, multi-tenant | 🔜 v3 |

**Run pattern:**

```bash
# Default (Simple)
docker compose -f docker-compose.yml -f compose/simple.yml up -d

# With OTel demo overlay (requires 8 GB+ machine)
docker compose -f docker-compose.yml -f compose/simple.yml -f compose/otel-demo.yml up -d
```

A `Makefile` provides shortcuts (`make simple`, `make demo`, `make verify`).

---

## 5. Default Configuration (Simple Profile)

### 5.1 Retention defaults

- Metrics: 7 days (Prometheus TSDB)
- Logs: 7 days (VictoriaLogs)
- Traces: 3 days (Tempo) — traces eat disk fastest
- Profiles: 14 days (Pyroscope)

All retentions are configurable via `.env` variables.

### 5.2 OTel Collector tuning

- Batch processor: 200 ms timeout, 8192 spans/items per batch
- Memory limiter: 75% of allocated container memory, 25% spike threshold
- Receivers: OTLP gRPC + HTTP, optional Prometheus scrape config for app endpoints
- Exporters: Prometheus remote_write, OTLP/HTTP for Tempo, OTLP/HTTP for VictoriaLogs, Pyroscope HTTP
- Sampling: tail-sampling on traces (errors + slow + 10% baseline) to keep storage manageable

### 5.3 Grafana provisioning

- All 4 datasources auto-provisioned with correlations enabled (logs↔traces↔profiles)
- 4 default dashboards shipped:
  1. **Stack Health** — every component's status, ingestion rate, storage usage
  2. **Logs Explorer** — quick search, level breakdown, top services by volume
  3. **Traces Browser** — service graph, latency heatmap, error spans
  4. **Container Metrics** — CPU/RAM/disk per container, scraped via cAdvisor
- Default admin credentials in `.env`; first-login password change enforced

### 5.4 Pre-tuned alert pack

12–15 alerts shipped in `alerts/default-rules.yaml`:

- Service down (per component)
- High error rate (>5% over 5min)
- Ingestion drop >50%
- Disk usage >80%
- RAM usage >85%
- Cert expiring <14 days
- Grafana down
- OTel Collector dropping spans
- Query latency >5s
- (final alert selection finalized during implementation; minimum 12)

User adds their webhook endpoint (Slack/Discord/email/PagerDuty) via `.env`.

### 5.5 Auto-TLS (Caddy)

- If `DOMAIN=<real domain>` is set: Caddy auto-provisions Let's Encrypt cert
- If `DOMAIN=localhost` or unset: Caddy generates self-signed cert
- Renewal handled automatically by Caddy
- Optional: HTTP→HTTPS redirect, HSTS

### 5.6 Demo strategy (two-tier)

**Tier 1 — Self-monitoring (always on, default):**
- Stack monitors itself from second 1
- Dashboards populated immediately on first install
- No extra RAM cost

**Tier 2 — OTel demo overlay (opt-in, requires 8 GB+):**
- `compose/otel-demo.yml` pulls a curated subset of `open-telemetry/opentelemetry-demo` services (frontend, cart, checkout, payment, recommendation, load-generator)
- Demo's bundled Prometheus/Grafana/Jaeger stripped — services point to our OTel Collector
- Service names namespaced under `demo.*` for easy filtering
- Locust load generator drives steady traffic
- Pinned to a specific OTel demo release tag, bumped deliberately
- License: Apache 2.0 (compatible with our MIT)

---

## 6. Directory Layout

```
otel-jps/
├── README.md                          # rewritten: hero pitch, screenshots, install
├── CHANGELOG.md                       # Keep a Changelog format
├── LICENSE                            # MIT
├── .env.example                       # variable names corrected
├── .gitignore
├── Makefile                           # make simple / make demo / make verify / make update
│
├── docker-compose.yml                 # base: shared services, networks, volumes
├── compose/
│   ├── simple.yml                     # Simple profile overlay (v1)
│   ├── standard.yml                   # placeholder (v1.1)
│   ├── scale.yml                      # placeholder (v2)
│   └── otel-demo.yml                  # OTel demo overlay (opt-in)
│
├── configs/
│   ├── caddy/
│   │   └── Caddyfile                  # replaces nginx.conf
│   ├── otel-collector/
│   │   └── config.yaml                # replaces config.alloy
│   ├── prometheus/
│   │   └── prometheus.yml             # replaces mimir.yaml
│   │                                  # (VictoriaLogs needs no config file — CLI flags only)
│   ├── tempo/
│   │   └── tempo.yaml                 # filesystem storage
│   ├── pyroscope/
│   │   └── pyroscope.yaml             # filesystem storage
│   └── grafana/
│       ├── provisioning/
│       │   ├── datasources/
│       │   ├── dashboards/
│       │   └── alerting/
│       └── dashboards/                # 4 default dashboards (JSON)
│
├── alerts/
│   └── default-rules.yaml             # 12–15 pre-tuned alerts
│
├── demo/
│   ├── README.md
│   ├── otel-demo-overrides.yml        # disable bundled obs, rewire to our collector
│   └── load-config.json               # locust config
│
├── scripts/
│   ├── verify_stack.sh                # parameterized, all components
│   ├── update.sh                      # pull + restart helper
│   └── prepare_configs.sh             # env var substitution
│
├── templates/                         # PaaS one-click templates
│   ├── coolify/
│   ├── dokploy/
│   ├── jelastic/                      # current manifest.jps moves here
│   └── caprover/
│
├── docs/                              # SSOT for documentation
│   ├── README.md                      # docs index
│   ├── quickstart.md                  # 5-minute install guide
│   ├── architecture.md                # what's inside, why
│   ├── profiles.md                    # Simple/Standard/Scale/Enterprise
│   │
│   ├── deployment/
│   │   ├── docker-compose.md
│   │   ├── coolify.md
│   │   ├── dokploy.md
│   │   ├── jelastic.md
│   │   └── caprover.md
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
│   ├── decisions/                     # ADRs
│   │   ├── 0001-hybrid-stack.md       # why VictoriaLogs not Loki
│   │   ├── 0002-otel-collector-not-alloy.md
│   │   ├── 0003-caddy-not-nginx.md
│   │   ├── 0004-no-minio-for-simple.md
│   │   ├── 0005-prometheus-not-mimir-for-simple.md
│   │   └── 0006-self-monitoring-not-seeder.md
│   │
│   └── superpowers/
│       └── specs/
│           └── 2026-04-25-otel-jps-redesign.md   # this document
│
├── assets/                            # logos, screenshots for README
│
├── .github/
│   └── workflows/
│       ├── validate.yml               # split CI from CD
│       └── deploy.yml                 # CD only
│
└── (legacy `addons/` removed; Jelastic linker may move into templates/jelastic/)
```

### 6.1 Throw-away list (current → new)

| Current | Action | Notes |
|---------|--------|-------|
| `INTEGRATION.md` | Delete | Folds into `docs/instrumentation/` |
| `logs.txt` (1 MB debug artifact) | Delete | Add to `.gitignore` |
| `nginx/nginx.conf` | Replace | → `configs/caddy/Caddyfile` |
| `configs/alloy/config.alloy` | Replace | → `configs/otel-collector/config.yaml` |
| `configs/mimir.yaml` | Replace | → `configs/prometheus/prometheus.yml` |
| `configs/loki.yaml` | Replace | → VictoriaLogs (no config file needed) |
| `manifest.jps` (root) | Move | → `templates/jelastic/manifest.jps` |
| `addons/linker.jps` | Move | → `templates/jelastic/linker.jps` |
| `verify_stack.sh` (hardcoded domain, 3 services) | Rewrite | Parameterized, all 7 components |
| `init_buckets.sh` | Delete | No MinIO in Simple profile |
| `.env.example` (`MINIO_ACCESS_KEY` mismatch) | Fix | Variable names match docker-compose |
| `pyroscope.yaml` (`${MINIO_ACCESS_KEY}` reference) | Fix | Filesystem storage instead |
| Jelastic-only positioning in README | Rewrite | New wedge pitch |

---

## 7. Documentation Strategy

### 7.1 Three audiences, three doc tones

1. **Discoverer** (lands on README via HN/Reddit): wants to know in 30 seconds — what is this, why care, can I try it?
2. **Installer** (decided to try): needs the 5-minute quickstart that *just works*
3. **Operator** (running it): needs reference material, runbooks, alerts, upgrade paths

### 7.2 Doc site

- **MkDocs Material** (Python, simple config, beautiful defaults — lowest effort for solo dev) — alternative is Docusaurus if a JS pipeline is preferred later
- Hosted via GitHub Pages on push to main
- Search built in, dark mode, mobile-friendly

### 7.3 Doc tone & style

- Short paragraphs, lots of code blocks
- One happy path per doc (alternative paths in expandable sections)
- Every doc has "What you'll need" + "Time to complete" header
- Every command copy-paste runnable (env vars, no `<placeholder>` traps)
- Screenshots for the visual moments (Grafana opened, dashboard populated)
- ADRs follow canonical format: Context → Decision → Consequences

### 7.4 ADRs to write at v1

| # | Title | One-line summary |
|---|-------|------------------|
| 0001 | Hybrid stack (Prometheus + VictoriaLogs + Tempo + Pyroscope + Grafana) | Why we don't ship pure LGTM |
| 0002 | OpenTelemetry Collector contrib over Grafana Alloy | Standards over Grafana-specific dialect |
| 0003 | Caddy over Nginx | Auto-TLS, simpler self-host UX |
| 0004 | No MinIO in Simple profile | Filesystem storage saves 1 GB RAM |
| 0005 | Prometheus over Mimir for Simple | Brand recognition, lower mental friction |
| 0006 | Self-monitoring over synthetic data seeder | Real data day 1, zero extra cost |

---

## 8. Launch Plan

### 8.1 v1 acceptance criteria

- [ ] Single `make simple` command (or equivalent `docker compose -f docker-compose.yml -f compose/simple.yml up -d`) install works on fresh Ubuntu 22.04 / 24.04 VPS with 4 GB RAM
- [ ] Stack idles under 2.2 GB RAM total (system + Docker + stack), aligned with §4.2 budget
- [ ] Caddy auto-provisions Let's Encrypt for any domain (or self-signed for localhost)
- [ ] Grafana opens with all 4 datasources connected, 4 default dashboards populated
- [ ] OTLP endpoints accept gRPC + HTTP, basic auth enforced via Caddy
- [ ] Self-monitoring shows real data in dashboards within 30 seconds of `docker compose up -d`
- [ ] OTel demo overlay works with one extra `-f` flag (8 GB+ machine)
- [ ] `verify_stack.sh` passes 100%
- [ ] CI validates configs on every push, deploys docs on every merge to main
- [ ] README, quickstart, instrumentation guides for 5 languages (Node, Python, Go, Java, Ruby), 4 PaaS deployment guides (Coolify, Dokploy, Jelastic, CapRover)
- [ ] At least 3 PaaS templates work end-to-end: Coolify, Dokploy, Jelastic
- [ ] CHANGELOG follows Keep a Changelog format
- [ ] LICENSE = MIT, repo follows Open Source Guides
- [ ] All 6 ADRs written

### 8.2 Launch sequencing (after v1 acceptance)

| Week | Action |
|------|--------|
| 0 | GitHub release v1.0.0, docs site live |
| 1 | Show HN with founder Q&A — *"Show HN: Production observability for your $20/month VPS"* |
| 2 | r/selfhosted post with screenshots + comparison table |
| 3 | Submit to Coolify community + Dokploy community as ready-made templates |
| 4 | Submit Jelastic marketplace listing |
| Month 2 | Blog post: *"How we fit Prometheus + VictoriaLogs + Tempo + Pyroscope on a 4 GB VPS"* (technical deep-dive) |
| Month 3 | Blog post: *"Migrating from Datadog to OTel-jps in 30 minutes"* (story-driven, with cost numbers) |
| Ongoing | Reply to every issue/PR within 48h; weekly release cadence for first 8 weeks |

### 8.3 Success metrics (12 months post-v1)

| Metric | Target | How to measure |
|--------|--------|----------------|
| GitHub stars | 1000+ | Public counter |
| Docker pulls | 10K+/month | Docker Hub stats |
| External contributors | 10+ | GitHub PR authors |
| HN frontpage appearances | 1+ | HN search |
| Production deployments (self-reported) | 50+ | Optional `OTEL_JPS_TELEMETRY=true` opt-in only |
| Reddit r/selfhosted launch upvotes | 200+ | Direct |
| Blog post mentions | 5+ external | Google Alerts |
| PaaS marketplace listings | All 3 | Direct |

### 8.4 Anti-goals at v1 (explicitly NOT shipping)

- No SaaS / hosted version
- No Kubernetes / Helm chart (community-contributed later)
- No Datadog importer
- No custom UI (Grafana is the UI)
- No paid tier
- No HA mode
- No multi-tenancy
- No telemetry that isn't opt-in
- No eBPF auto-instrumentation (Coroot's lane)
- No AI triage layer (Coroot's lane)

---

## 9. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Solo developer burnout | High | Critical | Strict scope discipline — Simple profile only at v1; defer everything else |
| OTel demo upstream changes break overlay | Medium | Medium | Pin to specific release tag; bump deliberately in CHANGELOG |
| Loki users object to VictoriaLogs choice | Medium | Low | ADR-0001 documents the why; benchmarks cited |
| Grafana version churn | Medium | High | Pin all images to digest; test upgrades in CI |
| VictoriaLogs is younger than Loki — fewer community resources | Medium | Medium | Document common gotchas in `docs/operations/troubleshooting.md` |
| Renaming repo breaks existing links | Low | Low | Defer rename to v2 unless naming-blocked at launch; GitHub auto-redirects |
| Adoption stalls (the wedge doesn't resonate) | Medium | High | After 90 days post-launch, review metrics; if <100 stars, consider second wedge (e.g., "Datadog migrator") |

---

## 10. Open Questions / Future Work

These are explicitly *not* decided in this spec — they are deferred to implementation planning, post-v1 iterations, or community input:

1. **Project rename** — `OTel-jps` is misleading post-redesign. Candidate names: `otelbox`, `signal-stack`, `obstack`, `loomstack`, `lite-observe`. Decide before v1.0 marketing push or defer to v2.
2. **Helm chart for K8s** — community-contributed in v2 territory.
3. **Datadog migrator** — flagged as a candidate v2/v3 wedge if adoption stalls.
4. **AI triage layer** — Coroot is ahead; LLM infra is expensive. Watch the space; revisit at v2.
5. **eBPF auto-instrumentation** — Coroot's lane; avoid head-on competition until clear advantage exists.
6. **Backup/restore tooling** — out of scope for Simple v1; basic `tar` of volumes documented in `docs/operations/backup-restore.md`. Proper tooling at Standard/Scale.
7. **Multi-tenancy** — explicitly deferred to Enterprise profile.
8. **Optional opt-in install telemetry** — desirable for measuring adoption (Docker pulls undercount actual deploys), but adds privacy burden. Defer decision; if implemented, must be opt-in with clear data policy.

---

## 11. Definition of Done (this spec)

This document is "done" when:
- [x] All major architectural decisions are recorded with rationale
- [x] Stack components, RAM budget, and data flow are concrete
- [x] Directory layout reflects all new and removed files
- [x] Documentation strategy maps to specific files in `docs/`
- [x] Launch plan and success metrics are measurable
- [x] Anti-goals are explicit
- [x] Risks are catalogued with mitigations
- [x] Open questions are flagged so they don't get silently decided

The spec does **not** need to define:
- Specific YAML/HCL contents (handled in implementation plan)
- Exact alert thresholds and rule expressions (handled in implementation)
- Dashboard JSON internals (handled in implementation)
- README copy (handled at launch)

---

## 12. Appendix: Research Sources Cited

- [VictoriaMetrics vs Mimir benchmark](https://victoriametrics.com/blog/mimir-benchmark/)
- [VictoriaLogs vs Loki benchmark (TrueFoundry)](https://www.truefoundry.com/blog/victorialogs-vs-loki)
- [Loki monolithic memory issues (GitHub #13501)](https://github.com/grafana/loki/issues/13501)
- [Pyroscope 2.0 release](https://grafana.com/blog/pyroscope-2-0-release/)
- [Alloy vs OTel Collector comparison (OneUptime)](https://oneuptime.com/blog/post/2026-02-06-compare-opentelemetry-collector-vs-grafana-alloy/view)
- [Mimir filesystem alternative (rmoff)](https://rmoff.net/2026/01/14/alternatives-to-minio-for-single-node-local-s3/)
- [Caddy vs Nginx vs Traefik 2026](https://selfhostwise.com/posts/traefik-vs-caddy-vs-nginx-proxy-manager-which-reverse-proxy-should-you-choose-in-2026/)
- [MinIO 1 GiB preallocation](https://github.com/minio/minio/discussions/19133)
- [open-telemetry/opentelemetry-demo](https://github.com/open-telemetry/opentelemetry-demo)

---

## 13. Original Plan Reference

The original 5-stage strategic plan (`~/.claude/plans/rippling-swimming-river.md`) is superseded by this spec. Notable departures from the original:

- Original: "pre-assembled LGTM+P" wedge → Replaced (Grafana already ships this).
- Original: 5 stages over 30 months including business model → Replaced (single-stage v1 launch first; profitability deferred).
- Original: serve 6 personas (SMB, Healthcare, Finance, Government, Hosting providers, DevOps) → Narrowed (Docker self-hosters as beachhead).
- Original: Mimir/Loki/MinIO/Alloy/Nginx → Replaced (Prometheus/VictoriaLogs/filesystem/OTel Collector/Caddy).
- Original: 30-month roadmap → Replaced (v1 acceptance criteria only; Standard/Scale/Enterprise are placeholders).

The original document remains useful as historical context for the breadth of the original vision but is not authoritative.
