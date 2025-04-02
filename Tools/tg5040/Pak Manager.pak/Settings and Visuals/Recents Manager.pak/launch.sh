#!/bin/sh
TEMP_MENU="/tmp/recents_menu.txt"
EMU_MENU="/tmp/recents_emu.txt"
trap 'rm -f "$TEMP_MENU" "$EMU_MENU"' EXIT
cd "$(dirname "$0")"
export LD_LIBRARY_PATH="/usr/trimui/lib:$LD_LIBRARY_PATH"
RECENTS_FILE="/mnt/SDCARD/.userdata/shared/.minui/recent.txt"
CLEAR_RECENT_LINE='echo "" > /mnt/SDCARD/.userdata/shared/.minui/recent.txt'
GS_CLEAR_LINE='echo "" > /mnt/SDCARD/.userdata/shared/.minui/recent.txt'
PLATFORM="$(basename "$(dirname "$(dirname "$0")")")"
PICKER="./picker"
SHOW_MESSAGE="./show_message"

clear_all_recents() {
    if [ ! -f "$RECENTS_FILE" ]; then
        "$SHOW_MESSAGE" "No recents file found." -l a
        return
    fi
    RECENTS_COUNT=$(wc -l < "$RECENTS_FILE")
    if [ "$RECENTS_COUNT" -eq 0 ]; then
        "$SHOW_MESSAGE" "Recents already clear." -l a
        return
    fi
    "$SHOW_MESSAGE" "Clear Recents List?|Remove all entries?" -l -a "YES" -b "NO"
    if [ $? -eq 0 ]; then
        > "$RECENTS_FILE"
        "$SHOW_MESSAGE" "Recents cleared.|List is now empty." -l a
    fi
}

remove_top_entry() {
    if [ ! -f "$RECENTS_FILE" ]; then
        "$SHOW_MESSAGE" "No recents file found." -l a
        return
    fi
    RECENTS_COUNT=$(wc -l < "$RECENTS_FILE")
    if [ "$RECENTS_COUNT" -eq 0 ]; then
        "$SHOW_MESSAGE" "Recents already clear." -l a
        return
    fi
    "$SHOW_MESSAGE" "Remove Top Entry?|Remove only the first entry?" -l -a "YES" -b "NO"
    if [ $? -eq 0 ]; then
        sed -i '1d' "$RECENTS_FILE"
        "$SHOW_MESSAGE" "Top entry removed." -l a
    fi
}

is_launcher_disabled() {
    local launcher="$1"
    if grep -q "# BEGIN Disable Recents" "$launcher"; then
        return 0
    fi
    return 1
}

disable_recents() {
    "$SHOW_MESSAGE" "Disable Recents?|No new games will be recorded." -l -a "YES" -b "NO"
    if [ $? -ne 0 ]; then
        return
    fi
    RECENTS_COUNT=$(wc -l < "$RECENTS_FILE" 2>/dev/null || echo "0")
    if [ "$RECENTS_COUNT" -gt 0 ]; then
        "$SHOW_MESSAGE" "Clear current recents?|($RECENTS_COUNT entries) will be removed." -l -a "YES" -b "NO"
        if [ $? -eq 0 ]; then
            > "$RECENTS_FILE"
        fi
    fi
    "$SHOW_MESSAGE" "Disabling recents...|Please wait" &
    message_pid=$!
    inject_clear_line() {
        local launcher="$1"
        
        # First, check if our markers already exist and remove entire blocks
        if grep -q "# BEGIN Disable Recents" "$launcher"; then
            sed -i '/# BEGIN Disable Recents/,/# END Disable Recents/d' "$launcher"
        fi
        
        # Also remove any individual recents commands that might exist
        sed -i '/touch \/mnt\/SDCARD\/.userdata\/shared\/.minui\/recent.txt && echo "" > \/mnt\/SDCARD\/.userdata\/shared\/.minui\/recent.txt/d' "$launcher"
        sed -i '/echo "" > \/mnt\/SDCARD\/.userdata\/shared\/.minui\/recent.txt/d' "$launcher"
        sed -i '/sed -i '\''1d'\'' \/mnt\/SDCARD\/.userdata\/shared\/.minui\/recent.txt/d' "$launcher"
        
        # Make sure the file ends with a newline
        [ -s "$launcher" ] && sed -i -e '$a\' "$launcher"
        
        # Insert at the beginning, respecting shebang lines
        if echo "$launcher" | grep -q "(GS)"; then
            sed -i '1i\# BEGIN Disable Recents\necho "" > /mnt/SDCARD/.userdata/shared/.minui/recent.txt\n# END Disable Recents' "$launcher"
        else
            if head -n 1 "$launcher" | grep -q "^#!/"; then
                sed -i '1a\# BEGIN Disable Recents\necho "" > /mnt/SDCARD/.userdata/shared/.minui/recent.txt\n# END Disable Recents' "$launcher"
            else
                sed -i '1i\# BEGIN Disable Recents\necho "" > /mnt/SDCARD/.userdata/shared/.minui/recent.txt\n# END Disable Recents' "$launcher"
            fi
        fi
        
        # Add to the end of the file with proper spacing
        echo "# BEGIN Disable Recents" >> "$launcher"
        echo 'echo "" > /mnt/SDCARD/.userdata/shared/.minui/recent.txt' >> "$launcher"
        echo "# END Disable Recents" >> "$launcher"
    }
    for dir in "/mnt/SDCARD/.system/$PLATFORM/paks/Emus" "/mnt/SDCARD/Emus" "/mnt/SDCARD/Roms"; do
        if [ -d "$dir" ]; then
            find "$dir" -type f -name "launch.sh" | while read -r launcher; do
                inject_clear_line "$launcher"
            done
        fi
    done
    kill $message_pid 2>/dev/null
    "$SHOW_MESSAGE" "Recents disabled.|New games won't be recorded." -l a
}

enable_recents() {
    "$SHOW_MESSAGE" "Enable Recents?|Games will be recorded." -l -a "YES" -b "NO"
    if [ $? -ne 0 ]; then
        return
    fi
    "$SHOW_MESSAGE" "Enabling recents...|Please wait" &
    message_pid=$!
    remove_clear_line() {
        local launcher="$1"
        # Remove entire blocks between markers
        if grep -q "# BEGIN Disable Recents" "$launcher"; then
            sed -i '/# BEGIN Disable Recents/,/# END Disable Recents/d' "$launcher"
        fi
        # Also remove any individual commands that might exist
        sed -i '/touch \/mnt\/SDCARD\/.userdata\/shared\/.minui\/recent.txt && echo "" > \/mnt\/SDCARD\/.userdata\/shared\/.minui\/recent.txt/d' "$launcher"
        sed -i '/echo "" > \/mnt\/SDCARD\/.userdata\/shared\/.minui\/recent.txt/d' "$launcher"
        sed -i '/sed -i '\''1d'\'' \/mnt\/SDCARD\/.userdata\/shared\/.minui\/recent.txt/d' "$launcher"
    }
    for dir in "/mnt/SDCARD/.system/$PLATFORM/paks/Emus" "/mnt/SDCARD/Emus" "/mnt/SDCARD/Roms"; do
        if [ -d "$dir" ]; then
            find "$dir" -type f -name "launch.sh" | while read -r launcher; do
                remove_clear_line "$launcher"
            done
        fi
    done
    kill $message_pid 2>/dev/null
    "$SHOW_MESSAGE" "Recents enabled.|Games will now be recorded." -l a
}

get_display_name() {
    local folder_name="$1"
    if echo "$folder_name" | grep -qE "^[0-9]+[)\._ -]+"; then
        folder_name=$(echo "$folder_name" | sed -E 's/^[0-9]+[)\._ -]+//')
    fi
    folder_name=$(echo "$folder_name" | sed -E 's/ *\([^)]*\)$//')
    echo "$folder_name"
}

find_emulator_launchers() {
    local emu="$1"
    local found_launchers=""
    if [ -d "/mnt/SDCARD/Roms/$emu (GS)" ] && [ -f "/mnt/SDCARD/Roms/$emu (GS)/launch.sh" ]; then
        found_launchers="/mnt/SDCARD/Roms/$emu (GS)/launch.sh"
        echo "$found_launchers"
        return
    fi
    for folder in "/mnt/SDCARD/Roms"/*; do
        if [ -d "$folder" ]; then
            folder_name=$(basename "$folder")
            if echo "$folder_name" | grep -q "([^)]*)" && [ -f "$folder/launch.sh" ]; then
                folder_tag=$(echo "$folder_name" | grep -o "([^)]*)" | tr -d "(" | tr -d ")")
                if [ "$folder_tag" = "$emu" ]; then
                    found_launchers="$folder/launch.sh"
                    echo "$found_launchers"
                    return
                fi
            fi
        fi
    done
    for pak_dir in "/mnt/SDCARD/Emus/$PLATFORM" "/mnt/SDCARD/.system/$PLATFORM/paks/Emus"; do
        if [ -d "$pak_dir" ]; then
            if [ -d "$pak_dir/$emu.pak" ] && [ -f "$pak_dir/$emu.pak/launch.sh" ]; then
                found_launchers="$pak_dir/$emu.pak/launch.sh"
                echo "$found_launchers"
                return
            fi
            if [ -d "$pak_dir/$emu (GS).pak" ] && [ -f "$pak_dir/$emu (GS).pak/launch.sh" ]; then
                found_launchers="$pak_dir/$emu (GS).pak/launch.sh"
                echo "$found_launchers"
                return
            fi
        fi
    done
    for dir in "/mnt/SDCARD/Emus" "/mnt/SDCARD/.system/$PLATFORM/paks/Emus"; do
        if [ -d "$dir" ]; then
            find "$dir" -type f -name "launch.sh" | while read -r launcher; do
                if echo "$launcher" | grep -q "$emu"; then
                    found_launchers="$launcher"
                    echo "$found_launchers"
                    return
                fi
            done
        fi
    done
    echo "$found_launchers"
}

per_emulator_control() {
    "$SHOW_MESSAGE" "Loading emulators...|Please wait" &
    loading_pid=$!
    > "$EMU_MENU"
    echo "Per-Emulator Control|__HEADER__|header" > "$EMU_MENU"
    for folder in "/mnt/SDCARD/Roms"/*; do
        if [ -d "$folder" ]; then
            name=$(basename "$folder")
            if echo "$name" | grep -q "("; then
                emu_tag=$(echo "$name" | grep -o "([^)]*)" | tr -d "(" | tr -d ")")
                if [ "$(find "$folder" -type f ! -path "*.res*" | grep -Evi '\.(jpg|jpeg|png|bmp|gif|tiff|webp)$' | head -n 1)" ]; then
                    display_name=$(get_display_name "$name")
                    disabled=0
                    launcher=$(find_emulator_launchers "$emu_tag")
                    if [ -n "$launcher" ] && is_launcher_disabled "$launcher"; then
                        disabled=1
                    fi
                    if [ $disabled -eq 1 ]; then
                        echo "$display_name [Disabled]|$emu_tag|enable_emu" >> "$EMU_MENU"
                    else
                        echo "$display_name [Enabled]|$emu_tag|disable_emu" >> "$EMU_MENU"
                    fi
                fi
            fi
        fi
    done
    kill $loading_pid 2>/dev/null
    if [ ! -s "$EMU_MENU" ] || [ "$(wc -l < "$EMU_MENU")" -le 1 ]; then
        "$SHOW_MESSAGE" "No emulators found!" -l a
        return
    fi
    selection=$("$PICKER" "$EMU_MENU" -b "BACK")
    status=$?
    [ $status -eq 1 ] || [ -z "$selection" ] && return
    emu=$(echo "$selection" | cut -d'|' -f2)
    action=$(echo "$selection" | cut -d'|' -f3)
    if [ "$action" = "enable_emu" ]; then
        "$SHOW_MESSAGE" "Enable recents for $emu?|This emulator will record games." -l -a "YES" -b "NO"
        if [ $? -eq 0 ]; then
            "$SHOW_MESSAGE" "Enabling recents for $emu...|Please wait" &
            message_pid=$!
            for path in "/mnt/SDCARD/Emus/$PLATFORM/$emu.pak/launch.sh" "/mnt/SDCARD/Emus/$PLATFORM/$emu (GS).pak/launch.sh" "/mnt/SDCARD/Roms/$emu/launch.sh" "/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$emu.pak/launch.sh" "/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$emu (GS).pak/launch.sh"; do
                if [ -f "$path" ]; then
                    if grep -q "# BEGIN Disable Recents" "$path"; then
                        sed -i '/# BEGIN Disable Recents/,/# END Disable Recents/d' "$path"
                    fi
                    sed -i '/touch \/mnt\/SDCARD\/.userdata\/shared\/.minui\/recent.txt && echo "" > \/mnt\/SDCARD\/.userdata\/shared\/.minui\/recent.txt/d' "$path"
                    sed -i '/echo "" > \/mnt\/SDCARD\/.userdata\/shared\/.minui\/recent.txt/d' "$path"
                    sed -i '/sed -i '\''1d'\'' \/mnt\/SDCARD\/.userdata\/shared\/.minui\/recent.txt/d' "$path"
                fi
            done
            kill $message_pid 2>/dev/null
            "$SHOW_MESSAGE" "Recents enabled for $emu.|Games will now be recorded." -l a
        fi
    elif [ "$action" = "disable_emu" ]; then
        "$SHOW_MESSAGE" "Disable recents for $emu?|This emulator won't record games." -l -a "YES" -b "NO"
        if [ $? -eq 0 ]; then
            "$SHOW_MESSAGE" "Disabling recents for $emu...|Please wait" &
            message_pid=$!
            for path in "/mnt/SDCARD/Emus/$PLATFORM/$emu.pak/launch.sh" "/mnt/SDCARD/Emus/$PLATFORM/$emu (GS).pak/launch.sh" "/mnt/SDCARD/Roms/$emu/launch.sh" "/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$emu.pak/launch.sh" "/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$emu (GS).pak/launch.sh"; do
                if [ -f "$path" ]; then
                    # First, check if our markers already exist and remove entire blocks
                    if grep -q "# BEGIN Disable Recents" "$path"; then
                        sed -i '/# BEGIN Disable Recents/,/# END Disable Recents/d' "$path"
                    fi
                    
                    # Also remove any individual recents commands that might exist
                    sed -i '/touch \/mnt\/SDCARD\/.userdata\/shared\/.minui\/recent.txt && echo "" > \/mnt\/SDCARD\/.userdata\/shared\/.minui\/recent.txt/d' "$path"
                    sed -i '/echo "" > \/mnt\/SDCARD\/.userdata\/shared\/.minui\/recent.txt/d' "$path"
                    sed -i '/sed -i '\''1d'\'' \/mnt\/SDCARD\/.userdata\/shared\/.minui\/recent.txt/d' "$path"
                    
                    # Make sure the file ends with a newline
                    [ -s "$path" ] && sed -i -e '$a\' "$path"
                    
                    # Insert at the beginning, respecting shebang lines
                    if echo "$path" | grep -q "(GS)"; then
                        sed -i '1i\# BEGIN Disable Recents\necho "" > /mnt/SDCARD/.userdata/shared/.minui/recent.txt\n# END Disable Recents' "$path"
                    else
                        if head -n 1 "$path" | grep -q "^#!/"; then
                            sed -i '1a\# BEGIN Disable Recents\necho "" > /mnt/SDCARD/.userdata/shared/.minui/recent.txt\n# END Disable Recents' "$path"
                        else
                            sed -i '1i\# BEGIN Disable Recents\necho "" > /mnt/SDCARD/.userdata/shared/.minui/recent.txt\n# END Disable Recents' "$path"
                        fi
                    fi
                    
                    # Add to the end of the file with proper spacing
                    echo "# BEGIN Disable Recents" >> "$path"
                    echo 'echo "" > /mnt/SDCARD/.userdata/shared/.minui/recent.txt' >> "$path"
                    echo "# END Disable Recents" >> "$path"
                fi
            done
            kill $message_pid 2>/dev/null
            "$SHOW_MESSAGE" "Recents disabled for $emu.|It will no longer record games." -l a
        fi
    elif [ "$action" = "header" ]; then
        "$SHOW_MESSAGE" "Recents Manager|Clear All, Remove Top, Enable/Disable, Per-Emulator" -l -a "OK"
    fi
}

echo "Recently Played Manager|Main Menu" > "$TEMP_MENU"
RECENTS_COUNT=$(wc -l < "$RECENTS_FILE" 2>/dev/null || echo "0")
echo "Clear All Recents ($RECENTS_COUNT)|clear_all|action" >> "$TEMP_MENU"
echo "Remove Most Recent Entry|remove_top|action" >> "$TEMP_MENU"
echo "Enable Recents|enable|action" >> "$TEMP_MENU"
echo "Disable Recents|disable|action" >> "$TEMP_MENU"
echo "Per-Emulator Settings|per_emulator|action" >> "$TEMP_MENU"

menu_idx=0
while true; do
    selection=$("$PICKER" "$TEMP_MENU" -i $menu_idx -b "EXIT")
    status=$?
    if [ -n "$selection" ]; then
        menu_idx=$(grep -n "^$selection$" "$TEMP_MENU" | cut -d: -f1 || echo "0")
        menu_idx=$((menu_idx - 1))
        [ $menu_idx -lt 0 ] && menu_idx=0
    fi
    [ $status -eq 1 ] || [ -z "$selection" ] && exit 0
    action=$(echo "$selection" | cut -d'|' -f2)
    case "$action" in
        header)
            "$SHOW_MESSAGE" "Recents Manager|Clear All, Remove Top, Enable/Disable, Per-Emulator" -l -a "OK"
            ;;
        clear_all)
            clear_all_recents
            echo "Recently Played Manager|Main Menu" > "$TEMP_MENU"
            RECENTS_COUNT=$(wc -l < "$RECENTS_FILE" 2>/dev/null || echo "0")
            echo "Clear All Recents ($RECENTS_COUNT)|clear_all|action" >> "$TEMP_MENU"
            echo "Remove Most Recent Entry|remove_top|action" >> "$TEMP_MENU"
            echo "Enable Recents|enable|action" >> "$TEMP_MENU"
            echo "Disable Recents|disable|action" >> "$TEMP_MENU"
            echo "Per-Emulator Settings|per_emulator|action" >> "$TEMP_MENU"
            ;;
        remove_top)
            remove_top_entry
            echo "Recently Played Manager|Main Menu" > "$TEMP_MENU"
            RECENTS_COUNT=$(wc -l < "$RECENTS_FILE" 2>/dev/null || echo "0")
            echo "Clear All Recents ($RECENTS_COUNT)|clear_all|action" >> "$TEMP_MENU"
            echo "Remove Most Recent Entry|remove_top|action" >> "$TEMP_MENU"
            echo "Enable Recents|enable|action" >> "$TEMP_MENU"
            echo "Disable Recents|disable|action" >> "$TEMP_MENU"
            echo "Per-Emulator Settings|per_emulator|action" >> "$TEMP_MENU"
            ;;
        disable)
            disable_recents
            echo "Recently Played Manager|Main Menu" > "$TEMP_MENU"
            RECENTS_COUNT=$(wc -l < "$RECENTS_FILE" 2>/dev/null || echo "0")
            echo "Clear All Recents ($RECENTS_COUNT)|clear_all|action" >> "$TEMP_MENU"
            echo "Remove Most Recent Entry|remove_top|action" >> "$TEMP_MENU"
            echo "Enable Recents|enable|action" >> "$TEMP_MENU"
            echo "Disable Recents|disable|action" >> "$TEMP_MENU"
            echo "Per-Emulator Settings|per_emulator|action" >> "$TEMP_MENU"
            ;;
        enable)
            enable_recents
            echo "Recently Played Manager|Main Menu" > "$TEMP_MENU"
            RECENTS_COUNT=$(wc -l < "$RECENTS_FILE" 2>/dev/null || echo "0")
            echo "Clear All Recents ($RECENTS_COUNT)|clear_all|action" >> "$TEMP_MENU"
            echo "Remove Most Recent Entry|remove_top|action" >> "$TEMP_MENU"
            echo "Enable Recents|enable|action" >> "$TEMP_MENU"
            echo "Disable Recents|disable|action" >> "$TEMP_MENU"
            echo "Per-Emulator Settings|per_emulator|action" >> "$TEMP_MENU"
            ;;
        per_emulator)
            per_emulator_control
            echo "Recently Played Manager|Main Menu" > "$TEMP_MENU"
            RECENTS_COUNT=$(wc -l < "$RECENTS_FILE" 2>/dev/null || echo "0")
            echo "Clear All Recents ($RECENTS_COUNT)|clear_all|action" >> "$TEMP_MENU"
            echo "Remove Most Recent Entry|remove_top|action" >> "$TEMP_MENU"
            echo "Enable Recents|enable|action" >> "$TEMP_MENU"
            echo "Disable Recents|disable|action" >> "$TEMP_MENU"
            echo "Per-Emulator Settings|per_emulator|action" >> "$TEMP_MENU"
            ;;
    esac
done