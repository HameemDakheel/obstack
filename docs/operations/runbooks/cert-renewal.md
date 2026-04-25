# Runbook: Cert renewal

**Severity:** warning (until expiry imminent, then critical)
**Likely alert:** none built-in at v1 (cert-monitoring is a Phase 2-tier polish; alert is `CertExpiringSoon` if you add it)
**Time to remediate:** ~5 minutes

Caddy auto-renews Let's Encrypt certificates ~30 days before expiry. The vast majority of users never need to touch this. This runbook covers the rare cases where auto-renewal fails.

## Symptoms

- Browsers warn about an expired certificate.
- `openssl s_client -connect <DOMAIN>:443 -servername <DOMAIN> 2>/dev/null | openssl x509 -noout -dates` shows past `notAfter`.
- Caddy logs (`docker logs otel-jps-caddy`) show `failed to renew certificate` or `certificate has expired`.

## Root causes

- Port 80 blocked at firewall → ACME HTTP-01 challenge fails.
- DNS for `DOMAIN` no longer points to the host.
- Let's Encrypt rate limit hit (50 certs/week per registered domain; **5 failures per hour**).
- Caddy's `caddy_data` volume corrupted or wiped.
- `ACME_EMAIL` invalid, causing renewal notification bounces (LE only emails for renewal failures, doesn't block renewal).

## Triage (read-only)

```bash
# Current cert status (Caddy admin API)
docker exec otel-jps-caddy curl -s http://localhost:2019/config/ | grep -A 5 issuers

# Expiry date as seen by the world
echo | openssl s_client -connect <DOMAIN>:443 -servername <DOMAIN> 2>/dev/null \
  | openssl x509 -noout -dates

# Caddy renewal logs
docker logs otel-jps-caddy 2>&1 | grep -iE 'renew|certificate|acme'

# Is port 80 reachable?
curl -I http://<DOMAIN>/ 2>&1 | head -3
```

## Remediate

### Trigger an immediate renewal attempt

```bash
docker exec otel-jps-caddy caddy reload --config /etc/caddy/Caddyfile
```

Wait ~1 minute, check logs for `obtained certificate` messages.

### Fix port 80 reachability

Caddy needs port 80 reachable from the public internet for the ACME HTTP-01 challenge.

```bash
# Verify host firewall
sudo iptables -L -n | grep '80'   # or sudo ufw status

# Verify cloud provider firewall / security group allows 80
# (manually check at AWS/GCP/Hetzner/etc. console)
```

### Fix DNS

```bash
dig +short <DOMAIN>
# Should return your VPS public IP
```

If DNS is wrong, fix it at your DNS provider, wait for propagation (TTL), then trigger renewal.

### Recover from corrupted `caddy_data`

```bash
make stop
docker volume rm otel-jps_caddy_data
make simple
```

Caddy will re-issue from scratch. Make sure port 80 is open *before* doing this (you'll burn a Let's Encrypt issuance quota each retry).

### Hit Let's Encrypt rate limit

If the host failed renewal multiple times, you may have hit the 5-failures-per-hour rate limit. Wait at least 1 hour, fix the root cause, then retry.

For long-term debugging, switch to Let's Encrypt **staging** (no rate limits, untrusted certs):

In `Caddyfile`:

```caddyfile
{
    email {$ACME_EMAIL:admin@example.com}
    acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
}
```

Iterate until renewal works, then switch back to production by removing the `acme_ca` line.

## Verify recovery

```bash
echo | openssl s_client -connect <DOMAIN>:443 -servername <DOMAIN> 2>/dev/null \
  | openssl x509 -noout -dates
```

`notAfter` should be ~90 days from now.

Browser: visit `https://<DOMAIN>/` — no cert warnings.

## Prevention

- **Don't disable port 80.** Caddy uses HTTP-01 by default. If port 80 must be closed, switch Caddy to DNS-01 (configurable per provider; out of scope for this runbook).
- Set a calendar reminder 60 days from issuance to verify auto-renewal worked. Or set up an external uptime/cert-monitoring service (e.g. UptimeRobot).
- Don't `make clean` on a production host without re-issuing time budgeted in.

## See also

- [Caddy Automatic HTTPS docs](https://caddyserver.com/docs/automatic-https)
- [Let's Encrypt rate limits](https://letsencrypt.org/docs/rate-limits/)
- [Troubleshooting](../troubleshooting.md)
