# ADR 0006: Self-monitoring as the first-run experience (no synthetic data seeder)

**Status:** Accepted
**Date:** 2026-04-25

## Context

A new user installs OTel-jps, opens Grafana, and sees... empty dashboards. That's a poor first impression — the wedge ("ready out of the box") demands data on first launch.

Two ways to populate dashboards with data on first launch:

1. **Synthetic data seeder.** Ship a one-shot init container that emits 5 minutes of fake spans/metrics/logs via OTLP, then exits. ~100 LOC of Go or Python. Marks itself "seeded" via a file so it doesn't re-run. Dashboards show fake data the user knows is fake.

2. **Self-monitoring.** Configure every component to emit its own metrics (and where applicable logs and traces) to the stack itself. The OTel Collector scrapes its own `:8888`; Prometheus scrapes Tempo, Pyroscope, Grafana, cAdvisor; OTel Collector pushes to all four backends. From second 1, dashboards show **real data** — the stack monitoring itself.

## Decision

**Use self-monitoring.** Don't ship a seeder.

Configuration:
- Prometheus has scrape jobs for `prometheus-self`, `otel-collector` (port 8888), `tempo` (port 3200), `pyroscope` (port 4040), `grafana` (port 3000), `cadvisor` (port 8080).
- OTel Collector has a `prometheus/self` receiver that scrapes its own metrics endpoint, plus pipelines for traces/metrics/logs that flow to the four backends.
- cAdvisor (added in Phase 2) provides per-container CPU/RAM/network for the Container Metrics dashboard.

## Consequences

**Positive:**
- **Real data on second 1.** Dashboards populated immediately after `make simple` completes. No "wait for the demo to fire" delay.
- **Stronger first impression than synthetic data.** Users see their *actual* stack instrumented — a meta-demo of what they're getting.
- **Zero extra components.** No init container, no seeder language, no marker files, no version drift.
- **Continuously useful.** Self-monitoring data isn't "demo data" — it's the operational telemetry that makes the Stack Health and Container Metrics dashboards permanently useful.

**Negative:**
- The data is *only* about the stack itself. Users who want to see what application telemetry looks like need to either instrument an app (per [instrumentation guides](../instrumentation/nodejs.md)) or run `make demo` (the optional [OTel demo overlay](../../demo/README.md)).
- The first-run dashboards aren't visually "rich" — there's not much variety in the stack's own metrics. Mitigation: the optional OTel demo overlay provides the rich-microservice screenshot path for blog posts and evaluation.

**Neutral:**
- The OTel demo overlay (Astronomy Shop subset) covers the "what would this look like with my app?" use case opt-in, requiring 8+ GB.

## References

- [Phase 2 plan: cAdvisor + dashboards + alerts](../superpowers/plans/2026-04-25-phase-2-stack-polish.md)
- [Demo overlay README](../../demo/README.md)
- [Spec §5.6 — Demo strategy](../superpowers/specs/2026-04-25-otel-jps-redesign.md)
