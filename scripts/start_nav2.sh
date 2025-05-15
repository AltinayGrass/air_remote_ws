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

# Check required windows
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "❌ tmux session '$SESSION_NAME' not found. Please run control_only.sh first."
  exit 1
fi

# Check if 'control' window exists
tmux list-windows -t "$SESSION_NAME" | grep -q "control"
if [ $? -ne 0 ]; then
  echo "❌ 'control' window not found. Please run start_control.sh first."
  exit 1
fi

# Check if 'foxglove' window exists
tmux list-windows -t "$SESSION_NAME" | grep -q "foxglove"
if [ $? -ne 0 ]; then
  echo "❌ 'foxglove' window not found. Please run start_control.sh first."
  exit 1
fi

# Check if 'camera' window exists
tmux list-windows -t "$SESSION_NAME" | grep -q "camera"
if [ $? -ne 0 ]; then
  echo "❌ 'camera' window not found. Please run start_camera.sh first."
  exit 1
fi

echo "🚀 Starting Air Nav2 system..."

# Create and start 'nav2' window
tmux new-window -t "$SESSION_NAME" -n "nav2"
tmux send-keys -t "$SESSION_NAME:3" 'docker exec -it beautiful_bartik bash -c "
  source /opt/ros/humble/setup.sh && \
  source /root/nav2_ws/install/setup.sh && \
  ros2 launch ethercat_diff_drive air_nav2.py
"' C-m

echo "✅ Nav2 launched successfully."

EOF
