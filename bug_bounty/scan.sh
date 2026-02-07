#!/usr/bin/env bash
# ======================================================
#  Automated Scan Script for bug bounty targets
# ======================================================
#  Author: Naveen Jagadeesan(thevillagehacker)
#  Description: Runs reconnaissance against the targets
# ======================================================

# Set vars
id="$1"
ppath="$(pwd)"
scope_path="$ppath/scope/$id"
lists_path="$ppath/lists"

timestamp="$(date +%s)"
scan_path="$ppath/scans/$id-$timestamp"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[+]${NC} $1"
}

error() {
    echo -e "${RED}[-]${NC} $1"
    exit 1
}

# Check if required tool is installed
check_tool() {
    if ! command -v "$1" &> /dev/null; then
        error "$1 is not installed. Please install it first."
    fi
}

# Usage and disclaimer
if [ "$1" == "-h" ]; then
    echo "Usage: ./scan.sh <id>"
    echo "This script performs a scan for a given <id>. Ensure the following structure is in place:"
    echo "├── scan.sh"
    echo "├── scans"
    echo "└── scope"
    echo "    └── <id>"
    echo "        └── roots.txt"
    echo "Example:"
    echo "chmod +x scan.sh"
    echo "mkdir -p scope/example/"
    echo "touch scope/example/roots.txt"
    echo "./scan.sh example"
    exit 0
fi

# Exit if scope_path doesn't exist
if [ ! -d "$scope_path" ]; then
    error "Scope path doesn't exist: $scope_path"
fi

# Check required tools
log "Checking required tools..."
check_tool "haktrails"
check_tool "subfinder"
check_tool "alterx"
check_tool "puredns"
check_tool "dnsx"
check_tool "nmap"
check_tool "httpx"
check_tool "gospider"
check_tool "jq"
check_tool "wget"

# Create necessary directories
log "Creating necessary directories..."
mkdir -p "$lists_path"
mkdir -p "$scan_path"

log "Scan path: $scan_path"

### PERFORM SCAN ###
log "Starting scan against roots:"
cat "$scope_path/roots.txt" > "$scan_path/roots.txt"
sleep 2


# DNS Enumeration - Find Subdomains
log "DNS Enumeration: Running haktrails..."
cat "$scan_path/roots.txt" | haktrails subdomains | anew "$scan_path/subs.txt" | wc -l

log "DNS Enumeration: Running subfinder..."
subfinder -d "$(cat "$scan_path/roots.txt")" -all -silent | anew "$scan_path/subs.txt" | wc -l

# alterx subdomain wordlist generation
log "Generating subdomain permutations with alterx..."
cat "$scan_path/roots.txt" | alterx -silent | anew "$scan_path/subs.txt" | wc -l

# Download resolver lists (only if they don't exist or are older than 7 days)
download_if_needed() {
    local url="$1"
    local output="$2"
    if [ ! -f "$output" ] || [ "$(find "$output" -mtime +7 2>/dev/null)" ]; then
        log "Downloading $(basename "$output")..."
        wget -q --show-progress "$url" -O "$output"
    else
        log "Using cached $(basename "$output")..."
    fi
}

download_if_needed "https://raw.githubusercontent.com/trickest/resolvers/refs/heads/main/resolvers.txt" "$lists_path/resolvers.txt"
download_if_needed "https://raw.githubusercontent.com/trickest/resolvers/refs/heads/main/resolvers-trusted.txt" "$lists_path/resolvers-trusted.txt"
download_if_needed "https://raw.githubusercontent.com/trickest/resolvers/refs/heads/main/resolvers-extended.txt" "$lists_path/resolvers-extended.txt"
download_if_needed "https://raw.githubusercontent.com/danielmiessler/SecLists/refs/heads/master/Discovery/DNS/combined_subdomains.txt" "$lists_path/combined_subdomains.txt"

# Sort and unique resolvers
log "Sorting resolvers..."
cat "$lists_path"/resolvers*.txt | anew > "$lists_path/sorted_resolvers.txt"

# Copy sorted resolvers to puredns config
log "Copying resolvers to puredns config folder..."
mkdir -p "$HOME/.config/puredns"
cp "$lists_path/sorted_resolvers.txt" "$HOME/.config/puredns/resolvers.txt"

# DNS Resolution - Resolve Discovered Subdomains
log "DNS Resolution: Resolving subdomains with puredns..."
puredns resolve "$scan_path/subs.txt" -r "$lists_path/resolvers.txt" --resolvers-trusted "$lists_path/resolvers-trusted.txt" -w "$scan_path/resolved.txt" | wc -l

log "DNS Resolution: Extracting IP addresses with dnsx..."
dnsx -l "$scan_path/resolved.txt" -json -o "$scan_path/dns.json" && jq -r '.. | objects | to_entries[] | select(.value | tostring | test("^\\d+\\.\\d+\\.\\d+\\.\\d+$")) | .value' "$scan_path/dns.json" | anew "$scan_path/ips.txt" | wc -l

# Port Scanning & HTTP Server Discovery
log "Port Scanning: Running nmap on discovered IPs..."
nmap -iL "$scan_path/ips.txt" --top-ports 3000 -oN "$scan_path/nmap.txt" -v

log "HTTP Discovery: Finding live HTTP services..."
cat "$scan_path/nmap.txt" | dnsx -l "$scan_path/dns.json" --hosts | httpx -json -o "$scan_path/http.json"

cat "$scan_path/http.json" | jq -r '.url' | sed -e 's/:80$//' -e 's/:443$//' | sort -u > "$scan_path/http.txt"

log "Found $(wc -l < "$scan_path/http.txt") live HTTP services"

# Crawling
log "Web Crawling: Running gospider..."
gospider -S "$scan_path/http.txt" --json | grep '{}' | jq -r '.output?' | tee "$scan_path/crawl.txt"

# more crawling with katana
#katana -u "$scan_path/resolved.txt" -xhr -jsl -d 6

# Calculate time diff
end_time=$(date +%s)
seconds=$(expr $end_time - $timestamp)

if [ "$seconds" -gt 59 ]; then
    minutes=$(expr $seconds / 60)
    time="$minutes minutes"
else
    time="$seconds seconds"
fi

log "Scan completed for '$id' in $time"
log "Results saved to: $scan_path"
#log "Scan $id took $time" | notify