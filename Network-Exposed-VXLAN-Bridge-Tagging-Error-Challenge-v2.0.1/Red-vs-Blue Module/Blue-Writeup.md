# Blue Team Detection and Mitigation

Monitor UDP/4789, the bridge FDB, DHCP leases, tagged VLAN 30 frames on `vxlan-user`, and management HTTP access.

```bash
sudo tcpdump -ni any udp port 4789
sudo tcpdump -eni vxlan-user 'vlan 30'
bridge fdb show dev vxlan-user
cat runtime/dnsmasq.leases
cat runtime/mgmt-access.log
```

The root cause is:

```bash
bridge vlan add dev vxlan-user vid 10 pvid untagged
bridge vlan add dev vxlan-user vid 30
```

Mitigate with:

```bash
sudo bridge vlan del dev vxlan-user vid 30
```
