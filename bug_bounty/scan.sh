#!/bin/bash

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
cat "$scan_path/roots.txt" | subfinder | anew "$scan_path/subs.txt" | wc -l
shuffledns -d "$(cat "$scan_path/roots.txt")" -w "$ppath/lists/dns.txt" -r "$ppath/lists/resolvers.txt" -mode bruteforce | anew "$scan_path/subs.txt" | wc -l

# DNS Resolution - Resolve Discovered Subdomains
puredns resolve "$scan_path/subs.txt" -w "$ppath/lists/resolvers.txt" -w "$scan_path/resolved.txt" | wc -l
dnsx -l "$scan_path/resolved.txt" -json -o "$scan_path/dns.json" | jq -r '.[].a? // [] | .' | anew "$scan_path/ips.txt" | wc -l

# Port Scanning & HTTP Server Discovery
nmap -iL "$scan_path/ips.txt" --top-ports 3000 -oN "$scan_path/nmap.xml"
cat "$scan_path/nmap.xml" | dnsx -l "$scan_path/dns.json" --hosts | httpx -json -o "$scan_path/http.json"

cat "$scan_path/http.json" | jq -r '.url' | sed -e 's/:80$/g' -e 's/:443$/g' | sort -u > "$scan_path/http.txt"

# Crawling
gospider -S "$scan_path/http.txt" --json | grep '{}' | jq -r '.output?' | tee "$scan_path/crawl.txt"



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