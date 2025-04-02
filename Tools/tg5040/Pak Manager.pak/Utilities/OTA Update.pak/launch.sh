#!/bin/sh
DIR=$(dirname "$0")
cd "$DIR"

MINUI_VERSION_FILE="/mnt/SDCARD/.system/version.txt"
PAKUI_VERSION_FILE="/mnt/SDCARD/.pakui/version.txt"
DOWNLOAD_DIR="/mnt/SDCARD"
TEMP_DIR="/tmp/ota_update"
UPDATER_LIST="/tmp/updater_list.txt"

check_connectivity() {
   ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 ||
   ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 ||
   ping -c 1 -W 2 208.67.222.222 >/dev/null 2>&1 ||
   ping -c 1 -W 2 114.114.114.114 >/dev/null 2>&1 ||
   ping -c 1 -W 2 119.29.29.29 >/dev/null 2>&1
}

get_clean_version() {
   echo "$1" | sed -e 's/-base\.zip$//'
}

get_version_date() {
   echo "$1" | grep -o '[0-9]\{8\}'
}

get_version_revision() {
   echo "$1" | grep -o '[0-9]$'
}

version_greater() {
   local ver1=$(get_clean_version "$1")
   local ver2=$(get_clean_version "$2")
   local ver1_date=$(get_version_date "$ver1")
   local ver2_date=$(get_version_date "$ver2")
   local ver1_rev=$(get_version_revision "$ver1")
   local ver2_rev=$(get_version_revision "$ver2")
   
   if [ "$ver1_date" -gt "$ver2_date" ]; then
       return 0
   elif [ "$ver1_date" -eq "$ver2_date" ] && [ "$ver1_rev" -gt "$ver2_rev" ]; then
       return 0
   fi
   return 1
}

check_minui_update() {
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    if [ ! -f "$MINUI_VERSION_FILE" ]; then
        ./show_message "Error: Cannot find MinUI version" -l a -a "OK"
        return 1
    fi
    
    MINUI_VERSION=$(head -n 1 "$MINUI_VERSION_FILE")
    
    ./show_message "Checking for MinUI updates..." &
    SHOW_MESSAGE_PID=$!
    
    if ! wget -q -O "$TEMP_DIR/latest" "https://api.github.com/repos/shauninman/MinUI/releases/latest"; then
        kill $SHOW_MESSAGE_PID 2>/dev/null
        ./show_message "Error: Failed to check for updates" -l a -a "OK"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    BASE_URL=$(grep -o '"browser_download_url": *"[^"]*-base\.zip"' "$TEMP_DIR/latest" | cut -d'"' -f4)
    if [ -z "$BASE_URL" ]; then
        kill $SHOW_MESSAGE_PID 2>/dev/null
        ./show_message "Error: Update information not found" -l a -a "OK"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    LATEST_VERSION=$(basename "$BASE_URL" | sed 's/-base\.zip$//')
    
    if ! version_greater "$LATEST_VERSION" "$MINUI_VERSION"; then
        kill $SHOW_MESSAGE_PID 2>/dev/null
        ./show_message "No MinUI updates available" -l ab -a "OK" -b "Reinstall"
        
        if [ $? = 2 ]; then
            ./show_message "Reinstall latest MinUI?" -l ab -a "OK" -b "Cancel"
            if [ $? = 2 ]; then
                rm -rf "$TEMP_DIR"
                return 0
            fi
        else
            rm -rf "$TEMP_DIR"
            return 0
        fi
    else
        kill $SHOW_MESSAGE_PID 2>/dev/null
        ./show_message "MinUI update available|Current: $MINUI_VERSION|Latest: $LATEST_VERSION|Update now?" -l ab -a "OK" -b "CANCEL"
        
        if [ $? = 2 ]; then
            rm -rf "$TEMP_DIR"
            return 0
        fi
    fi
    
    ./show_message "Downloading MinUI|$LATEST_VERSION..." &
    SHOW_MESSAGE_PID=$!
    
    if ! wget -O "$TEMP_DIR/base.zip" "$BASE_URL"; then
        kill $SHOW_MESSAGE_PID 2>/dev/null
        ./show_message "Error: Failed to download update" -l a -a "OK"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    kill $SHOW_MESSAGE_PID 2>/dev/null
    
    if ! unzip -j "$TEMP_DIR/base.zip" "MinUI.zip" -d "$DOWNLOAD_DIR"; then
        ./show_message "Error: Failed to extract update" -l a -a "OK"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    rm -rf "$TEMP_DIR"
    
    ./show_message "Rebooting to apply..." &
    REBOOT_MSG_PID=$!
    sleep 2
    kill $REBOOT_MSG_PID 2>/dev/null
    reboot
}

check_pakui_update() {
    if [ ! -f "$PAKUI_VERSION_FILE" ]; then
        ./show_message "Error: Cannot find PakUI version|Make sure PakUI is installed." -l a -a "OK"
        return 1
    fi
    
    PAKUI_VERSION=$(head -n 1 "$PAKUI_VERSION_FILE")
    ./show_message "PakUI OTA Updates|Coming Soon!|Current Version: $PAKUI_VERSION|This feature will be available|in a future update." -l a -a "OK"
    return 0
}

main() {
    if ! check_connectivity; then
        ./show_message "No internet connection|Please check your WiFi settings." -l a -a "OK"
        exit 1
    fi
    
    > "$UPDATER_LIST"
    echo "OTA Updater|__HEADER__|header" >> "$UPDATER_LIST"
    echo "Check for MinUI Update|minui" >> "$UPDATER_LIST"
    echo "Check for PakUI Update|pakui" >> "$UPDATER_LIST"
    
    menu_idx=0
    while true; do
        picker_output=$(./picker "$UPDATER_LIST" -i $menu_idx -b "EXIT" -t "OTA Update")
        picker_status=$?
        
        if [ -n "$picker_output" ]; then
            menu_idx=$(grep -n "^${picker_output%$'\n'}$" "$UPDATER_LIST" | cut -d: -f1 || echo "0")
            menu_idx=$((menu_idx - 1))
            [ $menu_idx -lt 0 ] && menu_idx=0
        fi
        
        if [ $picker_status -ne 0 ] || [ -z "$picker_output" ]; then
            break
        fi
        
        if echo "$picker_output" | grep -q "^OTA Updater|"; then
            continue
        else
            action=$(echo "$picker_output" | cut -d'|' -f2)
            
            case "$action" in
                minui)
                    check_minui_update
                    ;;
                pakui)
                    check_pakui_update
                    ;;
                *)
                    ./show_message "Unknown option" -l a -a "OK"
                    ;;
            esac
        fi
    done
    
    rm -f "$UPDATER_LIST"
    exit 0
}

main