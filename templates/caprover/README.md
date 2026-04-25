# obstack for CapRover

This template deploys obstack as a multi-service One-Click App in [CapRover](https://caprover.com).

## Files

| File | Purpose |
|------|---------|
| `caprover-one-click-app.yml` | Multi-service deployment definition (CapRover One-Click Apps schema) |
| `captain-definition` | Stub (CapRover scans for this file; the actual logic is in the YAML above) |

## How CapRover differs from Coolify/Dokploy

CapRover deploys **individual apps**, not compose stacks. The One-Click App pattern works around this by spawning **8 separate CapRover apps** that communicate over CapRover's internal `srv-captain--<name>` network:

| CapRover app | Purpose |
|--------------|---------|
| `<name>-grafana` | UI (auto-issued HTTPS subdomain) |
| `<name>-otelcol` | OTLP receiver / fan-out |
| `<name>-prometheus` | Metrics |
| `<name>-victorialogs` | Logs |
| `<name>-tempo` | Traces |
| `<name>-pyroscope` | Profiles |
| `<name>-cadvisor` | Container metrics |
| `<name>-caddy` | Reverse proxy + basic auth on OTLP |

Each one shows up in the CapRover dashboard separately. You can scale, restart, or upgrade them individually.

## Two install paths

### Path A — Paste the YAML manually (immediate)

1. Generate a basic-auth bcrypt hash on your local machine:

   ```bash
   docker run --rm caddy:2-alpine caddy hash-password --plaintext 'YOUR_PASSWORD'
   ```

2. In CapRover, go to **Apps → One-Click Apps/Databases** → search for `Insert any link/yaml here` field at the bottom (or the Custom YAML option).
3. Paste the contents of `caprover-one-click-app.yml`.
4. Fill in the prompted variables (the `BASIC_AUTH_HASH` field is the most important — paste your `$2a$14$...` from step 1).
5. Click **Deploy**. ~2-3 minutes.

### Path B — Submit to the official One-Click Apps repo

The CapRover One-Click Apps registry at <https://github.com/caprover/one-click-apps> accepts community submissions via PR. When approved, obstack appears in the **One-Click Apps/Databases** list directly — users get one-click install with no copy/paste.

## Persistent storage

CapRover uses named volumes prefixed `<app-name>-data`. Each backend gets its own:
- `<name>-prometheus-data`
- `<name>-victorialogs-data`
- `<name>-tempo-data`
- `<name>-pyroscope-data`
- `<name>-grafana-data`
- `<name>-caddy-data`

Backups via your CapRover host's standard volume backup procedure.

## Sibling config files

Each CapRover app needs to have its corresponding config file (Caddyfile, prometheus.yml, etc.) baked into a custom Docker image. The current YAML uses upstream images directly — for full functionality you'll need to either:

- **Override via CapRover's "Edit & Save Captain-Definition"** for each app, adding `dockerfileLines` that COPY the config files from this repo into the image, OR
- **Build & push custom images** with the configs baked in, then reference those in the YAML.

The simplest near-term path: clone the repo on the CapRover host, then bind-mount the configs from `/captain/data/<app>/` into each app's container via the CapRover UI's volume editor.

## Caveats

- **CapRover's One-Click Apps schema is less expressive than Compose.** Some niceties like depends-on healthcheck conditions and inline resource limits don't exist; CapRover apps default to "always restart, no resource limits."
- **Per-app HTTPS**: CapRover auto-issues HTTPS for `<name>-grafana` and `<name>-caddy` (anything with `notExposeAsWebApp: false`). All internal apps stay HTTP-only on the internal network.
- **Multi-service one-click apps are second-class** in CapRover compared to Coolify/Dokploy. Expect more manual config.

## See also

- [CapRover deployment guide](https://github.com/HameemDakheel/obstack/blob/main/docs/deployment/caprover.md) — full step-by-step
- [CapRover One-Click Apps documentation](https://caprover.com/docs/one-click-apps.html)
- [Architecture](https://github.com/HameemDakheel/obstack/blob/main/docs/architecture.md)
