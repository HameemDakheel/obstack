# obstack examples

Standalone reference workloads that integrate with obstack as **external clients** — not part of obstack's runtime. Use them to validate obstack works end-to-end with a realistic application.

## Available

| Directory | Description | RAM |
|-----------|-------------|-----|
| `otel-demo/` | A 7-service curated subset of the official [open-telemetry/opentelemetry-demo](https://github.com/open-telemetry/opentelemetry-demo) Astronomy Shop. Sends OTLP to obstack via HTTPS + Basic auth — same path real applications use. | 4–6 GB |

## Why standalone, not integrated

These projects deliberately do **not** share Docker networks with obstack. They emit telemetry through obstack's *public* OTLP endpoint (`https://${DOMAIN}/v1/traces`, etc.) with HTTP Basic auth — exactly the path that customer applications would use. This catches bugs in TLS, basic-auth, and OTLP routing that an internal-network shortcut would mask.

## Adding new examples

Drop a new directory under `examples/`. Keep it self-contained: its own docker-compose.yml, its own README, its own .env.example. Document what it teaches and what its RAM footprint is.
