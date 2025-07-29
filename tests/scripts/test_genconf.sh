#!/bin/bash

set -x
set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_DIR=$(cd "$(dirname "${SCRIPT_DIR}")/.." &> /dev/null && pwd)
GENCONF="${PROJECT_DIR}/scripts/genconf.sh"

# Test cases

function test_basic() {
    local conf=$(HFP_PROXIES=p1 HFP_p1_PORT=3128 bash "${GENCONF}")
    #assert_eq "$(_get_prop "${conf}" "daemon")" "off" "unexpected value"
    #assert_eq "$(_get_prop "${conf}" "worker_processes")" "4" "unexpected value"
    #assert_eq "$(_get_prop "${conf}" "error_log")" "/var/log/nginx/error.log info" "unexpected value"
    #assert_eq "$(_get_prop "${conf}" "pid")" "/var/run/nginx/nginx.pid" "unexpected value"
    #assert_eq "$(_get_prop "${conf}" "worker_connections")" "1024" "unexpected value"
    #assert_eq "$(_get_prop "${conf}" "include")" "/opt/openresty/conf/mime.types" "unexpected value"
    #assert_eq "$(_get_prop "${conf}" "default_type")"  "application/octet-stream" "unexpected value"
    #assert_eq "$(_get_prop "${conf}" "access_log")" "/var/log/nginx/access.log" "unexpected value"
    #assert_eq "$(_get_prop "${conf}" "client_body_temp_path")" "/tmp/client_body_temp" "unexpected value"
    #assert_eq "$(_get_prop "${conf}" "proxy_temp_path")" "/tmp/proxy_temp" "unexpected value"
    #assert_eq "$(_get_prop "${conf}" "fastcgi_temp_path")" "/tmp/fastcgi_temp" "unexpected value"
    #assert_eq "$(_get_prop "${conf}" "uwsgi_temp_path")" "/tmp/uwsgi_temp" "unexpected value"
    #assert_eq "$(_get_prop "${conf}" "scgi_temp_path")" "/tmp/scgi_temp" "unexpected value"

    _get_section "${conf}" "http"

    #local p1="$(_get_server "${conf}" "p1")"
    #assert_eq "$(_get_prop "${p1}" "listen")" "3128" "unexpected port"
}

# Internal test functions

function _get_section() {
    local context="${1}"
    local section="${2}"

    awk -v section"=${section} {" \
        'BEGIN { nested=0; }
        $0 ~ section {f=1}f
        $0 ~ /\{/ { nested++; }
        $0 ~ /\}/ { nested--; if (nested == 0) { f=0; } }' <<< "${conf}"

}

function _get_server() {
    local conf="${1}"
    local server="${2}"
    awk -v server"=${server}" '$0 ~ server {f=1}f; /^    \}/ { f=0 }' <<< "${conf}"
}

function _get_prop() {
    local section="${1}"
    local prop="${2}"
    awk -v prop="${prop}" \
        ' $0 ~ prop { 
            $1="";
            sub(";", "");
            gsub(/^[ \t]+/,"",$0);
            gsub(/[ \t]+$/,"",$0);
            print $0 
        }' <<< "${section}"
}

# make version available to all tests
export HFP_VERSION_FILE="${PROJECT_DIR}/VERSION"

# import assert
source "${SCRIPT_DIR}/assert.sh"

test_basic
