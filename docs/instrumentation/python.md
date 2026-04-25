# Python instrumentation

> **What you'll need:** Python 3.10+, an obstack stack reachable at `https://<DOMAIN>/`, and the basic-auth credentials from your `.env`.
> **Time to complete:** ~10 minutes.

This guide uses the **`opentelemetry-distro`** package which auto-instruments Flask, Django, FastAPI, requests, psycopg2, redis, pymongo, and ~30 other libraries with zero code changes.

---

## Step 1 — Install

```bash
pip install opentelemetry-distro opentelemetry-exporter-otlp
opentelemetry-bootstrap -a install
```

`opentelemetry-bootstrap` scans your installed packages and installs instrumentation libraries for each one it recognises.

---

## Step 2 — Configure via environment variables

```bash
export OTEL_SERVICE_NAME=my-python-app
export OTEL_EXPORTER_OTLP_ENDPOINT=https://<DOMAIN>
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_HEADERS="authorization=Basic $(echo -n 'ingest:YOUR_PASSWORD' | base64)"
export OTEL_LOGS_EXPORTER=otlp
export OTEL_METRICS_EXPORTER=otlp
export OTEL_TRACES_EXPORTER=otlp
```

For dev with self-signed certs:

```bash
export OTEL_EXPORTER_OTLP_INSECURE=true
```

(or, more strictly, set `OTEL_EXPORTER_OTLP_CERTIFICATE` to your Caddy cert path).

---

## Step 3 — Run your app with auto-instrumentation

```bash
opentelemetry-instrument python app.py
```

The `opentelemetry-instrument` wrapper enables auto-instrumentation. For Gunicorn / Uvicorn:

```bash
opentelemetry-instrument gunicorn app:app
opentelemetry-instrument uvicorn app:app --host 0.0.0.0 --port 8000
```

---

## Step 4 — Send a manual test span

```python
# test_trace.py
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
import os, time

provider = TracerProvider(
    resource=Resource.create({SERVICE_NAME: os.environ.get("OTEL_SERVICE_NAME", "test-python-app")})
)
provider.add_span_processor(BatchSpanProcessor(
    OTLPSpanExporter(endpoint=f"{os.environ['OTEL_EXPORTER_OTLP_ENDPOINT']}/v1/traces")
))
trace.set_tracer_provider(provider)

tracer = trace.get_tracer("test")
with tracer.start_as_current_span("hello-world") as span:
    span.set_attribute("greeting", "hi from python")
    time.sleep(0.1)

# flush
provider.shutdown()
print("span flushed")
```

```bash
python test_trace.py
```

---

## Step 5 — Verify in Grafana

Open Grafana → **Explore** → datasource: **Tempo** → "Search" tab → service: `test-python-app`.

For auto-instrumented apps, also check:
- **Dashboards → obstack → Traces Browser** — service graph includes your app
- **Dashboards → obstack → Logs Explorer** — application logs (Python logging module is auto-instrumented via `opentelemetry-instrumentation-logging`)

---

## Common pitfalls

- **`Connection refused` on localhost** — make sure `OTEL_EXPORTER_OTLP_ENDPOINT` points to the actual host, not `localhost` if your Python app runs in a different container.
- **Header format** — the env var is `OTEL_EXPORTER_OTLP_HEADERS="authorization=Basic <base64>"` with `=` separator (not `:`). Multiple headers are comma-separated: `key1=val1,key2=val2`.
- **Spans flushed but not appearing** — Python's BatchSpanProcessor batches; add `provider.shutdown()` at exit for short-lived scripts.
- **Async frameworks (FastAPI, asyncio)** — auto-instrumentation handles these correctly. If you write custom async code, use `with tracer.start_as_current_span()` inside async functions.
- **Disabling specific instrumentations** — set `OTEL_PYTHON_DISABLED_INSTRUMENTATIONS=psycopg2,redis` to skip noisy ones.

---

## Next steps

- [Node.js instrumentation](nodejs.md)
- [Go instrumentation](go.md)
- [Architecture overview](../architecture.md)
- [OpenTelemetry Python docs](https://opentelemetry.io/docs/instrumentation/python/)
