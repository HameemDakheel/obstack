# Phase 4 — PaaS Templates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn OTel-jps into a one-click install on the four PaaS platforms our beachhead uses: **Coolify**, **Dokploy**, **CapRover**, **Jelastic**. Each template wraps the same base stack so a user clicks "Deploy" and gets a working observability stack with no manual `docker compose` knowledge required. Plus four matching deployment guides under `docs/deployment/`.

**Architecture:** Templates are *thin wrappers* around the existing `docker-compose.yml` + `compose/simple.yml`. Each PaaS has its own metadata format (JSON for Coolify/Dokploy, YAML/JS for CapRover, .jps for Jelastic) but the underlying stack is identical. Per-PaaS quirks (env-var prompting, persistent storage, port mapping, TLS) are bridged in the template metadata, not in the stack itself.

**Tech Stack:** Coolify ≥ 4.0, Dokploy ≥ 0.7, CapRover ≥ 1.13, Jelastic JPS, Markdown.

**Spec reference:** [docs/superpowers/specs/2026-04-25-otel-jps-redesign.md](../specs/2026-04-25-otel-jps-redesign.md) §6 (templates/), §7 (docs/deployment/)
**Predecessor:** Phase 3 — `v1.0.0-alpha.3` must be tagged before starting.

---

## File Structure (Phase 4 deliverables)

```
otel-jps/
├── templates/
│   ├── coolify/
│   │   ├── README.md                      # NEW: how to use, what to expect
│   │   ├── docker-compose.yml             # NEW: Coolify-compatible compose (slight tweaks)
│   │   └── coolify-template.json          # NEW: metadata for Coolify Templates registry
│   ├── dokploy/
│   │   ├── README.md                      # NEW
│   │   ├── docker-compose.yml             # NEW
│   │   └── template.json                  # NEW: Dokploy Templates JSON
│   ├── caprover/
│   │   ├── README.md                      # NEW
│   │   └── captain-definition             # NEW: CapRover multi-app definition
│   └── jelastic/
│       ├── manifest.jps                   # UPDATED: rewrite for new hybrid stack
│       ├── linker.jps                     # UPDATED: env-var injection for new endpoints
│       └── README.md                      # NEW: how Jelastic install differs
│
└── docs/deployment/
    ├── docker-compose.md                  # already exists from Phase 3
    ├── coolify.md                         # NEW
    ├── dokploy.md                         # NEW
    ├── caprover.md                        # NEW
    └── jelastic.md                        # NEW
```

Plus a `mkdocs.yml` nav update to surface the four new deployment guides.

---

## Task 1: Audit and update the Jelastic manifest

The `manifest.jps` file was moved into `templates/jelastic/` in Phase 1 but its *contents* still describe the old LGTM+MinIO stack. The new hybrid stack (Prometheus+VictoriaLogs+Tempo+Pyroscope, no MinIO) needs a manifest update.

**Files:**
- Modify: `templates/jelastic/manifest.jps`
- Modify: `templates/jelastic/linker.jps`
- Create: `templates/jelastic/README.md`

- [ ] **Step 1: Inspect the current manifest**

```bash
head -60 templates/jelastic/manifest.jps
```

Note which sections reference old components (`MINIO_*`, `mimir`, `loki`, `alloy`).

- [ ] **Step 2: Rewrite `manifest.jps` for the new stack**

Update or replace these key sections:
- **`globals`** — replace `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD` with `BASIC_AUTH_HASH` + `GRAFANA_ADMIN_PASSWORD` + `ALERT_WEBHOOK_URL`.
- **`onInstall`** — git clone the repo at the desired tag (use `v1.0.0-alpha.3` or later), generate `.env` from `.env.example` with substituted credentials, run `make simple`.
- **`onAfterScaleOut`** — leave behavior unchanged but verify it doesn't reference defunct endpoints.
- **`onUninstall`** — clean stop via `make stop` (keeps volumes) or `make clean` per user preference.

The full `.jps` rewrite is content-heavy; do it during execution. Validate via `python3 -c "import json; json.load(open('manifest.jps'))"` since the file is JSON-format.

- [ ] **Step 3: Update `linker.jps`**

Should inject these env vars into linked application containers:

```json
{
  "OTEL_EXPORTER_OTLP_ENDPOINT": "https://${env.DOMAIN}",
  "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf",
  "OTEL_EXPORTER_OTLP_HEADERS": "authorization=Basic ${calc(base64(...))}"
}
```

(Old linker injected `OTEL_EXPORTER_OTLP_ENDPOINT` pointing at port 4319 on Alloy — update to the Caddy-fronted public domain.)

- [ ] **Step 4: Write `templates/jelastic/README.md`**

- [ ] **Step 5: Validate JSON parses**

```bash
python3 -c "import json; json.load(open('templates/jelastic/manifest.jps'))" && echo OK
python3 -c "import json; json.load(open('templates/jelastic/linker.jps'))" && echo OK
```

- [ ] **Step 6: Commit**

```bash
git add templates/jelastic/
git commit -m "feat(jelastic): rewrite manifest.jps and linker.jps for the new hybrid stack"
```

---

## Task 2: Coolify template

Coolify ≥ 4.0 has a Templates registry that ingests JSON metadata + a docker-compose file. Users browse "Add resource → Browse templates → OTel-jps" and click Deploy.

**Files:**
- Create: `templates/coolify/coolify-template.json`
- Create: `templates/coolify/docker-compose.yml`
- Create: `templates/coolify/README.md`

- [ ] **Step 1: Create directory and write the metadata JSON**

```bash
mkdir -p templates/coolify
```

`coolify-template.json` structure (Coolify 4 schema):

```json
{
  "name": "OTel-jps",
  "description": "Production observability for your $20/month VPS — all 5 signals, one command",
  "tags": ["observability", "monitoring", "opentelemetry", "grafana"],
  "logo": "https://github.com/HameemDakheel/OTel-jps/raw/main/assets/logo.png",
  "minimum_version": "4.0.0-beta.318",
  "documentation_url": "https://github.com/HameemDakheel/OTel-jps/blob/main/docs/deployment/coolify.md"
}
```

- [ ] **Step 2: Write a Coolify-tuned `docker-compose.yml`**

Key adjustments vs the base compose:

- Add Coolify magic comments: `# coolify`, `# coolify-network`
- Use environment variable substitution Coolify understands: `${SERVICE_FQDN_GRAFANA}` for the auto-issued domain.
- Set `restart: always` (Coolify expects this).
- Mark Caddy's `:80` and `:443` ports as the "primary" service port via Coolify's `ports.primary` annotation.

Embed the full file content during execution. Reference: <https://coolify.io/docs/knowledge-base/docker/services>

- [ ] **Step 3: Write `templates/coolify/README.md`** explaining:
- How to add OTel-jps to your Coolify instance.
- That Coolify auto-assigns a domain via wildcard DNS — no manual DOMAIN config needed.
- Where the data lives in Coolify's persistent storage.
- How to upgrade.

- [ ] **Step 4: Validate JSON + compose**

```bash
python3 -c "import json; json.load(open('templates/coolify/coolify-template.json'))" && echo OK
docker compose -f templates/coolify/docker-compose.yml config --quiet 2>&1 | grep -v BASIC_AUTH_HASH | tail -2
```

- [ ] **Step 5: Commit**

```bash
git add templates/coolify/
git commit -m "feat(coolify): add OTel-jps template + Coolify-tuned compose"
```

---

## Task 3: Dokploy template

Dokploy uses a similar Templates pattern. Format: JSON with name, description, compose, envs.

**Files:**
- Create: `templates/dokploy/template.json`
- Create: `templates/dokploy/docker-compose.yml`
- Create: `templates/dokploy/README.md`

- [ ] **Step 1: mkdir and write metadata**

```bash
mkdir -p templates/dokploy
```

`template.json` (Dokploy schema):

```json
{
  "id": "otel-jps",
  "name": "OTel-jps",
  "version": "v1.0.0-alpha.4",
  "description": "Production observability for your $20/month VPS — all 5 signals, one command",
  "logo": "https://github.com/HameemDakheel/OTel-jps/raw/main/assets/logo.png",
  "links": {
    "github": "https://github.com/HameemDakheel/OTel-jps",
    "website": "https://otel-jps.dev",
    "docs": "https://github.com/HameemDakheel/OTel-jps/blob/main/docs/deployment/dokploy.md"
  },
  "tags": ["observability", "monitoring", "opentelemetry", "grafana"],
  "envs": [
    { "name": "DOMAIN", "value": "obs.example.com", "description": "Public hostname" },
    { "name": "ACME_EMAIL", "value": "admin@example.com", "description": "Let's Encrypt contact email" },
    { "name": "GRAFANA_ADMIN_PASSWORD", "value": "${randomPassword}", "description": "Grafana admin password (auto-generated)" },
    { "name": "BASIC_AUTH_USER", "value": "ingest", "description": "OTLP ingestion username" },
    { "name": "BASIC_AUTH_HASH", "value": "${input}", "description": "bcrypt hash of OTLP password — generate with caddy hash-password" },
    { "name": "ALERT_WEBHOOK_URL", "value": "https://example.invalid/alert", "description": "Slack/Discord/PagerDuty webhook" }
  ]
}
```

- [ ] **Step 2: Write `docker-compose.yml`** (very close to the base file with Dokploy-specific tweaks)

- [ ] **Step 3: Write `README.md`**

- [ ] **Step 4: Validate**

```bash
python3 -c "import json; json.load(open('templates/dokploy/template.json'))" && echo OK
docker compose -f templates/dokploy/docker-compose.yml config --quiet 2>&1 | grep -v BASIC_AUTH_HASH | tail -2
```

- [ ] **Step 5: Commit**

```bash
git add templates/dokploy/
git commit -m "feat(dokploy): add OTel-jps template"
```

---

## Task 4: CapRover one-click app

CapRover's one-click app format is YAML-based (`captain-definition` + repo). Each *captain-definition* file defines a single app; multi-service apps need separate captain-definitions or a one-click YAML that orchestrates several apps.

**Files:**
- Create: `templates/caprover/captain-definition`
- Create: `templates/caprover/caprover-one-click-app.yml` (CapRover One-Click Apps registry format)
- Create: `templates/caprover/README.md`

CapRover's complexity: it deploys *individual apps* — for a multi-service stack like ours, the one-click app spawns 8 separate CapRover apps with shared volumes via `srv-captain--<name>` naming.

- [ ] **Step 1: mkdir and write `caprover-one-click-app.yml`**

```bash
mkdir -p templates/caprover
```

The file follows CapRover's [One-Click Apps schema](https://github.com/caprover/one-click-apps). Each service becomes a `services:` entry with image, persistent directories, env vars, and notExposeAsWebApp toggles.

This is the most complex template in Phase 4 — embed the full content during execution. Reference an existing multi-service one-click app like Plausible or Wallabag for shape.

- [ ] **Step 2: Write `captain-definition`** — minimal stub directing CapRover to the multi-service compose pattern.

- [ ] **Step 3: Write `README.md`** documenting:
- That CapRover users need to use the One-Click App pattern, not bare `docker compose`.
- How to submit to the public CapRover One-Click Apps registry.

- [ ] **Step 4: Validate YAML**

```bash
python3 -c "import yaml; yaml.safe_load(open('templates/caprover/caprover-one-click-app.yml'))" && echo OK
```

- [ ] **Step 5: Commit**

```bash
git add templates/caprover/
git commit -m "feat(caprover): add OTel-jps as a multi-service one-click app"
```

---

## Task 5–8: Per-PaaS deployment guides

Four markdown files, one per PaaS, each ~150 lines, following the same structure:

```markdown
# Deploy on <PaaS>

> What you'll need · Time to complete

## Step 1 — Prerequisites
## Step 2 — Add OTel-jps to your <PaaS>
## Step 3 — Configure
## Step 4 — Deploy
## Step 5 — Verify
## Step 6 — Point your apps at the OTLP endpoints
## Day-2 ops
## Troubleshooting (PaaS-specific)
## See also
```

**Files:**
- Create: `docs/deployment/coolify.md` (Task 5)
- Create: `docs/deployment/dokploy.md` (Task 6)
- Create: `docs/deployment/caprover.md` (Task 7)
- Create: `docs/deployment/jelastic.md` (Task 8)

For each: write the 150-line guide with copy-paste commands, screenshots noted as future-Phase-5 placeholders, and links to the PaaS's own docs for installing the PaaS itself (out of scope for OTel-jps docs).

- [ ] **Step 1 (×4): Write each deployment guide**
- [ ] **Step 2: Validate each (≥80 lines, ≥4 H2 sections)**

```bash
for f in docs/deployment/coolify.md docs/deployment/dokploy.md docs/deployment/caprover.md docs/deployment/jelastic.md; do
  lines=$(wc -l < "$f"); h2=$(grep -c "^## " "$f")
  echo "$f: $lines lines, $h2 H2"
  [[ $lines -ge 80 && $h2 -ge 4 ]] || { echo FAIL; exit 1; }
done
```

- [ ] **Step 3: Commit (one commit per guide preferred for atomicity)**

```bash
git add docs/deployment/coolify.md && git commit -m "docs: add Coolify deployment guide"
git add docs/deployment/dokploy.md && git commit -m "docs: add Dokploy deployment guide"
git add docs/deployment/caprover.md && git commit -m "docs: add CapRover deployment guide"
git add docs/deployment/jelastic.md && git commit -m "docs: add Jelastic deployment guide"
```

---

## Task 9: Update `mkdocs.yml` nav

Surface the four new deployment guides in the docs site nav.

**Files:**
- Modify: `mkdocs.yml`

- [ ] **Step 1: Replace the Deployment nav block**

Find:

```yaml
  - Deployment:
      - Docker Compose: deployment/docker-compose.md
```

Replace with:

```yaml
  - Deployment:
      - Docker Compose: deployment/docker-compose.md
      - Coolify: deployment/coolify.md
      - Dokploy: deployment/dokploy.md
      - CapRover: deployment/caprover.md
      - Jelastic: deployment/jelastic.md
```

- [ ] **Step 2: Validate the site still builds strict**

```bash
docker run --rm -v "$(pwd):/docs" -w /docs squidfunk/mkdocs-material:9.5.39 build --strict --site-dir /tmp/site 2>&1 | tail -5
```

Expected: `Documentation built` with no warnings.

- [ ] **Step 3: Commit**

```bash
git add mkdocs.yml
git commit -m "docs(site): add Coolify/Dokploy/CapRover/Jelastic to deployment nav"
```

---

## Task 10: End-to-end Phase 4 verification + tag

- [ ] **Step 1: Verify all template files exist**

```bash
COUNT=$(find templates -type f -not -name '.*' | wc -l)
echo "Template files: $COUNT (expected ≥10: 3 Coolify + 3 Dokploy + 3 CapRover + 3 Jelastic)"
[[ $COUNT -ge 10 ]] || exit 1
```

- [ ] **Step 2: Verify each template's primary spec file is syntactically valid**

```bash
python3 -c "import json; json.load(open('templates/coolify/coolify-template.json'))" && echo "coolify json OK"
python3 -c "import json; json.load(open('templates/dokploy/template.json'))" && echo "dokploy json OK"
python3 -c "import yaml; yaml.safe_load(open('templates/caprover/caprover-one-click-app.yml'))" && echo "caprover yaml OK"
python3 -c "import json; json.load(open('templates/jelastic/manifest.jps'))" && echo "jelastic json OK"
```

- [ ] **Step 3: Verify all 4 deployment guides exist and pass length checks (already done in Task 5-8)**

- [ ] **Step 4: Verify `mkdocs build --strict` passes (already done in Task 9)**

- [ ] **Step 5: Verify Phase 2 runtime still works**

```bash
./scripts/verify_stack.sh 2>&1 | tail -3
```

- [ ] **Step 6: Tag**

```bash
git tag -a v1.0.0-alpha.4 -m "Phase 4 complete: Coolify/Dokploy/CapRover/Jelastic templates and deployment guides"
git tag --list 'v1*'
```

---

## Phase 4 Acceptance Criteria

- [ ] 4 PaaS templates exist (`templates/{coolify,dokploy,caprover,jelastic}/`)
- [ ] Each template's primary spec file (JSON/YAML/JPS) parses cleanly
- [ ] 4 deployment guides exist (`docs/deployment/{coolify,dokploy,caprover,jelastic}.md`)
- [ ] Each deployment guide is ≥80 lines with ≥4 H2 sections
- [ ] `mkdocs build --strict` passes with the new nav entries
- [ ] Phase 2 runtime still works (`make verify` exits 0)
- [ ] Tagged `v1.0.0-alpha.4`

**Note:** "Each template installs a working stack on its target PaaS" is the *real* acceptance bar from spec §6. We can't validate that without running each PaaS — that's a Phase 5+ activity (community testing during launch). For Phase 4 we ship templates that *should* work based on each PaaS's documented schema and accept that some real-world iteration is expected.

---

## Notes & Gotchas

- **Coolify schema is fast-moving.** Coolify 4 templates schema is younger than Dokploy's; expect minor field renames. Always check the latest Coolify docs before submitting upstream.
- **Dokploy templates support env-var prompting** (`${input}`, `${randomPassword}`) which makes the install UX better than Coolify's. Lean on this in the Dokploy template.
- **CapRover doesn't natively understand multi-service compose** the way Coolify/Dokploy do. The One-Click App pattern with multiple `services:` entries is the canonical workaround.
- **Jelastic's persistent storage model differs** — it uses `nodeGroup` and `cloudlets` instead of Docker volumes. The manifest needs to map our compose volumes to Jelastic's storage primitives.
- **No actual PaaS testing in Phase 4.** Templates ship as v1; refinement comes from real users at launch.
- **No screenshots in deployment guides.** Phase 5 captures real screenshots from each PaaS UI and embeds them then.
