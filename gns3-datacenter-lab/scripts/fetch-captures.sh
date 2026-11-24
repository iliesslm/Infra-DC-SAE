#!/usr/bin/env bash
# Recupere les pcap generes par tests/capture.sh dans ./captures
C=$(docker ps -q --filter ancestor=dc-ansible:1 | head -1)
mkdir -p captures && docker cp "$C:/captures/." captures/ && ls -l captures
