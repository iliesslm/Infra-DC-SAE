#!/bin/sh
/usr/local/bin/netinit.sh
[ $# -eq 0 ] && set -- telegraf
exec /entrypoint.sh "$@"
