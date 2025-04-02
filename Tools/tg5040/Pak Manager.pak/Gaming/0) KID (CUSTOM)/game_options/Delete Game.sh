#!/bin/sh
if [ -z "$SELECTED_ITEM" ] || [ -z "$MENU" ]; then
    echo "Error: Required environment variables not set" >&2
    exit 1
fi
temp_file="/tmp/menu.$$"
name=$(basename "$SELECTED_ITEM")
clean_name=$(echo "$name" | sed 's/([^)]*)//g' | sed 's/\.[^.]*$//' | tr '_' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
display_name=$(echo "$SELECTED_ITEM" | cut -d'|' -f1)
./show_message "Remove|$display_name?" -l -a "YES" -b "NO"
if [ $? -ne 0 ]; then
    exit 0
fi
grep -v "^$SELECTED_ITEM$" "$MENU" > "$temp_file"
if [ $? -ne 0 ]; then
    rm -f "$temp_file"
    echo "Error: Failed to process menu file" >&2
    exit 1
fi
mv "$temp_file" "$MENU"
exit 0