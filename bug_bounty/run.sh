#!/usr/bin/env bash
# ======================================================
#  Automated Scan Script for bug bounty targets
# ======================================================
#  Author: Naveen Jagadeesan(thevillagehacker)
#  Description: Runs reconnaissance against the targets
# ======================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
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

# Function to setup target directory
setup_target() {
    local target_id="$1"
    local scope_path="$ppath/scope/$target_id"
    
    # Create scope and target directories
    mkdir -p "$scope_path"
    
    # Ask for roots content (send prompts to stderr so they don't get captured by command substitution)
    echo "" >&2
    echo -e "${YELLOW}[*]${NC} Enter the target roots (domains/IPs) for $target_id" >&2
    echo -e "${YELLOW}[*]${NC} You can enter multiple roots, one per line." >&2
    echo -e "${YELLOW}[*]${NC} Press Ctrl+D (or Ctrl+Z on Windows) when done:" >&2
    echo "---" >&2
    
    # Read user input and write to roots.txt
    cat > "$scope_path/roots.txt"
    
    echo "---" >&2
    echo "" >&2
    echo -e "${GREEN}[+]${NC} Target directory created at: $scope_path" >&2
    echo -e "${GREEN}[+]${NC} Roots file saved at: $scope_path/roots.txt" >&2
    echo "" >&2
    
    # Only echo the target_id to stdout so it gets captured by command substitution
    echo "$target_id"
}

# Set vars
ppath="$(pwd)"
lists_path="$ppath/lists"

# Usage and disclaimer
if [ "$1" == "-h" ]; then
    echo "Usage: ./scan.sh [id]"
    echo ""
    echo "This script performs a scan for a given target ID."
    echo ""
    echo "Options:"
    echo "  [id]  - Optional. If provided, uses existing scope/[id]/roots.txt"
    echo "  -h    - Show this help message"
    echo ""
    echo "If no ID is provided, the script will prompt you to:"
    echo "  1. Enter a target name (will create scope/[target_name]/ directory)"
    echo "  2. Enter roots (domains/IPs to scan, one per line)"
    echo ""
    echo "Directory structure:"
    echo "├── scan.sh"
    echo "├── scans"
    echo "└── scope"
    echo "    └── [target_name]"
    echo "        └── roots.txt"
    echo ""
    echo "Examples:"
    echo "  ./scan.sh example        # Use existing scope/example/roots.txt"
    echo "  ./scan.sh                # Interactive mode - create new target"
    exit 0
fi

# Prompt for target if not provided as argument
if [ -z "$1" ]; then
    echo -e "${YELLOW}[-]${NC} No target ID provided"
    read -p "Enter target name: " id
    if [ -z "$id" ]; then
        error "Target name cannot be empty"
    fi
    id=$(setup_target "$id")
else
    id="$1"
fi

scope_path="$ppath/scope/$id"

timestamp="$(date +%s)"
scan_path="$ppath/scans/$id-$timestamp"

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
dnsx -l "$scan_path/resolved.txt" -json -o "$scan_path/dns.json"
log "Extracting IP addresses from $scan_path/dns.json"

# DEBUG: Check if dns.json exists and has content
echo "[DEBUG] Checking dns.json file..." >&2
if [ -f "$scan_path/dns.json" ]; then
    file_size=$(wc -c < "$scan_path/dns.json")
    echo "[DEBUG] dns.json exists. File size: $file_size bytes" >&2
    echo "[DEBUG] First 500 chars of dns.json:" >&2
    head -c 500 "$scan_path/dns.json" >&2
    echo "" >&2
else
    error "dns.json not found at $scan_path/dns.json"
fi

# DEBUG: Extract with grep and show count
echo "[DEBUG] Running grep to extract IPs..." >&2
grep_count=$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$scan_path/dns.json" | wc -l)
echo "[DEBUG] Grep found $grep_count IP matches" >&2

# DEBUG: Show first 10 IPs found by grep
echo "[DEBUG] First 10 IPs found by grep:" >&2
grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$scan_path/dns.json" | head -10 >&2

# Extract, sort, validate, and write to ips.txt
echo "[DEBUG] Sorting and validating IPs..." >&2
grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$scan_path/dns.json" | sort -u > "$scan_path/ips.tmp"
tmp_count=$(wc -l < "$scan_path/ips.tmp")
echo "[DEBUG] After sort -u: $tmp_count unique IPs" >&2

# Validate octets
awk -F'.' '($1<=255 && $2<=255 && $3<=255 && $4<=255){print}' "$scan_path/ips.tmp" > "$scan_path/ips.txt"
final_count=$(wc -l < "$scan_path/ips.txt")
echo "[DEBUG] After validation: $final_count valid IPs written to ips.txt" >&2
echo "[DEBUG] First 10 IPs in ips.txt:" >&2
head -10 "$scan_path/ips.txt" >&2

rm -f "$scan_path/ips.tmp"
log "Wrote $final_count IPs to $scan_path/ips.txt"

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