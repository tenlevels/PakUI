#!/bin/sh

# Define variables
: ${PLATFORM:?PLATFORM variable not set}
# Use environment overrides if provided; otherwise default to GTT paths.
: ${SESSION_FILE:="/mnt/SDCARD/Tools/$PLATFORM/Game Time Tracker.pak/current_session.txt"}
: ${LAST_SESSION_FILE:="/mnt/SDCARD/Tools/$PLATFORM/Game Time Tracker.pak/last_session_duration.txt"}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GTT_LIST="/mnt/SDCARD/Tools/$PLATFORM/Game Time Tracker.pak/gtt_list.txt"
AUTO_RESUME_SCRIPT="$SCRIPT_DIR/auto_resume.sh"
ROM="$1"

# --- NEW: Check for BitPal active missions ---
BITPAL_DIR="/mnt/SDCARD/Tools/$PLATFORM/BitPal.pak/bitpal_data"
BITPAL_ACTIVE_MISSIONS_DIR="$BITPAL_DIR/active_missions"
BITPAL_ACTIVE_MISSION="$BITPAL_DIR/active_mission.txt"
BITPAL_MISSION_ROM=""
BITPAL_MISSION_FILE=""

# Check if this ROM is part of an active BitPal mission
check_bitpal_missions() {
    local rom_path="$1"
    BITPAL_MISSION_ROM=""
    BITPAL_MISSION_FILE=""
    
    # Check the active missions directory
    if [ -d "$BITPAL_ACTIVE_MISSIONS_DIR" ]; then
        for mission_file in "$BITPAL_ACTIVE_MISSIONS_DIR"/mission_*.txt; do
            if [ -f "$mission_file" ]; then
                mission=$(cat "$mission_file")
                mission_rom=$(echo "$mission" | cut -d'|' -f7)
                if [ "$rom_path" = "$mission_rom" ]; then
                    BITPAL_MISSION_ROM="$mission_rom"
                    BITPAL_MISSION_FILE="$mission_file"
                    return 0
                fi
            fi
        done
    fi
    
    # Also check legacy active mission
    if [ -f "$BITPAL_ACTIVE_MISSION" ]; then
        mission=$(cat "$BITPAL_ACTIVE_MISSION")
        mission_rom=$(echo "$mission" | cut -d'|' -f7)
        if [ "$rom_path" = "$mission_rom" ]; then
            BITPAL_MISSION_ROM="$mission_rom"
            BITPAL_MISSION_FILE="$BITPAL_ACTIVE_MISSION"
            return 0
        fi
    fi
    
    return 1
}

# Call the function to check BitPal missions
check_bitpal_missions "$ROM"
if [ -n "$BITPAL_MISSION_ROM" ]; then
    # Setup BitPal session tracking
    BITPAL_SESSION_FILE="/mnt/SDCARD/Tools/$PLATFORM/BitPal.pak/current_session.txt"
    BITPAL_LAST_SESSION_FILE="/mnt/SDCARD/Tools/$PLATFORM/BitPal.pak/last_session_duration.txt"
    # We'll track for both GTT and BitPal
    TRACK_BITPAL=1
else
    TRACK_BITPAL=0
fi

# --- ORPHAN SESSION RECOVERY ---
if [ -f "$SESSION_FILE" ]; then
    # File format: ROM|elapsed_time
    orphan_data=$(cat "$SESSION_FILE")
    orphan_rom=$(echo "$orphan_data" | cut -d'|' -f1)
    orphan_elapsed=$(echo "$orphan_data" | cut -d'|' -f2)
    if [ -f "$orphan_rom" ]; then
        if [ -f "$GTT_LIST" ]; then
            if grep -q "|$orphan_rom|" "$GTT_LIST"; then
                temp_file="/tmp/gtt_update.txt"
                while IFS= read -r line; do
                    if echo "$line" | grep -q "|$orphan_rom|"; then
                        game_name=$(echo "$line" | cut -d'|' -f1 | sed 's/^\[[^]]*\] //')
                        emulator=$(echo "$line" | cut -d'|' -f3)
                        play_count=$(echo "$line" | cut -d'|' -f4)
                        total_time=$(echo "$line" | cut -d'|' -f5)
                        play_count=$((play_count + 1))
                        session_time=$orphan_elapsed
                        total_time=$((total_time + session_time))
                        hours=$((total_time / 3600))
                        minutes=$(((total_time % 3600) / 60))
                        seconds=$((total_time % 60))
                        if [ $hours -gt 0 ]; then
                            time_display="${hours}h ${minutes}m"
                        elif [ $minutes -gt 0 ]; then
                            time_display="${minutes}m"
                        else
                            time_display="${seconds}s"
                        fi
                        display_name="[${time_display}] $game_name"
                        echo "$display_name|$orphan_rom|$emulator|$play_count|$total_time|$time_display|launch|$session_time" >> "$temp_file"
                    else
                        echo "$line" >> "$temp_file"
                    fi
                done < "$GTT_LIST"
                mv "$temp_file" "$GTT_LIST"
            else
                emulator="NDS"
                game_name=$(basename "$orphan_rom")
                game_name=$(echo "$game_name" | sed 's/([^)]*)//g' | sed 's/\.[^.]*$//' | tr '_' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^[0-9]\+[)\._ -]\+//')
                session_time=$orphan_elapsed
                hours=$((session_time / 3600))
                minutes=$(((session_time % 3600) / 60))
                seconds=$((session_time % 60))
                if [ $hours -gt 0 ]; then
                    time_display="${hours}h ${minutes}m"
                elif [ $minutes -gt 0 ]; then
                    time_display="${minutes}m"
                else
                    time_display="${seconds}s"
                fi
                temp_file="/tmp/gtt_list_temp.txt"
                header_line=$(head -n 1 "$GTT_LIST")
                echo "$header_line" > "$temp_file"
                display_name="[${time_display}] $game_name"
                echo "$display_name|$orphan_rom|NDS|1|$session_time|$time_display|launch|$session_time" >> "$temp_file"
                tail -n +2 "$GTT_LIST" >> "$temp_file"
                mv "$temp_file" "$GTT_LIST"
            fi
            temp_sorted="/tmp/gtt_sorted.txt"
            header=$(head -n 1 "$GTT_LIST")
            echo "$header" > "$temp_sorted"
            tail -n +2 "$GTT_LIST" | sort -t'|' -k5,5nr >> "$temp_sorted"
            mv "$temp_sorted" "$GTT_LIST"
        fi
    fi
    rm -f "$SESSION_FILE"
fi

# --- NEW: BITPAL ORPHAN SESSION RECOVERY ---
if [ -f "/mnt/SDCARD/Tools/$PLATFORM/BitPal.pak/current_session.txt" ]; then
    orphan_data=$(cat "/mnt/SDCARD/Tools/$PLATFORM/BitPal.pak/current_session.txt")
    orphan_rom=$(echo "$orphan_data" | cut -d'|' -f1)
    orphan_elapsed=$(echo "$orphan_data" | cut -d'|' -f2)
    
    if [ -f "$orphan_rom" ]; then
        # Check if this ROM belongs to a BitPal mission
        check_bitpal_missions "$orphan_rom"
        if [ -n "$BITPAL_MISSION_FILE" ]; then
            mission=$(cat "$BITPAL_MISSION_FILE")
            field_count=$(echo "$mission" | awk -F'|' '{print NF}')
            if [ "$field_count" -lt 8 ]; then
                current_accum=0
            else
                current_accum=$(echo "$mission" | cut -d'|' -f8)
            fi
            new_total=$((current_accum + orphan_elapsed))
            
            if [ "$field_count" -lt 8 ]; then
                mission=$(echo "$mission" | sed "s/\$/|${new_total}/")
            else
                mission=$(echo "$mission" | awk -F'|' -v newval="$new_total" 'BEGIN{OFS="|"} {$8=newval; print}')
            fi
            echo "$mission" > "$BITPAL_MISSION_FILE"
            
            # Create a marker file for BitPal to check if mission is complete
            target_seconds=$(( $(echo "$mission" | cut -d'|' -f4) * 60 ))
            if [ "$new_total" -ge "$target_seconds" ]; then
                touch "${BITPAL_MISSION_FILE}.complete"
            fi
        fi
    fi
    
    # Clean up the session file
    rm -f "/mnt/SDCARD/Tools/$PLATFORM/BitPal.pak/current_session.txt"
fi

# Record start time
START_TIME=$(date +%s)

# Update auto_resume script and remove previous auto_resume lines
update_auto_resume_script() {
    local rom_path="$1"
    if [ -f "$AUTO_RESUME_SCRIPT" ]; then
        sed -i "s|^ROM_PATH=.*|ROM_PATH=\"$rom_path\"|" "$AUTO_RESUME_SCRIPT"
    fi
}
remove_auto_resume_line() {
    local auto_sh_path="/mnt/SDCARD/.userdata/$PLATFORM/auto.sh"
    if [ -f "$auto_sh_path" ]; then
        sed -i '/auto_resume.sh/d' "$auto_sh_path"
    fi
}
remove_auto_resume_line
update_auto_resume_script "$ROM"

# --- Start Background Updater ---
# Every 10 seconds, write "ROM|elapsed_time" into SESSION_FILE and BitPal session file if needed.
( while true; do
      curr_time=$(date +%s)
      elapsed=$((curr_time - START_TIME))
      echo "$ROM|$elapsed" > "$SESSION_FILE"
      if [ "$TRACK_BITPAL" -eq 1 ]; then
          echo "$ROM|$elapsed" > "$BITPAL_SESSION_FILE"
      fi
      sleep 10
  done ) &
BG_PID=$!

# Launch DraStic emulator
echo $0 $*
progdir=`dirname "$0"`/drastic
cd $progdir
echo "=============================================="
echo "==================== DRASTIC ================="
echo "=============================================="
export HOME="$progdir"
#export SDL_AUDIODRIVER=dsp
./launch.sh "$*"
RET=$?

# On normal shutdown: kill background updater and remove SESSION_FILE.
kill $BG_PID 2>/dev/null
rm -f "$SESSION_FILE"
if [ "$TRACK_BITPAL" -eq 1 ]; then
    rm -f "$BITPAL_SESSION_FILE"
fi

# Calculate final session duration.
END_TIME=$(date +%s)
SESSION_DURATION=$((END_TIME - START_TIME))

# Update GTT list (same as before)
if [ -f "$ROM" ]; then
    if [ -f "$GTT_LIST" ]; then
        if grep -q "|$ROM|" "$GTT_LIST"; then
            temp_file="/tmp/gtt_update.txt"
            while IFS= read -r line; do
                if echo "$line" | grep -q "|$ROM|"; then
                    game_name=$(echo "$line" | cut -d'|' -f1 | sed 's/^\[[^]]*\] //')
                    emulator=$(echo "$line" | cut -d'|' -f3)
                    play_count=$(echo "$line" | cut -d'|' -f4)
                    total_time=$(echo "$line" | cut -d'|' -f5)
                    play_count=$((play_count + 1))
                    session_time=$SESSION_DURATION
                    total_time=$((total_time + session_time))
                    hours=$((total_time / 3600))
                    minutes=$(((total_time % 3600) / 60))
                    seconds=$((total_time % 60))
                    if [ $hours -gt 0 ]; then
                        time_display="${hours}h ${minutes}m"
                    elif [ $minutes -gt 0 ]; then
                        time_display="${minutes}m"
                    else
                        time_display="${seconds}s"
                    fi
                    display_name="[${time_display}] $game_name"
                    echo "$display_name|$ROM|$emulator|$play_count|$total_time|$time_display|launch|$session_time" >> "$temp_file"
                else
                    echo "$line" >> "$temp_file"
                fi
            done < "$GTT_LIST"
            mv "$temp_file" "$GTT_LIST"
        else
            emulator="NDS"
            game_name=$(basename "$ROM")
            game_name=$(echo "$game_name" | sed 's/([^)]*)//g' | sed 's/\.[^.]*$//' | tr '_' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^[0-9]\+[)\._ -]\+//')
            session_time=$SESSION_DURATION
            hours=$((session_time / 3600))
            minutes=$(((session_time % 3600) / 60))
            seconds=$((session_time % 60))
            if [ $hours -gt 0 ]; then
                time_display="${hours}h ${minutes}m"
            elif [ $minutes -gt 0 ]; then
                time_display="${minutes}m"
            else
                time_display="${seconds}s"
            fi
            temp_file="/tmp/gtt_list_temp.txt"
            header_line=$(head -n 1 "$GTT_LIST")
            echo "$header_line" > "$temp_file"
            display_name="[${time_display}] $game_name"
            echo "$display_name|$ROM|NDS|1|$session_time|$time_display|launch|$session_time" >> "$temp_file"
            tail -n +2 "$GTT_LIST" >> "$temp_file"
            mv "$temp_file" "$GTT_LIST"
        fi
        temp_sorted="/tmp/gtt_sorted.txt"
        header=$(head -n 1 "$GTT_LIST")
        echo "$header" > "$temp_sorted"
        tail -n +2 "$GTT_LIST" | sort -t'|' -k5,5nr >> "$temp_sorted"
        mv "$temp_sorted" "$GTT_LIST"
    elif [ -d "/mnt/SDCARD/Tools/$PLATFORM/Game Time Tracker.pak" ]; then
        mkdir -p "$(dirname "$GTT_LIST")"
        echo "Game Time Tracker|__HEADER__|header" > "$GTT_LIST"
        game_name=$(basename "$ROM")
        game_name=$(echo "$game_name" | sed 's/([^)]*)//g' | sed 's/\.[^.]*$//' | tr '_' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^[0-9]\+[)\._ -]\+//')
        session_time=$SESSION_DURATION
        hours=$((session_time / 3600))
        minutes=$(((session_time % 3600) / 60))
        seconds=$((session_time % 60))
        if [ $hours -gt 0 ]; then
            time_display="${hours}h ${minutes}m"
        elif [ $minutes -gt 0 ]; then
            time_display="${minutes}m"
        else
            time_display="${seconds}s"
        fi
        display_name="[${time_display}] $game_name"
        echo "$display_name|$ROM|NDS|1|$session_time|$time_display|launch|$session_time" >> "$GTT_LIST"
    fi
fi

# --- NEW: UPDATE BITPAL MISSION TIME ---
if [ "$TRACK_BITPAL" -eq 1 ]; then
    # Write the session duration for BitPal
    echo "$SESSION_DURATION" > "$BITPAL_LAST_SESSION_FILE"
    
    # Also update the mission file directly
    if [ -f "$BITPAL_MISSION_FILE" ]; then
        mission=$(cat "$BITPAL_MISSION_FILE")
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
        echo "$mission" > "$BITPAL_MISSION_FILE"
        
        # Create a marker file for BitPal to check if mission is complete
        target_seconds=$(( $(echo "$mission" | cut -d'|' -f4) * 60 ))
        if [ "$new_total" -ge "$target_seconds" ]; then
            touch "${BITPAL_MISSION_FILE}.complete"
        fi
    fi
else
    # Even if we're not actively tracking a BitPal mission, write the session duration
    # This allows BitPal to detect the time when launching games
    echo "$SESSION_DURATION" > "$LAST_SESSION_FILE"
fi

exit $RET