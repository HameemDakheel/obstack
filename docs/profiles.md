# Profiles

> **Audience:** anyone deciding which profile to deploy or planning to scale up. Read after [Architecture](architecture.md).

obstack ships as one product with four profiles — different tunings of the same components for different deployment shapes. You pick what your machine and team can operate today. You can switch profiles later.

---

## Why profiles?

A self-hoster on a $20/month VPS and an enterprise running multi-region observability have radically different needs but want the *same product*. Forcing one to operate the other's complexity, or shipping two products with diverged code, both fail.

Profiles solve this by:

- **Sharing the base `docker-compose.yml`** — same image versions, same service definitions, same network.
- **Layering profile-specific overlays** (`compose/<profile>.yml`) for resource limits, retention values, replica counts, HA toggles.
- **Shared documentation** — operators learn one set of operational concepts.

Most users never need to "upgrade" between profiles — they pick once and stay.

---

## Comparison table

| Profile | Target | RAM idle / peak | Retention | HA | Auth | Storage | Status |
|---------|--------|-----------------|-----------|----|----|---------|--------|
| **Simple** | Solo dev / indie SaaS, single VPS | ≤2 GB / ≤4 GB | 7 d | No | Caddy basic auth + Grafana login | Filesystem | ✅ **v1.0** |
| **Standard** | Small team, single server (8 GB) | ≤4 GB / ≤8 GB | 30 d | No | Caddy basic auth + Grafana login | Filesystem (optional MinIO) | ✅ **v1.1** |
| **Scale** | Growing team, multi-node | 16 GB+ | 90 d | Mimir HA / Loki HA / VictoriaMetrics cluster | OAuth2 + SSO | MinIO or external S3 | 🔜 v2 |
| **Enterprise** | Regulated / compliance | Sized to load | 1+ year | Full HA + DR + replication | SAML, audit logs, multi-tenant | External S3 + replication | 🔜 v3 |

---

## How profiles work mechanically

Profiles are **docker-compose overlay files**. The base file declares everything; overlays add per-profile constraints.

### Base file

`docker-compose.yml` declares:
- All 8 service definitions (Caddy, OTel Collector, Prometheus, VictoriaLogs, Tempo, Pyroscope, Grafana, cAdvisor)
- All named volumes
- The `obs-net` bridge network
- All `depends_on` ordering

It does **not** set:
- Resource limits (`deploy.resources.limits`)
- Replica counts
- Profile-specific env vars

### Profile overlay

`compose/simple.yml` adds Simple-specific constraints:

```yaml
services:
  caddy:
    deploy:
      resources:
        limits:
          memory: 128M
        reservations:
          memory: 32M
  prometheus:
    deploy:
      resources:
        limits:
          memory: 384M
        reservations:
          memory: 128M
  # ... per service
```

Other profiles (`compose/standard.yml`, `compose/scale.yml`) are placeholders at v1; they ship in their respective releases.

### Running a profile

```bash
# Default
docker compose -f docker-compose.yml -f compose/simple.yml up -d

# Or via Makefile
make simple
```

The Makefile shortcut hides the multi-`-f` syntax. Other shortcuts:

```bash
make stop         # docker compose ... down
make restart      # stop + simple
make logs         # tail logs
make verify       # run scripts/verify_stack.sh
make update       # pull images + recreate containers
make standard     # bring up the Standard profile (8 GB host)
make demo-up      # bring up the standalone examples/otel-demo (external client)
make demo-down    # stop the demo client
make config       # show the resolved compose config
make clean        # destructive: stops and removes all volumes
```

---

## Choosing a profile

Use this decision tree:

```
Single VPS, ≤4 GB RAM?
   ├─ yes → Simple
   └─ no, single server with 8+ GB?
            ├─ yes, no HA needed → Standard (when v1.1 ships; for now use Simple)
            └─ no, multi-node?
                     ├─ yes → Scale (when v2 ships)
                     └─ multi-tenant / compliance?
                              └─ Enterprise (when v3 ships)
```

**At v1.1, Simple and Standard are shipped.** Operators on bigger machines can run Simple and just have headroom — there's no penalty for running below the profile's intended scale.

---

## Upgrading between profiles

Upgrading is **not yet implemented at v1**. The Standard / Scale / Enterprise profiles are placeholders. When they ship, the upgrade procedure will look like:

### Simple → Standard

Same components, expanded limits and retention. Operations are:
1. Stop the stack (`make stop`).
2. Edit `.env` to extend retention values (e.g. `PROMETHEUS_RETENTION=30d`).
3. `docker compose -f docker-compose.yml -f compose/standard.yml up -d`.

Data persists across the swap — same volumes, same components, same query languages.

### Simple → Scale

This is a real migration: Prometheus → VictoriaMetrics cluster (or Mimir), filesystem → MinIO/S3. Documented in detail when v2 ships. Expected steps:
1. Add MinIO to compose.
2. Use migration scripts to upload existing TSDB blocks to S3.
3. Switch the Prometheus image to a Mimir-monolithic or VictoriaMetrics-cluster instance.
4. Add additional replica nodes via Docker Swarm or external orchestration.

### Standard → Enterprise

Adds SSO/SAML, audit logging, multi-tenant routing (X-Scope-OrgID), and replicated storage. Compliance-driven.

---

## Profile-specific knobs

### Simple profile

Tunables via `.env`:

| Knob | Default | Effect |
|------|---------|--------|
| `PROMETHEUS_RETENTION` | `7d` | How long Prometheus keeps metrics |
| `VICTORIALOGS_RETENTION` | `7d` | How long VictoriaLogs keeps logs |
| `TEMPO_RETENTION_HOURS` | `72` | How long Tempo keeps trace blocks |
| `PYROSCOPE_RETENTION_HOURS` | `336` | How long Pyroscope keeps profiles (default 14 d) |

Container limits are in `compose/simple.yml`. Adjust with caution — e.g. raising Prometheus memory headroom is fine, lowering Caddy below 64 MB will OOM under TLS handshakes.

## Standard profile

Targets a small team running on a single beefy server (~8 GB RAM). Same components as Simple — bigger limits, longer retention, no HA.

### Tunables (Standard profile defaults)

| Knob | Standard default | Effect |
|------|------------------|--------|
| `PROMETHEUS_RETENTION` | `30d` | Metrics retained for a month |
| `VICTORIALOGS_RETENTION` | `30d` | Logs retained for a month |
| `TEMPO_RETENTION_HOURS` | `168` | Trace blocks retained for 7 d |
| `PYROSCOPE_RETENTION_HOURS` | `720` | Profiles retained for 30 d |

Set these in `.env` (commented examples included in `.env.example` under "Standard profile defaults").

### Resource limits

Bumped per service in `compose/standard.yml`:

| Service | Simple | Standard |
|---------|--------|----------|
| Prometheus | 384M | **768M** |
| VictoriaLogs | 256M | **384M** |
| Tempo | 512M | **768M** |
| Pyroscope | 384M | **512M** |
| OTel Collector | 256M | **384M** |
| Grafana | 256M | **384M** |
| Caddy | 128M | 128M (unchanged) |
| cAdvisor | 128M | 128M (unchanged) |

Total stack ceiling at Standard: ~3.4 GB. Realistic idle: ~700 MB-1.2 GB. Combined with OS overhead (~700 MB) you have **2.5-3 GB of headroom for queries, ingestion bursts, and your applications** on an 8 GB host.

### Running it

```bash
make standard         # bring up Standard profile
make standard-verify  # health check
make standard-stop    # tear down
```

### Future profiles (Scale, Enterprise)

Each future profile will document its own knobs in this file when it ships.

---

## Demo client (orthogonal to profiles)

The OTel demo lives at [`examples/otel-demo/`](https://github.com/HameemDakheel/obstack/tree/main/examples/otel-demo) as a **standalone compose project** — not an obstack profile or overlay. It runs a 7-service subset of the official OpenTelemetry demo and emits OTLP to obstack's *public* endpoint with HTTP Basic auth — exactly the path real customer applications use.

```bash
make demo-up    # configure .env, compute auth header, start demo
make demo-down  # stop demo
```

The demo needs ~6 GB RAM on its own. Running it alongside obstack on the same host means budgeting **12+ GB total**. Because it's a separate compose project, it shares no Docker network with obstack and stops cleanly without touching obstack's runtime.

See [`examples/otel-demo/README.md`](https://github.com/HameemDakheel/obstack/blob/main/examples/otel-demo/README.md) for full details.

---

## See also

- [Architecture](architecture.md) — what's inside the stack
- [Quickstart](quickstart.md) — get started
- [ADR 0001 — Hybrid stack](decisions/0001-hybrid-stack.md) — why these specific components
