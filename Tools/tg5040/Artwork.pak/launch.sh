#!/bin/sh

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

TEMP_MENU="/tmp/artwork_menu.txt"

PLATFORM="tg5040"
THEME_PATHS="/mnt/SDCARD/.res /mnt/SDCARD/Roms/.res /mnt/SDCARD/Tools/.res /mnt/SDCARD/Tools/$PLATFORM/.res"

BOXART_BASE="/mnt/SDCARD/Roms"

PICKER="./picker"
SHOW_MESSAGE="./show_message"

export LD_LIBRARY_PATH="$SCRIPT_DIR/.lib:$LD_LIBRARY_PATH"

trap 'rm -f "$TEMP_MENU"' EXIT

get_theme_status() {
   for path in $THEME_PATHS; do
       if [ -d "$path" ]; then
           echo "enabled"
           return 0
       fi
   done
   echo "disabled"
   return 1
}

toggle_theme() {
   local status
   status=$(get_theme_status)
   
   if [ "$status" = "enabled" ]; then
       "$SHOW_MESSAGE" "Disabling theme..." -t 1
       for path in $THEME_PATHS; do
           if [ -d "$path" ]; then
               mv "$path" "${path}_off" 2>/dev/null
           fi
       done
       "$SHOW_MESSAGE" "Theme disabled" -l a
   else
       "$SHOW_MESSAGE" "Enabling theme..." -t 1
       for path in $THEME_PATHS; do
           local off_path="${path}_off"
           if [ -d "$off_path" ]; then
               mv "$off_path" "$path" 2>/dev/null
           fi
       done
       "$SHOW_MESSAGE" "Theme enabled" -l a
   fi
}

get_boxart_status() {
   res_found=$(find "$BOXART_BASE" -mindepth 2 -type d -name ".res" 2>/dev/null)
   if [ -n "$res_found" ]; then
       echo "enabled"
       return 0
   fi
   res_off_found=$(find "$BOXART_BASE" -mindepth 2 -type d -name ".res_off" 2>/dev/null)
   if [ -n "$res_off_found" ]; then
       echo "disabled"
       return 0
   fi
   echo "enabled"
   return 0
}

toggle_boxart() {
   local status
   status=$(get_boxart_status)
   
   if [ "$status" = "enabled" ]; then
        "$SHOW_MESSAGE" "Disabling Box Art..." -t 1
        find "$BOXART_BASE" -mindepth 2 -type d -name ".res" 2>/dev/null | while IFS= read -r folder; do
            mv "$folder" "${folder}_off"
        done
        "$SHOW_MESSAGE" "Box Art disabled" -l a
   else
        "$SHOW_MESSAGE" "Enabling Box Art..." -t 1
        find "$BOXART_BASE" -mindepth 2 -type d -name ".res_off" 2>/dev/null | while IFS= read -r folder; do
            new_folder=$(echo "$folder" | sed 's/\.res_off$/.res/')
            mv "$folder" "$new_folder"
        done
        "$SHOW_MESSAGE" "Box Art enabled" -l a
   fi
}

create_main_menu() {
   local theme_status boxart_status
   theme_status=$(get_theme_status)
   boxart_status=$(get_boxart_status)
   
   local theme_text="Disable Theme"
   if [ "$theme_status" = "disabled" ]; then
       theme_text="Enable Theme"
   fi
   
   local boxart_text="Disable Box Art"
   if [ "$boxart_status" = "disabled" ]; then
       boxart_text="Enable Box Art"
   fi
   
   rm -f "$TEMP_MENU"
   echo "Artwork Manager|__HEADER__|header" > "$TEMP_MENU"
   echo "Create New Theme|theme|action" >> "$TEMP_MENU"
   echo "$theme_text|toggle|action" >> "$TEMP_MENU"
   echo "$boxart_text|boxart|action" >> "$TEMP_MENU"
   echo "Change Bootlogo|bootlogo|action" >> "$TEMP_MENU"
}

start_theme_creation() {
   local status
   status=$(get_theme_status)
   if [ "$status" = "disabled" ]; then
       "$SHOW_MESSAGE" "Enabling theme..." -t 1
       for path in $THEME_PATHS; do
           local off_path="${path}_off"
           if [ -d "$off_path" ]; then
               mv "$off_path" "$path" 2>/dev/null
           fi
       done
   fi
   "$SCRIPT_DIR/theme_creator.sh"
   return 0
}

start_boxart_toggle() {
   toggle_boxart
   return 0
}

start_bootlogo_creation() {
   "$SCRIPT_DIR/bootlogos.sh"
   return 0
}

create_main_menu
IDX=0

while true; do
   SEL=$("$PICKER" "$TEMP_MENU" -i $IDX -a "SELECT" -b "EXIT")
   ST=$?
   
   [ -n "$SEL" ] && IDX=$(grep -n "^$SEL$" "$TEMP_MENU" | cut -d: -f1 || echo "0")
   IDX=$((IDX - 1))
   [ $IDX -lt 0 ] && IDX=0
   
   [ $ST -eq 1 ] || [ -z "$SEL" ] && exit 0
   
   ACT=$(echo "$SEL" | cut -d'|' -f2)
   
   case "$ACT" in
       header)
           local status
           status=$(get_theme_status)
           if [ "$status" = "enabled" ]; then
               "$SHOW_MESSAGE" "Artwork Manager|Theme is currently enabled" -l a
           else
               "$SHOW_MESSAGE" "Artwork Manager|Theme is currently disabled" -l a
           fi
       ;;
       toggle)
           toggle_theme
           create_main_menu
       ;;
       theme)
           start_theme_creation
           create_main_menu
       ;;
       boxart)
           start_boxart_toggle
           create_main_menu
       ;;
       bootlogo)
           start_bootlogo_creation
           create_main_menu
       ;;
   esac
done