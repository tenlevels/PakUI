#!/bin/sh
cd "$(dirname "$0")"
SDCARD_PATH="/mnt/SDCARD"
TMP_UPDATE_PATH="${SDCARD_PATH}/.tmp_update"
UPDATER_PATH="${TMP_UPDATE_PATH}/updater"
MINUI_UPDATER_PATH="${TMP_UPDATE_PATH}/updater.minui"
SPRUCE_UPDATER_PATH="${TMP_UPDATE_PATH}/updater.spruce"
ROMS_PATH="${SDCARD_PATH}/Roms"
FOLDERS_MAPPING="${ROMS_PATH}/roms_folders.txt"
# Don't redefine $PLATFORM as it's a MinUI variable

rename_rom_folders() {
    if [ ! -d "$ROMS_PATH" ]; then
        return 1
    fi
    > "$FOLDERS_MAPPING"
    
    find "$ROMS_PATH" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
        dirname=$(basename "$dir")
        if echo "$dirname" | grep -q "(.*)" ; then
            tag=$(echo "$dirname" | sed -n 's/.*(\([^)]*\)).*/\1/p')
            
            if [ ! -z "$tag" ]; then
                clean_tag=$(echo "$tag" | tr -d ' ')
                echo "$clean_tag|$dirname" >> "$FOLDERS_MAPPING"
                
                if [ ! -d "$ROMS_PATH/$clean_tag" ]; then
                    mv "$dir" "$ROMS_PATH/$clean_tag"
                else
                    cp -rf "$dir/"* "$ROMS_PATH/$clean_tag/" 2>/dev/null
                    rm -rf "$dir"
                fi
            fi
        fi
    done
    sync
    return 0
}

copy_app_folders() {
    if [ -d "./App" ]; then
        cp -rf "./App" "${SDCARD_PATH}/"
    fi
    if [ -d "./Apps" ]; then
        cp -rf "./Apps" "${SDCARD_PATH}/"
    fi
    sync
    return 0
}

inject_cleanup_script() {
    # Use the $PLATFORM variable directly, don't redefine it
    CLEANUP_SCRIPT="/mnt/SDCARD/Tools/\$PLATFORM/Switch OS.pak/remove_stock_folder.sh"
    
    if [ -d "/mnt/SDCARD/.userdata" ]; then
        for platform_dir in /mnt/SDCARD/.userdata/*; do
            if [ -d "$platform_dir" ]; then
                AUTO_SH="$platform_dir/auto.sh"
                if [ -f "$AUTO_SH" ]; then
                    # Remove any existing cleanup script line first
                    sed -i '/remove_stock_folder\.sh.*ADDED BY SWITCH OS/d' "$AUTO_SH"
                    # Add our cleanup script to auto.sh on a clean line
                    echo "" >> "$AUTO_SH"
                    echo "\"$CLEANUP_SCRIPT\" # ADDED BY SWITCH OS" >> "$AUTO_SH"
                fi
            fi
        done
    fi
    sync
}

OPTIONS_FILE="/tmp/os_options.txt"
if [ -f "$UPDATER_PATH" ]; then
    echo "Switch to Stock OS|stock" > "$OPTIONS_FILE"
    echo "Switch to Spruce OS|spruce" >> "$OPTIONS_FILE"
    picker_output=$(./picker "$OPTIONS_FILE" -a "SELECT" -b "CANCEL")
    picker_status=$?
    if [ $picker_status -ne 0 ]; then
        rm -f "$OPTIONS_FILE"
        exit 0
    fi
    selected_os=$(echo "$picker_output" | cut -d'|' -f2)
    
    # Inject cleanup script for when we return to MinUI
    inject_cleanup_script
    
    ./show_message "Preparing to switch OS...|Renaming ROM folders..." &
    SHOW_PID=$!
    rename_rom_folders
    rename_status=$?
    if [ $rename_status -ne 0 ]; then
        kill $SHOW_PID 2>/dev/null
        ./show_message "Error: Failed to rename ROM folders" -l a -a "OK"
        rm -f "$OPTIONS_FILE"
        exit 1
    fi
    copy_app_folders
    kill $SHOW_PID 2>/dev/null
    ./show_message "Switching OS..." &
    SHOW_PID=$!
    case "$selected_os" in
        "stock")
            mv "$UPDATER_PATH" "$MINUI_UPDATER_PATH"
            success=$?
            target="Stock OS"
            ;;
        "spruce")
            if [ -f "$SPRUCE_UPDATER_PATH" ]; then
                mv "$UPDATER_PATH" "$MINUI_UPDATER_PATH"
                mv "$SPRUCE_UPDATER_PATH" "$UPDATER_PATH"
                success=$?
            else
                kill $SHOW_PID 2>/dev/null
                ./show_message "Error: Spruce updater not found|Cannot switch to Spruce OS" -l a -a "OK"
                rm -f "$OPTIONS_FILE"
                exit 1
            fi
            target="Spruce OS"
            ;;
    esac
    kill $SHOW_PID 2>/dev/null
    if [ $success -eq 0 ]; then
        ./show_message "Switching to ${target}|ROM folders renamed|Device will reboot now" -l a -a "OK"
        sync
        reboot
    else
        ./show_message "Error: Failed to switch OS" -l a -a "OK"
        exit 1
    fi
else
    ./show_message "Error: Already in Stock/Spruce OS|Cannot switch again" -l a -a "OK"
    exit 1
fi
rm -f "$OPTIONS_FILE"