# Screenshots

> Real screenshots of the running stack. Captured manually, committed here, referenced from the README and the docs.

## Why this directory has a README and no images yet

OTel-jps v1.0.0 ships before screenshots are captured. Reasons:

- Good screenshots need 30+ minutes of accumulated data so dashboards aren't empty.
- Lighting (light vs dark mode), viewport size, and crop framing all matter — easier to redo manually than automate poorly.
- The `make demo` overlay produces realistic microservice traces that make the Traces Browser dashboard much more compelling — but the demo runs separately from the production stack.

Capture once, commit, then update the README and docs to reference the images. Plan: do this in a follow-up PR within the first 7 days post-launch.

---

## What to capture

Each screenshot below should be:

- **1920 × 1080** (so it crops cleanly to 1600 × 900 for the README hero)
- **Dark mode** (Grafana default) unless light reads better in context
- Free of any personal info (real domains, email addresses, IPs in URL bar)
- Committed as PNG (lossless), filename per the table below

| Filename | Subject | When to capture |
|----------|---------|-----------------|
| `01-grafana-login.png` | Grafana login page (just the form) | Immediately after `make simple` |
| `02-otel-jps-folder.png` | Grafana sidebar showing OTel-jps folder expanded with the 4 dashboards | After 1 minute of stack running |
| `03-stack-health.png` | Stack Health dashboard, all panels populated | After 30 minutes of self-monitoring data |
| `04-container-metrics.png` | Container Metrics dashboard, CPU/RAM panels showing real time-series | After 30 minutes |
| `05-logs-explorer.png` | Logs Explorer dashboard with VictoriaLogs query showing real recent logs | After 30 minutes |
| `06-traces-browser-demo.png` | Traces Browser **with the OTel demo running** so the service graph shows demo.frontend → demo.cart → demo.checkout → demo.payment | Run `make demo` first; wait 5 minutes |
| `07-traces-browser-heatmap.png` | Traces Browser span-duration heatmap with visible heat (red = slower spans) | While demo is running |
| `08-alerts-list.png` | Grafana → Alerting → Alert rules, showing 12 default rules loaded | After `make simple` |
| `09-make-verify-output.png` | Terminal showing `make verify` output: 7 passed, 0 failed | Capture from a clean run |

## Capture checklist

For each screenshot:

- [ ] Stack idle ≥ 30 minutes (or demo running ≥ 5 minutes for traces).
- [ ] Browser zoom at 100%, dev tools closed.
- [ ] Window at 1920 × 1080. Use Chrome DevTools "Device Toolbar" with custom dimensions if your real screen differs.
- [ ] Take the screenshot via the browser's built-in capture or a tool like Flameshot.
- [ ] Crop generously — leave breathing room around panels.
- [ ] Save as PNG with the exact filename from the table above.

## After capture

Update the relevant files to embed the images:

1. **README.md** — replace the placeholder `[Image: ...]` lines with `![alt](assets/screenshots/01-grafana-login.png)` style refs.
2. **launch/show-hn.md, launch/reddit-selfhosted.md, launch/announce-twitter.md** — replace `[REPLACE WITH REAL IMAGES]` with image refs.
3. **docs/architecture.md, docs/quickstart.md** — embed the relevant ones inline near their first mention.

Commit the screenshots in a single PR titled something like *"docs: add screenshots from running stack."*

## Optional: animated GIF for the README hero

A 5–10-second GIF showing `make simple` → wait → open Grafana → click into a dashboard adds a lot to the README hero. Tools:

- **`asciinema`** for terminal sequences (export to GIF via `agg`).
- **`peek`** or **OBS Studio** for browser action.

Keep under 5 MB so GitHub renders it inline. Save as `00-hero.gif`.

## Don't commit

- Screenshots with real domains other than `localhost`/`example.com` (PII concern).
- Screenshots with the actual `BASIC_AUTH_HASH` visible.
- Massive PNGs > 1 MB each. Compress first via `pngquant`/`oxipng`.
- Screenshots from beta versions older than the current tag.
