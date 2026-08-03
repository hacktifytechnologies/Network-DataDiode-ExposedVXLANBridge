#!/usr/bin/env bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y iproute2 bridge-utils dnsmasq curl python3 tcpdump nmap procps isc-dhcp-client
