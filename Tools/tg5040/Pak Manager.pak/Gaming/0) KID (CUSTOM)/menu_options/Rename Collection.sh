#!/bin/sh
if [ -z "$MENU" ]; then
   echo "Error: MENU environment variable not set" >&2
   exit 1
fi

current_name=$(head -n 1 "$MENU" | cut -d'|' -f1)
./show_message "Rename Collection:|$current_name" -l -a "OK" -b "CANCEL"
if [ $? -ne 0 ]; then
   exit 0
fi

new_name=$(./keyboard)
if [ -z "$new_name" ]; then
   exit 0
fi

sed -i "1s/^[^|]*/$new_name/" "$MENU"

current_dir=$(pwd)
current_basename=$(basename "$current_dir")
suffix=$(echo "$current_basename" | grep -oE ' \(.*\)$')
new_folder_name="${new_name}${suffix}"
parent_dir=$(dirname "$current_dir")
old_folder_name="$current_basename"

OLD_PATH="$parent_dir/$old_folder_name/launch.sh"
NEW_PATH="$parent_dir/$new_folder_name/launch.sh"

update_exec_line() {
   local file="$1"
   OLD_PATH_ESCAPED=$(echo "$OLD_PATH" | sed 's/[\/&]/\\&/g')
   NEW_PATH_ESCAPED=$(echo "$NEW_PATH" | sed 's/[\/&]/\\&/g')
   sed -i "s|exec \"$OLD_PATH_ESCAPED\"|exec \"$NEW_PATH_ESCAPED\"|g" "$file"
}

if [ -d "/mnt/SDCARD/.system/$PLATFORM/paks/Emus" ]; then
   for pak in /mnt/SDCARD/.system/$PLATFORM/paks/Emus/*.pak; do
       if [ -f "$pak/launch.sh" ]; then
           if echo "$pak" | grep -q "/CUSTOM\.pak$"; then
               continue
           fi
           update_exec_line "$pak/launch.sh"
       fi
   done
fi

if [ -d "/mnt/SDCARD/Emus" ]; then
   find "/mnt/SDCARD/Emus" -type f -name "launch.sh" | while read -r EMU_LAUNCHER; do
       if echo "$EMU_LAUNCHER" | grep -q "/CUSTOM\.pak/launch\.sh$"; then
           continue
       fi
       update_exec_line "$EMU_LAUNCHER"
   done
fi

if [ -d "/mnt/SDCARD/.userdata" ]; then
   for platform_dir in /mnt/SDCARD/.userdata/*; do
       if [ -d "$platform_dir" ]; then
           AUTO_SH="$platform_dir/auto.sh"
           if [ -f "$AUTO_SH" ]; then
               OLD_PATH_ESCAPED=$(echo "$OLD_PATH" | sed 's/[\/&]/\\&/g')
               sed -i "\|exec \"$OLD_PATH_ESCAPED\"|d" "$AUTO_SH"
           fi
       fi
   done
fi

mv "$current_dir" "$parent_dir/$new_folder_name"
cd "$parent_dir/$new_folder_name" || exit 1
old_m3u="${old_folder_name}.m3u"
new_m3u="${new_folder_name}.m3u"
if [ -f "$old_m3u" ]; then
   mv "$old_m3u" "$new_m3u"
fi

old_img="/mnt/SDCARD/Roms/.res/${old_folder_name}.png"
new_img="/mnt/SDCARD/Roms/.res/${new_folder_name}.png"
if [ -f "$old_img" ]; then
   mv "$old_img" "$new_img"
fi

./show_message "Collection renamed|to $new_name" -l a
exit 0