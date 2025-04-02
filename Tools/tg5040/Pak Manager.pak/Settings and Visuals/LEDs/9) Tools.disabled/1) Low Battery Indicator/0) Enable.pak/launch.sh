#!/bin/sh

DIR=$(dirname "$0")
. "$DIR/../../../scripts.disabled/common.sh"
. "$DIR/../../../scripts.disabled/lib/led_update.sh"


load_settings

if [ "$low_batt_ind" = "0" ]; then
    killall batt_mon 2>/dev/null
    killall low_batt_led 2>/dev/null
    "$BATT_MON" "$low_batt_threshold" "$LOW_BATT_LED_SCRIPT" &
    low_batt_ind=1
    save_settings
    enabledisable_rename "$DIR" "enable"
else
    killall batt_mon 2>/dev/null
    killall low_batt_led 2>/dev/null
    low_batt_ind=0
    save_settings
    enabledisable_rename "$DIR" "disable"
    if [ "$effect_enabled" = "0" ] && [ "$animation_enabled" = "0" ]; then
        reset_effects
        reset_brightness
    fi
fi