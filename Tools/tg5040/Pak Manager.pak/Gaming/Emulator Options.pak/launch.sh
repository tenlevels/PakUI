#!/bin/sh
export LD_LIBRARY_PATH="/usr/lib:$LD_LIBRARY_PATH"
SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"
CONFIG_FILE="/mnt/SDCARD/Emus/$PLATFORM/core.txt"
FILTERED_CONFIG="$SCRIPT_DIR/filtered_core.txt"
TEMP_MENU="/tmp/emu_menu.txt"
MAIN_MENU="/tmp/emu_main_menu.txt"
SYSTEM_MENU="/tmp/emu_system_menu.txt"
PICKER_OUTPUT="/tmp/picker_output.txt"
ROM_DIR="/mnt/SDCARD/Roms"
PAK_BASE_DIR="/mnt/SDCARD/.system/$PLATFORM/paks/Emus"
ADDON_PAK_DIR="/mnt/SDCARD/Emus/$PLATFORM"
DEBUG_FILE="$SCRIPT_DIR/emu_debug.txt"
GAME_SETTINGS_MENU="/tmp/emu_game_settings_menu.txt"

SELECTED_ROM=""
ROM_PLATFORM=""

cleanup() {
    rm -f "$PICKER_OUTPUT"
}

get_folder_display_name() {
    local section="$1"
    folder=$(find "$ROM_DIR" -maxdepth 1 -type d -name "*($section)" | head -n 1)
    if [ -n "$folder" ]; then
        folder_name=$(basename "$folder")
        if echo "$folder_name" | grep -qE "^[0-9]+[)\._ -]+"; then
            folder_name=$(echo "$folder_name" | sed -E 's/^[0-9]+[)\._ -]+//')
        fi
        folder_name=$(echo "$folder_name" | sed -E "s/ *\($section\)$//")
        echo "$folder_name"
    else
        echo "$section"
    fi
}

get_game_switcher_state() {
    local section="$1"
    local core_setting=""
    local in_section=0
    while IFS= read -r line; do
        case "$line" in
            "[""$section""]") in_section=1 ;;
            "["*) in_section=0 ;;
            gameswitcher=*)
                if [ $in_section -eq 1 ]; then
                    core_setting="${line#gameswitcher=}"
                    break
                fi
            ;;
        esac
    done < "$CONFIG_FILE"
    if [ -n "$core_setting" ]; then
        echo "$core_setting"
    else
        echo "OFF"
    fi
}

toggle_game_switcher_state() {
    local section="$1"
    local new_state="$2"
    local success=0
    local in_section=0
    local found=0
    local temp_file="/tmp/gs_temp.txt"
    > "$temp_file"
    while IFS= read -r line; do
        case "$line" in
            "[""$section""]")
                in_section=1
                echo "$line" >> "$temp_file"
            ;;
            "["*)
                in_section=0
                echo "$line" >> "$temp_file"
            ;;
            gameswitcher=*)
                if [ $in_section -eq 1 ]; then
                    echo "gameswitcher=$new_state" >> "$temp_file"
                    found=1
                else
                    echo "$line" >> "$temp_file"
                fi
            ;;
            *)
                echo "$line" >> "$temp_file"
                if [ $in_section -eq 1 ] && [ "$line" = "" ] && [ $found -eq 0 ]; then
                    echo "gameswitcher=$new_state" >> "$temp_file"
                    found=1
                fi
            ;;
        esac
    done < "$CONFIG_FILE"
    if [ $found -eq 0 ]; then
        if ! grep -q "\[$section\]" "$CONFIG_FILE"; then
            echo "" >> "$temp_file"
            echo "[$section]" >> "$temp_file"
            echo "gameswitcher=$new_state" >> "$temp_file"
        else
            local new_temp="/tmp/gs_temp2.txt"
            > "$new_temp"
            in_section=0
            while IFS= read -r line; do
                echo "$line" >> "$new_temp"
                if [ "$line" = "[$section]" ]; then
                    echo "gameswitcher=$new_state" >> "$new_temp"
                fi
            done < "$temp_file"
            mv "$new_temp" "$temp_file"
        fi
    fi
    mv "$temp_file" "$CONFIG_FILE"
    if grep -q "gameswitcher=$new_state" "$CONFIG_FILE"; then
        success=1
    fi
    create_filtered_config
    if [ $success -eq 1 ]; then
        ./show_message "GameSwitcher set to $new_state" -t 2
    else
        ./show_message "Failed to update GameSwitcher state" -t 2
    fi
}

is_valid_rom() {
    local file="$1"
    if echo "$file" | grep -qiE '\.png$'; then
        folder=$(dirname "$file")
        if echo "$folder" | grep -qi "pico"; then
            return 0
        fi
    fi
    if echo "$file" | grep -qiE '\.(txt|log|cfg|ini)$'; then
        return 1
    fi
    if echo "$file" | grep -qiE '\.(jpg|jpeg|png|bmp|gif|tiff|webp)$'; then
        return 1
    fi
    if echo "$file" | grep -qiE '\.(xml|json|md|html|css|js|map)$'; then
        return 1
    fi
    return 0
}

folder_has_roms() {
    local folder="$1"
    for f in "$folder"/*; do
        if [ -f "$f" ] && is_valid_rom "$f"; then
            return 0
        fi
    done
    return 1
}

should_exclude_folder() {
    local folder="$1"
    local name=$(basename "$folder")
    if echo "$name" | grep -qiE '\(CUSTOM\)|\(RND\)|\(GS\)|\(BITPAL\)'; then
        return 0
    fi
    if echo "$folder" | grep -qi "GAMESWITCHER"; then
        return 0
    fi
    if ! folder_has_roms "$folder"; then
        return 0
    fi
    return 1
}

create_filtered_config() {
    > "$FILTERED_CONFIG"
    local include_section=0 buffer="" last_comment="" current_section
    while IFS= read -r line; do
        case "$line" in
            \#*)
                last_comment="$line"
            ;;
            \[*\])
                [ $include_section -eq 1 ] && echo "$buffer" >> "$FILTERED_CONFIG" && echo "" >> "$FILTERED_CONFIG"
                current_section="${line#\[}"; current_section="${current_section%\]}"
                local folder
                folder=$(find "$ROM_DIR" -maxdepth 1 -type d -name "*($current_section)" | head -n 1)
                local pak_exists=0
                local emu_launcher="$ADDON_PAK_DIR/$current_section.pak/launch.sh"
                if [ -f "$emu_launcher" ]; then
                    pak_exists=1
                fi
                local should_include=1
                if [ -z "$folder" ] || should_exclude_folder "$folder" || [ $pak_exists -ne 1 ]; then
                    should_include=0
                fi
                if [ $should_include -eq 1 ]; then
                    include_section=1
                    buffer="$last_comment"$'\n'"$line"
                else
                    include_section=0
                    buffer=""
                fi
                last_comment=""
            ;;
            *)
                [ $include_section -eq 1 ] && buffer="$buffer"$'\n'"$line"
            ;;
        esac
    done < "$CONFIG_FILE"
    [ $include_section -eq 1 ] && echo "$buffer" >> "$FILTERED_CONFIG"
}

update_core_order_in_file() {
    local file="$1" section="$2" new_core="$3"
    local temp_file="/tmp/core_temp.txt"
    awk -v section="$section" -v new_core="$new_core" '
    BEGIN { in_section=0; core_count=0; processed=0 }
    /^\[/ {
        if ($0 ~ "\\[" section "\\]") { in_section=1; print; next } else { in_section=0 }
    }
    in_section && /^core[0-9]*=/ {
        old=$0
        sub(/^core[0-9]*=/,"",old)
        if (!processed) { print "core1=" new_core; processed=1 }
        if (old != new_core) {
            core_count++
            print "core" (core_count+1) "=" old
        }
        next
    }
    { print }
    ' "$file" > "$temp_file"
    mv "$temp_file" "$file"
}

update_core_order() {
    update_core_order_in_file "$FILTERED_CONFIG" "$1" "$2"
    update_core_order_in_file "$CONFIG_FILE" "$1" "$2"
}

create_main_menu() {
    > "$MAIN_MENU"
    echo "Global Options|global|options" >> "$MAIN_MENU"
    echo "System Options|systems|options" >> "$MAIN_MENU"
    echo "Per-Game Settings|per_game|options" >> "$MAIN_MENU"
}

create_system_menu() {
    > "$SYSTEM_MENU"
    while IFS= read -r line; do
        line="${line%%$'\r'}"
        [ -z "$line" ] && continue
        if [ "${line:0:1}" = "[" ]; then
            local section="${line#\[}"; section="${section%\]}"
            if [ -n "$section" ]; then
                local display_name=$(get_folder_display_name "$section")
                echo "$display_name|section|$section" >> "$SYSTEM_MENU"
            fi
        fi
    done < "$FILTERED_CONFIG"
}

create_global_menu() {
    > "$TEMP_MENU"
    echo "Apply RetroArch to All|retroarch_all|global" >> "$TEMP_MENU"
    echo "Apply minarch to All|minarch_all|global" >> "$TEMP_MENU"
    echo "Apply GameSwitcher ON to All|gs_on_all|global" >> "$TEMP_MENU"
    echo "Apply GameSwitcher OFF to All|gs_off_all|global" >> "$TEMP_MENU"
}

apply_launcher_to_all() {
    local launcher="$1"
    local total_count=0
    local updated_count=0
    local section=""
    ./show_message "Applying $launcher to all emulators..." &
    loading_pid=$!
    while IFS= read -r line; do
        line="${line%%$'\r'}"
        [ -z "$line" ] && continue
        if [ "${line:0:1}" = "[" ]; then
            section=$(echo "$line" | sed 's/^\[//' | sed 's/\]$//')
            if [ -n "$section" ]; then
                total_count=$((total_count + 1))
                local current_launcher=""
                local in_section=0
                while IFS= read -r config_line; do
                    case "$config_line" in
                        "[""$section""]") in_section=1 ;;
                        "["*) in_section=0 ;;
                        launcher=*)
                            if [ $in_section -eq 1 ]; then
                                current_launcher="${config_line#launcher=}"
                                break
                            fi
                        ;;
                    esac
                done < "$FILTERED_CONFIG"
                if [ "$current_launcher" != "$launcher" ]; then
                    update_config "$section" "launcher" "$launcher"
                    updated_count=$((updated_count + 1))
                fi
            fi
        fi
    done < "$FILTERED_CONFIG"
    kill $loading_pid 2>/dev/null
    ./show_message "$launcher applied to $updated_count emulators." -l -a "OK"
}

apply_gameswitcher_to_all() {
    local gs_state="$1"
    local total_count=0
    local updated_count=0
    local section=""
    ./show_message "Setting GameSwitcher $gs_state for all emulators..." &
    loading_pid=$!
    while IFS= read -r line; do
        line="${line%%$'\r'}"
        [ -z "$line" ] && continue
        if [ "${line:0:1}" = "[" ]; then
            section=$(echo "$line" | sed 's/^\[//' | sed 's/\]$//')
            if [ -n "$section" ]; then
                total_count=$((total_count + 1))
                update_config "$section" "gameswitcher" "$gs_state"
                updated_count=$((updated_count + 1))
            fi
        fi
    done < "$FILTERED_CONFIG"
    kill $loading_pid 2>/dev/null
    ./show_message "GameSwitcher $gs_state applied to $updated_count emulators." -l -a "OK"
}

create_section_menu() {
    local section="$1"
    > "$TEMP_MENU"
    local current_launcher="" current_core="" current_section=""
    local game_switcher_state=$(get_game_switcher_state "$section")
    while IFS= read -r line; do
        case "$line" in
            "["*)
                current_section="${line#\[}"; current_section="${current_section%\]}"
            ;;
            launcher=*)
                [ "$current_section" = "$section" ] && current_launcher="${line#launcher=}"
            ;;
            core1=*)
                [ "$current_section" = "$section" ] && current_core="${line#core1=}"
            ;;
        esac
    done < "$FILTERED_CONFIG"
    echo "Launcher: $current_launcher|launcher|$section" >> "$TEMP_MENU"
    echo "Core: $current_core|core|$section" >> "$TEMP_MENU"
    if [ -z "$game_switcher_state" ]; then
        game_switcher_state="OFF"
    fi
    echo "GameSwitcher: $game_switcher_state|gameswitcher|$section" >> "$TEMP_MENU"
}

create_launcher_menu() {
    local section="$1"
    > "$TEMP_MENU"
    local in_section=0 current_launcher=""
    while IFS= read -r line; do
        case "$line" in
            "[""$section""]") in_section=1 ;;
            "["*) in_section=0 ;;
            launcher=*) [ $in_section -eq 1 ] && current_launcher="${line#launcher=}" ;;
        esac
    done < "$FILTERED_CONFIG"
    if [ "$current_launcher" = "retroarch" ]; then
        echo "RetroArch|retroarch|$section" >> "$TEMP_MENU"
        echo "minarch|minarch|$section" >> "$TEMP_MENU"
    elif [ "$current_launcher" = "minarch" ]; then
        echo "minarch|minarch|$section" >> "$TEMP_MENU"
        echo "RetroArch|retroarch|$section" >> "$TEMP_MENU"
    else
        echo "$current_launcher|$current_launcher|$section" >> "$TEMP_MENU"
        echo "RetroArch|retroarch|$section" >> "$TEMP_MENU"
        echo "minarch|minarch|$section" >> "$TEMP_MENU"
    fi
}

create_core_menu() {
    local section="$1"
    > "$TEMP_MENU"
    local in_section=0 current_core=""
    
    while IFS= read -r line; do
        case "$line" in
            "[""$section""]") in_section=1 ;;
            "["*) in_section=0 ;;
            core1=*) 
                if [ $in_section -eq 1 ]; then
                    current_core="${line#core1=}"
                    break
                fi
            ;;
        esac
    done < "$FILTERED_CONFIG"
    
    in_section=0
    local seen_cores=""
    while IFS= read -r line; do
        case "$line" in
            "[""$section""]") in_section=1 ;;
            "["*) in_section=0 ;;
            core[0-9]*=*)
                if [ $in_section -eq 1 ]; then
                    local core_num=$(echo "$line" | grep -o "core[0-9]*=" | sed 's/core//' | sed 's/=//')
                    local val=$(echo "$line" | cut -d'=' -f2)
                    val="${val%%[![:print:]]*}"
                    
                    # Check if we've already seen this core to avoid duplicates
                    if ! echo "$seen_cores" | grep -q "|$val|"; then
                        seen_cores="$seen_cores|$val|"
                        echo "$val|$val|$section" >> "$TEMP_MENU"
                    fi
                fi
            ;;
        esac
    done < "$FILTERED_CONFIG"
    
    if [ -n "$current_core" ] && ! grep -q "|$current_core|" "$TEMP_MENU"; then
        echo "$current_core|$current_core|$section" >> "$TEMP_MENU"
    fi
}

create_gameswitcher_menu() {
    local section="$1"
    local current_state=$(get_game_switcher_state "$section")
    > "$TEMP_MENU"
    if [ "$current_state" = "ON" ]; then
        echo "ON|ON|$section" >> "$TEMP_MENU"
        echo "OFF|OFF|$section" >> "$TEMP_MENU"
    else
        echo "OFF|OFF|$section" >> "$TEMP_MENU"
        echo "ON|ON|$section" >> "$TEMP_MENU"
    fi
}

update_config() {
    local section="$1" key="$2" value="$3"
    if [ "$key" = "core1" ]; then
        update_core_order "$section" "$value"
        return
    fi
    if ! grep -q "\[$section\]" "$CONFIG_FILE"; then
        echo "" >> "$CONFIG_FILE"
        echo "[$section]" >> "$CONFIG_FILE"
        echo "$key=$value" >> "$CONFIG_FILE"
        if ! grep -q "\[$section\]" "$FILTERED_CONFIG"; then
            echo "" >> "$FILTERED_CONFIG"
            echo "[$section]" >> "$FILTERED_CONFIG"
            echo "$key=$value" >> "$FILTERED_CONFIG"
        fi
        return
    fi
    local temp_file="/tmp/core_temp.txt" in_section=0 setting_found=0
    > "$temp_file"
    while IFS= read -r line; do
        case "$line" in
            "[""$section""]")
                in_section=1
                echo "$line" >> "$temp_file"
            ;;
            "["*)
                if [ $in_section -eq 1 ] && [ $setting_found -eq 0 ]; then
                    echo "$key=$value" >> "$temp_file"
                    setting_found=1
                fi
                in_section=0
                echo "$line" >> "$temp_file"
            ;;
            *)
                if [ $in_section -eq 1 ] && [[ $line == $key=* ]]; then
                    echo "$key=$value" >> "$temp_file"
                    setting_found=1
                else
                    echo "$line" >> "$temp_file"
                fi
            ;;
        esac
    done < "$FILTERED_CONFIG"
    if [ $in_section -eq 1 ] && [ $setting_found -eq 0 ]; then
        echo "$key=$value" >> "$temp_file"
    fi
    mv "$temp_file" "$FILTERED_CONFIG"
    temp_file="/tmp/core_temp.txt"
    > "$temp_file"
    in_section=0
    setting_found=0
    while IFS= read -r line; do
        case "$line" in
            "[""$section""]")
                in_section=1
                echo "$line" >> "$temp_file"
            ;;
            "["*)
                if [ $in_section -eq 1 ] && [ $setting_found -eq 0 ]; then
                    echo "$key=$value" >> "$temp_file"
                    setting_found=1
                fi
                in_section=0
                echo "$line" >> "$temp_file"
            ;;
            *)
                if [ $in_section -eq 1 ] && [[ $line == $key=* ]]; then
                    echo "$key=$value" >> "$temp_file"
                    setting_found=1
                else
                    echo "$line" >> "$temp_file"
                fi
            ;;
        esac
    done < "$CONFIG_FILE"
    if [ $in_section -eq 1 ] && [ $setting_found -eq 0 ]; then
        echo "$key=$value" >> "$temp_file"
    fi
    mv "$temp_file" "$CONFIG_FILE"
}

create_per_game_menu() {
    > "$TEMP_MENU"
    echo "Browse|browse" >> "$TEMP_MENU"
    echo "Search|search" >> "$TEMP_MENU"
    echo "Recents|recent" >> "$TEMP_MENU"
    echo "Manage Existing|manage_existing" >> "$TEMP_MENU"
}

detect_rom_platform() {
    local rom_path="$1"
    local rom_platform=""
    local rom_parent_path
    local rom_folder_name
    rom_parent_path=$(dirname "$rom_path")
    rom_folder_name=$(basename "$rom_parent_path")
    while [ -z "$rom_platform" ]; do
        if [ "$rom_folder_name" = "Roms" ]; then
            rom_platform="UNK"
            break
        fi
        rom_platform=$(echo "$rom_folder_name" | sed -n 's/.*(\(.*\)).*/\1/p')
        if [ -z "$rom_platform" ]; then
            rom_parent_path=$(dirname "$rom_parent_path")
            rom_folder_name=$(basename "$rom_parent_path")
        fi
    done
    echo "$rom_platform"
}

get_emulator_setting() {
    local section="$1"
    local key="$2"
    sed -n "/^\[$section\]/,/^\[/p" "$CONFIG_FILE" | grep "^$key=" | cut -d'=' -f2
}

folder_has_valid_roms() {
    local dir="$1"
    for f in "$dir"/*; do
        if [ -f "$f" ] && is_valid_rom "$f"; then
            return 0
        fi
    done
    return 1
}

handle_per_game_settings() {
    local per_game_menu_idx=0
    while true; do
        create_per_game_menu
        picker_output=$("$SCRIPT_DIR/picker" "$TEMP_MENU" -i $per_game_menu_idx)
        picker_status=$?
        if [ $picker_status -eq 0 ]; then
            per_game_menu_idx=$(grep -n "^${picker_output%$'\n'}$" "$TEMP_MENU" | cut -d: -f1)
            per_game_menu_idx=$((per_game_menu_idx - 1))
        else
            return
        fi
        per_game_method=$(echo "$picker_output" | cut -d'|' -f2)
        case "$per_game_method" in
            "browse")
                local filtered_dirs="/tmp/filtered_rom_dirs.txt"
                > "$filtered_dirs"
                for dir in "$ROM_DIR"/*; do
                    if [ -d "$dir" ] && ! should_exclude_folder "$dir"; then
                        clean_name=$(basename "$dir" | sed -E 's/^[0-9]+[)\._ -]+//; s/ *\([^)]*\)$//')
                        echo "$clean_name|$dir" >> "$filtered_dirs"
                    fi
                done
                if [ ! -s "$filtered_dirs" ]; then
                    "$SCRIPT_DIR/show_message" "No ROM directories found" -l -t 2
                    continue
                fi
                selected_dir=$("$SCRIPT_DIR/picker" "$filtered_dirs")
                [ -z "$selected_dir" ] && continue
                selected_dir_path=$(echo "$selected_dir" | cut -d'|' -f2)
                selected_rom=$("$SCRIPT_DIR/directory" "$selected_dir_path")
                [ -z "$selected_rom" ] && continue
                SELECTED_ROM="$selected_rom"
                ROM_PLATFORM=$(detect_rom_platform "$SELECTED_ROM")
                handle_game_settings "$SELECTED_ROM" "$ROM_PLATFORM"
            ;;
            "search")
                search_term=$("$SCRIPT_DIR/keyboard")
                [ -z "$search_term" ] && continue
                "$SCRIPT_DIR/show_message" "Searching for $search_term" -l -t 1
                find /mnt/SDCARD/Roms -iname "*${search_term}*" | while read path; do
                    if [ -f "$path" ] && is_valid_rom "$path" && ! echo "$path" | grep -q "GAMESWITCHER"; then
                        name=$(basename "$path")
                        name_clean=$(echo "$name" | sed -E 's/\.[^.]*$//; s/^[0-9]+[)\._ -]+//; s/ *\([^)]*\)$//')
                        echo "$name_clean|$path"
                    fi
                done > /tmp/search_results.txt
                if [ ! -s /tmp/search_results.txt ]; then
                    "$SCRIPT_DIR/show_message" "No results found for '$search_term'" -l -t 2
                    continue
                fi
                search_selection=$("$SCRIPT_DIR/picker" "/tmp/search_results.txt")
                [ -z "$search_selection" ] && continue
                SELECTED_ROM=$(echo "$search_selection" | cut -d'|' -f2)
                ROM_PLATFORM=$(detect_rom_platform "$SELECTED_ROM")
                handle_game_settings "$SELECTED_ROM" "$ROM_PLATFORM"
            ;;
            "recent")
                RECENT_FILE="/mnt/SDCARD/.userdata/shared/.minui/recent.txt"
                if [ ! -f "$RECENT_FILE" ]; then
                    "$SCRIPT_DIR/show_message" "No recents found" -l -t 2
                    continue
                fi
                > /tmp/recent_list.txt
                while IFS= read -r line; do
                    if echo "$line" | grep -q '\.sh\|\.m3u\|(GS)\|GAMESWITCHER'; then
                        continue
                    fi
                    candidate="/mnt/SDCARD$(echo "$line" | cut -f1)"
                    if [ -f "$candidate" ] && is_valid_rom "$candidate" ]; then
                        candidate_name=$(basename "$candidate")
                        candidate_clean=$(echo "$candidate_name" | sed -E 's/\.[^.]*$//; s/^[0-9]+[)\._ -]+//; s/ *\([^)]*\)$//')
                        echo "$candidate_clean|$candidate" >> /tmp/recent_list.txt
                    fi
                done < "$RECENT_FILE"
                if [ ! -s /tmp/recent_list.txt ]; then
                    "$SCRIPT_DIR/show_message" "No recents found" -l -t 2
                    continue
                fi
                recents_selection=$("$SCRIPT_DIR/picker" "/tmp/recent_list.txt")
                [ -z "$recents_selection" ] && continue
                SELECTED_ROM=$(echo "$recents_selection" | cut -d'|' -f2)
                ROM_PLATFORM=$(detect_rom_platform "$SELECTED_ROM")
                handle_game_settings "$SELECTED_ROM" "$ROM_PLATFORM"
            ;;
            "manage_existing")
                handle_manage_existing_settings
            ;;
        esac
    done
}

handle_manage_existing_settings() {
    local temp_list="/tmp/existing_games.txt"
    > "$temp_list"
    
    # Search for game settings across all platform paks
    for pak_dir in "$ADDON_PAK_DIR"/*; do
        [ ! -d "$pak_dir" ] && continue
        basename_pak=$(basename "$pak_dir")
        if echo "$basename_pak" | grep -qiE '\(CUSTOM\)|\(RND\)|\(BITPAL\)'; then
            continue
        fi
        
        # Extract platform code from pak name
        platform_code=$(echo "$basename_pak" | sed 's/\.pak//')
        
        # Check if game_settings directory exists
        game_settings_dir="$pak_dir/game_settings"
        [ ! -d "$game_settings_dir" ] && continue
        
        # List all game settings
        for conf in "$game_settings_dir"/*.conf; do
            [ ! -f "$conf" ] && continue
            game_name=$(basename "$conf" .conf)
            clean_name=$(echo "$game_name" | sed -E 's/^[0-9]+[)\._ -]+//; s/ *\([^)]*\)$//')
            echo "$clean_name|$conf|$platform_code" >> "$temp_list"
        done
    done
    
    if [ ! -s "$temp_list" ]; then
        "$SCRIPT_DIR/show_message" "No existing game settings found" -l -t 2
        return
    fi
    
    selection=$("$SCRIPT_DIR/picker" "$temp_list")
    [ -z "$selection" ] && return
    
    selected_conf=$(echo "$selection" | cut -d'|' -f2)
    selected_platform=$(echo "$selection" | cut -d'|' -f3)
    
    handle_existing_game_settings "$selected_conf" "$selected_platform"
}
handle_existing_game_settings() {
    local config_file="$1"
    local rom_platform="$2"
    local menu_idx=0
    
    while true; do
        create_existing_game_settings_menu "$config_file" "$rom_platform"
        sel=$("$SCRIPT_DIR/picker" "$GAME_SETTINGS_MENU" -i $menu_idx)
        [ -z "$sel" ] && break
        
        menu_idx=$(grep -n "^${sel%$'\n'}$" "$GAME_SETTINGS_MENU" | cut -d: -f1)
        menu_idx=$((menu_idx - 1))
        
        action=$(echo "$sel" | cut -d'|' -f2)
        
        case "$action" in
            "game_launcher")
                create_game_launcher_menu_existing "$config_file" "$rom_platform"
                launcher_sel=$("$SCRIPT_DIR/picker" "$TEMP_MENU")
                [ -z "$launcher_sel" ] && continue
                launcher_choice=$(echo "$launcher_sel" | cut -d'|' -f2)
                update_existing_game_setting "$config_file" "launcher" "$launcher_choice"
            ;;
            "game_core")
                create_game_core_menu_existing "$config_file" "$rom_platform"
                core_sel=$("$SCRIPT_DIR/picker" "$TEMP_MENU")
                [ -z "$core_sel" ] && continue
                core_choice=$(echo "$core_sel" | cut -d'|' -f2)
                update_existing_game_setting "$config_file" "core" "$core_choice"
            ;;
            "game_gameswitcher")
                create_game_gameswitcher_menu_existing "$config_file" "$rom_platform"
                gs_sel=$("$SCRIPT_DIR/picker" "$TEMP_MENU")
                [ -z "$gs_sel" ] && continue
                gs_choice=$(echo "$gs_sel" | cut -d'|' -f2)
                update_existing_game_setting "$config_file" "gameswitcher" "$gs_choice"
            ;;
            "remove_game_settings")
                rm -f "$config_file"
                "$SCRIPT_DIR/show_message" "Game settings removed" -t 1
                break
            ;;
        esac
    done
}

create_existing_game_settings_menu() {
    local config_file="$1"
    local rom_platform="$2"
    local game_name=$(basename "$config_file" .conf)
    local clean_name=$(echo "$game_name" | sed -E 's/^[0-9]+[)\._ -]+//; s/ *\([^)]*\)$//')
    > "$GAME_SETTINGS_MENU"
    echo "Game: $clean_name|header|none" >> "$GAME_SETTINGS_MENU"
    if [ -f "$config_file" ]; then
        game_launcher=$(grep "^launcher=" "$config_file" | cut -d'=' -f2)
        game_core=$(grep "^core=" "$config_file" | cut -d'=' -f2)
        gameswitcher_state=$(grep "^gameswitcher=" "$config_file" | cut -d'=' -f2)
        if [ -n "$game_launcher" ]; then
            echo "Launcher: $game_launcher|game_launcher|none" >> "$GAME_SETTINGS_MENU"
        else
            echo "Launcher: (Use system default)|game_launcher|none" >> "$GAME_SETTINGS_MENU"
        fi
        if [ -n "$game_core" ]; then
            echo "Core: $game_core|game_core|none" >> "$GAME_SETTINGS_MENU"
        else
            echo "Core: (Use system default)|game_core|none" >> "$GAME_SETTINGS_MENU"
        fi
        if [ -n "$gameswitcher_state" ]; then
            echo "GameSwitcher: $gameswitcher_state|game_gameswitcher|none" >> "$GAME_SETTINGS_MENU"
        else
            echo "GameSwitcher: (Use system default)|game_gameswitcher|none" >> "$GAME_SETTINGS_MENU"
        fi
        echo "Remove Game Settings|remove_game_settings|none" >> "$GAME_SETTINGS_MENU"
    else
        echo "Launcher: (Use system default)|game_launcher|none" >> "$GAME_SETTINGS_MENU"
        echo "Core: (Use system default)|game_core|none" >> "$GAME_SETTINGS_MENU"
        echo "GameSwitcher: (Use system default)|game_gameswitcher|none" >> "$GAME_SETTINGS_MENU"
    fi
}

update_existing_game_setting() {
    local config_file="$1"
    local key="$2"
    local value="$3"
    if [ "$value" = "default" ]; then
        if grep -q "^$key=" "$config_file"; then
            grep -v "^$key=" "$config_file" > "/tmp/game_conf.tmp"
            mv "/tmp/game_conf.tmp" "$config_file"
        fi
        return
    fi
    if grep -q "^$key=" "$config_file"; then
        sed -i "s|^$key=.*|$key=$value|" "$config_file"
    else
        echo "$key=$value" >> "$config_file"
    fi
}

create_game_launcher_menu_existing() {
    local config_file="$1"
    local rom_platform="$2"
    > "$TEMP_MENU"
    system_launcher=$(get_emulator_setting "$rom_platform" "launcher")
    [ -z "$system_launcher" ] && system_launcher="retroarch"
    echo "System Default ($system_launcher)|default|none" >> "$TEMP_MENU"
    current_launcher=$(grep "^launcher=" "$config_file" | cut -d'=' -f2)
    if [ "$current_launcher" = "retroarch" ]; then
        echo "RetroArch|retroarch|none" >> "$TEMP_MENU"
        echo "minarch|minarch|none" >> "$TEMP_MENU"
    elif [ "$current_launcher" = "minarch" ]; then
        echo "minarch|minarch|none" >> "$TEMP_MENU"
        echo "RetroArch|retroarch|none" >> "$TEMP_MENU"
    elif [ -n "$current_launcher" ]; then
        echo "$current_launcher|$current_launcher|none" >> "$TEMP_MENU"
        echo "RetroArch|retroarch|none" >> "$TEMP_MENU"
        echo "minarch|minarch|none" >> "$TEMP_MENU"
    else
        echo "RetroArch|retroarch|none" >> "$TEMP_MENU"
        echo "minarch|minarch|none" >> "$TEMP_MENU"
    fi
}

create_game_core_menu_existing() {
    local config_file="$1"
    local rom_platform="$2"
    > "$TEMP_MENU"
    system_core=$(get_emulator_setting "$rom_platform" "core1")
    [ -z "$system_core" ] && system_core="(none)"
    echo "System Default ($system_core)|default|none" >> "$TEMP_MENU"
    current_core=$(grep "^core=" "$config_file" | cut -d'=' -f2)
    
    # Get cores from the platform section in core.txt
    local in_section=0
    while IFS= read -r line; do
        case "$line" in
            "["$rom_platform"]") in_section=1 ;;
            "["*) in_section=0 ;;
            core[0-9]*=*)
                if [ $in_section -eq 1 ]; then
                    local val=$(echo "$line" | sed 's/core[0-9]*=//')
                    val="${val%%[![:print:]]*}"
                    if [ "$val" = "$current_core" ]; then
                        echo "Current: $val|$val|none" >> "$TEMP_MENU"
                    elif [ "$val" != "$system_core" ]; then
                        echo "$val|$val|none" >> "$TEMP_MENU"
                    fi
                fi
            ;;
        esac
    done < "$CONFIG_FILE"
    
    if [ -n "$current_core" ] && ! grep -q "|$current_core|" "$TEMP_MENU"; then
        echo "$current_core|$current_core|none" >> "$TEMP_MENU"
    fi
}

create_game_gameswitcher_menu_existing() {
    local config_file="$1"
    local rom_platform="$2"
    > "$TEMP_MENU"
    system_state=$(get_game_switcher_state "$rom_platform")
    echo "System Default ($system_state)|default|none" >> "$TEMP_MENU"
    current_state=$(grep "^gameswitcher=" "$config_file" | cut -d'=' -f2)
    if [ "$current_state" = "ON" ]; then
        echo "ON|ON|none" >> "$TEMP_MENU"
        echo "OFF|OFF|none" >> "$TEMP_MENU"
    elif [ "$current_state" = "OFF" ]; then
        echo "OFF|OFF|none" >> "$TEMP_MENU"
        echo "ON|ON|none" >> "$TEMP_MENU"
    else
        echo "ON|ON|none" >> "$TEMP_MENU"
        echo "OFF|OFF|none" >> "$TEMP_MENU"
    fi
}

handle_game_settings() {
    local rom_path="$1"
    local rom_platform="$2"
    local game_menu_idx=0
    create_game_settings_menu "$rom_path" "$rom_platform"
    while true; do
        game_option=$("$SCRIPT_DIR/picker" "$GAME_SETTINGS_MENU" -i $game_menu_idx)
        if [ -z "$game_option" ]; then
            break
        fi
        game_menu_idx=$(grep -n "^${game_option%$'\n'}$" "$GAME_SETTINGS_MENU" | cut -d: -f1)
        game_menu_idx=$((game_menu_idx - 1))
        game_action=$(echo "$game_option" | cut -d'|' -f2)
        game_rom=$(echo "$game_option" | cut -d'|' -f3)
        case "$game_action" in
            "game_launcher")
                create_game_launcher_menu "$game_rom" "$rom_platform"
                launcher_sel=$("$SCRIPT_DIR/picker" "$TEMP_MENU")
                [ -z "$launcher_sel" ] && continue
                launcher_choice=$(echo "$launcher_sel" | cut -d'|' -f2)
                update_game_setting "$game_rom" "$rom_platform" "launcher" "$launcher_choice"
                create_game_settings_menu "$rom_path" "$rom_platform"
            ;;
            "game_core")
                create_game_core_menu "$game_rom" "$rom_platform"
                core_sel=$("$SCRIPT_DIR/picker" "$TEMP_MENU")
                [ -z "$core_sel" ] && continue
                core_choice=$(echo "$core_sel" | cut -d'|' -f2)
                update_game_setting "$game_rom" "$rom_platform" "core" "$core_choice"
                create_game_settings_menu "$rom_path" "$rom_platform"
            ;;
            "game_gameswitcher")
                create_game_gameswitcher_menu "$game_rom" "$rom_platform"
                gs_sel=$("$SCRIPT_DIR/picker" "$TEMP_MENU")
                [ -z "$gs_sel" ] && continue
                gs_choice=$(echo "$gs_sel" | cut -d'|' -f2)
                update_game_setting "$game_rom" "$rom_platform" "gameswitcher" "$gs_choice"
                create_game_settings_menu "$rom_path" "$rom_platform"
            ;;
            "remove_game_settings")
                remove_game_settings "$game_rom" "$rom_platform"
                create_game_settings_menu "$rom_path" "$rom_platform"
            ;;
        esac
    done
}

create_game_settings_menu() {
    local rom_path="$1"
    local rom_platform="$2"
    local rom_name
    rom_name=$(basename "$rom_path")
    local rom_name_clean="${rom_name%.*}"
    local game_config_dir="/mnt/SDCARD/Emus/$PLATFORM/$rom_platform.pak/game_settings"
    local game_config="$game_config_dir/$rom_name_clean.conf"
    > "$GAME_SETTINGS_MENU"
    echo "Game: $rom_name_clean|header|none" >> "$GAME_SETTINGS_MENU"
    if [ -f "$game_config" ]; then
        game_launcher=$(grep "^launcher=" "$game_config" | cut -d'=' -f2)
        game_core=$(grep "^core=" "$game_config" | cut -d'=' -f2)
        gameswitcher_state=$(grep "^gameswitcher=" "$game_config" | cut -d'=' -f2)
        if [ -n "$game_launcher" ]; then
            echo "Launcher: $game_launcher|game_launcher|$rom_path" >> "$GAME_SETTINGS_MENU"
        else
            echo "Launcher: (Use system default)|game_launcher|$rom_path" >> "$GAME_SETTINGS_MENU"
        fi
        if [ -n "$game_core" ]; then
            echo "Core: $game_core|game_core|$rom_path" >> "$GAME_SETTINGS_MENU"
        else
            echo "Core: (Use system default)|game_core|$rom_path" >> "$GAME_SETTINGS_MENU"
        fi
        if [ -n "$gameswitcher_state" ]; then
            echo "GameSwitcher: $gameswitcher_state|game_gameswitcher|$rom_path" >> "$GAME_SETTINGS_MENU"
        else
            echo "GameSwitcher: (Use system default)|game_gameswitcher|$rom_path" >> "$GAME_SETTINGS_MENU"
        fi
        echo "Remove Game Settings|remove_game_settings|$rom_path" >> "$GAME_SETTINGS_MENU"
    else
        echo "Launcher: (Use system default)|game_launcher|$rom_path" >> "$GAME_SETTINGS_MENU"
        echo "Core: (Use system default)|game_core|$rom_path" >> "$GAME_SETTINGS_MENU"
        echo "GameSwitcher: (Use system default)|game_gameswitcher|$rom_path" >> "$GAME_SETTINGS_MENU"
    fi
}

create_game_launcher_menu() {
    local rom_path="$1"
    local rom_platform="$2"
    local rom_name
    rom_name=$(basename "$rom_path")
    local rom_name_clean="${rom_name%.*}"
    local game_config_dir="/mnt/SDCARD/Emus/$PLATFORM/$rom_platform.pak/game_settings"
    local game_config="$game_config_dir/$rom_name_clean.conf"
    > "$TEMP_MENU"
    local current_launcher=""
    if [ -f "$game_config" ]; then
        current_launcher=$(grep "^launcher=" "$game_config" | cut -d'=' -f2)
    fi
    local system_launcher
    system_launcher=$(get_emulator_setting "$rom_platform" "launcher")
    [ -z "$system_launcher" ] && system_launcher="retroarch"
    echo "System Default ($system_launcher)|default|$rom_path" >> "$TEMP_MENU"
    if [ "$current_launcher" = "retroarch" ]; then
        echo "RetroArch|retroarch|$rom_path" >> "$TEMP_MENU"
        echo "minarch|minarch|$rom_path" >> "$TEMP_MENU"
    elif [ "$current_launcher" = "minarch" ]; then
        echo "minarch|minarch|$rom_path" >> "$TEMP_MENU"
        echo "RetroArch|retroarch|$rom_path" >> "$TEMP_MENU"
    elif [ -n "$current_launcher" ]; then
        echo "Current: $current_launcher|$current_launcher|$rom_path" >> "$TEMP_MENU"
        echo "RetroArch|retroarch|$rom_path" >> "$TEMP_MENU"
        echo "minarch|minarch|$rom_path" >> "$TEMP_MENU"
    else
        echo "RetroArch|retroarch|$rom_path" >> "$TEMP_MENU"
        echo "minarch|minarch|$rom_path" >> "$TEMP_MENU"
    fi
}

create_game_core_menu() {
    local rom_path="$1"
    local rom_platform="$2"
    local rom_name
    rom_name=$(basename "$rom_path")
    local rom_name_clean="${rom_name%.*}"
    local game_config_dir="/mnt/SDCARD/Emus/$PLATFORM/$rom_platform.pak/game_settings"
    local game_config="$game_config_dir/$rom_name_clean.conf"
    > "$TEMP_MENU"
    
    # Get system core
    local system_core
    system_core=$(get_emulator_setting "$rom_platform" "core1")
    [ -z "$system_core" ] && system_core="(none)"
    
    # Add system default option
    echo "System Default ($system_core)|default|$rom_path" >> "$TEMP_MENU"
    
    # Check for current game core
    local current_core=""
    if [ -f "$game_config" ]; then
        current_core=$(grep "^core=" "$game_config" | cut -d'=' -f2)
    fi
    
    # List all cores for this platform from core.txt
    local in_section=0
    while IFS= read -r line; do
        case "$line" in
            "["$rom_platform"]") in_section=1 ;;
            "["*) in_section=0 ;;
            core[0-9]*=*)
                if [ $in_section -eq 1 ]; then
                    local val=$(echo "$line" | sed 's/core[0-9]*=//')
                    val="${val%%[![:print:]]*}"
                    if [ "$val" = "$current_core" ]; then
                        echo "Current: $val|$val|$rom_path" >> "$TEMP_MENU"
                    else
                        echo "$val|$val|$rom_path" >> "$TEMP_MENU"
                    fi
                fi
            ;;
        esac
    done < "$CONFIG_FILE"
    
    # Add current core if it's not among the listed cores
    if [ -n "$current_core" ] && ! grep -q "|$current_core|" "$TEMP_MENU"; then
        echo "Current: $current_core|$current_core|$rom_path" >> "$TEMP_MENU"
    fi
}

create_game_gameswitcher_menu() {
    local rom_path="$1"
    local rom_platform="$2"
    local rom_name
    rom_name=$(basename "$rom_path")
    local rom_name_clean="${rom_name%.*}"
    local game_config_dir="/mnt/SDCARD/Emus/$PLATFORM/$rom_platform.pak/game_settings"
    local game_config="$game_config_dir/$rom_name_clean.conf"
    > "$TEMP_MENU"
    local current_state=""
    if [ -f "$game_config" ]; then
        current_state=$(grep "^gameswitcher=" "$game_config" | cut -d'=' -f2)
    fi
    local system_state
    system_state=$(get_game_switcher_state "$rom_platform")
    echo "System Default ($system_state)|default|$rom_path" >> "$TEMP_MENU"
    if [ "$current_state" = "ON" ]; then
        echo "Current: ON|ON|$rom_path" >> "$TEMP_MENU"
        echo "OFF|OFF|$rom_path" >> "$TEMP_MENU"
    elif [ "$current_state" = "OFF" ]; then
        echo "Current: OFF|OFF|$rom_path" >> "$TEMP_MENU"
        echo "ON|ON|$rom_path" >> "$TEMP_MENU"
    else
        echo "ON|ON|$rom_path" >> "$TEMP_MENU"
        echo "OFF|OFF|$rom_path" >> "$TEMP_MENU"
    fi
}

update_game_setting() {
    local rom_path="$1"
    local rom_platform="$2"
    local key="$3"
    local value="$4"
    local rom_name
    rom_name=$(basename "$rom_path")
    local rom_name_clean="${rom_name%.*}"
    local game_config_dir="/mnt/SDCARD/Emus/$PLATFORM/$rom_platform.pak/game_settings"
    local game_config="$game_config_dir/$rom_name_clean.conf"
    if [ ! -d "$game_config_dir" ]; then
        mkdir -p "$game_config_dir"
    fi
    if [ ! -f "$game_config" ]; then
        touch "$game_config"
    fi
    if [ "$value" = "default" ]; then
        if grep -q "^$key=" "$game_config"; then
            grep -v "^$key=" "$game_config" > "/tmp/game_conf.tmp"
            mv "/tmp/game_conf.tmp" "$game_config"
        fi
        return
    fi
    if grep -q "^$key=" "$game_config"; then
        sed -i "s|^$key=.*|$key=$value|" "$game_config"
    else
        echo "$key=$value" >> "$game_config"
    fi
}

remove_game_settings() {
    local rom_path="$1"
    local rom_platform="$2"
    local rom_name
    rom_name=$(basename "$rom_path")
    local rom_name_clean="${rom_name%.*}"
    local game_config_dir="/mnt/SDCARD/Emus/$PLATFORM/$rom_platform.pak/game_settings"
    local game_config="$game_config_dir/$rom_name_clean.conf"
    if [ -f "$game_config" ]; then
        "$SCRIPT_DIR/show_message" "Remove custom settings for this game?" -l -a "Yes" -b "No"
        if [ $? -eq 0 ]; then
            rm -f "$game_config"
            "$SCRIPT_DIR/show_message" "Game settings removed" -t 1
        fi
    else
        "$SCRIPT_DIR/show_message" "No custom settings found" -t 1
    fi
}

# Main execution starts here
./show_message "Loading emulator configs..." &
create_filtered_config
create_main_menu
main_menu_idx=0
while true; do
    cp "$MAIN_MENU" "$TEMP_MENU"
    killall show_message 2>/dev/null
    emu_selection=$(./picker "$TEMP_MENU")
    [ -z "$emu_selection" ] && { cleanup; exit 0; }
    selection="$(echo "$emu_selection" | cut -d'|' -f2)"
    section="$(echo "$emu_selection" | cut -d'|' -f3)"
    
    if [ "$selection" = "global" ]; then
        create_global_menu
        global_opt=$(./picker "$TEMP_MENU")
        [ -z "$global_opt" ] && continue
        global_action="$(echo "$global_opt" | cut -d'|' -f2)"
        case "$global_action" in
            retroarch_all)
                ./show_message "Apply RetroArch to all?" -l -a "YES" -b "NO"
                if [ $? -eq 0 ]; then
                    apply_launcher_to_all "retroarch"
                fi
            ;;
            minarch_all)
                ./show_message "Apply minarch to all?" -l -a "YES" -b "NO"
                if [ $? -eq 0 ]; then
                    apply_launcher_to_all "minarch"
                fi
            ;;
            gs_on_all)
                ./show_message "Turn GameSwitcher ON for all?" -l -a "YES" -b "NO"
                if [ $? -eq 0 ]; then
                    apply_gameswitcher_to_all "ON"
                fi
            ;;
            gs_off_all)
                ./show_message "Turn GameSwitcher OFF for all?" -l -a "YES" -b "NO"
                if [ $? -eq 0 ]; then
                    apply_gameswitcher_to_all "OFF"
                fi
            ;;
        esac
        continue
    elif [ "$selection" = "systems" ]; then
        create_system_menu
        system_sel=$(./picker "$SYSTEM_MENU")
        [ -z "$system_sel" ] && continue
        selection="$(echo "$system_sel" | cut -d'|' -f2)"
        section="$(echo "$system_sel" | cut -d'|' -f3)"
    elif [ "$selection" = "per_game" ]; then
        handle_per_game_settings
        continue
    fi
    
    while [ "$selection" = "section" ]; do
        create_section_menu "$section"
        emu_option=$(./picker "$TEMP_MENU")
        [ -z "$emu_option" ] && break
        action="$(echo "$emu_option" | cut -d'|' -f2)"
        section="$(echo "$emu_option" | cut -d'|' -f3)"
        case "$action" in
            launcher)
                create_launcher_menu "$section"
                launcher_sel=$(./picker "$TEMP_MENU")
                [ -z "$launcher_sel" ] && continue
                update_config "$section" "launcher" "$(echo "$launcher_sel" | cut -d'|' -f2)"
            ;;
            core)
                create_core_menu "$section"
                core_sel=$(./picker "$TEMP_MENU")
                [ -z "$core_sel" ] && continue
                update_config "$section" "core1" "$(echo "$core_sel" | cut -d'|' -f2)"
            ;;
            gameswitcher)
                create_gameswitcher_menu "$section"
                gs_sel=$(./picker "$TEMP_MENU")
                [ -z "$gs_sel" ] && continue
                gs_state="$(echo "$gs_sel" | cut -d'|' -f2)"
                toggle_game_switcher_state "$section" "$gs_state"
            ;;
        esac
    done
done
cleanup