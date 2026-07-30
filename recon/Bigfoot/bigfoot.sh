#!/usr/bin/env bash
# Bigfoot v3 — Subdomain takeover detection
# Checks CNAME (when dig/host available) and HTTP fingerprint matches.
set -euo pipefail

VERSION="3.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FINGERPRINTS_FILE="${SCRIPT_DIR}/fingerprints.txt"

# Defaults
TIMEOUT=8
CONCURRENCY=10
ONLY_VULN=0
JSON_OUT=0
OUTPUT_FILE=""
USE_HTTPS=1
SILENT=0
CHECK_CNAME=1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
  cat <<EOF
Bigfoot v${VERSION} — Subdomain takeover detection

Usage:
  ./bigfoot.sh -d <domain>     Scan a single host
  ./bigfoot.sh -f <file>       Scan hosts from a file (one per line)

Options:
  -d HOST          Single target hostname
  -f FILE          File of hostnames
  -o FILE          Write findings to file
  -t SECONDS       HTTP timeout (default: ${TIMEOUT})
  -c N             Concurrency for bulk scans (default: ${CONCURRENCY})
  --only-vuln      Only print potential takeovers
  --json           JSON lines output (one object per finding)
  --http-only      Skip HTTPS probes
  --no-cname       Skip CNAME resolution
  -q, --silent     Suppress banner
  -h, --help       Show this help

Examples:
  ./bigfoot.sh -d dangling.example.com
  ./bigfoot.sh -f subs.txt --only-vuln -o findings.txt
  ./bigfoot.sh -f subs.txt --json -o findings.jsonl
EOF
  exit 0
}

banner() {
  [[ "$SILENT" -eq 1 || "$JSON_OUT" -eq 1 ]] && return
  echo -e "${GREEN}"
  cat <<'EOF'
 ______  __          ___                __   
|   __ \|__|.-----..'  _|.-----..-----.|  |_ 
|   __ <|  ||  _  ||   _||  _  ||  _  ||   _|
|______/|__||___  ||__|  |_____||_____||____|
            |_____|
EOF
  echo -e "          Bigfoot v${VERSION} — takeover check${NC}"
  echo -e "    https://github.com/thevillagehacker"
  echo ""
}

log()  { [[ "$JSON_OUT" -eq 1 ]] && return; echo -e "$*"; }
info() { [[ "$SILENT" -eq 1 || "$JSON_OUT" -eq 1 ]] && return; echo -e "${CYAN}[*]${NC} $*"; }
ok()   { echo -e "${GREEN}[+]${NC} $*"; }
bad()  { [[ "$ONLY_VULN" -eq 1 || "$JSON_OUT" -eq 1 ]] && return; echo -e "${RED}[-]${NC} $*"; }
warn() { [[ "$JSON_OUT" -eq 1 ]] && return; echo -e "${YELLOW}[!]${NC} $*"; }

# service|fingerprint substring (case-sensitive match against body)
DEFAULT_FINGERPRINTS=$(cat <<'EOF'
Heroku|//www.herokucdn.com/error-pages/no-such-app.html
Heroku|No such app
GitHub Pages|There isn't a GitHub Pages site here
GitHub Pages|For root URLs (like http://example.com/) you must provide an index.html file
AWS/S3|NoSuchBucket
AWS/S3|The specified bucket does not exist
Bitbucket|Repository not found
Pantheon|404 error unknown site!
Shopify|Sorry, this shop is currently unavailable
Tumblr|Whatever you were looking for doesn't currently exist at this address
WordPress.com|Do you want to register
WordPress.com|doesn't exist
Ghost|The thing you were looking for is no longer here
Surge.sh|project not found
Surge.sh|repository not found
Cargo Collective|If you're moving your domain away from Cargo
Webflow|The page you are looking for doesn't exist or has been moved
Webflow|The page you are looking for cannot be found
Helpjuice|We could not find what you're looking for
Help Scout|No settings were found for this company
Teamwork|Oops - We didn't find your site
Thinkific|You may have mistyped the address or the page may have moved
Tilda|Please renew your subscription
Tilda|Domain has been assigned
Unbounce|The requested URL was not found on this server
UserVoice|This UserVoice subdomain is currently available
WordPress.com|Do you want to register
Azure|404 Web Site not found
Azure|The resource you are looking for has been removed
Cloudfront|ERROR: The request could not be satisfied
Cloudfront|Bad request
Fastly|Fastly error: unknown domain
Netlify|Not Found - Request ID
GitLab Pages|The page you're looking for could not be found
Fly.io|404 Not Found
Zendesk|Help Center Closed
Zendesk|this help center no longer exists
Readme.io|Project doesnt exist... yet!
SmartJobBoard|This job board website is either expired or its domain name is invalid
EOF
)

load_fingerprints() {
  FINGERPRINT_LINES=()
  if [[ -f "$FINGERPRINTS_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" || "$line" =~ ^# ]] && continue
      FINGERPRINT_LINES+=("$line")
    done < "$FINGERPRINTS_FILE"
  else
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" ]] && continue
      FINGERPRINT_LINES+=("$line")
    done <<< "$DEFAULT_FINGERPRINTS"
  fi
}

resolve_cname() {
  local host="$1"
  local cname=""
  if command -v dig >/dev/null 2>&1; then
    cname=$(dig +short CNAME "$host" 2>/dev/null | head -1 | sed 's/\.$//')
  elif command -v host >/dev/null 2>&1; then
    cname=$(host -t CNAME "$host" 2>/dev/null | awk '/alias for/{print $NF}' | sed 's/\.$//' | head -1)
  fi
  echo "$cname"
}

fetch_body() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -skL --max-time "$TIMEOUT" -A "Bigfoot/${VERSION}" "$url" 2>/dev/null || true
  elif command -v http >/dev/null 2>&1; then
    http -b --timeout="$TIMEOUT" GET "$url" 2>/dev/null || true
  else
    warn "Neither curl nor httpie found; install curl"
    return 1
  fi
}

emit_finding() {
  local host="$1" service="$2" scheme="$3" cname="$4"
  if [[ "$JSON_OUT" -eq 1 ]]; then
    local line
    line=$(printf '{"host":"%s","service":"%s","scheme":"%s","cname":"%s","verdict":"possible_takeover"}\n' \
      "$host" "$service" "$scheme" "$cname")
    echo "$line"
    [[ -n "$OUTPUT_FILE" ]] && echo "$line" >> "$OUTPUT_FILE"
  else
    ok "POSSIBLE TAKEOVER: ${host} → ${service} (${scheme})${cname:+ [CNAME: $cname]}"
    [[ -n "$OUTPUT_FILE" ]] && echo "[+] $host | $service | $scheme | cname=$cname" >> "$OUTPUT_FILE"
  fi
}

check_host() {
  local host="$1"
  host="${host//$'\r'/}"
  host="${host#"${host%%[![:space:]]*}"}"
  host="${host%"${host##*[![:space:]]}"}"
  [[ -z "$host" || "$host" =~ ^# ]] && return 0

  # strip scheme if user pasted URL
  host="${host#http://}"
  host="${host#https://}"
  host="${host%%/*}"

  local cname=""
  if [[ "$CHECK_CNAME" -eq 1 ]]; then
    cname=$(resolve_cname "$host")
  fi

  local found=0
  local schemes=("http")
  [[ "$USE_HTTPS" -eq 1 ]] && schemes=("https" "http")

  for scheme in "${schemes[@]}"; do
    local body
    body=$(fetch_body "${scheme}://${host}")
    [[ -z "$body" ]] && continue

    for entry in "${FINGERPRINT_LINES[@]}"; do
      local service="${entry%%|*}"
      local fp="${entry#*|}"
      if [[ "$body" == *"$fp"* ]]; then
        emit_finding "$host" "$service" "$scheme" "$cname"
        found=1
        break 2
      fi
    done
  done

  if [[ "$found" -eq 0 ]]; then
    if [[ "$JSON_OUT" -eq 0 ]]; then
      if [[ -n "$cname" ]]; then
        bad "$host — no fingerprint match (CNAME: $cname)"
      else
        bad "$host — no takeover fingerprint matched"
      fi
    fi
  fi
}

export -f check_host resolve_cname fetch_body emit_finding log ok bad warn info
export TIMEOUT ONLY_VULN JSON_OUT OUTPUT_FILE USE_HTTPS SILENT CHECK_CNAME VERSION
export RED GREEN YELLOW CYAN NC

# --- parse args ---
TARGET_HOST=""
TARGET_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d) TARGET_HOST="${2:-}"; shift 2 ;;
    -f) TARGET_FILE="${2:-}"; shift 2 ;;
    -o) OUTPUT_FILE="${2:-}"; shift 2 ;;
    -t) TIMEOUT="${2:-8}"; shift 2 ;;
    -c) CONCURRENCY="${2:-10}"; shift 2 ;;
    --only-vuln) ONLY_VULN=1; shift ;;
    --json) JSON_OUT=1; shift ;;
    --http-only) USE_HTTPS=0; shift ;;
    --no-cname) CHECK_CNAME=0; shift ;;
    -q|--silent) SILENT=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$TARGET_HOST" && -z "$TARGET_FILE" ]]; then
  echo -e "${RED}No target supplied.${NC}"
  usage
fi

if ! command -v curl >/dev/null 2>&1 && ! command -v http >/dev/null 2>&1; then
  echo -e "${RED}[-] Error: curl (or httpie) is required${NC}" >&2
  echo "    Install: sudo apt-get install curl"
  exit 1
fi

banner
load_fingerprints
info "Loaded ${#FINGERPRINT_LINES[@]} fingerprints"

if [[ -n "$OUTPUT_FILE" ]]; then
  : > "$OUTPUT_FILE"
fi

# Export fingerprint array for subshells is hard; run inline for bulk with xargs carefully.
# Use a simple parallel approach with background jobs.

scan_list() {
  local file="$1"
  local hosts=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    hosts+=("$line")
  done < "$file"

  info "Scanning ${#hosts[@]} host(s) with concurrency ${CONCURRENCY}"

  local running=0
  for h in "${hosts[@]}"; do
    check_host "$h" &
    running=$((running + 1))
    if [[ "$running" -ge "$CONCURRENCY" ]]; then
      wait -n 2>/dev/null || wait
      running=$((running - 1))
    fi
  done
  wait
}

if [[ -n "$TARGET_HOST" ]]; then
  info "Target: $TARGET_HOST"
  check_host "$TARGET_HOST"
elif [[ -n "$TARGET_FILE" ]]; then
  if [[ ! -f "$TARGET_FILE" ]]; then
    echo -e "${RED}[-] File not found: $TARGET_FILE${NC}" >&2
    exit 1
  fi
  scan_list "$TARGET_FILE"
fi

[[ "$JSON_OUT" -eq 0 && "$SILENT" -eq 0 ]] && log "${GREEN}Done.${NC}"
[[ -n "$OUTPUT_FILE" && "$JSON_OUT" -eq 0 && "$SILENT" -eq 0 ]] && info "Findings written to $OUTPUT_FILE"
