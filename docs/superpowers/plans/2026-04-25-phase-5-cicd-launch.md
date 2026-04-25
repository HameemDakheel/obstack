# Phase 5 — CI/CD + Launch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Take OTel-jps from "the code is good" to "ready for the world to find." Add GitHub Actions for CI (config validation on every push) and CD (docs site auto-deploy), write a CHANGELOG, polish the README, draft launch announcements (HN, r/selfhosted), and tag the final `v1.0.0` release.

**Architecture:** No runtime changes. CI is a single `validate.yml` workflow that runs on every push to main and on PRs — validates docker-compose, all YAML configs, the Caddyfile, alert rules, and the MkDocs site. CD is a `deploy-docs.yml` workflow that runs on push to main when `docs/` or `mkdocs.yml` changes — builds the MkDocs site and pushes to GitHub Pages via the official `actions/deploy-pages` action. CHANGELOG and README polish are content-only.

**Tech Stack:** GitHub Actions (Ubuntu 24.04 runners), Python 3.12 (for YAML/JSON validation), MkDocs Material 9.5, the `mkdocs-material/build` action.

**Spec reference:** [docs/superpowers/specs/2026-04-25-otel-jps-redesign.md](../specs/2026-04-25-otel-jps-redesign.md) §8.1 (acceptance criteria), §8.2 (launch sequencing)
**Predecessor:** Phase 4 — `v1.0.0-alpha.4` must be tagged before starting.

---

## File Structure (Phase 5 deliverables)

```
otel-jps/
├── LICENSE                                # NEW (if missing): MIT
├── CHANGELOG.md                           # NEW: Keep a Changelog format, all 5 phases
├── README.md                              # POLISHED: badges, social preview, screenshots placeholder
├── .github/
│   └── workflows/
│       ├── validate.yml                   # NEW: CI on every push
│       └── deploy-docs.yml                # NEW: CD docs site to GitHub Pages
└── launch/
    ├── README.md                          # NEW: launch artifacts index
    ├── show-hn.md                         # NEW: Show HN post draft
    ├── reddit-selfhosted.md               # NEW: r/selfhosted launch draft
    └── announce-twitter.md                # NEW: Twitter/X thread draft
```

Plus one optional task to capture or stub screenshots referenced by the README.

---

## Task 1: LICENSE (MIT)

The README references MIT but the file may not exist. Add it.

**Files:**
- Create or verify: `LICENSE`

- [ ] **Step 1: Check if LICENSE exists**

```bash
ls -la LICENSE 2>&1
```

- [ ] **Step 2: If missing, write it**

Path: `LICENSE`

```
MIT License

Copyright (c) 2026 Hameem Dakheel and contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 3: Commit (if newly created)**

```bash
git add LICENSE
git commit -m "chore: add MIT LICENSE file"
```

---

## Task 2: CI workflow — `.github/workflows/validate.yml`

**Files:**
- Create: `.github/workflows/validate.yml`

This workflow runs on every push to `main` and every PR. It validates:
- All YAML configs parse
- All JSON template files parse
- `docker compose` config validates
- The Caddyfile is syntactically valid
- The OTel Collector config validates (using the contrib image's built-in validator)
- All Prometheus alert rules parse
- `mkdocs build --strict` passes (no broken doc links)
- Bash scripts pass `bash -n`

- [ ] **Step 1: Create the workflows directory if missing**

```bash
mkdir -p .github/workflows
```

- [ ] **Step 2: Write the validate workflow**

Path: `.github/workflows/validate.yml`

```yaml
name: validate

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  validate:
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: 'pip'

      - name: Install Python deps
        run: |
          pip install --upgrade pip
          pip install pyyaml mkdocs-material

      - name: Validate YAML configs
        run: |
          for f in \
            configs/otel-collector/config.yaml \
            configs/prometheus/prometheus.yml \
            configs/tempo/tempo.yaml \
            configs/pyroscope/pyroscope.yaml \
            configs/grafana/provisioning/datasources/all.yaml \
            configs/grafana/provisioning/dashboards/dashboards.yaml \
            configs/grafana/provisioning/alerting/contact-points.yaml \
            configs/grafana/provisioning/alerting/notification-policies.yaml \
            alerts/default-rules.yaml \
            mkdocs.yml \
            templates/coolify/docker-compose.yml \
            templates/dokploy/docker-compose.yml \
            templates/caprover/caprover-one-click-app.yml; do
            echo "Validating $f"
            python3 -c "import yaml; yaml.safe_load(open('$f'))"
          done

      - name: Validate JSON templates
        run: |
          for f in \
            templates/coolify/coolify-template.json \
            templates/dokploy/template.json \
            templates/caprover/captain-definition \
            templates/jelastic/manifest.jps \
            templates/jelastic/linker.jps \
            configs/grafana/dashboards/stack-health.json \
            configs/grafana/dashboards/container-metrics.json \
            configs/grafana/dashboards/logs-explorer.json \
            configs/grafana/dashboards/traces-browser.json; do
            echo "Validating $f"
            python3 -c "import json; json.load(open('$f'))"
          done

      - name: Validate docker-compose merges (Simple profile)
        run: |
          docker compose -f docker-compose.yml -f compose/simple.yml config --quiet
          docker compose -f docker-compose.yml -f compose/simple.yml -f compose/otel-demo.yml config --quiet

      - name: Validate Caddyfile
        run: |
          docker run --rm -v "$PWD/configs/caddy/Caddyfile:/etc/caddy/Caddyfile:ro" \
            caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

      - name: Validate OTel Collector config
        run: |
          docker run --rm -v "$PWD/configs/otel-collector/config.yaml:/etc/otelcol-contrib/config.yaml:ro" \
            otel/opentelemetry-collector-contrib:0.111.0 validate --config=/etc/otelcol-contrib/config.yaml

      - name: Validate Prometheus rules
        run: |
          docker run --rm -v "$PWD/alerts:/etc/prometheus/rules:ro" \
            prom/prometheus:v3.0.1 promtool check rules /etc/prometheus/rules/default-rules.yaml

      - name: Validate bash scripts
        run: |
          for f in scripts/*.sh; do
            echo "Validating $f"
            bash -n "$f"
          done

      - name: Build MkDocs site (strict)
        run: |
          mkdocs build --strict --site-dir /tmp/mkdocs-site

  shellcheck:
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Run shellcheck on scripts/*.sh
        uses: ludeeus/action-shellcheck@master
        env:
          SHELLCHECK_OPTS: -e SC1091 -e SC2086
        with:
          scandir: scripts
```

- [ ] **Step 3: Validate YAML parses**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/validate.yml'))" && echo OK
```

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/validate.yml
git commit -m "ci: add validate workflow (YAML/JSON/compose/caddy/otel/prom/mkdocs/bash/shellcheck)"
```

---

## Task 3: CD workflow — `.github/workflows/deploy-docs.yml`

Deploys MkDocs to GitHub Pages on push to main when docs change.

**Files:**
- Create: `.github/workflows/deploy-docs.yml`

- [ ] **Step 1: Write the deploy workflow**

Path: `.github/workflows/deploy-docs.yml`

```yaml
name: deploy-docs

on:
  push:
    branches: [main]
    paths:
      - 'docs/**'
      - 'mkdocs.yml'
      - '.github/workflows/deploy-docs.yml'
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: 'pip'

      - name: Install MkDocs
        run: pip install mkdocs-material

      - name: Build site
        run: mkdocs build --strict --site-dir ./_site

      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: ./_site

  deploy:
    needs: build
    runs-on: ubuntu-24.04
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

- [ ] **Step 2: Validate YAML parses**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/deploy-docs.yml'))" && echo OK
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/deploy-docs.yml
git commit -m "ci: add deploy-docs workflow (MkDocs site to GitHub Pages on main push)"
```

**Note for repo owner:** GitHub Pages must be enabled in repo Settings → Pages → Source: GitHub Actions before the first run will succeed.

---

## Task 4: CHANGELOG.md

Keep a Changelog format covering all 5 phases.

**Files:**
- Create: `CHANGELOG.md`

- [ ] **Step 1: Write the file** following [keepachangelog.com](https://keepachangelog.com/en/1.1.0/) format. Sections: Unreleased + each tagged release with Added / Changed / Removed / Fixed / Deprecated / Security categories.

The full content follows the canonical Keep a Changelog spec; embed during execution. Cover:

- **Unreleased** — current main, planned items
- **v1.0.0** *(when tagged)* — final release notes
- **v1.0.0-alpha.4** — Phase 4: PaaS templates (Coolify/Dokploy/CapRover/Jelastic) + 4 deployment guides
- **v1.0.0-alpha.3** — Phase 3: 28 docs + MkDocs site + README rewrite
- **v1.0.0-alpha.2** — Phase 2: 4 dashboards + 12 alerts + cAdvisor + OTel demo overlay + healthcheck cleanup
- **v1.0.0-alpha.1** — Phase 1: hybrid stack (Prometheus+VictoriaLogs+Tempo+Pyroscope+Grafana+OTel Collector+Caddy) replacing the LGTM+MinIO prototype

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: add CHANGELOG covering all alpha releases"
```

---

## Task 5: README polish

The Phase 3 README has the hero pitch and comparison table. Phase 5 polish:
- Verify all badges resolve to real URLs
- Add an "Activity" / "Status" section with the current alpha tag
- Add an "Acknowledgements" section (Grafana, OTel project, VictoriaMetrics, etc.)
- Add a "Star History" placeholder for once stars start coming in
- Update version badge from `alpha.3` to `1.0.0` (after Task 8)

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add an Acknowledgements section** before the License footer

- [ ] **Step 2: Add a Status badge** at the top showing current build state

- [ ] **Step 3: Verify all GitHub URLs in the README resolve** (manually inspect on push)

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: README polish (acknowledgements, status badge)"
```

---

## Task 6: Launch artifacts (drafts)

Pre-written posts ready to copy/paste on launch day. Drafts only — not published.

**Files:**
- Create: `launch/README.md`
- Create: `launch/show-hn.md`
- Create: `launch/reddit-selfhosted.md`
- Create: `launch/announce-twitter.md`

- [ ] **Step 1: Create the directory**

```bash
mkdir -p launch
```

- [ ] **Step 2: Write `launch/README.md`** — index of artifacts and a launch checklist (when to post, in what order, what to monitor).

- [ ] **Step 3: Write `launch/show-hn.md`** — Show HN draft following Hacker News best practices: punchy title, factual description, founder availability. Title: *"Show HN: OTel-jps — Production observability for your $20/month VPS"*.

- [ ] **Step 4: Write `launch/reddit-selfhosted.md`** — r/selfhosted post. Different tone than HN: more "look what I built, here's why it matters for selfhosters specifically." Include screenshots reference.

- [ ] **Step 5: Write `launch/announce-twitter.md`** — Twitter/X thread (5-7 tweets) for the launch.

- [ ] **Step 6: Commit**

```bash
git add launch/
git commit -m "docs(launch): add Show HN, Reddit, and Twitter draft posts"
```

---

## Task 7: Screenshots placeholder

Real screenshots from the running stack are best captured manually post-launch (different ages of data make for better screenshots). For Phase 5, add an `assets/screenshots/` directory with a README explaining what to capture and when.

**Files:**
- Create: `assets/screenshots/README.md` (the directory exists but documents what screenshots to add)

- [ ] **Step 1: Create the directory**

```bash
mkdir -p assets/screenshots
```

- [ ] **Step 2: Write `assets/screenshots/README.md`** with a checklist of screenshots to capture:
  - Grafana login page
  - OTel-jps folder showing 4 dashboards
  - Stack Health dashboard with live data
  - Container Metrics dashboard
  - Logs Explorer dashboard
  - Traces Browser dashboard with service graph
  - Alerts UI with the 12 default rules
  - `make verify` terminal output

Include capture instructions: viewport size (1920×1080), include 30+ minutes of data first, dark mode preference, no personally identifiable info.

- [ ] **Step 3: Commit**

```bash
git add assets/
git commit -m "docs: add assets/screenshots/ placeholder with capture instructions"
```

---

## Task 8: Final E2E verification + tag v1.0.0

- [ ] **Step 1: Run runtime verify**

```bash
./scripts/verify_stack.sh 2>&1 | tail -3
```

Expected: 7 passed, 0 failed.

- [ ] **Step 2: Validate all CI workflows YAML**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/validate.yml'))"
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/deploy-docs.yml'))"
```

- [ ] **Step 3: Validate MkDocs strict build still passes**

```bash
docker run --rm -v "$(pwd):/docs" -w /docs squidfunk/mkdocs-material:9.5.39 build --strict --site-dir /tmp/site 2>&1 | tail -3
```

- [ ] **Step 4: Update README version badge from alpha.4 to 1.0.0**

- [ ] **Step 5: Update CHANGELOG with the v1.0.0 release entry** (move Unreleased into v1.0.0).

- [ ] **Step 6: Commit version bumps**

```bash
git add README.md CHANGELOG.md
git commit -m "release: v1.0.0 — first production release"
```

- [ ] **Step 7: Tag**

```bash
git tag -a v1.0.0 -m "v1.0.0 — first production release. All 5 phases shipped: core stack, polish, docs, PaaS templates, CI/CD."
git tag --list 'v1*'
```

The tag is local until the user explicitly pushes (per global git workflow rules — no auto-push).

---

## Phase 5 Acceptance Criteria

- [ ] `LICENSE` file present (MIT)
- [ ] `.github/workflows/validate.yml` exists, valid YAML
- [ ] `.github/workflows/deploy-docs.yml` exists, valid YAML
- [ ] `CHANGELOG.md` covers all alpha releases + v1.0.0 entry
- [ ] `README.md` has acknowledgements section, status badge, and v1.0.0 version badge
- [ ] `launch/` directory contains 4 artifacts (index, Show HN, Reddit, Twitter)
- [ ] `assets/screenshots/README.md` documents what to capture
- [ ] Runtime verify still passes
- [ ] MkDocs strict build still passes
- [ ] Tagged `v1.0.0` (locally)

---

## Notes & Gotchas

- **No screenshots in this phase.** They're captured manually post-launch and added in a follow-up PR. Phase 5 leaves placeholders.
- **GitHub Pages must be enabled** in repo Settings before `deploy-docs.yml` will succeed. Document in launch checklist.
- **Don't push the tag automatically.** Per global git workflow — the user pushes when ready to actually launch.
- **The validate workflow is heavy** — it pulls Caddy, OTel Collector, and Prometheus images for validation. First run takes ~3-5 minutes; subsequent runs cache.
- **Launch artifacts are drafts only.** Don't post them anywhere as part of Phase 5. Posting is the actual launch event, separate from the code work.
- **The `v1.0.0` tag is the *capstone*.** After this, every change is `v1.0.x` (patch) or `v1.x.0` (feature) — semver applies.
