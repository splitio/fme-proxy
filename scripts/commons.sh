#!/usr/bin/env bash

# -- shared functions

function get_var() {
    var="HFP_${1}_${2}"
    echo -n ${!var}
}

function log_error() {
    awk " BEGIN { print \"$@\" > \"/dev/fd/2\" }"
}

function abort() {
    log_error "killing ${ROOT_PID} from pid $$"
    kill -s TERM ${ROOT_PID}
}

function item_is_in_array() {
    local needle="${1}"
    shift
    for item in "$@"; do
        [ "${item}" = "${needle}" ] && return 0
    done
    return 1
}

# shared script init directives
trap "exit 1" TERM
export ROOT_PID=$$

# toggle debugging
[[ ${DEBUG} == "true" ]] && set -x

# ensure GNU awk is installed
[[ $(uname) == "Darwin" ]] && AWK="gawk" || AWK="gawk"
which ${AWK} > /dev/null || (log_error "GNU awk not found. If running on osx, try 'brew install gawk'" && abort)
