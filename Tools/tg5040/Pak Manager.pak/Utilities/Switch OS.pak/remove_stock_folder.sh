#!/bin/sh

# Path definitions
SDCARD_PATH="/mnt/SDCARD"
ROMS_PATH="${SDCARD_PATH}/Roms"
FOLDERS_MAPPING="${ROMS_PATH}/roms_folders.txt"
USERDATA_PATH="${SDCARD_PATH}/.userdata"

# Clean up auto.sh files by removing this script's execution line
clean_autostart() {
    if [ -d "$USERDATA_PATH" ]; then
        for platform_dir in "$USERDATA_PATH"/*; do
            if [ -d "$platform_dir" ]; then
                AUTO_SH="$platform_dir/auto.sh"
                if [ -f "$AUTO_SH" ]; then
                    # Remove our script call from auto.sh
                    sed -i '/remove_stock_folder\.sh.*ADDED BY SWITCH OS/d' "$AUTO_SH"
                fi
            fi
        done
    fi
}

# Remove stock folders that have MinUI equivalents
remove_stock_folders() {
    # If mapping file doesn't exist, we can't determine which folders to remove
    if [ ! -f "$FOLDERS_MAPPING" ]; then
        return 1
    fi
    
    # Create a list of all emulator tags from the mapping file
    TMP_TAGS="${ROMS_PATH}/.tmp_cleanup_tags.txt"
    > "$TMP_TAGS"
    
    # Extract all emulator tags (just the tag, not the full name)
    while IFS= read -r line || [ -n "$line" ]; do
        [ -z "$line" ] && continue
        
        tag=$(echo "$line" | cut -d'|' -f1)
        
        if [ ! -z "$tag" ]; then
            echo "$tag" >> "$TMP_TAGS"
        fi
    done < "$FOLDERS_MAPPING"
    
    # Get a list of all MinUI folders for comparison
    TMP_MINUI="${ROMS_PATH}/.tmp_minui_folders.txt"
    > "$TMP_MINUI"
    
    # Find all MinUI-formatted folders (containing parentheses)
    find "$ROMS_PATH" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
        dirname=$(basename "$dir")
        if echo "$dirname" | grep -q "(.*)" ; then
            echo "$dirname" >> "$TMP_MINUI"
        fi
    done
    
    # Now remove any folder that matches a tag and isn't a MinUI folder
    find "$ROMS_PATH" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
        dirname=$(basename "$dir")
        
        # Skip MinUI-formatted folders (containing parentheses)
        if echo "$dirname" | grep -q "(.*)" ; then
            continue
        fi
        
        # Check if this folder name matches one of our emulator tags
        if grep -q "^$dirname$" "$TMP_TAGS"; then
            # This is a stock folder that corresponds to a MinUI folder, remove it
            rm -rf "$dir"
        fi
    done
    
    # Clean up temporary files
    rm -f "$TMP_TAGS" "$TMP_MINUI"
    
    sync
    return 0
}

# Main execution
remove_stock_folders
clean_autostart

exit 0