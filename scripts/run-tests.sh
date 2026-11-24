#!/usr/bin/env bash
# Lance un script de test dans ansible-ctl :  ./run-tests.sh verify | resilience [spine1|spine2] | capture
set -euo pipefail
T=${1:-verify}; shift || true
C=$(docker ps -q --filter ancestor=dc-ansible:1 | head -1)
[ -n "$C" ] || { echo "Conteneur ansible-ctl introuvable : le projet GNS3 est-il demarre ?"; exit 1; }
docker exec -it "$C" "/tests/$T.sh" "$@"
if [ "$T" = capture ]; then
  mkdir -p captures && docker cp "$C:/captures/." captures/ && echo "Captures copiees dans ./captures"
fi
