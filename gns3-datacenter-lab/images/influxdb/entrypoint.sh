#!/bin/sh
/usr/local/bin/netinit.sh
[ $# -eq 0 ] && set -- influxd
exec /entrypoint.sh "$@"
