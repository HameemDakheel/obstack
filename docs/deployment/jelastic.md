# Deploy on Jelastic

> **What you'll need:** an account on a Jelastic-based PaaS (mirohost, Layershift, Hostinger Cloud, OVH Jelastic, etc.).
> **Time to complete:** ~5 minutes — Jelastic has the most automated install of any PaaS we support.

[Jelastic](https://jelastic.com) is a turnkey PaaS sold by hosting providers. Its JPS (Jelastic Packaging Standard) format lets the entire obstack install be expressed as a single manifest the Jelastic dashboard reads and executes.

---

## Step 1 — Prerequisites

You need:
- An account on any Jelastic-based hosting provider.
- Enough quota for **at least 4 cloudlets fixed and 24 cloudlets max** (~3 GB max RAM).

That's it. Jelastic provisions Docker, the domain, the SSL cert, and the storage automatically.

---

## Step 2 — Import the manifest

1. In the Jelastic dashboard, click **Import** in the top toolbar (icon looks like an arrow into a tray).
2. Choose **URL** and paste:

   ```
   https://raw.githubusercontent.com/HameemDakheel/obstack/main/templates/jelastic/manifest.jps
   ```

   *(Or upload `templates/jelastic/manifest.jps` from a local clone of the repo.)*

3. Jelastic parses the manifest and shows a settings dialog.

---

## Step 3 — Configure

Fill the prompted fields:

| Field | Default | What it does |
|-------|---------|-------------|
| Git repository URL | `https://github.com/HameemDakheel/obstack.git` | Where to clone obstack from |
| Git tag or branch | `v1.0.0-alpha.4` | Version to deploy. Use `main` for bleeding edge. |
| Environment name | `obstack` | Jelastic environment name (becomes part of the auto-issued domain) |
| Alert webhook URL | `https://example.invalid/alert` | Optional Slack/Discord webhook |

Jelastic auto-generates:
- Grafana admin password (16 chars)
- OTLP basic-auth password (24 chars) and its bcrypt hash
- Lets-Encrypt SSL cert via the platform's built-in flow

Click **Install**. ~3-5 minutes.

---

## Step 4 — Check the success screen

When install completes, Jelastic shows a success message with everything you need:

- **Grafana URL**: `https://<env>.<provider-domain>/`
- **Grafana admin password** (generated)
- **OTLP basic-auth username + password** (generated)
- **OTLP HTTPS endpoint**: `https://<env>.<provider-domain>/v1/{traces,metrics,logs}`

The same info is emailed to your Jelastic account.

---

## Step 5 — Verify

Open the Grafana URL. Login with the credentials shown. Confirm you see 4 pre-built dashboards in the obstack folder.

If you want to trigger the same verify-stack script as the local install:

```
Jelastic dashboard → environment → ... menu → Add-Ons → ⋯ → Run action → verify
```

---

## Step 6 — Connect other Jelastic apps via the linker

If you have other Jelastic environments (Node app, Spring Boot service, Django app), the **linker.jps** add-on automatically configures them to send telemetry here.

1. Go to your application environment (the one you want to instrument).
2. Click **Add-Ons → Import**.
3. Paste:

   ```
   https://raw.githubusercontent.com/HameemDakheel/obstack/main/templates/jelastic/linker.jps
   ```

4. Configure:
   - obstack environment name (e.g. `obstack`)
   - obstack public domain (the one Jelastic issued)
   - Basic-auth username and **plaintext** password (the one shown on the obstack install success screen)
   - Service name (defaults to your environment name)
   - Sampling ratio (default `1.0` = sample everything)

5. Click **Install**. The linker injects OTLP env vars into every container in the target environment.

6. Restart the target application — it picks up `OTEL_EXPORTER_OTLP_ENDPOINT` and starts sending telemetry.

---

## Day-2 ops

The manifest exposes these as Jelastic actions (run from the Add-Ons menu):

| Action | What it does |
|--------|-------------|
| `upgrade` | `git fetch` + `make update` — pulls the latest tag and recreates containers |
| `restart` | `make restart` |
| `logs` | Tails last 100 lines from each container |
| `verify` | Runs `verify_stack.sh` |
| `checkStack` | Compose ps + recent logs |

---

## Troubleshooting (Jelastic-specific)

- **Install fails at "deployStack" with git errors** — your Jelastic provider may block outbound HTTPS to GitHub. Configure the `repoUrl` setting to point to a mirror, or import the manifest from a private GitLab.
- **"Pre-allocated cloudlets exceeded" error** — increase the cloudlet limit in your Jelastic plan.
- **Grafana shows "502 Bad Gateway"** — Jelastic's load balancer can race ahead of the Caddy startup. Wait 30 s after install completes and refresh.
- **OTLP gRPC port 4317 unreachable from outside** — the manifest opens port 4317 in the Jelastic SLB rules. If your provider customizes SLB behavior, you may need to manually add port 4317 in the environment's **Endpoints** tab.

---

## See also

- [Quickstart](../quickstart.md)
- [Architecture](../architecture.md)
- [Jelastic template README](https://github.com/HameemDakheel/obstack/blob/main/templates/jelastic/README.md)
- [Jelastic JPS documentation](https://docs.jelastic.com/manifest-overview/)
