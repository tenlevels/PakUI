#!/bin/sh
cd "$(dirname "$0")"
cd ..
GTT_LIST="./gtt_list.txt"
if [ ! -f "$GTT_LIST" ]; then
    ./show_message "GTT list not found" -l a
    exit 1
fi
> /tmp/sort_menu.txt
echo "Sort by Name (A-Z)|name" > /tmp/sort_menu.txt
echo "Sort by Play Time|playtime" >> /tmp/sort_menu.txt
echo "Sort by System|system" >> /tmp/sort_menu.txt
sort_selection=$(./picker "/tmp/sort_menu.txt" -b "BACK")
sort_option=$(echo "$sort_selection" | cut -d'|' -f2)
[ -z "$sort_option" ] && exit 0
sort_by_name() {
    temp_file="/tmp/gtt_sorted.txt"
    
    header=$(head -n 1 "$GTT_LIST")
    echo "$header" > "$temp_file"
    
    temp_sort="/tmp/gtt_sort_temp.txt"
    > "$temp_sort"
    
    tail -n +2 "$GTT_LIST" | while IFS= read -r line; do
        display_name=$(echo "$line" | cut -d'|' -f1)
        clean_name=$(echo "$display_name" | sed 's/^\[[^]]*\] //')
        echo "$clean_name|$line" >> "$temp_sort"
    done
    
    sort -t'|' -k1,1 "$temp_sort" | cut -d'|' -f2- >> "$temp_file"
    
    mv "$temp_file" "$GTT_LIST"
    
    ./show_message "Games sorted alphabetically (A-Z)" -t 1
}
sort_by_playtime() {
    temp_file="/tmp/gtt_sorted.txt"
    
    header=$(head -n 1 "$GTT_LIST")
    echo "$header" > "$temp_file"
    
    tail -n +2 "$GTT_LIST" | sort -t'|' -k5,5nr >> "$temp_file"
    
    mv "$temp_file" "$GTT_LIST"
    
    ./show_message "Games sorted by play time" -t 1
}
get_clean_system() {
    local rom_path="$1"
    local rom_folder_path=$(dirname "$rom_path")
    local rom_folder_name=$(basename "$rom_folder_path")
    local rom_parent_dir=$(dirname "$rom_folder_path")
    
    if [ "$rom_parent_dir" = "/mnt/SDCARD/Roms" ]; then
        system_raw="$rom_folder_name"
    else
        system_raw=$(basename "$rom_parent_dir")
    fi
    
    echo "$system_raw" | sed -E 's/^[0-9]+[)\._ -]+//g' | sed 's/ *([^)]*)//g' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}
sort_by_system() {
    temp_file="/tmp/gtt_sorted.txt"
    
    header=$(head -n 1 "$GTT_LIST")
    echo "$header" > "$temp_file"
    
    temp_system="/tmp/gtt_with_system.txt"
    > "$temp_system"
    
    tail -n +2 "$GTT_LIST" | while read -r line; do
        rom_path=$(echo "$line" | cut -d'|' -f2)
        clean_system=$(get_clean_system "$rom_path")
        echo "$clean_system|$line" >> "$temp_system"
    done
    
    sort "$temp_system" | cut -d'|' -f2- >> "$temp_file"
    
    mv "$temp_file" "$GTT_LIST"
    
    ./show_message "Games sorted by system" -t 1
}
case "$sort_option" in
    "name")
        sort_by_name
        ;;
    "playtime")
        sort_by_playtime
        ;;
    "system")
        sort_by_system
        ;;
esac
rm -f /tmp/sort_menu.txt /tmp/gtt_sort_temp.txt /tmp/gtt_with_system.txt
exit 0