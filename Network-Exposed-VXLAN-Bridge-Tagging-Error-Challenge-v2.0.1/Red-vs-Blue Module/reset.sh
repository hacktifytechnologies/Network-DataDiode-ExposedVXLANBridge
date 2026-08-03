#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$EUID" -eq 0 ]] || exit 1
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; R="$D/runtime"
for f in "$R"/*.pid; do [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null || true; done
for n in vlan10-services vlan10-workstation vlan30-management vlan30-approved; do ip netns del "$n" 2>/dev/null || true; done
ip link del vxlan-user 2>/dev/null || true; ip link del br-vlanlab 2>/dev/null || true
rm -f "$R"/*.pid "$R"/*.log "$R"/dnsmasq.leases "$R"/lab.env
echo "Reset Successful"
