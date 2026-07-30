#!/usr/bin/env bash
# ======================================================
#  Automated recon scan for bug bounty targets (v2)
#  Author: Naveen Jagadeesan (thevillagehacker)
# ======================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

VERSION="2.0"
ppath="$(pwd)"
lists_path="$ppath/lists"
TOOLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Stage flags (default: all on after dns)
STAGE_DNS=1
STAGE_PORTS=1
STAGE_HTTP=1
STAGE_CRAWL=1
STAGE_TAKEOVER=1
STAGE_FILES=1
PASSIVE_ONLY=0
DEBUG=0
SKIP_NMAP=0

log()   { echo -e "${GREEN}[+]${NC} $1"; }
info()  { echo -e "${CYAN}[*]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[-]${NC} $1"; exit 1; }
debug() { [[ "$DEBUG" -eq 1 ]] && echo -e "${YELLOW}[DEBUG]${NC} $1" >&2 || true; }

check_tool() {
  if ! command -v "$1" &>/dev/null; then
    error "$1 is not installed. Run bug_bounty/setup.sh or install it manually."
  fi
}

check_tool_optional() {
  if ! command -v "$1" &>/dev/null; then
    warn "optional tool missing: $1 (skipping related step)"
    return 1
  fi
  return 0
}

usage() {
  cat <<EOF
Usage: ./run.sh [id] [options]

  [id]             Optional target id (uses scope/[id]/roots.txt).
                   If omitted, interactive setup creates scope/[name]/roots.txt

Options:
  -h, --help       This help
  --passive         Skip nmap (HTTP probe from resolved hosts only)
  --dns-only        Only subdomain enum + resolve
  --no-crawl        Skip crawling
  --no-takeover     Skip Bigfoot takeover checks
  --no-files        Skip FileFetcher classification
  --debug           Verbose debug logs
  --skip-nmap       Alias for --passive

Directory layout:
  run.sh
  lists/
  scans/<id>-<timestamp>/
  scope/<id>/roots.txt

Examples:
  ./run.sh example
  ./run.sh example --passive --no-crawl
  ./run.sh
EOF
  exit 0
}

setup_target() {
  local target_id="$1"
  local scope_path="$ppath/scope/$target_id"
  mkdir -p "$scope_path"
  echo "" >&2
  echo -e "${YELLOW}[*]${NC} Enter roots (domains) for $target_id — one per line, Ctrl+D when done:" >&2
  echo "---" >&2
  cat > "$scope_path/roots.txt"
  echo "---" >&2
  echo -e "${GREEN}[+]${NC} Saved $scope_path/roots.txt" >&2
  echo "$target_id"
}

# --- parse args ---
ID_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    --passive|--skip-nmap) PASSIVE_ONLY=1; SKIP_NMAP=1; shift ;;
    --dns-only)
      STAGE_PORTS=0; STAGE_HTTP=0; STAGE_CRAWL=0; STAGE_TAKEOVER=0; STAGE_FILES=0
      shift
      ;;
    --no-crawl) STAGE_CRAWL=0; shift ;;
    --no-takeover) STAGE_TAKEOVER=0; shift ;;
    --no-files) STAGE_FILES=0; shift ;;
    --debug) DEBUG=1; shift ;;
    -*)
      error "Unknown option: $1"
      ;;
    *)
      if [[ -z "$ID_ARG" ]]; then
        ID_ARG="$1"
        shift
      else
        error "Unexpected argument: $1"
      fi
      ;;
  esac
done

if [[ -z "$ID_ARG" ]]; then
  echo -e "${YELLOW}[-]${NC} No target ID provided"
  read -r -p "Enter target name: " id
  [[ -z "$id" ]] && error "Target name cannot be empty"
  id=$(setup_target "$id")
else
  id="$ID_ARG"
fi

scope_path="$ppath/scope/$id"
[[ -f "$scope_path/roots.txt" ]] || error "Missing $scope_path/roots.txt"

timestamp="$(date +%s)"
scan_path="$ppath/scans/$id-$timestamp"
mkdir -p "$lists_path" "$scan_path"

log "Bug bounty recon v${VERSION}"
log "Scan path: $scan_path"
cp "$scope_path/roots.txt" "$scan_path/roots.txt"
log "Roots:"
cat "$scan_path/roots.txt"

# Required tools for core path
log "Checking required tools..."
for t in subfinder dnsx httpx anew jq; do
  check_tool "$t"
done

# ---------- DNS / subdomains ----------
if [[ "$STAGE_DNS" -eq 1 ]]; then
  : > "$scan_path/subs.txt"

  if check_tool_optional haktrails; then
    log "DNS: haktrails"
    # haktrails reads domains from stdin
    while IFS= read -r root || [[ -n "$root" ]]; do
      root="${root//$'\r'/}"
      [[ -z "$root" || "$root" =~ ^# ]] && continue
      echo "$root" | haktrails subdomains 2>/dev/null | anew "$scan_path/subs.txt" >/dev/null || true
    done < "$scan_path/roots.txt"
  fi

  log "DNS: subfinder"
  subfinder -dL "$scan_path/roots.txt" -all -silent 2>/dev/null | anew "$scan_path/subs.txt" >/dev/null || \
    subfinder -dL "$scan_path/roots.txt" -silent 2>/dev/null | anew "$scan_path/subs.txt" >/dev/null || true

  if check_tool_optional alterx; then
    log "DNS: alterx permutations"
    cat "$scan_path/roots.txt" | alterx -silent 2>/dev/null | anew "$scan_path/subs.txt" >/dev/null || true
  fi

  # Always include roots themselves
  cat "$scan_path/roots.txt" | anew "$scan_path/subs.txt" >/dev/null
  log "Subdomains collected: $(wc -l < "$scan_path/subs.txt" | tr -d ' ')"

  download_if_needed() {
    local url="$1" output="$2"
    if [[ ! -f "$output" ]] || [[ -n "$(find "$output" -mtime +7 2>/dev/null || true)" ]]; then
      log "Downloading $(basename "$output")..."
      if command -v wget >/dev/null 2>&1; then
        wget -q --show-progress "$url" -O "$output" || curl -fsSL "$url" -o "$output"
      else
        curl -fsSL "$url" -o "$output"
      fi
    else
      info "Using cached $(basename "$output")"
    fi
  }

  if check_tool_optional puredns; then
    download_if_needed "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt" "$lists_path/resolvers.txt"
    download_if_needed "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers-trusted.txt" "$lists_path/resolvers-trusted.txt"
    mkdir -p "$HOME/.config/puredns"
    if [[ -f "$lists_path/resolvers.txt" ]]; then
      cp "$lists_path/resolvers.txt" "$HOME/.config/puredns/resolvers.txt" 2>/dev/null || true
      log "DNS: puredns resolve"
      if [[ -f "$lists_path/resolvers-trusted.txt" ]]; then
        puredns resolve "$scan_path/subs.txt" \
          -r "$lists_path/resolvers.txt" \
          --resolvers-trusted "$lists_path/resolvers-trusted.txt" \
          -w "$scan_path/resolved.txt" 2>/dev/null \
          || puredns resolve "$scan_path/subs.txt" -w "$scan_path/resolved.txt" 2>/dev/null \
          || cp "$scan_path/subs.txt" "$scan_path/resolved.txt"
      else
        puredns resolve "$scan_path/subs.txt" \
          -r "$lists_path/resolvers.txt" \
          -w "$scan_path/resolved.txt" 2>/dev/null \
          || cp "$scan_path/subs.txt" "$scan_path/resolved.txt"
      fi
    else
      warn "No resolvers file; copying subs → resolved"
      cp "$scan_path/subs.txt" "$scan_path/resolved.txt"
    fi
  else
    # fallback: dnsx resolve
    log "DNS: dnsx resolve (puredns missing)"
    dnsx -l "$scan_path/subs.txt" -silent -o "$scan_path/resolved.txt" || cp "$scan_path/subs.txt" "$scan_path/resolved.txt"
  fi

  log "Resolved hosts: $(wc -l < "$scan_path/resolved.txt" | tr -d ' ')"

  log "DNS: dnsx JSON + IPs"
  dnsx -l "$scan_path/resolved.txt" -a -aaaa -silent -json -o "$scan_path/dns.json" 2>/dev/null || \
    dnsx -l "$scan_path/resolved.txt" -json -o "$scan_path/dns.json" 2>/dev/null || : > "$scan_path/dns.json"

  if [[ -s "$scan_path/dns.json" ]]; then
    # Prefer jq for A records; fallback to regex
    if jq -r 'if type=="object" then .a[]? // empty elif type=="array" then .[].a[]? // empty else empty end' \
         "$scan_path/dns.json" 2>/dev/null | grep -E '^[0-9.]+$' | sort -u > "$scan_path/ips.txt"; then
      :
    else
      grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$scan_path/dns.json" \
        | awk -F. '($1<=255&&$2<=255&&$3<=255&&$4<=255){print}' \
        | sort -u > "$scan_path/ips.txt"
    fi
  else
    : > "$scan_path/ips.txt"
  fi
  log "IPs: $(wc -l < "$scan_path/ips.txt" | tr -d ' ')"
fi

# ---------- Ports ----------
if [[ "$STAGE_PORTS" -eq 1 && "$SKIP_NMAP" -eq 0 ]]; then
  if [[ -s "$scan_path/ips.txt" ]] && check_tool_optional nmap; then
    log "Ports: nmap top ports"
    nmap -iL "$scan_path/ips.txt" --top-ports 1000 -T4 -oN "$scan_path/nmap.txt" -oG "$scan_path/nmap.gnmap" 2>/dev/null || \
      warn "nmap failed or returned non-zero"
  else
    info "Skipping nmap (no IPs or nmap missing / --passive)"
  fi
else
  info "Port scan skipped"
fi

# ---------- HTTP ----------
if [[ "$STAGE_HTTP" -eq 1 ]]; then
  log "HTTP: httpx on resolved hosts"
  httpx -l "$scan_path/resolved.txt" -silent -status-code -title -tech-detect -json -o "$scan_path/http.json" 2>/dev/null \
    || httpx -l "$scan_path/resolved.txt" -silent -json -o "$scan_path/http.json" 2>/dev/null \
    || : > "$scan_path/http.json"

  if [[ -s "$scan_path/http.json" ]]; then
    jq -r 'if type=="object" then .url // empty else empty end' "$scan_path/http.json" 2>/dev/null \
      | sed -e 's/:80$//' -e 's/:443$//' \
      | sort -u > "$scan_path/http.txt" \
      || grep -oE 'https?://[^"]+' "$scan_path/http.json" | sort -u > "$scan_path/http.txt"
  else
    : > "$scan_path/http.txt"
  fi
  log "Live HTTP services: $(wc -l < "$scan_path/http.txt" | tr -d ' ')"
fi

# ---------- Crawl ----------
if [[ "$STAGE_CRAWL" -eq 1 && -s "$scan_path/http.txt" ]]; then
  : > "$scan_path/crawl.txt"
  if check_tool_optional katana; then
    log "Crawl: katana"
    katana -list "$scan_path/http.txt" -silent -d 3 -o "$scan_path/crawl.txt" 2>/dev/null || true
  fi
  if check_tool_optional gospider; then
    log "Crawl: gospider"
    gospider -S "$scan_path/http.txt" -c 5 -d 2 --json 2>/dev/null \
      | jq -r 'select(.output != null) | .output' 2>/dev/null \
      | anew "$scan_path/crawl.txt" >/dev/null || true
  fi
  log "Crawl URLs: $(wc -l < "$scan_path/crawl.txt" | tr -d ' ')"
else
  info "Crawl skipped"
fi

# ---------- Takeover (Bigfoot) ----------
if [[ "$STAGE_TAKEOVER" -eq 1 && -s "$scan_path/resolved.txt" ]]; then
  BF="$TOOLS_ROOT/recon/Bigfoot/bigfoot.sh"
  if [[ -x "$BF" ]] || [[ -f "$BF" ]]; then
    log "Takeover: Bigfoot"
    bash "$BF" -f "$scan_path/resolved.txt" --only-vuln -q -o "$scan_path/takeover.txt" || true
    [[ -s "$scan_path/takeover.txt" ]] && warn "Possible takeovers written to takeover.txt" || info "No takeover fingerprints matched"
  else
    warn "Bigfoot not found at $BF"
  fi
fi

# ---------- FileFetcher ----------
if [[ "$STAGE_FILES" -eq 1 ]]; then
  FF="$TOOLS_ROOT/recon/FileFetcher/fetcher.sh"
  url_src=""
  if [[ -s "$scan_path/crawl.txt" ]]; then
    url_src="$scan_path/crawl.txt"
  fi
  # Merge wayback if available
  if check_tool_optional waybackurls; then
    log "Passive URLs: waybackurls"
    : > "$scan_path/wayback.txt"
    while IFS= read -r root || [[ -n "$root" ]]; do
      root="${root//$'\r'/}"
      [[ -z "$root" || "$root" =~ ^# ]] && continue
      waybackurls "$root" 2>/dev/null | anew "$scan_path/wayback.txt" >/dev/null || true
    done < "$scan_path/roots.txt"
  fi

  if [[ -f "$FF" ]]; then
    mkdir -p "$scan_path/filefetcher"
    if [[ -s "$scan_path/wayback.txt" ]]; then
      log "FileFetcher on wayback URLs"
      bash "$FF" -f "$scan_path/wayback.txt" -o "$scan_path/filefetcher" -q || true
    elif [[ -n "$url_src" ]]; then
      log "FileFetcher on crawl URLs"
      bash "$FF" -f "$url_src" -o "$scan_path/filefetcher" -q || true
    else
      # domain mode on first root
      root=$(grep -vE '^\s*(#|$)' "$scan_path/roots.txt" | head -1 | tr -d '\r')
      if [[ -n "$root" ]]; then
        log "FileFetcher -d $root"
        bash "$FF" -d "$root" -o "$scan_path/filefetcher" -q || true
      fi
    fi
  fi
fi

end_time=$(date +%s)
seconds=$((end_time - timestamp))
if [[ "$seconds" -gt 59 ]]; then
  time="$((seconds / 60)) minutes"
else
  time="$seconds seconds"
fi

log "Scan completed for '$id' in $time"
log "Results: $scan_path"
ls -la "$scan_path" 2>/dev/null || true
