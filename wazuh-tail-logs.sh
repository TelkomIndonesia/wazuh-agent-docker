#!/bin/bash

until /var/ossec/bin/wazuh-control status; do sleep 1; done
exec tail -f /var/ossec/logs/*