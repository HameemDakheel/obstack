# OTel-jps Jelastic Templates

This directory contains the JPS (Jelastic Packaging Standard) manifests that turn OTel-jps into a one-click install in any Jelastic-based PaaS (mirohost, Hostinger Cloud, Layershift, J-elasticHost, OVH Jelastic Cloud, etc.).

## Files

| File | Type | What it does |
|------|------|--------------|
| `manifest.jps` | Install manifest | Provisions a Docker engine node, clones OTel-jps, generates credentials, runs `make simple` |
| `linker.jps` | Update manifest (add-on) | Injects OTLP env vars into other Jelastic apps so they send telemetry to a co-located OTel-jps environment |

## Install

In the Jelastic dashboard:

1. Click **Marketplace → Import** (or use the URL field).
2. Paste either the raw GitHub URL of `manifest.jps` or upload the file.
3. Pick environment name (defaults to `otel-jps`), domain, and optional alert webhook.
4. Click **Install**. ~3-5 minutes.
5. When complete, the success screen shows the Grafana URL and credentials.

Detailed walkthrough: [docs/deployment/jelastic.md](../../docs/deployment/jelastic.md).

## Linker (connecting other apps)

After OTel-jps is running, install `linker.jps` as an **add-on** on each application environment you want to instrument. It injects:

- `OTEL_EXPORTER_OTLP_ENDPOINT=https://<obs-domain>`
- `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf`
- `OTEL_EXPORTER_OTLP_HEADERS=authorization=Basic <base64>`
- `OTEL_SERVICE_NAME`, `OTEL_RESOURCE_ATTRIBUTES`, sampling config

Restart the target application — telemetry starts flowing immediately if the app uses an OpenTelemetry SDK.

## Architecture notes

- The Jelastic node runs **one** Docker engine; OTel-jps runs as 8 containers inside it.
- Persistent storage uses the node's local disk. For real production, mount a Jelastic Storage container and bind-mount it under `/var/lib/docker/volumes` if you need NFS-backed persistence.
- The Jelastic-issued domain (`*.jelastic.com` or your custom CNAME) is set automatically — Caddy auto-issues Let's Encrypt for it via the standard ACME flow.

## Versioning

- The manifest pins to a specific OTel-jps git tag (default `v1.0.0-alpha.4`). Bump the `repoRef` setting at install time to deploy a different release.
- The `upgrade` action runs `git fetch` + `make update` — preserves all telemetry data across upgrades.

## Caveats

- **Cloudlet sizing** — defaults to 24 max / 4 fixed cloudlets (~3 GB max RAM). If your provider uses smaller cloudlets, raise the limit.
- **Jelastic SSL toggle** — the manifest sets `ssl: true`, which means Jelastic's load balancer terminates TLS *in front of* Caddy. Caddy still has its own cert from Let's Encrypt for direct `:443` connections (e.g. OTLP gRPC on `:4317`), but if you only access Grafana via the Jelastic-issued domain, Jelastic's SLB will handle TLS.
- **OTLP gRPC on port 4317** — Jelastic must allow this port through its load balancer. Verify by checking the SLB rules in the Jelastic UI; add port 4317 if missing.
