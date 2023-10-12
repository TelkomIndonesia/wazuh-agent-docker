#!/bin/bash
set -euo pipefail

### enable sca ruleset
export WAZUH_RULESET_SCA="${WAZUH_RULESET_SCA:-""}"
rm -rf /var/ossec/ruleset/sca
cp -r /var/ossec/ruleset/sca.disabled /var/ossec/ruleset/sca
if [ -z "$WAZUH_RULESET_SCA" ]; then
    WAZUH_RULESET_SCA="$(find /var/ossec/ruleset/sca/ -type f -exec basename {} \; | sed 's|.yml\(.disabled\)\?||')"
else
    WAZUH_RULESET_SCA="${WAZUH_RULESET_SCA//,/ }"
fi
for filename in $WAZUH_RULESET_SCA; do
    file="/var/ossec/ruleset/sca/$filename.yml"
    if [ -f "${file}.disabled" ]; then
        mv ${file}.disabled ${file}
    fi
done
###

# prepare config and copy to host
WAZUH_AGENT_HOST_DIR=${WAZUH_AGENT_HOST_DIR:-"/host"}
gomplate -f /var/ossec/etc/ossec.tpl.conf -o /var/ossec/etc/ossec.conf
rsync /var/ossec/ "$WAZUH_AGENT_HOST_DIR/var/ossec" \
    -avq --delete \
    --exclude "etc/client.keys"

# rename agent if changed
desiredname="${WAZUH_AGENT_NAME_PREFIX:-""}${WAZUH_AGENT_NAME:-""}${WAZUH_AGENT_NAME_POSTFIX:-""}"
currentname=$(cat "$WAZUH_AGENT_HOST_DIR/var/ossec/etc/client.keys" | awk '{print $2}' || echo)
if [ "$desiredname" != "$currentname" ]; then
    echo -n "" >"$WAZUH_AGENT_HOST_DIR/var/ossec/etc/client.keys"
fi

/yara-rule-downloader.sh

exec multirun \
    "env PATH='/var/ossec/active-response/bin:$PATH' wazuh-container-exec server" \
    "job -s '0 1 * * *' -- /yara-rule-downloader.sh" \
    "chroot $WAZUH_AGENT_HOST_DIR /var/ossec/bin/wazuh-start.sh" \
    "chroot $WAZUH_AGENT_HOST_DIR /var/ossec/bin/wazuh-tail-logs.sh"
