#!/bin/bash
set -euo pipefail

WAZUH_YARA_HOME="${WAZUH_YARA_HOME:-"/usr/local/yara"}"
WAZUH_YARA_RULES_URLS="${WAZUH_YARA_RULES_URLS:-}"

if [ -z "$WAZUH_YARA_RULES_URLS" ]; then
    echo "INFO: No yara rules to download."
    exit 0
fi

mkdir -p /tmp/rules
cd /tmp/rules
for url in $WAZUH_YARA_RULES_URLS; do
    echo "Downloading yara rules from '$url'."
    curl -sfL "$url" -o temp.zip
    unzip -qq temp.zip
    rm temp.zip
done
rm -rf "$WAZUH_YARA_HOME/rules"
mv /tmp/rules "$WAZUH_YARA_HOME/rules"
