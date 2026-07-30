#!/usr/bin/env bash
# Bulk-Ping v3 — parallel host reachability (ICMP, optional TCP)
set -euo pipefail

VERSION="3.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/results"
CONCURRENCY=50
COUNT=1
TIMEOUT=2
TCP_PORT=""
SILENT=0
TAR=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
  cat <<EOF
Bulk-Ping v${VERSION} — bulk host liveness

Usage:
  ./bulk_ping.sh -f <hosts.txt> [options]

Options:
  -f FILE          Hosts/IPs file (required)
  -o DIR           Output directory (default: ./results)
  -c N             Concurrency (default: ${CONCURRENCY})
  -W SECONDS       Per-probe timeout (default: ${TIMEOUT})
  --tcp PORT       Also try TCP connect to PORT (useful when ICMP is blocked)
  -q, --silent     Less noise
  -h, --help       Help

Outputs:
  up.txt, down.txt, summary.txt

Examples:
  ./bulk_ping.sh -f hosts.txt
  ./bulk_ping.sh -f hosts.txt -c 100 --tcp 443
EOF
  exit 0
}

banner() {
  [[ "$SILENT" -eq 1 ]] && return
  echo -e "${GREEN}"
  cat <<'EOF'
██████╗░██╗░░░██╗██╗░░░░░██╗░░██╗  ██████╗░██╗███╗░░██╗░██████╗░
██╔══██╗██║░░░██║██║░░░░░██║░██╔╝  ██╔══██╗██║████╗░██║██╔════╝░
██████╦╝██║░░░██║██║░░░░░█████═╝░  ██████╔╝██║██╔██╗██║██║░░██╗░
██╔══██╗██║░░░██║██║░░░░░██╔═██╗░  ██╔═══╝░██║██║╚████║██║░░╚██╗
██████╦╝╚██████╔╝███████╗██║░╚██╗  ██║░░░░░██║██║░╚███║╚██████╔╝
╚═════╝░░╚═════╝░╚══════╝╚═╝░░╚═╝  ╚═╝░░░░░╚═╝╚═╝░░╚══╝░╚═════╝░
EOF
  echo -e "  Bulk-Ping v${VERSION}${NC}"
  echo -e "  Date: $(date)"
  echo ""
}

info() { [[ "$SILENT" -eq 1 ]] && return; echo -e "${CYAN}[*]${NC} $*"; }

is_up() {
  local host="$1"
  # ICMP
  if ping -c "$COUNT" -W "$TIMEOUT" "$host" >/dev/null 2>&1; then
    return 0
  fi
  # Linux ping uses -W in seconds; some systems use -w. Already tried.
  if [[ -n "$TCP_PORT" ]]; then
    if command -v timeout >/dev/null 2>&1; then
      timeout "$TIMEOUT" bash -c "echo >/dev/tcp/${host}/${TCP_PORT}" 2>/dev/null && return 0
    else
      (echo >/dev/tcp/${host}/${TCP_PORT}) >/dev/null 2>&1 && return 0
    fi
  fi
  return 1
}

probe_one() {
  local host="$1"
  host="${host//$'\r'/}"
  host="${host#"${host%%[![:space:]]*}"}"
  host="${host%"${host##*[![:space:]]}"}"
  [[ -z "$host" || "$host" =~ ^# ]] && return 0

  if is_up "$host"; then
    echo "$host" >> "$OUT_DIR/up.tmp"
    [[ "$SILENT" -eq 0 ]] && echo -e "${GREEN}[+]${NC} up   $host"
  else
    echo "$host" >> "$OUT_DIR/down.tmp"
    [[ "$SILENT" -eq 0 ]] && echo -e "${RED}[-]${NC} down $host"
  fi
}

export -f is_up probe_one
export COUNT TIMEOUT TCP_PORT OUT_DIR SILENT RED GREEN NC

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f) TAR="${2:-}"; shift 2 ;;
    -o) OUT_DIR="${2:-}"; shift 2 ;;
    -c) CONCURRENCY="${2:-50}"; shift 2 ;;
    -W) TIMEOUT="${2:-2}"; shift 2 ;;
    --tcp) TCP_PORT="${2:-}"; shift 2 ;;
    -q|--silent) SILENT=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$TAR" || ! -f "$TAR" ]]; then
  echo -e "${RED}No valid -f hosts file supplied${NC}"
  usage
fi

banner
mkdir -p "$OUT_DIR"
: > "$OUT_DIR/up.tmp"
: > "$OUT_DIR/down.tmp"

info "Scanning $(grep -cve '^\s*$\|^\s*#' "$TAR" || true) hosts (concurrency=$CONCURRENCY)"

# Prefer xargs -P for portability
if command -v xargs >/dev/null 2>&1; then
  grep -vE '^\s*(#|$)' "$TAR" | tr -d '\r' | xargs -P "$CONCURRENCY" -I{} bash -c 'probe_one "$@"' _ {}
else
  running=0
  while IFS= read -r host || [[ -n "$host" ]]; do
    probe_one "$host" &
    running=$((running + 1))
    if [[ "$running" -ge "$CONCURRENCY" ]]; then
      wait -n 2>/dev/null || wait
      running=$((running - 1))
    fi
  done < "$TAR"
  wait
fi

sort -u "$OUT_DIR/up.tmp" > "$OUT_DIR/up.txt"
sort -u "$OUT_DIR/down.tmp" > "$OUT_DIR/down.txt"
rm -f "$OUT_DIR/up.tmp" "$OUT_DIR/down.tmp"

up_n=$(wc -l < "$OUT_DIR/up.txt" | tr -d ' ')
down_n=$(wc -l < "$OUT_DIR/down.txt" | tr -d ' ')
{
  echo "Bulk-Ping v${VERSION} $(date -Iseconds 2>/dev/null || date)"
  echo "up=$up_n down=$down_n"
} > "$OUT_DIR/summary.txt"

echo -e "${GREEN}[+]${NC} up: $up_n → $OUT_DIR/up.txt"
echo -e "${YELLOW}[+]${NC} down: $down_n → $OUT_DIR/down.txt"
echo -e "${GREEN}All done.${NC}"
