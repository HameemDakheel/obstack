# r/selfhosted launch post draft

## Subreddit

**r/selfhosted** — primary
**r/devops** — secondary (different audience, different angle; consider day +2)
**r/grafana** — tertiary (they like Grafana ecosystem stories)

## Title

**[Project] obstack — production observability stack for your $20/month VPS, 311 MB idle, all 5 signals**

## Body

Hey r/selfhosted!

I built **obstack** because every self-hosted observability stack I tried either ate 3+ GB of RAM at idle (LGTM) or required 56 CPU and 152 GB RAM in production (SigNoz, per their own docs). Neither fits on the VPS most of us actually run.

obstack is OpenTelemetry-native and **idles at ~311 MB** total across 8 containers. Everything is auto-provisioned — you `git clone`, `make simple`, open Grafana, and you immediately see 4 dashboards populated with live data (the stack monitors itself).

### What's inside
- **Caddy** — auto-TLS via Let's Encrypt, basic auth on OTLP ingestion.
- **OpenTelemetry Collector** (upstream contrib) — receives your OTLP, fans out to backends.
- **Prometheus** for metrics, **VictoriaLogs** for logs (~87% less RAM than Loki), **Tempo** for traces, **Pyroscope** for continuous profiling.
- **Grafana** with 4 pre-built dashboards in the obstack folder + 12 pre-tuned alerts already loaded.
- **cAdvisor** for per-container CPU/RAM/network metrics.

### Why I think it's interesting for self-hosters
- **Real defaults.** No "follow this 14-step Helm chart configuration." Run one command, get production-grade setup.
- **One-click PaaS templates** for **Coolify, Dokploy, CapRover, and Jelastic** so you can deploy without `git clone`-ing if that's your workflow.
- **Demo overlay** — `make demo` adds the official OpenTelemetry demo microservices so you can see real traces flowing in the dashboards (good for evaluation; needs 8 GB+).
- **MIT-licensed** — fork it, modify it, sell it. No surprise rug-pull.

### Repository
https://github.com/HameemDakheel/obstack

5-minute quickstart: https://github.com/HameemDakheel/obstack/blob/main/docs/quickstart.md

### Screenshots

[REPLACE WITH REAL IMAGES on launch day; placeholders below]

- *(Stack Health dashboard with live ingestion-rate panels)*
- *(Container Metrics dashboard showing per-container CPU/RAM)*
- *(Traces Browser showing the demo Astronomy Shop service graph)*
- *(make verify terminal output: 7 passed, 0 failed)*

### What's NOT yet there
Honest list:
- Single-node only at v1 (Simple profile). Multi-node Scale profile is planned for v2.
- No automated screenshots in this thread because I want to capture them when there's enough data variety. Will edit the post.
- Not yet listed in Coolify/Dokploy/CapRover marketplaces (PRs going up next week).
- Multi-tenancy is Enterprise-profile work (v3).

### Sample 4 GB VPS deployment

If you have a Hetzner CPX21 (4 GB / 2 vCPU / 80 GB SSD, ~$8.50/mo) or DigitalOcean basic droplet, this works comfortably:

```bash
git clone https://github.com/HameemDakheel/obstack.git
cd obstack
cp .env.example .env
# Generate basic-auth hash (one line)
docker run --rm caddy:2-alpine caddy hash-password --plaintext 'YOUR_PASSWORD'
# Paste output into .env, then:
make simple
make verify
```

Open `https://your-domain/`, login admin / GRAFANA_ADMIN_PASSWORD from .env. Done.

### Why I built this

I'm a solo dev. Watching Datadog cost more than my whole infrastructure was the breaking point. Tried LGTM, hit RAM limits. Tried SigNoz, hit CPU limits. Built the stack I wished existed.

Happy to answer questions, take feedback, accept PRs. The architecture decisions are all documented as ADRs in the repo, so "why VictoriaLogs and not Loki?" gets a real answer.

Cheers!

---

## Engagement plan

- **Reply within 30 minutes** to every top-level comment for the first 6 hours.
- **Don't argue** — disagreements stay technical. "Here's the data point I was working with; happy to be corrected."
- **Common questions** (have replies pre-drafted):
  - "How does this compare to [SigNoz | OpenObserve | HyperDX]?" → Reference the comparison table in the README; acknowledge their strengths.
  - "What about Prometheus cardinality?" → Point to the high-cardinality runbook.
  - "Is the Pyroscope datasource really useful?" → Yes, especially with Tempo's `tracesToProfilesV2` correlation — span → flame graph in one click.
  - "Why MIT and not AGPL/SSPL?" → Self-hoster freedom matters more than enterprise-extraction protection at this stage.
