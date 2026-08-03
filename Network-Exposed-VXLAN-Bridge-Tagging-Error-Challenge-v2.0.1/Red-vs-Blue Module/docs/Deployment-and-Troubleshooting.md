# Deployment and Troubleshooting

Allow TCP/8088 and UDP/4789 to the machine's existing private/local IP. No second IP, loopback VTEP, random port, or DNAT is used.

```bash
ip -d link show vxlan-user
bridge vlan show dev vxlan-user
tcpdump -ni any udp port 4789
cat runtime/dnsmasq.log
```
