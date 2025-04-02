#!/bin/sh

DIR=$(dirname "$0")
BASE_PATH="/mnt/SDCARD/Tools/$PLATFORM" 

export LED_MODULE_PATH="/mnt/SDCARD/Tools/tg5040/LEDs"

. "$LED_MODULE_PATH/scripts.disabled/common.sh"
. "$LED_MODULE_PATH/scripts.disabled/lib/led_update.sh"

LED_SETTINGS_FILE="$LED_MODULE_PATH/scripts.disabled/config/led.conf"

load_settings
reset_effects
reset_animations
reset_brightness

if [ "$effect_enabled" = "1" ] || [ "$animation_enabled" = "1" ]; then
    update_leds
    configure_enabled_folders
else
    apply_standby_color "$standby_color"
    configure_disabled_folders
fi

if [ "$low_batt_ind" = "1" ]; then
    # Kill any existing battery monitoring processes that might be left over
    killall batt_mon 2>/dev/null
    killall low_batt_led 2>/dev/null
    
    # Use the existing DEVICE environment variable to determine device type
    if [ "$DEVICE" = "brick" ]; then
        DEVICE_TYPE="brick"
    else
        DEVICE_TYPE="tsp"
    fi
    
    # Get current battery level
    CURRENT_BATT=$(cat /sys/class/power_supply/axp2202-battery/capacity 2>/dev/null || echo 100)
    
    # Check if battery is below threshold and start monitor if needed
    if [ "$CURRENT_BATT" -lt "$low_batt_threshold" ]; then
        # Battery is already low, start the low battery LED script directly
        "$LOW_BATT_LED_SCRIPT" "$DEVICE_TYPE" &
    else
        # Battery is above threshold, start the monitor
        "$BATT_MON" "$low_batt_threshold" "$LOW_BATT_LED_SCRIPT" "$DEVICE_TYPE" &
    fi
    
    # Update folder names
    enabledisable_rename "$LED_MODULE_PATH/9) Tools/1) Low Battery Indicator/Enable.pak" "enable"
else
    # Low battery indicator is disabled
    killall batt_mon 2>/dev/null
    killall low_batt_led 2>/dev/null
    enabledisable_rename "$LED_MODULE_PATH/9) Tools/1) Low Battery Indicator/Disable.pak" "disable"
fi