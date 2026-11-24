#!/bin/sh
# Active toutes les interfaces et configure l'IP de gestion (eth0) depuis $MGMT_IP (ex: 192.168.100.11/24)
ip link set lo up
for d in /sys/class/net/eth*; do
  [ -e "$d" ] && ip link set dev "$(basename "$d")" up 2>/dev/null
done
if [ -n "${MGMT_IP:-}" ]; then
  ip addr flush dev eth0 2>/dev/null
  ip addr add "$MGMT_IP" dev eth0
fi
exit 0
