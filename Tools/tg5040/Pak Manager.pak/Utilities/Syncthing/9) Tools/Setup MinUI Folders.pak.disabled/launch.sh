#!/bin/sh

DIR="$(dirname "$0")"
TOOLS_PATH="$(dirname "$DIR")"
MODULE_PATH="$(dirname "$TOOLS_PATH")"

CONFIG_PATH="$MODULE_PATH/.config"
CONFIG_FILE="$CONFIG_PATH/config.xml"

API_KEY=$(sed -n 's/.*<apikey>\(.*\)<\/apikey>.*/\1/p' "$CONFIG_FILE")

. "$MODULE_PATH/.scripts/common.sh"

if ! pidof syncthing >/dev/null; then
    display_message "Ensure Syncthing is Running" 3
    exit 1
fi

DEVICE_ID=$(curl -s -H "X-API-Key: $API_KEY" \
    "http://localhost:8384/rest/system/status" | \
    grep -o '"myID":"[^"]*"' | cut -d'"' -f4)

SAVES_FOLDER="/mnt/SDCARD/Saves"
if ! check_folder_exists "$SAVES_FOLDER"; then
    SAVES_LABEL="MinUI Saves"
    SAVES_FOLDER_ID="MINUI-SAVES"
    add_folder "$SAVES_FOLDER_ID" "$SAVES_LABEL" "$SAVES_FOLDER" "$DEVICE_ID"
fi

STATES_FOLDER="/mnt/SDCARD/.userdata/shared"
if ! check_folder_exists "$FOLDER"; then
    STATES_LABEL="MinUI States"
    SAVES_FOLDER_ID="MINUI-STATES"
    add_folder "$SAVES_FOLDER_ID" "$STATES_LABEL" "$STATES_FOLDER" "$DEVICE_ID"
fi
