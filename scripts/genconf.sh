#!/usr/bin/env bash

############## errors
readonly ERR_NO_SERVERS=100
readonly ERR_NO_PORT=101
readonly ERR_SSL_NO_KEY=110
readonly ERR_SSL_NO_CERT=111
readonly ERR_SSL_NO_CLIENT_CERT=112
readonly ERR_AUTH_INVALID_SCHEME=120
readonly ERR_AUTH_NO_BASIC_PASSWD=121
readonly ERR_AUTH_NO_DIGEST_PASSWD=123
readonly ERR_AUTH_NO_BEARER_JWKS=123
readonly ERR_CHAIN_NO_PROXY_CACERT=130
##############

############## templates declaration

IFS_BAK=${IFS}
export IFS=''

read -r -d '' BASE_CONF << "EOF"
daemon off;

worker_processes  {{WORKER_PROCESSES}};

error_log /var/log/nginx/error.log {{LOG_LEVEL}};
pid /var/run/nginx/nginx.pid;

events {
    worker_connections  {{WORKER_CONNECTIONS}};
}

http {

    include       /opt/openresty/conf/mime.types;
    default_type  application/octet-stream;
    access_log /var/log/nginx/access.log;

    client_body_temp_path /tmp/client_body_temp;
    proxy_temp_path /tmp/proxy_temp;
    fastcgi_temp_path /tmp/fastcgi_temp;
    uwsgi_temp_path /tmp/uwsgi_temp;
    scgi_temp_path /tmp/scgi_temp;

    lua_package_path "/etc/nginx/lua/?.lua;/opt/openresty/lua/?.lua;;";
{{TARGET_WHITELIST_INIT_BLOCK}}

    # version 
    server {
        listen 8080;
        location /version {
            default_type text/plain;
            content_by_lua_block { ngx.say("{{VERSION}}") }
        }
    }
{{SERVER_DEFINITIONS}}

}
EOF

read -r -d '' SERVER_DEFINITION <<"EOF"
    # {{NAME}}
    server {
        listen                         {{PORT}} {{SSL}};
  
{{SSL_BLOCK}}
{{AUTH_BLOCK}}

        # dns resolver used by forward proxying
        resolver                       {{RESOLVER}} ipv6=off;
    
        # forward proxy for CONNECT requests
        proxy_connect;
        proxy_connect_allow            {{ALLOWED_TARGET_PORTS}};
        proxy_connect_connect_timeout  10s;
        proxy_connect_data_timeout     120s; # 2x SSE keep-alive

{{PROXY_CHAIN_BLOCK}}
{{HOST_WHITELIST_BLOCK}}
    }
EOF

read -r -d '' SSL_BLOCK <<"EOF"
        # TLS setup
        ssl_certificate                {{SERVER_CERTIFICATE}};
        ssl_certificate_key            {{SERVER_PRIVATE_KEY}};
        ssl_session_cache              shared:SSL:1m;
{{CLIENT_VALIDATION_BLOCK}}\n
EOF

read -r -d '' CLIENT_VALIDATION_BLOCK <<"EOF"
        ssl_client_certificate         {{CLIENT_VALIDATION_CERTIFICATE}};
        ssl_verify_client              on;
EOF

read -r -d '' BASIC_AUTH_BLOCK <<"EOF"
        # Authentication setup
        auth_basic                      "harness";
        auth_basic_user_file            {{BASIC_AUTH_PASSWD}};
        rewrite_by_lua_file             /opt/openresty/lua/proxy_auth_basic.lua;
EOF

read -r -d '' DIGEST_AUTH_BLOCK <<"EOF"
        # Authentication setup
        auth_digest                     "harness";
        auth_digest_user_file           {{DIGEST_AUTH_PASSWD}};
        rewrite_by_lua_file             /opt/openresty/lua/proxy_auth_digest.lua;
        header_filter_by_lua_file       /opt/openresty/lua/proxy_auth_digest_status.lua;\n
EOF

read -r -d '' BEARER_AUTH_BLOCK <<"EOF"
        # Authentication setup
        auth_jwt                        "all";
        auth_jwt_key_file               {{BEARER_AUTH_JWKS}};
        rewrite_by_lua_file             /opt/openresty/lua/proxy_auth_bearer.lua;

EOF

read -r -d '' TARGET_WHITELIST_INIT_BLOCK << "EOF"
    init_by_lua_block {
        require "host_access_control"
{{REQUIRE_LIST}}
    }
EOF

read -r -d '' TARGET_WHITELIST_BLOCK << "EOF"
        access_by_lua_block {
            local allowed_hosts = require "host_whitelist_{{NAME}}".whitelist;
            require "host_access_control".fail_if_host_not_allowed(allowed_hosts)
        }
EOF

read -r -d '' PROXY_CHAIN_BLOCK <<"EOF"
        proxy_connect_chain_proxy      {{NEXT_PROXY_HOST}};
{{PROXY_CHAIN_SSL_BLOCK}}

EOF

read -r -d '' PROXY_CHAIN_SSL_BLOCK << "EOF"
        proxy_connect_chain_proxy_ssl;
        proxy_connect_chain_proxy_ssl_verify;
        proxy_connect_chain_proxy_ssl_verify_cert {{PROXY_CHAIN_SSL_CERT}};

EOF

IFS=${IFS_BAK}

############## internal functions

function gen_server_section() {
    local id="${1}"

    local port=$(get_var ${id} PORT)
    [ -z "${port}" ] && log_error "Server '${id}' is missing port, which is mandatory. Aborting" && return "${ERR_NO_PORT}"

    local target_ports="80,443"
    local tpr=$(get_var ${id} ALLOWED_TARGET_PORTS)
    if [ ! -z "${tpr}" ]; then
        target_ports=$(tr ',' ' ' <<< "${tpr}")
    fi

    local target_whitelist_block=""
    local target_whitelist_raw=$(get_var "${id}" ALLOWED_TARGETS)
    if [[ ${target_whitelist_block} != "*" ]]; then
        target_whitelist_block=$(${AWK} -v name="${id}" '{ sub("{{NAME}}", name); };1' <<< "${TARGET_WHITELIST_BLOCK}")
    fi

    local ssl
    local ssl_block
    if [[ $(get_var ${id} SSL) == "true" ]]; then
        ssl="ssl"
        ssl_block=$(gen_ssl_block ${id}); ret=${?}
        if [ ${ret} -ne 0 ]; then
            return "${ret}"
        fi
    fi

    local auth_block=$(gen_auth_block ${id}); ret=${?}
    if [ ${ret} -ne 0 ]; then
        return "${ret}"
    fi

    local proxy_chain_block=$(gen_proxy_chain_block "${id}")
    if [ ${ret} -ne 0 ]; then
        return "${ret}"
    fi

    local resolver=$(get_var "${id}" RESOLVER_IP)
    if [ -z "${resolver}" ]; then
        resolver="8.8.8.8"
    fi

    ${AWK} -v id="${id}" -v port="${port}" -v ssl="${ssl}" -v ssl_block="${ssl_block}" -v auth_block="${auth_block}" \
        -v proxy_chain_block="${proxy_chain_block}" -v resolver="${resolver}" -v target_ports="${target_ports}" \
        -v target_whitelist_block="${target_whitelist_block}" \
        '{
            sub("{{NAME}}", id);
            sub("{{PORT}}", port);
            sub("{{ALLOWED_TARGET_PORTS}}", target_ports);
            sub("{{SSL}}", ssl);
            sub("{{SSL_BLOCK}}", ssl_block);
            sub("{{AUTH_BLOCK}}", auth_block);
            sub("{{PROXY_CHAIN_BLOCK}}", proxy_chain_block);
            sub("{{RESOLVER}}", resolver);
            sub("{{HOST_WHITELIST_BLOCK}}", target_whitelist_block);
        };1' <<< "${SERVER_DEFINITION}"
}

function gen_ssl_block() {
    id="${1}"
    [ -z $(get_var ${id} SSL) ] && return 0 # should not happen but just in case
    
    private_key=$(get_var "${id}" SSL_PRIVATE_KEY)
    [ -z "${private_key}" ] && log_error "server '${id}' has ssl enabled but no private key was provided" && return "${ERR_SSL_NO_KEY}"

    certificate=$(get_var "${id}" SSL_CERTIFICATE)
    [ -z "${certificate}" ] && log_error "server '${id}' has ssl enabled but no certificate was provided" && return "${ERR_SSL_NO_CERT}"

    local client_validation_cert="$(get_var ${id} SSL_CLIENT_CERTIFICATE)"
    if [ ! -z ${client_validation_cert} ]; then
        local client_validation_block=$(${AWK} -v client_validation_cert="${client_validation_cert}" \
            '{ sub("{{CLIENT_VALIDATION_CERTIFICATE}}", client_validation_cert); };1' \
            <<< "${CLIENT_VALIDATION_BLOCK}")
    fi

    ${AWK} -v certificate="${certificate}" -v private_key="${private_key}" -v cv_block="${client_validation_block}" \
    '{
        sub("{{SERVER_CERTIFICATE}}", certificate);
        sub("{{SERVER_PRIVATE_KEY}}", private_key);
        sub("{{CLIENT_VALIDATION_BLOCK}}", cv_block);
    };1' <<< "${SSL_BLOCK}"
}

function gen_proxy_chain_block() {
    local id="${1}"

    [[ -z $(get_var "${id}" PROXY_CHAIN) ]] && return 0
    local proxy_url=$(get_var "${id}" PROXY_CHAIN)
    local proxy_chain_ssl_block
    if [ ! -z $(get_var "${id}" PROXY_CHAIN_SSL) ]; then
        proxy_chain_ssl_block=$(gen_proxy_chain_ssl_block "${id}"); ret=${?}
        if [ ${ret} -ne 0 ]; then
            return "${ret}"
        fi
    fi
    
   ${AWK} -v proxy_url="${proxy_url}" -v pcssl="${proxy_chain_ssl_block}" \
   '{
       sub("{{NEXT_PROXY_HOST}}", proxy_url);
       sub("{{PROXY_CHAIN_SSL_BLOCK}}", pcssl);
   };1' <<< "${PROXY_CHAIN_BLOCK}"
}

function gen_proxy_chain_ssl_block() {
    id="${1}"
    [[ -z $(get_var "${id}" PROXY_CHAIN_CA_CERT) ]] && \
        log_error "CA cert for nested proxy verification is mandatory is proxy chain ssl is enabled" && \
        return "${ERR_CHAIN_NO_PROXY_CACERT}"

    ssl_cert=$(get_var "${id}" PROXY_CHAIN_CA_CERT)
    ${AWK} -v certificate="${ssl_cert}" \ 
        '{ sub("{{PROXY_CHAIN_SSL_CERT}}", certificate); };1' \
        <<< "${PROXY_CHAIN_SSL_BLOCK}"
}

function gen_auth_block() {
    id="${1}"
    scheme="$(get_var ${id} AUTH)"
    case "${scheme}" in
        basic)
            fn="$(get_var ${id} AUTH_BASIC_PASSWD)"
            [ -z "${fn}" ] && log_error "PASSWD file is mandatory for basic auth in server '${id}'" && return "${ERR_AUTH_NO_BASIC_PASSWD}"
            ${AWK} -v fn="${fn}" '{sub("{{BASIC_AUTH_PASSWD}}", fn)};1' <<< "${BASIC_AUTH_BLOCK}"
            ;;
        digest)
            fn="$(get_var ${id} AUTH_DIGEST_PASSWD)"
            [ -z "${fn}" ] && log_error "PASSWD file is mandatory for digest auth in server '${id}'" && return "${ERR_AUTH_NO_DIGEST_PASSWD}"
            ${AWK} -v fn="${fn}" '{sub("{{DIGEST_AUTH_PASSWD}}", fn)};1' <<< "${DIGEST_AUTH_BLOCK}"
            ;;
        bearer)
            fn="$(get_var ${id} AUTH_BEARER_JWKS)"
            [ -z "${fn}" ] && log_error "JWKS file is mandatory for bearer auth in server '${id}'" && return "${ERR_AUTH_NO_BEARER_JWKS}"
            ${AWK} -v fn="${fn}" '{sub("{{BEARER_AUTH_JWKS}}", fn)};1' <<< "${BEARER_AUTH_BLOCK}"
            ;;
        "")
            # No auth scheme, empty string is fine
            ;;
        *)
            log_error "invalid auth scheme: '${scheme}' in server '${id}'" && return "${ERR_AUTH_INVALID_SCHEME}"
    esac
}

function gen_target_whitelist_init_block() {
    local statements=""
    while read -r -d ',' sid; do
        local allowed_targets=$(get_var ALLOWED_TARGETS)
        if [ "${allowed_targets}" != "\*" ]; then
            statements="${statements}        require \"host_whitelist_${sid}\"\n"
        fi
    done <<< "${HFP_PROXIES},"

    if [ ! -z "${statements}" ]; then
        ${AWK} -v stmts="${statements}" '{sub("{{REQUIRE_LIST}}", stmts)};1' <<< "${TARGET_WHITELIST_INIT_BLOCK}"
    fi
}

############## main execution flow

HFP_VERSION_FILE="${HFP_VERSION_FILE:-/.version}"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "${SCRIPT_DIR}/commons.sh"

# ensure minimal config is supplied
[ -z "${HFP_PROXIES}" ] && log_error "HFP_PROXIES is mandatory and must be a comma-separated list of proxy server names/identifiers" && exit "${ERR_NO_SERVERS}"

server_definitions=""
while read -r -d ',' sid; do
    server_definitions="${server_definitions}\n$(gen_server_section ${sid})"; ret=${?}
    if [ ${ret} -ne 0 ]; then
        exit ${ret}
    fi
done <<< "${HFP_PROXIES},"

whitelist_init=$(gen_target_whitelist_init_block)
if [ ${ret} -ne 0 ]; then
    exit ${ret}
fi

${AWK} \
    -v version="$(head -n1 ${HFP_VERSION_FILE})" \
    -v processes="${HFP_WORKER_PROCESSES:-4}" \
    -v connections="${HFP_WORKER_CONNECTIONS:-1024}" \
    -v servers="${server_definitions}" \
    -v whinit="${whitelist_init}" \
    -v loglevel="${HFP_LOG_LEVEL:-info}" \
    '{
        sub("{{VERSION}}",version);
        sub("{{WORKER_PROCESSES}}",processes);
        sub("{{WORKER_CONNECTIONS}}",connections);
        sub("{{SERVER_DEFINITIONS}}",servers);
        sub("{{TARGET_WHITELIST_INIT_BLOCK}}", whinit); 
        sub("{{LOG_LEVEL}}", loglevel); 
    };1' \
    <<< "${BASE_CONF}"
