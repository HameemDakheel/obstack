# obstack OTel Demo (standalone)

A curated 7-service subset of the [official OpenTelemetry demo](https://github.com/open-telemetry/opentelemetry-demo) ("Astronomy Shop"), reconfigured to emit telemetry to your obstack instance over its **public OTLP endpoint** with HTTP Basic auth — exactly the path a real customer's applications would take.

## Why this exists

obstack ships with no pre-instrumented application of its own. After installing obstack you have empty traces, sparse logs (just the stack monitoring itself), and dashboards waiting for app-level data. This demo:

- **Validates the production OTLP path** — TLS, basic auth, all of it.
- **Populates the dashboards** with realistic microservice telemetry within ~2 minutes.
- **Doubles as your end-to-end test.** If `make verify` passes but the demo's traces don't show up, something is broken in the public-facing path.

## Prerequisites

- obstack running and reachable at the URL you'll set as `DEMO_OBSTACK_ENDPOINT`.
- The plaintext basic-auth password (the one whose bcrypt hash is in obstack's `.env` as `BASIC_AUTH_HASH`).
- A machine with **at least 6 GB RAM free** to run the demo. If you're running it alongside obstack on the same host, budget **12+ GB total**.

## Run it

From this directory:

```bash
cp .env.example .env
# Edit .env: set DEMO_OBSTACK_ENDPOINT, DEMO_BASIC_AUTH_USER, DEMO_BASIC_AUTH_PASSWORD
docker compose up -d
```

Or from the repo root: `make demo-up` (this script will set up the basic-auth header for you from the values in `.env`).

## Verify

About 2 minutes after the demo starts:

1. Open obstack's Grafana → **Dashboards → obstack → Traces Browser**
2. You should see a service graph with edges between `demo.frontend`, `demo.cart`, `demo.checkout`, `demo.payment`, and `demo.recommendation`.
3. Browse to <http://localhost:8082/> for the demo's web UI; clicking around generates more spans.

If the graph is empty after 2 minutes:
- Check `docker compose logs demo-load-generator` — should show successful HTTP requests.
- Check `docker exec obstack-otelcol cat /var/log/...` — collector should be receiving traces (look for `demo.*` service names).
- 401 errors → basic auth header is wrong.
- Connection-refused → DEMO_OBSTACK_ENDPOINT is wrong or obstack isn't listening on that domain.
- TLS errors with `localhost` → set `DEMO_OBSTACK_INSECURE=true` in `.env`.

## Stop it

```bash
docker compose down
```

Or from repo root: `make demo-down`.

## Caveats

- Demo images are pinned to OTel demo `1.12.0`. Bump deliberately and test — the demo's env-var contract has changed in past major releases.
- The 7-service subset is intentionally minimal. The full upstream demo has ~17 services (kafka, accounting, fraud-detection, ad, etc.) but those add 4+ GB of RAM for marginal teaching value here.
- This demo is **not** a profile of obstack itself. It's a separate compose project. Obstack stays unchanged whether you run the demo or not.

## License

The OTel demo images and source are Apache 2.0 licensed (this directory's wiring is MIT, matching obstack).
