#!/bin/bash
/usr/local/bin/netinit.sh
mkdir -p /run/sshd && ssh-keygen -A >/dev/null 2>&1
/usr/sbin/sshd
exec ${DC_FINAL_CMD:-/bin/bash}
