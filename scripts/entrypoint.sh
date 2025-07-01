#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

OPENRESTY_BASE_PATH="/opt/openresty"
OPENRESTY_SCRIPTS_PATH="${OPENRESTY_BASE_PATH}/scripts"
OPENRESTY_CONFIG_PATH="${OPENRESTY_BASE_PATH}/conf"

# the allowed targets list is used to generate a whitelist lua file as well
# as adding a section to the nginx conf file. Because `genconf` outputs a command
# other files cannot be written within such script.
IFS=","
HFP_ALLOWED_TARGET_HOSTS="${HFP_ALLOWED_TARGET_HOSTS:-sdk.split.io:443,auth.split.io:443,streaming.split.io:443,events.split.io:443,telemetry.split.io:443}"
whitelist=""
for host in ${HFP_ALLOWED_TARGET_HOSTS}; do
    whitelist="${whitelist}\t\t\'${host}',\n"
done


cat /opt/openresty/lua/whitelist.lua.tpl |
    awk -v hosts="${whitelist}" '{sub("{{WHITELIST}}",hosts)};1' \
    > /etc/nginx/lua/host_whitelist.lua

bash "${OPENRESTY_SCRIPTS_PATH}/genconf.sh" > /etc/nginx/nginx.conf
[[ ${HFP_DEBUG_CONF} == "true" ]] && echo "generated nginx config: " && cat /etc/nginx/nginx.conf

export LD_LIBRARY_PATH="/usr/local/lib"
exec /opt/openresty/sbin/nginx -c /etc/nginx/nginx.conf 
