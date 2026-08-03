#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$EUID" -eq 0 ]] || { echo "Run as root"; exit 1; }
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; R="$D/runtime"; mkdir -p "$R" "$D/evidence"
"$D/deps.sh"
EXT_IF="$(ip route show default | awk '/default/ {print $5; exit}')"
EXT_IP="$(ip -4 -o addr show dev "$EXT_IF" | awk '{print $4}' | cut -d/ -f1 | head -n1)"
[[ -n "$EXT_IP" ]] || { echo "IP discovery failed"; exit 1; }
BR=br-vlanlab; VX=vxlan-user; VNI=200; USER_VLAN=10; MGMT_VLAN=30
USER_NS=vlan10-services; WORK_NS=vlan10-workstation; MGMT_NS=vlan30-management; ADMIN_NS=vlan30-approved
USER_GW=10.20.10.1; WORK_IP=10.20.10.20; MGMT_IP=10.20.30.10; ADMIN_IP=10.20.30.20
for f in "$R"/*.pid; do [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null || true; done
for n in "$USER_NS" "$WORK_NS" "$MGMT_NS" "$ADMIN_NS"; do ip netns del "$n" 2>/dev/null || true; done
ip link del "$VX" 2>/dev/null || true; ip link del "$BR" 2>/dev/null || true
rm -f "$R"/*.pid "$R"/*.log "$R"/dnsmasq.leases
cat > "$R/lab.env" <<EOF
EXT_IF=$EXT_IF
EXT_IP=$EXT_IP
BR=$BR
VXLAN_PORT=$VX
VXLAN_VNI=$VNI
USER_VLAN=$USER_VLAN
MGMT_VLAN=$MGMT_VLAN
USER_NS=$USER_NS
WORK_NS=$WORK_NS
MGMT_NS=$MGMT_NS
ADMIN_NS=$ADMIN_NS
USER_GW=$USER_GW
WORK_IP=$WORK_IP
MGMT_IP=$MGMT_IP
ADMIN_IP=$ADMIN_IP
EOF
ip link add "$BR" type bridge vlan_filtering 1 vlan_default_pvid 0; ip link set "$BR" up
make_port(){ local ns="$1" host="$2" peer="$3"; ip netns add "$ns"; ip link add "$host" type veth peer name "$peer"; ip link set "$peer" netns "$ns"; ip link set "$host" master "$BR"; ip link set "$host" up; ip netns exec "$ns" ip link set lo up; ip netns exec "$ns" ip link set "$peer" up; }
make_port "$USER_NS" user-svc user0; make_port "$WORK_NS" user-work work0; make_port "$MGMT_NS" mgmt-host mgmt0; make_port "$ADMIN_NS" approved-host admin0
bridge vlan add dev user-svc vid 10 pvid untagged; bridge vlan add dev user-work vid 10 pvid untagged; bridge vlan add dev mgmt-host vid 30 pvid untagged; bridge vlan add dev approved-host vid 30 pvid untagged
ip netns exec "$USER_NS" ip addr add "$USER_GW/24" dev user0; ip netns exec "$WORK_NS" ip addr add "$WORK_IP/24" dev work0; ip netns exec "$MGMT_NS" ip addr add "$MGMT_IP/24" dev mgmt0; ip netns exec "$ADMIN_NS" ip addr add "$ADMIN_IP/24" dev admin0
ip link add "$VX" type vxlan id "$VNI" local "$EXT_IP" dstport 4789 learning; ip link set "$VX" master "$BR"; ip link set "$VX" up
bridge vlan add dev "$VX" vid 10 pvid untagged; bridge vlan add dev "$VX" vid 30
cat > "$R/maintenance.py" <<'PYA'
from http.server import BaseHTTPRequestHandler, HTTPServer

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/backup.conf":
            body = b"# legacy overlay backup\nVXLAN_PORT=4789\nVXLAN_VNI=200\nACCESS_PROFILE=user-edge\n"
        else:
            body = b"Network Maintenance Portal\nArchived configuration: /backup.conf\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass

HTTPServer(("0.0.0.0", 8088), Handler).serve_forever()
PYA
nohup python3 "$R/maintenance.py" >"$R/maintenance.log" 2>&1 & echo $! > "$R/maintenance.pid"
cat > "$R/workstation.py" <<'PYB'
from http.server import BaseHTTPRequestHandler, HTTPServer

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/network-note":
            body = b"Legacy switch migration note: management subnet 10.20.30.0/24 remains on tagged VLAN 30.\n"
        else:
            body = b"User Services Portal\nDiagnostics: /network-note\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass

HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
PYB
cat > "$R/management.py" <<PYC
from http.server import BaseHTTPRequestHandler, HTTPServer

LOG = r"$R/mgmt-access.log"
FLAG = b"FLAG{linux_bridge_tagged_vlan_bypass}\\n"

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        with open(LOG, "a", encoding="utf-8") as handle:
            handle.write(f"{self.client_address[0]} {self.path}\\n")
        body = FLAG
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass

HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
PYC
ip netns exec "$WORK_NS" sh -c "nohup python3 '$R/workstation.py' >'$R/workstation.log' 2>&1 & echo \$! > '$R/workstation.pid'"
ip netns exec "$MGMT_NS" sh -c "nohup python3 '$R/management.py' >'$R/management.log' 2>&1 & echo \$! > '$R/management.pid'"
ip netns exec "$USER_NS" dnsmasq --no-daemon --interface=user0 --bind-interfaces --dhcp-authoritative --dhcp-range=10.20.10.100,10.20.10.150,255.255.255.0,10m --dhcp-option=3 --dhcp-option=6,10.20.10.1 --address=/user-portal.lab/10.20.10.20 --dhcp-leasefile="$R/dnsmasq.leases" --log-dhcp --log-facility="$R/dnsmasq.log" & echo $! > "$R/dnsmasq.pid"
for _ in $(seq 1 20); do
  if curl -fsS --connect-timeout 1 "http://${EXT_IP}:8088/backup.conf" >/dev/null 2>&1      && ip netns exec "$WORK_NS" curl -fsS --connect-timeout 1 "http://${WORK_IP}:8080/network-note" >/dev/null 2>&1      && ip netns exec "$ADMIN_NS" curl -fsS --connect-timeout 1 "http://${MGMT_IP}:8080/" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
"$D/validate.sh"
echo "Setup Successful"
echo "Challenge IP: $EXT_IP"
echo "Only TCP/8088 and UDP/4789 must be reachable from the authorised attacker."
