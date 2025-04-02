#!/bin/sh
# Direct launcher script for Boot To

# Make sure the auto_resume.txt is removed so MinUI doesn't try to resume again
rm -f "/mnt/SDCARD/.userdata/shared/.minui/auto_resume.txt"

# Launch the emulator with the game ROM
"/mnt/SDCARD/Emus/tg5040/GBC.pak/launch.sh" "/mnt/SDCARD/Roms/Game Boy Color (GBC)/Black Castle.zip"

# After the game exits (regardless of internal structure),
# directly launch our boot option
if [ "custom" = "game" ]; then
    exec "/mnt/SDCARD/Roms/0) Favorites (CUSTOM)/launch.sh" ""
else
    exec "/mnt/SDCARD/Roms/0) Favorites (CUSTOM)/launch.sh"
fi
