#!/bin/sh

PAK_PATH=$(dirname "$0")
PAK_NAME=$(basename "$PAK_PATH")
MODULE_PATH=$(dirname "$PAK_PATH")

. "$MODULE_PATH/scripts.disabled/common.sh"
. "$MODULE_PATH/scripts.disabled/lib/led_update.sh"

load_settings

if [ "$effect_enabled" = "0" ] && [ "$animation_enabled" = "0" ]; then
	update_leds
    configure_enabled_folders
else
    echo "disable"
    effect_enabled="0"
    animation_enabled="0"
	save_settings
    reset_effects
    reset_animations
    reset_brightness
	apply_standby_color "$standby_color"
    configure_disabled_folders
fi
