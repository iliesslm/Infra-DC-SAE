#!/bin/sh
# Nombre de SA IKE etablies
ipsec statusall 2>/dev/null | grep -c ESTABLISHED || true
