#!/bin/sh
cd "$(dirname "$0")"
export LD_LIBRARY_PATH=/usr/trimui/lib:$LD_LIBRARY_PATH

SCRIPT_DIR=$(dirname "$0")
BOOT_TO_CONFIG="${SCRIPT_DIR}/boot_to.txt"
HELPER_SCRIPT="${SCRIPT_DIR}/boot_to_helper.sh"

# Clean up auto.sh files
clean_auto_sh() {
    if [ -d "/mnt/SDCARD/.userdata" ]; then
        for platform_dir in /mnt/SDCARD/.userdata/*; do
            if [ -d "$platform_dir" ]; then
                AUTO_SH="$platform_dir/auto.sh"
                if [ -f "$AUTO_SH" ]; then
                    # Only remove our own markers, not the entire line
                    sed -i '/# BOOT_TO_AUTO_MARKER/d' "$AUTO_SH"
                fi
            fi
        done
    fi
}

# Clean up any emulator redirects
clean_emulator_scripts() {
    for script in $(find /mnt/SDCARD/Emus -name "launch.sh"); do
        if grep -q "# BOOT_TO_REDIRECT" "$script"; then
            # Only remove our own markers, not the entire line
            sed -i '/# BOOT_TO_REDIRECT/d' "$script"
        fi
    done
    
    if [ -d "/mnt/SDCARD/.system/$PLATFORM/paks/Emus" ]; then
        for script in $(find "/mnt/SDCARD/.system/$PLATFORM/paks/Emus" -name "launch.sh"); do
            if grep -q "# BOOT_TO_REDIRECT" "$script"; then
                # Only remove our own markers, not the entire line
                sed -i '/# BOOT_TO_REDIRECT/d' "$script"
            fi
        done
    fi
}

# Set up auto.sh to call the helper script
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
                    
                    # Add one clean line to auto.sh
                    echo "exec \"$HELPER_SCRIPT\" # BOOT_TO_AUTO_MARKER" >> "$AUTO_SH"
                else
                    # Create auto.sh if it doesn't exist
                    echo "#!/bin/sh" > "$AUTO_SH"
                    echo "" >> "$AUTO_SH"
                    echo "exec \"$HELPER_SCRIPT\" # BOOT_TO_AUTO_MARKER" >> "$AUTO_SH"
                    chmod +x "$AUTO_SH"
                fi
            fi
        done
    fi
}

function cleanup {
    rm -f /tmp/keyboard_output.txt /tmp/picker_output.txt /tmp/browser_selection.txt /tmp/boot_options_current.txt /tmp/rom_dirs.txt /tmp/actual_games.txt /tmp/splore_files.txt
}

is_valid_rom() {
    local file="$1"
    # Allow PNG files if their parent folder has "pico" (case-insensitive)
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

folder_has_actual_roms() {
    local folder="$1"
    local found=0
    for file in "$folder"/*; do
        if [ -f "$file" ] && ! echo "$file" | grep -q "\.res"; then
            if is_valid_rom "$file"; then
                found=1
                break
            fi
        fi
    done
    return $((1-found))
}

# Clean a name by removing prefixes and tags
clean_display_name() {
    local name="$1"
    # Remove numeric prefixes (like "01_" or "1) ")
    name=$(echo "$name" | sed -E 's/^[0-9]+[)\._ -]+//')
    # Remove any content within parentheses at the end
    name=$(echo "$name" | sed 's/ *([^)]*)$//')
    # Make first letter uppercase for consistency
    name=$(echo ${name:0:1} | tr '[:lower:]' '[:upper:]')${name:1}
    echo "$name"
}

build_valid_rom_folders() {
    > /tmp/rom_dirs.txt
    ./show_message "Finding valid ROM folders..." &
    loading_pid=$!
    for folder in "/mnt/SDCARD/Roms/"*; do
        if [ -d "$folder" ]; then
            folder_name=$(basename "$folder")
            # Skip special folders
            if echo "$folder_name" | grep -qiE 'Game Switcher|Random Game|\.res|\(CUSTOM\)|\(RND\)|\(GS\)|\(BITPAL\)'; then
                continue
            fi
            if ! folder_has_actual_roms "$folder"; then
                continue
            fi
            clean_name=$(clean_display_name "$folder_name")
            platform=$(echo "$folder_name" | sed -n 's/.*(\(.*\)).*/\1/p')
            echo "$clean_name|$folder|$platform" >> /tmp/rom_dirs.txt
        fi
    done
    kill $loading_pid 2>/dev/null
}

get_current_boot_setting() {
    if [ -f "$BOOT_TO_CONFIG" ]; then
        boot_type=$(head -n 1 "$BOOT_TO_CONFIG" | cut -d'|' -f1)
        boot_name=$(head -n 1 "$BOOT_TO_CONFIG" | cut -d'|' -f2)
        if [ -n "$boot_name" ]; then
            echo "$boot_name"
            return 0
        fi
    fi
    
    echo "MinUI"
    return 0
}

find_special_script() {
    local folder_name="$1"
    local tag="$2"
    
    # Check for local script first if it's Random Game
    if [ "$folder_name" = "Random Game" ] && [ -f "${SCRIPT_DIR}/random_game.sh" ]; then
        echo "${SCRIPT_DIR}/random_game.sh"
        return 0
    fi
    
    # Search in Roms directory
    for dir in "/mnt/SDCARD/Roms/"*; do
        if [ -d "$dir" ]; then
            dir_name=$(basename "$dir")
            # Look for folder with the specified tag
            if echo "$dir_name" | grep -qi "($tag)"; then
                if [ -f "$dir/launch.sh" ]; then
                    echo "$dir/launch.sh"
                    return 0
                fi
            # Also try matching by name if no tag
            elif echo "$dir_name" | grep -qi "$folder_name"; then
                if [ -f "$dir/launch.sh" ]; then
                    echo "$dir/launch.sh"
                    return 0
                fi
            fi
        fi
    done
    
    # Search in Tools directory
    if [ -d "/mnt/SDCARD/Tools/$PLATFORM" ]; then
        for dir in "/mnt/SDCARD/Tools/$PLATFORM/"*; do
            if [ -d "$dir" ]; then
                dir_name=$(basename "$dir")
                # Look for folder with the specified tag
                if echo "$dir_name" | grep -qi "($tag)"; then
                    if [ -f "$dir/launch.sh" ]; then
                        echo "$dir/launch.sh"
                        return 0
                    fi
                # Also try matching by name
                elif echo "$dir_name" | grep -qi "$folder_name"; then
                    if [ -f "$dir/launch.sh" ]; then
                        echo "$dir/launch.sh"
                        return 0
                    fi
                fi
            fi
        done
    fi
    
    return 1
}

# Find PICO-8 Splore files
find_pico8_splore_files() {
    > /tmp/splore_files.txt
    ./show_message "Finding PICO-8 Splore files..." &
    loading_pid=$!
    
    # First look in folders with (PICO-8) tag
    for dir in "/mnt/SDCARD/Roms/"*; do
        if [ -d "$dir" ] && echo "$(basename "$dir")" | grep -qi "(PICO-8)"; then
            for file in "$dir"/*; do
                if [ -f "$file" ] && echo "$(basename "$file")" | grep -qi "splore"; then
                    # Store file with simple label
                    echo "PICO-8 Splore|$file" >> /tmp/splore_files.txt
                fi
            done
        fi
    done
    
    # Also look in folders with "pico" in the name
    for dir in "/mnt/SDCARD/Roms/"*; do
        if [ -d "$dir" ] && echo "$(basename "$dir")" | grep -qi "pico" && ! echo "$(basename "$dir")" | grep -qi "(PICO-8)"; then
            for file in "$dir"/*; do
                if [ -f "$file" ] && echo "$(basename "$file")" | grep -qi "splore"; then
                    # Store file with simple label
                    echo "PICO-8 Splore|$file" >> /tmp/splore_files.txt
                fi
            done
        fi
    done
    
    kill $loading_pid 2>/dev/null
    
    if [ ! -s /tmp/splore_files.txt ]; then
        return 1
    fi
    
    # Sort the files if there are multiple
    if [ $(wc -l < /tmp/splore_files.txt) -gt 1 ]; then
        sort -t'|' -k1,1 /tmp/splore_files.txt -o /tmp/splore_files.txt
    fi
    
    return 0
}

find_games_in_folder() {
    local folder="$1"
    > /tmp/actual_games.txt
    ./show_message "Scanning games..." &
    loading_pid=$!
    for file in "$folder"/*; do
        if [ -f "$file" ] && is_valid_rom "$file"; then
            filename=$(basename "$file")
            # Clean name for display - remove extension, prefixes, and tags
            clean_name=$(echo "$filename" | sed 's/\.[^.]*$//' | sed -E 's/^[0-9]+[)\._ -]+//' | sed 's/ *([^)]*)$//')
            # Capitalize first letter
            display_name=$(echo ${clean_name:0:1} | tr '[:lower:]' '[:upper:]')${clean_name:1}
            echo "$display_name|$file" >> /tmp/actual_games.txt
        fi
    done
    kill $loading_pid 2>/dev/null
    if [ -s /tmp/actual_games.txt ]; then
        sort -t'|' -k1,1 /tmp/actual_games.txt -o /tmp/actual_games.txt
    fi
}

setup_boot_option() {
    local boot_type="$1"
    local boot_option="$2"
    local boot_name="$3"
    local rom_path="$4"
    
    # Clean up previous boot settings
    clean_auto_sh
    clean_emulator_scripts
    
    # Update config file with the new boot option
    if [ "$boot_type" = "game" ]; then
        echo "$boot_type|$boot_name|$boot_option|$rom_path" > "$BOOT_TO_CONFIG"
    else
        echo "$boot_type|$boot_name|$boot_option" > "$BOOT_TO_CONFIG"
    fi
    
    # Update auto.sh to call our helper
    update_auto_sh
}

# Setup boot options menu
MENU="boot_to_menu.txt"
CUSTOM_TEXT="Boot To|__BOOT_TO__|select"
[ -f "$MENU" ] || echo "$CUSTOM_TEXT" > "$MENU"

> boot_options.txt
echo "MinUI|minui" > boot_options.txt
echo "BitPal|bitpal" >> boot_options.txt
echo "Game Switcher|gameswitcher" >> boot_options.txt
echo "Custom Collection|custom" >> boot_options.txt
echo "PICO-8 Splore|pico8splore" >> boot_options.txt
echo "Random Game|random" >> boot_options.txt
echo "Game|game" >> boot_options.txt
echo "Tool|tool" >> boot_options.txt

main_menu_idx=0
while true; do
    current_boot=$(get_current_boot_setting)
    > /tmp/boot_options_current.txt
    echo "Current: $current_boot|current" > /tmp/boot_options_current.txt
    cat boot_options.txt >> /tmp/boot_options_current.txt
    killall picker 2>/dev/null
    picker_output=$(./picker "/tmp/boot_options_current.txt" -i $main_menu_idx -a "SELECT" -b "EXIT")
    picker_status=$?
    if [ $main_menu_idx -gt 0 ]; then
        main_menu_idx=$((main_menu_idx + 1))
    fi
    if [ $picker_status -ne 0 ]; then
        cleanup
        exit 0
    fi
    boot_option=$(echo "$picker_output" | cut -d'|' -f2)
    if [ "$boot_option" = "current" ]; then
        ./show_message "Currently booting to:|$current_boot" -l ab -a "OK" -b "RESET"
        button_pressed=$?
        if [ $button_pressed -eq 2 ]; then
            if [ "$current_boot" != "MinUI" ]; then
                clean_auto_sh
                clean_emulator_scripts
                rm -f "$BOOT_TO_CONFIG"
                ./show_message "Boot to MinUI set!" -l a
                current_boot="MinUI"
            else
                ./show_message "Already booting to MinUI." -l a
            fi
        fi
        continue
    fi
    case "$boot_option" in
        "minui")
            if [ "$current_boot" = "MinUI" ]; then
                ./show_message "Already booting to MinUI." -l a
                continue
            fi
            ./show_message "Boot to MinUI?" -l ab -a "YES" -b "NO"
            if [ $? -eq 0 ]; then
                clean_auto_sh
                clean_emulator_scripts
                rm -f "$BOOT_TO_CONFIG"
                ./show_message "Boot to MinUI set!" -l a
            fi
            ;;
        "gameswitcher")
            gameswitcher_script=$(find_special_script "Game Switcher" "GS")
            if [ -z "$gameswitcher_script" ]; then
                ./show_message "Game Switcher not found!|Make sure you have Game Switcher|in your Roms or Tools directory." -l a
                continue
            fi
            ./show_message "Boot to Game Switcher?" -l ab -a "YES" -b "NO"
            if [ $? -eq 0 ]; then
                setup_boot_option "custom" "$gameswitcher_script" "Game Switcher"
                ./show_message "Boot to Game Switcher set!" -l a
            fi
            ;;
        "bitpal")
            bitpal_script=$(find_special_script "BitPal" "BITPAL")
            if [ -z "$bitpal_script" ]; then
                ./show_message "BitPal not found!|Make sure you have BitPal|in your Roms or Tools directory." -l a
                continue
            fi
            ./show_message "Boot to BitPal?" -l ab -a "YES" -b "NO"
            if [ $? -eq 0 ]; then
                setup_boot_option "custom" "$bitpal_script" "BitPal"
                ./show_message "Boot to BitPal set!" -l a
            fi
            ;;
        "pico8splore")
            # Find PICO-8 Splore files
            if ! find_pico8_splore_files; then
                ./show_message "No PICO-8 Splore files found!|Make sure you have files with 'splore'|in their name in a PICO-8 folder." -l a
                continue
            fi
            
            # If there's only one file, use it directly without prompting
            if [ $(wc -l < /tmp/splore_files.txt) -eq 1 ]; then
                splore_file=$(cat /tmp/splore_files.txt | cut -d'|' -f2)
                splore_name="PICO-8 Splore"
            else
                # Let user pick a splore file if multiple are found
                splore_output=$(./picker "/tmp/splore_files.txt" -t "Select PICO-8 Splore File")
                splore_status=$?
                if [ $splore_status -ne 0 ]; then
                    continue
                fi
                splore_file=$(echo "$splore_output" | cut -d'|' -f2)
                splore_name=$(echo "$splore_output" | cut -d'|' -f1)
            fi
            
            # Get the folder containing the splore file
            splore_dir=$(dirname "$splore_file")
            
            # Detect platform from folder name
            platform_tag=$(echo "$(basename "$splore_dir")" | sed -n 's/.*(\(.*\)).*/\1/p')
            if [ -z "$platform_tag" ]; then
                platform_tag="pico8"  # Default if no tag found
            fi
            
            # Try to find the emulator
            emu_path=""
            if [ -d "/mnt/SDCARD/Emus/$PLATFORM/$platform_tag.pak" ]; then
                emu_path="/mnt/SDCARD/Emus/$PLATFORM/$platform_tag.pak/launch.sh"
            elif [ -d "/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$platform_tag.pak" ]; then
                emu_path="/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$platform_tag.pak/launch.sh"
            elif [ -d "/mnt/SDCARD/Emus/$PLATFORM/pico8.pak" ]; then
                emu_path="/mnt/SDCARD/Emus/$PLATFORM/pico8.pak/launch.sh"
            elif [ -d "/mnt/SDCARD/.system/$PLATFORM/paks/Emus/pico8.pak" ]; then
                emu_path="/mnt/SDCARD/.system/$PLATFORM/paks/Emus/pico8.pak/launch.sh"
            fi
            
            if [ -z "$emu_path" ] || [ ! -f "$emu_path" ]; then
                ./show_message "PICO-8 emulator not found!|Make sure you have the PICO-8|emulator installed." -l a
                continue
            fi
            
            ./show_message "Boot to PICO-8 Splore?" -l ab -a "YES" -b "NO"
            if [ $? -eq 0 ]; then
                setup_boot_option "game" "$emu_path" "PICO-8 Splore" "$splore_file"
                ./show_message "Boot to PICO-8 Splore set!" -l a
            fi
            ;;
        "random")
            random_script=$(find_special_script "Random Game" "RND")
            if [ -z "$random_script" ]; then
                ./show_message "Random Game script not found!|Make sure you have a Random Game|folder in your Roms directory." -l a
                continue
            fi
            ./show_message "Boot to Random Game?" -l ab -a "YES" -b "NO"
            if [ $? -eq 0 ]; then
                setup_boot_option "custom" "$random_script" "Random Game"
                ./show_message "Boot to Random Game set!" -l a
            fi
            ;;
        "custom")
            ./show_message "Select a custom collection..." -d 1
            > /tmp/browser_selection.txt
            find "/mnt/SDCARD/Roms" -name "launch.sh" | while read -r launch_file; do
                collection_dir=$(dirname "$launch_file")
                collection_name=$(basename "$collection_dir")
                if echo "$collection_name" | grep -qi "CUSTOM"; then
                    clean_name=$(clean_display_name "$collection_name")
                    echo "$clean_name|$launch_file" >> /tmp/browser_selection.txt
                fi
            done
            if [ ! -s /tmp/browser_selection.txt ]; then
                ./show_message "No custom collections found!" -l a
                continue
            fi
            custom_output=$(./picker "/tmp/browser_selection.txt")
            custom_status=$?
            if [ $custom_status -ne 0 ]; then
                continue
            fi
            custom_path=$(echo "$custom_output" | cut -d'|' -f2)
            custom_name=$(echo "$custom_output" | cut -d'|' -f1)
            ./show_message "Boot to $custom_name?" -l ab -a "YES" -b "NO"
            if [ $? -eq 0 ]; then
                setup_boot_option "custom" "$custom_path" "$custom_name"
                ./show_message "Boot to $custom_name set!" -l a
            fi
            ;;
        "game")
            build_valid_rom_folders
            if [ ! -s /tmp/rom_dirs.txt ]; then
                ./show_message "No ROM folders with games found!" -l a
                continue
            fi
            rom_dir_output=$(./picker "/tmp/rom_dirs.txt")
            rom_dir_status=$?
            if [ $rom_dir_status -ne 0 ]; then
                continue
            fi
            selected_folder=$(echo "$rom_dir_output" | cut -d'|' -f2)
            folder_name=$(echo "$rom_dir_output" | cut -d'|' -f1)
            platform=$(echo "$(basename "$selected_folder")" | sed -n 's/.*(\(.*\)).*/\1/p')
            find_games_in_folder "$selected_folder"
            if [ ! -s /tmp/actual_games.txt ]; then
                ./show_message "No valid games found in folder!" -l a
                continue
            fi
            game_output=$(./picker "/tmp/actual_games.txt")
            game_status=$?
            if [ $game_status -ne 0 ]; then
                continue
            fi
            selected_rom=$(echo "$game_output" | cut -d'|' -f2)
            game_name=$(echo "$game_output" | cut -d'|' -f1)
            EMULATOR_PATH=""
            if [ -d "/mnt/SDCARD/Emus/$PLATFORM/$platform.pak" ]; then
                EMULATOR_PATH="/mnt/SDCARD/Emus/$PLATFORM/$platform.pak/launch.sh"
            elif [ -d "/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$platform.pak" ]; then
                EMULATOR_PATH="/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$platform.pak/launch.sh"
            else
                ./show_message "Emulator not found for $platform" -l a
                continue
            fi
            ./show_message "Boot to $game_name?" -l ab -a "YES" -b "NO"
            if [ $? -eq 0 ]; then
                setup_boot_option "game" "$EMULATOR_PATH" "$game_name" "$selected_rom"
                ./show_message "Boot to $game_name set!" -l a
            fi
            ;;
        "tool")
            if [ ! -d "/mnt/SDCARD/Tools/$PLATFORM" ]; then
                ./show_message "Tools directory not found!" -l a
                continue
            fi
            > /tmp/browser_selection.txt
            for tool in "/mnt/SDCARD/Tools/$PLATFORM"/*; do
                if [ -d "$tool" ] && [ -f "$tool/launch.sh" ]; then
                    tool_name=$(basename "$tool" | sed 's/\.pak$//')
                    # Clean name for display - remove underscore separator, prefixes, and tags
                    display_name=$(echo "$tool_name" | sed 's/_/ /g' | sed -E 's/^[0-9]+[)\._ -]+//' | sed 's/ *([^)]*)$//')
                    # Capitalize first letter
                    display_name=$(echo ${display_name:0:1} | tr '[:lower:]' '[:upper:]')${display_name:1}
                    echo "$display_name|$tool/launch.sh" >> /tmp/browser_selection.txt
                fi
            done
            if [ ! -s /tmp/browser_selection.txt ]; then
                ./show_message "No tools found!" -l a
                continue
            fi
            tool_output=$(./picker "/tmp/browser_selection.txt")
            tool_status=$?
            if [ $tool_status -ne 0 ]; then
                continue
            fi
            tool_path=$(echo "$tool_output" | cut -d'|' -f2)
            tool_name=$(echo "$tool_output" | cut -d'|' -f1)
            ./show_message "Boot to $tool_name?" -l ab -a "YES" -b "NO"
            if [ $? -eq 0 ]; then
                setup_boot_option "custom" "$tool_path" "$tool_name"
                ./show_message "Boot to $tool_name set!" -l a
            fi
            ;;
    esac
    if [ "$boot_option" = "current" ]; then
        main_menu_idx=0
    else
        main_menu_idx=$(grep -n "^${picker_output%$'\n'}$" "boot_options.txt" | cut -d: -f1)
        main_menu_idx=$((main_menu_idx - 1))
    fi
done

cleanup
exit 0