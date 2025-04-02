#!/bin/sh
PAK_PATH=$(dirname "$0")
MODULE_PATH=$(readlink -f "$PAK_PATH/../..")

echo "Running uninstall..."
# First run your exact uninstall script
PAK_PATH=$(dirname "$0")
MODULE_PATH=$(readlink -f "$PAK_PATH/../..")
AUTO_PATH="/mnt/SDCARD/.userdata/$PLATFORM/auto.sh"
. "$MODULE_PATH/scripts.disabled/common.sh"
. "$MODULE_PATH/scripts.disabled/lib/led_update.sh"
load_settings
effect_enabled="0"
animation_enabled="0"
reset_animations
reset_effects
reset_brightness
apply_standby_color "00FF33"
# hide everything, unhide install pak
configure_disabled_folders
showhide_folder "$LED_MODULE_PATH/0) Enable.pak/" "disable"
showhide_folder "$LED_MODULE_PATH/0) Disable.pak/" "disable"
showhide_folder "$LED_MODULE_PATH/Install.pak.disabled/" "enable"
showhide_folder "$LED_MODULE_PATH/9) Tools/" "disable"
# remove led startup script to system auto.sh
sed -i '/led_startup.sh/d' "$AUTO_PATH"
rm "$MODULE_PATH/scripts.disabled/config/led.conf"

echo "Running install..."
# Then run your exact install script
PAK_PATH="$MODULE_PATH/Install.pak"
PAK_NAME=$(basename "$PAK_PATH")
MODULE_PATH=$(dirname "$PAK_PATH")
AUTO_PATH="/mnt/SDCARD/.userdata/$PLATFORM/auto.sh"
STARTUP_SCRIPT="$MODULE_PATH/scripts.disabled/led_startup.sh"
SHARED_SCRIPT="$MODULE_PATH/scripts.disabled/common.sh"
# add led startup script to system auto.sh
sed -i '/led_startup.sh/d' "$AUTO_PATH"
echo "\"$STARTUP_SCRIPT\"" >> "$AUTO_PATH"
if [ $? -eq 0 ]; then
    echo "Successfully added startup script to auto.sh"
else
    echo "Error: Failed to add startup script to auto.sh"
    exit 1
fi
# update led shared script with module path
sed -i "s|export LED_MODULE_PATH=.*|export LED_MODULE_PATH=\"$MODULE_PATH\"|g" "$SHARED_SCRIPT"
if ! grep -q "export LED_MODULE_PATH=\"$MODULE_PATH\"" "$SHARED_SCRIPT"; then
    echo "Error: Failed to update LED_MODULE_PATH"
    exit 1
fi
# update led startup script with module path
sed -i "s|export LED_MODULE_PATH=.*|export LED_MODULE_PATH=\"$MODULE_PATH\"|g" "$STARTUP_SCRIPT"
if ! grep -q "export LED_MODULE_PATH=\"$MODULE_PATH\"" "$STARTUP_SCRIPT"; then
    echo "Error: Failed to update LED_MODULE_PATH"
    exit 1
fi
mv "$MODULE_PATH/0) Enable.pak.disabled" "$MODULE_PATH/0) Enable.pak" 
mv "$MODULE_PATH/9) Tools.disabled" "$MODULE_PATH/9) Tools"
if [ "$DEVICE" != "brick" ]; then
    mv "$MODULE_PATH/9) Tools/0) Standby Color" "$MODULE_PATH/9) Tools/0) Standby Color.disabled"
fi
touch "$MODULE_PATH/scripts.disabled/config/led.conf"
# run startup script
"$STARTUP_SCRIPT"
"$MODULE_PATH/0) Enable.pak/launch.sh"

echo "Uninstall and install completed."