#!/usr/bin/env bash
# demo-up.sh — bring up examples/otel-demo with computed Basic-auth header.
# Reads examples/otel-demo/.env (or .env.example as fallback), base64-encodes
# the credentials, exports DEMO_OBSTACK_AUTH_HEADER, then docker compose up -d.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEMO_DIR="$REPO_ROOT/examples/otel-demo"

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

# Source vars from .env without leaking quoting.
set -a
# shellcheck disable=SC1091
source .env
set +a

: "${DEMO_BASIC_AUTH_USER:?must be set in .env}"
: "${DEMO_BASIC_AUTH_PASSWORD:?must be set in .env}"
: "${DEMO_OBSTACK_ENDPOINT:?must be set in .env}"

# Compute and export the OTLP header.
B64="$(printf '%s:%s' "$DEMO_BASIC_AUTH_USER" "$DEMO_BASIC_AUTH_PASSWORD" | base64 -w0 2>/dev/null || \
       printf '%s:%s' "$DEMO_BASIC_AUTH_USER" "$DEMO_BASIC_AUTH_PASSWORD" | base64)"
export DEMO_OBSTACK_AUTH_HEADER="authorization=Basic $B64"

echo "→ Starting demo (endpoint=$DEMO_OBSTACK_ENDPOINT, user=$DEMO_BASIC_AUTH_USER)"
docker compose up -d

echo ""
echo "Demo starting (~2 min). Check obstack's Traces Browser dashboard for the service graph."
echo "Frontend: http://localhost:${DEMO_FRONTEND_PORT:-8082}/"
