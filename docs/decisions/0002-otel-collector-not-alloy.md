# ADR 0002: OpenTelemetry Collector contrib over Grafana Alloy

**Status:** Accepted
**Date:** 2026-04-25

## Context

obstack needs a telemetry pipeline that accepts OTLP from applications and fans out to four backends (metrics, logs, traces, profiles). Two viable options:

1. **Grafana Alloy** — Grafana's distribution of the OpenTelemetry Collector. Uses a custom DSL called *River* (HCL-style) for configuration. Native to the Grafana ecosystem.
2. **OpenTelemetry Collector contrib** — the upstream project. Uses YAML for configuration. The de-facto OTel-ecosystem standard.

Alloy's River syntax is genuinely more readable than YAML — it supports comments, has named blocks, and avoids YAML's whitespace pitfalls. But the question is which tool best serves our adoption wedge.

## Decision

Standardize on **`otel/opentelemetry-collector-contrib`** (upstream), pinned to a specific minor version.

## Consequences

**Positive:**
- **Copy-paste from official docs works.** Every OTel SDK tutorial, every OpenTelemetry blog post, every Stack Overflow answer references upstream Collector YAML. Users searching for help find answers that work directly with our config.
- **AI-assistant familiarity.** Coding assistants and LLMs have been trained on dramatically more upstream Collector content than Alloy River configs. When a user asks Claude, ChatGPT, or Copilot about their obstack config, the answers are accurate.
- **Vendor neutrality.** "OTel-native" is a core part of our pitch — using the upstream tool reinforces that we don't quietly bind users to Grafana-specific tooling.
- **Receiver/processor/exporter ecosystem.** The contrib distribution ships with the broadest set of components (Prometheus remote-write, Tempo OTLP, VictoriaLogs OTLP, etc.).

**Negative:**
- YAML quirks (indentation, no comments in some contexts, tag confusion). Mitigated by the relatively small Collector config we ship.
- Slightly larger binary than minimal Alloy — but the RAM difference (≤30 MB) is irrelevant on a 4 GB VPS.
- We lose Alloy's nicer error messages and live-reload UI.

**Neutral:**
- Both are written in Go and use most of the same component code internally. Functionality is equivalent for our use case.

## References

- [OpenTelemetry Collector documentation](https://opentelemetry.io/docs/collector/)
- [Alloy vs OpenTelemetry Collector comparison (OneUptime)](https://oneuptime.com/blog/post/2026-02-06-compare-opentelemetry-collector-vs-grafana-alloy/view)
- [Spec §4.1 — Stack selection](../superpowers/specs/2026-04-25-obstack-redesign.md)
