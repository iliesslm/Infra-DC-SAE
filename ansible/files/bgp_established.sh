#!/bin/sh
# Nombre de voisins BGP en etat Established (toutes address-families, sans doublon)
vtysh -c 'show bgp summary json' 2>/dev/null | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print(0); sys.exit()
up = set()
for af in d.values():
    if isinstance(af, dict):
        for ip, p in af.get("peers", {}).items():
            if p.get("state") == "Established":
                up.add(ip)
print(len(up))'
