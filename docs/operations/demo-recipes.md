# Demo recipes — driving traffic and failures into obstack

> **Audience:** anyone who has the [demo running](demo-tutorial.md) and wants to use it to populate dashboards with specific scenarios — load spikes, error spikes, slow images, memory leaks, GC pauses, …

The Astronomy Shop demo ships with two control surfaces you'll use constantly:

| Surface | URL | What it does |
|---------|-----|--------------|
| **Feature flags (flagd UI)** | <http://localhost:8080/feature/> | Toggle 15+ failure-injection flags. Changes propagate within seconds. |
| **Load generator (Locust)** | <http://localhost:8080/loadgen/> | Adjust user count, spawn rate, scenarios. Also has stats/charts. |

Direct host ports (assigned by Docker, may differ on your machine):
- Locust web UI: `docker port load-generator 8089`
- flagd UI: `docker port flagd-ui 4000`

---

## Recipe 1 — Drive a baseline traffic load

The demo always runs Locust with 5 simulated users by default. To increase load:

1. Open <http://localhost:8080/loadgen/>.
2. Click **Stop** if a test is running.
3. Click **New** → set:
   - **Number of users:** 50 (or 200 for stress test — watch your CPU)
   - **Ramp up:** 5 (users/second)
   - **Host:** `http://frontend-proxy:8080` (auto-filled)
4. **Start swarming**.

**Watch in obstack:**
- *Astronomy Shop* dashboard → "Total request rate" stat shoots up
- *Container Metrics* dashboard → CPU/memory of `frontend`, `cart`, `currency` climbs
- *Stack Health* dashboard → obstack's own ingest queue grows (otelcol metrics)

**Expected throughput** at 50 users on a modern laptop: ~80–150 req/s; at 200 users: ~250–400 req/s before backpressure.

---

## Recipe 2 — Inject service failures

| Flag | Effect | What you'll see |
|------|--------|-----------------|
| `cartFailure` | Cart service returns errors on add-to-cart | Error rate spike on `cart`; cart-related spans show `STATUS_CODE_ERROR`; frontend logs show retry loops |
| `productCatalogFailure` | Specific product (`OLJCESPC7Z`) fails to load | Error rate on `product-catalog`; trace from frontend → product-catalog shows the failure path |
| `paymentFailure` | n% of charge requests fail | Variants: `10%`, `25%`, `50%`, `75%`, `90%`, `100%`. Watch p99 latency rise as retries kick in |
| `paymentUnreachable` | Payment service unreachable entirely | Connection-refused errors propagate up to checkout |
| `adFailure` | Ad service errors out | Frontend home page degrades; ad spans error |
| `failedReadinessProbe` | Cart's readiness probe fails | Health check failures (visible in cAdvisor metrics) |

**Run a recipe:**
```bash
# Browse to http://localhost:8080/feature/
# Toggle the flag to "on" (or pick a percentage variant)
# Wait ~30s and watch obstack
```

**Verify it landed:**
```bash
# Error rate query (should rise within 30s of flag flip)
B64="Basic $(printf 'ingest:<password>' | base64 -w0)"
docker exec obstack-caddy sh -c "wget -qO- --header='Authorization: $B64' \
  'http://prometheus:9090/api/v1/query?query=sum(rate(traces_span_metrics_calls_total%7Bservice_namespace%3D%22opentelemetry-demo%22%2Cstatus_code%3D%22STATUS_CODE_ERROR%22%7D%5B1m%5D))%20by%20(service_name)'"
```

Don't forget to toggle flags **off** when done — they persist across container restarts.

---

## Recipe 3 — Generate slow / high-latency traces

| Flag | Effect | Best dashboard view |
|------|--------|---------------------|
| `imageSlowLoad` (`5sec` or `10sec`) | Frontend image fetches stall | "p95/p99 latency by service" panel — `image-provider` shoots to seconds |
| `adHighCpu` | Ad service pegged at 100% CPU | Container Metrics → CPU per container; ad-service traces become slow |
| `adManualGc` | Periodic full GC pauses | Latency histogram develops a long tail; GC-induced latency spikes visible in p99 |

Open the *Astronomy Shop* dashboard → **Top 15 slowest spans** table. Within ~1 minute of toggling `imageSlowLoad=10sec`, the table reorders to put `image-provider` spans on top with p95 ≈ 10s.

---

## Recipe 4 — Memory leak demonstration

```
flag:  emailMemoryLeak
variants: 1x, 10x, 100x, 1000x, 10000x
```

1. Toggle `emailMemoryLeak` to `100x` at <http://localhost:8080/feature/>.
2. Open obstack's *Container Metrics* dashboard.
3. Filter to `name=email`. Watch the memory line climb steadily — Go heap grows on each request.
4. After ~5 min, the email service may OOM-kill itself. Container restarts; counter resets.

**Catch the leak with traces too:** the Astronomy Shop dashboard's `email` service throughput stays normal even as memory climbs — a textbook silent leak that only metrics catch.

To clean up: toggle the flag back to `off` and `docker restart email`.

---

## Recipe 5 — Cache stampede / unbounded growth

```
flag:  recommendationCacheFailure   (variants: on, off)
```

Recommendation service caches per-user recommendations. With this flag on, the cache breaks and the service spawns unbounded computation per request.

1. Toggle on.
2. Crank up Locust users to 100.
3. Within 2 minutes:
   - `recommendation` container memory climbs (Container Metrics dashboard)
   - p99 latency on `recommendation` spans spikes (Astronomy Shop)
   - Eventually the service OOMs — Stack Health dashboard shows the restart

This is the most visceral demo of why production observability matters — **slow memory bugs are invisible to logs and load tests but obvious in metrics + traces together.**

---

## Recipe 6 — Kafka backpressure

```
flag:  kafkaQueueProblems   (variants: on, off)
```

Overloads Kafka queue and adds consumer-side delay.

1. Toggle on.
2. Generate moderate load (Locust at 30 users).
3. Watch:
   - `accounting` and `fraud-detection` consumer lag in their span attributes
   - Kafka topic depth metrics in Prometheus (`kafka_*` series)
   - End-to-end checkout traces show extended consumer-side delays at the bottom of the waterfall

Excellent for demonstrating async-system observability — error rates stay near zero, but latency p99 rises.

---

## Recipe 7 — Flood scenario (stress test)

```
flag:  loadGeneratorFloodHomepage   (variants: on, off)
```

Tells the load generator to hammer the homepage as fast as possible (bypasses normal Locust pacing).

1. Toggle on.
2. Watch obstack's own ingest health on *Stack Health*:
   - otelcol queue size grows
   - Memory limiter may start dropping data (look for `otelcol_processor_dropped_*` metrics)
3. This is the right scenario to validate that **obstack stays healthy under load** before deploying to production.

---

## Recipe 8 — LLM-related failures

If you're running with the demo's `llm` service:

| Flag | Effect |
|------|--------|
| `llmInaccurateResponse` | Returns a wrong product summary for one specific product ID |
| `llmRateLimitError` | Intermittent 429s from the LLM |

Useful for demonstrating that observability covers AI features too — you'll see the rate-limit errors in trace attributes (`error.type=429`) and you can build alerts on them.

---

## Combining recipes

For a realistic "incident drill" demo:

```
1. Set Locust to 75 users
2. Enable adHighCpu          (CPU pressure)
3. Enable paymentFailure=25% (some checkout failures)
4. Enable imageSlowLoad=5sec (latency)
5. Wait 5 minutes
6. Open obstack Grafana, demonstrate that all three problems are
   independently visible across metrics/traces/logs without
   needing to know in advance what's wrong.
```

Then turn flags off in reverse order and watch dashboards return to baseline.

---

## Resetting to clean state

```bash
# Disable all flags via flagd-ui (set them all to "off")
# Or: restart the demo entirely (clears in-memory state)
make demo-down
make demo-up
```

---

## See also

- [Demo tutorial](demo-tutorial.md) — initial setup
- [`examples/otel-demo/README.md`](https://github.com/HameemDakheel/obstack/blob/main/examples/otel-demo/README.md) — architecture
- [Upstream OTel demo feature flags](https://github.com/open-telemetry/opentelemetry-demo/blob/main/src/flagd/demo.flagd.json) — full source of truth for flag behaviour
