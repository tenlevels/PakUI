#!/bin/sh

DIR=$(dirname "$0")
MODULE_PATH="$(dirname "$DIR")"

AUTO_PATH="/mnt/SDCARD/.userdata/$PLATFORM/auto.sh"
STARTUP_SCRIPT="$MODULE_PATH/.scripts/syncthing_startup.sh"

SYNCUSER=minui
SYNCPASS=minuipassword

if [ -z $DEVICE ]; then
  DEVICE="tsp"
fi
DEVICE_NAME="minui-$DEVICE"

CONFIG_PATH="$MODULE_PATH/.config"
CONFIG_FILE="$CONFIG_PATH/config.xml"

. "$MODULE_PATH/.scripts/common.sh"

if [ -f "$CONFIG_PATH/syncthing_running" ]; then
  pkill $SYNCTHING
  rm "$CONFIG_PATH/syncthing_running"
  mv "$DIR" "$MODULE_PATH/0) Enable.pak"
else
  display_message "Starting Syncthing"

  pkill $SYNCTHING

  # wifi check
  if [ "$(cat /sys/class/net/wlan0/operstate)" = "up" ]; then
    echo "WiFI on, checking IP"
    ip_addr=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    if [ -z $ip_addr ]; then
      display_message "Please check WiFi connection" 3
      exit 1      
    fi
  else
    display_message "Wifi not enabled" 3
    exit 1      
  fi

  if ! [ -f $CONFIG_FILE ]; then
    mkdir -p "$CONFIG_PATH"
    $SYNCTHING generate --no-default-folder --gui-user="$SYNCUSER" --gui-password="$SYNCPASS" --home="$CONFIG_PATH"
    sync
    sleep 2

    $XMLSTARLET ed --inplace -u "//options/urAccepted" -v "-1" "$CONFIG_FILE"
    $XMLSTARLET ed --inplace -u "//device/@name" -v "$DEVICE_NAME" "$CONFIG_FILE"
    sync

  fi

  nice -2 $SYNCTHING serve --no-browser --no-restart --no-upgrade --gui-address="0.0.0.0:8384" --home="$CONFIG_PATH" &
  sleep 1

  display_message "Syncthing started" 2
  display_message "IP Address: $ip_addr" 7

  touch "$CONFIG_PATH/syncthing_running"
  mv "$DIR" "$MODULE_PATH/0) Disable.pak"
fi

# add startup script to system auto.sh
sed -i '/syncthing_startup.sh/d' "$AUTO_PATH"

echo "\"$STARTUP_SCRIPT\" &" >> "$AUTO_PATH"
if [ $? -eq 0 ]; then
    echo "Successfully added startup script to auto.sh"
else
    echo "Error: Failed to add startup script to auto.sh"
    exit 1
fi