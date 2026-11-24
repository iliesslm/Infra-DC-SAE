#!/usr/bin/env bash
# Captures pour le rapport Wireshark : VXLAN + BGP EVPN (leaf1) et IKE/ESP (edge-dc, cote Internet).
# Resultat dans $CAPDIR (defaut /captures) ; recuperer avec : docker cp <conteneur ansible-ctl>:/captures .
cd "$(dirname "$0")" && . ./lib.sh
mkdir -p "$CAPDIR"

echo ">> capture VXLAN + BGP sur leaf1 (toutes interfaces) et IKE/ESP sur edge-dc"
x leaf1   "rm -f /tmp/fabric.pcap; (timeout 45 tcpdump -ni any -w /tmp/fabric.pcap 'udp port 4789 or tcp port 179' >/dev/null 2>&1 &)"
x edge-dc "rm -f /tmp/vpn.pcap;    (timeout 45 tcpdump -ni eth2 -w /tmp/vpn.pcap 'esp or udp port 500 or udp port 4500' >/dev/null 2>&1 &)"
sleep 2
echo ">> trafic VXLAN (ARP + ICMP encapsules)"
x client1 "ip neigh flush all; ping -c 5 -W 1 10.10.10.12" >/dev/null 2>&1
echo ">> reset des sessions BGP de leaf1 (pour capturer les annonces EVPN type-2/3)"
vt leaf1 "clear bgp *" >/dev/null 2>&1
sleep 12
echo ">> trafic dans le tunnel IPsec"
x client-branch "ping -c 5 -W 1 10.10.10.11" >/dev/null 2>&1
echo ">> renegociation IKE (ipsec restart sur edge-dc)"
x edge-dc "ipsec restart >/dev/null 2>&1"
sleep 20
x leaf1   "pkill tcpdump" ; x edge-dc "pkill tcpdump"; sleep 1
scp "${SSH_OPTS[@]}" "root@${IP[leaf1]}:/tmp/fabric.pcap" "$CAPDIR/fabric-leaf1.pcap"
scp "${SSH_OPTS[@]}" "root@${IP[edge-dc]}:/tmp/vpn.pcap"  "$CAPDIR/vpn-edge-dc-wan.pcap"
ls -l "$CAPDIR"
echo "Filtres Wireshark : vxlan || bgp   et   isakmp || esp"
