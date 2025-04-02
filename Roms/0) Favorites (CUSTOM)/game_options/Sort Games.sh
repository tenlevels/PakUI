#!/bin/sh

CURRENT_DIR=$(basename "$(pwd)")
COLLECTION_NAME=$(echo "$CURRENT_DIR" | sed 's/ ([^)]*)//g' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

cleanup() {
   rm -f /tmp/sort_options.txt
   rm -f /tmp/menu.$$
   rm -f /tmp/reorder_list.txt
   rm -f /tmp/reorder_list.tmp
   rm -f /tmp/display_list.txt
}

sort_by_name() {
   head -n 1 "$MENU" > "/tmp/menu.$$"
   tail -n +2 "$MENU" | sort -f >> "/tmp/menu.$$"
   mv "/tmp/menu.$$" "$MENU"
   ./show_message "Games sorted alphabetically!" -l a
   return 0
}

sort_by_platform() {
   head -n 1 "$MENU" > "/tmp/menu.$$"
   tail -n +2 "$MENU" | while IFS='|' read -r name path launch; do
       platform=$(echo "$path" | sed -n 's|.*/Roms/\([^/]*\)/.*|\1|p')
       echo "$platform|$name|$path|$launch"
   done | sort -f | while IFS='|' read -r platform name path launch; do
       echo "$name|$path|$launch"
   done >> "/tmp/menu.$$"
   mv "/tmp/menu.$$" "$MENU"
   ./show_message "Games sorted by platform!" -l a
   return 0
}

swap_lines() {
   local file="$1"
   local line1="$2"
   local line2="$3"
   awk -v l1="$line1" -v l2="$line2" '{
       arr[NR] = $0
   }
   END {
       tmp = arr[l1]
       arr[l1] = arr[l2]
       arr[l2] = tmp
       for (i = 1; i <= NR; i++) {
           print arr[i]
       }
   }' "$file" > "/tmp/reorder_list.tmp" && mv "/tmp/reorder_list.tmp" "$file"
}

create_display_list() {
   > "/tmp/display_list.txt"
   while IFS='|' read -r name path launch; do
       echo "$name|$path|launch" >> "/tmp/display_list.txt"
   done < "/tmp/reorder_list.txt"
}

manual_reorder() {
   head -n 1 "$MENU" > "/tmp/menu.$$"
   tail -n +2 "$MENU" > "/tmp/reorder_list.txt"
   
   reorder_idx=0
   while true; do
       create_display_list
       
       picker_output=$(./picker "/tmp/display_list.txt" -i $reorder_idx -x "MOVE UP" -y "MOVE DOWN" -a "SAVE")
       picker_status=$?
       
       current_line=$(grep -n "^${picker_output%$'\n'}$" "/tmp/display_list.txt" | cut -d: -f1)
       [ -z "$current_line" ] && current_line=1
       reorder_idx=$((current_line - 1))
       
       case $picker_status in
           0)
               if [ ! -s "/tmp/reorder_list.txt" ]; then
                   ./show_message "Error: No games to save!" -l a
                   return 1
               fi
               
               ./show_message "Save new sort order?" -l -a "YES" -b "NO"
               if [ $? = 0 ]; then
                   if [ -s "/tmp/menu.$$" ] && [ -s "/tmp/reorder_list.txt" ]; then
                       cat "/tmp/reorder_list.txt" >> "/tmp/menu.$$"
                       mv "/tmp/menu.$$" "$MENU"
                       ./show_message "New order saved!" -l a
                       return 0
                   else
                       ./show_message "Error saving order!" -l a
                       return 1
                   fi
               fi
               ;;
           2)
               ./show_message "Sort canceled - no changes made" -l a
               return 0
               ;;
           3)
               if [ "$current_line" -gt 1 ]; then
                   swap_lines "/tmp/reorder_list.txt" "$current_line" "$((current_line - 1))"
                   reorder_idx=$((reorder_idx - 1))
               fi
               ;;
           4)
               total_lines=$(wc -l < "/tmp/reorder_list.txt")
               if [ "$current_line" -lt "$total_lines" ]; then
                   swap_lines "/tmp/reorder_list.txt" "$current_line" "$((current_line + 1))"
                   reorder_idx=$((reorder_idx + 1))
               fi
               ;;
       esac
   done
}

sort_menu_idx=0
while true; do
   echo "Building Sort $COLLECTION_NAME Menu"
   echo "Sort A-Z|name" > "/tmp/sort_options.txt"
   echo "Sort by Platform|platform" >> "/tmp/sort_options.txt"
   echo "Manual Sort|manual" >> "/tmp/sort_options.txt"
   
   picker_output=$(./picker "/tmp/sort_options.txt" -i $sort_menu_idx)
   picker_status=$?
   
   if [ $picker_status -ne 0 ]; then
       cleanup
       exit 0
   fi
   
   sort_menu_idx=$(grep -n "^${picker_output%$'\n'}$" "/tmp/sort_options.txt" | cut -d: -f1)
   sort_menu_idx=$((sort_menu_idx - 1))

   sort_method=$(echo "$picker_output" | cut -d'|' -f2)
   case "$sort_method" in
       "name")
           sort_by_name
           cleanup
           exit 0
           ;;
       "platform")
           sort_by_platform
           cleanup
           exit 0
           ;;
       "manual")
           manual_reorder
           cleanup
           exit 0
           ;;
   esac
done

cleanup
exit 0