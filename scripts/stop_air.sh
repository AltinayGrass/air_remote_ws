#!/bin/bash

# SSH connection info
REMOTE_USER=rnd
REMOTE_HOST=10.42.0.1

WIFI_SSID="air"   # Bağlı olunması gereken Wi-Fi ağı

# 1. (İsteğe Bağlı) Wi-Fi SSID kontrolü
SSID_MATCHED=false

for iface in $(ls /sys/class/net/ | grep '^wl'); do
    SSID=$(iw dev $iface link | grep SSID | awk '{print $2}')
    if [ "$SSID" == "$WIFI_SSID" ]; then
        echo "✅ Connected to '$WIFI_SSID' via interface: $iface"
        SSID_MATCHED=true
        break
    fi
done

if [ "$SSID_MATCHED" != true ]; then
    echo "❌ Not connected to '$WIFI_SSID' on any Wi-Fi interface."
    exit 1
fi
# 2. Ping testi
ping -c 1 -W 1 $REMOTE_HOST > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "❌ Cannot reach $REMOTE_HOST. Check your connection."
  exit 1
else
  echo "✅ Host $REMOTE_HOST is reachable. Proceeding..."
fi
ssh -t ${REMOTE_USER}@${REMOTE_HOST} << "EOF"

SESSION_NAME="robot"

echo "🔍 Checking for tmux session '$SESSION_NAME'..."
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "🛑 Killing tmux session '$SESSION_NAME'..."
    tmux kill-session -t "$SESSION_NAME"
    echo "✅ tmux session killed."
else
    echo "ℹ️ tmux session '$SESSION_NAME' not found."
fi

echo "📦 Stopping Docker container 'beautiful_bartik'..."
docker stop beautiful_bartik

# Optional: stop EtherCAT if needed
# echo "🛑 Stopping EtherCAT service..."
# sudo systemctl stop ethercat

echo "🧹 Shutdown sequence completed."

EOF
