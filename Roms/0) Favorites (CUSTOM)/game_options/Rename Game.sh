#!/bin/sh
if [ -z "$SELECTED_ITEM" ] || [ -z "$MENU" ]; then
   echo "Error: Required environment variables not set" >&2
   exit 1
fi
current_name=$(echo "$SELECTED_ITEM" | cut -d'|' -f1)
current_path=$(echo "$SELECTED_ITEM" | cut -d'|' -f2)
current_action=$(echo "$SELECTED_ITEM" | cut -d'|' -f3)
./show_message "Rename:|$current_name" -l -a "OK" -b "CANCEL"
if [ $? -ne 0 ]; then
   exit 0
fi
new_name=$(./keyboard)
if [ -z "$new_name" ]; then
   exit 0
fi
new_entry="$new_name|$current_path|$current_action"
temp_file="/tmp/menu.$$"
> "$temp_file"
while IFS= read -r line; do
   if [ "$line" = "$SELECTED_ITEM" ]; then
       echo "$new_entry" >> "$temp_file"
   else
       echo "$line" >> "$temp_file"
   fi
done < "$MENU"
mv "$temp_file" "$MENU"
exit 0