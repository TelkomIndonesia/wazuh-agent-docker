#!/bin/bash
set -euo pipefail


### enable sca ruleset
export WAZUH_RULESET_SCA="${WAZUH_RULESET_SCA:-""}"
rm -rf /var/ossec/ruleset/sca
cp -r /var/ossec/ruleset/sca.bak /var/ossec/ruleset/sca
if [ -z "$WAZUH_RULESET_SCA" ]; then 
    WAZUH_RULESET_SCA="$(find /var/ossec/ruleset/sca/ -type f -exec basename {} \; | sed  's|.yml\(.disabled\)\?||')"
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

if [ -f "/var/run/wazuh/authd.pass" ]; then 
    cp /var/run/wazuh/authd.pass /var/ossec/etc/authd.pass
fi
gomplate -f /var/ossec/etc/ossec.tpl.conf -o /var/ossec/etc/ossec.conf
rsync -av --delete --exclude etc/client.keys /var/ossec/ /host/var/ossec
exec chroot /host /var/ossec/bin/entrypoint-chroot.sh