#!/bin/sh
cd "$(dirname "$0")"
cd ..
FINISHED_FILE="./finished_games.txt"
if [ ! -f "$FINISHED_FILE" ]; then
    echo "Finished Games|__HEADER__|header" > "$FINISHED_FILE"
fi
cleanup() {
    rm -f /tmp/keyboard_output.txt
    rm -f /tmp/picker_output.txt
    rm -f /tmp/search_results.txt
    rm -f /tmp/add_finished.txt
    rm -f /tmp/remove_list.txt
    rm -f /tmp/finished_list.txt
    rm -f /tmp/recent_list.txt
    rm -f /tmp/finished_menu.txt
    rm -f /tmp/finished_temp.txt
    rm -f /tmp/options_list.txt
    rm -f /tmp/entry_options.txt
}

get_system_code() {
    local rom_path="$1"
    local rom_folder_path=$(dirname "$rom_path")
    local rom_folder_name=$(basename "$rom_folder_path")
    local rom_parent_dir=$(dirname "$rom_folder_path")
    
    if [ "$rom_parent_dir" = "/mnt/SDCARD/Roms" ]; then
        echo "$rom_folder_name" | sed -n 's/.*(\([^)]*\)).*/\1/p'
    else
        echo "$(basename "$rom_parent_dir")" | sed -n 's/.*(\([^)]*\)).*/\1/p'
    fi
}

get_clean_system() {
    local rom_path="$1"
    local rom_folder_path=$(dirname "$rom_path")
    local rom_folder_name=$(basename "$rom_folder_path")
    local rom_parent_dir=$(dirname "$rom_folder_path")
    if [ "$rom_parent_dir" = "/mnt/SDCARD/Roms" ]; then
        echo "$rom_folder_name" | sed -E 's/^[0-9]+[)\._ -]+//g' | sed 's/ *([^)]*)//g' | sed 's/^ *//;s/ *$//'
    else
        echo "$(basename "$rom_parent_dir")" | sed -E 's/^[0-9]+[)\._ -]+//g' | sed 's/ *([^)]*)//g' | sed 's/^ *//;s/ *$//'
    fi
}

add_finished_game() {
    add_menu_idx=0
    while true; do
        > /tmp/add_finished.txt
        echo "Recents|recent" >> /tmp/add_finished.txt
        echo "Browse|browse" >> /tmp/add_finished.txt
        echo "Search|search" >> /tmp/add_finished.txt
        picker_output=$(./picker "/tmp/add_finished.txt" -i $add_menu_idx)
        picker_status=$?
        [ $picker_status -ne 0 ] && break
        add_menu_idx=$(grep -n "^${picker_output%$'\n'}$" /tmp/add_finished.txt | cut -d: -f1)
        add_menu_idx=$((add_menu_idx - 1))
        add_method=$(echo "$picker_output" | cut -d'|' -f2)
        case "$add_method" in
            recent)
                RECENT_FILE="/mnt/SDCARD/.userdata/shared/.minui/recent.txt"
                if [ ! -f "$RECENT_FILE" ]; then
                    ./show_message "No recents found." -l a
                    continue
                fi
                > /tmp/recent_list.txt
                while IFS= read -r line; do
                    if echo "$line" | grep -q "\.sh\|\.m3u\|(GS)\|GAMESWITCHER"; then
                        continue
                    fi
                    candidate="/mnt/SDCARD$(echo "$line" | cut -f1)"
                    candidate_name=$(basename "$candidate" | sed 's/\.[^.]*$//')
                    echo "$candidate_name|$candidate" >> /tmp/recent_list.txt
                done < "$RECENT_FILE"
                selected_rom=$(./picker "/tmp/recent_list.txt" | cut -d'|' -f2)
                [ -z "$selected_rom" ] && continue
                ;;
            browse)
                selected_rom=$(./directory "/mnt/SDCARD/Roms")
                [ -z "$selected_rom" ] && continue
                ;;
            search)
                search_term=$(./keyboard)
                [ -z "$search_term" ] && continue
                ./show_message "Searching for '$search_term'" -l &
                find /mnt/SDCARD/Roms -iname "*${search_term}*" | while read path; do
                    name=$(basename "$path")
                    echo "$name|$path"
                done > /tmp/search_results.txt
                killall show_message
                selected_rom=$(./picker "/tmp/search_results.txt" | cut -d'|' -f2)
                [ -z "$selected_rom" ] && continue
                ;;
        esac
        game_name=$(basename "$selected_rom")
        clean_name=$(echo "$game_name" | sed 's/([^)]*)//g' | sed 's/\.[^.]*$//' | tr '_' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        system_code=$(get_system_code "$selected_rom")
        
        ./show_message "Add \"$clean_name\"?|to Finished Games?" -l -a "YES" -b "NO"
        if [ $? -eq 0 ]; then
            DATE_FINISHED="$(date +%-m-%-d-%y)"
            display_name="[$DATE_FINISHED] $clean_name"
            echo "$display_name|$selected_rom|$system_code|1|0|$DATE_FINISHED|launch|0" >> "$FINISHED_FILE"
            ./show_message "\"$clean_name\" added|to Finished Games." -l a
            cleanup
            break
        fi
    done
}

view_game_details() {
    local game_data="$1"
    
    display_name=$(echo "$game_data" | cut -d'|' -f1)
    rom_path=$(echo "$game_data" | cut -d'|' -f2)
    system_code=$(echo "$game_data" | cut -d'|' -f3)
    finished_date=$(echo "$game_data" | cut -d'|' -f6)
    
    game_name=$(echo "$display_name" | sed 's/^\[[^]]*\] //')
    
    # Use the get_clean_system function for consistent system name display
    system_name=$(get_clean_system "$rom_path")
    
    ./show_message "$game_name|System: $system_name||Finished Date: $finished_date" -l a
}

remove_finished_game() {
    local game_data="$1"
    
    display_name=$(echo "$game_data" | cut -d'|' -f1)
    path=$(echo "$game_data" | cut -d'|' -f2)
    
    full_match="${display_name}|${path}|"
    
    game_name=$(echo "$display_name" | sed 's/^\[[^]]*\] //')
    
    ./show_message "Remove \"$game_name\"?|from Finished Games?" -l -a "YES" -b "NO"
    if [ $? -eq 0 ]; then
        header_line=$(head -n1 "$FINISHED_FILE")
        echo "$header_line" > /tmp/finished_temp.txt
        
        grep -v "$full_match" "$FINISHED_FILE" | grep -v "^$header_line$" >> /tmp/finished_temp.txt
        
        if [ $(wc -l < /tmp/finished_temp.txt) -eq 0 ]; then
            echo "$header_line" > /tmp/finished_temp.txt
        fi
        
        mv /tmp/finished_temp.txt "$FINISHED_FILE"
        ./show_message "\"$game_name\" removed." -l a
    fi
}

launch_game() {
    local rom_path="$1"
    CURRENT_PATH=$(dirname "$rom_path")
    ROM_FOLDER_NAME=$(basename "$CURRENT_PATH")
    ROM_PLATFORM=""
    
    while [ -z "$ROM_PLATFORM" ]; do
        [ "$ROM_FOLDER_NAME" = "Roms" ] && { ROM_PLATFORM="UNK"; break; }
        ROM_PLATFORM=$(echo "$ROM_FOLDER_NAME" | sed -n 's/.*(\(.*\)).*/\1/p')
        [ -z "$ROM_PLATFORM" ] && { CURRENT_PATH=$(dirname "$CURRENT_PATH"); ROM_FOLDER_NAME=$(basename "$CURRENT_PATH"); }
    done
    
    PLATFORM="$(basename "$(dirname "$(dirname "$0")")")"
    
    if [ -d "/mnt/SDCARD/Emus/$PLATFORM/$ROM_PLATFORM.pak" ]; then
        EMULATOR="/mnt/SDCARD/Emus/$PLATFORM/$ROM_PLATFORM.pak/launch.sh"
        "$EMULATOR" "$rom_path"
    elif [ -d "/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$ROM_PLATFORM.pak" ]; then
        EMULATOR="/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$ROM_PLATFORM.pak/launch.sh"
        "$EMULATOR" "$rom_path"
    else
        ./show_message "Emulator not found for $ROM_PLATFORM" -l a
        return 1
    fi
    return 0
}

clear_finished_games() {
    result=$(./show_message "Clear Finished List?|Clears only your finished list." -l -a "YES" -b "BACK")
    if [ $? -eq 0 ]; then
        echo "Finished Games|__HEADER__|header" > "$FINISHED_FILE"
        ./show_message "List cleared." -l a
        return 1
    fi
}

export_finished_games() {
    finished_list=$(tail -n +2 "$FINISHED_FILE")
    if [ -z "$finished_list" ]; then
        ./show_message "No Data Available|No finished games to export." -l a
        return
    fi
    ./show_message "Export Finished Games?|This will save your finished games list to a text file.|Continue?" -l -a "YES" -b "NO"
    if [ $? -eq 0 ]; then
        EXPORT_DIR="/mnt/SDCARD/GTT_Stats"
        mkdir -p "$EXPORT_DIR"
        EXPORT_FILE="$EXPORT_DIR/finished_games_$(date +%-m-%-d-%y).txt"
        {
            echo "FINISHED GAMES"
            echo "Generated: $(date +%-m-%-d-%y)"
            echo "----------------------------------------"
            printf "%-30s | %-10s | %s\n" "Game" "Completed" "ROM Path"
            echo "----------------------------------------"
            tail -n +2 "$FINISHED_FILE" | while IFS='|' read -r display_name path system play_count time_secs date action last_session; do
                game_name=$(echo "$display_name" | sed 's/^\[[^]]*\] //')
                printf "%-30s | %-10s | %s\n" "$game_name" "$date" "$path"
            done
        } > "$EXPORT_FILE"
        ./show_message "Finished Games Exported!|File saved to GTT_Stats folder" -l a
    fi
}

create_options_list() {
    > /tmp/options_list.txt
    echo "Add Game|add" >> /tmp/options_list.txt
    echo "Export List|export" >> /tmp/options_list.txt
    echo "Clear List|clear" >> /tmp/options_list.txt
}

show_options_menu() {
    local game_data="$1"
    local return_to_options=true
    while $return_to_options; do
        create_options_list
        options_output=$(./picker "/tmp/options_list.txt" -b "BACK")
        options_status=$?
        [ $options_status -eq 1 ] || [ -z "$options_output" ] && return
        if [ $options_status -eq 0 ] && [ -n "$options_output" ]; then
            option_action=$(echo "$options_output" | cut -d'|' -f2)
            case "$option_action" in
                add) add_finished_game ;;
                export) export_finished_games ;;
                clear) 
                    clear_finished_games
                    return_to_options=false
                    ;;
            esac
        fi
    done
}

migrate_data_format() {
    [ ! -f "$FINISHED_FILE" ] && return
    [ $(wc -l < "$FINISHED_FILE") -le 1 ] && return
    
    sample_line=$(tail -n1 "$FINISHED_FILE")
    field_count=$(echo "$sample_line" | tr '|' '\n' | wc -l)
    
    if [ "$field_count" -ne 8 ]; then
        echo "Migrating data format to be compatible with boxart display..."
        local temp_file="/tmp/migrate_finished.txt"
        head -n 1 "$FINISHED_FILE" > "$temp_file"
        
        tail -n +2 "$FINISHED_FILE" | while IFS='|' read -r name path date_old; do
            if [ "$field_count" -eq 3 ]; then
                system_code=$(get_system_code "$path")
                date="$date_old"
                display_name="[$date] $name"
                echo "$display_name|$path|$system_code|1|0|$date|launch|0" >> "$temp_file"
            elif [ "$field_count" -eq 6 ]; then
                system_code="$system"
                date="$date_old"
                display_name="[$date] $name"
                echo "$display_name|$path|$system_code|1|0|$date|launch|0" >> "$temp_file"
            fi
        done
        
        mv "$temp_file" "$FINISHED_FILE"
        echo "Data format migration complete."
    fi
}

trap cleanup EXIT

migrate_data_format

menu_idx=0
while true; do
    picker_output=$(./game_picker "$FINISHED_FILE" -i $menu_idx -y "OPTIONS" -b "BACK")
    picker_status=$?
    
    if [ -n "$picker_output" ]; then
        menu_idx=$(grep -n "^${picker_output%$'\n'}$" "$FINISHED_FILE" | cut -d: -f1 || echo "0")
        menu_idx=$((menu_idx - 1))
        [ $menu_idx -lt 0 ] && menu_idx=0
    fi
    
    [ $picker_status -eq 1 ] || [ $picker_status -eq 2 ] && cleanup && exit 0
    
    if [ $picker_status -eq 0 ]; then
        if echo "$picker_output" | grep -q "^Finished Games|"; then
            show_options_menu "$picker_output"
        else
            view_game_details "$picker_output"
        fi
    elif [ $picker_status -eq 3 ]; then
        if ! echo "$picker_output" | grep -q "^Finished Games|"; then
            rom_path=$(echo "$picker_output" | cut -d'|' -f2)
            if [ -f "$rom_path" ]; then
                launch_game "$rom_path"
            else
                ./show_message "Game file not found|$rom_path" -l a
            fi
        fi
    elif [ $picker_status -eq 4 ]; then
        if echo "$picker_output" | grep -q "^Finished Games|"; then
            show_options_menu "$picker_output"
        else
            > /tmp/entry_options.txt
            echo "View Details|view" >> /tmp/entry_options.txt
            echo "Remove Game|remove" >> /tmp/entry_options.txt
            
            entry_option=$(./picker "/tmp/entry_options.txt" -b "BACK")
            entry_status=$?
            
            if [ $entry_status -eq 0 ] && [ -n "$entry_option" ]; then
                entry_action=$(echo "$entry_option" | cut -d'|' -f2)
                
                case "$entry_action" in
                    view) view_game_details "$picker_output" ;;
                    remove) remove_finished_game "$picker_output" ;;
                esac
            fi
        fi
    fi
done