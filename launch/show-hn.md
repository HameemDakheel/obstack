# Show HN draft

## Title

**Show HN: obstack – Production observability for your $20/month VPS**

(Alt title if rejected for sounding salesy: *"Show HN: A 311 MB observability stack — Prometheus, Tempo, Pyroscope, Grafana, all 5 signals on a 4 GB VPS"*)

## URL

`https://github.com/HameemDakheel/obstack`

## Submission text (the body of the Show HN post)

Hi HN. I've been frustrated for a while that "self-hosted observability" means either:

  1. Run the official Grafana LGTM stack and watch it eat 3+ GB of RAM at idle on a small VPS, or
  2. Run something like SigNoz, which the docs say needs 56 CPU and 152 GB RAM in production.

For solo devs and indie SaaS people running on a Hetzner or DO box, neither is reasonable. So I built obstack — a hybrid stack that idles at 311 MB and gives you all 5 OpenTelemetry signals (logs, metrics, traces, profiles, dashboards) with one `make simple` command.

Tech choices that mattered:
- **VictoriaLogs instead of Loki** — same query language style, 87% less RAM, 94% lower query latency in independent benchmarks.
- **Prometheus (not Mimir) at the Simple profile** — universal recognition, scales to remote_write later when you actually need to.
- **No MinIO** — at single-node scale it preallocates 1 GB for nothing. Filesystem storage works fine.
- **Caddy** — auto-TLS in 3 lines, what r/selfhosted uses.
- **Upstream OTel Collector** (not Grafana Alloy) — copy-paste from the OTel docs actually works.

What you get out of the box:
- 4 pre-built Grafana dashboards (stack health, container metrics via cAdvisor, logs explorer, traces browser).
- 12 pre-tuned Prometheus alert rules (service down, cardinality explosion, disk full, ingestion drops, …).
- Compatible with the official OpenTelemetry demo — `make demo` adds the Astronomy Shop microservices for screenshots/blog content.
- One-click templates for Coolify, Dokploy, CapRover, and Jelastic.

Total: 8 containers, ~310 MB idle. Tested on Ubuntu 24.04 with 4 GB RAM.

I documented every architectural decision as an ADR (`docs/decisions/`), so when someone asks "why VictoriaLogs and not Loki?" I can point to the rationale instead of restating it. It's MIT-licensed.

Repo: https://github.com/HameemDakheel/obstack
Quickstart (5 minutes): https://github.com/HameemDakheel/obstack/blob/main/docs/quickstart.md

Happy to answer questions about the architecture, the tradeoffs, or anything you'd like to see added.

---

## First-comment template (post immediately after submission)

> Author here. A few things I figured I'd preempt:
>
> - **"Why not just use SigNoz?"** I explored that. SigNoz is great if you have the budget for the resource footprint and prefer the all-in-one approach with their custom UI. obstack targets the smaller-machine end where SigNoz currently doesn't fit, and stays on Grafana for the UI which most devs already know.
>
> - **"How is this different from `grafana/docker-otel-lgtm`?"** Grafana ships an official one-shot LGTM image too, but it includes the heavyweight Mimir+Loki+MinIO data plane that's hostile to small VPSs. obstack swaps out those three components for Prometheus + VictoriaLogs + filesystem storage, which is what makes the 311 MB idle achievable.
>
> - **"Will this scale?"** Simple profile is single-node by design. The Standard profile (v1.1) and Scale profile (v2) are planned with Prometheus → VictoriaMetrics cluster (or Mimir) upgrade paths. If you're at 100 GB/day already, this is the wrong tool right now.
>
> Pleased to hear feedback, especially edge cases I haven't hit. The whole repo is MIT — feel free to fork, improve, send PRs.

---

## Talking points (in case someone asks a hard question)

- **Cardinality explosion at scale**: Prometheus is sensitive to it. The `PrometheusHighCardinality` alert fires above 1M head series; documented runbook covers tactics to drop noisy labels at the OTel Collector via the `transform` processor before they hit storage.
- **Why not eBPF?** Coroot does eBPF + AI RCA already and they're ahead. Don't fight a head-on competitor when there's a different niche to serve.
- **Why pre-tuned alerts?** Datadog ships defaults; SigNoz doesn't. We do because v1 is opinionated for self-hosters who don't want to hand-write alert rules to start.
- **What about the demo overlay?** Optional add-on. Pulls a curated subset of `open-telemetry/opentelemetry-demo` (frontend, cart, checkout, payment, recommendation, valkey, load-generator). Needs ~8 GB RAM total, so it's evaluation-only — not for the production 4 GB VPS.
