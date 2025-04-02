#!/bin/sh

cd "$(dirname "$0")"
export LD_LIBRARY_PATH=/usr/trimui/lib:$LD_LIBRARY_PATH

ROM_DIR="/mnt/SDCARD/Roms"
RES_DIR="/mnt/SDCARD/Roms/.res"
BITPAL_DIR="/mnt/SDCARD/Tools"

FOLDERS_LIST="/tmp/rom_folders.txt"
DISPLAY_LIST="/tmp/display_folders.txt"  
REORDER_LIST="/tmp/reorder_folders.txt"  
REORDER_TMP="/tmp/reorder_tmp.txt"       

remove_sort_mode="false"
sort_applied="false"

cleanup() {
   rm -f "$FOLDERS_LIST" "$DISPLAY_LIST" "$REORDER_LIST" "$REORDER_TMP" \
         "/tmp/folder_sort_result.txt" "/tmp/reorder_folders.txt.backup" \
         "/tmp/rename_display.txt" "/tmp/folder_mapping.txt" "/tmp/sort_options.txt"
}

folder_has_roms() {
   local folder="$1"
   if [ "$(find "$folder" -type f ! -path "*.res*" | grep -Evi '\.(jpg|jpeg|png|bmp|gif|tiff|webp)$' | head -n 1)" ]; then
       return 0
   else
       return 1
   fi
}

get_rom_folders() {
   > "$FOLDERS_LIST"
   > "$DISPLAY_LIST"
   
   ./show_message "Scanning emulators..." &
   loading_pid=$!
   
   for folder in "$ROM_DIR"/*; do
       if [ -d "$folder" ] && folder_has_roms "$folder"; then
           folder_name=$(basename "$folder")
           if echo "$folder_name" | grep -qE "^[0-9]+"; then
               order="$folder_name"
               base=$(echo "$folder_name" | sed -E 's/^[0-9]+[)\._ -]+//')
           else
               order="$folder_name"
               base="$folder_name"
           fi
           if echo "$base" | grep -qE " *\([^)]*\)$"; then
               tag=$(echo "$base" | grep -oE " *\([^)]*\)$")
               base=$(echo "$base" | sed -E 's/ *\([^)]*\)$//')
           else
               tag=""
           fi
           echo "$order|$base|$tag|$folder" >> "$FOLDERS_LIST"
       fi
   done
   
   kill $loading_pid 2>/dev/null
   cp "$FOLDERS_LIST" "$REORDER_LIST"
   
   if [ ! -s "$FOLDERS_LIST" ]; then
       ./show_message "No emulators found!" -l a
       cleanup
       exit 1
   fi
}

update_display_list() {
   > "$DISPLAY_LIST"
   while IFS='|' read -r order base tag folder; do
       echo "$base|$folder|select" >> "$DISPLAY_LIST"
   done < "$REORDER_LIST"
}

swap_lines() {
   local file="$1" line1="$2" line2="$3"
   awk -v l1="$line1" -v l2="$line2" '{
       arr[NR] = $0
   }
   END {
       tmp = arr[l1]
       arr[l1] = arr[l2]
       arr[l2] = tmp
       for (i = 1; i <= NR; i++) print arr[i]
   }' "$file" > "$REORDER_TMP" && mv "$REORDER_TMP" "$file"
}

sort_alphabetical() {
   sort -t'|' -k2,2 "$FOLDERS_LIST" > "$REORDER_LIST"
   update_display_list
   sort_applied="true"
   return 0
}

remove_sort() {
   remove_sort_mode="true"
   cp "$REORDER_LIST" "$REORDER_LIST.remove.backup"
   sort -t'|' -k2,2 "$REORDER_LIST" > "$REORDER_TMP"
   mv "$REORDER_TMP" "$REORDER_LIST"
   update_display_list
   sort_applied="true"
   return 0
}

rename_emulator() {
   current_line="$1"
   
   entry=$(sed -n "${current_line}p" "$REORDER_LIST")
   old_base=$(echo "$entry" | cut -d'|' -f2)
   tag=$(echo "$entry" | cut -d'|' -f3)
   folder=$(echo "$entry" | cut -d'|' -f4)
   
   new_base=$(./keyboard)
   
   if [ -n "$new_base" ]; then
       sed -i "${current_line}s@^\([^|]*\)|[^|]*@\1|${new_base}@" "$REORDER_LIST"
       update_display_list
       sort_applied="true"
   fi
   
   return 0
}

manual_reorder() {
   cp "$REORDER_LIST" "$REORDER_LIST.backup"
   reorder_idx=0
   while true; do
       update_display_list
       picker_output=$(./picker "$DISPLAY_LIST" -i $reorder_idx -x "MOVE UP" -y "MOVE DOWN" -a "OK")
       picker_status=$?
       
       if [ $picker_status -eq 0 ]; then
           rm -f "$REORDER_LIST.backup"
           sort_applied="true"
           return 0
       elif [ $picker_status -eq 2 ]; then
           mv "$REORDER_LIST.backup" "$REORDER_LIST"
           return 0
       fi
       
       current_line=$(grep -n "^${picker_output%$'\n'}$" "$DISPLAY_LIST" | cut -d: -f1)
       [ -z "$current_line" ] && current_line=1
       reorder_idx=$((current_line - 1))
       
       if [ $picker_status -eq 3 ] && [ "$current_line" -gt 1 ]; then
           swap_lines "$REORDER_LIST" "$current_line" "$((current_line - 1))"
           reorder_idx=$((reorder_idx - 1))
       elif [ $picker_status -eq 4 ]; then
           total_lines=$(wc -l < "$REORDER_LIST")
           if [ "$current_line" -lt "$total_lines" ]; then
               swap_lines "$REORDER_LIST" "$current_line" "$((current_line + 1))"
               reorder_idx=$((reorder_idx + 1))
           fi
       fi
   done
}

update_paths_in_configs() {
   local orig_name="$1"
   local final_name="$2"
   
   find "$ROM_DIR" -name "game_order.txt" -type f | while read -r order_file; do
       tmp_file="${order_file}.tmp"
       
       sed "s|${ROM_DIR}/${orig_name}/|${ROM_DIR}/${final_name}/|g" "$order_file" > "$tmp_file"
       
       mv "$tmp_file" "$order_file"
   done
   
   find "$BITPAL_DIR" -path "*/BitPal.pak/bitpal_menu.txt" -type f | while read -r bitpal_file; do
       tmp_file="${bitpal_file}.tmp"
       
       sed "s|${ROM_DIR}/${orig_name}/|${ROM_DIR}/${final_name}/|g" "$bitpal_file" > "$tmp_file"
       
       mv "$tmp_file" "$bitpal_file"
   done
   
   find "$BITPAL_DIR" -path "*/Game Time Tracker.pak/gtt_list.txt" -type f | while read -r gtt_file; do
       tmp_file="${gtt_file}.tmp"
       
       sed "s|${ROM_DIR}/${orig_name}/|${ROM_DIR}/${final_name}/|g" "$gtt_file" > "$tmp_file"
       
       mv "$tmp_file" "$gtt_file"
   done
   
   find "$BITPAL_DIR" -path "*/Game Time Tracker.pak/finished_games.txt" -type f | while read -r finished_file; do
       tmp_file="${finished_file}.tmp"
       
       awk -v old_path="${ROM_DIR}/${orig_name}/" -v new_path="${ROM_DIR}/${final_name}/" '
       BEGIN { FS="|"; OFS="|" }
       {
           if (NF > 1 && $2 ~ old_path) {
               $2 = gensub(old_path, new_path, "g", $2)
           }
           print $0
       }' "$finished_file" > "$tmp_file"
       
       mv "$tmp_file" "$finished_file"
   done
   
   find "$ROM_DIR" -path "*CUSTOM*" -name "menu.txt" -type f | while read -r menu_file; do
       tmp_file="${menu_file}.tmp"
       
       sed "s|${ROM_DIR}/${orig_name}/|${ROM_DIR}/${final_name}/|g" "$menu_file" > "$tmp_file"
       
       mv "$tmp_file" "$menu_file"
   done
   
   for folder in "$ROM_DIR"/*; do
       if [ -d "$folder" ] && [ -f "$folder/menu.txt" ]; then
           menu_file="$folder/menu.txt"
           tmp_file="${menu_file}.tmp"
           
           sed "s|${ROM_DIR}/${orig_name}/|${ROM_DIR}/${final_name}/|g" "$menu_file" > "$tmp_file"
           
           mv "$tmp_file" "$menu_file"
       fi
   done
}

apply_sort_order() {
   > "/tmp/folder_sort_result.txt"
   
   ./show_message "Applying changes..." &
   loading_pid=$!
   mapping_file="/tmp/folder_mapping.txt"
   rm -f "$mapping_file"
   counter=0
   
   while IFS='|' read -r order base tag folder; do
       if [ "$remove_sort_mode" = "true" ]; then
           final_name="${base}${tag}"
       else
           prefix=$(printf "%02d" $counter)
           final_name="$prefix) ${base}${tag}"
       fi
       
       final_path="$ROM_DIR/$final_name"
       temp_path="$ROM_DIR/temp_${final_name}"
       orig_name=$(basename "$folder")
       
       echo "$orig_name|$final_name|$folder|$temp_path|$final_path" >> "$mapping_file"
       counter=$((counter + 1))
   done < "$REORDER_LIST"
   
   while IFS='|' read -r orig_name final_name folder temp_path final_path; do
       update_paths_in_configs "$orig_name" "$final_name"
   done < "$mapping_file"
   
   while IFS='|' read -r orig_name final_name folder temp_path final_path; do
       if [ -d "$folder" ]; then
           mv "$folder" "$temp_path"
       fi
   done < "$mapping_file"
   
   while IFS='|' read -r orig_name final_name folder temp_path final_path; do
       if [ -d "$temp_path" ]; then
           mv "$temp_path" "$final_path"
           
           if [ -f "$final_path/$orig_name.m3u" ]; then
               mv "$final_path/$orig_name.m3u" "$final_path/$final_name.m3u"
           fi
           
           if [ -f "$RES_DIR/$orig_name.png" ]; then
               mv "$RES_DIR/$orig_name.png" "$RES_DIR/$final_name.png"
           fi
       fi
   done < "$mapping_file"
   
   if [ "$remove_sort_mode" = "true" ]; then
       for folder in "$ROM_DIR"/*; do
           if [ -d "$folder" ]; then
               folder_name=$(basename "$folder")
               if ! grep -q "^$folder_name|" "$mapping_file" && echo "$folder_name" | grep -qE "^[0-9]+[)\._ -]+"; then
                   base=$(echo "$folder_name" | sed -E 's/^[0-9]+[)\._ -]+//')
                   if echo "$base" | grep -qE " *\([^)]*\)$"; then
                       tag=$(echo "$base" | grep -oE " *\([^)]*\)$")
                       base=$(echo "$base" | sed -E 's/ *\([^)]*\)$//')
                   else
                       tag=""
                   fi
                   final_name="${base}${tag}"
                   final_path="$ROM_DIR/$final_name"
                   temp_path="$ROM_DIR/temp_${final_name}"
                   
                   update_paths_in_configs "$folder_name" "$final_name"
                   
                   mv "$folder" "$temp_path"
                   mv "$temp_path" "$final_path"
                   
                   if [ -f "$final_path/$folder_name.m3u" ]; then
                       mv "$final_path/$folder_name.m3u" "$final_path/$final_name.m3u"
                   fi
                   
                   if [ -f "$RES_DIR/$folder_name.png" ]; then
                       mv "$RES_DIR/$folder_name.png" "$RES_DIR/$final_name.png"
                   fi
               fi
           fi
       done
   fi
   
   remove_sort_mode="false"
   sort_applied="false"
   
   rm -f "$mapping_file"
   kill $loading_pid 2>/dev/null
   ./show_message "Changes applied successfully." -l a
}

show_options_menu() {
   echo "Sort A-Z|alpha" > "/tmp/sort_options.txt"
   echo "Manual Reorder|manual" >> "/tmp/sort_options.txt" 
   echo "Remove Sort|remove" >> "/tmp/sort_options.txt"
   echo "Rename|rename" >> "/tmp/sort_options.txt"
   
   current_line=$((${1:-0} + 1))
   
   picker_output=$(./picker "/tmp/sort_options.txt" -a "SELECT" -b "CANCEL")
   picker_status=$?
   
   if [ $picker_status -ne 0 ]; then
       return 0
   fi
   
   sort_method=$(echo "$picker_output" | cut -d'|' -f2)
   case "$sort_method" in
       "rename") 
           rename_emulator "$current_line" 
           ;;
       "alpha") 
           sort_alphabetical 
           sort_applied="true"
           ;;
       "manual") 
           manual_reorder 
           sort_applied="true"
           ;;
       "remove") 
           remove_sort 
           sort_applied="true"
           ;;
   esac
   
   return 0
}

main() {
   cleanup
   get_rom_folders
   remove_sort_mode="false"
   sort_applied="false"
   
   current_idx=0
   while true; do
       update_display_list
       
       picker_output=$(./picker "$DISPLAY_LIST" -i $current_idx -y "OPTIONS" -a "SAVE" -b "CANCEL")
       picker_status=$?
       
       current_line=$(grep -n "^${picker_output%$'\n'}$" "$DISPLAY_LIST" | cut -d: -f1)
       [ -z "$current_line" ] && current_line=1
       current_idx=$((current_line - 1))
       
       if [ $picker_status -eq 2 ]; then
           if [ "$sort_applied" = "true" ]; then
               ./show_message "Exit without saving changes?" -l -a "YES" -b "NO"
           else
               ./show_message "Exit without changes?" -l -a "YES" -b "NO"
           fi
           
           if [ $? -eq 0 ]; then
               cleanup
               exit 0
           else
               continue
           fi
       elif [ $picker_status -eq 0 ]; then
           apply_sort_order
           cleanup
           exit 0
       elif [ $picker_status -eq 4 ]; then
           show_options_menu "$current_idx"
       fi
   done
}

main