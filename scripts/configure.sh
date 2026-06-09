#!/usr/bin/env bash
set -euo pipefail

# Load existing values as defaults (ignore errors on unbound vars)
if [ -f .env ]; then
  set +u
  # shellcheck disable=SC1091
  source .env
  set -u
fi

ask() {
  local var="$1"
  local prompt="$2"
  local default="$3"
  local current="${!var:-}"
  local effective="${current:-$default}"
  local input
  read -rp "  $prompt [$effective]: " input
  echo "${input:-$effective}"
}

hr() { printf '  %s\n' "$(printf '%.0s─' {1..50})"; }

validate_retention() {
  local val="$1" label="$2"
  if ! [[ "$val" =~ ^[0-9]+[hdw]$ ]]; then
    echo "  ERRORE: $label deve avere formato <numero>h|d|w (es: 744h, 30d, 4w)." >&2
    exit 1
  fi
}

echo ""
echo "  kickstart-otel-lgtm — setup guidato"
hr
echo ""

# ── Grafana ──────────────────────────────────────────────────────────────────
echo "  [1/3] Grafana"
echo "        Credenziali dell'interfaccia web."
echo ""
GF_USER=$(ask  GF_SECURITY_ADMIN_USER     "Admin user"     "admin")
GF_PASS=$(ask  GF_SECURITY_ADMIN_PASSWORD "Admin password" "admin")

if [[ "$GF_PASS" == "admin" ]]; then
  echo ""
  echo "  ATTENZIONE: stai usando la password di default 'admin'."
  echo "              Cambiala prima di esporre lo stack su rete pubblica."
fi
echo ""

# ── Trace Sampling ───────────────────────────────────────────────────────────
echo "  [2/3] Trace sampling"
echo "        Errori e trace lente sono sempre mantenuti al 100%."
echo "        Il campionamento si applica solo alle trace sane e veloci."
echo ""
SAMPLING_RATE=$(ask  TRACE_SAMPLING_RATE          "Campionamento trace sane (%)"              "20")
LATENCY_MS=$(ask     TRACE_LATENCY_THRESHOLD_MS   "Soglia latenza sempre preservata (ms)"     "2000")
DECISION_WAIT=$(ask  TRACE_DECISION_WAIT          "Finestra raccolta span (es: 10s, 15s)"     "10s")
echo ""

# ── Retention ────────────────────────────────────────────────────────────────
echo "  [3/3] Retention dei dati"
echo "        Per quanto tempo conservare log, trace e metriche."
echo "        Suffissi validi: h (ore), d (giorni), w (settimane)"
echo ""
LOKI_RET=$(ask   LOKI_RETENTION_PERIOD   "Log retention      (default 31gg)" "744h")
TEMPO_RET=$(ask  TEMPO_BLOCK_RETENTION   "Trace retention    (default  7gg)" "168h")
MIMIR_RET=$(ask  MIMIR_BLOCKS_RETENTION  "Metriche retention (default 90gg)" "2160h")
echo ""

# ── Validazione ──────────────────────────────────────────────────────────────
if ! [[ "$SAMPLING_RATE" =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
   (( $(echo "$SAMPLING_RATE > 100" | bc -l) )); then
  echo "  ERRORE: TRACE_SAMPLING_RATE deve essere un numero tra 0 e 100." >&2
  exit 1
fi

if ! [[ "$LATENCY_MS" =~ ^[0-9]+$ ]]; then
  echo "  ERRORE: TRACE_LATENCY_THRESHOLD_MS deve essere un intero (millisecondi)." >&2
  exit 1
fi

if ! [[ "$DECISION_WAIT" =~ ^[0-9]+(s|m)$ ]]; then
  echo "  ERRORE: TRACE_DECISION_WAIT deve avere il formato <numero>s o <numero>m (es: 10s)." >&2
  exit 1
fi

validate_retention "$LOKI_RET"  "LOKI_RETENTION_PERIOD"
validate_retention "$TEMPO_RET" "TEMPO_BLOCK_RETENTION"
validate_retention "$MIMIR_RET" "MIMIR_BLOCKS_RETENTION"

# ── Scrittura .env ────────────────────────────────────────────────────────────
cat > .env <<EOF
# Grafana admin credentials
GF_SECURITY_ADMIN_USER=${GF_USER}
GF_SECURITY_ADMIN_PASSWORD=${GF_PASS}

# Retention (h = ore, d = giorni, w = settimane)
LOKI_RETENTION_PERIOD=${LOKI_RET}
TEMPO_BLOCK_RETENTION=${TEMPO_RET}
MIMIR_BLOCKS_RETENTION=${MIMIR_RET}

# Trace sampling
# TRACE_SAMPLING_RATE          → % di trace sane campionate (0-100)
# TRACE_LATENCY_THRESHOLD_MS   → trace piu' lente di Xms sempre mantenute
# TRACE_DECISION_WAIT          → finestra di attesa per raccogliere tutti gli span
TRACE_SAMPLING_RATE=${SAMPLING_RATE}
TRACE_LATENCY_THRESHOLD_MS=${LATENCY_MS}
TRACE_DECISION_WAIT=${DECISION_WAIT}
EOF

hr
echo ""
echo "  .env aggiornato. Riepilogo:"
echo ""
echo "    Grafana user           : ${GF_USER}"
echo "    Grafana password       : ${GF_PASS}"
echo "    Campionamento          : ${SAMPLING_RATE}% delle trace sane"
echo "    Soglia latenza         : trace > ${LATENCY_MS}ms sempre mantenute"
echo "    Finestra span          : ${DECISION_WAIT}"
echo "    Log retention          : ${LOKI_RET}"
echo "    Trace retention        : ${TEMPO_RET}"
echo "    Metriche retention     : ${MIMIR_RET}"
echo ""
echo "  Avvia lo stack con: make up"
echo ""
