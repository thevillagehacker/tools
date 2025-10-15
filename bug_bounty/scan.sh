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

timestamp="$(date +%s)"
scan_path="$ppath/scans/$id-$timestamp"

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
    echo "Path doesn't exist"
    exit 1
fi

mkdir -p "$scan_path"
echo "$scan_path"

### PERFORM SCAN ###
echo "Starting scan against roots:"
cat "$scope_path/roots.txt" > "$scan_path/roots.txt"
cp -v "$scope_path/roots.txt" "$scan_path/roots.txt"
sleep 3


# DNS Enumeration - Find Subdomains
cat "$scan_path/roots.txt" | haktrails subdomains | anew "$scan_path/subs.txt" | wc -l
subfinder -d "$(cat "$scan_path/roots.txt")" -all -silent | anew "$scan_path/subs.txt" | wc -l

# alterx subdomain wordlist generatiion
echo "[+] Writing permutations to the subs path"
cat "$scan_path/roots.txt" | alterx -silent | anew "$scan_path/subs.txt" | wc -l

# download and place resolvers
echo "[+] Downloading resolvers.txt..."
wget -q --show-progress https://raw.githubusercontent.com/trickest/resolvers/refs/heads/main/resolvers.txt -O "$ppath/lists/resolvers.txt"
echo "[+] Downloading resolvers-trusted.txt..."
wget -q --show-progress https://raw.githubusercontent.com/trickest/resolvers/refs/heads/main/resolvers-trusted.txt -O "$ppath/lists/resolvers-trusted.txt"
echo "[+] Downloading resolvers-extended.txt..."
wget -q --show-progress https://raw.githubusercontent.com/trickest/resolvers/refs/heads/main/resolvers-extended.txt -O "$ppath/lists/resolvers-extended.txt"

# sort and unique resolvers
cat "$ppath"/lists/resolvers*.txt | anew > "$ppath/lists/sorted_resolvers.txt"

# download subdomain wordlist combined
echo "[+] Downloading combined_subdomains..."
wget -q --show-progress https://raw.githubusercontent.com/danielmiessler/SecLists/refs/heads/master/Discovery/DNS/combined_subdomains.txt -O "$ppath/lists/combined_subdomains.txt"

#better run this in a vps
#shuffledns -d "$(cat "$scan_path/roots.txt")" -w "$ppath/lists/combined_subdomains.txt" -r "$ppath/lists/resolvers.txt" -mode bruteforce -silent | anew "$scan_path/subs.txt" | wc -l

# copy sorted resolvers to puredns config
echo "[+] Copying resolvers to puredns config folder..."
cp "$ppath/lists/sorted_resolvers.txt" "$HOME/.config/puredns/resolvers.txt"

# DNS Resolution - Resolve Discovered Subdomains
puredns resolve "$scan_path/subs.txt" -r "$ppath/lists/resolvers.txt" --resolvers-trusted "$ppath/lists/resolvers-trusted.txt" -w "$scan_path/resolved.txt" | wc -l

dnsx -l "$scan_path/resolved.txt" -json -o "$scan_path/dns.json" && jq -r '.. | objects | to_entries[] | select(.value | tostring | test("^\\d+\\.\\d+\\.\\d+\\.\\d+$")) | .value' "$scan_path/dns.json" | anew "$scan_path/ips.txt" | wc -l

# Port Scanning & HTTP Server Discovery
nmap -iL "$scan_path/ips.txt" --top-ports 3000 -oN "$scan_path/nmap.xml" -v
cat "$scan_path/nmap.xml" | dnsx -l "$scan_path/dns.json" --hosts | httpx -json -o "$scan_path/http.json"

cat "$scan_path/http.json" | jq -r '.url' | sed -e 's/:80$/g' -e 's/:443$/g' | sort -u > "$scan_path/http.txt"

# Crawling
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

echo "Scan $id took $time"
#echo "Scan $id took $time" | notify