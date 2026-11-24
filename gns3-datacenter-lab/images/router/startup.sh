#!/bin/bash
# Demarrage d'un routeur : reseau de gestion, SSH, puis zebra + bgpd (config chargee ensuite par Ansible)
/usr/local/bin/netinit.sh
mkdir -p /run/sshd && ssh-keygen -A >/dev/null 2>&1
/usr/sbin/sshd

mkdir -p /etc/frr /var/run/frr
[ -s /etc/frr/frr.conf ] || echo "frr defaults datacenter" > /etc/frr/frr.conf
echo "service integrated-vtysh-config" > /etc/frr/vtysh.conf
chown -R frr:frr /etc/frr /var/run/frr
chgrp frrvty /etc/frr/vtysh.conf 2>/dev/null
chmod 640 /etc/frr/frr.conf

/usr/lib/frr/zebra -d -A 127.0.0.1 -s 90000000 -u frr -g frr
/usr/lib/frr/bgpd  -d -A 127.0.0.1 -u frr -g frr
exec ${DC_FINAL_CMD:-/bin/bash}
