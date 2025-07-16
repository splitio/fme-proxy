#!/usr/bin/env bash

[[ ${DEBUG} == "true" ]] && set -x

############## templates declaration

IFS_BAK=${IFS}
export IFS=''

read -r -d '' BASE_CONF << "EOF"
user  {{USER}};
daemon off;

worker_processes  {{WORKER_PROCESSES}};

error_log /var/log/nginx/error.log;
pid /var/run/nginx.pid;

events {
    worker_connections  {{WORKER_CONNECTIONS}};
}

http {
    include       /opt/openresty/conf/mime.types;
    default_type  application/octet-stream;
    access_log /var/log/nginx/access.log;

    # WebSocket support
    map $http_upgrade $connection_upgrade {
        default upgrade;
        ''      close;
    }

    # version 
    server {
        listen 80;
        location /version {
            default_type text/plain;
            content_by_lua_block { ngx.say("0.0.1-alpha1") }
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
        resolver                       8.8.8.8 ipv6=off;
    
        # forward proxy for CONNECT requests
        proxy_connect;
        proxy_connect_allow            443 563;
        proxy_connect_connect_timeout  10s;
        proxy_connect_data_timeout     120s; # 2x SSE keep-alive

        # WebSocket proxy configuration
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
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

IFS=${IFS_BAK}

############## internal functions

function gen_server_section() {
    local id="${1}"

    local port=$(get_var ${id} PORT)
    [ -z "${port}" ] && log_error "Server '${id}' is missing port, which is mandatory. Aborting" && abort

    if [[ $(get_var ${id} SSL) == "true" ]]; then
        local ssl="ssl"
        ssl_block=$(gen_ssl_block ${id})
    fi

    auth_block=$(gen_auth_block ${id})

    echo -n "${SERVER_DEFINITION}" |
        ${AWK} -v id="${id}" -v port="${port}" -v ssl="${ssl}" -v ssl_block="${ssl_block}" -v auth_block="${auth_block}" \
        '{
            sub("{{NAME}}", id);
            sub("{{PORT}}", port);
            sub("{{SSL}}", ssl);
            sub("{{SSL_BLOCK}}", ssl_block);
            sub("{{AUTH_BLOCK}}", auth_block);
        };1'
}

function gen_ssl_block() {
    id="${1}"
    [ -z $(get_var ${id} SSL) ] && return 0 # should not happen but just in case
    
    private_key=$(get_var "${id}" SSL_PRIVATE_KEY)
    [ -z "${private_key}" ] && log_error "server '${id}' has ssl enabled but no private key was provided" && abort

    certificate=$(get_var "${id}" SSL_CERTIFICATE)
    [ -z "${certificate}" ] && log_error "server '${id}' has ssl enabled but no certificate was provided" && abort

    local client_validation_cert="$(get_var ${id} SSL_CLIENT_CERTIFICATE)"
    if [ ! -z ${client_validation_cert} ]; then
        local client_validation_block=$(echo -n "${CLIENT_VALIDATION_BLOCK}" |
            ${AWK} -v client_validation_cert="${client_validation_cert}" \
            '{ sub("{{CLIENT_VALIDATION_CERTIFICATE}}", client_validation_cert); };1')
    fi

    echo -n "${SSL_BLOCK}" |
        ${AWK} -v certificate="${certificate}" -v private_key="${private_key}" -v cv_block="${client_validation_block}" \
        '{
            sub("{{SERVER_CERTIFICATE}}", certificate);
            sub("{{SERVER_PRIVATE_KEY}}", private_key);
            sub("{{CLIENT_VALIDATION_BLOCK}}", cv_block);
        };1'
}

function gen_auth_block() {
    id="${1}"
    scheme="$(get_var ${id} AUTH)"
    case "${scheme}" in
        basic)
            fn="$(get_var ${id} AUTH_BASIC_PASSWD)"
            [ -z "${fn}" ] && log_error "PASSWD file is mandatory for basic auth in server '${id}'" && abort
            echo -n "${BASIC_AUTH_BLOCK}" | ${AWK} -v fn="${fn}" '{sub("{{BASIC_AUTH_PASSWD}}", fn)};1'
            ;;
        digest)
            fn="$(get_var ${id} AUTH_DIGEST_PASSWD)"
            [ -z "${fn}" ] && log_error "PASSWD file is mandatory for digest auth in server '${id}'" && abort
            echo -n "${DIGEST_AUTH_BLOCK}" | ${AWK} -v fn="${fn}" '{sub("{{DIGEST_AUTH_PASSWD}}", fn)};1'
            ;;
        bearer)
            fn="$(get_var ${id} AUTH_BEARER_JWKS)"
            [ -z "${fn}" ] && log_error "JWKS file is mandatory for bearer auth in server '${id}'" && abort
            echo -n "${BEARER_AUTH_BLOCK}" | ${AWK} -v fn="${fn}" '{sub("{{BEARER_AUTH_JWKS}}", fn)};1'
            ;;
        "")
            # No auth scheme, empty string is fine
            ;;
        *)
            log_error "invalid auth scheme: '${scheme}' in server '${id}'" && abort
    esac
}

function get_var() {
    var="HFP_${1}_${2}"
    echo -n ${!var}
}

function log_error() {
    awk " BEGIN { print \"$@\" > \"/dev/fd/2\" }"
}

function abort() {
    kill -s TERM ${ROOT_PID}
}


############## main execution flow

# setup abort handler
trap "exit 1" TERM
export ROOT_PID=$$

# ensure GNU awk is installed
[[ $(uname) == "Darwin" ]] && AWK="gawk" || AWK="gawk"
which ${AWK} > /dev/null || (log_error "GNU awk not found. If running on osx, try 'brew install gawk'" && abort)

# ensure minimal config is supplied
[ -z "${HFP_PROXIES}" ] && log_error "HFP_PROXIES is mandatory and must be a comma-separated list of proxy server names/identifiers" && abort

server_definitions=""
IFS=','
for sid in ${HFP_PROXIES}; do
    server_definitions="${server_definitions}\n$(gen_server_section ${sid})"
done

echo -n "${BASE_CONF}" |
    ${AWK} \
        -v user="${HFP_USER:-root}" \
        -v processes="${HFP_WORKER_PROCESSES:-4}" \
        -v connections="${HFP_WORKER_CONNECTIONS:-1024}" \
        -v servers="${server_definitions}" \
        '{
            sub("{{USER}}",user);
            sub("{{WORKER_PROCESSES}}",processes);
            sub("{{WORKER_CONNECTIONS}}",connections);
            sub("{{SERVER_DEFINITIONS}}",servers);
        };1'
     
