#!/bin/sh
DIR=$(dirname "$0")
. "$DIR/../../../../scripts.disabled/common.sh"
. "$DIR/../../../../scripts.disabled/lib/led_update.sh"

# Load current settings
load_settings

# Set your desired threshold
low_batt_threshold="5"

# Use the existing DEVICE environment variable
if [ "$DEVICE" = "brick" ]; then
    DEVICE_TYPE="brick"
else
    DEVICE_TYPE="tsp"
fi
echo "Device type: $DEVICE_TYPE"

# Save the new threshold
save_settings

if [ "$low_batt_ind" = "1" ]; then
    # Kill any existing battery monitoring processes
    killall batt_mon 2>/dev/null
    killall low_batt_led 2>/dev/null
    
    # Get current battery level
    CURRENT_BATT=$(cat /sys/class/power_supply/axp2202-battery/capacity 2>/dev/null || echo 100)
    
    # Only reset effects if battery is below threshold
    if [ "$CURRENT_BATT" -le "$low_batt_threshold" ]; then
        reset_effects
        reset_brightness
    fi
    
    # Start the battery monitor with the correct device type
    "$BATT_MON" "$low_batt_threshold" "$LOW_BATT_LED_SCRIPT" "$DEVICE_TYPE" &
    
    echo "Low battery threshold set to $low_batt_threshold% for $DEVICE_TYPE"
else
    # Low battery indicator is disabled, clean up any running processes
    killall batt_mon 2>/dev/null
    killall low_batt_led 2>/dev/null
    
    echo "Low battery indicator is disabled"
fi