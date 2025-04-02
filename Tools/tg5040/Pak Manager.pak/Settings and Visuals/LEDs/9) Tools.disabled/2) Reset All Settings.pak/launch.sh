#!/bin/sh
PAK_PATH=$(dirname "$0")
MODULE_PATH=$(readlink -f "$PAK_PATH/../..")
. "$MODULE_PATH/scripts.disabled/common.sh"
. "$MODULE_PATH/scripts.disabled/lib/led_update.sh"

# Remove existing config
rm -f "$MODULE_PATH/scripts.disabled/config/led.conf"

# Load defaults
load_settings

# Force enable settings
effect_enabled="1"
animation_enabled="0"
save_settings

# Apply settings
reset_effects  # First clear current state
reset_animations
reset_brightness
update_leds
configure_enabled_folders

# Make sure folders show correct state
if [ -d "$MODULE_PATH/0) Enable.pak" ]; then
    mv "$MODULE_PATH/0) Enable.pak" "$MODULE_PATH/0) Disable.pak"
fi

echo "LED effects have been enabled with default settings"