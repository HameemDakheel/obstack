# Java instrumentation

> **What you'll need:** JDK 17+, an obstack stack reachable at `https://<DOMAIN>/`, and the basic-auth credentials from your `.env`.
> **Time to complete:** ~5 minutes (Java has the best auto-instrumentation story — a single javaagent JAR covers ~100 frameworks).

The OpenTelemetry Java agent is a **single JAR** you attach via `-javaagent`. It auto-instruments Spring, Hibernate, JDBC, Kafka, Vert.x, Micrometer, Apache HTTP, Netty, and ~90 other libraries with **zero code changes**.

---

## Step 1 — Download the agent

```bash
curl -L -o opentelemetry-javaagent.jar \
  https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar
```

Check the [releases page](https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases) for the latest version. As of 2026, releases happen ~monthly.

---

## Step 2 — Configure via environment variables

```bash
export OTEL_SERVICE_NAME=my-java-app
export OTEL_EXPORTER_OTLP_ENDPOINT=https://<DOMAIN>
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_HEADERS="authorization=Basic $(echo -n 'ingest:YOUR_PASSWORD' | base64)"
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=prod,team=platform"
```

For dev with self-signed certs, the agent has its own flag:

```bash
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_INSECURE=true
```

---

## Step 3 — Run your app with the agent

```bash
java -javaagent:./opentelemetry-javaagent.jar -jar your-app.jar
```

Or for Maven / Gradle apps:

```bash
java -javaagent:./opentelemetry-javaagent.jar -cp target/classes:lib/* com.example.Main
```

That's it. Spring controllers become traces. JDBC queries become child spans. JVM metrics flow automatically (heap, GC, threads).

---

## Step 4 — Verify in Grafana

Open Grafana → **Explore** → datasource: **Tempo** → "Search" tab → service: `my-java-app`. Hit your app's HTTP endpoints and check the traces appear within ~10 seconds.

JVM metrics appear in **Dashboards → obstack → Stack Health** (and you can search Prometheus for `process_runtime_jvm_*`). For richer JVM dashboards, install the [OpenTelemetry JVM Metrics dashboard](https://grafana.com/grafana/dashboards/19004) from grafana.com (Phase 5 work — not pre-bundled).

---

## Step 5 — Send a manual span (optional)

If you want to add custom spans alongside auto-instrumentation:

```java
// add dependency: io.opentelemetry:opentelemetry-api:1.42.0
import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.Tracer;

public class Demo {
    private static final Tracer tracer = GlobalOpenTelemetry.getTracer("my-app");

    public void doWork() {
        Span span = tracer.spanBuilder("doWork").startSpan();
        try {
            // ... your code
            span.setAttribute("user.id", 42);
        } finally {
            span.end();
        }
    }
}
```

The `GlobalOpenTelemetry` instance is set up automatically by the agent.

---

## Common pitfalls

- **Agent JAR path** — `-javaagent:` doesn't accept relative paths in some JVMs depending on working directory. Use absolute paths in production or symlinks.
- **Spring Boot duplicate spans** — if your app already has Spring Cloud Sleuth or Micrometer Tracing, disable them or you'll get duplicate spans. Set `spring.sleuth.enabled=false` and remove Micrometer Tracing dependencies.
- **Memory overhead** — the agent adds ~50-100 MB heap usage and ~5% CPU. Acceptable for production; tune via `OTEL_BSP_MAX_QUEUE_SIZE` if span volume is high.
- **`OTEL_TRACES_SAMPLER=always_off` accidentally** — the default is `parentbased_always_on`, which is what you want. If spans don't appear, check `OTEL_TRACES_SAMPLER` isn't disabled.
- **Long-running tasks** — for batch jobs that run >5 minutes per task, increase `OTEL_BSP_SCHEDULE_DELAY` to reduce flush frequency and CPU overhead.

---

## Next steps

- [Ruby instrumentation](ruby.md)
- [Python instrumentation](python.md)
- [Architecture overview](../architecture.md)
- [OpenTelemetry Java docs](https://opentelemetry.io/docs/languages/java/)
- [Auto-instrumentation supported libraries](https://github.com/open-telemetry/opentelemetry-java-instrumentation/blob/main/docs/supported-libraries.md)
