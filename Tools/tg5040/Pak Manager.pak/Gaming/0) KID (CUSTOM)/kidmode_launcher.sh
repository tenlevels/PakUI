#!/bin/sh
# Direct launcher script for Kid Mode

# Make sure the auto_resume.txt is removed so MinUI doesn't try to resume again
rm -f "/mnt/SDCARD/.userdata/shared/.minui/auto_resume.txt"

# Create a sentinel file that will help us detect if we need to return to Kid Mode
touch "/tmp/kidmode_active"

# Launch the emulator with the game ROM
"/mnt/SDCARD/Emus/tg5040/GBC.pak/launch.sh" "/mnt/SDCARD/Roms/Game Boy Color (GBC)/Black Castle.zip"
GAME_EXIT_CODE=$?

# After the game exits, directly launch kid mode
# Using exec ensures we replace this process with Kid Mode
if [ -f "/tmp/kidmode_active" ]; then
    rm -f "/tmp/kidmode_active"
    # Full explicit path to Kid Mode
    exec "/mnt/SDCARD/Roms/0) KID (CUSTOM)/launch.sh"
fi
