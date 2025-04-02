#!/bin/sh
# HEADER
UPDATE_DIR="/mnt/SDCARD/System/updates/$(basename "$0" | cut -d'.' -f 1)"
UPDATE_ID="$(basename "$UPDATE_DIR" | cut -d'_' -f 2)"

# Only proceed if the hidden files exist
if [ ! -f "/mnt/SDCARD/.MinUI.zip" ] && [ ! -d "/mnt/SDCARD/.trimui" ]; then
    # No files to update, exit silently
    exit 0
fi

sdl2imgshow \
    -i "$EX_RESOURCE_PATH/background.png" \
    -f "$EX_RESOURCE_PATH/DejaVuSans.ttf" \
    -s 48 \
    -c "0,0,0" \
    -t "Installing PakUI" &
echo "--------------------------------------------"
echo "Running $0"
echo "- $UPDATE_DIR"
echo "- $UPDATE_ID"
# CONTENT
mv -f /mnt/SDCARD/.MinUI.zip /mnt/SDCARD/MinUI.zip
mv -f /mnt/SDCARD/.trimui /mnt/SDCARD/trimui
# FOOTER
pkill -f sdl2imgshow
echo "Done!"