#!/usr/bin/env bash

export LD_LIBRARY_PATH="/usr/local/lib"
exec /usr/nginx/sbin/nginx \
    -g daemon off


