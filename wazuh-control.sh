#!/bin/bash
set -euo pipefail

/var/ossec/bin/wazuh-control start 

/var/ossec/bin/fsnotify watch /var/ossec/var/run/ | 
    while read time number event path; do 
        if [ "$event" != "REMOVE" ]; then 
            continue
        fi 
        /var/ossec/bin/wazuh-control status || /var/ossec/bin/wazuh-control start 
    done
