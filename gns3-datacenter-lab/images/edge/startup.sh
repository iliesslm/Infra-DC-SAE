#!/bin/bash
# Demarrage d'un equipement de bordure : gestion + SSH ; nftables/IPsec/SNMP sont poses par Ansible
/usr/local/bin/netinit.sh
mkdir -p /run/sshd && ssh-keygen -A >/dev/null 2>&1
/usr/sbin/sshd
echo 1 > /proc/sys/net/ipv4/ip_forward
exec ${DC_FINAL_CMD:-/bin/bash}
