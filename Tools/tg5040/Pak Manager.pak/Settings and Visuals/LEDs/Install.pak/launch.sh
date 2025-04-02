#!/bin/sh
PAK_PATH=$(dirname "$0")
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




mv "$PAK_PATH" "$PAK_PATH.disabled"


