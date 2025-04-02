#!/bin/sh
# Mission Manager
MENU="${MENU:-bitpal_menu.txt}"
BITPAL_DIR="${BITPAL_DIR:-./bitpal_data}"
BITPAL_DATA="${BITPAL_DATA:-$BITPAL_DIR/bitpal_data.txt}"
ACTIVE_MISSIONS_DIR="${ACTIVE_MISSIONS_DIR:-$BITPAL_DIR/active_missions}"
COMPLETED_FILE="${COMPLETED_FILE:-$BITPAL_DIR/completed.txt}"
FACE_DIR="${FACE_DIR:-./bitpal_faces}"

# Function to restore original GameSwitcher settings
restore_game_switcher() {
    local rom_path="$1"
    
    # Get ROM platform
    CURRENT_PATH=$(dirname "$rom_path")
    ROM_FOLDER_NAME=$(basename "$CURRENT_PATH")
    ROM_PLATFORM=""
    while [ -z "$ROM_PLATFORM" ]; do
         [ "$ROM_FOLDER_NAME" = "Roms" ] && { ROM_PLATFORM="UNK"; break; }
         ROM_PLATFORM=$(echo "$ROM_FOLDER_NAME" | sed -n 's/.*(\(.*\)).*/\1/p')
         [ -z "$ROM_PLATFORM" ] && { CURRENT_PATH=$(dirname "$CURRENT_PATH"); ROM_FOLDER_NAME=$(basename "$CURRENT_PATH"); }
    done
    
    # Get config file path
    local rom_name
    rom_name=$(basename "$rom_path")
    local rom_name_clean="${rom_name%.*}"
    local game_config_dir="/mnt/SDCARD/Emus/$PLATFORM/$ROM_PLATFORM.pak/game_settings"
    local game_config="$game_config_dir/$rom_name_clean.conf"
    
    # Check if the file exists and was modified by BitPal
    if [ -f "$game_config" ] && grep -q "#BitPal original=" "$game_config"; then
        # Extract the original setting
        local original_setting
        original_setting=$(grep "#BitPal original=" "$game_config" | sed -E 's/.*#BitPal original=([^ ]*).*/\1/')
        
        if [ "$original_setting" = "NONE" ]; then
            # No previous gameswitcher setting existed, remove the line
            grep -v "^gameswitcher=" "$game_config" > "$game_config.tmp"
            mv "$game_config.tmp" "$game_config"
            
            # If file is empty now, remove it
            if [ ! -s "$game_config" ]; then
                rm -f "$game_config"
            fi
        elif [ "$original_setting" = "NONE_FILE" ]; then
            # File was created by BitPal, remove it entirely
            rm -f "$game_config"
        else
            # Restore the original setting
            sed -i "s|^gameswitcher=OFF #BitPal original=$original_setting|gameswitcher=$original_setting|" "$game_config"
        fi
    fi
}

#######################################################################
# FINALIZE MISSION
finalize_mission() {
    mission_file="$1"
    mission=$(cat "$mission_file")
    desc=$(echo "$mission" | cut -d'|' -f1)
    start_time=$(echo "$mission" | cut -d'|' -f6)
    xp_reward=$(echo "$mission" | cut -d'|' -f5)
    complete_time=$(date +%s)
    
    # Restore GameSwitcher setting for the mission's game
    rom_path=$(echo "$mission" | cut -d'|' -f7)
    if [ -n "$rom_path" ] && [ -f "$rom_path" ]; then
        restore_game_switcher "$rom_path"
    fi
    
    # Save original level for level up detection
    original_level="$level"
    
    # Append to completed missions (format: description|start_time|complete_time|xp_reward)
    echo "$desc|$start_time|$complete_time|$xp_reward" >> "$COMPLETED_FILE"
    
    # Update BitPal data: award XP and increment missions_completed
    . "$BITPAL_DATA"
    xp=$((xp + xp_reward))
    missions_completed=$((missions_completed + 1))
    
    # ---- LEVEL UP LOGIC ----
    while [ "$xp" -ge "$xp_next" ]; do
        xp=$((xp - xp_next))
        level=$((level + 1))
        # New formula: 50 * level + 50
        xp_next=$(( level * 50 + 50 ))
    done
    # --------------------------
    
    # Make BitPal happier after completing a mission
    if [ "$mood" = "sad" ]; then
        mood="neutral"
    elif [ "$mood" = "neutral" ]; then
        mood="happy"
    elif [ "$mood" = "angry" ]; then
        mood="neutral"
    # Add this line:
    elif [ "$mood" = "surprised" ]; then
        mood="happy"
    elif [ "$mood" = "happy" ] && [ $((RANDOM % 100)) -lt 40 ]; then
        mood="excited"
    fi
    
    # Update BitPal data file with the new mood and other stats
    cat > "$BITPAL_DATA" <<EOF
name=$name
level=$level
xp=$xp
xp_next=$xp_next
mood=$mood
last_visit=$(date +%s)
missions_completed=$missions_completed
EOF
    # Try to show face image if available
    if [ -f "$FACE_DIR/$mood.png" ]; then
        show.elf "$FACE_DIR/$mood.png" &
        sleep 2
        killall show.elf 2>/dev/null
    fi
    rm -f "$mission_file"
    ./show_message "Mission Complete!|$desc complete.|Earned: $xp_reward XP|Current XP: $xp|Level: $level" -l a
}

> /tmp/mission_manager.txt
mission_found=0
for mission_file in "$ACTIVE_MISSIONS_DIR"/mission_*.txt; do
    if [ -f "$mission_file" ]; then
        mission=$(cat "$mission_file")
        # Check if mission is already complete
        mins=$(echo "$mission" | cut -d'|' -f4)
        accumulated_time=$(echo "$mission" | cut -d'|' -f8)
        [ -z "$accumulated_time" ] && accumulated_time=0
        target_seconds=$((mins * 60))
        if [ "$accumulated_time" -ge "$target_seconds" ]; then
            finalize_mission "$mission_file"
            continue
        fi
        mission_found=1
        mission_desc=$(echo "$mission" | cut -d'|' -f1)
        mission_num=$(basename "$mission_file" | sed 's/mission_\(.*\)\.txt/\1/')
        echo "Mission $mission_num: $mission_desc|$mission_file|view_mission" >> /tmp/mission_manager.txt
    fi
done
[ "$mission_found" -eq 0 ] && { ./show_message "No active missions found.|Start a new mission first." -l a; exit 0; }
./show_message "Manage Missions|Select a mission to view progress|or cancel." -l a
mission_choice=$(./picker "/tmp/mission_manager.txt" -a "SELECT" -b "BACK")
mission_status=$?
if [ $mission_status -eq 0 ]; then
    selected_mission=$(echo "$mission_choice" | cut -d'|' -f2)
    if [ -f "$selected_mission" ]; then
        export ACTIVE_MISSION="$selected_mission"
        ./bitpal_options/view_mission.sh
    else
        ./show_message "Mission not found.|It may have been completed or canceled." -l a
    fi
fi
rm -f /tmp/mission_manager.txt
exit 0