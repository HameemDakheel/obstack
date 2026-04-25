# ADR 0001: Hybrid stack (Prometheus + VictoriaLogs + Tempo + Pyroscope + Grafana)

**Status:** Accepted
**Date:** 2026-04-25

## Context

obstack targets self-hosters running on a single 4 GB VPS. The original positioning — *"Grafana LGTM+P pre-assembled"* — turned out to be redundant: Grafana already ships [`grafana/docker-otel-lgtm`](https://hub.docker.com/r/grafana/otel-lgtm), an official one-shot image bundling the full stack.

We also discovered that the LGTM data plane is architecturally hostile to small machines:

- **Mimir** is the distributed-Prometheus successor; even its monolithic mode carries the architectural weight of horizontal scale (~500 MB at idle, multi-GB query spikes).
- **Loki** has well-documented memory issues at small scale (1.5 GB idle floor, multi-GB query spikes, [GitHub #13501](https://github.com/grafana/loki/issues/13501)).
- **MinIO** preallocates ~1 GB on a single node — 25% of a 4 GB VPS for zero benefit when filesystem storage works.

Independent benchmarks show **VictoriaMetrics uses 5× less RAM than Mimir** and **VictoriaLogs uses 87% less RAM than Loki** with 94% lower query latency. The wedge — *"Production observability for your $20/month VPS"* — is only honest with these lighter components.

## Decision

Ship a **hybrid stack** at Simple profile:

- **Metrics:** Prometheus (single binary)
- **Logs:** VictoriaLogs
- **Traces:** Grafana Tempo (monolithic, filesystem)
- **Profiles:** Pyroscope (filesystem)
- **UI:** Grafana — the visual brand and integration moat
- **Ingest:** OpenTelemetry Collector contrib
- **Reverse proxy / TLS:** Caddy
- **Object storage:** filesystem (no MinIO at Simple)

The stack is "hybrid" in the sense that the **data plane** uses non-Grafana components (VictoriaLogs, optionally VictoriaMetrics at Scale) while the **UI** stays Grafana. Marketing pitch: *"All 5 signals, all in Grafana."*

## Consequences

**Positive:**
- Stack idles at ~250–311 MB (vs ~3 GB for the original LGTM stack) — the "$20 VPS" pitch is honest with comfortable margin.
- VictoriaLogs query latency is ~94% lower than Loki for typical SMB workloads.
- Scale upgrade path is clean: Prometheus → VictoriaMetrics cluster *or* Mimir via `remote_write`; VictoriaLogs has its own clustered version.

**Negative:**
- Lose the recognizable "LGTM" branding. We replace it with *"OpenTelemetry-native observability for self-hosters."*
- VictoriaMetrics community is smaller than Grafana's (~17K vs ~70K stars across LGTM components combined).
- Two query languages to learn (PromQL, LogsQL) — but that's no worse than LGTM (PromQL, LogQL, TraceQL).

**Neutral:**
- Pyroscope and Tempo remain Grafana ecosystem — the visual cohesion stays.
- All components support `remote_write` or compatible push protocols, so users can migrate to or from Mimir/Loki without re-instrumenting their apps.

## References

- [VictoriaMetrics vs Mimir benchmark](https://victoriametrics.com/blog/mimir-benchmark/)
- [VictoriaLogs vs Loki benchmark (TrueFoundry)](https://www.truefoundry.com/blog/victorialogs-vs-loki)
- [Loki monolithic memory issues (GitHub #13501)](https://github.com/grafana/loki/issues/13501)
- [Spec §4.1 — Stack selection](../superpowers/specs/2026-04-25-obstack-redesign.md)
- Related: [ADR 0004 — No MinIO at Simple](0004-no-minio-for-simple.md), [ADR 0005 — Prometheus over Mimir](0005-prometheus-not-mimir-for-simple.md)
