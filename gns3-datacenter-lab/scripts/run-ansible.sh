#!/usr/bin/env bash
# Lance le playbook depuis le conteneur ansible-ctl (a executer sur l'hote qui heberge les noeuds Docker).
# Equivalent : ouvrir la console de ansible-ctl dans GNS3, puis  cd /ansible && ansible-playbook site.yml
set -euo pipefail
C=$(docker ps -q --filter ancestor=dc-ansible:1 | head -1)
[ -n "$C" ] || { echo "Conteneur ansible-ctl introuvable : le projet GNS3 est-il demarre ?"; exit 1; }
docker exec -w /ansible "$C" ansible-playbook site.yml "$@"
