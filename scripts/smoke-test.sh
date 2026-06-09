#!/usr/bin/env bash
set -euo pipefail

OTLP_HTTP="${OTLP_HTTP:-http://localhost:4318}"
TEMPO_URL="${TEMPO_URL:-http://localhost:3200}"

# Load TRACE_DECISION_WAIT from .env if present
if [ -f .env ]; then
  set +u
  # shellcheck disable=SC1091
  source .env 2>/dev/null || true
  set -u
fi

# Calcola tempo attesa: decision_wait + 10s di buffer per batch ed export
DW="${TRACE_DECISION_WAIT:-10s}"
if [[ "$DW" =~ ^([0-9]+)s$ ]]; then
  WAIT=$(( BASH_REMATCH[1] + 10 ))
elif [[ "$DW" =~ ^([0-9]+)m$ ]]; then
  WAIT=$(( BASH_REMATCH[1] * 60 + 10 ))
else
  WAIT=20
fi

hr() { printf '  %s\n' "──────────────────────────────────────────────────"; }

echo ""
echo "  kickstart-otel-lgtm — smoke test"
hr
echo ""

# ── Dipendenze ───────────────────────────────────────────────────────────────
if ! command -v curl > /dev/null 2>&1; then
  echo "  ERRORE: curl non trovato. Installalo con: apt install curl" >&2
  exit 1
fi

# Genera ID casuali in formato base64 (spec OTLP/JSON)
if command -v python3 > /dev/null 2>&1; then
  TRACE_ID=$(python3 -c "import os,base64; print(base64.b64encode(os.urandom(16)).decode())")
  SPAN_ID=$(python3 -c "import os,base64; print(base64.b64encode(os.urandom(8)).decode())")
elif command -v openssl > /dev/null 2>&1; then
  TRACE_ID=$(openssl rand -base64 16 | tr -d '\n')
  SPAN_ID=$(openssl rand -base64 8 | tr -d '\n')
else
  echo "  ERRORE: serve python3 o openssl per generare gli span ID." >&2
  exit 1
fi

NOW_S=$(date +%s)
START_NS="${NOW_S}000000000"
END_NS="$((NOW_S + 1))000000000"

# ── [1/3] Health check ────────────────────────────────────────────────────────
echo "  [1/3] Verifica endpoints..."
ALL_UP=true
for row in \
  "Loki|http://localhost:3100/ready" \
  "Tempo|${TEMPO_URL}/ready" \
  "Mimir|http://localhost:9009/ready" \
  "OTel Collector|http://localhost:13133/" \
  "Grafana|http://localhost:3000/api/health"; do
  label="${row%%|*}"
  url="${row##*|}"
  if curl -sf --max-time 3 "$url" > /dev/null 2>&1; then
    printf '    %-22s \033[32mUP\033[0m\n' "$label"
  else
    printf '    %-22s \033[31mDOWN\033[0m\n' "$label"
    ALL_UP=false
  fi
done
echo ""

if [ "$ALL_UP" = false ]; then
  echo "  Uno o più servizi non sono pronti. Avvia lo stack con: make up" >&2
  exit 1
fi

# ── [2/3] Invio span ──────────────────────────────────────────────────────────
echo "  [2/3] Invio span con status ERROR (sempre campionato dal tail sampler)..."

TMPFILE=$(mktemp /tmp/otel-smoke-XXXXXX.txt)
trap 'rm -f "$TMPFILE"' EXIT

HTTP_STATUS=$(curl -s -o "$TMPFILE" -w "%{http_code}" \
  -X POST "${OTLP_HTTP}/v1/traces" \
  -H "Content-Type: application/json" \
  --data-raw "{
    \"resourceSpans\": [{
      \"resource\": {
        \"attributes\": [{
          \"key\": \"service.name\",
          \"value\": {\"stringValue\": \"smoke-test\"}
        }]
      },
      \"scopeSpans\": [{
        \"spans\": [{
          \"traceId\": \"${TRACE_ID}\",
          \"spanId\": \"${SPAN_ID}\",
          \"name\": \"smoke-test-span\",
          \"kind\": 2,
          \"startTimeUnixNano\": \"${START_NS}\",
          \"endTimeUnixNano\": \"${END_NS}\",
          \"status\": {\"code\": 2, \"message\": \"intentional error for smoke test\"}
        }]
      }]
    }]
  }")

if [ "$HTTP_STATUS" = "200" ]; then
  echo "  Span accettato dal collector (HTTP 200)"
else
  echo "  ERRORE: il collector ha risposto HTTP ${HTTP_STATUS}" >&2
  cat "$TMPFILE" >&2
  exit 1
fi
echo ""

# ── [3/3] Verifica in Tempo ───────────────────────────────────────────────────
echo "  [3/3] Attendo ${WAIT}s (tail sampling: ${DW} + buffer batch/export)..."

# Spinner minimale
i=0
while [ $i -lt "$WAIT" ]; do
  printf '\r  %ds rimanenti...' "$((WAIT - i))"
  sleep 1
  i=$((i + 1))
done
printf '\r  %s\n' "                        "

RESULT=$(curl -sf --max-time 5 \
  "${TEMPO_URL}/api/search?tags=service.name%3Dsmoke-test&limit=1" 2>/dev/null || echo "")

if echo "${RESULT}" | grep -q '"traceID"'; then
  echo "  Trace trovata in Tempo."
  hr
  echo ""
  echo "  Stack funzionante end-to-end."
  echo "  Apri Grafana con: make open"
else
  echo "  ATTENZIONE: nessuna trace trovata in Tempo dopo ${WAIT}s."
  echo ""
  echo "  Possibili cause:"
  echo "    - TRACE_DECISION_WAIT lungo (attuale: ${DW}) — riprova tra qualche secondo"
  echo "    - Errori nell'export: make logs s=otel-collector"
  echo "    - Stack non ancora completamente avviato: make check"
fi
echo ""
