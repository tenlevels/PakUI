#!/bin/sh

source /mnt/SDCARD/System/etc/ex_config

echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo 1008000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
echo 2000000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq

PORTS_DIR=/mnt/SDCARD/Roms/PORTS
cd "$PORTS_DIR" || exit 1

# -------------------------------------------------------------------
# We REMOVE the forced  PLATFORM="PORTS"
# so it uses your existing $PLATFORM env variable.
# -------------------------------------------------------------------
# PLATFORM="PORTS"

# Define variables for Game Time Tracker and BitPal
# Use environment overrides if provided; otherwise default to GTT paths
: "${SESSION_FILE:="/mnt/SDCARD/Tools/$PLATFORM/Game Time Tracker.pak/current_session.txt"}"
: "${LAST_SESSION_FILE:="/mnt/SDCARD/Tools/$PLATFORM/Game Time Tracker.pak/last_session_duration.txt"}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GTT_LIST="/mnt/SDCARD/Tools/$PLATFORM/Game Time Tracker.pak/gtt_list.txt"

# Save the full command line as the ROM identifier
ROM="${1:-$0}"
FULL_CMDLINE="$@"

# Check for BitPal active missions
find_bitpal_dir() {
    local found_dir=""
    for check_dir in "/mnt/SDCARD/Tools/$PLATFORM"/*; do
        if [ -d "$check_dir" ]; then
            base_name=$(basename "$check_dir")
            if echo "$base_name" | grep -i "bitpal" > /dev/null; then
                found_dir="$check_dir"
                break
            fi
        fi
    done

    if [ -z "$found_dir" ]; then
        for check_dir in "/mnt/SDCARD/Roms"/*; do
            if [ -d "$check_dir" ]; then
                base_name=$(basename "$check_dir")
                if echo "$base_name" | grep -i "bitpal" > /dev/null; then
                    found_dir="$check_dir"
                    break
                fi
            fi
        done
    fi

    echo "$found_dir"
}

BITPAL_DIR=$(find_bitpal_dir)

if [ -n "$BITPAL_DIR" ]; then
    BITPAL_ACTIVE_MISSIONS_DIR="$BITPAL_DIR/bitpal_data/active_missions"
    BITPAL_ACTIVE_MISSION="$BITPAL_DIR/bitpal_data/active_mission.txt"
    BITPAL_SESSION_FILE="$BITPAL_DIR/current_session.txt"
    BITPAL_LAST_SESSION_FILE="$BITPAL_DIR/last_session_duration.txt"
else
    BITPAL_DIR="/mnt/SDCARD/Tools/$PLATFORM/BitPal.pak"
    BITPAL_ACTIVE_MISSIONS_DIR="$BITPAL_DIR/bitpal_data/active_missions"
    BITPAL_ACTIVE_MISSION="$BITPAL_DIR/bitpal_data/active_mission.txt"
    BITPAL_SESSION_FILE="$BITPAL_DIR/current_session.txt"
    BITPAL_LAST_SESSION_FILE="$BITPAL_DIR/last_session_duration.txt"
fi

BITPAL_MISSION_ROM=""
BITPAL_MISSION_FILE=""

# -------------------------------------------------------------------
# First check for orphaned session files and clean them up
# Removed the [ -f "$orphan_rom" ] checks so GTT doesn't skip shell scripts
# -------------------------------------------------------------------
handle_orphan_session() {
    if [ -f "$SESSION_FILE" ]; then
        orphan_data=$(cat "$SESSION_FILE")
        orphan_rom=$(echo "$orphan_data" | cut -d'|' -f1)
        orphan_elapsed=$(echo "$orphan_data" | cut -d'|' -f2)

        # Directly update GTT list (no [ -f "$orphan_rom" ] check)
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
                emulator="PORTS"
                game_name=$(basename "$orphan_rom")
                game_name=$(echo "$game_name" | sed 's/([^)]*)//g' | sed 's/\.[^.]*$//' | tr '_' ' ' \
                                     | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                                           -e 's/^[0-9]\+[)\._ -]\+//')
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
                echo "$display_name|$orphan_rom|PORTS|1|$session_time|$time_display|launch|$session_time" >> "$temp_file"
                tail -n +2 "$GTT_LIST" >> "$temp_file"
                mv "$temp_file" "$GTT_LIST"
            fi
            temp_sorted="/tmp/gtt_sorted.txt"
            header=$(head -n 1 "$GTT_LIST")
            echo "$header" > "$temp_sorted"
            tail -n +2 "$GTT_LIST" | sort -t'|' -k5,5nr >> "$temp_sorted"
            mv "$temp_sorted" "$GTT_LIST"
        fi
        rm -f "$SESSION_FILE"
    fi

    if [ -f "$BITPAL_SESSION_FILE" ]; then
        orphan_data=$(cat "$BITPAL_SESSION_FILE")
        orphan_rom=$(echo "$orphan_data" | cut -d'|' -f1)
        orphan_elapsed=$(echo "$orphan_data" | cut -d'|' -f2)

        # Remove [ -f "$orphan_rom" ] check so we always update BitPal
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

            target_seconds=$(( $(echo "$mission" | cut -d'|' -f4) * 60 ))
            if [ "$new_total" -ge "$target_seconds" ]; then
                touch "${BITPAL_MISSION_FILE}.complete"
            fi
        fi
        rm -f "$BITPAL_SESSION_FILE"
    fi
}

# Check if this ROM is part of an active BitPal mission
check_bitpal_missions() {
    local rom_path="$1"
    BITPAL_MISSION_ROM=""
    BITPAL_MISSION_FILE=""

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

update_gtt_list() {
    local rom="$1"
    local session_duration="$2"

    if [ -f "$GTT_LIST" ]; then
        if grep -q "|$rom|" "$GTT_LIST"; then
            temp_file="/tmp/gtt_update.txt"
            while IFS= read -r line; do
                if echo "$line" | grep -q "|$rom|"; then
                    game_name=$(echo "$line" | cut -d'|' -f1 | sed 's/^\[[^]]*\] //')
                    emulator=$(echo "$line" | cut -d'|' -f3)
                    play_count=$(echo "$line" | cut -d'|' -f4)
                    total_time=$(echo "$line" | cut -d'|' -f5)
                    play_count=$((play_count + 1))
                    session_time=$session_duration
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
                    echo "$display_name|$rom|$emulator|$play_count|$total_time|$time_display|launch|$session_time" >> "$temp_file"
                else
                    echo "$line" >> "$temp_file"
                fi
            done < "$GTT_LIST"
            mv "$temp_file" "$GTT_LIST"
        else
            emulator="PORTS"
            game_name=$(basename "$rom")
            game_name=$(echo "$game_name" | sed 's/([^)]*)//g' | sed 's/\.[^.]*$//' | tr '_' ' ' \
                                 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                                       -e 's/^[0-9]\+[)\._ -]\+//')
            session_time=$session_duration
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
            echo "$display_name|$rom|PORTS|1|$session_time|$time_display|launch|$session_time" >> "$temp_file"
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
        game_name=$(basename "$rom")
        game_name=$(echo "$game_name" | sed 's/([^)]*)//g' | sed 's/\.[^.]*$//' | tr '_' ' ' \
                                 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                                       -e 's/^[0-9]\+[)\._ -]\+//')
        session_time=$session_duration
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
        echo "$display_name|$rom|PORTS|1|$session_time|$time_display|launch|$session_time" >> "$GTT_LIST"
    fi
}

update_bitpal_mission() {
    local session_duration="$1"

    if [ "$TRACK_BITPAL" -eq 1 ] && [ -f "$BITPAL_MISSION_FILE" ]; then
        mission=$(cat "$BITPAL_MISSION_FILE")
        field_count=$(echo "$mission" | awk -F'|' '{print NF}')
        if [ "$field_count" -lt 8 ]; then
            current_accum=0
        else
            current_accum=$(echo "$mission" | cut -d'|' -f8)
        fi
        new_total=$((current_accum + session_duration))

        if [ "$field_count" -lt 8 ]; then
            mission=$(echo "$mission" | sed "s/\$/|${new_total}/")
        else
            mission=$(echo "$mission" | awk -F'|' -v newval="$new_total" 'BEGIN{OFS="|"} {$8=newval; print}')
        fi
        echo "$mission" > "$BITPAL_MISSION_FILE"

        target_seconds=$(( $(echo "$mission" | cut -d'|' -f4) * 60 ))
        if [ "$new_total" -ge "$target_seconds" ]; then
            touch "${BITPAL_MISSION_FILE}.complete"
        fi
    fi
}

# Clean up any orphaned sessions
handle_orphan_session

# Call the function to check BitPal missions
check_bitpal_missions "$ROM"
if [ -n "$BITPAL_MISSION_ROM" ]; then
    # We'll track for both GTT and BitPal
    TRACK_BITPAL=1
else
    TRACK_BITPAL=0
fi

# Record start time
START_TIME=$(date +%s)

# Start Background Updater for GTT
(
  while true; do
      curr_time=$(date +%s)
      elapsed=$((curr_time - START_TIME))
      echo "$ROM|$elapsed" > "$SESSION_FILE"
      if [ "$TRACK_BITPAL" -eq 1 ]; then
          echo "$ROM|$elapsed" > "$BITPAL_SESSION_FILE"
      fi
      sleep 10
  done
) &
BG_PID=$!

# Launch the port
/bin/sh "$@"
RET=$?

# Ensure at least one time update occurred
sleep 2

# On normal shutdown: kill background updater
kill "$BG_PID" 2>/dev/null

# Save last session data before removing the files
FINAL_SESSION_DATA=""
if [ -f "$SESSION_FILE" ]; then
    FINAL_SESSION_DATA=$(cat "$SESSION_FILE")
    rm -f "$SESSION_FILE"
fi

BITPAL_SESSION_DATA=""
if [ "$TRACK_BITPAL" -eq 1 ] && [ -f "$BITPAL_SESSION_FILE" ]; then
    BITPAL_SESSION_DATA=$(cat "$BITPAL_SESSION_FILE")
    rm -f "$BITPAL_SESSION_FILE"
fi

# Calculate final session duration
END_TIME=$(date +%s)
SESSION_DURATION=$((END_TIME - START_TIME))
[ "$SESSION_DURATION" -lt 5 ] && SESSION_DURATION=5  # minimal track time

# Update GTT list
update_gtt_list "$ROM" "$SESSION_DURATION"

# Write session duration to GTT
echo "$SESSION_DURATION" > "$LAST_SESSION_FILE"

# Write to BitPal if needed and update mission
if [ "$TRACK_BITPAL" -eq 1 ]; then
    echo "$SESSION_DURATION" > "$BITPAL_LAST_SESSION_FILE"
    update_bitpal_mission "$SESSION_DURATION"
fi

exit $RET
