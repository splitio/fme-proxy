#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

OPENRESTY_BASE_PATH="/opt/openresty"
OPENRESTY_SCRIPTS_PATH="${OPENRESTY_BASE_PATH}/scripts"
OPENRESTY_CONFIG_PATH="${OPENRESTY_BASE_PATH}/conf"


# Create nginx config directory if it doesn't exist
mkdir -p /etc/nginx

# Generate and write nginx configuration
bash "${OPENRESTY_SCRIPTS_PATH}/genconf.sh" > /etc/nginx/nginx.conf
[[ ${HFP_DEBUG_CONF} == "true" ]] && echo "generated nginx config: " && cat /etc/nginx/nginx.conf

export LD_LIBRARY_PATH="/usr/local/lib"
exec /opt/openresty/sbin/nginx -c /etc/nginx/nginx.conf 


