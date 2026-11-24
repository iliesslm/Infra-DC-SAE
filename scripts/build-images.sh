#!/usr/bin/env bash
# Construit toutes les images Docker de la maquette. A lancer SUR LA MACHINE QUI HEBERGE LES NOEUDS
# DOCKER DE GNS3 (la GNS3 VM, ou ton Linux si GNS3 y tourne). Necessite Docker et un acces Internet.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CTX="$ROOT/.build-context"

# --- cle SSH du lab (generee une seule fois) ---
if [ ! -f "$ROOT/images/common/dc_lab" ]; then
  ssh-keygen -q -t ed25519 -N "" -C "dc-lab" -f "$ROOT/images/common/dc_lab"
fi
cp "$ROOT/images/common/dc_lab.pub" "$ROOT/images/common/authorized_keys"

# --- contexte de build : images + ansible + tests + configs de supervision ---
rm -rf "$CTX" && mkdir -p "$CTX"
cp -r "$ROOT/images/"* "$CTX/"
cp -r "$ROOT/ansible" "$CTX/ansible"
cp -r "$ROOT/tests"   "$CTX/tests"
mkdir -p "$CTX/grafana" "$CTX/telegraf"
cp -r "$ROOT/monitoring/grafana/provisioning" "$CTX/grafana/provisioning"
cp -r "$ROOT/monitoring/grafana/dashboards"   "$CTX/grafana/dashboards"
cp    "$ROOT/monitoring/telegraf.conf"        "$CTX/telegraf/telegraf.conf"
cp    "$ROOT/images/grafana/Dockerfile"       "$CTX/grafana/Dockerfile"

build() { echo "==> $2"; docker build -q -t "$2" -f "$CTX/$1/Dockerfile" "$CTX" >/dev/null; }
build base      dc-base:1
build router    dc-router:1
build edge      dc-edge:1
build client    dc-client:1
build ansible-ctl dc-ansible:1
build influxdb  dc-influxdb:1
build telegraf  dc-telegraf:1
build grafana   dc-grafana:1
echo "Images pretes :"; docker images --format '  {{.Repository}}:{{.Tag}}' | grep '^  dc-'
