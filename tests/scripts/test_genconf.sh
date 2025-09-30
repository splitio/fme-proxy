#!/bin/bash

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_DIR=$(cd "$(dirname "${SCRIPT_DIR}")/.." &> /dev/null && pwd)
GENCONF="${PROJECT_DIR}/scripts/genconf.sh"

# Test cases

function test_defaults_and_simple_server() {

    local conf=$(HP_PROXIES=p1 HP_p1_PORT=3128 bash "${GENCONF}")
    assert_eq "$(_get_prop "${conf}" "daemon")" "off" "unexpected daemon"
    assert_eq "$(_get_prop "${conf}" "worker_processes")" "4" "unexpected worker_processes"
    assert_eq "$(_get_prop "${conf}" "error_log")" "/var/log/nginx/error.log info" "unexpected error_log"
    assert_eq "$(_get_prop "${conf}" "pid")" "/var/run/nginx/nginx.pid" "unexpected pid"

    local events=$(_get_section "${conf}" "events")
    assert_eq "$(_get_prop "${events}" "worker_connections")" "1024" "unexpected worker_connections"

    local http=$(_get_section "${conf}" "http")
    assert_eq "$(_get_prop "${http}" "include")" "/opt/openresty/conf/mime.types" "unexpected mime.types"
    assert_eq "$(_get_prop "${http}" "default_type")"  "application/octet-stream" "unexpected default_type"
    assert_eq "$(_get_prop "${http}" "access_log")" "/var/log/nginx/access.log" "unexpected access_log"
    assert_eq "$(_get_prop "${http}" "client_body_temp_path")" "/tmp/client_body_temp" "unexpected client_body_temp_path"
    assert_eq "$(_get_prop "${http}" "proxy_temp_path")" "/tmp/proxy_temp" "unexpected proxy_temp_path"
    assert_eq "$(_get_prop "${http}" "fastcgi_temp_path")" "/tmp/fastcgi_temp" "unexpected fastcgi_temp_path"
    assert_eq "$(_get_prop "${http}" "uwsgi_temp_path")" "/tmp/uwsgi_temp" "unexpected uwsgi_temp_path"
    assert_eq "$(_get_prop "${http}" "scgi_temp_path")" "/tmp/scgi_temp" "unexpected scgi_temp_path"
    assert_eq "$(_get_prop "${http}" "lua_package_path")" "\"/etc/nginx/lua/?.lua;/opt/openresty/lua/?.lua;;\"" "unexpected scgi_temp_path"

    local lua_init_block=$(_get_section "${http}" "init_by_lua_block")
    assert_contain "$(_get_prop "${lua_init_block}" "require")" "\"host_access_control\"" "missing whitelist validation module"
    assert_contain "$(_get_prop "${lua_init_block}" "require")" "\"host_whitelist_p1\"" "missing whitelist for server1"

    local version="$(_get_named_section "${http}" "server" "version")"
    assert_eq "$(_get_prop "${version}" "listen")" "8080" "unexpected listen"

    local version_location="$(_get_section "${version}" "location /version")"
    assert_eq "$(_get_prop "${version_location}" "default_type")"  "text/plain" "unexpected default_type in version location"
    assert_eq "$(_get_inline_section "${version_location}" "content_by_lua_block")" "ngx.say(\"1.0.0\")" "unexpected version content block"

    local p1="$(_get_named_section "${http}" "server" "p1")"
    assert_eq "$(_get_prop "${p1}" "listen")" "3128" "unexpected port"
    assert_eq "$(_get_prop "${p1}" "resolver")" "8.8.8.8 ipv6=off" "unexpected resolver"
    assert_true "$(_property_exists "${p1}" "proxy_connect")" "proxy_connect directive not present"
    assert_eq "$(_get_prop "${p1}" "proxy_connect_allow")" "80 443" "unexpected allowed ports"
    assert_eq "$(_get_prop "${p1}" "proxy_connect_connect_timeout")" "10s" "unexpected connect timeout"
    assert_eq "$(_get_prop "${p1}" "proxy_connect_data_timeout")" "120s" "unexpected data timeout"

    local p1_access="$(_get_section "${p1}" "access_by_lua_block")"
    assert_contain "${p1_access}" "local allowed_hosts = require \"host_whitelist_p1\".whitelist;"
    assert_contain "${p1_access}" "require \"host_access_control\".fail_if_host_not_allowed(allowed_hosts)"
}

function test_mtls() {

    local conf=$(HP_PROXIES=p1 \
        HP_p1_PORT=3128 \
        HP_p1_SSL=true \
        HP_p1_SSL_CERTIFICATE=cert.crt \
        HP_p1_SSL_PRIVATE_KEY=pk.key \
        HP_p1_SSL_CLIENT_CERTIFICATE=client_cert.crt \
        bash "${GENCONF}")

    local http=$(_get_section "${conf}" "http")
    local p1="$(_get_named_section "${http}" "server" "p1")"
    assert_eq "$(_get_prop "${p1}" "listen")" "3128 ssl" "unexpected port or (lack of) ssl directive"
    assert_eq "$(_get_prop "${p1}" "ssl_certificate")" "cert.crt" "unexpected server certificate"
    assert_eq "$(_get_prop "${p1}" "ssl_certificate_key")" "pk.key" "unexpected server certificate key"
    assert_eq "$(_get_prop "${p1}" "ssl_session_cache")" "shared:SSL:1m" "unexpected ssl session cache"
    assert_eq "$(_get_prop "${p1}" "ssl_verify_client")" "on" "unexpected ssl_verify_client value"
    assert_eq "$(_get_prop "${p1}" "ssl_client_certificate")" "client_cert.crt" "unexpected client cert"
}

function test_tls_basic_auth() {

    local conf=$(HP_PROXIES=p1 \
        HP_p1_PORT=3128 \
        HP_p1_SSL=true \
        HP_p1_SSL_CERTIFICATE=cert.crt \
        HP_p1_SSL_PRIVATE_KEY=pk.key \
        HP_p1_AUTH=basic \
        HP_p1_AUTH_BASIC_PASSWD="pepe.passwd" \
        bash "${GENCONF}")

    local http=$(_get_section "${conf}" "http")
    local p1="$(_get_named_section "${http}" "server" "p1")"
    assert_eq "$(_get_prop "${p1}" "listen")" "3128 ssl" "unexpected port or (lack of) ssl directive"
    assert_eq "$(_get_prop "${p1}" "ssl_certificate")" "cert.crt" "unexpected server certificate"
    assert_eq "$(_get_prop "${p1}" "ssl_certificate_key")" "pk.key" "unexpected server certificate key"
    assert_eq "$(_get_prop "${p1}" "ssl_session_cache")" "shared:SSL:1m" "unexpected ssl session cache"
    assert_eq "$(_get_prop "${p1}" "auth_basic")" "\"harness\"" "unexpected realm for basic auth"
    assert_eq "$(_get_prop "${p1}" "auth_basic_user_file")" "pepe.passwd" "unexpected basic auth passwd file"
    assert_eq "$(_get_prop "${p1}" "rewrite_by_lua_file")" "/opt/openresty/lua/proxy_auth_basic.lua" "unexpected header rewrite file"
}

function test_plain_digest_auth() {

    local conf=$(HP_PROXIES=p1 \
        HP_p1_PORT=3128 \
        HP_p1_AUTH=digest \
        HP_p1_AUTH_DIGEST_PASSWD="pepe2.passwd" \
        bash "${GENCONF}")

    local http=$(_get_section "${conf}" "http")
    local p1="$(_get_named_section "${http}" "server" "p1")"
    assert_eq "$(_get_prop "${p1}" "listen")" "3128" "unexpected port or (lack of) ssl directive"
    assert_eq "$(_get_prop "${p1}" "auth_digest")" "\"harness\"" "unexpected realm for basic auth"
    assert_eq "$(_get_prop "${p1}" "auth_digest_user_file")" "pepe2.passwd" "unexpected basic auth passwd file"
    assert_eq "$(_get_prop "${p1}" "rewrite_by_lua_file")" "/opt/openresty/lua/proxy_auth_digest.lua" "unexpected header rewrite file"
}

function test_tls_bearer_auth() {

    local conf=$(HP_PROXIES=p1 \
        HP_p1_PORT=3128 \
        HP_p1_SSL=true \
        HP_p1_SSL_CERTIFICATE=cert.crt \
        HP_p1_SSL_PRIVATE_KEY=pk.key \
        HP_p1_AUTH=bearer \
        HP_p1_AUTH_BEARER_JWKS="my.jwks" \
        bash "${GENCONF}")

    local http=$(_get_section "${conf}" "http")
    local p1="$(_get_named_section "${http}" "server" "p1")"
    assert_eq "$(_get_prop "${p1}" "listen")" "3128 ssl" "unexpected port or (lack of) ssl directive"
    assert_eq "$(_get_prop "${p1}" "ssl_certificate")" "cert.crt" "unexpected server certificate"
    assert_eq "$(_get_prop "${p1}" "ssl_certificate_key")" "pk.key" "unexpected server certificate key"
    assert_eq "$(_get_prop "${p1}" "ssl_session_cache")" "shared:SSL:1m" "unexpected ssl session cache"
    assert_eq "$(_get_prop "${p1}" "auth_jwt")" "\"all\"" "unexpected valule for jwt auth"
    assert_eq "$(_get_prop "${p1}" "auth_jwt_key_file")" "my.jwks" "unexpected basic auth jwks file"
    assert_eq "$(_get_prop "${p1}" "rewrite_by_lua_file")" "/opt/openresty/lua/proxy_auth_bearer.lua" "unexpected header rewrite file"
}

# Internal config parsing functions

function _get_section() {
    local context="${1}"
    local section="${2}"

    awk -v section"=${section} {" \
        'BEGIN { nested=0; }
        $0 ~ /\{/ { nested++; }
        $0 ~ /\}/ { nested--; if (nested == 0) { s=0; } }
        s == 1 && nested > 0
        $0 ~ section {s=1}' <<< "${context}"
}

function _get_named_section() {
    local context="${1}"
    local section="${2}"
    local name="${3}"

    # nested: numeric count of nested blocks (between curly braces)
    # n: numeric bool representing whether the name of this section matches the input name
    # s: numeric bool representing whether the current section matches the input one
    awk -v section"=${section} {" -v name="# ${name}" \
        'BEGIN { nested=0; s=0; n=0; }
        $0 ~ /\{/ && n > 0 { nested++; }
        $0 ~ /\}/ {
            if (n == 1) { nested--; }
            if (nested == 0) { s=0; n=0; }
        }
        s == 1 && n == 1 && nested > 0
        $0 ~ name {n=1}
        $0 ~ section {s=1}
        ' <<< "${context}"
}

function _get_inline_section() {
    local context="${1}"
    local section="${2}"

    awk -v re="[[:space:]]*${section}[[:space:]]*{" \
        '$0 ~ re {
            sub(re, "");
            sub(/[[:space:]]*\};{0,1}/, "")
            gsub(/^[ \t]+/,"",$0);
            gsub(/[ \t]+$/,"",$0);
            print $0;
        }' <<< "${context}"
}

function _get_prop() {
    local section="${1}"
    local prop="${2}"

    awk -v re="^[[:space:]]*${prop}[[:space:]]+" \
        'BEGIN { nested = 0; }
        $0 ~ /\{/ { nested++; }
        $0 ~ /\}/ { nested--; }
        $0 ~ re && nested == 0 { 
            $1="";
            sub(/;([[:space:]]*#.*){0,1}$/, "");
            gsub(/^[ \t]+/,"",$0);
            gsub(/[ \t]+$/,"",$0);
            print $0 
        }' <<< "${section}"
}

function _property_exists() {
    local section="${1}"
    local prop="${2}"
    awk -v re="^[[:space:]]*${prop}[[:space:]]*;([[:space:]]*#.*){0,1}$" \
        '$0 ~ re { print "true"; }' <<< "${section}"
}

# make version available to all tests
export HP_VERSION_FILE="${PROJECT_DIR}/VERSION"

# import assert
source "${SCRIPT_DIR}/assert.sh"

test_defaults_and_simple_server
test_tls_basic_auth
test_plain_digest_auth
test_mtls
test_tls_bearer_auth
