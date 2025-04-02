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
