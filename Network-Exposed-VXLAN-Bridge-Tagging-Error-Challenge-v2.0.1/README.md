# Network Exposed VXLAN Bridge Tagging Error Challenge v2.0.1

A native Linux networking challenge where an external participant starts with only the challenge machine IP. The participant discovers TCP/8088 and UDP/4789, retrieves a leaked VXLAN VNI, joins VLAN 10 through real VXLAN, receives a real DHCP lease, and exploits incorrect tagged VLAN 30 membership on a Linux bridge port.

## Real components
- Linux kernel bridge with VLAN filtering
- Linux kernel VXLAN on UDP/4789
- IEEE 802.1Q VLAN tags
- Network namespaces and veth pairs
- dnsmasq DHCP/DNS
- Real HTTP services and packet traffic

## Deploy
```bash
cd "Red-vs-Blue Module"
sudo ./setup.sh
sudo ./validate.sh
```

Permit authorised attacker traffic to TCP/8088 and UDP/4789 on the machine's existing private/local IP. No second IP and no DNAT are used.
