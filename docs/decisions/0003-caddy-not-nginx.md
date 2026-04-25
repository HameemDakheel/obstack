# ADR 0003: Caddy over Nginx for the reverse proxy

**Status:** Accepted
**Date:** 2026-04-25

## Context

The stack needs a reverse proxy that handles three jobs:

1. TLS termination (Let's Encrypt for real domains, self-signed for `localhost`)
2. Basic auth on OTLP ingestion endpoints
3. Reverse-proxy routing (Grafana on `/`, OTel Collector on `/v1/*`, gRPC on `:4317`)

Three candidates:
- **Nginx** — the industry standard. Requires Certbot for Let's Encrypt, plus separate ACME challenge config and renewal cron.
- **Caddy v2** — newer, ships with automatic HTTPS via Let's Encrypt out of the box. Single binary. ~30 MB memory.
- **Traefik** — popular in Kubernetes ecosystems but heavier (~80 MB) and tuned for service-discovery use cases that don't apply at single-node Simple profile.

The wedge is *"production observability for self-hosters."* The r/selfhosted and indie-SaaS communities — our beachhead — strongly prefer Caddy for its zero-friction TLS.

## Decision

Use **Caddy v2** as the reverse proxy at Simple profile.

## Consequences

**Positive:**
- **Auto-TLS in 3 lines of Caddyfile.** No certbot. No renewal cron. No ACME challenge endpoints. Caddy handles renewals automatically before expiry.
- **Single binary** (~30 MB resident at runtime) — fits comfortably in the RAM budget.
- **Familiar to the target audience** — Coolify, Dokploy, and most modern self-host PaaS bundle Caddy or recommend it.
- **Cleaner config** — Caddyfile is much shorter than equivalent nginx + certbot setup. The obstack Caddyfile is ~30 lines including comments.

**Negative:**
- Smaller community than Nginx (~50K vs ~22K GitHub stars; broader Stack Overflow corpus for Nginx).
- Nginx has more battle-tested edge-case behavior at internet-scale; not a concern at single-VPS.
- Some advanced load-balancing features (e.g. `upstream` weighted load balancing with health checks) are easier in Nginx — irrelevant for our single-node stack.

**Neutral:**
- Both can do everything we need. The difference is operator ergonomics, not capability.
- At Scale profile, Caddy still works; or operators may swap to Nginx for advanced LB. Documented in the upgrade path.

## References

- [Caddy automatic HTTPS](https://caddyserver.com/docs/automatic-https)
- [Caddy vs Nginx vs Traefik 2026 comparison](https://selfhostwise.com/posts/traefik-vs-caddy-vs-nginx-proxy-manager-which-reverse-proxy-should-you-choose-in-2026/)
- [Spec §4.1 — Stack selection](../superpowers/specs/2026-04-25-obstack-redesign.md)
