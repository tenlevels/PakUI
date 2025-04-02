#!/bin/sh
cd "$(dirname "$0")"
SDCARD_PATH="/mnt/SDCARD"
TMP_UPDATE_PATH="${SDCARD_PATH}/.tmp_update"
UPDATER_PATH="${TMP_UPDATE_PATH}/updater"
MINUI_UPDATER_PATH="${TMP_UPDATE_PATH}/updater.minui"
SPRUCE_UPDATER_PATH="${TMP_UPDATE_PATH}/updater.spruce"
ROMS_PATH="${SDCARD_PATH}/Roms"
FOLDERS_MAPPING="${ROMS_PATH}/roms_folders.txt"

restore_rom_folders() {
    if [ ! -d "$ROMS_PATH" ] || [ ! -f "$FOLDERS_MAPPING" ]; then
        return 1
    fi
    
    while IFS= read -r line || [ -n "$line" ]; do
        [ -z "$line" ] && continue
        
        tag=$(echo "$line" | cut -d'|' -f1)
        original_name=$(echo "$line" | cut -d'|' -f2-)
        
        if [ -z "$tag" ] || [ -z "$original_name" ]; then
            continue
        fi
        
        if [ -d "$ROMS_PATH/$tag" ] && [ ! -d "$ROMS_PATH/$original_name" ]; then
            mv "$ROMS_PATH/$tag" "$ROMS_PATH/$original_name"
        elif [ -d "$ROMS_PATH/$tag" ] && [ -d "$ROMS_PATH/$original_name" ]; then
            mkdir -p "$ROMS_PATH/$original_name/"
            cp -rf "$ROMS_PATH/$tag/"* "$ROMS_PATH/$original_name/" 2>/dev/null
            rm -rf "$ROMS_PATH/$tag"
        fi
    done < "$FOLDERS_MAPPING"
    
    sync
    return 0
}

./show_message "Preparing to switch to MinUI...|Restoring ROM folders..." &
SHOW_PID=$!

restore_status=0
if [ -f "$FOLDERS_MAPPING" ]; then
    restore_rom_folders
    restore_status=$?
fi

kill $SHOW_PID 2>/dev/null
./show_message "Switching to MinUI..." &
SHOW_PID=$!

if [ -f "$UPDATER_PATH" ]; then
    mv "$UPDATER_PATH" "$SPRUCE_UPDATER_PATH"
fi

if [ -f "$MINUI_UPDATER_PATH" ]; then
    mv "$MINUI_UPDATER_PATH" "$UPDATER_PATH"
    if [ $? -eq 0 ]; then
        kill $SHOW_PID 2>/dev/null
        
        if [ $restore_status -eq 0 ]; then
            ./show_message "Switching to MinUI|ROM folders restored|Device will reboot now" -l a -a "OK"
        else
            ./show_message "Switching to MinUI|ROM folders not restored|Device will reboot now" -l a -a "OK"
        fi
        sync
        reboot
    else
        kill $SHOW_PID 2>/dev/null
        ./show_message "Error: Failed to switch OS" -l a -a "OK"
        exit 1
    fi
else
    kill $SHOW_PID 2>/dev/null
    ./show_message "Error: MinUI updater not found|Cannot switch to MinUI" -l a -a "OK"
    exit 1
fi