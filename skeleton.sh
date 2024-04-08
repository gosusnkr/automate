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

echo "Starting scan against roots:"
cp "$scope_path/roots.txt" "$scan_path/roots.txt"

# Step 1: Subdomain Enumeration
subfinder -silent -dL "$scan_path/roots.txt" | anew subs.txt

# Step 2: Continuous Monitoring, Checking, Scanning, and Notification
while true; do
    subfinder -dL "$scan_path/roots.txt" -all | anew subs.txt | httpx | nuclei -s Critical,high -ept ssl -et wordpress-login | notify ; sleep 3600; done

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
