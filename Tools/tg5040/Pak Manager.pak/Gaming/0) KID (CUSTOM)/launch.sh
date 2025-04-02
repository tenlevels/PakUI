#!/bin/sh
cd "$(dirname "$0")"
export LD_LIBRARY_PATH=/usr/trimui/lib:$LD_LIBRARY_PATH
MENU_UNLOCKED=0

# Dynamically determine our own path - this works regardless of where we're installed
KIDMODE_FULL_PATH="$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")"
KIDMODE_DIR="$(cd "$(dirname "$0")" && pwd -P)"
SCRIPT_DIR="$KIDMODE_DIR"
HELPER_SCRIPT="${SCRIPT_DIR}/kidmode_helper.sh"

# Get the collection name without prefix or tag
CURRENT_DIR=$(basename "$(pwd -P)")
# Remove sorting prefix (like "0) " or "1_") - handles multiple formats
CLEAN_NAME=$(echo "$CURRENT_DIR" | sed -E 's/^[0-9]+[)\._ -]+//' | sed 's/ ([^)]*)$//')

# Display personalized welcome message
"$SCRIPT_DIR/show_message" "Hello $CLEAN_NAME!" -t 2

clean_auto_sh() {
    # Avoid hardcoding the path - clean all kid mode markers
    if [ -d "/mnt/SDCARD/.userdata" ]; then
        for platform_dir in /mnt/SDCARD/.userdata/*; do
            if [ -d "$platform_dir" ]; then
                AUTO_SH="$platform_dir/auto.sh"
                if [ -f "$AUTO_SH" ]; then
                    sed -i '/# KIDMODE_AUTO_MARKER/d' "$AUTO_SH"
                fi
            fi
        done
    fi
}

clean_emulator_scripts() {
    if [ -d "/mnt/SDCARD/Emus" ]; then
        for script in $(find /mnt/SDCARD/Emus -name "launch.sh"); do
            if grep -q "# KIDMODE_REDIRECT" "$script"; then
                # Only remove our own markers, not the entire line
                sed -i '/# KIDMODE_REDIRECT/d' "$script"
            fi
        done
    fi
    
    if [ -d "/mnt/SDCARD/.system/$PLATFORM/paks/Emus" ]; then
        for script in $(find "/mnt/SDCARD/.system/$PLATFORM/paks/Emus" -name "launch.sh"); do
            if grep -q "# KIDMODE_REDIRECT" "$script"; then
                # Only remove our own markers, not the entire line
                sed -i '/# KIDMODE_REDIRECT/d' "$script"
            fi
        done
    fi
}

inject_exec_line() {
    add_exec_line_if_missing() {
        local file="$1"
        # Only modify emulator launchers, not our own script
        if [ "$file" = "$KIDMODE_FULL_PATH" ]; then
            return
        fi
        
        # Check if the file ends with a newline
        if [ -f "$file" ] && [ -s "$file" ]; then
            local last_char=$(tail -c 1 "$file" | hexdump -e '1/1 "%02x"')
            if [ "$last_char" != "0a" ]; then
                # Add a newline if missing
                echo "" >> "$file"
            fi
        fi
        
        # Remove any existing redirect lines first to avoid duplicates
        sed -i '/# KIDMODE_REDIRECT/d' "$file"
        
        # Add an extra blank line for safety
        echo "" >> "$file"
        
        # Add our launch path to the emulator script
        echo "exec \"$KIDMODE_FULL_PATH\" # KIDMODE_REDIRECT" >> "$file"
    }
    
    if [ -d "/mnt/SDCARD/.system/$PLATFORM/paks/Emus" ]; then
        for pak in /mnt/SDCARD/.system/$PLATFORM/paks/Emus/*.pak; do
            if [ -f "$pak/launch.sh" ]; then
                if echo "$pak" | grep -q "/CUSTOM\.pak$"; then
                    continue
                fi
                add_exec_line_if_missing "$pak/launch.sh"
            fi
        done
    fi
    
    if [ -d "/mnt/SDCARD/Emus" ]; then
        find "/mnt/SDCARD/Emus" -type f -name "launch.sh" | while read -r EMU_LAUNCHER; do
            if echo "$EMU_LAUNCHER" | grep -q "/CUSTOM\.pak/launch\.sh$"; then
                continue
            fi
            add_exec_line_if_missing "$EMU_LAUNCHER"
        done
    fi
}

update_auto_sh() {
    if [ -d "/mnt/SDCARD/.userdata" ]; then
        for platform_dir in /mnt/SDCARD/.userdata/*; do
            if [ -d "$platform_dir" ]; then
                AUTO_SH="$platform_dir/auto.sh"
                if [ -f "$AUTO_SH" ]; then
                    # Check if the file ends with a newline
                    if [ -s "$AUTO_SH" ]; then
                        last_char=$(tail -c 1 "$AUTO_SH" | hexdump -e '1/1 "%02x"')
                        if [ "$last_char" != "0a" ]; then
                            # Add a newline if missing
                            echo "" >> "$AUTO_SH"
                        fi
                    fi
                    
                    # Add an extra blank line for safety
                    echo "" >> "$AUTO_SH"
                    
                    # Remove any existing Kid Mode markers
                    sed -i '/# KIDMODE_AUTO_MARKER/d' "$AUTO_SH"
                    
                    # Add the execute line to call our helper script
                    echo "exec \"$HELPER_SCRIPT\" # KIDMODE_AUTO_MARKER" >> "$AUTO_SH"
                else
                    # Create auto.sh if it doesn't exist
                    echo "#!/bin/sh" > "$AUTO_SH"
                    echo "" >> "$AUTO_SH"
                    echo "exec \"$HELPER_SCRIPT\" # KIDMODE_AUTO_MARKER" >> "$AUTO_SH"
                    chmod +x "$AUTO_SH"
                fi
            fi
        done
    fi
}

# Start monitoring for power button press in the background
start_power_monitor() {
    # Only start if not already running
    if [ -z "$POWER_MONITOR_PID" ] || ! kill -0 $POWER_MONITOR_PID 2>/dev/null; then
        # Monitor power button events
        "$SCRIPT_DIR/evtest" "/dev/input/event1" 2>/dev/null | while read -r line; do
            if echo "$line" | grep "code 116 (KEY_POWER)" | grep -q "value 1"; then
                # Power button was pressed
                # Kill picker first to clear the screen
                killall picker 2>/dev/null 
                sleep 0.2
                # Now show message on clean screen
                "$SCRIPT_DIR/show_message" "See you again soon!" -t 2
                
                # Set up auto-boot to Kid Mode on next power on
                update_auto_sh
                
                # Now power off the device
                poweroff
            fi
        done &
        POWER_MONITOR_PID=$!
    fi
}

# Stop power button monitoring
stop_power_monitor() {
    if [ -n "$POWER_MONITOR_PID" ]; then
        kill $POWER_MONITOR_PID 2>/dev/null
        POWER_MONITOR_PID=""
    fi
}

# Create direct launcher for handling game execution with auto-return
create_kid_game_launcher() {
    local emu_script="$1"
    local rom_path="$2"
    local launcher_script="/tmp/kid_game_launcher.sh"
    
    # Create a script that will launch the game and return to kid mode
    cat > "$launcher_script" << EOF
#!/bin/sh
# Direct launcher script for Kid Mode

# Make sure the auto_resume.txt is removed so MinUI doesn't try to resume again
rm -f "/mnt/SDCARD/.userdata/shared/.minui/auto_resume.txt"

# Create a sentinel file to indicate we're running
touch "/tmp/kidmode_active"

# Launch the game directly
"$emu_script" "$rom_path"

# After the game exits, directly launch kid mode if sentinel exists
if [ -f "/tmp/kidmode_active" ]; then
    rm -f "/tmp/kidmode_active"
    exec "$KIDMODE_FULL_PATH"
fi
EOF
    
    chmod +x "$launcher_script"
    echo "$launcher_script"
}

# Function to handle exiting Kid Mode with password
exit_kid_mode() {
    "$SCRIPT_DIR/show_message" "Exit Kid Mode?" -l ab -a "YES" -b "NO"
    if [ $? -eq 0 ]; then
        # Ask for password
        if check_password; then
            # Password correct, run exit procedure
            clean_up_redirects
            "$SCRIPT_DIR/show_message" "Exiting Kid Mode" -d 1
            cleanup
            exit 0
        fi
    fi
}

# Clean up all redirects when exiting Kid Mode
clean_up_redirects() {
    # Clean up emulator scripts
    clean_emulator_scripts
    
    # Clean auto.sh files
    clean_auto_sh
}

# Run initial setup to ensure auto-resume will work properly next boot
update_auto_sh

MENU="menu.txt"
DUMMY_ROM="__COLLECTION__"

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
    SLOT=$(cat "$SLOT_FILE")
    echo $SLOT > /tmp/resume_slot.txt
}

function cleanup {
    rm -f /tmp/keyboard_output.txt /tmp/picker_output.txt /tmp/search_results.txt /tmp/add_favorites.txt /tmp/browser_selection.txt /tmp/browser_history.txt /tmp/kid_game_launcher.sh /tmp/kidmode_active
    
    # Stop power button monitoring
    stop_power_monitor
}

function check_password {
    "$SCRIPT_DIR/show_message" "Enter password to continue" -d 1
    entered_password=$("$SCRIPT_DIR/keyboard" minui.ttf)
    
    # Path to the password file
    PASSWORD_FILE="$SCRIPT_DIR/password.txt"
    
    # Create the password file with default password if it doesn't exist
    if [ ! -f "$PASSWORD_FILE" ]; then
        echo "1234" > "$PASSWORD_FILE"
        chmod 600 "$PASSWORD_FILE"
    fi
    
    # Read the stored password
    stored_password=$(cat "$PASSWORD_FILE")
    
    if [ "$entered_password" = "$stored_password" ]; then
        return 0
    else
        "$SCRIPT_DIR/show_message" "Incorrect Password" -d 2
        return 1
    fi
}

# Make sure we have a clean name for the menu
COLLECTION_NAME=$CLEAN_NAME
ADD_TO_TEXT="$COLLECTION_NAME|$DUMMY_ROM|locked"
[ -f "$MENU" ] || echo "$ADD_TO_TEXT" > "$MENU"

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
    # Start the power button monitor when in the menu
    start_power_monitor
    
    # Refresh clean name in case folder was renamed
    CURRENT_DIR=$(basename "$(pwd -P)")
    CLEAN_NAME=$(echo "$CURRENT_DIR" | sed -E 's/^[0-9]+[)\._ -]+//' | sed 's/ ([^)]*)$//')
    COLLECTION_NAME=$CLEAN_NAME
    ADD_TO_TEXT="$COLLECTION_NAME|$DUMMY_ROM|locked"
    sed -i "1s/^.*|.*|.*\$/$ADD_TO_TEXT/" "$MENU"
    
    killall picker 2>/dev/null
    picker_output=$("$SCRIPT_DIR/game_picker" "$MENU" -i $main_menu_idx -x "RESUME" -y "OPTIONS" -b "EXIT")
    picker_status=$?
    main_menu_idx=$(grep -n "^${picker_output%$'\n'}$" "$MENU" | cut -d: -f1)
    main_menu_idx=$((main_menu_idx - 1))
    
    # Handle direct exit when B button (EXIT) is pressed
    if [ $picker_status -eq 2 ]; then
        exit_kid_mode
        continue
    fi
    
    if [ $picker_status -eq 4 ]; then
         entry_action=$(echo "$picker_output" | cut -d'|' -f3)
         if [ "$entry_action" = "locked" ]; then
              if [ $MENU_UNLOCKED -ne 1 ]; then
                   check_password
                   if [ $? -eq 0 ]; then
                        MENU_UNLOCKED=1
                   else
                        continue
                   fi
              fi
              options_output=$("$SCRIPT_DIR/picker" "menu_options.txt")
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
         if [ $MENU_UNLOCKED -ne 1 ]; then
              check_password
              if [ $? -eq 0 ]; then
                   MENU_UNLOCKED=1
              else
                   continue
              fi
         fi
         options_output=$("$SCRIPT_DIR/picker" "game_options.txt")
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
    [ $picker_status -eq 1 ] || [ $picker_status -gt 4 ] && cleanup && exit $picker_status
    action=$(echo "$picker_output" | cut -d'|' -f3)
    case "$action" in
        "launch")
            ROM=$(echo "$picker_output" | cut -d'|' -f2)
            if [ "$ROM" = "$DUMMY_ROM" ]; then
                options_output=$("$SCRIPT_DIR/picker" "menu_options.txt")
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
                    
                    # Add redirect to emulator scripts
                    inject_exec_line
                    
                    # Update auto.sh to ensure we come back to Kid Mode on boot
                    update_auto_sh
                    
                    # Stop power button monitoring before launching game
                    stop_power_monitor
                    
                    # Create and use a launcher instead of direct execution
                    LAUNCHER=$(create_kid_game_launcher "$EMULATOR" "$ROM")
                    exec "$LAUNCHER"
                elif [ -d "/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$ROM_PLATFORM.pak" ]; then
                    EMULATOR="/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$ROM_PLATFORM.pak/launch.sh"
                    
                    # Add redirect to emulator scripts
                    inject_exec_line
                    
                    # Update auto.sh to ensure we come back to Kid Mode on boot
                    update_auto_sh
                    
                    # Stop power button monitoring before launching game
                    stop_power_monitor
                    
                    # Create and use a launcher instead of direct execution
                    LAUNCHER=$(create_kid_game_launcher "$EMULATOR" "$ROM")
                    exec "$LAUNCHER"
                else
                    "$SCRIPT_DIR/show_message" "Emulator not found for $ROM_PLATFORM" -l a
                fi
            else
                "$SCRIPT_DIR/show_message" "Game file not found|$ROM" -l a
            fi
            ;;
        "menu_options")
            options_output=$("$SCRIPT_DIR/picker" "menu_options.txt")
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
cleanup