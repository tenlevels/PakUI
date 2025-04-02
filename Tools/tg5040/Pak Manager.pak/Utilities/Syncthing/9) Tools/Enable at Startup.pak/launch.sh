#!/bin/sh

DIR="$(dirname "$0")"
TOOLS_PATH="$(dirname "$DIR")"
MODULE_PATH="$(dirname "$TOOLS_PATH")"

. "$MODULE_PATH/.scripts/common.sh"

CONFIG_PATH="$MODULE_PATH/.config"
CONFIG_FILE="$CONFIG_PATH/config.xml"

STARTUP_MARKER_FILE="$CONFIG_PATH/start_syncthing"

if [ -f "$STARTUP_MARKER_FILE" ]; then
    rm "$STARTUP_MARKER_FILE"
    mv "$DIR" "$TOOLS_PATH/Enable at Startup.pak"
else
    touch "$STARTUP_MARKER_FILE"
    mv "$DIR" "$TOOLS_PATH/Disable at Startup.pak"
    display_message "Syncthing will run even if there is no WiFi" 4
fi