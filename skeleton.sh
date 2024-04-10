#!/bin/bash

# Install nuclei
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

# Install subfinder
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

# Install notify
go install -v github.com/projectdiscovery/notify/cmd/notify@latest

# Install anew
go install -v github.com/tomnomnom/anew@latest

id="$1"
ppath="$(pwd)"
scope_path="$ppath/scope/$id"

timestamp="$(date +'%Y%m%d-%H%M%S')"
scan_path="$ppath/scan/${id}-${timestamp}"

# Exit if scope path doesn't exist
if [ ! -d "$scope_path" ]; then
    echo "Path doesn't exist"
    exit 1
fi

mkdir -p "$scan_path" || exit

### PERFORM SCAN ###

## SETUP ##
echo "Starting scan against roots:"
cat "$scope_path/roots.txt"
cp -v "$scope_path/roots.txt" "$scan_path/roots.txt"

## DNS Enumeration - Find Subdomains
#cat "$scan_path/roots.txt" | haktrails subdomains | anew subs.txt | wc -l
cat "$scan_path/roots.txt" | subfinder | anew subs.txt | wc -l
cat "$scan_path/roots.txt" | shuffledns -w "$ppath/lists/dns-wordlist.txt" -r "$ppath/lists/resolvers.txt" | anew subs.txt | wc -l

## DNS Resolution - Resolve Discovered Subdomains
puredns resolve "$scan_path/subs.txt" - "$ppath/lists/resolvers.txt" -w "$scan_path/resolved.txt" | wc -l
dnsx -l "$scan_path/resolved.txt" -json -o "$scan_path/dns.json" | jq -r '.a?[]?' | anew "$scan_path/ips.txt" | wc -l

## Port Scanning & HTTP Server Discovery
nmap -T4 -vv -iL "$scan_path/ips.txt" --top-ports 3000 -n--open -oX "$scan_path/nmap.xml"
tew -x "$scan_path/nmap.xml" -dnsx "$scan_path/dns.json" --vhost -o "$scan_path/hostport.txt" | httpx -sr -srd "$scan_path/responses" -json -o "$scan_path/http.json"
cat "$scan_path/http.json" | jq -r '.url' | sed -e 's/:80$//g' -e 's/:443$//g' | sort -u > "$scan_path/http.txt"

## Crawling
gospider - "$scan_path/http.txt" --json | grep "{" | jq -r '.output?' | tee "$scan_path/crawl.txt"

## Javascript Pulling

cat "$scan_path/crawl.txt" | grep "\.js" | httpx -sr -srd js
sleep 3

############ ADD SCAN LOGIC HERE ############

# Calculate time diff
end_time=$(date +%s)
seconds=$((end_time - timestamp))
time=""

if [[ "$seconds" -gt 59 ]]; then
    minutes=$((seconds / 60))
    time="$minutes minutes"
else
    time="$seconds seconds"
fi

echo "Scan $id took $time"
# echo "Scan $id took $time" | notify
