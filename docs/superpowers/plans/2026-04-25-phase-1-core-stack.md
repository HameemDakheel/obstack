# Phase 1 — Core Stack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the legacy LGTM+P prototype with a working hybrid stack (Prometheus + VictoriaLogs + Tempo + Pyroscope + Grafana + OpenTelemetry Collector + Caddy) that boots from a single `make simple` command, idles under 2.2 GB on a 4 GB VPS, and accepts OTLP on the standard endpoints.

**Architecture:** Base `docker-compose.yml` declares all services on an internal Docker network with named volumes for filesystem persistence. `compose/simple.yml` overlay applies resource limits and retention defaults. Caddy fronts everything with auto-TLS (Let's Encrypt or self-signed) and basic auth on OTLP ingestion paths. OTel Collector ingests OTLP and fans out to four backends. Grafana is the single UI with all four datasources auto-provisioned.

**Tech Stack:** Docker, Docker Compose, Caddy v2, OpenTelemetry Collector contrib, Prometheus, VictoriaLogs, Grafana Tempo, Pyroscope, Grafana, Bash, Make.

**Spec reference:** [docs/superpowers/specs/2026-04-25-otel-jps-redesign.md](../specs/2026-04-25-otel-jps-redesign.md)

---

## File Structure (what this phase produces)

| File | Responsibility |
|------|---------------|
| `docker-compose.yml` | Base service definitions, networks, volumes |
| `compose/simple.yml` | Simple-profile overlay: resource limits, retention env vars |
| `compose/standard.yml` | Stub for v1.1 (placeholder file with comment only) |
| `compose/scale.yml` | Stub for v2 (placeholder file with comment only) |
| `configs/caddy/Caddyfile` | TLS, basic auth, reverse-proxy routing |
| `configs/otel-collector/config.yaml` | OTLP receivers, processors, fan-out exporters |
| `configs/prometheus/prometheus.yml` | Scrape config, remote-write enabled |
| `configs/tempo/tempo.yaml` | Monolithic mode, filesystem storage |
| `configs/pyroscope/pyroscope.yaml` | Filesystem storage, retention |
| `configs/grafana/provisioning/datasources/all.yaml` | Provision Prometheus, VictoriaLogs, Tempo, Pyroscope datasources |
| `.env.example` | Documented env vars (DOMAIN, credentials, retention overrides) |
| `.gitignore` | Add `.env`, `*.log`, `data/`, `volumes/` |
| `scripts/verify_stack.sh` | Health-check every component over HTTP |
| `Makefile` | `make simple`, `make stop`, `make logs`, `make verify`, `make update` |
| `templates/jelastic/manifest.jps` | Moved from repo root |
| `templates/jelastic/linker.jps` | Moved from repo root `addons/` |

**Files removed:** `logs.txt`, `INTEGRATION.md`, `manifest.jps` (root), `addons/`, `nginx/`, `configs/alloy/`, `configs/mimir.yaml`, `configs/loki.yaml`, `scripts/init_buckets.sh`.

---

## Task 1: Foundation Cleanup — remove legacy artifacts

**Files:**
- Delete: `/home/hameem/workspace/OTel-jps/logs.txt`
- Delete: `/home/hameem/workspace/OTel-jps/INTEGRATION.md`
- Modify: `/home/hameem/workspace/OTel-jps/.gitignore`

- [ ] **Step 1: Verify the files exist before deletion**

```bash
ls -la /home/hameem/workspace/OTel-jps/logs.txt /home/hameem/workspace/OTel-jps/INTEGRATION.md
```

Expected: both files listed with sizes (logs.txt ~1 MB, INTEGRATION.md ~3 KB).

- [ ] **Step 2: Delete them**

```bash
rm /home/hameem/workspace/OTel-jps/logs.txt
rm /home/hameem/workspace/OTel-jps/INTEGRATION.md
```

- [ ] **Step 3: Replace `.gitignore` with the new content**

Path: `/home/hameem/workspace/OTel-jps/.gitignore`

```gitignore
# Environment
.env
.env.local
.env.*.local
!.env.example
!.env.test

# Data and logs
data/
volumes/
*.log
logs/

# OS / editor
.DS_Store
*.swp
*.swo
*~
.idea/
.vscode/

# Temp / cache
*.tmp
*.bak
.cache/

# Build artifacts (none expected at v1, kept for safety)
dist/
build/
```

- [ ] **Step 4: Verify**

```bash
git -C /home/hameem/workspace/OTel-jps status --short
```

Expected: shows `D logs.txt`, `D INTEGRATION.md`, `M .gitignore`.

- [ ] **Step 5: Commit**

```bash
git -C /home/hameem/workspace/OTel-jps add -A
git -C /home/hameem/workspace/OTel-jps commit -m "chore: remove legacy debug artifacts and refresh .gitignore"
```

---

## Task 2: Move Jelastic legacy files into `templates/`

**Files:**
- Move: `manifest.jps` → `templates/jelastic/manifest.jps`
- Move: `addons/linker.jps` → `templates/jelastic/linker.jps`
- Delete: empty `addons/` directory

- [ ] **Step 1: Verify current locations**

```bash
ls -la /home/hameem/workspace/OTel-jps/manifest.jps /home/hameem/workspace/OTel-jps/addons/
```

Expected: `manifest.jps` ~6 KB; `addons/` contains `linker.jps`.

- [ ] **Step 2: Create the target directory and move both files**

```bash
mkdir -p /home/hameem/workspace/OTel-jps/templates/jelastic
git -C /home/hameem/workspace/OTel-jps mv manifest.jps templates/jelastic/manifest.jps
git -C /home/hameem/workspace/OTel-jps mv addons/linker.jps templates/jelastic/linker.jps
rmdir /home/hameem/workspace/OTel-jps/addons
```

- [ ] **Step 3: Verify**

```bash
ls -la /home/hameem/workspace/OTel-jps/templates/jelastic/
```

Expected: both `manifest.jps` and `linker.jps` listed; `addons/` no longer exists.

- [ ] **Step 4: Commit**

```bash
git -C /home/hameem/workspace/OTel-jps add -A
git -C /home/hameem/workspace/OTel-jps commit -m "refactor: relocate Jelastic templates into templates/jelastic/"
```

---

## Task 3: Rewrite `.env.example` with the new variable set

**Files:**
- Replace: `/home/hameem/workspace/OTel-jps/.env.example`

- [ ] **Step 1: Inspect the current file**

```bash
cat /home/hameem/workspace/OTel-jps/.env.example
```

Expected: contains `MINIO_ACCESS_KEY` etc. — variables we no longer use.

- [ ] **Step 2: Write the new `.env.example`**

Path: `/home/hameem/workspace/OTel-jps/.env.example`

```dotenv
# OTel-jps Simple profile environment
# Copy this file to .env and edit before running `make simple`.

# ─── Domain & TLS ──────────────────────────────────────────────────────────
# Public hostname for Caddy. Use "localhost" for local dev (self-signed cert).
# A real domain enables Caddy auto-TLS via Let's Encrypt.
DOMAIN=localhost

# Email used by Caddy when requesting Let's Encrypt certs.
# Required when DOMAIN is a real public domain.
ACME_EMAIL=admin@example.com

# ─── Authentication ────────────────────────────────────────────────────────
# Grafana admin login (used on first launch; change after login).
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=changeme

# Basic auth for OTLP ingestion endpoints (protected by Caddy).
# Generate the hash with: docker run --rm caddy:2-alpine caddy hash-password --plaintext '<password>'
BASIC_AUTH_USER=ingest
BASIC_AUTH_HASH=$2a$14$Z9Lr.JI8h6yrkqu6E9c7Pez3K8iH6zS6h8Y5J6K9L1N4M2P3Q5R7S

# ─── Retention overrides (Simple profile defaults shown) ───────────────────
PROMETHEUS_RETENTION=7d
VICTORIALOGS_RETENTION=7d
TEMPO_RETENTION_HOURS=72
PYROSCOPE_RETENTION_HOURS=336

# ─── Resource hints (Simple profile) ───────────────────────────────────────
# These are advisory; compose/simple.yml applies the actual limits.
STACK_PROFILE=simple
```

- [ ] **Step 3: Verify it parses as a shell-compatible env file**

```bash
set -a; source /home/hameem/workspace/OTel-jps/.env.example; set +a; \
  echo "DOMAIN=$DOMAIN GRAFANA_ADMIN_USER=$GRAFANA_ADMIN_USER STACK_PROFILE=$STACK_PROFILE"
```

Expected: prints `DOMAIN=localhost GRAFANA_ADMIN_USER=admin STACK_PROFILE=simple`.

- [ ] **Step 4: Commit**

```bash
git -C /home/hameem/workspace/OTel-jps add .env.example
git -C /home/hameem/workspace/OTel-jps commit -m "feat: rewrite .env.example for new stack components"
```

---

## Task 4: Scaffold base `docker-compose.yml` (skeleton + network + volumes)

**Files:**
- Replace: `/home/hameem/workspace/OTel-jps/docker-compose.yml`

This task creates the skeleton — services are added one per task in Tasks 5-11.

- [ ] **Step 1: Run `docker compose config` against the existing file**

```bash
cd /home/hameem/workspace/OTel-jps && docker compose config --quiet
```

Expected: succeeds (current file is valid). We're rewriting it; this just confirms the toolchain works before we start.

- [ ] **Step 2: Replace `docker-compose.yml` with the new skeleton**

Path: `/home/hameem/workspace/OTel-jps/docker-compose.yml`

```yaml
# OTel-jps base compose file.
# This file declares networks and volumes; services are layered in by `compose/<profile>.yml`.
# Run with: docker compose -f docker-compose.yml -f compose/simple.yml up -d
# Or via:    make simple

networks:
  obs-net:
    driver: bridge

volumes:
  caddy_data:
  caddy_config:
  prometheus_data:
  victorialogs_data:
  tempo_data:
  pyroscope_data:
  grafana_data:

services:
  # Service definitions are added by overlays (compose/simple.yml etc.) plus the
  # profile-independent service blocks added in subsequent tasks of this plan.
```

- [ ] **Step 3: Validate**

```bash
cd /home/hameem/workspace/OTel-jps && docker compose -f docker-compose.yml config --quiet
```

Expected: exits 0 with no output (valid).

- [ ] **Step 4: Commit**

```bash
git -C /home/hameem/workspace/OTel-jps add docker-compose.yml
git -C /home/hameem/workspace/OTel-jps commit -m "refactor: replace docker-compose.yml with new profile-aware skeleton"
```

---

## Task 5: Create `compose/simple.yml` overlay (skeleton + stubs for other profiles)

**Files:**
- Create: `compose/simple.yml`
- Create: `compose/standard.yml` (stub)
- Create: `compose/scale.yml` (stub)

- [ ] **Step 1: Create the directory**

```bash
mkdir -p /home/hameem/workspace/OTel-jps/compose
```

- [ ] **Step 2: Write `compose/simple.yml` (overlay skeleton — service blocks filled in later tasks)**

Path: `/home/hameem/workspace/OTel-jps/compose/simple.yml`

```yaml
# Simple profile overlay.
# Targets: solo dev / indie SaaS, single VPS with 4 GB RAM.
# Apply with: docker compose -f docker-compose.yml -f compose/simple.yml up -d

services:
  # Service deploy/limit blocks are added by Tasks 6-11.
```

- [ ] **Step 3: Write the placeholder for `compose/standard.yml`**

Path: `/home/hameem/workspace/OTel-jps/compose/standard.yml`

```yaml
# Standard profile overlay (placeholder — ships in v1.1).
# Targets: small team, single beefy server (~8 GB RAM).
# Currently contains no service blocks; use compose/simple.yml until v1.1 ships.

services: {}
```

- [ ] **Step 4: Write the placeholder for `compose/scale.yml`**

Path: `/home/hameem/workspace/OTel-jps/compose/scale.yml`

```yaml
# Scale profile overlay (placeholder — ships in v2).
# Targets: multi-node, growing team, ~16+ GB RAM with HA storage.
# Currently contains no service blocks.

services: {}
```

- [ ] **Step 5: Validate the simple overlay applies cleanly to the base**

```bash
cd /home/hameem/workspace/OTel-jps && \
  docker compose -f docker-compose.yml -f compose/simple.yml config --quiet
```

Expected: exits 0 with no output.

- [ ] **Step 6: Commit**

```bash
git -C /home/hameem/workspace/OTel-jps add compose/
git -C /home/hameem/workspace/OTel-jps commit -m "feat: add profile overlays (simple ships v1; standard/scale stubs)"
```

---

## Task 6: Caddy reverse proxy

**Files:**
- Create: `configs/caddy/Caddyfile`
- Modify: `docker-compose.yml` — append `caddy` service block
- Modify: `compose/simple.yml` — append `caddy` deploy limits

- [ ] **Step 1: Create the configs directory**

```bash
mkdir -p /home/hameem/workspace/OTel-jps/configs/caddy
```

- [ ] **Step 2: Write the Caddyfile**

Path: `/home/hameem/workspace/OTel-jps/configs/caddy/Caddyfile`

```caddyfile
# Global options
{
    email {$ACME_EMAIL}
    # Auto HTTPS uses Let's Encrypt for any non-localhost DOMAIN.
    # For localhost, Caddy generates an internal self-signed cert automatically.
}

{$DOMAIN} {
    encode gzip zstd

    # Grafana UI on root
    handle / {
        reverse_proxy grafana:3000
    }

    handle_path /grafana/* {
        reverse_proxy grafana:3000
    }

    # OTLP HTTP ingestion (basic auth required)
    handle_path /v1/* {
        basic_auth {
            {$BASIC_AUTH_USER} {$BASIC_AUTH_HASH}
        }
        reverse_proxy otel-collector:4318
    }

    # Default: proxy to Grafana
    reverse_proxy grafana:3000
}

# OTLP gRPC endpoint on port 4317 (HTTP/2)
:4317 {
    reverse_proxy otel-collector:4317 {
        transport http {
            versions h2c 2
        }
    }
}
```

- [ ] **Step 3: Validate the Caddyfile syntax**

```bash
docker run --rm -v /home/hameem/workspace/OTel-jps/configs/caddy/Caddyfile:/etc/caddy/Caddyfile:ro \
  caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
```

Expected: prints `Valid configuration` (env-var placeholders are tolerated by validate).

- [ ] **Step 4: Append the caddy service block to `docker-compose.yml`**

Modify `/home/hameem/workspace/OTel-jps/docker-compose.yml` — replace the closing `services:` section with the full block below (append all subsequent services in later tasks).

The base service definition (no resource limits — those go in `compose/simple.yml`):

```yaml
  caddy:
    image: caddy:2-alpine
    container_name: otel-jps-caddy
    restart: unless-stopped
    networks:
      - obs-net
    ports:
      - "80:80"
      - "443:443"
      - "4317:4317"   # OTLP gRPC
    volumes:
      - ./configs/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    environment:
      DOMAIN: ${DOMAIN:-localhost}
      ACME_EMAIL: ${ACME_EMAIL:-admin@example.com}
      BASIC_AUTH_USER: ${BASIC_AUTH_USER:-ingest}
      BASIC_AUTH_HASH: ${BASIC_AUTH_HASH}
    depends_on:
      grafana:
        condition: service_started
      otel-collector:
        condition: service_started
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:2019/config/"]
      interval: 30s
      timeout: 5s
      retries: 5
```

Place this under `services:` in `docker-compose.yml`.

- [ ] **Step 5: Append caddy resource limits to `compose/simple.yml`**

Path: `/home/hameem/workspace/OTel-jps/compose/simple.yml` — replace the empty `services:` line with:

```yaml
services:
  caddy:
    deploy:
      resources:
        limits:
          memory: 128M
        reservations:
          memory: 32M
```

- [ ] **Step 6: Validate the merged config**

```bash
cd /home/hameem/workspace/OTel-jps && \
  docker compose -f docker-compose.yml -f compose/simple.yml config --quiet
```

Expected: exits non-zero with a message about `grafana` and `otel-collector` services not being defined yet (they're listed under `depends_on`). This is the intended RED state — those services arrive in later tasks.

- [ ] **Step 7: Temporarily comment out `depends_on` to confirm the rest is valid**

Edit `docker-compose.yml` and prefix the `depends_on:` block under `caddy:` with `#` on each line, then re-run:

```bash
cd /home/hameem/workspace/OTel-jps && \
  docker compose -f docker-compose.yml -f compose/simple.yml config --quiet && echo OK
```

Expected: prints `OK`. Then **restore** the `depends_on` block (un-comment) — it'll resolve once Tasks 7-11 land.

- [ ] **Step 8: Commit (with `depends_on` restored)**

```bash
git -C /home/hameem/workspace/OTel-jps add configs/caddy/ docker-compose.yml compose/simple.yml
git -C /home/hameem/workspace/OTel-jps commit -m "feat: add Caddy reverse proxy with auto-TLS and basic auth"
```

---

## Task 7: OpenTelemetry Collector (contrib)

**Files:**
- Create: `configs/otel-collector/config.yaml`
- Modify: `docker-compose.yml` — append `otel-collector` service
- Modify: `compose/simple.yml` — append `otel-collector` deploy limits

- [ ] **Step 1: Create the directory**

```bash
mkdir -p /home/hameem/workspace/OTel-jps/configs/otel-collector
```

- [ ] **Step 2: Write the OTel Collector config**

Path: `/home/hameem/workspace/OTel-jps/configs/otel-collector/config.yaml`

```yaml
# OpenTelemetry Collector contrib config — Simple profile.
# Receives OTLP, fans out to Prometheus (metrics), VictoriaLogs (logs),
# Tempo (traces), and Pyroscope (profiles).

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

  # Self-monitoring: scrape the collector's own /metrics
  prometheus/self:
    config:
      scrape_configs:
        - job_name: otel-collector-self
          scrape_interval: 30s
          static_configs:
            - targets: ['localhost:8888']

processors:
  memory_limiter:
    check_interval: 5s
    limit_percentage: 75
    spike_limit_percentage: 25

  batch:
    timeout: 200ms
    send_batch_size: 8192
    send_batch_max_size: 16384

  resourcedetection:
    detectors: [env, system]
    timeout: 2s

exporters:
  # Metrics → Prometheus remote-write
  prometheusremotewrite:
    endpoint: http://prometheus:9090/api/v1/write
    tls:
      insecure: true
    resource_to_telemetry_conversion:
      enabled: true

  # Logs → VictoriaLogs OTLP receiver
  otlphttp/logs:
    endpoint: http://victorialogs:9428/insert/opentelemetry
    tls:
      insecure: true

  # Traces → Tempo OTLP HTTP
  otlphttp/tempo:
    endpoint: http://tempo:4318
    tls:
      insecure: true

  # NOTE: profiles export to Pyroscope is wired in Phase 2 (Stack Polish).
  # Reason: OTel Collector contrib's profiles signal is still maturing; we keep
  # Phase 1 strictly to the stable receivers/exporters to ensure the stack boots.
  # In Phase 2, applications can either:
  #   (a) push profiles directly to Pyroscope's native /ingest endpoint, OR
  #   (b) route through the collector once a stable profiles pipeline is added.

  debug:
    verbosity: basic

extensions:
  health_check:
    endpoint: 0.0.0.0:13133

service:
  extensions: [health_check]
  telemetry:
    metrics:
      address: 0.0.0.0:8888
  pipelines:
    metrics:
      receivers: [otlp, prometheus/self]
      processors: [memory_limiter, resourcedetection, batch]
      exporters: [prometheusremotewrite]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, resourcedetection, batch]
      exporters: [otlphttp/logs]
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resourcedetection, batch]
      exporters: [otlphttp/tempo]
```

- [ ] **Step 3: Validate the YAML**

```bash
python3 -c "import yaml; yaml.safe_load(open('/home/hameem/workspace/OTel-jps/configs/otel-collector/config.yaml'))" && echo OK
```

Expected: prints `OK`.

- [ ] **Step 4: Add the `otel-collector` service block to `docker-compose.yml`**

Append to `services:` in `/home/hameem/workspace/OTel-jps/docker-compose.yml`:

```yaml
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.111.0
    container_name: otel-jps-otelcol
    restart: unless-stopped
    networks:
      - obs-net
    command: ["--config=/etc/otelcol-contrib/config.yaml"]
    volumes:
      - ./configs/otel-collector/config.yaml:/etc/otelcol-contrib/config.yaml:ro
    expose:
      - "4317"   # gRPC OTLP (Caddy fronts this)
      - "4318"   # HTTP OTLP
      - "8888"   # Self-metrics
      - "13133"  # health_check
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:13133/"]
      interval: 30s
      timeout: 5s
      retries: 5
    depends_on:
      prometheus:
        condition: service_started
      victorialogs:
        condition: service_started
      tempo:
        condition: service_started
      pyroscope:
        condition: service_started
```

- [ ] **Step 5: Append resource limits to `compose/simple.yml`**

Append under `services:` in `/home/hameem/workspace/OTel-jps/compose/simple.yml`:

```yaml
  otel-collector:
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 96M
```

- [ ] **Step 6: Validate (with `depends_on` temporarily commented since prometheus/etc. don't exist yet)**

Comment out the `depends_on:` block under `otel-collector:` in `docker-compose.yml`, then:

```bash
cd /home/hameem/workspace/OTel-jps && \
  docker compose -f docker-compose.yml -f compose/simple.yml config --quiet && echo OK
```

Expected: prints `OK`. **Restore** `depends_on` immediately after.

- [ ] **Step 7: Commit (with `depends_on` restored)**

```bash
git -C /home/hameem/workspace/OTel-jps add configs/otel-collector/ docker-compose.yml compose/simple.yml
git -C /home/hameem/workspace/OTel-jps commit -m "feat: add OpenTelemetry Collector contrib with OTLP fan-out"
```

---

## Task 8: Prometheus

**Files:**
- Create: `configs/prometheus/prometheus.yml`
- Modify: `docker-compose.yml` — append `prometheus` service
- Modify: `compose/simple.yml` — append `prometheus` deploy limits

- [ ] **Step 1: Create the directory**

```bash
mkdir -p /home/hameem/workspace/OTel-jps/configs/prometheus
```

- [ ] **Step 2: Write `prometheus.yml`**

Path: `/home/hameem/workspace/OTel-jps/configs/prometheus/prometheus.yml`

```yaml
# Prometheus config — Simple profile.
# Receives metrics via OTel Collector remote-write (push from collector → us).
# Self-scrapes own /metrics + scrapes other backends for stack health dashboards.

global:
  scrape_interval: 30s
  evaluation_interval: 30s
  external_labels:
    profile: simple

scrape_configs:
  - job_name: prometheus-self
    static_configs:
      - targets: ['localhost:9090']

  - job_name: otel-collector
    static_configs:
      - targets: ['otel-collector:8888']

  - job_name: tempo
    static_configs:
      - targets: ['tempo:3200']

  - job_name: pyroscope
    static_configs:
      - targets: ['pyroscope:4040']

  - job_name: grafana
    static_configs:
      - targets: ['grafana:3000']
    metrics_path: /metrics
```

- [ ] **Step 3: Validate**

```bash
python3 -c "import yaml; yaml.safe_load(open('/home/hameem/workspace/OTel-jps/configs/prometheus/prometheus.yml'))" && echo OK
```

Expected: `OK`.

- [ ] **Step 4: Append `prometheus` service to `docker-compose.yml`**

```yaml
  prometheus:
    image: prom/prometheus:v3.0.1
    container_name: otel-jps-prometheus
    restart: unless-stopped
    networks:
      - obs-net
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.time=${PROMETHEUS_RETENTION:-7d}
      - --web.enable-remote-write-receiver
      - --web.listen-address=0.0.0.0:9090
    volumes:
      - ./configs/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    expose:
      - "9090"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:9090/-/ready"]
      interval: 30s
      timeout: 5s
      retries: 5
```

- [ ] **Step 5: Append `prometheus` deploy limits to `compose/simple.yml`**

```yaml
  prometheus:
    deploy:
      resources:
        limits:
          memory: 384M
        reservations:
          memory: 128M
```

- [ ] **Step 6: Validate**

```bash
cd /home/hameem/workspace/OTel-jps && \
  docker compose -f docker-compose.yml -f compose/simple.yml config --quiet && echo OK
```

Expected: prints `OK` (some `depends_on` references may still complain — comment-out trick only if needed; restore before commit).

- [ ] **Step 7: Commit**

```bash
git -C /home/hameem/workspace/OTel-jps add configs/prometheus/ docker-compose.yml compose/simple.yml
git -C /home/hameem/workspace/OTel-jps commit -m "feat: add Prometheus with remote-write receiver and self-scraping"
```

---

## Task 9: VictoriaLogs

**Files:**
- Modify: `docker-compose.yml` — append `victorialogs` service (no config file)
- Modify: `compose/simple.yml` — append `victorialogs` deploy limits

- [ ] **Step 1: Append `victorialogs` service to `docker-compose.yml`**

```yaml
  victorialogs:
    image: victoriametrics/victoria-logs:v1.1.0-victorialogs
    container_name: otel-jps-victorialogs
    restart: unless-stopped
    networks:
      - obs-net
    command:
      - --storageDataPath=/vlogs
      - --retentionPeriod=${VICTORIALOGS_RETENTION:-7d}
      - --httpListenAddr=0.0.0.0:9428
      - --loggerLevel=INFO
    volumes:
      - victorialogs_data:/vlogs
    expose:
      - "9428"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:9428/health"]
      interval: 30s
      timeout: 5s
      retries: 5
```

- [ ] **Step 2: Append deploy limits to `compose/simple.yml`**

```yaml
  victorialogs:
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 64M
```

- [ ] **Step 3: Validate**

```bash
cd /home/hameem/workspace/OTel-jps && \
  docker compose -f docker-compose.yml -f compose/simple.yml config --quiet && echo OK
```

Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git -C /home/hameem/workspace/OTel-jps add docker-compose.yml compose/simple.yml
git -C /home/hameem/workspace/OTel-jps commit -m "feat: add VictoriaLogs as logs backend (filesystem storage)"
```

---

## Task 10: Tempo (monolithic, filesystem storage)

**Files:**
- Create: `configs/tempo/tempo.yaml`
- Modify: `docker-compose.yml` — append `tempo` service
- Modify: `compose/simple.yml` — append `tempo` deploy limits

- [ ] **Step 1: Create the directory**

```bash
mkdir -p /home/hameem/workspace/OTel-jps/configs/tempo
```

- [ ] **Step 2: Write `tempo.yaml`**

Path: `/home/hameem/workspace/OTel-jps/configs/tempo/tempo.yaml`

```yaml
# Tempo monolithic config — Simple profile.
# Filesystem storage; no S3.

stream_over_http_enabled: true

server:
  http_listen_port: 3200
  grpc_listen_port: 9095

distributor:
  receivers:
    otlp:
      protocols:
        http:
          endpoint: 0.0.0.0:4318
        grpc:
          endpoint: 0.0.0.0:4317

ingester:
  trace_idle_period: 10s
  max_block_bytes: 100_000_000
  max_block_duration: 5m

compactor:
  compaction:
    block_retention: ${TEMPO_RETENTION_HOURS:-72}h

storage:
  trace:
    backend: local
    local:
      path: /var/tempo/blocks
    wal:
      path: /var/tempo/wal

metrics_generator:
  registry:
    external_labels:
      source: tempo
  storage:
    path: /var/tempo/generator/wal
    remote_write:
      - url: http://prometheus:9090/api/v1/write

overrides:
  defaults:
    metrics_generator:
      processors: [service-graphs, span-metrics]
```

- [ ] **Step 3: Validate**

```bash
python3 -c "import yaml; yaml.safe_load(open('/home/hameem/workspace/OTel-jps/configs/tempo/tempo.yaml'))" && echo OK
```

Expected: `OK`.

- [ ] **Step 4: Append `tempo` service to `docker-compose.yml`**

```yaml
  tempo:
    image: grafana/tempo:2.6.1
    container_name: otel-jps-tempo
    restart: unless-stopped
    networks:
      - obs-net
    command: ["-config.file=/etc/tempo/tempo.yaml"]
    volumes:
      - ./configs/tempo/tempo.yaml:/etc/tempo/tempo.yaml:ro
      - tempo_data:/var/tempo
    expose:
      - "3200"   # HTTP query
      - "4317"   # OTLP gRPC (collector pushes here directly via grpc when needed)
      - "4318"   # OTLP HTTP (collector pushes here)
      - "9095"   # gRPC native
    environment:
      TEMPO_RETENTION_HOURS: ${TEMPO_RETENTION_HOURS:-72}
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3200/ready"]
      interval: 30s
      timeout: 5s
      retries: 5
```

- [ ] **Step 5: Append deploy limits to `compose/simple.yml`**

```yaml
  tempo:
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 192M
```

- [ ] **Step 6: Validate**

```bash
cd /home/hameem/workspace/OTel-jps && \
  docker compose -f docker-compose.yml -f compose/simple.yml config --quiet && echo OK
```

Expected: `OK`.

- [ ] **Step 7: Commit**

```bash
git -C /home/hameem/workspace/OTel-jps add configs/tempo/ docker-compose.yml compose/simple.yml
git -C /home/hameem/workspace/OTel-jps commit -m "feat: add Tempo monolithic with filesystem storage"
```

---

## Task 11: Pyroscope

**Files:**
- Create: `configs/pyroscope/pyroscope.yaml`
- Modify: `docker-compose.yml` — append `pyroscope` service
- Modify: `compose/simple.yml` — append `pyroscope` deploy limits

- [ ] **Step 1: Create the directory**

```bash
mkdir -p /home/hameem/workspace/OTel-jps/configs/pyroscope
```

- [ ] **Step 2: Write `pyroscope.yaml`**

Path: `/home/hameem/workspace/OTel-jps/configs/pyroscope/pyroscope.yaml`

```yaml
# Pyroscope monolithic config — Simple profile.

server:
  http_listen_port: 4040

storage:
  backend: filesystem
  filesystem:
    dir: /data/pyroscope

pyroscopedb:
  data_path: /data/pyroscope-db

limits:
  retention_period: ${PYROSCOPE_RETENTION_HOURS:-336}h
  max_query_lookback: 720h
  ingestion_rate_mb: 12
  ingestion_burst_size_mb: 24

analytics:
  reporting_enabled: false
```

- [ ] **Step 3: Validate**

```bash
python3 -c "import yaml; yaml.safe_load(open('/home/hameem/workspace/OTel-jps/configs/pyroscope/pyroscope.yaml'))" && echo OK
```

Expected: `OK`.

- [ ] **Step 4: Append `pyroscope` service to `docker-compose.yml`**

```yaml
  pyroscope:
    image: grafana/pyroscope:1.10.0
    container_name: otel-jps-pyroscope
    restart: unless-stopped
    networks:
      - obs-net
    command: ["-config.file=/etc/pyroscope/pyroscope.yaml"]
    volumes:
      - ./configs/pyroscope/pyroscope.yaml:/etc/pyroscope/pyroscope.yaml:ro
      - pyroscope_data:/data
    expose:
      - "4040"
    environment:
      PYROSCOPE_RETENTION_HOURS: ${PYROSCOPE_RETENTION_HOURS:-336}
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:4040/ready"]
      interval: 30s
      timeout: 5s
      retries: 5
```

- [ ] **Step 5: Append deploy limits to `compose/simple.yml`**

```yaml
  pyroscope:
    deploy:
      resources:
        limits:
          memory: 384M
        reservations:
          memory: 128M
```

- [ ] **Step 6: Validate**

```bash
cd /home/hameem/workspace/OTel-jps && \
  docker compose -f docker-compose.yml -f compose/simple.yml config --quiet && echo OK
```

Expected: `OK`.

- [ ] **Step 7: Commit**

```bash
git -C /home/hameem/workspace/OTel-jps add configs/pyroscope/ docker-compose.yml compose/simple.yml
git -C /home/hameem/workspace/OTel-jps commit -m "feat: add Pyroscope with filesystem storage and retention limits"
```

---

## Task 12: Grafana with auto-provisioned datasources

**Files:**
- Create: `configs/grafana/provisioning/datasources/all.yaml`
- Create: `configs/grafana/provisioning/dashboards/dashboards.yaml`
- Create: `configs/grafana/dashboards/.keep` (empty marker; dashboards land in Phase 2)
- Modify: `docker-compose.yml` — append `grafana` service
- Modify: `compose/simple.yml` — append `grafana` deploy limits

- [ ] **Step 1: Create the provisioning directory tree**

```bash
mkdir -p /home/hameem/workspace/OTel-jps/configs/grafana/provisioning/datasources
mkdir -p /home/hameem/workspace/OTel-jps/configs/grafana/provisioning/dashboards
mkdir -p /home/hameem/workspace/OTel-jps/configs/grafana/dashboards
touch /home/hameem/workspace/OTel-jps/configs/grafana/dashboards/.keep
```

- [ ] **Step 2: Write the datasource provisioning file**

Path: `/home/hameem/workspace/OTel-jps/configs/grafana/provisioning/datasources/all.yaml`

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    uid: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    jsonData:
      timeInterval: 30s
      exemplarTraceIdDestinations:
        - name: trace_id
          datasourceUid: tempo
    editable: true

  - name: VictoriaLogs
    type: victoriametrics-logs-datasource
    uid: victorialogs
    access: proxy
    url: http://victorialogs:9428
    jsonData:
      maxLines: 1000
    editable: true

  - name: Tempo
    type: tempo
    uid: tempo
    access: proxy
    url: http://tempo:3200
    jsonData:
      tracesToLogsV2:
        datasourceUid: victorialogs
        spanStartTimeShift: -1m
        spanEndTimeShift: 1m
        tags: ['service.name', 'service']
        filterByTraceID: true
      tracesToProfilesV2:
        datasourceUid: pyroscope
        tags: ['service.name', 'service']
        profileTypeId: process_cpu:cpu:nanoseconds:cpu:nanoseconds
      serviceMap:
        datasourceUid: prometheus
      nodeGraph:
        enabled: true
    editable: true

  - name: Pyroscope
    type: grafana-pyroscope-datasource
    uid: pyroscope
    access: proxy
    url: http://pyroscope:4040
    editable: true
```

- [ ] **Step 3: Write the dashboard provisioning file (registers `/etc/grafana/dashboards` as a directory; Phase 2 fills it with JSON)**

Path: `/home/hameem/workspace/OTel-jps/configs/grafana/provisioning/dashboards/dashboards.yaml`

```yaml
apiVersion: 1

providers:
  - name: 'OTel-jps default dashboards'
    orgId: 1
    folder: 'OTel-jps'
    type: file
    disableDeletion: false
    editable: true
    updateIntervalSeconds: 30
    options:
      path: /etc/grafana/dashboards
      foldersFromFilesStructure: true
```

- [ ] **Step 4: Validate**

```bash
python3 -c "import yaml; yaml.safe_load(open('/home/hameem/workspace/OTel-jps/configs/grafana/provisioning/datasources/all.yaml'))" && \
python3 -c "import yaml; yaml.safe_load(open('/home/hameem/workspace/OTel-jps/configs/grafana/provisioning/dashboards/dashboards.yaml'))" && \
echo OK
```

Expected: `OK`.

- [ ] **Step 5: Append `grafana` service to `docker-compose.yml`**

```yaml
  grafana:
    image: grafana/grafana:11.3.0
    container_name: otel-jps-grafana
    restart: unless-stopped
    networks:
      - obs-net
    volumes:
      - ./configs/grafana/provisioning:/etc/grafana/provisioning:ro
      - ./configs/grafana/dashboards:/etc/grafana/dashboards:ro
      - grafana_data:/var/lib/grafana
    environment:
      GF_SECURITY_ADMIN_USER: ${GRAFANA_ADMIN_USER:-admin}
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD:-changeme}
      GF_USERS_ALLOW_SIGN_UP: "false"
      GF_AUTH_ANONYMOUS_ENABLED: "false"
      GF_INSTALL_PLUGINS: victoriametrics-logs-datasource,grafana-pyroscope-datasource
      GF_FEATURE_TOGGLES_ENABLE: traceToProfiles tracesEmbeddedFlameGraph
      GF_SERVER_ROOT_URL: ${GF_SERVER_ROOT_URL:-https://${DOMAIN:-localhost}/}
    expose:
      - "3000"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 5s
      retries: 5
    depends_on:
      prometheus:
        condition: service_started
      victorialogs:
        condition: service_started
      tempo:
        condition: service_started
      pyroscope:
        condition: service_started
```

- [ ] **Step 6: Append deploy limits to `compose/simple.yml`**

```yaml
  grafana:
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 96M
```

- [ ] **Step 7: Validate**

```bash
cd /home/hameem/workspace/OTel-jps && \
  docker compose -f docker-compose.yml -f compose/simple.yml config --quiet && echo OK
```

Expected: `OK`.

- [ ] **Step 8: Commit**

```bash
git -C /home/hameem/workspace/OTel-jps add configs/grafana/ docker-compose.yml compose/simple.yml
git -C /home/hameem/workspace/OTel-jps commit -m "feat: add Grafana with auto-provisioned datasources for Prom/VLogs/Tempo/Pyroscope"
```

---

## Task 13: `scripts/verify_stack.sh` (parameterized health check)

**Files:**
- Replace: `/home/hameem/workspace/OTel-jps/scripts/verify_stack.sh`

- [ ] **Step 1: Inspect the current script**

```bash
cat /home/hameem/workspace/OTel-jps/scripts/verify_stack.sh
```

Expected: hardcoded domain, only checks 3 services. We're rewriting it.

- [ ] **Step 2: Write the new `verify_stack.sh`**

Path: `/home/hameem/workspace/OTel-jps/scripts/verify_stack.sh`

```bash
#!/usr/bin/env bash
# verify_stack.sh — health-check every component in the OTel-jps stack.
# Usage: ./scripts/verify_stack.sh
# Exits 0 if all components are healthy, non-zero otherwise.

set -euo pipefail

DOMAIN="${DOMAIN:-localhost}"
SCHEME="${SCHEME:-https}"
TIMEOUT="${TIMEOUT:-10}"

# Component → (container name, internal endpoint, expected substring or empty for HTTP 200)
declare -A CHECKS=(
  ["caddy"]="otel-jps-caddy|http://localhost:2019/config/|"
  ["otel-collector"]="otel-jps-otelcol|http://localhost:13133/|"
  ["prometheus"]="otel-jps-prometheus|http://localhost:9090/-/ready|Prometheus is Ready"
  ["victorialogs"]="otel-jps-victorialogs|http://localhost:9428/health|"
  ["tempo"]="otel-jps-tempo|http://localhost:3200/ready|ready"
  ["pyroscope"]="otel-jps-pyroscope|http://localhost:4040/ready|"
  ["grafana"]="otel-jps-grafana|http://localhost:3000/api/health|database"
)

PASS=0
FAIL=0
RESULTS=()

check_component() {
  local name="$1"
  local container="$2"
  local url="$3"
  local expected="$4"

  if ! docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null | grep -q running; then
    RESULTS+=("FAIL $name (container not running)")
    return 1
  fi

  local body
  if ! body="$(docker exec "$container" wget -qO- --timeout="$TIMEOUT" "$url" 2>&1)"; then
    RESULTS+=("FAIL $name (HTTP request failed: $url)")
    return 1
  fi

  if [[ -n "$expected" ]] && ! echo "$body" | grep -q "$expected"; then
    RESULTS+=("FAIL $name (expected '$expected' in response)")
    return 1
  fi

  RESULTS+=("PASS $name")
  return 0
}

echo "── OTel-jps stack verification ──────────────────"
for name in caddy otel-collector prometheus victorialogs tempo pyroscope grafana; do
  IFS='|' read -r container url expected <<< "${CHECKS[$name]}"
  if check_component "$name" "$container" "$url" "$expected"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
  fi
done

printf '\n'
for r in "${RESULTS[@]}"; do
  echo "  $r"
done

printf '\n── %d passed, %d failed ─────────────────────────\n' "$PASS" "$FAIL"

if (( FAIL > 0 )); then
  exit 1
fi

# Smoke: send an OTLP HTTP trace request through Caddy
echo "── OTLP smoke test ──────────────────────────────"
if [[ "${BASIC_AUTH_USER:-}" && "${BASIC_AUTH_PASSWORD:-}" ]]; then
  CURL_AUTH=(-u "${BASIC_AUTH_USER}:${BASIC_AUTH_PASSWORD}")
else
  echo "  (skipping; set BASIC_AUTH_USER and BASIC_AUTH_PASSWORD to test ingestion)"
  CURL_AUTH=()
fi

if (( ${#CURL_AUTH[@]} > 0 )); then
  HTTP_CODE="$(curl -k -sS -o /dev/null -w '%{http_code}' \
    "${CURL_AUTH[@]}" \
    -H 'Content-Type: application/json' \
    -d '{"resourceSpans":[]}' \
    "${SCHEME}://${DOMAIN}/v1/traces" || true)"

  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    echo "  PASS OTLP HTTP traces endpoint (HTTP $HTTP_CODE)"
  else
    echo "  FAIL OTLP HTTP traces endpoint (HTTP $HTTP_CODE)"
    exit 1
  fi
fi

echo "✅ All checks passed."
```

- [ ] **Step 3: Make it executable and validate syntax**

```bash
chmod +x /home/hameem/workspace/OTel-jps/scripts/verify_stack.sh
bash -n /home/hameem/workspace/OTel-jps/scripts/verify_stack.sh && echo OK
```

Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git -C /home/hameem/workspace/OTel-jps add scripts/verify_stack.sh
git -C /home/hameem/workspace/OTel-jps commit -m "refactor: rewrite verify_stack.sh — parameterized, all 7 components"
```

---

## Task 14: `Makefile` shortcuts

**Files:**
- Create: `/home/hameem/workspace/OTel-jps/Makefile`

- [ ] **Step 1: Write the Makefile**

Path: `/home/hameem/workspace/OTel-jps/Makefile`

```makefile
# OTel-jps developer shortcuts
.DEFAULT_GOAL := help

COMPOSE       := docker compose -f docker-compose.yml
SIMPLE_FLAGS  := -f compose/simple.yml

.PHONY: help simple stop restart logs verify update config clean

help: ## Show this help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

simple: ## Bring up the Simple profile (default for v1).
	$(COMPOSE) $(SIMPLE_FLAGS) up -d
	@echo ""
	@echo "Stack starting... give it ~30s, then run: make verify"

stop: ## Stop the running stack (Simple).
	$(COMPOSE) $(SIMPLE_FLAGS) down

restart: stop simple ## Restart the Simple stack.

logs: ## Tail logs from all services (Ctrl-C to exit).
	$(COMPOSE) $(SIMPLE_FLAGS) logs -f --tail=100

verify: ## Run end-to-end stack verification.
	./scripts/verify_stack.sh

update: ## Pull latest images and recreate containers.
	$(COMPOSE) $(SIMPLE_FLAGS) pull
	$(COMPOSE) $(SIMPLE_FLAGS) up -d

config: ## Show the resolved compose config.
	$(COMPOSE) $(SIMPLE_FLAGS) config

clean: ## Stop stack AND remove volumes (DESTRUCTIVE — wipes all data).
	@echo "This will delete all telemetry data. Press Ctrl-C to abort, Enter to continue."
	@read _
	$(COMPOSE) $(SIMPLE_FLAGS) down -v
```

- [ ] **Step 2: Validate Makefile syntax**

```bash
make -C /home/hameem/workspace/OTel-jps -n simple
```

Expected: prints the commands `make simple` would run, without errors.

- [ ] **Step 3: Commit**

```bash
git -C /home/hameem/workspace/OTel-jps add Makefile
git -C /home/hameem/workspace/OTel-jps commit -m "feat: add Makefile with shortcuts (simple/stop/logs/verify/update)"
```

---

## Task 15: End-to-end smoke test

This task brings the stack up on a real machine and confirms each component is reachable, healthy, and serving its expected role.

- [ ] **Step 1: Copy `.env.example` → `.env` (skip if `.env` already exists)**

```bash
cd /home/hameem/workspace/OTel-jps && \
  ([[ -f .env ]] || cp .env.example .env)
```

- [ ] **Step 2: Set a dev basic-auth hash for ingestion testing**

```bash
cd /home/hameem/workspace/OTel-jps && \
  HASH="$(docker run --rm caddy:2-alpine caddy hash-password --plaintext 'devpass')" && \
  echo "Generated hash: $HASH" && \
  sed -i.bak "s|^BASIC_AUTH_HASH=.*|BASIC_AUTH_HASH=${HASH}|" .env && \
  rm .env.bak
```

Then export the plaintext for the verify script:
```bash
export BASIC_AUTH_USER=ingest
export BASIC_AUTH_PASSWORD=devpass
```

- [ ] **Step 3: Bring the stack up**

```bash
cd /home/hameem/workspace/OTel-jps && make simple
```

Expected: each container reaches `Started` state. Wait ~45 s for healthchecks to settle.

- [ ] **Step 4: Verify all services healthy**

```bash
cd /home/hameem/workspace/OTel-jps && docker compose -f docker-compose.yml -f compose/simple.yml ps
```

Expected: all 7 services `Up (healthy)`.

- [ ] **Step 5: Run `verify_stack.sh`**

```bash
cd /home/hameem/workspace/OTel-jps && SCHEME=https DOMAIN=localhost make verify
```

Expected: prints `7 passed, 0 failed` and `PASS OTLP HTTP traces endpoint`. Final line: `✅ All checks passed.`

- [ ] **Step 6: Open Grafana in a browser**

Visit `https://localhost/` (accept self-signed cert).

Login: `admin` / value of `GRAFANA_ADMIN_PASSWORD` from `.env`.

Confirm under **Connections → Data sources** that all 4 are present:
- Prometheus (default)
- VictoriaLogs
- Tempo
- Pyroscope

Each should show "Data source is working" when its **Test** button is clicked.

- [ ] **Step 7: Check idle memory budget**

```bash
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}'
```

Expected: total `MemUsage` summed across all 7 containers ≤ 1.5 GB. If significantly higher, review the resource limits in `compose/simple.yml`.

- [ ] **Step 8: Tag the milestone**

```bash
git -C /home/hameem/workspace/OTel-jps tag -a v1.0.0-alpha.1 -m "Phase 1 complete: core stack boots, all components healthy"
```

(No push — leave that for the user to perform manually per global no-auto-push rule.)

---

## Phase 1 Acceptance Criteria

- [ ] `make simple` brings up 7 containers on a fresh Ubuntu 24.04 box with 4 GB RAM
- [ ] Total stack RAM at idle ≤ 1.5 GB (per `docker stats`); system + Docker total ≤ 2.2 GB
- [ ] `make verify` exits 0 with all 7 components passing
- [ ] Grafana opens at `https://${DOMAIN}/` with all 4 datasources auto-provisioned and testable
- [ ] OTLP HTTP endpoint at `https://${DOMAIN}/v1/traces` accepts POST with basic auth and returns 2xx for an empty-spans payload
- [ ] All commits follow conventional commit format (`feat:`, `refactor:`, `chore:`, `docs:`)
- [ ] No legacy artifacts remain (`logs.txt`, root-level `manifest.jps`, `addons/`, `nginx/`, `configs/alloy/`, `configs/mimir.yaml`, `configs/loki.yaml`, `scripts/init_buckets.sh`)

When all criteria pass, Phase 1 is done. Move to writing the Phase 2 plan (Stack Polish: self-monitoring, dashboards, alerts, OTel demo overlay).

---

## Notes & Gotchas for the Engineer

- **VictoriaLogs OTLP endpoint** — `/insert/opentelemetry` is the documented path as of mid-2024; if the VictoriaLogs version pinned in Task 9 changes the route, the OTel Collector exporter URL in Task 7 must be updated to match.
- **Pyroscope OTLP profile signal** — the profiles signal is relatively new in OTel; older OTel Collector contrib versions may not include the `otlphttp/pyroscope` exporter named that way. If the collector fails to start because of an unknown exporter, downgrade the profiles export pipeline to send via Pyroscope's native ingest endpoint instead, and remove the `profiles:` pipeline from the service block.
- **Grafana plugin name** — `victoriametrics-logs-datasource` is the published plugin name as of late 2024. If the install fails, run `docker exec otel-jps-grafana grafana-cli plugins list-remote | grep -i victorialogs` to discover the current name.
- **Self-signed cert acceptance** — when `DOMAIN=localhost`, browsers will warn. Accept the cert manually for dev. CI smoke tests use `curl -k` to bypass.
- **Image pinning** — every image is pinned to a specific tag, not `:latest`. When upgrading, do it in a single PR with rationale in CHANGELOG and a smoke test.
- **The `depends_on` trick** during early tasks (commenting out, then restoring) is a deliberate workaround so each task validates standalone; once all tasks land, the `depends_on` chain works correctly.
