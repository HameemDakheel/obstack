# ADR 0005: Prometheus over Mimir at Simple profile

**Status:** Accepted
**Date:** 2026-04-25

## Context

The original prototype used Mimir as the metrics backend. Mimir is the spiritual successor to Cortex — designed for horizontally-scalable, multi-tenant, distributed Prometheus deployments. Even in monolithic mode (`-target=all`), Mimir carries the architectural weight of a distributed system: ~500 MB at idle with multi-GB query spikes under load.

At Simple profile (single VPS, 4 GB RAM, single-tenant), this is overkill. Three viable alternatives:

1. **Prometheus** (single binary) — the obvious lightweight pick. Universal recognition, ~150 MB idle.
2. **VictoriaMetrics** — Prom-compatible, technically lighter (~100 MB), better cardinality handling.
3. **Mimir monolithic** — the original choice; technically works but RAM-hostile.

For an audience optimizing for adoption (not raw performance), brand recognition matters. Every Grafana tutorial, every Stack Overflow answer, every blog post says "Prometheus + Grafana." Picking VictoriaMetrics requires a paragraph in the README defending the choice.

## Decision

Use **Prometheus** (single binary, `prom/prometheus`) as the metrics backend at Simple profile, configured with `--web.enable-remote-write-receiver` so the OTel Collector can push metrics into it.

VictoriaMetrics returns at the Scale profile as one of two upgrade paths (the other being Mimir).

## Consequences

**Positive:**
- **Universal recognition** — every developer has heard of "Prometheus + Grafana." Zero defensive paragraphs required in the README.
- **Lower mental friction** — newcomers expect Prometheus when they see a Grafana stack.
- **Tutorial / copy-paste compatibility** — existing PromQL examples, exporters, and instrumentation work unchanged.
- **Lowest maintenance burden for solo dev** — Prometheus has the most documentation, the largest community, and the most Stack Overflow answers.
- **Scales gracefully** — `remote_write` to VictoriaMetrics or Mimir is a single config-line change with zero data loss.

**Negative:**
- **Cardinality sensitivity** — Prometheus memory grows linearly with active series. Users running 1M+ series will hit walls. Mitigation: alert rule `PrometheusHighCardinality` fires above 1M series; documented in [high-cardinality runbook](../operations/runbooks/high-cardinality.md).
- **Long-term storage** is filesystem only; sweet spot 7–30 days. Beyond that, query performance degrades. Acceptable for Simple-profile users; Scale users can move to VictoriaMetrics for better long-term storage.
- **No native multi-tenancy** — single tenant only. Multi-tenancy moves to Enterprise profile via Mimir.

**Neutral:**
- All Prometheus exporters work unchanged.
- The OTel Collector exports via `prometheusremotewrite` — same protocol regardless of backend.

## References

- [Prometheus storage documentation](https://prometheus.io/docs/prometheus/latest/storage/)
- [Prometheus remote-write receiver flag](https://prometheus.io/docs/prometheus/latest/feature_flags/#remote-write-receiver)
- [Spec §4.1 — Stack selection](../superpowers/specs/2026-04-25-obstack-redesign.md)
- Related: [ADR 0001 — Hybrid stack](0001-hybrid-stack.md)
