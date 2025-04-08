#!/bin/sh

export LD_LIBRARY_PATH="/usr/lib:$LD_LIBRARY_PATH"
SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

ROM_BASE_DIR="/mnt/SDCARD/Roms"
TEMP_MENU="/tmp/boxart_menu.txt"
TEMP_SYSTEMS="/tmp/boxart_systems.txt"

create_main_menu() {
    > "$TEMP_MENU"
    echo "Rename All System Boxart|all|menu" >> "$TEMP_MENU"
    echo "Select Specific System|select|menu" >> "$TEMP_MENU"
}

create_systems_menu() {
    > "$TEMP_SYSTEMS"
    ./show_message "Scanning for systems with boxart..." &
    scan_pid=$!
    found=0
    for SYS_DIR in "$ROM_BASE_DIR"/*; do
        if [ -d "$SYS_DIR" ] && [ -d "$SYS_DIR/.res" ]; then
            SYSTEM_NAME=$(basename "$SYS_DIR")
            PNG_COUNT=$(find "$SYS_DIR/.res" -maxdepth 1 -name "*.png" 2>/dev/null | wc -l)
            if [ "$PNG_COUNT" -gt 0 ]; then
                echo "$SYSTEM_NAME ($PNG_COUNT boxarts)|$SYSTEM_NAME|system" >> "$TEMP_SYSTEMS"
                found=1
            fi
        fi
    done
    kill $scan_pid 2>/dev/null
    if [ $found -eq 0 ]; then
        ./show_message "No systems with boxart found!" -l -a "OK"
        return 1
    fi
    sort "$TEMP_SYSTEMS" -o "$TEMP_SYSTEMS"
    return 0
}

process_system() {
    local SYSTEM_NAME="$1"
    local SYSTEM_FOLDER="$ROM_BASE_DIR/$SYSTEM_NAME"
    local RES_FOLDER="$SYSTEM_FOLDER/.res"
    if [ ! -d "$RES_FOLDER" ]; then
        ./show_message "No .res folder found for $SYSTEM_NAME" -t 2
        return 1
    fi
    ./show_message "Processing $SYSTEM_NAME boxart..." &
    process_pid=$!
    RENAMED=0
    ALREADY_OK=0
    NO_MATCH=0
    find "$RES_FOLDER" -maxdepth 1 -type f -name '*.png' 2>/dev/null | sed 's|.*/||' | sort > /tmp/boxart_files.txt
    find "$SYSTEM_FOLDER" -maxdepth 1 -type f ! -path '*/.res/*' 2>/dev/null | sed 's|.*/||' | sort > /tmp/rom_files.txt
    exec 3</tmp/boxart_files.txt
    exec 4</tmp/rom_files.txt
    read -r BOXART_FILE <&3
    read -r ROM_FILE <&4
    boxart_name_without_ext() { echo "${1%.png}"; }
    rom_name_no_ext() { echo "${1%.*}"; }
    rom_ext() { echo "${1##*.}"; }
    while true; do
        [ -z "$BOXART_FILE" ] && [ -z "$ROM_FILE" ] && break
        if [ -z "$BOXART_FILE" ]; then
            break
        fi
        if [ -z "$ROM_FILE" ]; then
            NO_MATCH=$((NO_MATCH + 1))
            read -r BOXART_FILE <&3
            continue
        fi
        local bn="$(boxart_name_without_ext "$BOXART_FILE")"
        local rn="$(rom_name_no_ext "$ROM_FILE")"
        if [ "$bn" = "$rn" ]; then
            local ext="$(rom_ext "$ROM_FILE")"
            local newName="${bn}.${ext}.png"
            if [ "$BOXART_FILE" = "$newName" ]; then
                ALREADY_OK=$((ALREADY_OK + 1))
            else
                mv "$RES_FOLDER/$BOXART_FILE" "$RES_FOLDER/$newName"
                RENAMED=$((RENAMED + 1))
            fi
            read -r BOXART_FILE <&3
            read -r ROM_FILE <&4
        elif [ "$bn" \< "$rn" ]; then
            NO_MATCH=$((NO_MATCH + 1))
            read -r BOXART_FILE <&3
        else
            read -r ROM_FILE <&4
        fi
    done
    while [ -n "$BOXART_FILE" ]; do
        NO_MATCH=$((NO_MATCH + 1))
        read -r BOXART_FILE <&3
    done
    exec 3<&-
    exec 4<&-
    kill $process_pid 2>/dev/null
    TOTAL=$((RENAMED + ALREADY_OK + NO_MATCH))
    ./show_message "System: $SYSTEM_NAME\n\nRenamed: $RENAMED\nAlready OK: $ALREADY_OK\nNo Match: $NO_MATCH\nTotal: $TOTAL" -l -a "OK"
    return 0
}

process_system_quiet() {
    local SYSTEM_NAME="$1"
    local SYSTEM_FOLDER="$ROM_BASE_DIR/$SYSTEM_NAME"
    local RES_FOLDER="$SYSTEM_FOLDER/.res"
    [ ! -d "$RES_FOLDER" ] && echo 0 && return 0
    find "$RES_FOLDER" -maxdepth 1 -type f -name '*.png' 2>/dev/null | sed 's|.*/||' | sort > /tmp/boxart_files_quiet.txt
    find "$SYSTEM_FOLDER" -maxdepth 1 -type f ! -path '*/.res/*' 2>/dev/null | sed 's|.*/||' | sort > /tmp/rom_files_quiet.txt
    exec 3</tmp/boxart_files_quiet.txt
    exec 4</tmp/rom_files_quiet.txt
    RENAMED=0
    read -r BOXART_FILE <&3
    read -r ROM_FILE <&4
    while true; do
        [ -z "$BOXART_FILE" ] && [ -z "$ROM_FILE" ] && break
        [ -z "$BOXART_FILE" ] && break
        [ -z "$ROM_FILE" ] && break
        local bn="${BOXART_FILE%.png}"
        local rn="${ROM_FILE%.*}"
        if [ "$bn" = "$rn" ]; then
            local ext="${ROM_FILE##*.}"
            local newName="${bn}.${ext}.png"
            if [ "$BOXART_FILE" != "$newName" ]; then
                mv "$RES_FOLDER/$BOXART_FILE" "$RES_FOLDER/$newName"
                RENAMED=$((RENAMED + 1))
            fi
            read -r BOXART_FILE <&3
            read -r ROM_FILE <&4
        elif [ "$bn" \< "$rn" ]; then
            read -r BOXART_FILE <&3
        else
            read -r ROM_FILE <&4
        fi
    done
    exec 3<&-
    exec 4<&-
    echo $RENAMED
    return $RENAMED
}

process_all_systems() {
    if ! create_systems_menu; then
        return 1
    fi
    TOTAL_SYSTEMS=$(wc -l < "$TEMP_SYSTEMS")
    CURRENT_SYSTEM=0
    TOTAL_RENAMED=0
    while IFS= read -r line; do
        SYSTEM_NAME=$(echo "$line" | cut -d'|' -f2)
        CURRENT_SYSTEM=$((CURRENT_SYSTEM + 1))
        ./show_message "Processing $CURRENT_SYSTEM of $TOTAL_SYSTEMS: $SYSTEM_NAME" -t 1
        SYSTEM_RENAMED=$(process_system_quiet "$SYSTEM_NAME")
        TOTAL_RENAMED=$((TOTAL_RENAMED + SYSTEM_RENAMED))
    done < "$TEMP_SYSTEMS"
    ./show_message "Boxart Renaming Complete\n\nSystems processed: $TOTAL_SYSTEMS\nTotal files renamed: $TOTAL_RENAMED" -l -a "OK"
    return 0
}

while true; do
    create_main_menu
    SELECTION=$(./picker "$TEMP_MENU")
    if [ -z "$SELECTION" ]; then
        exit 0
    fi
    ACTION=$(echo "$SELECTION" | cut -d'|' -f2)
    case "$ACTION" in
        "all")
            process_all_systems
        ;;
        "select")
            if create_systems_menu; then
                SYSTEM_SELECTION=$(./picker "$TEMP_SYSTEMS")
                if [ -n "$SYSTEM_SELECTION" ]; then
                    SELECTED_SYSTEM=$(echo "$SYSTEM_SELECTION" | cut -d'|' -f2)
                    process_system "$SELECTED_SYSTEM"
                fi
            fi
        ;;
    esac
done
