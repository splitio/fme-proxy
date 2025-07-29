#!/usr/bin/env bash

DEFAULT_ALLOWED_TARGETS="sdk.split.io:443,auth.split.io:443,streaming.split.io:443,events.split.io:443,telemetry.split.io:443,app.harness.io:80,app.harness.io:443,logging.googleapis.com:443"
LUA_OUTPUT_PATH="${LUA_OUTPUT_PATH:-/etc/nginx/lua}"


############## templates declaration

IFS='' read -r -d '' WHITELIST_TEMPLATE << "EOF"
return { 
    whitelist = {
{{WHITELIST}}
    }
}
EOF

############## internal functions

# return codes
readonly RET_WHITELIST_GENERATED=0 # default
readonly RET_ALLOW_ALL=100 

function generate_host_whitelist() {
    local id="${1}"

    local allowed_raw=$(get_var "${id}" ALLOWED_TARGETS)
    [ "${allowed_raw}" == "\*" ] && return "${RET_ALLOW_ALL}"

    if [ -z "${allowed_raw}" ]; then
        allowed_raw="${DEFAULT_ALLOWED_TARGETS}"
    fi
    
    local allowed_ports=("80" "443")
    local allowed_ports_raw=$(get_var "${id}" ALLOWED_TARGET_PORTS)
    if [ ! -z "${allowed_ports_raw}" ]; then
        IFS=',' read -r -a allowed_ports <<< "${allowed_ports_raw}"
    fi

    local whitelist=""
    local target
    while read -r -d ',' target; do
        local host
        local port
        IFS=":" read -r host port <<< "${target}"
        [ -z ${port} ] && port="80"
        if ! item_is_in_array "${port}" "${allowed_ports[@]}"; then
            log_error "target ${target} requires port ${port} to be whitelisted but it's not. invalid config."
            return 1
        fi
        whitelist="${whitelist}\t\t\'${host}:${port}',\n"
    done <<< "${allowed_raw},"

    ${AWK} -v hosts="${whitelist}" '{sub("{{WHITELIST}}",hosts)};1' <<< "${WHITELIST_TEMPLATE}"
}

############## main execution flow

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "${SCRIPT_DIR}/commons.sh"

[ -z "${HFP_PROXIES}" ] \
    && log_error "HFP_PROXIES is mandatory and must be a comma-separated list of proxy server names/identifiers" \
    && exit 1

while read -r -d ',' server; do
    out=$(generate_host_whitelist "${server}")
    ret=$?
    if [ ${ret} -eq "${RET_WHITELIST_GENERATED}" ]; then
        echo "${out}" > "${LUA_OUTPUT_PATH}/host_whitelist_${server}.lua"
    elif [ ${ret} -ne "${RET_ALLOW_ALL}" ]; then
        exit 1
    fi
done <<< "${HFP_PROXIES},"
