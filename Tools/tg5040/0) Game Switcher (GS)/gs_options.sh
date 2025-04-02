#!/bin/sh
SCRIPT_DIR="$(dirname "$0")"
EMULATOR_CONFIG="/mnt/SDCARD/Emus/$PLATFORM/core.txt"
TEMP_MENU="/tmp/gs_options_menu.txt"
EMU_MENU="/tmp/emu_menu.txt"
GAME_SETTINGS_MENU="/tmp/gs_game_settings_menu.txt"
ADD_GAME_MENU="/tmp/add_game_menu.txt"
DEFAULT_IMAGE="$SCRIPT_DIR/default.zip.0.bmp"

SELECTED_GAME="$1"
GAME_ORDER="$2"

##############################################################################
# Main Options Menu – now with an extra “Set Hotkey” entry.
##############################################################################
show_options_menu() {
    local options_menu_idx=0

    while true; do
        echo "Restart Game|restart" > "$TEMP_MENU"
        echo "Add Game|add" >> "$TEMP_MENU"
        echo "Remove Game|remove" >> "$TEMP_MENU"
        echo "Game Settings|game_settings" >> "$TEMP_MENU"
        echo "Emulator Options|emulator" >> "$TEMP_MENU"
        echo "Set Shortcut Button|set_hotkey" >> "$TEMP_MENU"
        echo "Clear Game Switcher|clear" >> "$TEMP_MENU"

        picker_output=$("$SCRIPT_DIR/picker" "$TEMP_MENU" -i $options_menu_idx)
        picker_status=$?

        if [ $picker_status -eq 0 ]; then
            options_menu_idx=$(grep -n "^${picker_output%$'\n'}$" "$TEMP_MENU" | cut -d: -f1)
            options_menu_idx=$((options_menu_idx - 1))
        else
            return
        fi

        action=$(echo "$picker_output" | cut -d'|' -f2)
        case "$action" in
            "restart")
                restart_game
                return
                ;;
            "add")
                handle_add_game
                return
                ;;
            "remove")
                remove_game "$SELECTED_GAME" || continue
                return
                ;;
            "game_settings")
                ROM_PLATFORM=$(detect_rom_platform "$SELECTED_GAME")
                handle_game_settings "$SELECTED_GAME" "$ROM_PLATFORM"
                ;;
            "emulator")
                ROM_PLATFORM=$(detect_rom_platform "$SELECTED_GAME")
                handle_emulator_options "$SELECTED_GAME" "$ROM_PLATFORM"
                ;;
            "set_hotkey")
                set_hotkey
                ;;
            "clear")
                clear_game_switcher
                return
                ;;
        esac
    done
}

##############################################################################
# set_hotkey - Complete solution with ignore_hotkey.txt handling
##############################################################################
set_hotkey() {
    local hotkey_menu="/tmp/hotkey_menu.txt"
    echo "OFF|OFF" > "$hotkey_menu"  # Added OFF option
    echo "MENU|MENU" >> "$hotkey_menu"
    echo "L2|L2" >> "$hotkey_menu"
    echo "R2|R2" >> "$hotkey_menu"
    echo "F1|F1" >> "$hotkey_menu"
    echo "F2|F2" >> "$hotkey_menu"

    # Setup auto.sh path
    [ -z "$PLATFORM" ] && \
    if [ -d "/mnt/SDCARD/.userdata/trimui" ]; then
        PLATFORM="trimui"
    elif [ -d "/mnt/SDCARD/.userdata/miyoo" ]; then
        PLATFORM="miyoo"
    else
        PLATFORM="trimui"
    fi
    
    local AUTO_DIR="/mnt/SDCARD/.userdata/$PLATFORM"
    local AUTO_PATH="$AUTO_DIR/auto.sh"
    local IGNORE_FILE="$SCRIPT_DIR/ignore_hotkey.txt"
    
    # Check if auto.sh exists, create if not
    mkdir -p "$AUTO_DIR"
    [ ! -f "$AUTO_PATH" ] && echo "#!/bin/sh" > "$AUTO_PATH" && chmod +x "$AUTO_PATH"

    # Check current hotkey setting
    local current_hotkey="F2"
    [ -f "$SCRIPT_DIR/hotkey.conf" ] && . "$SCRIPT_DIR/hotkey.conf" && current_hotkey="$HOTKEY"

    "$SCRIPT_DIR/show_message" "Current: $current_hotkey|Select shortcut button" -t 2
    new_hotkey=$("$SCRIPT_DIR/picker" "$hotkey_menu")

    if [ -n "$new_hotkey" ]; then
        new_choice=$(echo "$new_hotkey" | cut -d'|' -f2)
        
        # Different message based on current state and selection
        if [ "$current_hotkey" = "OFF" ] && [ "$new_choice" != "OFF" ]; then
            message_text="Enable shortcut $new_choice|Requires a reboot to take effect.|Reboot now?"
        elif [ "$current_hotkey" != "OFF" ] && [ "$new_choice" = "OFF" ]; then
            message_text="Disable shortcut|Requires a reboot to take effect.|Reboot now?"
        else
            message_text="Change shortcut to $new_choice|Requires a reboot to take effect.|Reboot now?"
        fi
        
        # Show the appropriate message
        "$SCRIPT_DIR/show_message" "$message_text" -l -a "Yes" -b "No"
        
        if [ $? -eq 0 ]; then
            # Update hotkey.conf first
            echo "HOTKEY=\"$new_choice\"" > "$SCRIPT_DIR/hotkey.conf"
            
            # Now handle auto.sh and ignore_hotkey.txt
            if [ "$new_choice" = "OFF" ]; then
                # Remove any line containing (GS) from auto.sh
                sed -i '/(GS)/d' "$AUTO_PATH"
                
                # Create ignore_hotkey.txt to disable monitoring
                touch "$IGNORE_FILE"
                
                "$SCRIPT_DIR/show_message" "Shortcut disabled|Rebooting..." -t 2
            else
                # Remove any existing GS entry to avoid duplicates
                sed -i '/(GS)/d' "$AUTO_PATH"
                
                # Add new line to auto.sh with (GS) tag
                echo "\"$SCRIPT_DIR/gs_monitor.sh\" # Game Switcher (GS)" >> "$AUTO_PATH"
                
                # Remove ignore_hotkey.txt if it exists
                [ -f "$IGNORE_FILE" ] && rm -f "$IGNORE_FILE"
                
                "$SCRIPT_DIR/show_message" "Shortcut set to $new_choice|Rebooting..." -t 2
            fi
            
            reboot
        else
            "$SCRIPT_DIR/show_message" "Shortcut change cancelled" -t 2
        fi
    else
        "$SCRIPT_DIR/show_message" "No shortcut selected" -t 2
    fi
}

##############################################################################
# Determine which launcher is used by a particular game.
##############################################################################
get_active_launcher_for_game() {
    local rom_path="$1"
    local rom_platform="$2"
    local game_config

    game_config=$(get_game_specific_settings "$rom_path" "$rom_platform")
    if [ $? -eq 0 ] && [ -n "$game_config" ]; then
        local game_launcher
        game_launcher=$(echo "$game_config" | cut -d'|' -f1)
        if [ "$game_launcher" = "retroarch" ] || [ "$game_launcher" = "minarch" ]; then
            echo "$game_launcher"
            return
        fi
    fi

    local system_launcher
    system_launcher=$(get_emulator_setting "$rom_platform" "launcher")
    [ -z "$system_launcher" ] && system_launcher="retroarch"
    echo "$system_launcher"
}

##############################################################################
# Restart game: clear saves/screenshots for the launcher in use.
##############################################################################
restart_game() {
    if [ -f "$SELECTED_GAME" ]; then
        ROM_PLATFORM=$(detect_rom_platform "$SELECTED_GAME")
        ROM_NAME=$(basename "$SELECTED_GAME")
        GAME_BASE_NAME="${ROM_NAME%.*}"
        local active_launcher
        active_launcher=$(get_active_launcher_for_game "$SELECTED_GAME" "$ROM_PLATFORM")

        if [ "$active_launcher" = "retroarch" ]; then
            rm -f /tmp/resume_slot.txt 2>/dev/null
            rm -f "/mnt/SDCARD/.userdata/shared/.minui/$ROM_PLATFORM/$ROM_NAME.txt" 2>/dev/null
            rm -f "/mnt/SDCARD/Tools/$PLATFORM/RetroArch.pak/.retroarch/states/${GAME_BASE_NAME}.state.auto.png" 2>/dev/null
            rm -f "/mnt/SDCARD/Tools/$PLATFORM/RetroArch.pak/.retroarch/states/${GAME_BASE_NAME}.state.auto" 2>/dev/null
        elif [ "$active_launcher" = "minarch" ]; then
            rm -f /tmp/resume_slot.txt 2>/dev/null
            rm -f "/mnt/SDCARD/.userdata/shared/.minui/$ROM_PLATFORM/$ROM_NAME.txt" 2>/dev/null
            local SLOT
            SLOT=$(find_save_slot "$SELECTED_GAME" "$ROM_PLATFORM")
            local game_config
            game_config=$(get_game_specific_settings "$SELECTED_GAME" "$ROM_PLATFORM")
            local core_name
            core_name=$(get_emulator_setting "$ROM_PLATFORM" "core1" | sed 's/_libretro\.so$//')
            if [ -n "$game_config" ] && echo "$game_config" | grep -q "^minarch"; then
                local game_core
                game_core=$(echo "$game_config" | cut -d'|' -f2 | sed 's/_libretro\.so$//')
                [ -n "$game_core" ] && core_name="$game_core"
            fi
            rm -f "/mnt/SDCARD/.userdata/shared/.minui/$ROM_PLATFORM/$ROM_NAME.$SLOT.bmp" 2>/dev/null
            rm -f "/mnt/SDCARD/.userdata/shared/$ROM_PLATFORM-$core_name/$ROM_NAME.st$SLOT" 2>/dev/null
        fi

        local temp_game_order="/tmp/gs_temp_restart.txt"
        grep -v "|$SELECTED_GAME|" "$GAME_ORDER" > "$temp_game_order"
        local display_name image_path launcher
        local entry_line
        entry_line=$(grep "|$SELECTED_GAME|" "$GAME_ORDER")
        display_name=$(echo "$entry_line" | cut -d'|' -f1)
        image_path=$(echo "$entry_line" | cut -d'|' -f2)
        launcher=$(echo "$entry_line" | cut -d'|' -f4)
        echo "$display_name|$image_path|$SELECTED_GAME|$launcher" > "$GAME_ORDER"
        cat "$temp_game_order" >> "$GAME_ORDER"
        rm -f "$temp_game_order"
        echo "$SELECTED_GAME" > "$SCRIPT_DIR/last_game.txt"
        exit 99
    else
        "$SCRIPT_DIR/show_message" "Game file not found: $SELECTED_GAME" -l -t 2
        return 1
    fi
}

##############################################################################
remove_game() {
    local to_remove="$1"
    if [ -z "$to_remove" ]; then
        return 1
    fi
    local name display_name
    name=$(basename "$to_remove")
    display_name=$(echo "$name" | sed 's/([^)]*)//g' | sed 's/\.[^.]*$//' | tr '_' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    "$SCRIPT_DIR/show_message" "Remove $display_name|from Game Switcher?" -l -a "Yes" -b "No"
    if [ $? -ne 0 ]; then
        return 1
    fi
    grep -v "|$to_remove" "$GAME_ORDER" > "/tmp/gs_temp.txt"
    if [ $? -eq 2 ]; then
        rm -f "/tmp/gs_temp.txt"
        return 1
    fi
    mv "/tmp/gs_temp.txt" "$GAME_ORDER"
    return 0
}

##############################################################################
clear_game_switcher() {
    "$SCRIPT_DIR/show_message" "Clear Game Switcher?|This will remove all games." -l -a "Yes" -b "No"
    if [ $? -ne 0 ]; then
        return 1
    fi
    > "$GAME_ORDER"
    "$SCRIPT_DIR/show_message" "Game Switcher cleared." -t 1
    return 0
}

##############################################################################
handle_add_game() {
    local add_menu_idx=0
    while true; do
        echo "Browse|browse" > "$ADD_GAME_MENU"
        echo "Search|search" >> "$ADD_GAME_MENU"
        echo "Recents|recent" >> "$ADD_GAME_MENU"
        picker_output=$("$SCRIPT_DIR/picker" "$ADD_GAME_MENU" -i $add_menu_idx)
        picker_status=$?
        if [ $picker_status -eq 0 ]; then
            add_menu_idx=$(grep -n "^${picker_output%$'\n'}$" "$ADD_GAME_MENU" | cut -d: -f1)
            add_menu_idx=$((add_menu_idx - 1))
        else
            return
        fi
        add_method=$(echo "$picker_output" | cut -d'|' -f2)
        case "$add_method" in
            "browse")
                selected_rom=$("$SCRIPT_DIR/directory" "/mnt/SDCARD/Roms")
                [ -z "$selected_rom" ] && continue
                add_game_via_browser "$selected_rom"
                return
                ;;
            "search")
                search_term=$("$SCRIPT_DIR/keyboard")
                [ -z "$search_term" ] && continue
                "$SCRIPT_DIR/show_message" "Searching for $search_term" -l -t 1
                find /mnt/SDCARD/Roms -iname "*${search_term}*" | while read path; do
                    if ! echo "$path" | grep -q "GAMESWITCHER"; then
                        name=$(basename "$path")
                        echo "$name|$path"
                    fi
                done > /tmp/search_results.txt
                if [ ! -s /tmp/search_results.txt ]; then
                    "$SCRIPT_DIR/show_message" "No results found for '$search_term'" -l -t 2
                    continue
                fi
                search_selection=$("$SCRIPT_DIR/picker" "/tmp/search_results.txt")
                [ -z "$search_selection" ] && continue
                selected_rom=$(echo "$search_selection" | cut -d'|' -f2)
                add_game_via_browser "$selected_rom"
                return
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
                    candidate_name=$(basename "$candidate" | sed 's/\.[^.]*$//')
                    echo "$candidate_name|$candidate" >> /tmp/recent_list.txt
                done < "$RECENT_FILE"
                if [ ! -s /tmp/recent_list.txt ]; then
                    "$SCRIPT_DIR/show_message" "No recents found" -l -t 2
                    continue
                fi
                recents_selection=$("$SCRIPT_DIR/picker" "/tmp/recent_list.txt")
                [ -z "$recents_selection" ] && continue
                selected_rom=$(echo "$recents_selection" | cut -d'|' -f2)
                add_game_via_browser "$selected_rom"
                return
                ;;
        esac
    done
}

##############################################################################
add_game_via_browser() {
    local rom_path="$1"
    if [ -z "$rom_path" ]; then
        return 1
    fi
    local name display_name
    name=$(basename "$rom_path")
    display_name=$(echo "$name" | sed 's/([^)]*)//g' | sed 's/\.[^.]*$//' | tr '_' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    "$SCRIPT_DIR/show_message" "Add $display_name|to Game Switcher?" -l -a "Yes" -b "No"
    if [ $? = 0 ]; then
        grep -v "|$rom_path" "$GAME_ORDER" > "/tmp/gs_temp.txt" 2>/dev/null || cp "$GAME_ORDER" "/tmp/gs_temp.txt"
        echo "$display_name|$DEFAULT_IMAGE|$rom_path" > "/tmp/gs_temp.new"
        cat "/tmp/gs_temp.txt" >> "/tmp/gs_temp.new"
        mv "/tmp/gs_temp.new" "$GAME_ORDER"
        ROM_PLATFORM=$(detect_rom_platform "$rom_path")
        update_game "$rom_path" "$ROM_PLATFORM"
    fi
    return 0
}

##############################################################################
update_game() {
    local rom_path="$1"
    local emu_tag="$2"
    if [ -z "$rom_path" ]; then
        return 1
    fi
    local name display_name
    name=$(basename "$rom_path")
    display_name=$(echo "$name" | sed 's/([^)]*)//g' | sed 's/\.[^.]*$//' | tr '_' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    local image_path="$DEFAULT_IMAGE"
    if [ -x "$SCRIPT_DIR/gs_image" ]; then
        image_path=$("$SCRIPT_DIR/gs_image" find_best "$rom_path" "$emu_tag" "$DEFAULT_IMAGE")
    else
        local save_slot minarch_image GAME_BASE_NAME ra_image
        save_slot=$(find_save_slot "$rom_path" "$emu_tag")
        minarch_image="/mnt/SDCARD/.userdata/shared/.minui/$emu_tag/$name.$save_slot.bmp"
        GAME_BASE_NAME="${name%.*}"
        ra_image="/mnt/SDCARD/Tools/$PLATFORM/RetroArch.pak/.retroarch/states/${GAME_BASE_NAME}.state.auto.png"
        if [ -f "$minarch_image" ] && [ -f "$ra_image" ]; then
            local minarch_time ra_time
            minarch_time=$(stat -c %Y "$minarch_image" 2>/dev/null || echo "0")
            ra_time=$(stat -c %Y "$ra_image" 2>/dev/null || echo "0")
            if [ "$minarch_time" -gt "$ra_time" ]; then
                image_path="$minarch_image"
            else
                image_path="$ra_image"
            fi
        elif [ -f "$minarch_image" ]; then
            image_path="$minarch_image"
        elif [ -f "$ra_image" ]; then
            image_path="$ra_image"
        fi
    fi
    local launcher="retroarch" existing_entry
    existing_entry=$(grep "|$rom_path|" "$GAME_ORDER")
    if [ -n "$existing_entry" ]; then
        launcher=$(echo "$existing_entry" | cut -d'|' -f4)
    fi
    grep -v "|$rom_path" "$GAME_ORDER" > "/tmp/gs_temp.txt" 2>/dev/null || cp "$GAME_ORDER" "/tmp/gs_temp.txt"
    echo "$display_name|$image_path|$rom_path|$launcher" > "/tmp/gs_temp.new"
    cat "/tmp/gs_temp.txt" >> "/tmp/gs_temp.new"
    mv "/tmp/gs_temp.new" "$GAME_ORDER"
    return 0
}

##############################################################################
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

##############################################################################
find_save_slot() {
    local rom_path="$1"
    local emu_tag="$2"
    local name
    name=$(basename "$rom_path")
    local slot
    slot=$(cat "/mnt/SDCARD/.userdata/shared/.minui/$emu_tag/$name.txt" 2>/dev/null || echo "0")
    local core_name=""
    local game_config
    game_config=$(get_game_specific_settings "$rom_path" "$emu_tag")
    if [ $? -eq 0 ] && echo "$game_config" | grep -q "^minarch"; then
        core_name=$(echo "$game_config" | cut -d'|' -f2 | sed 's/_libretro\.so$//')
    else
        core_name=$(get_emulator_setting "$emu_tag" "core1" | sed 's/_libretro\.so$//')
    fi
    if [ -n "$core_name" ]; then
        if [ ! -f "/mnt/SDCARD/.userdata/shared/$emu_tag-$core_name/$name.st$slot" ]; then
            if [ -f "/mnt/SDCARD/.userdata/shared/$emu_tag-$core_name/$name.st9" ]; then
                slot=9
            else
                slot=0
            fi
        fi
    fi
    echo "$slot"
}

##############################################################################
get_game_specific_settings() {
    local rom_path="$1"
    local emu_tag="$2"
    local rom_name
    rom_name=$(basename "$rom_path")
    local rom_name_clean="${rom_name%.*}"
    local game_config_dir="/mnt/SDCARD/Emus/$PLATFORM/$emu_tag.pak/game_settings"
    local game_config="$game_config_dir/$rom_name_clean.conf"
    if [ -f "$game_config" ]; then
        local game_launcher game_core
        game_launcher=$(grep "^launcher=" "$game_config" | cut -d'=' -f2)
        game_core=$(grep "^core=" "$game_config" | cut -d'=' -f2)
        echo "$game_launcher|$game_core"
        return 0
    fi
    return 1
}

##############################################################################
get_emulator_setting() {
    section=$1
    key=$2
    sed -n "/^\[$section\]/,/^\[/p" "$EMULATOR_CONFIG" | grep "^$key=" | cut -d'=' -f2
}

##############################################################################
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
    done < "$EMULATOR_CONFIG"
    if [ -n "$core_setting" ]; then
        echo "$core_setting"
    else
        echo "OFF"
    fi
}

##############################################################################
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
                if [ $in_section -eq 1 ] && [ $found -eq 0 ]; then
                    echo "gameswitcher=$new_state" >> "$temp_file"
                    found=1
                fi
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
    done < "$EMULATOR_CONFIG"

    if [ $found -eq 0 ]; then
        if ! grep -q "\[$section\]" "$EMULATOR_CONFIG"; then
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

    mv "$temp_file" "$EMULATOR_CONFIG"
    if grep -q "gameswitcher=$new_state" "$EMULATOR_CONFIG"; then
        success=1
    fi

    if [ $success -eq 1 ]; then
        "$SCRIPT_DIR/show_message" "GameSwitcher set to $new_state" -t 2
    else
        "$SCRIPT_DIR/show_message" "Failed to update GameSwitcher state" -t 2
    fi
}

##############################################################################
update_config() {
    local section="$1" key="$2" value="$3"
    if [ "$key" = "core1" ]; then
        update_core_order "$section" "$value"
        return
    fi

    if ! grep -q "\[$section\]" "$EMULATOR_CONFIG"; then
        echo "" >> "$EMULATOR_CONFIG"
        echo "[$section]" >> "$EMULATOR_CONFIG"
        echo "$key=$value" >> "$EMULATOR_CONFIG"
        return
    fi

    local temp_file="/tmp/core_temp.txt"
    > "$temp_file"
    local in_section=0 setting_found=0

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
    done < "$EMULATOR_CONFIG"

    if [ $in_section -eq 1 ] && [ $setting_found -eq 0 ]; then
        echo "$key=$value" >> "$temp_file"
    fi

    mv "$temp_file" "$EMULATOR_CONFIG"
}

##############################################################################
update_core_order() {
    local section="$1" new_core="$2"
    local temp_file="/tmp/core_temp.txt"
    > "$temp_file"

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
    ' "$EMULATOR_CONFIG" > "$temp_file"

    mv "$temp_file" "$EMULATOR_CONFIG"
}

##############################################################################
handle_emulator_options() {
    local rom_path="$1"
    local rom_platform="$2"
    local emu_menu_idx=0

    create_emulator_options_menu "$rom_path" "$rom_platform"

    while true; do
        emu_option=$("$SCRIPT_DIR/picker" "$EMU_MENU" -i $emu_menu_idx)

        if [ -z "$emu_option" ]; then
            break
        fi

        emu_menu_idx=$(grep -n "^${emu_option%$'\n'}$" "$EMU_MENU" | cut -d: -f1)
        emu_menu_idx=$((emu_menu_idx - 1))

        emu_action=$(echo "$emu_option" | cut -d'|' -f2)
        emu_section=$(echo "$emu_option" | cut -d'|' -f3)

        case "$emu_action" in
            "launcher")
                create_launcher_menu "$emu_section"
                launcher_sel=$("$SCRIPT_DIR/picker" "$EMU_MENU")
                [ -z "$launcher_sel" ] && continue
                launcher_choice=$(echo "$launcher_sel" | cut -d'|' -f2)
                update_config "$emu_section" "launcher" "$launcher_choice"
                create_emulator_options_menu "$rom_path" "$rom_platform"
                ;;
            "core")
                create_core_menu "$emu_section"
                core_sel=$("$SCRIPT_DIR/picker" "$EMU_MENU")
                [ -z "$core_sel" ] && continue
                core_choice=$(echo "$core_sel" | cut -d'|' -f2)
                if [ "$core_choice" != "none" ]; then
                    update_config "$emu_section" "core1" "$core_choice"
                fi
                create_emulator_options_menu "$rom_path" "$rom_platform"
                ;;
            "gameswitcher")
                create_gameswitcher_menu "$emu_section"
                gs_sel=$("$SCRIPT_DIR/picker" "$EMU_MENU")
                [ -z "$gs_sel" ] && continue
                gs_choice=$(echo "$gs_sel" | cut -d'|' -f2)
                toggle_game_switcher_state "$emu_section" "$gs_choice"
                create_emulator_options_menu "$rom_path" "$rom_platform"
                ;;
        esac
    done
}

##############################################################################
create_emulator_options_menu() {
    local rom_path="$1"
    local rom_platform="$2"

    > "$EMU_MENU"

    local current_launcher
    current_launcher=$(get_emulator_setting "$rom_platform" "launcher")
    [ -z "$current_launcher" ] && current_launcher="retroarch"
    echo "Launcher: $current_launcher|launcher|$rom_platform" >> "$EMU_MENU"

    local current_core
    current_core=$(get_emulator_setting "$rom_platform" "core1")
    if [ -n "$current_core" ]; then
        echo "Core: $current_core|core|$rom_platform" >> "$EMU_MENU"
    else
        echo "Core: (Not Set)|core|$rom_platform" >> "$EMU_MENU"
    fi

    local gs_state
    gs_state=$(get_game_switcher_state "$rom_platform")
    echo "GameSwitcher: $gs_state|gameswitcher|$rom_platform" >> "$EMU_MENU"
}

##############################################################################
create_launcher_menu() {
    local section="$1"
    > "$EMU_MENU"
    local current_launcher
    current_launcher=$(get_emulator_setting "$section" "launcher")

    if [ "$current_launcher" = "retroarch" ]; then
        echo "Current: RetroArch|retroarch|$section" >> "$EMU_MENU"
        echo "minarch|minarch|$section" >> "$EMU_MENU"
    elif [ "$current_launcher" = "minarch" ]; then
        echo "Current: minarch|minarch|$section" >> "$EMU_MENU"
        echo "RetroArch|retroarch|$section" >> "$EMU_MENU"
    else
        echo "RetroArch|retroarch|$section" >> "$EMU_MENU"
        echo "minarch|minarch|$section" >> "$EMU_MENU"
    fi
}

##############################################################################
create_core_menu() {
    local section="$1"
    > "$EMU_MENU"
    local current_core
    current_core=$(get_emulator_setting "$section" "core1")

    local in_section=0
    while IFS= read -r line; do
        case "$line" in
            "[""$section""]") in_section=1 ;;
            "["*) in_section=0 ;;
            core[0-9]*=*)
                if [ $in_section -eq 1 ]; then
                    local val
                    val=$(echo "$line" | sed 's/core[0-9]*=//')
                    val="${val%%[![:print:]]*}"
                    if [ "$val" = "$current_core" ]; then
                        echo "Current: $val|$val|$section" >> "$EMU_MENU"
                    else
                        echo "$val|$val|$section" >> "$EMU_MENU"
                    fi
                fi
            ;;
        esac
    done < "$EMULATOR_CONFIG"

    if [ ! -s "$EMU_MENU" ]; then
        if [ -n "$current_core" ]; then
            echo "Current: $current_core|$current_core|$section" >> "$EMU_MENU"
        else
            echo "No cores defined|none|$section" >> "$EMU_MENU"
        fi
    fi
}

##############################################################################
create_gameswitcher_menu() {
    local section="$1"
    local current_state
    current_state=$(get_game_switcher_state "$section")
    > "$EMU_MENU"
    if [ "$current_state" = "ON" ]; then
        echo "Current: ON|ON|$section" >> "$EMU_MENU"
        echo "OFF|OFF|$section" >> "$EMU_MENU"
    else
        echo "Current: OFF|OFF|$section" >> "$EMU_MENU"
        echo "ON|ON|$section" >> "$EMU_MENU"
    fi
}

##############################################################################
# -------------------- Game Settings Functions ---------------------------
##############################################################################
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
                launcher_sel=$("$SCRIPT_DIR/picker" "$EMU_MENU")
                [ -z "$launcher_sel" ] && continue
                launcher_choice=$(echo "$launcher_sel" | cut -d'|' -f2)
                update_game_setting "$game_rom" "$rom_platform" "launcher" "$launcher_choice"
                create_game_settings_menu "$rom_path" "$rom_platform"
                ;;
            "game_core")
                create_game_core_menu "$game_rom" "$rom_platform"
                core_sel=$("$SCRIPT_DIR/picker" "$EMU_MENU")
                [ -z "$core_sel" ] && continue
                core_choice=$(echo "$core_sel" | cut -d'|' -f2)
                update_game_setting "$game_rom" "$rom_platform" "core" "$core_choice"
                create_game_settings_menu "$rom_path" "$rom_platform"
                ;;
            "game_gameswitcher")
                create_game_gameswitcher_menu "$game_rom" "$rom_platform"
                gs_sel=$("$SCRIPT_DIR/picker" "$EMU_MENU")
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

##############################################################################
create_game_settings_menu() {
    local rom_path="$1"
    local rom_platform="$2"
    local rom_name
    rom_name=$(basename "$rom_path")
    local rom_name_clean="${rom_name%.*}"
    local game_config_dir="/mnt/SDCARD/Emus/$PLATFORM/$rom_platform.pak/game_settings"
    local game_config="$game_config_dir/$rom_name_clean.conf"

    > "$GAME_SETTINGS_MENU"

    if [ -f "$game_config" ]; then
        local game_launcher game_core gameswitcher_state
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

##############################################################################
create_game_launcher_menu() {
    local rom_path="$1"
    local rom_platform="$2"
    local rom_name
    rom_name=$(basename "$rom_path")
    local rom_name_clean="${rom_name%.*}"
    local game_config_dir="/mnt/SDCARD/Emus/$PLATFORM/$rom_platform.pak/game_settings"
    local game_config="$game_config_dir/$rom_name_clean.conf"

    > "$EMU_MENU"

    local current_launcher=""
    if [ -f "$game_config" ]; then
        current_launcher=$(grep "^launcher=" "$game_config" | cut -d'=' -f2)
    fi

    local system_launcher
    system_launcher=$(get_emulator_setting "$rom_platform" "launcher")
    [ -z "$system_launcher" ] && system_launcher="retroarch"

    echo "System Default ($system_launcher)|default|$rom_path" >> "$EMU_MENU"

    if [ "$current_launcher" = "retroarch" ]; then
        echo "Current: RetroArch|retroarch|$rom_path" >> "$EMU_MENU"
        echo "minarch|minarch|$rom_path" >> "$EMU_MENU"
    elif [ "$current_launcher" = "minarch" ]; then
        echo "Current: minarch|minarch|$rom_path" >> "$EMU_MENU"
        echo "RetroArch|retroarch|$rom_path" >> "$EMU_MENU"
    elif [ -n "$current_launcher" ]; then
        echo "Current: $current_launcher|$current_launcher|$rom_path" >> "$EMU_MENU"
        echo "RetroArch|retroarch|$rom_path" >> "$EMU_MENU"
        echo "minarch|minarch|$rom_path" >> "$EMU_MENU"
    else
        echo "Retroarch|retroarch|$rom_path" >> "$EMU_MENU"
        echo "minarch|minarch|$rom_path" >> "$EMU_MENU"
    fi
}

##############################################################################
create_game_core_menu() {
    local rom_path="$1"
    local rom_platform="$2"
    local rom_name
    rom_name=$(basename "$rom_path")
    local rom_name_clean="${rom_name%.*}"
    local game_config_dir="/mnt/SDCARD/Emus/$PLATFORM/$rom_platform.pak/game_settings"
    local game_config="$game_config_dir/$rom_name_clean.conf"

    > "$EMU_MENU"

    local current_core=""
    if [ -f "$game_config" ]; then
        current_core=$(grep "^core=" "$game_config" | cut -d'=' -f2)
    fi

    local system_core
    system_core=$(get_emulator_setting "$rom_platform" "core1")
    [ -z "$system_core" ] && system_core="(none)"

    echo "System Default ($system_core)|default|$rom_path" >> "$EMU_MENU"

    local in_section=0
    while IFS= read -r line; do
        case "$line" in
            "["$rom_platform"]") in_section=1 ;;
            "["*) in_section=0 ;;
            core[0-9]*=*)
                if [ $in_section -eq 1 ]; then
                    local val
                    val=$(echo "$line" | sed 's/core[0-9]*=//')
                    val="${val%%[![:print:]]*}"
                    if [ "$val" = "$current_core" ]; then
                        echo "Current: $val|$val|$rom_path" >> "$EMU_MENU"
                    elif [ "$val" != "$system_core" ]; then
                        echo "$val|$val|$rom_path" >> "$EMU_MENU"
                    fi
                fi
            ;;
        esac
    done < "$EMULATOR_CONFIG"

    if [ -n "$current_core" ] && ! grep -q "|$current_core|" "$EMU_MENU"; then
        echo "Current: $current_core|$current_core|$rom_path" >> "$EMU_MENU"
    fi
}

##############################################################################
create_game_gameswitcher_menu() {
    local rom_path="$1"
    local rom_platform="$2"
    local rom_name
    rom_name=$(basename "$rom_path")
    local rom_name_clean="${rom_name%.*}"
    local game_config_dir="/mnt/SDCARD/Emus/$PLATFORM/$rom_platform.pak/game_settings"
    local game_config="$game_config_dir/$rom_name_clean.conf"

    > "$EMU_MENU"

    local current_state=""
    if [ -f "$game_config" ]; then
        current_state=$(grep "^gameswitcher=" "$game_config" | cut -d'=' -f2)
    fi

    local system_state
    system_state=$(get_game_switcher_state "$rom_platform")

    echo "System Default ($system_state)|default|$rom_path" >> "$EMU_MENU"

    if [ "$current_state" = "ON" ]; then
        echo "Current: ON|ON|$rom_path" >> "$EMU_MENU"
        echo "OFF|OFF|$rom_path" >> "$EMU_MENU"
    elif [ "$current_state" = "OFF" ]; then
        echo "Current: OFF|OFF|$rom_path" >> "$EMU_MENU"
        echo "ON|ON|$rom_path" >> "$EMU_MENU"
    else
        echo "ON|ON|$rom_path" >> "$EMU_MENU"
        echo "OFF|OFF|$rom_path" >> "$EMU_MENU"
    fi
}

##############################################################################
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

##############################################################################
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

##############################################################################
# At the end, display the main menu.
##############################################################################
show_options_menu
exit 0
