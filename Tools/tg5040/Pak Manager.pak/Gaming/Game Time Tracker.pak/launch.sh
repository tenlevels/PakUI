#!/bin/sh
cd "$(dirname "$0")"
export LD_LIBRARY_PATH=/usr/trimui/lib:$LD_LIBRARY_PATH
export PLATFORM="$(basename "$(dirname "$(dirname "$0")")")"
GTT_DIR="$(pwd)"
OPTIONS_DIR="$GTT_DIR/options"
GTT_LIST="$GTT_DIR/gtt_list.txt"
mkdir -p "$OPTIONS_DIR"
if [ ! -f "$GTT_LIST" ]; then
    echo "Game Time Tracker|__HEADER__|header" > "$GTT_LIST"
fi

format_time() {
    local seconds="$1"
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

streak_format_time() {
    local seconds="$1"
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    if [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m"
    else
        echo "${minutes}m"
    fi
}

calculate_average_session() {
    local total_time="$1"
    local play_count="$2"
    if [ "$play_count" -gt 0 ]; then
        avg_seconds=$((total_time / play_count))
        format_time "$avg_seconds"
    else
        echo "N/A"
    fi
}

get_clean_system() {
    local rom_path="$1"
    local rom_folder_path=$(dirname "$rom_path")
    local rom_folder_name=$(basename "$rom_folder_path")
    local rom_parent_dir=$(dirname "$rom_folder_path")
    if [ "$rom_parent_dir" = "/mnt/SDCARD/Roms" ]; then
        echo "$rom_folder_name" | sed -E 's/^[0-9]+[)\._ -]+//g' | sed 's/ *([^)]*)//g' | sed 's/^ *//;s/ *$//'
    else
        echo "$(basename "$rom_parent_dir")" | sed -E 's/^[0-9]+[)\._ -]+//g' | sed 's/ *([^)]*)//g' | sed 's/^ *//;s/ *$//'
    fi
}

get_motivation() {
    local rand=$(( ( $(date +%s) + $$ ) % 20 ))
    case $rand in
        0) echo "Keep up the great work!";;
        1) echo "You're on fire!";;
        2) echo "Game on, champion!";;
        3) echo "Your streak is impressive!";;
        4) echo "Keep the momentum!";;
        5) echo "You're unstoppable!";;
        6) echo "Fantastic, keep it going!";;
        7) echo "Every day counts!";;
        8) echo "Keep the streak alive!";;
        9) echo "You're a gaming legend!";;
        10) echo "Don't pause now, level up!";;
        11) echo "You're pressing all the right buttons!";;
        12) echo "Keep calm and respawn on!";;
        13) echo "No cheat codes needed, you're a natural!";;
        14) echo "You've got game, literally!";;
        15) echo "Game over? Not on your watch!";;
        16) echo "You're an XP-ert at this!";;
        17) echo "Leveling up, one day at a time!";;
        18) echo "Press start to continue your streak!";;
        19) echo "Happy Gaming!";;
    esac
}

update_display_names() {
    local temp_file="/tmp/gtt_display.txt"
    head -n 1 "$GTT_LIST" > "$temp_file"
    tail -n +2 "$GTT_LIST" | while IFS= read -r line; do
        game_name=$(echo "$line" | cut -d'|' -f1 | sed 's/^\[[^]]*\] //')
        rom_path=$(echo "$line" | cut -d'|' -f2)
        emulator=$(echo "$line" | cut -d'|' -f3)
        play_count=$(echo "$line" | cut -d'|' -f4)
        total_time=$(echo "$line" | cut -d'|' -f5)
        time_display=$(echo "$line" | cut -d'|' -f6)
        action=$(echo "$line" | cut -d'|' -f7)
        last_session=$(echo "$line" | cut -d'|' -f8)
        display_name="[${time_display}] $game_name"
        echo "$display_name|$rom_path|$emulator|$play_count|$total_time|$time_display|$action|$last_session" >> "$temp_file"
    done
    mv "$temp_file" "$GTT_LIST"
}

create_options_list() {
    > options_list.txt
    for script in "$OPTIONS_DIR"/*.sh; do
        if [ -x "$script" ]; then
            full_filename=$(basename "$script")
            name=$(echo "$full_filename" | sed 's/^[0-9]*) *//' | sed 's/\.sh$//')
            display_name=$(echo "$name" | sed -E 's/_/ /g; s/\b\(.*\)\b//g' | awk '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1')
            echo "$display_name|$full_filename" >> options_list.txt
        fi
    done
    if [ ! -s options_list.txt ]; then
        echo "No Options Available|no_options" > options_list.txt
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

# UPDATED: show_game_details now uses full formatting for Total Play Time and Last Session
show_game_details() {
    local game_data="$1"
    if [ -x "$OPTIONS_DIR/game_details.sh" ]; then
        "$OPTIONS_DIR/game_details.sh" "$game_data"
    else
        display_name=$(echo "$game_data" | cut -d'|' -f1)
        rom_path=$(echo "$game_data" | cut -d'|' -f2)
        emulator=$(echo "$game_data" | cut -d'|' -f3)
        play_count=$(echo "$game_data" | cut -d'|' -f4)
        total_time=$(echo "$game_data" | cut -d'|' -f5)
        time_display=$(echo "$game_data" | cut -d'|' -f6)
        last_session=$(echo "$game_data" | cut -d'|' -f8)
        game_name=$(echo "$display_name" | sed 's/^\[[^]]*\] //')
        avg_session=$(calculate_average_session "$total_time" "$play_count")
        rom_folder_path=$(dirname "$rom_path")
        rom_folder_name=$(basename "$rom_folder_path")
        rom_parent_dir=$(dirname "$rom_folder_path")
        system_name=$(get_clean_system "$rom_path")
        # Format both total time and last session with full formatting
        full_time_display=$(format_time "$total_time")
        last_session_display=$(format_time "$last_session")
        ./show_message "$game_name|System: $system_name||Play Count: $play_count times|Total Play Time: $full_time_display|Average Session: $avg_session|Last Session: $last_session_display" -l a
    fi
}

launch_game() {
    local rom_path="$1"
    local start_time=$(date +%s)
    prepare_resume "$rom_path"
    CURRENT_PATH=$(dirname "$rom_path")
    ROM_FOLDER_NAME=$(basename "$CURRENT_PATH")
    ROM_PLATFORM=""
    while [ -z "$ROM_PLATFORM" ]; do
        [ "$ROM_FOLDER_NAME" = "Roms" ] && { ROM_PLATFORM="UNK"; break; }
        ROM_PLATFORM=$(echo "$ROM_FOLDER_NAME" | sed -n 's/.*(\(.*\)).*/\1/p')
        [ -z "$ROM_PLATFORM" ] && { CURRENT_PATH=$(dirname "$CURRENT_PATH"); ROM_FOLDER_NAME=$(basename "$CURRENT_PATH"); }
    done
    if [ -d "/mnt/SDCARD/Emus/$PLATFORM/$ROM_PLATFORM.pak" ]; then
        EMULATOR="/mnt/SDCARD/Emus/$PLATFORM/$ROM_PLATFORM.pak/launch.sh"
        "$EMULATOR" "$rom_path"
    elif [ -d "/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$ROM_PLATFORM.pak" ]; then
        EMULATOR="/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$ROM_PLATFORM.pak/launch.sh"
        "$EMULATOR" "$rom_path"
    else
        ./show_message "Emulator not found for $ROM_PLATFORM" -l a
        return 1
    fi
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local temp_file="/tmp/gtt_update.txt"
    > "$temp_file"
    while IFS= read -r line; do
        if [ "$line" = "$(head -n 1 "$GTT_LIST")" ]; then
            echo "$line" >> "$temp_file"
            continue
        fi
        local curr_rom_path=$(echo "$line" | cut -d'|' -f2)
        if [ "$curr_rom_path" = "$rom_path" ]; then
            local game_name=$(echo "$line" | cut -d'|' -f1 | sed 's/^\[[^]]*\] //')
            local emulator=$(echo "$line" | cut -d'|' -f3)
            local play_count=$(echo "$line" | cut -d'|' -f4)
            local total_time=$(echo "$line" | cut -d'|' -f5)
            local time_display=$(echo "$line" | cut -d'|' -f6)
            local action=$(echo "$line" | cut -d'|' -f7)
            local last_session=$(echo "$line" | cut -d'|' -f8)
            play_count=$((play_count + 1))
            total_time=$((total_time + duration))
            time_display=$(format_time "$total_time")
            last_session=$(format_time "$duration")
            display_name="[${time_display}] $game_name"
            echo "$display_name|$rom_path|$emulator|$play_count|$total_time|$time_display|$action|$last_session" >> "$temp_file"
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$GTT_LIST"
    mv "$temp_file" "$GTT_LIST"
    return 0
}

show_options_menu() {
    local game_data="$1"
    local return_to_options=true
    while $return_to_options; do
        create_options_list
        options_output=$(./picker "options_list.txt" -b "BACK")
        options_status=$?
        if [ $options_status -eq 1 ] || [ -z "$options_output" ]; then
            return_to_options=false
            continue
        fi
        if [ $options_status -eq 0 ] && [ -n "$options_output" ]; then
            option_action=$(echo "$options_output" | cut -d'|' -f2)
            if [ "$option_action" != "no_options" ] && [ -x "$OPTIONS_DIR/$option_action" ]; then
                if [ -n "$game_data" ] && [ "$(echo "$game_data" | cut -d'|' -f7)" = "launch" ]; then
                    "$OPTIONS_DIR/$option_action" "$game_data"
                else
                    "$OPTIONS_DIR/$option_action"
                fi
            fi
        fi
    done
}

display_overview() {
    total_games=$(grep -c "|launch" "$GTT_LIST")
    if [ "$total_games" -eq 0 ]; then
        ./show_message "No Data Available|No games have been played yet." -l a
        return
    fi
    total_plays=$(awk -F'|' '/\|launch/ {sum+=$4} END {print sum}' "$GTT_LIST")
    total_time=$(awk -F'|' '/\|launch/ {sum+=$5} END {print sum}' "$GTT_LIST")
    formatted_time=$(format_time "$total_time")
    if [ "$total_plays" -gt 0 ]; then
        avg_time=$((total_time / total_plays))
        avg_formatted=$(format_time "$avg_time")
    else
        avg_formatted="N/A"
    fi
    most_played_line=$(grep "|launch" "$GTT_LIST" | sort -t'|' -k4,4nr | head -n 1)
    most_played_name=$(echo "$most_played_line" | cut -d'|' -f1 | sed 's/^\[[^]]*\] //')
    most_played_count=$(echo "$most_played_line" | cut -d'|' -f4)
    most_time_line=$(grep "|launch" "$GTT_LIST" | sort -t'|' -k5,5nr | head -n 1)
    most_time_name=$(echo "$most_time_line" | cut -d'|' -f1 | sed 's/^\[[^]]*\] //')
    most_time_seconds=$(echo "$most_time_line" | cut -d'|' -f5)
    most_time_formatted=$(format_time "$most_time_seconds")
    message="Overview Stats|Games: $total_games|Plays: $total_plays|Time: $formatted_time|Avg: $avg_formatted|Most Played: $most_played_count|$most_played_name"
    ./show_message "$message" -l a
}

display_top_games() {
    total_games=$(grep -c "|launch" "$GTT_LIST")
    if [ "$total_games" -eq 0 ]; then
        ./show_message "No Data Available|No games have been played yet." -l a
        return
    fi
    first_name=""; first_stats=""
    second_name=""; second_stats=""
    third_name=""; third_stats=""
    count=0
    grep "|launch" "$GTT_LIST" | sort -t'|' -k5,5nr | head -n 3 > /tmp/top_games.txt
    while IFS= read -r line; do
        count=$((count + 1))
        display_name=$(echo "$line" | cut -d'|' -f1)
        clean_name=$(echo "$display_name" | sed 's/^\[[^]]*\] //')
        play_time=$(echo "$line" | cut -d'|' -f5)
        formatted_time=$(format_time "$play_time")
        play_count=$(echo "$line" | cut -d'|' -f4)
        game_stats="$formatted_time ($play_count plays)"
        case $count in
            1) first_name="$clean_name"; first_stats="$game_stats" ;;
            2) second_name="$clean_name"; second_stats="$game_stats" ;;
            3) third_name="$clean_name"; third_stats="$game_stats" ;;
        esac
    done < /tmp/top_games.txt
    rm -f /tmp/top_games.txt
    message="Top 3 Games|$first_name|$first_stats|$second_name|$second_stats|$third_name|$third_stats"
    ./show_message "$message" -l a
}

display_system_stats() {
    total_games=$(grep -c "|launch" "$GTT_LIST")
    if [ "$total_games" -eq 0 ]; then
        ./show_message "No Data Available|No games have been played yet." -l a
        return
    fi
    temp_systems="/tmp/gtt_systems.txt"
    sorted_systems="/tmp/gtt_sorted.txt"
    rm -f "$temp_systems" "$sorted_systems"
    touch "$temp_systems"
    grep "|launch" "$GTT_LIST" > /tmp/all_games.txt
    while IFS='|' read -r disp rom_path emulator play_count total_time time_disp action last_session; do
        sys=$(get_clean_system "$rom_path")
        if grep -q "^$sys|" "$temp_systems"; then
            curr_time=$(grep "^$sys|" "$temp_systems" | cut -d'|' -f2)
            new_time=$((curr_time + total_time))
            grep -v "^$sys|" "$temp_systems" > /tmp/temp_sys.txt
            mv /tmp/temp_sys.txt "$temp_systems"
            echo "$sys|$new_time" >> "$temp_systems"
        else
            echo "$sys|$total_time" >> "$temp_systems"
        fi
    done < /tmp/all_games.txt
    rm -f /tmp/all_games.txt
    total_time_all=$(awk -F'|' '/\|launch/ {sum+=$5} END {print sum}' "$GTT_LIST")
    sort -t'|' -k2,2nr "$temp_systems" > "$sorted_systems"
    top1=""; top2=""; top3=""; top4=""; top5=""
    sum_top=0; count=0
    while IFS='|' read -r sys time; do
        count=$((count + 1))
        if [ $count -le 5 ]; then
            sum_top=$((sum_top + time))
            pct=$(( time * 100 / total_time_all ))
            line="$sys: $(format_time "$time") (${pct}%)"
            case $count in
                1) top1="$line" ;;
                2) top2="$line" ;;
                3) top3="$line" ;;
                4) top4="$line" ;;
                5) top5="$line" ;;
            esac
        fi
    done < "$sorted_systems"
    other_time=$(( total_time_all - sum_top ))
    [ $other_time -lt 0 ] && other_time=0
    other_pct=0
    if [ "$total_time_all" -gt 0 ]; then
       other_pct=$(( other_time * 100 / total_time_all ))
    fi
    other_line="Other: $(format_time "$other_time") (${other_pct}%)"
    message="Top Systems|$top1|$top2|$top3|$top4|$top5|$other_line"
    ./show_message "$message" -l a
    rm -f "$temp_systems" "$sorted_systems"
}

export_stats() {
    total_games=$(grep -c "|launch" "$GTT_LIST")
    if [ "$total_games" -eq 0 ]; then
        ./show_message "No Data Available|No games have been played yet." -l a
        return
    fi
    result=$(./show_message "Export Statistics?|This will save all your game stats and streak data to a text file.|Continue?" -l -a "YES" -b "NO")
    export_status=$?
    if [ $export_status -eq 0 ]; then
        EXPORT_DIR="/mnt/SDCARD/GTT_Stats"
        mkdir -p "$EXPORT_DIR"
        EXPORT_FILE="$EXPORT_DIR/gaming_stats_$(date +%Y-%m-%d).txt"
        {
            echo "GAME TIME TRACKER - GAMING STATISTICS"
            echo "Generated: $(date)"
            printf '%80s\n' | tr " " "-"
            total_games=$(grep -c "|launch" "$GTT_LIST")
            total_time=$(awk -F'|' '/\|launch/ {sum+=$5} END {print sum}' "$GTT_LIST")
            total_plays=$(awk -F'|' '/\|launch/ {sum+=$4} END {print sum}' "$GTT_LIST")
            formatted_time=$(format_time "$total_time")
            echo "OVERALL STATISTICS:"
            echo "Total Games: $total_games"
            echo "Total Play Time: $formatted_time"
            echo "Total Play Sessions: $total_plays"
            if [ "$total_plays" -gt 0 ]; then
                avg_session=$((total_time / total_plays))
                formatted_avg=$(format_time "$avg_session")
                echo "Average Session Length: $formatted_avg"
            fi
            STREAK_FILE="$GTT_DIR/.streak_data.txt"
            if [ -f "$STREAK_FILE" ]; then
                . "$STREAK_FILE"
                printf '%80s\n' | tr " " "-"
                echo "STREAK DATA:"
                echo "Current Streak: $current_streak days"
                echo "Longest Streak: $longest_streak days"
                echo "Total Gaming Days: $total_days"
                echo "Streak Start Date: $start_date"
            fi
            printf '%80s\n' | tr " " "-"
            echo "TOP 10 MOST PLAYED GAMES (BY TIME):"
            echo ""
            echo "Rank | Game Name                     | Play Time     | Sessions"
            echo "-----|-------------------------------|---------------|--------"
            count=1
            grep "|launch" "$GTT_LIST" | sort -t'|' -k5,5nr | head -n 10 > /tmp/top10_games.txt
            while IFS= read -r line; do
                display_name=$(echo "$line" | cut -d'|' -f1)
                clean_name=$(echo "$display_name" | sed 's/^\[[^]]*\] //')
                play_time=$(echo "$line" | cut -d'|' -f5)
                formatted_time=$(format_time "$play_time")
                play_count=$(echo "$line" | cut -d'|' -f4)
                printf "%-5s| %-30s| %-15s| %s\n" "$count" "${clean_name:0:30}" "$formatted_time" "$play_count"
                count=$((count + 1))
            done < /tmp/top10_games.txt
            rm -f /tmp/top10_games.txt
            printf '%80s\n' | tr " " "-"
            echo "GAMING BY SYSTEM:"
            echo ""
            temp_systems="/tmp/gtt_systems.txt"
            > "$temp_systems"
            grep "|launch" "$GTT_LIST" > /tmp/all_games_export.txt
            while IFS= read -r line; do
                rom_path=$(echo "$line" | cut -d'|' -f2)
                system=$(get_clean_system "$rom_path")
                play_time=$(echo "$line" | cut -d'|' -f5)
                if grep -q "^$system|" "$temp_systems"; then
                    curr_time=$(grep "^$system|" "$temp_systems" | cut -d'|' -f2)
                    new_time=$((curr_time + play_time))
                    sed -i "s|^$system.*|$system|$new_time|" "$temp_systems"
                else
                    echo "$system|$play_time" >> "$temp_systems"
                fi
            done < /tmp/all_games_export.txt
            rm -f /tmp/all_games_export.txt
            echo "System                 | Play Time      | % of Total"
            echo "-----------------------|----------------|----------"
            sort -t'|' -k2,2nr "$temp_systems" > /tmp/sorted_systems_export.txt
            while IFS='|' read -r system time; do
                formatted_time=$(format_time "$time")
                percentage=$((time * 100 / total_time))
                printf "%-22s| %-15s| %d%%\n" "${system:0:22}" "$formatted_time" "$percentage"
            done < /tmp/sorted_systems_export.txt
            rm -f /tmp/sorted_systems_export.txt "$temp_systems"
            printf '%80s\n' | tr " " "-"
            echo "NOTES:"
            echo "* This export was generated from Game Time Tracker data"
            echo "* All times are tracked automatically as you play games"
            echo "* Export date: $(date)"
        } > "$EXPORT_FILE"
        ./show_message "Stats Exported!|File saved to:|$EXPORT_DIR/gaming_stats_$(date +%Y-%m-%d).txt" -l a
    fi
}

show_streak_menu() {
    total_games=$(grep -c "|launch" "$GTT_LIST")
    if [ "$total_games" -eq 0 ]; then
        ./show_message "No Data Available|No games have been played yet." -l a
        return
    fi
    GTT_DIR="$(pwd)"
    STREAK_FILE="$GTT_DIR/.streak_data.txt"
    TODAY=$(date +%Y-%m-%d)
    if [ ! -f "$STREAK_FILE" ]; then
        echo "last_played=$TODAY" > "$STREAK_FILE"
        echo "current_streak=1" >> "$STREAK_FILE"
        echo "longest_streak=1" >> "$STREAK_FILE"
        echo "total_days=1" >> "$STREAK_FILE"
        echo "start_date=$TODAY" >> "$STREAK_FILE"
    fi
    . "$STREAK_FILE"
    days_diff() {
        local d1=$(date -d "$1" +%s)
        local d2=$(date -d "$2" +%s)
        echo $(( (d1 - d2) / 86400 ))
    }
    update_streak() {
        if [ "$TODAY" = "$last_played" ]; then
            return
        fi
        diff=$(days_diff "$TODAY" "$last_played")
        if [ "$diff" -eq 1 ]; then
            current_streak=$((current_streak + 1))
            if [ "$current_streak" -gt "$longest_streak" ]; then
                longest_streak=$current_streak
            fi
        elif [ "$diff" -gt 1 ]; then
            current_streak=1
        fi
        last_played="$TODAY"
        total_days=$((total_days + 1))
        {
            echo "last_played=$last_played"
            echo "current_streak=$current_streak"
            echo "longest_streak=$longest_streak"
            echo "total_days=$total_days"
            echo "start_date=$start_date"
        } > "$STREAK_FILE"
    }
    update_streak
    streak_sessions=0
    streak_time=0
    grep "|launch" "$GTT_LIST" > /tmp/streak_games.txt
    while IFS='|' read -r disp rom_path emulator play_count total_time_entry time_disp action last_session; do
        if [ -n "$last_session" ]; then
            sess_date=$(date -d "@$last_session" +%Y-%m-%d)
            if [ "$sess_date" \>= "$start_date" ]; then
                streak_sessions=$((streak_sessions + 1))
                streak_time=$((streak_time + total_time_entry))
            fi
        fi
    done < /tmp/streak_games.txt
    rm -f /tmp/streak_games.txt
    streak_time_formatted=$(streak_format_time "$streak_time")
    line1="Streak Tracker"
    line2="Current: ${current_streak} days"
    line3="Record: ${longest_streak} days"
    line4="Sessions: ${streak_sessions}"
    line5="Play Time: ${streak_time_formatted}"
    line6="Start: ${start_date}"
    line7="$(get_motivation)"
    unified_msg="${line1}|${line2}|${line3}|${line4}|${line5}|${line6}|${line7}"
    ./show_message "$unified_msg" -l a
}

clear_stats() {
    result=$(./show_message "Clear All Data?|This will remove your entire game history and streak data.|Are you sure?" -l -a "YES" -b "NO")
    clear_status=$?
    if [ $clear_status -eq 0 ]; then
        echo "Game Time Tracker|__HEADER__|header" > "$GTT_LIST"
        STREAK_FILE="$(pwd)/.streak_data.txt"
        [ -f "$STREAK_FILE" ] && rm -f "$STREAK_FILE"
        ./show_message "All data cleared successfully." -l a
    fi
}

show_stats_menu() {
    while true; do
        stats_menu="/tmp/stats_menu.txt"
        cat > "$stats_menu" <<EOF
Overview|overview
Top Games|top_games
Top Systems|system_stats
Streaks|streaks
Export|export
Clear|clear
EOF
choice=$(./picker "$stats_menu" -b "BACK")
        status=$?
        rm -f "$stats_menu"
        if [ $status -ne 0 ] || [ -z "$choice" ]; then
            break
        fi
        option=$(echo "$choice" | cut -d'|' -f2)
        case $option in
            overview) display_overview ;;
            top_games) display_top_games ;;
            system_stats) display_system_stats ;;
            streaks) show_streak_menu ;;
            export) export_stats ;;
            clear) clear_stats ;;
        esac
    done
}

cleanup() {
    rm -f /tmp/gtt_*.txt
    rm -f options_list.txt
    rm -f /tmp/resume_slot.txt
    rm -f /tmp/stats_menu.txt
    rm -f /tmp/temp_sys.txt
    rm -f /tmp/top_games.txt
    rm -f /tmp/all_games.txt
    rm -f /tmp/sorted_systems.txt
    rm -f /tmp/top10_games.txt
    rm -f /tmp/all_games_export.txt
    rm -f /tmp/sorted_systems_export.txt
    rm -f /tmp/streak_games.txt
}
trap cleanup EXIT

menu_idx=0
while true; do
    picker_output=$(./picker "$GTT_LIST" -i $menu_idx -a "SELECT" -x "PLAY" -y "OPTIONS" -b "EXIT")
    picker_status=$?
    if [ -n "$picker_output" ]; then
        menu_idx=$(grep -n "^${picker_output%$'\n'}$" "$GTT_LIST" | cut -d: -f1 || echo "0")
        menu_idx=$((menu_idx - 1))
        [ $menu_idx -lt 0 ] && menu_idx=0
    fi
    
    [ $picker_status -eq 2 ] && cleanup && exit 0
    
    case $picker_status in
        0)
            if echo "$picker_output" | grep -q "^Game Time Tracker|"; then
                action=$(echo "$picker_output" | cut -d'|' -f3)
                if [ "$action" = "header" ]; then
                    if [ -x "$OPTIONS_DIR/show_stats.sh" ]; then
                        "$OPTIONS_DIR/show_stats.sh"
                    else
                        show_stats_menu
                    fi
                fi
            else
                action=$(echo "$picker_output" | cut -d'|' -f7)
                if [ "$action" = "launch" ]; then
                    show_game_details "$picker_output"
                fi
            fi
            ;;
        3)
            if echo "$picker_output" | grep -q "^Game Time Tracker|"; then
                :
            else
                action=$(echo "$picker_output" | cut -d'|' -f7)
                if [ "$action" = "launch" ]; then
                    rom_path=$(echo "$picker_output" | cut -d'|' -f2)
                    if [ -f "$rom_path" ]; then
                        launch_game "$rom_path"
                    else
                        ./show_message "Game file not found|$rom_path" -l a
                    fi
                fi
            fi
            ;;
        4)
            show_options_menu "$picker_output"
            ;;
        *)
            ;;
    esac
done
