#!/bin/bash

id wazuh || useradd wazuh
chown -R root:wazuh /var/ossec
chown -R wazuh:wazuh /var/ossec/etc /var/ossec/logs /var/ossec/queues

exec /var/ossec/bin/multirun \
    /var/ossec/bin/wazuh-control.sh \
    /var/ossec/bin/wazuh-tail-logs.sh