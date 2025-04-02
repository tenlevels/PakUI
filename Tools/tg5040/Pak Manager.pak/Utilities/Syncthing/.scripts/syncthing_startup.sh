#!/bin/sh

DIR=$(dirname "$0")
MODULE_PATH="$(dirname "$DIR")"

. "$MODULE_PATH/.scripts/common.sh"

CONFIG_PATH="$MODULE_PATH/.config"
CONFIG_FILE="$CONFIG_PATH/config.xml"

STARTUP_MARKER_FILE="$CONFIG_PATH/start_syncthing"

if [ -f "$STARTUP_MARKER_FILE" ]; then
    nice -2 $SYNCTHING serve --no-browser --no-restart --no-upgrade --gui-address="0.0.0.0:8384" --home="$CONFIG_PATH" &
    sleep 1
    touch "$CONFIG_PATH/syncthing_running"
    mv "$MODULE_PATH/Enable at Startup.pak" "$MODULE_PATH/Disable at Startup.pak"
    mv "$MODULE_PATH/0) Enable.pak" "$MODULE_PATH/0) Disable.pak"
else
    rm "$CONFIG_PATH/syncthing_running"
    mv "$MODULE_PATH/Disable at Startup.pak" "$MODULE_PATH/Enable at Startup.pak"
    mv "$MODULE_PATH/0) Disable.pak" "$MODULE_PATH/0) Enable.pak"
fi