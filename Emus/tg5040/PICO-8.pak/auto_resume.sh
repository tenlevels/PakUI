#!/bin/sh
AUTO_SH="/mnt/SDCARD/.userdata/$PLATFORM/auto.sh"
if [ -f "$AUTO_SH" ]; then
    sed -i "\|$0|d" "$AUTO_SH"
fi
ROM_PATH="splore"
if [ "$ROM_PATH" = "splore" ]; then
    echo "Launching PICO-8 in Splore mode"
    if [ -d "/mnt/SDCARD/Emus/$PLATFORM/PICO-8.pak" ]; then
        EMULATOR="/mnt/SDCARD/Emus/$PLATFORM/PICO-8.pak/launch.sh"
        "$EMULATOR" "splore"
        exit 0
    fi
fi
CURRENT_PATH=$(dirname "$ROM_PATH")
ROM_FOLDER_NAME=$(basename "$CURRENT_PATH")
ROM_PLATFORM=""
while [ -z "$ROM_PLATFORM" ]; do
    if [ "$ROM_FOLDER_NAME" = "Roms" ]; then
        ROM_PLATFORM="UNK"
        echo "Error: Could not determine platform"
        exit 1
    fi
    ROM_PLATFORM=$(echo "$ROM_FOLDER_NAME" | sed -n 's/.*(\(.*\)).*/\1/p')
    if [ -z "$ROM_PLATFORM" ]; then
        CURRENT_PATH=$(dirname "$CURRENT_PATH")
        ROM_FOLDER_NAME=$(basename "$CURRENT_PATH")
    fi
done
echo "Launching game on platform: $ROM_PLATFORM"
export LD_LIBRARY_PATH=/usr/trimui/lib:$LD_LIBRARY_PATH
if [ -d "/mnt/SDCARD/Emus/$PLATFORM/$ROM_PLATFORM.pak" ]; then
    EMULATOR="/mnt/SDCARD/Emus/$PLATFORM/$ROM_PLATFORM.pak/launch.sh"
    "$EMULATOR" "$ROM_PATH"
elif [ -d "/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$ROM_PLATFORM.pak" ]; then
    EMULATOR="/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$ROM_PLATFORM.pak/launch.sh"
    "$EMULATOR" "$ROM_PATH"
elif [ -d "/mnt/SDCARD/Emus/$ROM_PLATFORM.pak" ]; then
    EMULATOR="/mnt/SDCARD/Emus/$ROM_PLATFORM.pak/launch.sh"
    "$EMULATOR" "$ROM_PATH"
elif [ -d "/mnt/SDCARD/.system/paks/Emus/$ROM_PLATFORM.pak" ]; then
    EMULATOR="/mnt/SDCARD/.system/paks/Emus/$ROM_PLATFORM.pak/launch.sh"
    "$EMULATOR" "$ROM_PATH"
else
    echo "Error: Emulator not found for platform $ROM_PLATFORM"
    exit 1
fi
