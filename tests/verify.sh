#!/usr/bin/env bash
# Verification de bout en bout de la maquette (a lancer depuis ansible-ctl apres le playbook).
cd "$(dirname "$0")" && . ./lib.sh
M=$((UNDERLAY_MTU-28))      # plus gros ping sans fragmentation sur l'underlay
C=$((UNDERLAY_MTU-50-28))   # idem pour un client a travers le VXLAN

echo "== 0. Acces SSH (reseau de gestion)"
for n in spine1 spine2 leaf1 leaf2 edge-dc edge-branch client1 client2 client-branch; do
  check "$n joignable" x "$n" true
done

echo "== 1. BGP (underlay eBGP + sessions EVPN) : 4 voisins Established par routeur"
for n in spine1 spine2 leaf1 leaf2; do
  check "$n : 4 voisins BGP Established" eq "$(x $n /usr/local/bin/bgp_established.sh 2>/dev/null)" 4
done

echo "== 2. Overlay EVPN-VXLAN"
check "leaf1 voit le VTEP de leaf2 (VNI 10010)" vhas leaf1 "show evpn vni 10010" 10.0.0.12
check "leaf2 voit le VTEP de leaf1 (VNI 10010)" vhas leaf2 "show evpn vni 10010" 10.0.0.11

echo "== 3. MTU de l'underlay (ping DF, loopback a loopback)"
check "leaf1 -> leaf2 (${M} octets)" x leaf1 "ping -M do -s $M -c 2 -W 2 -I 10.0.0.11 10.0.0.12"
check "leaf2 -> leaf1 (${M} octets)" x leaf2 "ping -M do -s $M -c 2 -W 2 -I 10.0.0.12 10.0.0.11"

echo "== 4. Le VLAN 10 est etendu entre les leafs (L2 a travers le VXLAN)"
check "client1 -> client2 (10.10.10.12)"         x client1 "ping -c 2 -W 2 10.10.10.12"
check "client1 -> passerelle edge-dc (10.10.10.1)" x client1 "ping -c 2 -W 2 10.10.10.1"
check "client2 -> passerelle edge-dc (10.10.10.1)" x client2 "ping -c 2 -W 2 10.10.10.1"
check "client1 -> client2 avec paquet de ${C} octets (DF)" x client1 "ping -M do -s $C -c 2 -W 2 10.10.10.12"

echo "== 5. VPN IPsec site-a-site (IKEv2)"
check "edge-dc : SA IKE etablie"     has edge-dc "ipsec statusall" ESTABLISHED
check "edge-branch : SA IKE etablie" has edge-branch "ipsec statusall" ESTABLISHED
if [ -n "${NO_ESP:-}" ]; then
  skip "SA ESP installee, chiffrement du trafic (noyau sans ESP : environnement de test limite)"
else
  check "edge-dc : SA ESP installee" has edge-dc "ipsec statusall" INSTALLED
  x edge-dc "rm -f /tmp/wan.txt; (timeout 10 tcpdump -ni eth2 -c 3 esp > /tmp/esp.txt 2>&1 &) ; (timeout 10 tcpdump -ni eth2 -c 1 'icmp and host 192.168.50.10' > /tmp/clear.txt 2>&1 &)" 
  sleep 1; x client-branch "ping -c 4 -W 2 10.10.10.11" >/dev/null 2>&1; sleep 9
  check "trafic ESP observe sur le lien Internet" has edge-dc "cat /tmp/esp.txt" "ESP"
  check "aucun ICMP en clair sur le lien Internet" has edge-dc "cat /tmp/clear.txt" "0 packets captured"
fi
check "client-branch -> client1 a travers le VPN"  x client-branch "ping -c 2 -W 2 10.10.10.11"
check "client-branch -> client2 a travers le VPN"  x client-branch "ping -c 2 -W 2 10.10.10.12"
check "client1 -> client-branch a travers le VPN"  x client1 "ping -c 2 -W 2 192.168.50.10"

echo "== 6. Filtrage de bordure (seuls ICMP et tcp 22/80/443 entre les sites)"
x client1 "pkill -f 'http.server' ; (nohup python3 -m http.server 80 >/dev/null 2>&1 &) ; (nohup python3 -m http.server 8080 >/dev/null 2>&1 &)" >/dev/null 2>&1
sleep 2
check     "client-branch -> client1 tcp/80 autorise"       x client-branch "curl -s -m 4 -o /dev/null http://10.10.10.11:80/"
check_not "client-branch -> client1 tcp/8080 bloque"       x client-branch "curl -s -m 4 -o /dev/null http://10.10.10.11:8080/"

echo "== 7. Supervision (SNMP, InfluxDB, Grafana)"
check "SNMP : sysName de spine1"            bash -c "snmpget -v2c -c dclab -Oqv ${IP[spine1]} .1.3.6.1.2.1.1.5.0 | grep -q spine1"
check "SNMP : compteur BGP de leaf1 = 4"    bash -c "snmpget -v2c -c dclab -Oqv ${IP[leaf1]} .1.3.6.1.4.1.8072.1.3.2.3.1.1.15.98.103.112.95.101.115.116.97.98.108.105.115.104.101.100 | grep -q 4"
if [ -n "${NO_MONITORING:-}" ]; then
  skip "InfluxDB / Grafana (non disponibles dans cet environnement de test)"
else
  check "InfluxDB contient des donnees 'interface'" bash -c "curl -s -G 'http://${IP[influxdb]}:8086/query' --data-urlencode 'db=telegraf' --data-urlencode 'q=SELECT count(ifHCInOctets) FROM interface' | grep -q '\"values\"'"
  check "Grafana repond (api/health)"               bash -c "curl -s -m 5 http://${IP[grafana]}:3000/api/health | grep -q ok"
  check "Dashboard 'dc-lab' provisionne"            bash -c "curl -s -m 5 -u admin:admin http://${IP[grafana]}:3000/api/dashboards/uid/dc-lab | grep -q dc-lab"
fi
summary
