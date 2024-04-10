#!/bin/bash

# Download and update domains
./chaospy.py --download-all

if ls *.zip &> /dev/null; then
    unzip '*.zip' &> /dev/null
    cat *.txt >> alltargets.txtls
    rm *.txt

    # Send new domains result to notify
    echo "Hourly scan result $(date +%F-%T)" | notify -silent -provider telegram,slack
    echo "Total $(wc -l < alltargets.txtls) new domains found" | notify -silent -provider telegram,slack

    # Update nuclei and nuclei-templates
    nuclei -silent -update
    nuclei -silent -ut
    rm *.zip
else
    echo "No new programs found" | notify -silent -provider telegram,slack
fi

# Scan live host/domain for vulnerability using nuclei and send result to notify
echo "Starting nuclei" | notify -silent -provider telegram,slack
cat alltargets.txtls | nuclei -silent -severity critical,medium,high -eid cve-2017-5487,cve-2020-14179 -ept ssl -et wordpress-login
echo "nuclei completed" | notify -silent -provider telegram,slack
