#!/bin/sh
SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"
touch "$SCRIPT_DIR/ignore_hotkey.txt"
touch /tmp/gs_active
if [ -n "$GS_FROM_MONITOR" ] || [ "$1" = "--from-monitor" ]; then
    touch "/tmp/gs_from_monitor"
fi

pause_minui() {
    killall -STOP minui.elf 2>/dev/null
    echo "MinUI suspended."
}

reset_minui() {
    killall -KILL minui.elf 2>/dev/null
    echo "MinUI killed."
    /mnt/SDCARD/.system/tg5040/bin/minui.elf &
    echo "MinUI restarted."
}

cleanup_on_exit() {
    rm -f /tmp/gs_active \
          /tmp/keyboard_output.txt /tmp/picker_output.txt /tmp/search_results.txt \
          /tmp/browser_selection.txt /tmp/browser_history.txt \
          /tmp/gs_options_menu.txt /tmp/add_game_menu.txt /tmp/recent_list.txt \
          /tmp/gameswitchertemp.* /tmp/update_image.*
    rm -f "$SCRIPT_DIR/ignore_hotkey.txt"
    
    FROM_MONITOR=0
    if [ -f "/tmp/gs_from_monitor" ]; then
        FROM_MONITOR=1
    fi
    
    rm -f "/tmp/gs_from_monitor" /tmp/gs_played_game
    
    killall "$SCRIPT_DIR/gs_monitor.sh" 2>/dev/null
    "$SCRIPT_DIR/gs_monitor.sh" &
    
    if [ $FROM_MONITOR -eq 1 ]; then
        killall -KILL minui.elf 2>/dev/null
        echo "MinUI killed - from monitor exit."
        /mnt/SDCARD/.system/tg5040/bin/minui.elf &
        echo "MinUI restarted."
    fi
}

trap cleanup_on_exit EXIT INT TERM

GAME_ORDER="$SCRIPT_DIR/game_order.txt"
LAST_GAME="$SCRIPT_DIR/last_game.txt"
DEFAULT_IMAGE="$SCRIPT_DIR/default.zip.0.bmp"
EMULATOR_CONFIG="/mnt/SDCARD/Emus/$PLATFORM/core.txt"
TEMP_FILE="/tmp/gameswitchertemp.$$"
LOGS_PATH="/mnt/SDCARD/logs"

GS_IMAGE="$SCRIPT_DIR/gs_image"
[ ! -x "$GS_IMAGE" ] && [ -f "$GS_IMAGE" ] && chmod +x "$GS_IMAGE"

GS_OPTIONS="$SCRIPT_DIR/gs_options.sh"
[ ! -x "$GS_OPTIONS" ] && [ -f "$GS_OPTIONS" ] && chmod +x "$GS_OPTIONS"

mkdir -p "$LOGS_PATH"
echo "Starting Game Switcher (PID: $$) at $(date)" > "$LOGS_PATH/game_switcher.log"

[ ! -f "$GAME_ORDER" ] && touch "$GAME_ORDER"
[ ! -f "$LAST_GAME" ] && touch "$LAST_GAME"

RECENTS_FILE="/mnt/SDCARD/.userdata/shared/.minui/recent.txt"
if [ -f "$RECENTS_FILE" ]; then
    FIRST_LINE=$(head -n 1 "$RECENTS_FILE")
    if echo "$FIRST_LINE" | grep -q "(GS)"; then
         sed -i '1d' "$RECENTS_FILE"
    fi
fi

cleanup() {
    rm -f /tmp/keyboard_output.txt
    rm -f /tmp/picker_output.txt
    rm -f /tmp/search_results.txt
    rm -f /tmp/browser_selection.txt
    rm -f /tmp/browser_history.txt
    rm -f /tmp/gs_options_menu.txt
    rm -f /tmp/add_game_menu.txt
    rm -f /tmp/recent_list.txt
    rm -f /tmp/gameswitchertemp.*
    rm -f /tmp/update_image.*
}

launch_rom() {
    local rom_path="$1"
    if [ -f "$rom_path" ]; then
        touch "/tmp/gs_played_game"
        ROM_PLATFORM=$(detect_rom_platform "$rom_path")
        game_config=$(get_game_specific_settings "$rom_path" "$ROM_PLATFORM")
        is_minarch=0
        if [ $? -eq 0 ]; then
            if echo "$game_config" | grep -q "^minarch"; then
                is_minarch=1
            fi
        fi
        if [ $is_minarch -eq 0 ]; then
            if [ "$(get_emulator_setting "$ROM_PLATFORM" "launcher")" = "minarch" ]; then
                is_minarch=1
            fi
        fi
        if [ $is_minarch -eq 1 ]; then
            SLOT=$(find_save_slot "$rom_path" "$ROM_PLATFORM")
            if [ -n "$SLOT" ] && [ -d "/tmp" ]; then
                echo "$SLOT" > "/tmp/resume_slot.txt" 2>/dev/null
                ROM_FILE=$(basename "$rom_path")
                mkdir -p "/mnt/SDCARD/.userdata/shared/.minui/$ROM_PLATFORM" 2>/dev/null
                echo "$SLOT" > "/mnt/SDCARD/.userdata/shared/.minui/$ROM_PLATFORM/$ROM_FILE.txt" 2>/dev/null
            fi
        fi
        if [ -d "/mnt/SDCARD/Emus/$PLATFORM/$ROM_PLATFORM.pak" ]; then
            EMULATOR="/mnt/SDCARD/Emus/$PLATFORM/$ROM_PLATFORM.pak/launch.sh"
            GAME_SWITCHER_MODE=1 exec "$EMULATOR" "$rom_path"
        elif [ -d "/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$ROM_PLATFORM.pak" ]; then
            EMULATOR="/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$ROM_PLATFORM.pak/launch.sh"
            GAME_SWITCHER_MODE=1 exec "$EMULATOR" "$rom_path"
        else
            ./show_message "Emulator not found for $ROM_PLATFORM" -l -t 2
            return 1
        fi
    else
        ./show_message "Game file not found: $rom_path" -l -t 2
        return 1
    fi
}

update_entry_image() {
    local rom_path="$1"
    local current_image="$2"
    if [ "$current_image" = "$DEFAULT_IMAGE" ] || [ ! -f "$current_image" ]; then
        local rom_platform
        rom_platform=$(detect_rom_platform "$rom_path")
        if [ -x "$GS_IMAGE" ]; then
            local result
            result=$("$GS_IMAGE" update_entry "$GAME_ORDER" "$rom_path" "$DEFAULT_IMAGE")
            if [ "$result" = "1" ]; then
                return 0
            else
                return 1
            fi
        else
            local rom_name save_slot minarch_image game_base_name ra_image new_image
            rom_name=$(basename "$rom_path")
            save_slot=$(find_save_slot "$rom_path" "$rom_platform")
            minarch_image="/mnt/SDCARD/.userdata/shared/.minui/$rom_platform/$rom_name.$save_slot.bmp"
            game_base_name="${rom_name%.*}"
            ra_image="/mnt/SDCARD/Tools/$PLATFORM/RetroArch.pak/.retroarch/states/${game_base_name}.state.auto.png"
            if [ -f "$minarch_image" ] && [ -f "$ra_image" ]; then
                local minarch_time ra_time
                minarch_time=$(stat -c %Y "$minarch_image" 2>/dev/null || echo "0")
                ra_time=$(stat -c %Y "$ra_image" 2>/dev/null || echo "0")
                if [ "$minarch_time" -gt "$ra_time" ]; then
                    new_image="$minarch_image"
                else
                    new_image="$ra_image"
                fi
            elif [ -f "$minarch_image" ]; then
                new_image="$minarch_image"
            elif [ -f "$ra_image" ]; then
                new_image="$ra_image"
            fi
            if [ -n "$new_image" ] && [ -f "$new_image" ]; then
                update_image_in_game_order "$rom_path" "$new_image"
                return 0
            fi
        fi
    fi
    return 1
}

update_all_game_images() {
    local updated=0
    if [ -f "$LAST_GAME" ]; then
        local last_game current_entry current_image
        last_game=$(cat "$LAST_GAME" 2>/dev/null)
        if [ -n "$last_game" ]; then
            current_entry=$(grep "|$last_game|" "$GAME_ORDER" 2>/dev/null)
            if [ -n "$current_entry" ]; then
                current_image=$(echo "$current_entry" | cut -d'|' -f2)
                if update_entry_image "$last_game" "$current_image"; then
                    updated=$((updated + 1))
                fi
                if grep -q "|$last_game|" "$GAME_ORDER"; then
                    local matching_line
                    matching_line=$(grep "|${last_game}|" "$GAME_ORDER")
                    grep -v "|${last_game}|" "$GAME_ORDER" > /tmp/gs_order.tmp
                    ( echo "$matching_line"; cat /tmp/gs_order.tmp ) > "$GAME_ORDER"
                    rm -f /tmp/gs_order.tmp
                fi
            fi
        fi
    fi
    if [ -x "$GS_IMAGE" ] && [ "$updated" -eq 0 ]; then
        local bulk_updated
        bulk_updated=$("$GS_IMAGE" update_all "$GAME_ORDER" "$DEFAULT_IMAGE")
        updated=$bulk_updated
    fi
    return $updated
}

update_image_in_game_order() {
    local rom_path="$1"
    local new_image="$2"
    local temp_file="/tmp/update_image.$$"
    while IFS= read -r line; do
        if echo "$line" | grep -q "|$rom_path|"; then
            local display_name launcher
            display_name=$(echo "$line" | cut -d'|' -f1)
            launcher=$(echo "$line" | cut -d'|' -f4)
            echo "$display_name|$new_image|$rom_path|$launcher" >> "$temp_file"
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$GAME_ORDER"
    mv "$temp_file" "$GAME_ORDER"
}

cleanup_duplicate_entries() {
    local last_cleanup_file="$SCRIPT_DIR/.last_cleanup"
    local current_time
    current_time=$(date +%s)
    local do_cleanup=0
    if [ -f "$last_cleanup_file" ]; then
        local last_time
        last_time=$(cat "$last_cleanup_file")
        if [ $((current_time - last_time)) -gt 604800 ]; then
            do_cleanup=1
        fi
    else
        do_cleanup=1
    fi
    if [ $do_cleanup -eq 1 ]; then
        if [ -f "$GAME_ORDER" ]; then
            local CLEANED_FILE="/tmp/clean_game_order.txt"
            > "$CLEANED_FILE"
            local SEEN_ROMS="/tmp/seen_roms.txt"
            > "$SEEN_ROMS"
            while IFS= read -r line; do
                local rom_path
                rom_path=$(echo "$line" | cut -d'|' -f3)
                if ! grep -q "^$rom_path$" "$SEEN_ROMS"; then
                    echo "$line" >> "$CLEANED_FILE"
                    echo "$rom_path" >> "$SEEN_ROMS"
                fi
            done < "$GAME_ORDER"
            if [ -s "$CLEANED_FILE" ]; then
                cp "$CLEANED_FILE" "$GAME_ORDER"
            fi
            rm -f "$CLEANED_FILE" "$SEEN_ROMS"
        fi
        echo "$current_time" > "$last_cleanup_file"
    fi
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

get_emulator_setting() {
    section=$1
    key=$2
    sed -n "/^\[$section\]/,/^\[/p" "$EMULATOR_CONFIG" | grep "^$key=" | cut -d'=' -f2
}

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
    if [ -x "$GS_IMAGE" ]; then
        image_path=$("$GS_IMAGE" find_best "$rom_path" "$emu_tag" "$DEFAULT_IMAGE")
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
    grep -v "|$rom_path|" "$GAME_ORDER" > "$TEMP_FILE" 2>/dev/null || cp "$GAME_ORDER" "$TEMP_FILE"
    echo "$display_name|$image_path|$rom_path|$launcher" > "$TEMP_FILE.new"
    cat "$TEMP_FILE" >> "$TEMP_FILE.new"
    mv "$TEMP_FILE.new" "$GAME_ORDER"
    return 0
}

ORIGINAL_LAST_GAME=""
if [ -f "$LAST_GAME" ]; then
    ORIGINAL_LAST_GAME=$(cat "$LAST_GAME" 2>/dev/null | tr -d '\n')
fi

PREV_STATUS=0
cleanup_duplicate_entries
update_all_game_images
pause_minui

while true; do
    cleanup
    if [ $PREV_STATUS -eq 0 ]; then
        last_game=$(cat "$LAST_GAME" 2>/dev/null | tr -d '\n')
        if [ -n "$last_game" ] && grep -q "|${last_game}|" "$GAME_ORDER"; then
            main_menu_idx=0
        else
            main_menu_idx=0
        fi
    else
        main_menu_idx=0
    fi
    
    killall game_switcher 2>/dev/null
    game_switcher_output=$(./game_switcher "$GAME_ORDER" -i $main_menu_idx -a "PLAY" -b "EXIT" -y "OPTIONS")
    game_switcher_status=$?
    PREV_STATUS=$game_switcher_status
    
    if [ $game_switcher_status -eq 2 ]; then
        if [ -n "$ORIGINAL_LAST_GAME" ]; then
            echo "$ORIGINAL_LAST_GAME" > "$LAST_GAME"
        fi
        killall evtest
        cleanup
        exit 0
    fi
    
    case "$game_switcher_status" in
        0)
            cleanup
            ROM=$(echo "$game_switcher_output" | cut -d'|' -f3)
            if [ -f "$ROM" ]; then
                ROM_PLATFORM=$(detect_rom_platform "$ROM")
                RECENTS_FILE="/mnt/SDCARD/.userdata/shared/.minui/recent.txt"
                RELATIVE_ROM=$(echo "$ROM" | sed 's#^/mnt/SDCARD##')
                GAME_NAME=$(basename "$ROM")
                GAME_NAME="${GAME_NAME%.*}"
                RECENT_ENTRY="$RELATIVE_ROM	$GAME_NAME"
                [ ! -f "$RECENTS_FILE" ] && touch "$RECENTS_FILE"
                grep -v "^$RELATIVE_ROM	" "$RECENTS_FILE" > "$RECENTS_FILE.tmp"
                { echo "$RECENT_ENTRY"; cat "$RECENTS_FILE.tmp"; } > "$RECENTS_FILE"
                rm -f "$RECENTS_FILE.tmp"
                game_config=$(get_game_specific_settings "$ROM" "$ROM_PLATFORM")
                is_minarch=0
                if [ $? -eq 0 ]; then
                    if echo "$game_config" | grep -q "^minarch"; then
                        is_minarch=1
                    fi
                fi
                if [ $is_minarch -eq 0 ]; then
                    if [ "$(get_emulator_setting "$ROM_PLATFORM" "launcher")" = "minarch" ]; then
                        is_minarch=1
                    fi
                fi
                if [ $is_minarch -eq 1 ]; then
                    SLOT=$(find_save_slot "$ROM" "$ROM_PLATFORM")
                    if [ -n "$SLOT" ] && [ -d "/tmp" ]; then
                        echo "$SLOT" > "/tmp/resume_slot.txt" 2>/dev/null
                        ROM_FILE=$(basename "$ROM")
                        mkdir -p "/mnt/SDCARD/.userdata/shared/.minui/$ROM_PLATFORM" 2>/dev/null
                        echo "$SLOT" > "/mnt/SDCARD/.userdata/shared/.minui/$ROM_PLATFORM/$ROM_FILE.txt" 2>/dev/null
                    fi
                fi
                touch "/tmp/gs_played_game"
                if [ -d "/mnt/SDCARD/Emus/$PLATFORM/$ROM_PLATFORM.pak" ]; then
                    EMULATOR="/mnt/SDCARD/Emus/$PLATFORM/$ROM_PLATFORM.pak/launch.sh"
                    GAME_SWITCHER_MODE=1 exec "$EMULATOR" "$ROM"
                elif [ -d "/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$ROM_PLATFORM.pak" ]; then
                    EMULATOR="/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$ROM_PLATFORM.pak/launch.sh"
                    GAME_SWITCHER_MODE=1 exec "$EMULATOR" "$ROM"
                else
                    ./show_message "Emulator not found for $ROM_PLATFORM" -l -t 2
                    continue
                fi
                update_game "$ROM" "$ROM_PLATFORM"
                echo "$ROM" > "$LAST_GAME"
                if grep -q "|$ROM|" "$GAME_ORDER"; then
                    matching_line=$(grep "|${ROM}|" "$GAME_ORDER")
                    grep -v "|${ROM}|" "$GAME_ORDER" > /tmp/gs_order.tmp
                    ( echo "$matching_line"; cat /tmp/gs_order.tmp ) > "$GAME_ORDER"
                    rm -f /tmp/gs_order.tmp
                fi
                PREV_STATUS=0
            else
                ./show_message "Game file not found|$ROM" -l -t 2
                continue
            fi
            ;;
        4)
            cleanup
            selected_game=$(echo "$game_switcher_output" | cut -d'|' -f3)
            if [ -x "$GS_OPTIONS" ]; then
                "$GS_OPTIONS" "$selected_game" "$GAME_ORDER"
                options_status=$?
                if [ $options_status -eq 99 ]; then
                    export RESTART_GAME=1
                    ROM=$(cat "$LAST_GAME" | tr -d '\n')
                    launch_rom "$ROM"
                fi
            else
                ./show_message "Options script not found" -l -t 2
            fi
            cleanup
            ;;
    esac
done

cleanup