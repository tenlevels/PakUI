#!/bin/sh


export LD_LIBRARY_PATH=/usr/trimui/lib:$LD_LIBRARY_PATH
DISPLAY_BASE_PATH="/sys/class/disp/disp/attr"
AUTO_PATH="/mnt/SDCARD/.userdata/$PLATFORM/auto.sh"
cd $(dirname "$0")

rm -f display_settings.conf
./display minui.ttf

if [ -f display_settings.conf ]; then
    sed -i '/enhance_bright\|enhance_contrast\|enhance_saturation\|color_temperature/d' "$AUTO_PATH"

    while IFS='=' read -r setting value; do
        echo "echo $value > \"$DISPLAY_BASE_PATH/$setting\"" >> "$AUTO_PATH"
    done < display_settings.conf

    rm -f display_settings.conf
fi