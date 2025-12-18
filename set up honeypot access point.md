# Captive Portal Honeypot - Complete Documentation

## Quick Start Commands

### 1. Create Configuration Files

```bash
# Create hostapd config
cat > /tmp/hostapd.conf <<EOF
interface=wlan0
driver=nl80211
ssid=Free_Public_WiFi
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF

# Create dnsmasq config
cat > /tmp/dnsmasq.conf <<EOF
interface=wlan0
dhcp-range=10.0.0.10,10.0.0.50,12h
dhcp-option=3,10.0.0.1
dhcp-option=6,10.0.0.1
address=/#/10.0.0.1
log-dhcp
EOF
```

### 2. Setup Network Interface

```bash
# Stop interfering services
sudo airmon-ng check kill
sudo pkill dnsmasq hostapd

# Configure interface
sudo ifconfig wlan0 down
sudo ifconfig wlan0 10.0.0.1 netmask 255.255.255.0 up
```

### 3. Configure iptables

```bash
# Flush existing rules
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X

# Enable IP forwarding
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

# Allow traffic TO portal
sudo iptables -A INPUT -i wlan0 -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -i wlan0 -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -i wlan0 -p udp --dport 53 -j ACCEPT
sudo iptables -A INPUT -i wlan0 -p tcp --dport 53 -j ACCEPT
sudo iptables -A INPUT -i wlan0 -p udp --dport 67:68 -j ACCEPT
sudo iptables -A OUTPUT -o wlan0 -j ACCEPT

# Redirect HTTP/HTTPS to portal
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 80 -j DNAT --to-destination 10.0.0.1:80
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 443 -j DNAT --to-destination 10.0.0.1:80
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 8080 -j DNAT --to-destination 10.0.0.1:80

# Redirect DNS
sudo iptables -t nat -A PREROUTING -i wlan0 -p udp --dport 53 -j DNAT --to-destination 10.0.0.1:53
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 53 -j DNAT --to-destination 10.0.0.1:53

# Create authenticated chain
sudo iptables -N AUTHENTICATED
sudo iptables -A FORWARD -i wlan0 -o eth0 -j AUTHENTICATED

# Enable NAT for authenticated users
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Allow return traffic
sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Block unauthenticated traffic
sudo iptables -A FORWARD -i wlan0 -o eth0 -j REJECT --reject-with icmp-host-prohibited
```

### 4. Start Services

```bash
# Start hostapd
sudo hostapd /tmp/hostapd.conf &
sleep 3

# Start dnsmasq
sudo dnsmasq -C /tmp/dnsmasq.conf &
sleep 2

# Start portal web server
sudo python3 portal_server.py
```

---

## All-in-One Setup Script

```bash
cat > setup_honeypot.sh <<'SCRIPT'
#!/bin/bash

echo "=== Starting WiFi Honeypot ==="

# Stop existing services
sudo airmon-ng check kill 2>/dev/null
sudo pkill dnsmasq hostapd
sleep 2

# Create hostapd config
cat > /tmp/hostapd.conf <<EOF
interface=wlan0
driver=nl80211
ssid=Free_Public_WiFi
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF

# Create dnsmasq config
cat > /tmp/dnsmasq.conf <<EOF
interface=wlan0
dhcp-range=10.0.0.10,10.0.0.50,12h
dhcp-option=3,10.0.0.1
dhcp-option=6,10.0.0.1
address=/#/10.0.0.1
log-dhcp
EOF

# Configure interface
sudo ifconfig wlan0 down
sudo ifconfig wlan0 10.0.0.1 netmask 255.255.255.0 up

# Start hostapd
echo "Starting hostapd..."
sudo hostapd /tmp/hostapd.conf &
sleep 3

# Start dnsmasq
echo "Starting dnsmasq..."
sudo dnsmasq -C /tmp/dnsmasq.conf &
sleep 2

# Configure iptables
echo "Configuring iptables..."
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X

echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward > /dev/null

sudo iptables -A INPUT -i wlan0 -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -i wlan0 -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -i wlan0 -p udp --dport 53 -j ACCEPT
sudo iptables -A INPUT -i wlan0 -p tcp --dport 53 -j ACCEPT
sudo iptables -A INPUT -i wlan0 -p udp --dport 67:68 -j ACCEPT
sudo iptables -A OUTPUT -o wlan0 -j ACCEPT

sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 80 -j DNAT --to-destination 10.0.0.1:80
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 443 -j DNAT --to-destination 10.0.0.1:80
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 8080 -j DNAT --to-destination 10.0.0.1:80
sudo iptables -t nat -A PREROUTING -i wlan0 -p udp --dport 53 -j DNAT --to-destination 10.0.0.1:53
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 53 -j DNAT --to-destination 10.0.0.1:53

sudo iptables -N AUTHENTICATED
sudo iptables -A FORWARD -i wlan0 -o eth0 -j AUTHENTICATED
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o eth0 -j REJECT --reject-with icmp-host-prohibited

echo ""
echo "=== Honeypot Ready ==="
echo "SSID: Free_Public_WiFi"
echo "Portal: http://10.0.0.1/"
echo ""
echo "Starting web server..."
sudo python3 portal_server.py
SCRIPT

chmod +x setup_honeypot.sh
```
---

```bash
# Flush old rules
sudo nft flush ruleset

# Create base table and chains
sudo nft add table inet filter
sudo nft add chain inet filter INPUT { type filter hook input priority 0 \; policy accept \; }
sudo nft add chain inet filter FORWARD { type filter hook forward priority 0 \; policy drop \; }
sudo nft add chain inet filter OUTPUT { type filter hook output priority 0 \; policy accept \; }

# Authenticated chain
sudo nft add chain inet filter AUTHENTICATED { type filter hook forward priority 0 \; }

# Allow forwarding from authenticated clients
sudo nft add rule inet filter FORWARD iif "wlan0" oif "eth0" jump AUTHENTICATED
sudo nft add rule inet filter FORWARD iif "eth0" oif "wlan0" ct state related,established accept

# Masquerade outgoing
sudo nft add table ip nat
sudo nft add chain ip nat POSTROUTING { type nat hook postrouting priority 100 \; }
sudo nft add rule ip nat POSTROUTING oif "eth0" masquerade

# Default reject for unauthenticated
sudo nft add rule inet filter FORWARD iif "wlan0" oif "eth0" reject with icmp host-prohibited

```

---
Perfect! Let’s break your captive portal setup into **iptables vs nftables** side by side. I’ll match the steps you’ve done with iptables to their nftables equivalents.

---

## **1️⃣ Flush existing rules**

**iptables:**

```bash
sudo iptables -F
sudo iptables -t nat -F
```

**nftables:**

```bash
sudo nft flush ruleset
```

> One command flushes all tables and chains, simpler than iptables’ separate tables.

---

## **2️⃣ Enable IP forwarding**

**Both systems use the same Linux kernel setting:**

```bash
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
```

---

## **3️⃣ NAT / Masquerade**

**iptables:**

```bash
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

**nftables:**

```bash
sudo nft add table ip nat
sudo nft 'add chain ip nat postrouting { type nat hook postrouting priority 100; }'
sudo nft add rule ip nat postrouting oifname "eth0" masquerade
```

> You explicitly define table → chain → hook → rule in nftables.

---

## **4️⃣ Forwarding rules**

**iptables:**

```bash
sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o eth0 -j REJECT --reject-with icmp-host-prohibited
```

**nftables:**

```bash
sudo nft add table ip filter
sudo nft 'add chain ip filter forward { type filter hook forward priority 0; policy drop; }'

# Allow established/related from eth0 → wlan0
sudo nft add rule ip filter forward iif "eth0" oif "wlan0" ct state related,established accept

# Reject other wlan0 → eth0 traffic by default
sudo nft add rule ip filter forward iif "wlan0" oif "eth0" reject with icmp type host-prohibited
```

> In nftables, you define a **default policy** for the chain (`policy drop` here), then allow exceptions.

---

## **5️⃣ Redirect all HTTP traffic to portal**

**iptables:**

```bash
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 80 -j DNAT --to-destination 10.0.0.1
```

**nftables:**

```bash
sudo nft add rule ip nat prerouting iif "wlan0" tcp dport 80 dnat to 10.0.0.1
```

> Same logic, syntax is shorter but requires table & chain setup first.

---

## **6️⃣ User-defined “authenticated” chain**

**iptables:**

```bash
sudo iptables -N AUTHENTICATED
sudo iptables -A FORWARD -i wlan0 -o eth0 -j AUTHENTICATED
```

**nftables:**

```bash
sudo nft add chain ip filter authenticated { type filter hook forward priority 1; }

# Jump traffic from wlan0 → eth0 through authenticated chain
sudo nft add rule ip filter forward iif "wlan0" oif "eth0" jump authenticated
```

> You still have a custom chain, but in nftables everything is tied to a table and chain explicitly.

---

✅ **Summary:**

* nftables = **table → chain → rule**, explicit and unified.
* iptables = simpler one-liners, separate tables (`filter`, `nat`, `mangle`).
* Conceptually they do the same thing, but nftables is more **structured** and consistent for IPv4/IPv6.

---

If you want, I can **write a complete nftables script for your captive portal setup** that mirrors exactly your iptables one. That way you can literally copy-paste it and it will work like your current setup.

Do you want me to do that?



---

## Python Portal Server

```bash
cat > portal_server.py <<'PYTHON'
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import subprocess
import json
import os

AUTH_FILE = '/tmp/authenticated_clients.json'

def load_authenticated():
    if os.path.exists(AUTH_FILE):
        with open(AUTH_FILE, 'r') as f:
            return json.load(f)
    return {}

def save_authenticated(data):
    with open(AUTH_FILE, 'w') as f:
        json.dump(data, f, indent=2)

def whitelist_client(ip):
    try:
        check_cmd = f"sudo iptables -L AUTHENTICATED -n | grep {ip}"
        result = subprocess.run(check_cmd, shell=True, capture_output=True)
        
        if result.returncode != 0:
            cmd = f"sudo iptables -I AUTHENTICATED -s {ip} -j ACCEPT"
            subprocess.run(cmd, shell=True, check=True)
            print(f"[AUTH] ✓ Whitelisted {ip}")
            return True
        return True
    except Exception as e:
        print(f"[AUTH] ✗ Failed: {e}")
        return False

class CaptivePortalHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        client_ip = self.client_address[0]
        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)
        
        print(f"[REQUEST] {client_ip} -> {self.path}")
        
        if parsed.path == '/login':
            name = params.get('name', [''])[0]
            email = params.get('email', [''])[0]
            
            if name and email:
                if whitelist_client(client_ip):
                    auth_data = load_authenticated()
                    auth_data[client_ip] = {'name': name, 'email': email}
                    save_authenticated(auth_data)
                    
                    self.send_response(200)
                    self.send_header('Content-type', 'text/html')
                    self.end_headers()
                    
                    success_html = f"""
                    <!DOCTYPE html>
                    <html>
                    <head>
                        <title>Connected!</title>
                        <meta http-equiv="refresh" content="3;url=http://google.com">
                        <style>
                            body {{
                                font-family: Arial, sans-serif;
                                text-align: center;
                                padding: 50px;
                                background: #4CAF50;
                                color: white;
                            }}
                            .success {{
                                background: white;
                                color: #4CAF50;
                                padding: 40px;
                                border-radius: 10px;
                                max-width: 400px;
                                margin: 0 auto;
                            }}
                            h1 {{ font-size: 48px; margin: 0; }}
                        </style>
                    </head>
                    <body>
                        <div class="success">
                            <h1>✓</h1>
                            <h2>Connected!</h2>
                            <p>Welcome, {name}</p>
                            <p>Redirecting...</p>
                        </div>
                    </body>
                    </html>
                    """
                    self.wfile.write(success_html.encode())
                    return
        
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        
        auth_count = len(load_authenticated())
        
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Free WiFi Portal</title>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body {{
                    font-family: Arial, sans-serif;
                    margin: 0;
                    padding: 20px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }}
                .portal {{
                    background: white;
                    padding: 40px;
                    border-radius: 15px;
                    box-shadow: 0 10px 40px rgba(0,0,0,0.2);
                    max-width: 400px;
                    width: 100%;
                }}
                h1 {{ color: #333; margin-top: 0; text-align: center; }}
                .subtitle {{ text-align: center; color: #666; margin-bottom: 30px; }}
                input {{
                    width: 100%;
                    padding: 12px;
                    margin: 10px 0;
                    border: 2px solid #e0e0e0;
                    border-radius: 8px;
                    box-sizing: border-box;
                    font-size: 14px;
                }}
                input:focus {{ outline: none; border-color: #667eea; }}
                button {{
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 14px 30px;
                    border: none;
                    border-radius: 8px;
                    cursor: pointer;
                    font-size: 16px;
                    font-weight: bold;
                    width: 100%;
                    margin-top: 10px;
                }}
                button:hover {{ transform: translateY(-2px); }}
                .info {{
                    margin-top: 30px;
                    padding-top: 20px;
                    border-top: 1px solid #e0e0e0;
                    font-size: 12px;
                    color: #999;
                    text-align: center;
                }}
            </style>
        </head>
        <body>
            <div class="portal">
                <h1>🌐 Free Public WiFi</h1>
                <p class="subtitle">Get online in seconds</p>
                
                <form action="/login" method="GET">
                    <input type="text" name="name" placeholder="Your Name" required>
                    <input type="email" name="email" placeholder="Email Address" required>
                    <button type="submit">🚀 Connect Now</button>
                </form>
                
                <div class="info">
                    <p>Your IP: <strong>{client_ip}</strong></p>
                    <p>Users online: <strong>{auth_count}</strong></p>
                </div>
            </div>
        </body>
        </html>
        """
        
        self.wfile.write(html.encode())
    
    def do_POST(self):
        self.do_GET()
    
    def log_message(self, format, *args):
        pass

if __name__ == '__main__':
    if not os.path.exists(AUTH_FILE):
        save_authenticated({})
    
    try:
        httpd = HTTPServer(('10.0.0.1', 80), CaptivePortalHandler)
        print(f"""
╔═══════════════════════════════════════╗
║   CAPTIVE PORTAL SERVER RUNNING       ║
╚═══════════════════════════════════════╝
Portal: http://10.0.0.1/
Auth log: {AUTH_FILE}
Press Ctrl+C to stop
        """)
        httpd.serve_forever()
    except PermissionError:
        print("❌ Need sudo: sudo python3 portal_server.py")
    except OSError as e:
        if "Address already in use" in str(e):
            print("❌ Port 80 in use: sudo pkill -f portal")
    except KeyboardInterrupt:
        print("\n✓ Server stopped")
PYTHON
```

---
### express version portal scripts
```js
// portal_server.js
import express from "express";
import fs from "fs";
import { execSync } from "child_process";
import path from "path";

const app = express();
const PORT = 80;
const AUTH_FILE = "/tmp/authenticated_clients.json";

// Load or create authenticated clients JSON
function loadAuthenticated() {
    if (fs.existsSync(AUTH_FILE)) {
        return JSON.parse(fs.readFileSync(AUTH_FILE));
    }
    return {};
}

function saveAuthenticated(data) {
    fs.writeFileSync(AUTH_FILE, JSON.stringify(data, null, 2));
}

// Whitelist a client IP in nftables
function whitelistClient(ip) {
    try {
        const check = execSync(`sudo nft list chain inet filter AUTHENTICATED | grep ${ip}`, { stdio: 'pipe' }).toString();
        if (!check) {
            execSync(`sudo nft insert rule inet filter AUTHENTICATED ip saddr ${ip} accept`);
            console.log(`[AUTH] ✓ Whitelisted ${ip}`);
        }
        return true;
    } catch (err) {
        console.log(`[AUTH] ✗ Failed: ${err}`);
        return false;
    }
}

// Serve the portal HTML
app.get("/", (req, res) => {
    const clientIP = req.ip.replace("::ffff:", "");
    const authCount = Object.keys(loadAuthenticated()).length;

    res.send(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>Free WiFi Portal</title>
        <style>
            body { font-family: Arial; text-align:center; padding:50px; background:#667eea; color:white;}
            input, button { padding:12px; margin:5px; border-radius:8px;}
        </style>
    </head>
    <body>
        <h1>🌐 Free WiFi</h1>
        <form action="/login" method="GET">
            <input type="text" name="name" placeholder="Your Name" required>
            <input type="email" name="email" placeholder="Email" required>
            <button type="submit">Connect</button>
        </form>
        <p>Your IP: ${clientIP}</p>
        <p>Users online: ${authCount}</p>
    </body>
    </html>
    `);
});

// Handle login and whitelist client
app.get("/login", (req, res) => {
    const clientIP = req.ip.replace("::ffff:", "");
    const { name, email } = req.query;

    if (name && email && whitelistClient(clientIP)) {
        const authData = loadAuthenticated();
        authData[clientIP] = { name, email };
        saveAuthenticated(authData);

        res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <title>Connected!</title>
            <meta http-equiv="refresh" content="3;url=http://google.com">
            <style>
                body { font-family: Arial; text-align:center; padding:50px; background:#4CAF50; color:white; }
            </style>
        </head>
        <body>
            <h1>✓ Connected!</h1>
            <p>Welcome, ${name}</p>
            <p>Redirecting...</p>
        </body>
        </html>
        `);
    } else {
        res.redirect("/");
    }
});

app.listen(PORT, () => console.log(`Captive portal running at http://10.0.0.1/`));

```

## Management Commands

### Start Everything
```bash
sudo ./setup_honeypot.sh
```

### Check Status
```bash
# Check services
pgrep hostapd && echo "hostapd: ✓" || echo "hostapd: ✗"
pgrep dnsmasq && echo "dnsmasq: ✓" || echo "dnsmasq: ✗"
sudo netstat -tulpn | grep :80 && echo "portal: ✓" || echo "portal: ✗"

# Check connected clients
cat /var/lib/misc/dnsmasq.leases

# Check authenticated clients
cat /tmp/authenticated_clients.json

# Check iptables rules
sudo iptables -L AUTHENTICATED -n -v
```

### View Logs
```bash
# View authenticated users
cat /tmp/authenticated_clients.json | jq

# Watch live connections
sudo tcpdump -i wlan0 -n port 80

# Watch iptables hits
watch -n1 'sudo iptables -L AUTHENTICATED -n -v'
```

### Manually Whitelist IP
```bash
sudo iptables -I AUTHENTICATED -s 10.0.0.35 -j ACCEPT
```

### Remove Whitelisted IP
```bash
sudo iptables -D AUTHENTICATED -s 10.0.0.35 -j ACCEPT
```

### Stop Everything
```bash
# Kill services
sudo pkill hostapd dnsmasq
sudo pkill -f "python.*portal"

# Clean up
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -X

# Restart normal networking
sudo systemctl start NetworkManager

# Reset interface
sudo ip link set wlan0 down
sudo iw dev wlan0 set type managed
sudo ip link set wlan0 up
```

---

## Debugging Commands

### Test DNS Hijacking
```bash
# From gateway
dig @10.0.0.1 google.com

# Should return 10.0.0.1
```

### Test HTTP Redirect
```bash
# From connected client
curl -v http://example.com

# Should connect to 10.0.0.1:80
```

### Monitor Traffic
```bash
# All traffic on wlan0
sudo tcpdump -i wlan0 -n

# Only HTTP traffic
sudo tcpdump -i wlan0 -n port 80

# Only DNS traffic
sudo tcpdump -i wlan0 -n port 53
```

### Check iptables Hit Counters
```bash
# See which rules are being hit
sudo iptables -t nat -L -n -v | grep DNAT
sudo iptables -L FORWARD -n -v
```

### Debug dnsmasq
```bash
# Stop dnsmasq
sudo pkill dnsmasq

# Run in debug mode
sudo dnsmasq -C /tmp/dnsmasq.conf -d --log-queries

# Ctrl+C to stop
```

### Debug hostapd
```bash
# Stop hostapd
sudo pkill hostapd

# Run in foreground
sudo hostapd /tmp/hostapd.conf

# Ctrl+C to stop
```

---

## Architecture Explained

### Component Stack
```
[Client Device]
      ↓
[hostapd] ← Creates WiFi AP "Free_Public_WiFi"
      ↓
[dnsmasq] ← Assigns IPs (DHCP) + Hijacks DNS
      ↓
[iptables] ← Redirects HTTP/HTTPS → Portal
      ↓
[Python Server] ← Serves portal + Authenticates
      ↓
[Internet via eth0] ← After authentication
```

### Traffic Flow
```
1. Client connects to "Free_Public_WiFi"
   → hostapd accepts connection

2. Client requests IP via DHCP
   → dnsmasq assigns 10.0.0.35

3. Client browses to google.com
   → dnsmasq DNS: "google.com = 10.0.0.1"
   → iptables NAT: redirect to portal
   → Python server: serves login page

4. Client submits form
   → Python executes: iptables -I AUTHENTICATED -s 10.0.0.35 -j ACCEPT
   → Client now has internet access

5. Client browses google.com again
   → iptables checks AUTHENTICATED chain
   → Match found: ACCEPT
   → MASQUERADE and forward to internet
```

### iptables Chain Order
```
PREROUTING (nat)
  ↓ DNAT HTTP/HTTPS → 10.0.0.1:80
  ↓ DNAT DNS → 10.0.0.1:53
  ↓
INPUT
  ↓ ACCEPT port 80, 53, 67-68
  ↓
FORWARD
  ↓ Check AUTHENTICATED chain
  ↓ If match → ACCEPT
  ↓ If no match → REJECT
  ↓
POSTROUTING (nat)
  ↓ MASQUERADE → eth0
```

---

## Common Issues

### "WiFi network not visible"
```bash
# Check hostapd is running
sudo hostapd /tmp/hostapd.conf

# If error "nl80211: Could not configure driver mode"
# Your WiFi adapter doesn't support AP mode
# Solution: Use different adapter (Alfa AWUS036NHA recommended)
```

### "Clients connect but no internet"
```bash
# Check IP forwarding
cat /proc/sys/net/ipv4/ip_forward
# Should be "1"

# Check eth0 has internet
ping -I eth0 8.8.8.8

# Check MASQUERADE rule exists
sudo iptables -t nat -L POSTROUTING -n
```

### "No redirect to portal"
```bash
# Check web server is running
sudo netstat -tulpn | grep :80

# Check iptables DNAT rules
sudo iptables -t nat -L PREROUTING -n -v

# Check if rules are being hit (pkts column)
# If pkts = 0, rules not working
```

### "DNS not hijacking"
```bash
# Check dnsmasq config has: address=/#/10.0.0.1
cat /tmp/dnsmasq.conf

# Test DNS manually
dig @10.0.0.1 google.com
# Should return 10.0.0.1

# Check DNS redirect in iptables
sudo iptables -t nat -L PREROUTING -n | grep 53
```

---

## Security & Legal

⚠️ **WARNING: Educational purposes only!**

### Legal Considerations
- Only use on networks you own
- Never deploy in public spaces
- Get written permission for penetration testing
- Intercepting traffic may violate wiretapping laws

### Detection Methods
Users can detect your honeypot via:
- Certificate warnings (HTTPS)
- All domains resolve to same IP
- Network tools (traceroute shows 1 hop)
- OS captive portal detection

### Ethical Usage
```python
# Add disclaimer to portal page
<div class="warning">
  ⚠️ SECURITY RESEARCH HONEYPOT
  This network is monitored for educational purposes.
  Do not enter real credentials.
</div>
```

---

## Advanced Features

### Log More Data
```python
# In portal_server.py, modify authentication handler
auth_data[client_ip] = {
    'name': name,
    'email': email,
    'timestamp': time.time(),
    'user_agent': self.headers.get('User-Agent'),
    'referer': self.headers.get('Referer'),
    'requested_url': self.path
}
```

### Auto-Expire Sessions
```bash
# Add to crontab: expire after 1 hour
echo "0 * * * * /usr/local/bin/expire_sessions.sh" | crontab -

# Create expire_sessions.sh
cat > /usr/local/bin/expire_sessions.sh <<'EOF'
#!/bin/bash
# Remove all authenticated IPs older than 1 hour
sudo iptables -F AUTHENTICATED
rm -f /tmp/authenticated_clients.json
EOF
chmod +x /usr/local/bin/expire_sessions.sh
```

### Packet Capture
```bash
# Log all traffic to pcap file
sudo tcpdump -i wlan0 -w /tmp/honeypot_$(date +%Y%m%d_%H%M%S).pcap
```

### Bandwidth Throttling
```bash
# Limit clients to 1Mbps
sudo tc qdisc add dev wlan0 root tbf rate 1mbit burst 32kbit latency 400ms
```

---

## References

- hostapd: https://w1.fi/hostapd/
- dnsmasq: http://www.thekelleys.org.uk/dnsmasq/doc.html
- iptables: https://netfilter.org/
- Python http.server: https://docs.python.org/3/library/http.server.html
