# obstack Demo Overlay

This directory documents the optional OTel Demo overlay — a way to spin up
a small subset of the official [open-telemetry/opentelemetry-demo](https://github.com/open-telemetry/opentelemetry-demo)
"Astronomy Shop" services, rewired to send telemetry to your local obstack stack.

## When to use it

- You want to **see what real microservice traces look like** in obstack.
- You want **screenshots / blog content / talk demos** with realistic data.
- You're **evaluating** obstack before deploying for real workloads.

## When NOT to use it

- On a 4 GB single VPS — the demo needs ~4-6 GB extra RAM.
- In production — these are demo apps, not your apps.

## Run it

```bash
docker compose \
  -f docker-compose.yml \
  -f compose/simple.yml \
  -f compose/otel-demo.yml \
  up -d
```

Then open Grafana at `https://localhost/`. Within 1-2 minutes you'll see:
- **Stack Health** dashboard: increasing trace/metric ingestion rates
- **Traces Browser**: a service graph showing demo.frontend → demo.cart → demo.checkout → demo.payment
- **Logs Explorer**: structured logs from each demo service
- **Container Metrics**: per-container resource usage for the demo apps

The demo's frontend is browsable at <http://localhost:8082/>.

## Stop it

```bash
docker compose \
  -f docker-compose.yml \
  -f compose/simple.yml \
  -f compose/otel-demo.yml \
  down
```

## Caveats

- Demo images are pinned to OTel Demo `1.12.0`. Bump deliberately when
  upstream releases — the env-var contract has changed in past major releases.
- Demo's bundled Prometheus / Grafana / Jaeger are NOT used; we route their
  telemetry to our own stack.
- Some demo services (currency, accounting, fraud-detection, ad, kafka, etc.)
  are intentionally NOT included to keep RAM under 6 GB. The included subset
  still produces a credible service graph and load.
