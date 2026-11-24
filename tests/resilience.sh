#!/usr/bin/env bash
# Tests de panne : coupure d'un spine pendant un flux continu, puis redemarrage du tunnel IPsec.
#   ./resilience.sh [spine1|spine2]
cd "$(dirname "$0")" && . ./lib.sh
SPINE=${1:-spine1}
ITV=0.05; COUNT=${COUNT:-400}

echo "== Panne de $SPINE (flux client1 -> client2, ping toutes les ${ITV}s)"
x client1 "ping -i $ITV -c $COUNT -W 1 10.10.10.12" > /tmp/res-spine.txt 2>&1 &
P=$!
sleep 4
echo ">> t=4s  : extinction de $SPINE (eth1 et eth2 down)"
x "$SPINE" "ip link set eth1 down; ip link set eth2 down"
sleep 8
echo "   voisins BGP de leaf1 encore Established : $(x leaf1 /usr/local/bin/bgp_established.sh)/4 (attendu 2/4)"
echo ">> t=12s : retablissement de $SPINE"
x "$SPINE" "ip link set eth1 up; ip link set eth2 up"
wait $P
grep transmitted /tmp/res-spine.txt
LOST=$(grep -oE '[0-9]+ received' /tmp/res-spine.txt | awk -v c=$COUNT '{print c-$1}')
python3 -c "print(f'Paquets perdus : $LOST  ->  convergence estimee : {$LOST*$ITV:.2f} s')"
sleep 10
check "fabric reconverge (4 voisins sur leaf1)" eq "$(x leaf1 /usr/local/bin/bgp_established.sh)" 4
check "client1 -> client2 apres retour"          x client1 "ping -c 2 -W 2 10.10.10.12"

echo
echo "== Panne du tunnel IPsec (redemarrage de strongSwan sur edge-dc)"
x client-branch "ping -i 0.2 -c 150 -W 1 10.10.10.11" > /tmp/res-vpn.txt 2>&1 &
P=$!
sleep 4
echo ">> t=4s : ipsec restart sur edge-dc"
x edge-dc "ipsec restart >/dev/null 2>&1"
wait $P
grep transmitted /tmp/res-vpn.txt
LOST=$(grep -oE '[0-9]+ received' /tmp/res-vpn.txt | awk '{print 150-$1}')
python3 -c "print(f'Paquets perdus : $LOST  ->  tunnel retabli en ~{$LOST*0.2:.1f} s')"
check "SA IKE reetablie" has edge-branch "ipsec statusall" ESTABLISHED
summary
