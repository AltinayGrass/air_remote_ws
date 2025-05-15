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
WINDOW_NAME="dock_undock"

# Eğer pencere yoksa oluştur
if ! tmux list-windows -t "$SESSION_NAME" | grep -q "$WINDOW_NAME"; then
  echo "🚀 Creating new tmux window: $WINDOW_NAME"
  tmux new-window -t "$SESSION_NAME" -n "$WINDOW_NAME"
else
  echo "ℹ️ Reusing existing tmux window: $WINDOW_NAME"
fi

tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME" 'docker exec -it beautiful_bartik bash -c "
  source /opt/ros/humble/setup.sh && \
  source /root/nav2_ws/install/setup.sh && \
  ros2 action send_goal /undock_robot opennav_docking_msgs/action/UndockRobot \"{dock_type: '\''simple_charging_dock'\'', max_undocking_time: 30.0}\"
"' C-m

echo "ℹ️ Undocking started with:"
echo "ℹ️ ros2 action send_goal /undock_robot opennav_docking_msgs/action/UndockRobot \"{dock_type: 'simple_charging_dock', max_undocking_time: 30.0}\""

EOF
