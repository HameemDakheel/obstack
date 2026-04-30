#!/usr/bin/env bash
# demo-up.sh — bring up the upstream OTel demo, configured to forward
# all telemetry to obstack's public OTLP endpoint with HTTP Basic auth.
#
# Reads examples/otel-demo/.env, base64-encodes the credentials, exports
# DEMO_OBSTACK_BASIC_AUTH, then runs docker compose with the upstream
# compose + obstack override.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEMO_DIR="$REPO_ROOT/examples/otel-demo"
UPSTREAM="$DEMO_DIR/upstream/docker-compose.yml"
OVERRIDE="$DEMO_DIR/docker-compose.override.yml"

cd "$DEMO_DIR"

if [[ ! -f .env ]]; then
  if [[ -f .env.example ]]; then
    echo "→ Creating .env from .env.example (edit it before re-running for production)"
    cp .env.example .env
  else
    echo "ERROR: no .env or .env.example in $DEMO_DIR" >&2
    exit 1
  fi
fi

if [[ ! -f "$UPSTREAM" ]]; then
  echo "→ Cloning upstream OTel demo (v2.2.0) into $DEMO_DIR/upstream"
  git clone --depth 1 --branch 2.2.0 \
    https://github.com/open-telemetry/opentelemetry-demo \
    "$DEMO_DIR/upstream"
fi

# Re-apply our otelcol-config-extras.yml in case the clone overwrote it.
EXTRAS_SRC="$DEMO_DIR/otelcol-config-extras.obstack.yml"
EXTRAS_DST="$DEMO_DIR/upstream/src/otel-collector/otelcol-config-extras.yml"
if [[ -f "$EXTRAS_SRC" ]]; then
  cp "$EXTRAS_SRC" "$EXTRAS_DST"
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

: "${DEMO_BASIC_AUTH_USER:?must be set in .env}"
: "${DEMO_BASIC_AUTH_PASSWORD:?must be set in .env}"
: "${DEMO_OBSTACK_ENDPOINT:?must be set in .env}"

B64="$(printf '%s:%s' "$DEMO_BASIC_AUTH_USER" "$DEMO_BASIC_AUTH_PASSWORD" | base64 -w0 2>/dev/null || \
       printf '%s:%s' "$DEMO_BASIC_AUTH_USER" "$DEMO_BASIC_AUTH_PASSWORD" | base64)"
export DEMO_OBSTACK_BASIC_AUTH="Basic $B64"

echo "→ Starting demo (endpoint=$DEMO_OBSTACK_ENDPOINT, user=$DEMO_BASIC_AUTH_USER)"

docker compose \
  --env-file "$DEMO_DIR/upstream/.env" \
  --env-file "$DEMO_DIR/.env" \
  -f "$UPSTREAM" \
  -f "$OVERRIDE" \
  -p obstack-demo \
  up -d

echo ""
echo "Demo starting (~2 min — kafka and opensearch take a while to warm up)."
echo "Frontend:    http://localhost:8080/"
echo "Telemetry:   check obstack Grafana → Traces Browser for service.namespace=opentelemetry-demo"
