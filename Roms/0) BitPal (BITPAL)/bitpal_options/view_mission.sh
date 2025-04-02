#!/bin/sh
# View Mission with mood integration

MENU="${MENU:-bitpal_menu.txt}"
BITPAL_DIR="${BITPAL_DIR:-./bitpal_data}"
BITPAL_DATA="${BITPAL_DATA:-$BITPAL_DIR/bitpal_data.txt}"
ACTIVE_MISSIONS_DIR="${ACTIVE_MISSIONS_DIR:-$BITPAL_DIR/active_missions}"
COMPLETED_FILE="${COMPLETED_FILE:-$BITPAL_DIR/completed.txt}"
FACE_DIR="../bitpal_faces"

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

[ -z "$name" ] && name="BitPal"
[ -z "$level" ] && level=1
[ -z "$xp" ] && xp=0
[ -z "$xp_next" ] && xp_next=100
[ -z "$mood" ] && mood="happy"
[ -z "$last_visit" ] && last_visit=$(date +%s)
[ -z "$missions_completed" ] && missions_completed=0

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

format_time() {
    local seconds="$1"
    [ -z "$seconds" ] && seconds=0
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    if [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m ${secs}s"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}m ${secs}s"
    else
        echo "${secs}s"
    fi
}

prepare_resume() {
    CURRENT_PATH=$(dirname "$1")
    ROM_FOLDER_NAME=$(basename "$CURRENT_PATH")
    ROM_PLATFORM=""
    while [ -z "$ROM_PLATFORM" ]; do
        [ "$ROM_FOLDER_NAME" = "Roms" ] && { ROM_PLATFORM="UNK"; break; }
        ROM_PLATFORM=$(echo "$ROM_FOLDER_NAME" | sed -n 's/.*(\(.*\)).*/\1/p')
        [ -z "$ROM_PLATFORM" ] && { CURRENT_PATH=$(dirname "$CURRENT_PATH"); ROM_FOLDER_NAME=$(basename "$CURRENT_PATH"); }
    done
    BASE_PATH="/mnt/SDCARD/.userdata/shared/.minui/$ROM_PLATFORM"
    ROM_NAME=$(basename "$1")
    SLOT_FILE="$BASE_PATH/$ROM_NAME.txt"
    [ -f "$SLOT_FILE" ] && cat "$SLOT_FILE" > /tmp/resume_slot.txt
}

# Update background using a random selection
update_background() {
    local mood_to_use="$1"
    local bg_dir="$FACE_DIR"
    files=$(ls "$bg_dir"/background_"${mood_to_use}"_*.png 2>/dev/null)
    if [ -n "$files" ]; then
         set -- $files
         count=$#
         random_index=$((RANDOM % count + 1))
         eval chosen=\$$random_index
         cp "$chosen" "../background.png"
    else
         local bg_src="$bg_dir/background_${mood_to_use}.png"
         [ -f "$bg_src" ] && cp "$bg_src" "../background.png"
    fi
}

#######################################################################FINALIZE MISSION
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

    # Update BitPal data file with new mood and stats
    cat > "$BITPAL_DATA" <<EOF
name=$name
level=$level
xp=$xp
xp_next=$xp_next
mood=$mood
last_visit=$(date +%s)
missions_completed=$missions_completed
EOF

    if [ -f "$FACE_DIR/$mood.png" ]; then
        show.elf "$FACE_DIR/$mood.png" &
        sleep 2
        killall show.elf 2>/dev/null
    fi

    rm -f "$mission_file"
    ./show_message "Mission Complete!|$desc complete.|Earned: $xp_reward XP|Current XP: $xp|Level: $level" -l a
}

# Get current face for display
face=$(get_face)

# If no specific mission is passed, choose the first active mission
if [ -z "$ACTIVE_MISSION" ]; then
    mission_found=0
    for mission_file in "$ACTIVE_MISSIONS_DIR"/mission_*.txt; do
        [ -f "$mission_file" ] && { mission_found=1; ACTIVE_MISSION="$mission_file"; break; }
    done
    [ "$mission_found" -eq 0 ] && { ./show_message "$face|No active mission.|Start a new mission first." -l a; exit 0; }
fi

mission=$(cat "$ACTIVE_MISSION")
desc=$(echo "$mission" | cut -d'|' -f1)
target=$(echo "$mission" | cut -d'|' -f2)
type=$(echo "$mission" | cut -d'|' -f3)
mins=$(echo "$mission" | cut -d'|' -f4)
xp_reward=$(echo "$mission" | cut -d'|' -f5)
start_time=$(echo "$mission" | cut -d'|' -f6)
rom_path=$(echo "$mission" | cut -d'|' -f7)
accumulated_time=$(echo "$mission" | cut -d'|' -f8)
[ -z "$accumulated_time" ] && accumulated_time=0

# Check if mission is already complete.
target_seconds=$((mins * 60))
if [ "$accumulated_time" -ge "$target_seconds" ]; then
    finalize_mission "$ACTIVE_MISSION"
else
    percent=$(( accumulated_time * 100 / target_seconds ))
    [ "$percent" -gt 100 ] && percent=100
    played_time=$(format_time "$accumulated_time")
    required_time=$(format_time "$target_seconds")
    progress_text="$played_time of $required_time ($percent%)"

    ./show_message "$face|Mission Progress|$desc|Progress: $progress_text|Reward: $xp_reward XP" -l a

    echo "Resume Mission|launch|action" > /tmp/mission_view.txt
    echo "Cancel Mission|cancel|action" >> /tmp/mission_view.txt
    choice=$(./picker "/tmp/mission_view.txt" -a "SELECT" -b "BACK")
    status=$?
    if [ $status -eq 0 ]; then
        action=$(echo "$choice" | cut -d'|' -f2)
        case "$action" in
            launch)
                if [ -f "$rom_path" ]; then
                    CURRENT_PATH=$(dirname "$rom_path")
                    ROM_FOLDER_NAME=$(basename "$CURRENT_PATH")
                    ROM_PLATFORM=""
                    while [ -z "$ROM_PLATFORM" ]; do
                        [ "$ROM_FOLDER_NAME" = "Roms" ] && { ROM_PLATFORM="UNK"; break; }
                        ROM_PLATFORM=$(echo "$ROM_FOLDER_NAME" | sed -n 's/.*(\(.*\)).*/\1/p')
                        [ -z "$ROM_PLATFORM" ] && { CURRENT_PATH=$(dirname "$CURRENT_PATH"); ROM_FOLDER_NAME=$(basename "$CURRENT_PATH"); }
                    done
                    prepare_resume "$rom_path"
                    # --- External Time Tracking for Resuming Mission ---
                    # Export BitPal-specific session file paths so that the universal emulator launcher
                    # writes session data into /mnt/SDCARD/Tools/$PLATFORM/BitPal.pak.
                    export SESSION_FILE="/mnt/SDCARD/Tools/$PLATFORM/BitPal.pak/current_session.txt"
                    export LAST_SESSION_FILE="/mnt/SDCARD/Tools/$PLATFORM/BitPal.pak/last_session_duration.txt"
                    
                    if [ -d "/mnt/SDCARD/Emus/$PLATFORM/$ROM_PLATFORM.pak" ]; then
                        EMULATOR="/mnt/SDCARD/Emus/$PLATFORM/$ROM_PLATFORM.pak/launch.sh"
                        "$EMULATOR" "$rom_path"
                    elif [ -d "/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$ROM_PLATFORM.pak" ]; then
                        EMULATOR="/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$ROM_PLATFORM.pak/launch.sh"
                        "$EMULATOR" "$rom_path"
                    else
                        ./show_message "Emulator not found for $ROM_PLATFORM" -l a
                    fi
                    
                    # Read the final session duration from BitPal's LAST_SESSION_FILE.
                    SESSION_DURATION=$(cat "$LAST_SESSION_FILE")
                    rm -f "$LAST_SESSION_FILE"
                    
                    # Re-load the mission (in case it's been updated elsewhere)
                    mission=$(cat "$ACTIVE_MISSION")
                    
                    # Update mission's accumulated playtime using the externally tracked session duration.
                    field_count=$(echo "$mission" | awk -F'|' '{print NF}')
                    if [ "$field_count" -lt 8 ]; then
                        current_accum=0
                    else
                        current_accum=$(echo "$mission" | cut -d'|' -f8)
                    fi
                    new_total=$((current_accum + SESSION_DURATION))
                    if [ "$field_count" -lt 8 ]; then
                        mission=$(echo "$mission" | sed "s/\$/|${new_total}/")
                    else
                        mission=$(echo "$mission" | awk -F'|' -v newval="$new_total" 'BEGIN{OFS="|"} {$8=newval; print}')
                    fi
                    echo "$mission" > "$ACTIVE_MISSION"
                    if [ "$new_total" -ge "$target_seconds" ]; then
                        finalize_mission "$ACTIVE_MISSION"
                    fi
                else
                    ./show_message "Game file not found|$rom_path" -l a
                fi
                ;;
            cancel)
                ./show_message "$face|Cancel Mission?|$desc|Are you sure you want|to cancel this mission?" -l -a "YES" -b "NO"
                if [ $? -eq 0 ]; then
                    # Restore GameSwitcher setting for the mission's game before cancelling
                    if [ -n "$rom_path" ] && [ -f "$rom_path" ]; then
                        restore_game_switcher "$rom_path"
                    fi
                    
                    if [ $((RANDOM % 100)) -lt 70 ]; then
                        mood="sad"
                    else
                        mood="angry"
                    fi
                    
                    sed -i "s/^mood=.*/mood=$mood/" "$BITPAL_DATA"
                    
                    if [ -f "$FACE_DIR/$mood.png" ]; then
                        show.elf "$FACE_DIR/$mood.png" &
                        sleep 2
                        killall show.elf 2>/dev/null
                    fi
                    
                    update_background "$mood"
                    face=$(get_face)
                    
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
                    
                    rm -f "$ACTIVE_MISSION"
                fi
                ;;
        esac
    fi

    rm -f /tmp/mission_view.txt
fi
exit 0