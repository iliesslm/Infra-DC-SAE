#!/bin/sh
# Nombre de SA enfants (ESP) installees
ipsec statusall 2>/dev/null | grep -c INSTALLED || true
