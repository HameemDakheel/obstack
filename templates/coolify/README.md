# OTel-jps for Coolify

This template lets Coolify users deploy OTel-jps in a few clicks instead of running `git clone` and `make simple` manually on the server.

## Files

| File | Purpose |
|------|---------|
| `coolify-template.json` | Metadata for the Coolify Templates registry (name, description, env vars, logo) |
| `docker-compose.yml` | Coolify-tuned compose. Uses `${SERVICE_FQDN_GRAFANA}` for auto-issued domain. |

## Two install paths

### Path A — Add as a custom Compose resource

1. In Coolify, go to your project → **+ Add resource** → **Docker Compose Empty**.
2. Paste the contents of `docker-compose.yml` from this directory.
3. In the resource's **Environment Variables** tab, set:
   - `BASIC_AUTH_HASH` (required) — generate with `docker run --rm caddy:2-alpine caddy hash-password --plaintext 'YOUR_PASSWORD'`
   - `BASIC_AUTH_USER` (default `ingest`)
   - `GRAFANA_ADMIN_USER` (default `admin`)
   - `GRAFANA_ADMIN_PASSWORD` (Coolify can auto-generate)
   - Retention overrides (optional)
4. Coolify auto-binds the configured FQDN to Grafana via its proxy and issues a Let's Encrypt cert.
5. The compose file expects sibling files (Caddyfile, prometheus.yml, etc.) — see Path B for the recommended approach.

### Path B — Submit to the Coolify Templates registry (recommended for adoption)

The Coolify Templates registry at <https://github.com/coollabsio/coolify> accepts community-contributed templates via PR. See the registry's contribution guide for the exact format.

When approved, OTel-jps shows up in the **Add resource → Browse templates** picker and installs with one click — no manual paste.

## Persistent storage

Coolify stores Docker volumes under `/var/lib/docker/volumes/` on the underlying server. Volume names are prefixed by Coolify's project + resource UUID, but the in-container paths and our backup procedures (see [docs/operations/backup-restore.md](https://github.com/HameemDakheel/OTel-jps/blob/main/docs/operations/backup-restore.md)) work the same.

## TLS

Coolify's reverse proxy (Traefik or Caddy depending on your Coolify version) terminates TLS for the Grafana service automatically. The OTel-jps Caddy in the compose file handles TLS only for the OTLP gRPC port `:4317`, which Coolify exposes raw on the host port.

If you want TLS on `:4317` too, configure Coolify to add a TCP service entry, or front the gRPC port with another Coolify-managed reverse proxy that handles HTTP/2.

## Upgrade

Coolify exposes "Pull latest images and restart" in the resource UI. That's equivalent to running `make update` on the host. Volumes persist across image upgrades.

## See also

- [Coolify deployment guide](https://github.com/HameemDakheel/OTel-jps/blob/main/docs/deployment/coolify.md) — full step-by-step
- [Coolify documentation](https://coolify.io/docs/) — Coolify itself
- [Architecture](https://github.com/HameemDakheel/OTel-jps/blob/main/docs/architecture.md) — what's inside the stack
