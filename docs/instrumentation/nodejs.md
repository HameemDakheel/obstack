# Node.js instrumentation

> **What you'll need:** Node 18+, an obstack stack reachable at `https://<DOMAIN>/`, and the basic-auth credentials from your `.env`.
> **Time to complete:** ~10 minutes.

This guide gets traces, metrics, and logs flowing from a Node.js app into your obstack stack using **auto-instrumentation** — no code changes required for most popular libraries (HTTP, Express, Postgres, Redis, etc.).

---

## Step 1 — Install the SDK

```bash
npm install --save \
  @opentelemetry/api \
  @opentelemetry/auto-instrumentations-node \
  @opentelemetry/exporter-trace-otlp-http \
  @opentelemetry/exporter-metrics-otlp-http \
  @opentelemetry/exporter-logs-otlp-http \
  @opentelemetry/sdk-node
```

---

## Step 2 — Configure via environment variables

Create a `.env` for your app (or set in your deployment env):

```bash
export OTEL_SERVICE_NAME=my-node-app
export OTEL_EXPORTER_OTLP_ENDPOINT=https://<DOMAIN>
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic $(echo -n 'ingest:YOUR_PASSWORD' | base64)"
export NODE_OPTIONS="--require @opentelemetry/auto-instrumentations-node/register"
```

That's it for auto-instrumentation. Replace `<DOMAIN>` and `YOUR_PASSWORD` with your values.

For local dev with self-signed certs, also export:

```bash
export NODE_TLS_REJECT_UNAUTHORIZED=0   # dev only — never in production
```

---

## Step 3 — Run your app

```bash
node index.js
```

Auto-instrumentation hooks into `http`, `express`, `koa`, `fastify`, `pg`, `mysql`, `redis`, `mongodb`, and ~40 other modules. Every incoming HTTP request becomes a trace; every outgoing DB query becomes a child span; metrics flow automatically.

---

## Step 4 — Send a manual test span

If you want to verify before deploying with auto-instrumentation, drop this in `test-trace.js`:

```javascript
// test-trace.js
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { trace } = require('@opentelemetry/api');

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'test-node-app',
  }),
  traceExporter: new OTLPTraceExporter({
    url: `${process.env.OTEL_EXPORTER_OTLP_ENDPOINT}/v1/traces`,
    headers: { Authorization: process.env.OTEL_EXPORTER_OTLP_HEADERS?.replace('Authorization=', '') },
  }),
});
sdk.start();

const tracer = trace.getTracer('test');
const span = tracer.startSpan('hello-world');
span.setAttribute('greeting', 'hi from node');
setTimeout(() => {
  span.end();
  sdk.shutdown().then(() => console.log('span flushed'));
}, 100);
```

Run:

```bash
node test-trace.js
```

---

## Step 5 — Verify in Grafana

Open Grafana → **Explore** → datasource: **Tempo** → switch to "Search" tab → service: `test-node-app` (or your `OTEL_SERVICE_NAME`).

You should see your `hello-world` span within ~10 seconds (OTel batching + Tempo flush interval).

For auto-instrumented traffic, also check:
- **Dashboards → obstack → Traces Browser** — your service appears in the service graph
- **Dashboards → obstack → Logs Explorer** — application logs (if you have a logger pipe configured)

---

## Common pitfalls

- **Spans don't appear** — check that `OTEL_EXPORTER_OTLP_HEADERS` is correctly base64-encoded. The header value should be `Authorization=Basic <base64>` (note the `=`, not `:`).
- **`fetch is not defined` errors** — Node 18+ has native fetch; older Node versions require `npm install node-fetch`.
- **Self-signed cert errors** — `NODE_TLS_REJECT_UNAUTHORIZED=0` is **dev only**. In production, use a real domain with Let's Encrypt (Caddy auto-provisions).
- **Spans flushed but not appearing** — OTel SDK batches up to 5 seconds before sending. Add `await sdk.shutdown()` for short-lived scripts; long-running apps don't need this.
- **Missing trace IDs in logs** — install `@opentelemetry/api-logs` and pipe your logger output through OTel for correlated traces↔logs.

---

## Next steps

- [Python instrumentation](python.md)
- [Go instrumentation](go.md)
- [Architecture overview](../architecture.md) — how spans flow from your app to Grafana
- [OpenTelemetry JS docs](https://opentelemetry.io/docs/instrumentation/js/) — official upstream
