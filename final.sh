#!/bin/bash

# Function to handle error and notify
handle_error() {
    local message=$1
    echo "$message" | notify -silent -provider slack
    exit 1
}

# Download and update domains
./chaospy.py --download-new || handle_error "Error downloading new domains"
./chaospy.py --download-updated || handle_error "Error downloading updated domains"

if ls | grep -q ".zip"; then
    unzip '*.zip' &> /dev/null || handle_error "Error unzipping files"
    cat *.txt >> newdomains.md
    rm *.txt
    awk 'NR==FNR{lines[$0];next} !($0 in lines)' alltargets.txtls newdomains.md >> domains.txtls

    # Notify about new domains
    echo "Hourly scan result $(date +%F-%T)"  | notify -silent -provider slack
    echo "Total $(wc -l < domains.txtls) new domains found" | notify -silent -provider slack

    # Update nuclei and nuclei-templates
    nuclei -silent -up
    nuclei -silent -ut
    rm *.zip
else
    echo "No new programs found" | notify -silent -provider slack
fi

# Find live host/domain using httpx
if [ -s domains.txtls ]; then
    # Combine existing and new domains
    cat domains.txtls >> alltargets.txtls
    rm domains.txtls

    # Perform nuclei scan
    echo "Starting nuclei scan" | notify -silent -provider slack
    nuclei -silent -severity critical,medium,high -eid cve-2017-5487,cve-2020-14179 -ept ssl -et wordpress-login -l alltargets.txtls || handle_error "Error running nuclei"
    echo "Nuclei scan completed" | notify -silent -provider slack
    rm newurls.txtls
else
    echo "No new domains found" | notify -silent -provider slack
fi
