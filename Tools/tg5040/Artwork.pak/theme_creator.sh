#!/bin/sh

DIR=$(dirname "$0")
cd "$DIR"

GM="$DIR/.bin/gm"
EV="$DIR/.bin/evtest"
LOG="$DIR/button_log.txt"
PRV="$DIR/previews"
CONFIG="$DIR/.bin/theme_config.txt"

export LD_LIBRARY_PATH="$DIR/.lib:$LD_LIBRARY_PATH"

restore_theme_paths() {
   PLATFORM="tg5040"
   THEME_PATHS="/mnt/SDCARD/.res /mnt/SDCARD/Roms/.res /mnt/SDCARD/Tools/.res /mnt/SDCARD/Tools/$PLATFORM/.res"
   for path in $THEME_PATHS; do
       off_path="${path}_off"
       if [ -d "$off_path" ]; then
           mv "$off_path" "$path"
       fi
   done
}
restore_theme_paths

cleanup() {
  [ -f "$LOG" ] && rm "$LOG"
  [ -d "$PRV" ] && rm -rf "$PRV"
  killall show.elf evtest 2>/dev/null
  sleep 0.1
}
trap cleanup EXIT

monitor_buttons() {
  for dev in /dev/input/event*; do
      [ -e "$dev" ] || continue
      "$EV" "$dev" 2>&1 | while read -r line; do
          if echo "$line" | grep -q "code 304 (BTN_SOUTH).*value 1"; then
              echo "BTN_SOUTH detected" >> "$LOG"
          elif echo "$line" | grep -q "code 305 (BTN_EAST).*value 1"; then
              echo "BTN_EAST detected" >> "$LOG"
          elif echo "$line" | grep -q "code 16 (ABS_HAT0X).*value 1"; then
              echo "D_PAD_RIGHT detected" >> "$LOG"
          elif echo "$line" | grep -q "code 16 (ABS_HAT0X).*value -1"; then
              echo "D_PAD_LEFT detected" >> "$LOG"
          fi
      done &
  done
}

create_composite_image() {
   if [ "$CURRENT_ICON_SET" = "none" ]; then
       cp "$2" "$3"
   else
       "$GM" composite -gravity east "$1" "$2" "$3"
   fi
}

show_icon_preview() {
   killall show.elf 2>/dev/null
   local preview
   preview=$(get_current_preview)
   show.elf "$preview" &
}

get_current_preview() {
   local preview="$ICONS_DIR/$CURRENT_ICON_SET/preview.png"
   if [ "$CURRENT_ICON_SET" = "none" ]; then
       echo "$DIR/.bin/none.png"
   elif [ -f "$preview" ]; then
       echo "$preview"
   else
       echo "$ICONS_DIR/$CURRENT_ICON_SET/(GBC).png"
   fi
}

create_background_preview() {
   local bg="$1"
   local preview_name="${bg%.*}_prev.png"
   local icon_preview
   icon_preview=$(get_current_preview)
   local width
   width=$("$GM" identify -format "%w" "$BACKGROUNDS_DIR/$bg")
   [ "$HEIGHT" = "720" ] && [ "$width" -gt 640 ] && return 1
   [ "$HEIGHT" != "720" ] && [ "$width" -gt 512 ] && return 1
   local base_background="$DIR/.bin/brickbackground.png"
   [ "$HEIGHT" = "720" ] && base_background="$DIR/.bin/tspbackground.png"
   [ ! -d "$PRV" ] && mkdir -p "$PRV"
   if [ "$CURRENT_ICON_SET" = "none" ]; then
       "$GM" composite -gravity east "$BACKGROUNDS_DIR/$bg" "$base_background" "$PRV/$preview_name"
   else
       "$GM" composite -gravity east "$BACKGROUNDS_DIR/$bg" "$base_background" miff:- | "$GM" composite -gravity east "$icon_preview" - "$PRV/$preview_name"
   fi
   return 0
}

show_background_preview() {
   local preview_name="${CURRENT_BACKGROUND%.*}_prev.png"
   if [ ! -f "$PRV/$preview_name" ]; then
       if ! create_background_preview "$CURRENT_BACKGROUND"; then
           local original_index="$CURRENT_BACKGROUND_INDEX"
           local tried_all=0
           while true; do
               if [ "$1" = "left" ]; then
                   CURRENT_BACKGROUND_INDEX=$((CURRENT_BACKGROUND_INDEX - 1))
                   [ "$CURRENT_BACKGROUND_INDEX" -lt 1 ] && CURRENT_BACKGROUND_INDEX="$NUM_BACKGROUNDS"
               else
                   CURRENT_BACKGROUND_INDEX=$((CURRENT_BACKGROUND_INDEX + 1))
                   [ "$CURRENT_BACKGROUND_INDEX" -gt "$NUM_BACKGROUNDS" ] && CURRENT_BACKGROUND_INDEX=1
               fi
               [ "$CURRENT_BACKGROUND_INDEX" = "$original_index" ] && tried_all=1 && break
               CURRENT_BACKGROUND=$(echo "$BACKGROUNDS" | sed -n "${CURRENT_BACKGROUND_INDEX}p")
               create_background_preview "$CURRENT_BACKGROUND" && break
           done
           [ "$tried_all" = "1" ] && cleanup && exit 1
           preview_name="${CURRENT_BACKGROUND%.*}_prev.png"
       fi
   fi
   killall show.elf 2>/dev/null
   [ -f "$PRV/$preview_name" ] && show.elf "$PRV/$preview_name" &
}

process_config_section() {
   local current_section=""
   local icon_set_dir="$ICONS_DIR/$CURRENT_ICON_SET"
   local background="$BACKGROUNDS_DIR/$CURRENT_BACKGROUND"
   if [ -n "$CONFIG" ] && [ -f "$CONFIG" ]; then
       local last_line
       last_line=$(tail -n 1 "$CONFIG")
       if [ -n "$last_line" ] && [ "${last_line#\#}" = "$last_line" ]; then
           echo "" >> "$CONFIG"
           echo "# End of configuration" >> "$CONFIG"
       fi
   fi
   while IFS= read -r line; do
       line=$(echo "$line" | tr -d '\r')
       [ -z "$line" ] && continue
       [ "${line#\#}" != "$line" ] && continue
       if [ "${line#[}" != "$line" ]; then
           current_section="${line#[}"
           current_section="${current_section%]}"
           rm -rf "$current_section"
           mkdir -p "$current_section"
           continue
       fi
       if [ -n "$current_section" ] && [ -n "$line" ]; then
           if [ "$CURRENT_ICON_SET" = "none" ]; then
               cp "$background" "$current_section/$line"
           else
               local src_icon="$icon_set_dir/$line"
               if [ -f "$src_icon" ]; then
                   create_composite_image "$src_icon" "$background" "$current_section/$line"
               else
                   cp "$background" "$current_section/$line"
               fi
           fi
       fi
   done < "$CONFIG"
}

find_and_create_icon() {
   local item_name="$1"
   local dst_path="$2"
   local icon_set_dir="$ICONS_DIR/$CURRENT_ICON_SET"
   local background="$BACKGROUNDS_DIR/$CURRENT_BACKGROUND"
   [ -f "$dst_path" ] && return 0
   if [ "$CURRENT_ICON_SET" = "none" ]; then
       cp "$background" "$dst_path"
       return 0
   fi
   if [ -f "$icon_set_dir/$item_name.png" ]; then
       create_composite_image "$icon_set_dir/$item_name.png" "$background" "$dst_path"
       return 0
   fi
   local stripped="$item_name"
   while echo "$stripped" | grep -q '\.'; do
       stripped="${stripped%.*}"
       if [ -f "$icon_set_dir/$stripped.png" ]; then
           create_composite_image "$icon_set_dir/$stripped.png" "$background" "$dst_path"
           return 0
       fi
   done
   local system_code
   system_code=$(echo "$item_name" | grep -oE '\([^)]*\)')
   if [ -n "$system_code" ]; then
       if [ -f "$icon_set_dir/$system_code.png" ]; then
           create_composite_image "$icon_set_dir/$system_code.png" "$background" "$dst_path"
           return 0
       fi
   fi
   cp "$background" "$dst_path"
   return 1
}

process_rom_directories() {
   local roms_dir="/mnt/SDCARD/Roms"
   local res_dir="$roms_dir/.res"
   mkdir -p "$res_dir"
   cd "$roms_dir" || return
   for romdir in */; do
       [ -d "$romdir" ] || continue
       local dirname
       dirname=$(basename "$romdir")
       local dst_png="$res_dir/$dirname.png"
       [ -f "$dst_png" ] && continue
       find_and_create_icon "$dirname" "$dst_png"
   done
}

process_tools_directory() {
   local tools_dir="/mnt/SDCARD/Tools"
   local res_dir="$tools_dir/.res"
   mkdir -p "$res_dir"
   find "$tools_dir" -maxdepth 1 -mindepth 1 | grep -v "\.res$" | while read -r item; do
       local item_name
       item_name=$(basename "$item")
       [ "${item_name:0:1}" = "." ] && continue
       local dst_png="$res_dir/$item_name.png"
       [ -f "$dst_png" ] && continue
       find_and_create_icon "$item_name" "$dst_png"
   done
}

process_platform_tools() {
   PLATFORM="tg5040"
   local tools_platform_dir="/mnt/SDCARD/Tools/$PLATFORM"
   local res_dir="$tools_platform_dir/.res"
   mkdir -p "$res_dir"
   find "$tools_platform_dir" -maxdepth 1 -mindepth 1 | grep -v "\.res$" | while read -r item; do
       local item_name
       item_name=$(basename "$item")
       [ "${item_name:0:1}" = "." ] && continue
       local dst_png="$res_dir/$item_name.png"
       [ -f "$dst_png" ] && continue
       find_and_create_icon "$item_name" "$dst_png"
   done
}

process_function_icons() {
   local func_dir="/mnt/SDCARD"
   local res_dir="$func_dir/.res"
   mkdir -p "$res_dir"
   for func_name in "Recently Played" "Collections"; do
       local dst_png="$res_dir/$func_name.png"
       [ -f "$dst_png" ] && continue
       find_and_create_icon "$func_name" "$dst_png"
   done
}

apply_theme() {
   if [ -f "$CONFIG" ]; then
       process_config_section
   fi
   process_rom_directories
   process_tools_directory
   process_platform_tools
   process_function_icons
}

HEIGHT=$(grep -E "^DISPLAY_HEIGHT=" "/device_info_TrimUI_TrimUI Smart Pro.txt" | sed 's/DISPLAY_HEIGHT=//' | tr -d ' ')
if [ "$HEIGHT" = "720" ]; then
  BACKGROUNDS_DIR="$DIR/theme_background/tsp"
else
  BACKGROUNDS_DIR="$DIR/theme_background/brick"
fi
ICONS_DIR="$DIR/theme_icons"

[ ! -d "$BACKGROUNDS_DIR" ] && exit 1
[ ! -d "$ICONS_DIR" ] && exit 1

cd "$ICONS_DIR" || exit 1
ICON_SETS=$(ls -d */ 2>/dev/null | grep -v "^\.bin\|^\.lib\|^\." | sed 's/\/$//')
ICON_SETS="$ICON_SETS"$'\n'"none"

cd "$BACKGROUNDS_DIR" || exit 1
BACKGROUNDS=$(find . -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) | grep -v "/\." | sed 's/^\.\///' | sort)

[ -z "$ICON_SETS" ] && exit 1
[ -z "$BACKGROUNDS" ] && exit 1

NUM_ICON_SETS=$(echo "$ICON_SETS" | wc -l)
NUM_BACKGROUNDS=$(echo "$BACKGROUNDS" | wc -l)
CURRENT_ICON_SET_INDEX=1
CURRENT_BACKGROUND_INDEX=1
CURRENT_ICON_SET=$(echo "$ICON_SETS" | sed -n "${CURRENT_ICON_SET_INDEX}p")
CURRENT_BACKGROUND=$(echo "$BACKGROUNDS" | sed -n "${CURRENT_BACKGROUND_INDEX}p")

> "$LOG"
monitor_buttons

show.elf "$DIR/.bin/chooseicon.png" && sleep 2
killall show.elf 2>/dev/null
show_icon_preview
STATE="ICON_SELECT"

handle_east_button() {
   if [ "$STATE" = "ICON_SELECT" ]; then
       STATE="BACKGROUND_SELECT"
       create_background_preview "$CURRENT_BACKGROUND"
       show.elf "$DIR/.bin/choosebackground.png"
       sleep 0.3
       killall show.elf
       show_background_preview "right"
   else
       show.elf "$DIR/.bin/applyingtheme.png" &
       apply_theme
       killall show.elf
       show.elf "$DIR/.bin/done.png" && sleep 1
       cleanup
       exit 0
   fi
}

handle_right_pad() {
   if [ "$STATE" = "ICON_SELECT" ]; then
       CURRENT_ICON_SET_INDEX=$((CURRENT_ICON_SET_INDEX + 1))
       [ "$CURRENT_ICON_SET_INDEX" -gt "$NUM_ICON_SETS" ] && CURRENT_ICON_SET_INDEX=1
       CURRENT_ICON_SET=$(echo "$ICON_SETS" | sed -n "${CURRENT_ICON_SET_INDEX}p")
       show_icon_preview
   else
       CURRENT_BACKGROUND_INDEX=$((CURRENT_BACKGROUND_INDEX + 1))
       [ "$CURRENT_BACKGROUND_INDEX" -gt "$NUM_BACKGROUNDS" ] && CURRENT_BACKGROUND_INDEX=1
       CURRENT_BACKGROUND=$(echo "$BACKGROUNDS" | sed -n "${CURRENT_BACKGROUND_INDEX}p")
       show_background_preview "right"
   fi
}

handle_left_pad() {
   if [ "$STATE" = "ICON_SELECT" ]; then
       CURRENT_ICON_SET_INDEX=$((CURRENT_ICON_SET_INDEX - 1))
       [ "$CURRENT_ICON_SET_INDEX" -lt 1 ] && CURRENT_ICON_SET_INDEX="$NUM_ICON_SETS"
       CURRENT_ICON_SET=$(echo "$ICON_SETS" | sed -n "${CURRENT_ICON_SET_INDEX}p")
       show_icon_preview
   else
       CURRENT_BACKGROUND_INDEX=$((CURRENT_BACKGROUND_INDEX - 1))
       [ "$CURRENT_BACKGROUND_INDEX" -lt 1 ] && CURRENT_BACKGROUND_INDEX="$NUM_BACKGROUNDS"
       CURRENT_BACKGROUND=$(echo "$BACKGROUNDS" | sed -n "${CURRENT_BACKGROUND_INDEX}p")
       show_background_preview "left"
   fi
}

while true; do
   if grep -q "BTN_SOUTH" "$LOG"; then
       cleanup
       exit 0
   elif grep -q "BTN_EAST" "$LOG"; then
       handle_east_button
       sed -i '/BTN_EAST/d' "$LOG"
   elif grep -q "D_PAD_RIGHT" "$LOG"; then
       handle_right_pad
       sed -i '/D_PAD_RIGHT/d' "$LOG"
   elif grep -q "D_PAD_LEFT" "$LOG"; then
       handle_left_pad
       sed -i '/D_PAD_LEFT/d' "$LOG"
   fi
   sleep 0.1
done
