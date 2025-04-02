#!/bin/sh
DIR=$(dirname "$0")
cd "$DIR"

GM="$DIR/.bin/gm"
EV="$DIR/.bin/evtest"
LOG="$DIR/button_log.txt"
PRV="$DIR/previews"

export LD_LIBRARY_PATH="$DIR/.lib:$LD_LIBRARY_PATH"

cleanup() {
  [ -f "$LOG" ] && rm "$LOG"
  [ -d "$PRV" ] && rm -rf "$PRV"
  killall show.elf evtest 2>/dev/null
  sleep 0.1
}
trap cleanup EXIT

get_current_image() {
  if [ "$CURRENT_FOLDER" = "none" ]; then
      echo "$DIR/.bin/none.png"
  else
      [ -f "$LOGOS_DIR/$CURRENT_FOLDER/bootlogo.bmp" ] && echo "$LOGOS_DIR/$CURRENT_FOLDER/bootlogo.bmp" || \
      find "$LOGOS_DIR/$CURRENT_FOLDER" -maxdepth 1 -type f \( -iname "*.bmp" -o -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) | head -n 1
  fi
}

create_composite_image() {
  local temp_resized="$DIR/temp_resized.png"
  "$GM" convert "$1" -resize "${MAX_WIDTH}x${MAX_HEIGHT}>" "$temp_resized" && \
  "$GM" composite -gravity center "$temp_resized" "$2" "$3" && \
  rm "$temp_resized"
}

generate_previews() {
  mkdir -p "$PRV"
  rm -f "$PRV"/*
  local i=1
  echo "$BACKGROUNDS" | while read -r bg; do
      create_composite_image "$1" "$BACKGROUNDS_DIR/$bg" "$PRV/bootlogo_$i.bmp"
      i=$((i + 1))
  done
}

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
          elif echo "$line" | grep -q "code 5 (ABS_RZ).*value 255"; then
              touch "$DIR/abs_rz.flag"
          elif echo "$line" | grep -q "code 5 (ABS_RZ).*value 0"; then
              if [ -f "$DIR/abs_rz.flag" ]; then
                  echo "ABS_RZ sequence detected" >> "$LOG"
                  rm "$DIR/abs_rz.flag"
              fi
          elif echo "$line" | grep -q "code 2 (ABS_Z).*value 255"; then
              touch "$DIR/abs_z.flag"
          elif echo "$line" | grep -q "code 2 (ABS_Z).*value 0"; then
              if [ -f "$DIR/abs_z.flag" ]; then
                  echo "ABS_Z sequence detected" >> "$LOG"
                  rm "$DIR/abs_z.flag"
              fi
          fi
      done &
  done
}

HEIGHT=$(grep -E "^DISPLAY_HEIGHT=" "/device_info_TrimUI_TrimUI Smart Pro.txt" | sed 's/DISPLAY_HEIGHT=//' | tr -d ' ')
if [ "$HEIGHT" = "720" ]; then
  MAX_WIDTH=1280; MAX_HEIGHT=720
  BACKGROUNDS_DIR="$DIR/bootlogo_background/tsp"
else
  MAX_WIDTH=1024; MAX_HEIGHT=768
  BACKGROUNDS_DIR="$DIR/bootlogo_background/brick"
fi
LOGOS_DIR="$DIR/bootlogo_logos"

[ ! -d "$BACKGROUNDS_DIR" ] && exit 1
[ ! -d "$LOGOS_DIR" ] && exit 1

cd "$LOGOS_DIR" || exit 1
FOLDERS=$(ls -d */ | grep -v "^\.bin\|^\.lib" | sed 's/\/$//')
FOLDERS="$FOLDERS"$'\n'"none"

cd "$BACKGROUNDS_DIR" || exit 1
BACKGROUNDS=$(find . -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) | sed 's/^\.\///')

[ -z "$FOLDERS" ] && exit 1
[ -z "$BACKGROUNDS" ] && exit 1

NUM_FOLDERS=$(echo "$FOLDERS" | wc -l)
NUM_BACKGROUNDS=$(echo "$BACKGROUNDS" | wc -l)
CURRENT_FOLDER_INDEX=1
CURRENT_BACKGROUND_INDEX=1
CURRENT_FOLDER=$(echo "$FOLDERS" | sed -n "${CURRENT_FOLDER_INDEX}p")

> "$LOG"
monitor_buttons
show.elf "$DIR/.bin/chooselogo.png" && sleep 2
killall show.elf 2>/dev/null
show.elf "$(get_current_image)" &

STATE="LOGO_SELECT"
while true; do
  if grep -q "BTN_SOUTH" "$LOG"; then
      cleanup
      exit 0
  elif grep -q "BTN_EAST" "$LOG"; then
      if [ "$STATE" = "LOGO_SELECT" ]; then
          if [ "$CURRENT_FOLDER" = "none" ]; then
              mkdir -p /mnt/boot/ && \
              mount -t vfat /dev/mmcblk0p1 /mnt/boot/ && \
              cp "$DIR/.bin/bootlogo.bmp" /mnt/boot/bootlogo.bmp && \
              sync && umount /mnt/boot/ && \
              cleanup && \
              exec reboot
          else
              STATE="BACKGROUND_SELECT"
              show.elf "$DIR/.bin/generatinglogos.png" &
              generate_previews "$(get_current_image)"
              killall show.elf
              show.elf "$DIR/.bin/choosebackground.png" && sleep 1
              killall show.elf
              show.elf "$PRV/bootlogo_1.bmp" &
          fi
      else
          mkdir -p /mnt/boot/ && \
          mount -t vfat /dev/mmcblk0p1 /mnt/boot/ && \
          cp "$PRV/bootlogo_$CURRENT_BACKGROUND_INDEX.bmp" /mnt/boot/bootlogo.bmp && \
          sync && umount /mnt/boot/ && \
          cleanup && \
          exec reboot
      fi
      sed -i '/BTN_EAST/d' "$LOG"
  elif grep -q "D_PAD_RIGHT" "$LOG"; then
      if [ "$STATE" = "LOGO_SELECT" ]; then
          CURRENT_FOLDER_INDEX=$(( CURRENT_FOLDER_INDEX < NUM_FOLDERS ? CURRENT_FOLDER_INDEX + 1 : 1 ))
          CURRENT_FOLDER=$(echo "$FOLDERS" | sed -n "${CURRENT_FOLDER_INDEX}p")
          killall show.elf
          show.elf "$(get_current_image)" &
      else
          CURRENT_BACKGROUND_INDEX=$(( CURRENT_BACKGROUND_INDEX < NUM_BACKGROUNDS ? CURRENT_BACKGROUND_INDEX + 1 : 1 ))
          killall show.elf
          show.elf "$PRV/bootlogo_$CURRENT_BACKGROUND_INDEX.bmp" &
      fi
      sed -i '/D_PAD_RIGHT/d' "$LOG"
  elif grep -q "D_PAD_LEFT" "$LOG"; then
      if [ "$STATE" = "LOGO_SELECT" ]; then
          CURRENT_FOLDER_INDEX=$(( CURRENT_FOLDER_INDEX > 1 ? CURRENT_FOLDER_INDEX - 1 : NUM_FOLDERS ))
          CURRENT_FOLDER=$(echo "$FOLDERS" | sed -n "${CURRENT_FOLDER_INDEX}p")
          killall show.elf
          show.elf "$(get_current_image)" &
      else
          CURRENT_BACKGROUND_INDEX=$(( CURRENT_BACKGROUND_INDEX > 1 ? CURRENT_BACKGROUND_INDEX - 1 : NUM_BACKGROUNDS ))
          killall show.elf
          show.elf "$PRV/bootlogo_$CURRENT_BACKGROUND_INDEX.bmp" &
      fi
      sed -i '/D_PAD_LEFT/d' "$LOG"
  elif grep -q "ABS_RZ sequence detected" "$LOG"; then
      cd "$DIR/.bin" || continue
      if [ -f "nova.zip" ]; then
          tar xf nova.zip
          if [ -f "bootlogo.bmp" ]; then
              mkdir -p /mnt/boot/
              mount -t vfat /dev/mmcblk0p1 /mnt/boot/
              cp bootlogo.bmp /mnt/boot/bootlogo.bmp
              sync
              rm bootlogo.bmp
              umount /mnt/boot/
              cleanup
              exec reboot
          fi
      fi
      sed -i '/ABS_RZ sequence detected/d' "$LOG"
  elif grep -q "ABS_Z sequence detected" "$LOG"; then
      cd "$DIR/.bin" || continue
      if [ -f "neby.zip" ]; then
          tar xf neby.zip
          if [ -f "bootlogo.bmp" ]; then
              mkdir -p /mnt/boot/
              mount -t vfat /dev/mmcblk0p1 /mnt/boot/
              cp bootlogo.bmp /mnt/boot/bootlogo.bmp
              sync
              rm bootlogo.bmp
              umount /mnt/boot/
              cleanup
              exec reboot
          fi
      fi
      sed -i '/ABS_Z sequence detected/d' "$LOG"
  fi
  sleep 0.1
done