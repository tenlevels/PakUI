#!/bin/sh
# Cancel current mission with mood changes
cd "$(dirname "$0")/.."
BITPAL_DIR="${BITPAL_DIR:-./bitpal_data}"
BITPAL_DATA="${BITPAL_DATA:-$BITPAL_DIR/bitpal_data.txt}"
ACTIVE_MISSION="${ACTIVE_MISSION:-$BITPAL_DIR/active_mission.txt}"
ACTIVE_MISSIONS_DIR="${ACTIVE_MISSIONS_DIR:-$BITPAL_DIR/active_missions}"
FACE_DIR="./bitpal_faces"

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

# Load BitPal data
[ -f "$BITPAL_DATA" ] && . "$BITPAL_DATA"

# Basic face function 
get_face() {
    case "$mood" in
        excited) echo "(^o^)" ;;
        happy)   echo "(^-^)" ;;
        neutral) echo "(-_-)" ;;
        sad)     echo "(;_;)" ;;
        angry)   echo "(>_<)" ;;
        surprised) echo "(O_O)" ;;
        *)       echo "(^-^)" ;;
    esac
}

# New function: update background with random selection
update_background() {
    local mood_to_use="$1"
    local bg_dir="$FACE_DIR"
    files=$(ls "$bg_dir"/background_"${mood_to_use}"_*.png 2>/dev/null)
    if [ -n "$files" ]; then
         set -- $files
         count=$#
         random_index=$((RANDOM % count + 1))
         eval chosen=\$$random_index
         cp "$chosen" "./background.png"
    else
         local bg_src="$bg_dir/background_${mood_to_use}.png"
         [ -f "$bg_src" ] && cp "$bg_src" "./background.png"
    fi
}

# Get current face
face=$(get_face)

# Check if a specific mission file is provided or if we need to check active_mission.txt
if [ -z "$ACTIVE_MISSION" ] || [ ! -f "$ACTIVE_MISSION" ]; then
    # If no specific mission, check if we have any active missions
    if [ -d "$ACTIVE_MISSIONS_DIR" ] && [ "$(find "$ACTIVE_MISSIONS_DIR" -type f -name "mission_*.txt" | wc -l)" -gt 0 ]; then
        # We have mission files in the directory, show a list to cancel
        > /tmp/cancel_mission_list.txt
        for mission_file in "$ACTIVE_MISSIONS_DIR"/mission_*.txt; do
            if [ -f "$mission_file" ]; then
                mission=$(cat "$mission_file")
                mission_desc=$(echo "$mission" | cut -d'|' -f1)
                mission_num=$(basename "$mission_file" | sed 's/mission_\(.*\)\.txt/\1/')
                echo "Mission $mission_num: $mission_desc|$mission_file" >> /tmp/cancel_mission_list.txt
            fi
        done
        
        ./show_message "$face|Select mission to cancel:" -l a
        mission_choice=$(./picker "/tmp/cancel_mission_list.txt" -a "SELECT" -b "BACK")
        picker_status=$?
        
        # Check if user selected a mission or went back
        if [ $picker_status -ne 0 ]; then
            rm -f /tmp/cancel_mission_list.txt
            exit 0
        fi
        
        ACTIVE_MISSION=$(echo "$mission_choice" | cut -d'|' -f2)
        rm -f /tmp/cancel_mission_list.txt
    else
        # No active missions found
        ./show_message "$face|No active mission.|There is no mission to cancel." -l a
        exit 0
    fi
fi

# Now process the mission to cancel
if [ -f "$ACTIVE_MISSION" ]; then
    mission=$(cat "$ACTIVE_MISSION")
    desc=$(echo "$mission" | cut -d'|' -f1)
    ./show_message "$face|Cancel Mission?|$desc|Are you sure you want|to cancel this mission?" -l -a "YES" -b "BACK"
    if [ $? -eq 0 ]; then
        # Restore GameSwitcher setting for the mission's game
        rom_path=$(echo "$mission" | cut -d'|' -f7)
        if [ -n "$rom_path" ] && [ -f "$rom_path" ]; then
            restore_game_switcher "$rom_path"
        fi
        
        # Update mood to sad or angry (70% sad, 30% angry)
        if [ $((RANDOM % 100)) -lt 70 ]; then
            mood="sad"
        else
            mood="angry"
        fi
        
        # Update mood in BitPal data
        sed -i "s/^mood=.*/mood=$mood/" "$BITPAL_DATA"
        
        # Try to show face image if available
        if [ -f "$FACE_DIR/$mood.png" ]; then
            show.elf "$FACE_DIR/$mood.png" &
            sleep 2
            killall show.elf 2>/dev/null
        fi
        
        # Update background with random selection for current mood
        update_background "$mood"
        
        # Get updated face
        face=$(get_face)
        
        # Remove the mission file and temporary files
        rm -f "$ACTIVE_MISSION" "/tmp/bitpal_plays_start.txt" "/tmp/bitpal_time_start.txt"
        
        # Show different responses based on mood
        case "$mood" in
            sad)
                ./show_message "$face|*sniff*|I was really hoping|we'd finish that one..." -l a
                ;;
            angry)
                ./show_message "$face|MISSION ABORTED!|All that progress... WASTED!|*digital grumbling*" -l a
                ;;
            *)
                ./show_message "$face|Mission canceled.|You can start a new|mission now." -l a
                ;;
        esac
    fi
else
    ./show_message "$face|No active mission.|There is no mission to cancel." -l a
fi

exit 0