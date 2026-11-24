#!/usr/bin/env bash
# Fonctions communes aux tests. A lancer depuis ansible-ctl (SSH sur le reseau de gestion).
# Variables : SSH_KEY, UNDERLAY_MTU (defaut 1500), NO_ESP=1 / NO_MONITORING=1 pour sauter ces tests.
SSH_KEY=${SSH_KEY:-/root/.ssh/id_ed25519}
UNDERLAY_MTU=${UNDERLAY_MTU:-1500}
CAPDIR=${CAPDIR:-/captures}

declare -A IP=(
  [ansible-ctl]=192.168.100.2
  [spine1]=192.168.100.11 [spine2]=192.168.100.12 [leaf1]=192.168.100.21 [leaf2]=192.168.100.22
  [edge-dc]=192.168.100.31 [edge-branch]=192.168.100.32
  [influxdb]=192.168.100.41 [telegraf]=192.168.100.42 [grafana]=192.168.100.43
  [client1]=192.168.100.51 [client2]=192.168.100.52 [client-branch]=192.168.100.53
)
SSH_OPTS=(-i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
          -o LogLevel=ERROR -o ConnectTimeout=5 -o BatchMode=yes)

# x <noeud> "<commande>" : execute la commande sur le noeud (via SSH)
x()  { local n=$1; shift; ssh "${SSH_OPTS[@]}" "root@${IP[$n]}" "$@"; }
# vt <noeud> "<commande vtysh>"
vt() { x "$1" "vtysh -c '$2'"; }

# has <noeud> "<commande>" <motif> : vrai si la sortie de la commande contient le motif
has()  { local n=$1 c=$2 p=$3; x "$n" "$c" 2>/dev/null | grep -q -- "$p"; }
# vhas <noeud> "<commande vtysh>" <motif>
vhas() { local n=$1 c=$2 p=$3; vt "$n" "$c" 2>/dev/null | grep -q -- "$p"; }

PASS=0; FAIL=0; SKIP=0
ok()   { echo "  [OK]   $1"; PASS=$((PASS+1)); }
ko()   { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
skip() { echo "  [SKIP] $1"; SKIP=$((SKIP+1)); }
check()     { local d=$1; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else ko "$d"; fi; }
check_not() { local d=$1; shift; if "$@" >/dev/null 2>&1; then ko "$d"; else ok "$d"; fi; }
eq()        { [ "$1" = "$2" ]; }
summary()   { echo; echo "Resultat : $PASS OK, $FAIL FAIL, $SKIP ignores"; [ "$FAIL" -eq 0 ]; }
