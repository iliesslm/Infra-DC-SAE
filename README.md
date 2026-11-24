# Maquette datacenter GNS3 : fabric EVPN-VXLAN + VPN IPsec + supervision Grafana

Tout est **déployé par du code** : images Docker (Dockerfile), topologie GNS3 (script Python sur l'API),
configuration (Ansible + Jinja2), supervision (Telegraf/InfluxDB/Grafana provisionnés), tests (scripts bash).
Aucune configuration manuelle dans les équipements.

## Architecture

```
 SW-MGMT (192.168.100.0/24) ── ansible-ctl · influxdb · telegraf · grafana · tous les noeuds (eth0)

        spine1 (AS65000)        spine2 (AS65000)         underlay eBGP /31, overlay BGP EVPN
           │ ╲                    ╱ │
           │   ╲                ╱   │
        leaf1 (AS65011)       leaf2 (AS65012)            VTEP, L2VNI 10010 = VLAN 10
           │                    │    │
        client1             client2  edge-dc ═══ SW-INTERNET ═══ edge-branch ── client-branch
        10.10.10.11         .12      .1   (203.0.113.1)   (203.0.113.2)  .1     192.168.50.10
                                     └─ pare-feu nftables + IPsec IKEv2 ─┘
```

| Élément | Détail |
|---|---|
| Fabric | 2 spines + 2 leafs (FRR 8.4), eBGP en /31, BGP EVPN entre loopbacks, VXLAN (UDP 4789), 1 L2VNI (10010) |
| Gestion | `192.168.100.0/24` : spine1 .11, spine2 .12, leaf1 .21, leaf2 .22, edge-dc .31, edge-branch .32, ansible-ctl .2, influxdb .41, telegraf .42, grafana .43, client1 .51, client2 .52, client-branch .53 |
| LAN datacenter | `10.10.10.0/24` étendu entre leaf1 et leaf2 ; passerelle = `edge-dc` (10.10.10.1) |
| VPN | IPsec IKEv2 site-à-site (strongSwan), AES-256 / SHA-256 / MODP2048, PSK. `10.10.10.0/24` ⇄ `192.168.50.0/24` |
| Pare-feu | nftables sur les deux bordures, politique **drop** ; entre sites seuls ICMP et tcp 22/80/443 passent |
| Supervision | SNMP v2c (`dclab`) → Telegraf → InfluxDB → Grafana : débit des interfaces, état des liens, sessions BGP, SA IPsec |

## Contenu du dépôt

```
images/      Dockerfiles : dc-base, dc-router (FRR+snmpd), dc-edge (strongSwan+nftables), dc-client,
             dc-ansible (contrôleur), dc-influxdb, dc-telegraf, dc-grafana
gns3/        topology.json (noeuds + liens) et create_lab.py (crée tout via l'API GNS3)
ansible/     site.yml, inventory.yml, group_vars/, host_vars/, templates/ (Jinja2), files/, tasks/
monitoring/  telegraf.conf, provisioning Grafana (datasource + dashboard JSON)
tests/       verify.sh, resilience.sh, capture.sh
scripts/     build-images.sh, run-ansible.sh, run-tests.sh, fetch-captures.sh
docs/        plan du rapport
```

## Mise en route

**Prérequis** : GNS3 (2.2+ ou 3.x) avec sa **GNS3 VM** (recommandé sous Windows) ou GNS3 sur un Linux avec Docker.
Les nœuds Docker tournent sur le *serveur* GNS3 : les images doivent donc être construites **sur la GNS3 VM**
(ou sur ton Linux), avec un accès Internet.

1. **Copier le projet sur la GNS3 VM et construire les images** (≈ 5-10 min)
   ```sh
   scp -r gns3-datacenter-lab gns3@<IP_GNS3_VM>:~        # identifiants par défaut de la VM : gns3 / gns3
   ssh gns3@<IP_GNS3_VM>
   cd gns3-datacenter-lab && ./scripts/build-images.sh
   ```
2. **Créer la maquette dans GNS3** (depuis ton PC, python3 suffit)
   ```sh
   python3 gns3/create_lab.py --server http://<IP_GNS3_VM>:3080 --compute vm
   # GNS3 3.x : ajouter --user admin --password <mot de passe> si tu les as changés
   ```
   Le projet `dc-lab` apparaît dans GNS3 avec tous les nœuds démarrés. (`--recreate` pour repartir de zéro, `--destroy` pour supprimer.)
3. **Déployer la configuration** : ouvre la console du nœud `ansible-ctl` dans GNS3 puis
   ```sh
   cd /ansible && ansible-playbook site.yml
   ```
   (ou, sur la VM : `./scripts/run-ansible.sh`). Le playbook est idempotent : tu peux le relancer.
4. **Vérifier** (attendre ~30 s que BGP converge)
   ```sh
   /tests/verify.sh            # ou sur la VM : ./scripts/run-tests.sh verify
   ```
5. **Grafana** : ouvre la console web du nœud `grafana` (clic droit → *Web console*, port 3000), ou ajoute un nœud
   « Cloud/NAT » sur SW-MGMT. Identifiants `admin` / `admin`, tableau de bord « Maquette datacenter ».
6. **Pannes et captures pour le rapport**
   ```sh
   /tests/resilience.sh spine1      # coupe un spine, mesure la convergence ; puis redémarre le tunnel IPsec
   /tests/capture.sh                # pcap VXLAN/BGP (leaf1) et IKE/ESP (edge-dc) ; ./scripts/fetch-captures.sh pour les récupérer
   ```
   Ouvre les pcap dans Wireshark avec les filtres `vxlan || bgp` et `isakmp || esp`.

## Réglages utiles

- **MTU** : `underlay_mtu: 1500` (group_vars/all.yml) fonctionne partout. Les clients VXLAN reçoivent automatiquement 1450.
  Si ton serveur GNS3 laisse passer les trames jumbo, mets `9000` et relance le playbook, puis `UNDERLAY_MTU=9000 /tests/verify.sh`.
- **Secret IPsec** : `ansible/group_vars/edges.yml` (`ipsec_psk`). Pour le chiffrer :
  `ansible-vault encrypt_string 'secret' --name ipsec_psk` puis `ansible-playbook site.yml --ask-vault-pass`.
- **Reconfigurer sans tout recréer** : modifier les `host_vars`/templates puis relancer `site.yml`.
  FRR applique la config par fusion (`vtysh -b`) : après la *suppression* d'un élément, recrée la maquette (`create_lab.py --recreate`).
- **Redémarrage d'un nœud** : la configuration posée par Ansible est perdue si le conteneur est recréé ; relance `site.yml`.

## État de validation

| Partie | Validé comment |
|---|---|
| Playbook, templates FRR / bridges / VXLAN / SNMP / nftables / IPsec | Exécutés pour de vrai (SSH + Ansible) sur 9 nœuds isolés avec les vrais `startup.sh` des images : BGP, EVPN, VXLAN, L2 étendu, pare-feu, SNMP, négociation IKEv2 OK ; playbook idempotent |
| `verify.sh` / `resilience.sh` / `capture.sh` | Exécutés sur ce banc : 31 OK, 0 FAIL ; captures VXLAN, BGP et IKE décodées par tshark |
| `create_lab.py` | Testé contre un **faux serveur GNS3 v3** (flux, jeton, ports de switch, relance) ; pas contre un vrai GNS3 |
| Chiffrement ESP du tunnel | **Non testé** (le noyau du banc n'a pas ESP) : à valider chez toi avec `verify.sh` (SA ESP installée, ESP vu sur le lien Internet, aucun ICMP en clair) |
| Images Docker (`docker build`) | **Non construites** (pas de Docker sur le banc) ; les paquets Debian utilisés (frr 8.4, snmpd, strongswan-starter, nftables) sont ceux du banc |
| Telegraf / InfluxDB / Grafana | **Non exécutés** : fichiers validés (TOML/YAML/JSON), OID SNMP lus avec succès ; requêtes InfluxQL et rendu du dashboard à vérifier chez toi |
| Redémarrage du tunnel IPsec (`resilience.sh`) | Dépend de l'ESP : à valider chez toi |

## Dépannage rapide

- `create_lab.py` : « compute introuvable » → `--compute local` (GNS3 sans VM) ou `--compute vm`.
- Un nœud ne répond pas en SSH : ouvre sa console GNS3 et lance `ip -br a` ; `eth0` doit porter `192.168.100.x`.
- Pas de session BGP : sur un routeur, `vtysh -c 'show bgp summary'` ; relance `site.yml`.
- Tunnel IPsec : sur `edge-dc`, `ipsec statusall` ; les journaux sont dans `/var/log/syslog` (ou `journalctl` selon l'image).
