#!/bin/bash

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

# EtherCAT kontrolü ve Docker başlatma
if ! systemctl is-active --quiet ethercat; then
  echo '🚀 Starting EtherCAT...'
  sudo systemctl start ethercat
  sleep 2
fi

echo "🔍 Checking for tmux session '$SESSION_NAME'..."
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "🛑 Killing tmux session '$SESSION_NAME'..."
    tmux kill-session -t "$SESSION_NAME"
    echo "✅ tmux session killed."
    echo "📦 Stopping Docker container 'beautiful_bartik'..."
    docker stop beautiful_bartik
else
    echo "ℹ️ tmux session '$SESSION_NAME' not found."
fi

echo "🚀 Starting Air control system..."
docker start beautiful_bartik

# Session yoksa oluştur
tmux new-session -d -s "$SESSION_NAME" -n "control"
tmux send-keys -t "$SESSION_NAME:0" 'docker exec -it beautiful_bartik bash -c "
  source /opt/ros/humble/setup.sh && \
  source /root/nav2_ws/install/setup.sh && \
  ros2 launch ethercat_diff_drive air_control.py
"' C-m
echo "Created 'control' window"

tmux new-window -t "$SESSION_NAME" -n "foxglove"
tmux send-keys -t "$SESSION_NAME:1" 'docker exec -it beautiful_bartik bash -c "
  source /opt/ros/humble/setup.sh && \
  source /root/nav2_ws/install/setup.sh && \
  ros2 launch foxglove_bridge foxglove_bridge_launch.xml
"' C-m
echo "Created 'foxglove' window"



EOF
