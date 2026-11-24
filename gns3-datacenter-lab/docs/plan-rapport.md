# Plan du rapport

1. **Contexte et objectifs** : datacenter à moderniser (fin du STP), interconnexion d'un site distant, supervision, infra as code.
2. **Architecture** : schéma, plan d'adressage (loopbacks, /31, VNI, LAN, WAN), choix techniques (eBGP, EVPN, VXLAN, IPsec IKEv2).
   Comparatif STP/trunking vs EVPN-VXLAN.
3. **Mise en place**
   - Images Docker et topologie GNS3 (`create_lab.py`)
   - Configuration Ansible : inventaire, variables, templates Jinja2 (extraits commentés)
   - VPN IPsec : paramètres IKE/ESP, PSK, sélecteurs de trafic, pare-feu nftables
4. **Supervision** : SNMP, Telegraf, InfluxDB, Grafana ; captures d'écran du tableau de bord.
5. **Analyse de trames (Wireshark)** : en-tête VXLAN (IP externe, UDP 4789, VNI, Ethernet interne), annonces BGP EVPN (type-2 MAC/IP, type-3 multicast), échange IKE_SA_INIT / IKE_AUTH, paquets ESP.
6. **Cahier de recette** : tableau des tests de `verify.sh` (résultat attendu / obtenu).
7. **Tests de résilience** : coupure d'un spine (convergence), redémarrage du tunnel (temps de rétablissement), courbes Grafana pendant la panne.
8. **Conclusion et perspectives** : VRF + L3VNI + Anycast Gateway, 802.1X avec FreeRADIUS, certificats IPsec, haute disponibilité des bordures.
