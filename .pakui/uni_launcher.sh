#!/bin/sh

: ${PLATFORM:?PLATFORM variable not set}
: ${SESSION_FILE:="/mnt/SDCARD/Tools/$PLATFORM/Game Time Tracker.pak/current_session.txt"}
: ${LAST_SESSION_FILE:="/mnt/SDCARD/Tools/$PLATFORM/Game Time Tracker.pak/last_session_duration.txt"}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GTT_LIST="/mnt/SDCARD/Tools/$PLATFORM/Game Time Tracker.pak/gtt_list.txt"
AUTO_RESUME_SCRIPT="$SCRIPT_DIR/auto_resume.sh"
ROM="$1"

EMU_TAG=$(basename "$(dirname "$0")" .pak)

mkdir -p "$BIOS_PATH/$EMU_TAG"
mkdir -p "$SAVES_PATH/$EMU_TAG"

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

check_bitpal_missions "$ROM"

if [ -n "$BITPAL_MISSION_ROM" ]; then
    TRACK_BITPAL=1
else
    TRACK_BITPAL=0
fi


if [ -f "$SESSION_FILE" ]; then
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
                emulator=$(basename "$(dirname "$0")" .pak)
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
                echo "$display_name|$orphan_rom|$emulator|1|$session_time|$time_display|launch|$session_time" >> "$temp_file"
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


if [ -f "$BITPAL_SESSION_FILE" ]; then
    orphan_data=$(cat "$BITPAL_SESSION_FILE")
    orphan_rom=$(echo "$orphan_data" | cut -d'|' -f1)
    orphan_elapsed=$(echo "$orphan_data" | cut -d'|' -f2)
    
    if [ -f "$orphan_rom" ]; then
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
    fi
    
    rm -f "$BITPAL_SESSION_FILE"
fi


START_TIME=$(date +%s)

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


"$SCRIPT_DIR/universal_launcher" "$@"
RET=$?

kill $BG_PID 2>/dev/null
rm -f "$SESSION_FILE"
if [ "$TRACK_BITPAL" -eq 1 ]; then
    rm -f "$BITPAL_SESSION_FILE"
fi


END_TIME=$(date +%s)
SESSION_DURATION=$((END_TIME - START_TIME))

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
            emulator=$(basename "$(dirname "$0")" .pak)
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
            echo "$display_name|$ROM|$emulator|1|$session_time|$time_display|launch|$session_time" >> "$temp_file"
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
        echo "$display_name|$ROM|$emu_tag|1|$session_time|$time_display|launch|$session_time" >> "$GTT_LIST"
    fi
fi


if [ "$TRACK_BITPAL" -eq 1 ]; then
    echo "$SESSION_DURATION" > "$BITPAL_LAST_SESSION_FILE"
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
        
        target_seconds=$(( $(echo "$mission" | cut -d'|' -f4) * 60 ))
        if [ "$new_total" -ge "$target_seconds" ]; then
            touch "${BITPAL_MISSION_FILE}.complete"
        fi
    fi
else
    echo "$SESSION_DURATION" > "$LAST_SESSION_FILE"
fi

exit $RET