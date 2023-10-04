#!/bin/bash
set -euo pipefail

id wazuh || useradd wazuh
chown -R root:wazuh /var/ossec
chown -R wazuh:wazuh /var/ossec/etc /var/ossec/logs 
chown -R wazuh:wazuh /var/ossec/queues/ || true

/var/ossec/bin/wazuh-control start 

/var/ossec/bin/fsnotify watch /var/ossec/var/run/ | 
    while read time number event path; do 
        if [ "$event" != "REMOVE" ]; then 
            continue
        fi 
        /var/ossec/bin/wazuh-control status || /var/ossec/bin/wazuh-control start 
    done
