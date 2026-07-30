#!/usr/bin/env bash
# FileFetcher v3 — Extract interesting/sensitive endpoints from URL lists or wayback
set -euo pipefail

VERSION="3.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/results"
TIMEOUT=10
PROBE=0
SILENT=0
TAR=""
MODE=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
  cat <<EOF
FileFetcher v${VERSION} — sensitive / interesting URL triage

Usage:
  ./fetcher.sh -d <domain>     Pull wayback URLs for domain, then classify
  ./fetcher.sh -f <url_file>   Classify URLs from an existing file

Options:
  -d DOMAIN        Target domain (uses waybackurls if installed)
  -f FILE          Input URL list
  -o DIR           Output directory (default: ./results)
  --probe          Live-check interesting URLs with httpx or curl (status)
  -q, --silent     Less banner / progress noise
  -h, --help       Show help

Outputs (under -o):
  all_urls.txt, js.txt, php.txt, json.txt, text.txt,
  docs.txt, config_secrets.txt, backups.txt, api_docs.txt, other_sensitive.txt

Examples:
  ./fetcher.sh -d example.com
  ./fetcher.sh -f urls.txt --probe -o out/example
EOF
  exit 0
}

banner() {
  [[ "$SILENT" -eq 1 ]] && return
  echo -e "${GREEN}"
  cat <<'EOF'
███████╗██╗██╗░░░░░███████╗███████╗███████╗████████╗░█████╗░██╗░░██╗███████╗██████╗░
██╔════╝██║██║░░░░░██╔════╝██╔════╝██╔════╝╚══██╔══╝██╔══██╗██║░░██║██╔════╝██╔══██╗
█████╗░░██║██║░░░░░█████╗░░█████╗░░█████╗░░░░░██║░░░██║░░╚═╝███████║█████╗░░██████╔╝
██╔══╝░░██║██║░░░░░██╔══╝░░██╔══╝░░██╔══╝░░░░░██║░░░██║░░██╗██╔══██║██╔══╝░░██╔══██╗
██║░░░░░██║███████╗███████╗██║░░░░░███████╗░░░██║░░░╚█████╔╝██║░░██║███████╗██║░░██║
╚═╝░░░░░╚═╝╚══════╝╚══════╝╚═╝░░░░░╚══════╝░░░╚═╝░░░░╚════╝░╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝
EOF
  echo -e "  FileFetcher v${VERSION} — interesting endpoint discovery${NC}"
  echo -e "  https://twitter.com/thevillagehackr"
  echo ""
  echo -e "  Date: $(date)"
  echo ""
}

info() { [[ "$SILENT" -eq 1 ]] && return; echo -e "${CYAN}[*]${NC} $*"; }
ok()   { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[-]${NC} $*" >&2; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "Required command not found: $1"
    return 1
  fi
}

collect_urls() {
  local src="$1"
  local dest="$2"
  if [[ "$MODE" == "domain" ]]; then
    if command -v waybackurls >/dev/null 2>&1; then
      info "Fetching waybackurls for $src ..."
      waybackurls "$src" | sort -u > "$dest"
    elif command -v gau >/dev/null 2>&1; then
      info "waybackurls missing; using gau for $src ..."
      gau --subs "$src" 2>/dev/null | sort -u > "$dest" || gau "$src" 2>/dev/null | sort -u > "$dest"
    else
      err "Install waybackurls (or gau) for -d mode: go install github.com/tomnomnom/waybackurls@latest"
      exit 1
    fi
  else
    if [[ ! -f "$src" ]]; then
      err "Input file not found: $src"
      exit 1
    fi
    # normalize: strip CR, drop blanks/comments
    grep -vE '^\s*(#|$)' "$src" | tr -d '\r' | sort -u > "$dest"
  fi

  local count
  count=$(wc -l < "$dest" | tr -d ' ')
  ok "Collected $count unique URL(s) → $dest"
  if [[ "$count" -eq 0 ]]; then
    warn "No URLs to classify."
    exit 0
  fi
}

# Case-insensitive extension / path classifiers
classify() {
  local urls_file="$1"
  local base="$OUT_DIR"

  # JS / source maps
  grep -iE '\.js([?#]|$)|\.mjs([?#]|$)|\.map([?#]|$)' "$urls_file" | sort -u > "$base/js.txt" || true

  # PHP
  grep -iE '\.php([?#]|$)|\.phtml([?#]|$)|\.php[0-9]?([?#]|$)' "$urls_file" | sort -u > "$base/php.txt" || true

  # JSON / YAML configs often exposed
  grep -iE '\.json([?#]|$)|\.yaml([?#]|$)|\.yml([?#]|$)' "$urls_file" | sort -u > "$base/json.txt" || true

  # Text / logs
  grep -iE '\.txt([?#]|$)|\.log([?#]|$)|\.md([?#]|$)' "$urls_file" | sort -u > "$base/text.txt" || true

  # Documents
  grep -iE '\.(pdf|docx?|xlsx?|csv|pptx?)([?#]|$)' "$urls_file" | sort -u > "$base/docs.txt" || true

  # Config / secrets / VCS
  grep -iE \
    '(\.env([.#?]|$)|\.git(/|$)|wp-config|web\.config|\.htaccess|\.htpasswd|id_rsa|\.pem([?#]|$)|credentials|secret|apikey|api_key|config\.(php|yml|yaml|json|xml|ini)|settings\.(py|php|json)|application\.(yml|yaml|properties)|docker-compose|\.DS_Store|package-lock\.json|composer\.(json|lock))' \
    "$urls_file" | sort -u > "$base/config_secrets.txt" || true

  # Backups / dumps
  grep -iE '\.(bak|old|orig|backup|sql|tar|gz|zip|7z|rar|dump|swp|swo)([?#]|$)|backup|db_dump|database\.sql' \
    "$urls_file" | sort -u > "$base/backups.txt" || true

  # API docs / swagger / graphql
  grep -iE \
    '(swagger|openapi|api-docs|graphql|/graphiql|redoc|actuator|metrics|debug|phpinfo|server-status|server-info|\.well-known)' \
    "$urls_file" | sort -u > "$base/api_docs.txt" || true

  # Combined "interesting" (union of high-value sets)
  cat "$base/config_secrets.txt" "$base/backups.txt" "$base/api_docs.txt" "$base/docs.txt" \
    "$base/js.txt" "$base/json.txt" "$base/php.txt" "$base/text.txt" 2>/dev/null \
    | sort -u > "$base/other_sensitive.txt" || true

  # Summary
  for f in js php json text docs config_secrets backups api_docs other_sensitive; do
    local n
    n=$(wc -l < "$base/${f}.txt" 2>/dev/null | tr -d ' ' || echo 0)
    info "${f}.txt: $n"
  done
}

probe_urls() {
  local list="$OUT_DIR/other_sensitive.txt"
  local out="$OUT_DIR/live_interesting.txt"
  if [[ ! -s "$list" ]]; then
    warn "Nothing to probe."
    return
  fi

  if command -v httpx >/dev/null 2>&1; then
    info "Probing with httpx..."
    httpx -l "$list" -silent -status-code -no-color -timeout "$TIMEOUT" \
      -o "$out" 2>/dev/null || httpx -l "$list" -silent -status-code -timeout "$TIMEOUT" > "$out" || true
    ok "Live probe results → $out"
  elif command -v curl >/dev/null 2>&1; then
    info "Probing with curl (slower)..."
    : > "$out"
    while IFS= read -r url || [[ -n "$url" ]]; do
      [[ -z "$url" ]] && continue
      code=$(curl -skL -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$url" 2>/dev/null || echo "000")
      echo "$code $url" >> "$out"
    done < "$list"
    ok "Live probe results → $out"
  else
    warn "Install httpx or curl for --probe"
  fi
}

# --- args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d) MODE="domain"; TAR="${2:-}"; shift 2 ;;
    -f) MODE="file"; TAR="${2:-}"; shift 2 ;;
    -o) OUT_DIR="${2:-}"; shift 2 ;;
    --probe) PROBE=1; shift ;;
    -q|--silent) SILENT=1; shift ;;
    -h|--help) usage ;;
    *) err "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$MODE" || -z "$TAR" ]]; then
  err "No inputs supplied."
  usage
fi

banner
mkdir -p "$OUT_DIR"

URLS_FILE="$OUT_DIR/all_urls.txt"
collect_urls "$TAR" "$URLS_FILE"
classify "$URLS_FILE"

if [[ "$PROBE" -eq 1 ]]; then
  probe_urls
fi

ok "Completed — results in $OUT_DIR"
