#!/bin/sh
cd "$(dirname "$0")"
export LD_LIBRARY_PATH=/usr/trimui/lib:$LD_LIBRARY_PATH

MENU="menu.txt"
DUMMY_ROM="__COLLECTION__"
RECENTS_FILE="/mnt/SDCARD/.userdata/shared/.minui/recent.txt"
if [ -f "$RECENTS_FILE" ]; then
    FIRST_LINE=$(head -n 1 "$RECENTS_FILE")
    if echo "$FIRST_LINE" | grep -q "(CUSTOM)"; then
         sed -i '1d' "$RECENTS_FILE"
    fi
fi

prepare_resume() {
    CURRENT_PATH=$(dirname "$1")
    ROM_FOLDER_NAME=$(basename "$CURRENT_PATH")
    while [ -z "$ROM_PLATFORM" ]; do
        if [ "$ROM_FOLDER_NAME" = "Roms" ]; then
            ROM_PLATFORM="UNK"
            break
        fi
        ROM_PLATFORM=$(echo "$ROM_FOLDER_NAME" | sed -n 's/.*(\(.*\)).*/\1/p')
        if [ -z "$ROM_PLATFORM" ]; then
            CURRENT_PATH=$(dirname "$CURRENT_PATH")
            ROM_FOLDER_NAME=$(basename "$CURRENT_PATH")
        fi
    done
    BASE_PATH="/mnt/SDCARD/.userdata/shared/.minui/$ROM_PLATFORM"
    ROM_NAME=$(basename "$1")
    SLOT_FILE="$BASE_PATH/$ROM_NAME.txt"
    if [ -f "$SLOT_FILE" ]; then
        SLOT=$(cat "$SLOT_FILE")
    else
        SLOT="0"
    fi
    echo $SLOT > /tmp/resume_slot.txt
}

cleanup() {
    rm -f /tmp/keyboard_output.txt
    rm -f /tmp/picker_output.txt
    rm -f /tmp/search_results.txt
    rm -f /tmp/add_favorites.txt
    rm -f /tmp/browser_selection.txt
    rm -f /tmp/browser_history.txt
}

CURRENT_DIR=$(basename "$(pwd -P)")
# First remove the platform identifier (CUSTOM) if present
COLLECTION_NAME=$(echo "$CURRENT_DIR" | sed 's/ ([^)]*)//g' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
# Then remove numeric prefixes like "0)", "00)", "1)", "01)" followed by a space
COLLECTION_NAME=$(echo "$COLLECTION_NAME" | sed 's/^[0-9]\+) //g')
ADD_TO_TEXT="$COLLECTION_NAME|$DUMMY_ROM|menu_options"
if [ ! -f "$MENU" ]; then
    echo "$ADD_TO_TEXT" > "$MENU"
fi

> game_options.txt
for script in "./game_options"/*.sh; do
    if [ -x "$script" ]; then
        name=$(basename "$script" .sh)
        display_name=$(echo "$name" | sed 's/_/ /g')
        display_name="$(echo ${display_name:0:1} | tr '[:lower:]' '[:upper:]')${display_name:1}"
        echo "$display_name|$name" >> game_options.txt
    fi
done

> menu_options.txt
for script in "./menu_options"/*.sh; do
    if [ -x "$script" ]; then
        name=$(basename "$script" .sh)
        display_name=$(echo "$name" | sed 's/_/ /g')
        display_name="$(echo ${display_name:0:1} | tr '[:lower:]' '[:upper:]')${display_name:1}"
        echo "$display_name|$name" >> menu_options.txt
    fi
done

[ -s game_options.txt ] || echo "No Options Available|no_options" > game_options.txt
[ -s menu_options.txt ] || echo "No Options Available|no_options" > menu_options.txt

main_menu_idx=0
while true; do
    CURRENT_DIR=$(basename "$(pwd -P)")
    # First remove the platform identifier (CUSTOM) if present
    COLLECTION_NAME=$(echo "$CURRENT_DIR" | sed 's/ ([^)]*)//g' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    # Then remove numeric prefixes like "0)", "00)", "1)", "01)" followed by a space
    COLLECTION_NAME=$(echo "$COLLECTION_NAME" | sed 's/^[0-9]\+) //g')
    ADD_TO_TEXT="$COLLECTION_NAME|$DUMMY_ROM|menu_options"
    sed -i "1s/^.*|.*|menu_options\$/$ADD_TO_TEXT/" "$MENU"
    killall picker 2>/dev/null
    picker_output=$(./game_picker "$MENU" -i $main_menu_idx -x "RESUME" -y "OPTIONS")
    picker_status=$?
    main_menu_idx=$(grep -n "^${picker_output%$'\n'}$" "$MENU" | cut -d: -f1)
    main_menu_idx=$((main_menu_idx - 1))
    [ $picker_status = 2 ] && cleanup && exit $picker_status
    if [ $picker_status = 4 ]; then
        if [ "$picker_output" = "$ADD_TO_TEXT" ]; then
            options_output=$(./picker "menu_options.txt")
            options_status=$?
            [ $options_status -ne 0 ] && continue
            option_action=$(echo "$options_output" | cut -d'|' -f2)
            if [ -x "./menu_options/${option_action}.sh" ]; then
                export SELECTED_ITEM="$picker_output"
                export MENU="$MENU"
                export ADD_TO_TEXT="$ADD_TO_TEXT"
                export COLLECTION_NAME="$COLLECTION_NAME"
                "./menu_options/${option_action}.sh"
            fi
            continue
        else
            options_output=$(./picker "game_options.txt")
            options_status=$?
            [ $options_status -ne 0 ] && continue
            option_action=$(echo "$options_output" | cut -d'|' -f2)
            [ "$option_action" = "no_options" ] && continue
            if [ -x "./game_options/${option_action}.sh" ]; then
                export SELECTED_ITEM="$picker_output"
                export MENU="$MENU"
                export ADD_TO_TEXT="$ADD_TO_TEXT"
                export COLLECTION_NAME="$COLLECTION_NAME"
                "./game_options/${option_action}.sh"
            fi
            continue
        fi
    fi
    [ $picker_status = 1 ] || [ $picker_status -gt 4 ] && cleanup && exit $picker_status
    action=$(echo "$picker_output" | cut -d'|' -f3)
    case "$action" in
        "launch")
            ROM=$(echo "$picker_output" | cut -d'|' -f2)
            if [ "$ROM" = "$DUMMY_ROM" ]; then
                options_output=$(./picker "menu_options.txt")
                options_status=$?
                [ $options_status -ne 0 ] && continue
                option_action=$(echo "$options_output" | cut -d'|' -f2)
                if [ -x "./menu_options/${option_action}.sh" ]; then
                    export SELECTED_ITEM="$picker_output"
                    export MENU="$MENU"
                    export ADD_TO_TEXT="$ADD_TO_TEXT"
                    export COLLECTION_NAME="$COLLECTION_NAME"
                    "./menu_options/${option_action}.sh"
                fi
                continue
            fi
            [ $picker_status = 3 ] && prepare_resume "$ROM"
            if [ -f "$ROM" ]; then
                RELATIVE_ROM=$(echo "$ROM" | sed 's#^/mnt/SDCARD##')
                GAME_NAME=$(basename "$ROM")
                GAME_NAME="${GAME_NAME%.*}"
                RECENT_ENTRY="$RELATIVE_ROM	$GAME_NAME"
                [ ! -f "$RECENTS_FILE" ] && touch "$RECENTS_FILE"
                grep -v "^$RELATIVE_ROM	" "$RECENTS_FILE" > "$RECENTS_FILE.tmp"
                { echo "$RECENT_ENTRY"; cat "$RECENTS_FILE.tmp"; } > "$RECENTS_FILE"
                rm -f "$RECENTS_FILE.tmp"
                CURRENT_PATH=$(dirname "$ROM")
                ROM_FOLDER_NAME=$(basename "$CURRENT_PATH")
                ROM_PLATFORM=""
                while [ -z "$ROM_PLATFORM" ]; do
                    if [ "$ROM_FOLDER_NAME" = "Roms" ]; then
                        ROM_PLATFORM="UNK"
                        exit 1
                    fi
                    ROM_PLATFORM=$(echo "$ROM_FOLDER_NAME" | sed -n 's/.*(\(.*\)).*/\1/p')
                    if [ -z "$ROM_PLATFORM" ]; then
                        CURRENT_PATH=$(dirname "$CURRENT_PATH")
                        ROM_FOLDER_NAME=$(basename "$CURRENT_PATH")
                    fi
                done
                if [ -d "/mnt/SDCARD/Emus/$PLATFORM/$ROM_PLATFORM.pak" ]; then
                    EMULATOR="/mnt/SDCARD/Emus/$PLATFORM/$ROM_PLATFORM.pak/launch.sh"
                    "$EMULATOR" "$ROM"
                elif [ -d "/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$ROM_PLATFORM.pak" ]; then
                    EMULATOR="/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$ROM_PLATFORM.pak/launch.sh"
                    "$EMULATOR" "$ROM"
                else
                    ./show_message "Emulator not found for $ROM_PLATFORM" -l a
                fi
            else
                ./show_message "Game file not found|$ROM" -l a
            fi
            ;;
        "menu_options")
            options_output=$(./picker "menu_options.txt")
            options_status=$?
            [ $options_status -ne 0 ] && continue
            option_action=$(echo "$options_output" | cut -d'|' -f2)
            if [ -x "./menu_options/${option_action}.sh" ]; then
                export SELECTED_ITEM="$picker_output"
                export MENU="$MENU"
                export ADD_TO_TEXT="$ADD_TO_TEXT"
                export COLLECTION_NAME="$COLLECTION_NAME"
                "./menu_options/${option_action}.sh"
            fi
            ;;
    esac
done