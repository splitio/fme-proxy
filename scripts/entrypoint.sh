#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
OPENRESTY_BASE_PATH="${OPENRESTY_BASE_PATH:-/opt/openresty}"
OPENRESTY_SCRIPTS_PATH="${OPENRESTY_BASE_PATH}/scripts"
OPENRESTY_CONFIG_PATH="${OPENRESTY_BASE_PATH}/conf"

source "${SCRIPT_DIR}/commons.sh"

bash "${OPENRESTY_SCRIPTS_PATH}/genconf.sh" > /etc/nginx/nginx.conf
[ $? -ne 0 ] && log_error "config generation failed. aborting" && exit 1

[[ ${HP_DEBUG_CONF} == "true" ]] && echo "generated nginx config: " && cat /etc/nginx/nginx.conf

bash "${OPENRESTY_SCRIPTS_PATH}/genallowlists.sh"
[ $? -ne 0 ] && log_error "host whitelist generation failed. aborting" && exit 1

export LD_LIBRARY_PATH="/usr/local/lib"
exec /opt/openresty/sbin/nginx -c /etc/nginx/nginx.conf 
