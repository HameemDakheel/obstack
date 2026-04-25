# Twitter/X launch thread draft

7 tweets. Post 1 hour after the HN submission goes live so it doesn't compete with HN traffic.

---

## Tweet 1 (anchor)

🔭 Just shipped obstack v1.0.0 — production observability for your $20/month VPS.

All 5 OpenTelemetry signals (logs, metrics, traces, profiles, dashboards) running on 8 containers in **311 MB of RAM**.

One command. MIT-licensed.

🧵👇

[Image: hero screenshot of Grafana with the 4 obstack dashboards in the sidebar, populated with live data]

---

## Tweet 2 (the problem)

I tried every "self-hosted observability" option:

• LGTM stack → 3+ GB RAM idle
• SigNoz → 56 CPU / 152 GB RAM in prod (their own docs!)
• OpenObserve → great, but no profiling
• Roll-your-own → 14 hours of YAML

None of them fit a 4 GB VPS. So I built the one I wanted.

---

## Tweet 3 (the stack)

Hybrid stack to keep it light:

🔵 Prometheus (metrics)
🟣 VictoriaLogs (logs — 87% less RAM than Loki)
🟢 Tempo (traces)
🔴 Pyroscope (profiles)
🟡 Grafana (UI, the moat)
⚪ OTel Collector contrib (ingest)
🟠 Caddy (auto-TLS)
⚫ cAdvisor (container metrics)

---

## Tweet 4 (out of the box)

Open Grafana on first launch — you immediately see:

✅ 4 pre-built dashboards (auto-provisioned)
✅ 12 alert rules already firing on stack health
✅ All 4 datasources connected
✅ Live self-monitoring data (no synthetic seeder)

No clicks. Real data. Day 1.

[Image: screenshot of Container Metrics dashboard showing per-container CPU/RAM]

---

## Tweet 5 (deploy paths)

One-click templates for the PaaS people actually use:

🚢 Coolify
🚢 Dokploy
🚢 CapRover
🚢 Jelastic

Or the OG: `git clone` + `make simple` on any Linux box with Docker. ~3 minutes from zero to populated dashboards.

---

## Tweet 6 (ADRs)

Every architectural decision is documented as an ADR.

"Why VictoriaLogs instead of Loki?" → docs/decisions/0001
"Why Prometheus instead of Mimir?" → docs/decisions/0005
"Why no MinIO?" → docs/decisions/0004

When someone forks this 6 months from now, the *why* is right there.

---

## Tweet 7 (CTA)

🔗 Repo: https://github.com/HameemDakheel/obstack
📚 Quickstart: https://github.com/HameemDakheel/obstack/blob/main/docs/quickstart.md
💬 Show HN: [LINK TO HN POST]

If you're paying Datadog more than you're paying for AWS — this is for you.

🌟 if it helped.

---

## Notes

- Replace `[LINK TO HN POST]` after submitting to HN.
- Add the screenshots referenced in Tweets 1 and 4 — both 1600×900, dark mode if Grafana looks better that way.
- Don't quote-tweet other people's projects in this thread — keep it focused on obstack.
- Pin Tweet 1 to your profile for ~7 days post-launch.
- For LinkedIn / Mastodon: paraphrase but link to the same repo and quickstart. Don't repost Twitter verbatim.
