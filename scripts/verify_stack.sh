#!/usr/bin/env bash
# verify_stack.sh — health-check every component in the OTel-jps stack.
# Usage: ./scripts/verify_stack.sh
# Exits 0 if all components are healthy, non-zero otherwise.

set -euo pipefail

DOMAIN="${DOMAIN:-localhost}"
SCHEME="${SCHEME:-https}"
TIMEOUT="${TIMEOUT:-10}"

# Component → (container name, internal endpoint, expected substring or empty for HTTP 200)
declare -A CHECKS=(
  ["caddy"]="otel-jps-caddy|http://localhost:2019/config/|"
  ["otel-collector"]="otel-jps-otelcol|http://localhost:13133/|"
  ["prometheus"]="otel-jps-prometheus|http://localhost:9090/-/ready|Prometheus is Ready"
  ["victorialogs"]="otel-jps-victorialogs|http://localhost:9428/health|"
  ["tempo"]="otel-jps-tempo|http://localhost:3200/ready|ready"
  ["pyroscope"]="otel-jps-pyroscope|http://localhost:4040/ready|"
  ["grafana"]="otel-jps-grafana|http://localhost:3000/api/health|database"
)

PASS=0
FAIL=0
RESULTS=()

check_component() {
  local name="$1"
  local container="$2"
  local url="$3"
  local expected="$4"

  if ! docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null | grep -q running; then
    RESULTS+=("FAIL $name (container not running)")
    return 1
  fi

  local body
  if ! body="$(docker exec "$container" wget -qO- --timeout="$TIMEOUT" "$url" 2>&1)"; then
    RESULTS+=("FAIL $name (HTTP request failed: $url)")
    return 1
  fi

  if [[ -n "$expected" ]] && ! echo "$body" | grep -q "$expected"; then
    RESULTS+=("FAIL $name (expected '$expected' in response)")
    return 1
  fi

  RESULTS+=("PASS $name")
  return 0
}

echo "── OTel-jps stack verification ──────────────────"
for name in caddy otel-collector prometheus victorialogs tempo pyroscope grafana; do
  IFS='|' read -r container url expected <<< "${CHECKS[$name]}"
  if check_component "$name" "$container" "$url" "$expected"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
  fi
done

printf '\n'
for r in "${RESULTS[@]}"; do
  echo "  $r"
done

printf '\n── %d passed, %d failed ─────────────────────────\n' "$PASS" "$FAIL"

if (( FAIL > 0 )); then
  exit 1
fi

# Smoke: send an OTLP HTTP trace request through Caddy
echo "── OTLP smoke test ──────────────────────────────"
if [[ "${BASIC_AUTH_USER:-}" && "${BASIC_AUTH_PASSWORD:-}" ]]; then
  CURL_AUTH=(-u "${BASIC_AUTH_USER}:${BASIC_AUTH_PASSWORD}")
else
  echo "  (skipping; set BASIC_AUTH_USER and BASIC_AUTH_PASSWORD to test ingestion)"
  CURL_AUTH=()
fi

if (( ${#CURL_AUTH[@]} > 0 )); then
  HTTP_CODE="$(curl -k -sS -o /dev/null -w '%{http_code}' \
    "${CURL_AUTH[@]}" \
    -H 'Content-Type: application/json' \
    -d '{"resourceSpans":[]}' \
    "${SCHEME}://${DOMAIN}/v1/traces" || true)"

  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    echo "  PASS OTLP HTTP traces endpoint (HTTP $HTTP_CODE)"
  else
    echo "  FAIL OTLP HTTP traces endpoint (HTTP $HTTP_CODE)"
    exit 1
  fi
fi

echo "✅ All checks passed."
