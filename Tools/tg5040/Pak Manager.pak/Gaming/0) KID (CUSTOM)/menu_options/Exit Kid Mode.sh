#!/bin/sh
# Dynamically determine our own path
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
KIDMODE_DIR="$(cd "$(dirname "$SCRIPT_DIR")" && pwd -P)"
KIDMODE_LAUNCH="$KIDMODE_DIR/launch.sh"

remove_kidmode_line() {
   local file="$1"
   
   if echo "$file" | grep -q "/CUSTOM\.pak/launch\.sh$" || [ "$file" = "$KIDMODE_LAUNCH" ]; then
       return
   fi
   
   # Remove all possible Kid Mode redirects
   sed -i '/# KIDMODE_REDIRECT/d' "$file"
   sed -i "/exec .*launch\.sh.*KIDMODE.*/d" "$file"
   sed -i "/exec .*Kid.*Collection.*launch\.sh.*/d" "$file"
   sed -i "/exec \"$KIDMODE_LAUNCH\"/d" "$file"
}

if [ -d "/mnt/SDCARD/.system/$PLATFORM/paks/Emus" ]; then
   for pak in /mnt/SDCARD/.system/$PLATFORM/paks/Emus/*.pak; do
       if [ -f "$pak/launch.sh" ]; then
           remove_kidmode_line "$pak/launch.sh"
       fi
   done
fi

if [ -d "/mnt/SDCARD/Emus" ]; then
   find "/mnt/SDCARD/Emus" -type f -name "launch.sh" | while read -r EMU_LAUNCHER; do
       remove_kidmode_line "$EMU_LAUNCHER"
   done
fi

if [ -d "/mnt/SDCARD/.userdata" ]; then
   for platform_dir in /mnt/SDCARD/.userdata/*; do
       if [ -d "$platform_dir" ]; then
           AUTO_SH="$platform_dir/auto.sh"
           if [ -f "$AUTO_SH" ]; then
               sed -i '/# KIDMODE_AUTO_MARKER/d' "$AUTO_SH"
           fi
       fi
   done
fi

rm -f /tmp/keyboard_output.txt \
     /tmp/picker_output.txt \
     /tmp/search_results.txt \
     /tmp/add_favorites.txt \
     /tmp/browser_selection.txt \
     /tmp/browser_history.txt \
     /tmp/kid_game_launcher.sh \
     /tmp/kid_game_running.tmp

kill -TERM $PPID

exit 0