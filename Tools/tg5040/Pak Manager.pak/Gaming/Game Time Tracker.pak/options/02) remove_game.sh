#!/bin/sh

cd "$(dirname "$0")"
cd ..
GTT_LIST="./gtt_list.txt"
if [ ! -f "$GTT_LIST" ]; then
    ./show_message "GTT list not found" -l a
    exit 1
fi

remove_game() {
    local game_entry="$1"
    
    display_name=$(echo "$game_entry" | cut -d'|' -f1)
    game_name=$(echo "$display_name" | sed 's/^\[[^]]*\] //')
    rom_path=$(echo "$game_entry" | cut -d'|' -f2)
    
    ./show_message "Remove $game_name|from Game Time Tracker?" -l -a "YES" -b "NO"
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    temp_file="/tmp/gtt_remove.txt"
    grep -v "|$rom_path|" "$GTT_LIST" > "$temp_file"
    
    mv "$temp_file" "$GTT_LIST"
    
    ./show_message "Removed $game_name" -t 1
    return 0
}

create_clean_game_list() {
    local temp_list="$1"
    local clean_list="/tmp/gtt_clean_games.txt"
    
    while IFS= read -r line; do
        display_name=$(echo "$line" | cut -d'|' -f1)
        clean_name=$(echo "$display_name" | sed 's/^\[[^]]*\] //')
        rest_of_line=$(echo "$line" | cut -d'|' -f2-)
        echo "$clean_name|$rest_of_line" >> "$clean_list"
    done < "$temp_list"
    
    mv "$clean_list" "$temp_list"
}

if [ -n "$1" ]; then
    remove_game "$1"
else
    temp_list="/tmp/gtt_game_list.txt"
    
    grep "|launch$" "$GTT_LIST" > "$temp_list"
    
    if [ ! -s "$temp_list" ]; then
        ./show_message "No games to remove" -l a
        rm -f "$temp_list"
        exit 0
    fi
    
    create_clean_game_list "$temp_list"
    
    selected_game=$(./picker "$temp_list" -b "EXIT")
    
    if [ -n "$selected_game" ]; then
        remove_game "$selected_game"
    fi
    
    rm -f "$temp_list"
fi
exit 0