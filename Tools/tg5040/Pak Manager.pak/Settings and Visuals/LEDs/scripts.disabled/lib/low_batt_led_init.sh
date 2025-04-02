#!/bin/sh
DIR=$(dirname "$0")
SCRIPTS_PATH=$(dirname "$DIR")

. "$SCRIPTS_PATH/common.sh"
. "$SCRIPTS_PATH/lib/led_update.sh"

LOW_BATT_LED="$SCRIPTS_PATH/bin/low_batt_led"  # Your long-running LED program

killall low_batt_led 2>/dev/null

load_settings
effect_enabled="0"
animation_enabled="0"
save_settings
reset_animations
reset_effects
reset_brightness
configure_disabled_folders

if [ "$DEVICE" != "brick" ]; then
    DEVICE="tsp"
fi
# Hand off to the LED program
$LOW_BATT_LED "$DEVICE" &