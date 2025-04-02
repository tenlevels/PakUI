#!/bin/sh

SCREEN_MODE="standard"
CURRENT_ROM="$1"
START_TIME=0
ACTION_FILE="/tmp/pico8_action"
SESSION_FILE="/mnt/SDCARD/Tools/$PLATFORM/Game Time Tracker.pak/current_session.txt"
LAST_SESSION_FILE="/mnt/SDCARD/Tools/$PLATFORM/Game Time Tracker.pak/last_session_duration.txt"
GTT_LIST="/mnt/SDCARD/Tools/$PLATFORM/Game Time Tracker.pak/gtt_list.txt"
PICO8_ROMS_FOLDER=$(find /mnt/SDCARD/Roms -maxdepth 1 -type d -name "*\(PICO-8\)*" | head -n 1)
if [ -z "$PICO8_ROMS_FOLDER" ]; then
  echo "PICO-8 roms folder not found."
  ./show_message "PICO-8 ROM folder not found|Check for a folder with (PICO-8) in name" -t 3
  exit 1
fi

PICO8_RES_FOLDER="$PICO8_ROMS_FOLDER/.res"
mkdir -p "$PICO8_RES_FOLDER"

export picodir=/mnt/SDCARD/Emus/$PLATFORM/PICO-8.pak/PICO8_Wrapper
cd "$picodir"
export PATH=$PATH:$PWD/bin
export HOME=$picodir
export PATH=${picodir}:$PATH
export LD_LIBRARY_PATH="$picodir/lib:/usr/lib:$LD_LIBRARY_PATH"

if [ ! -f "$picodir/bin/pico8_64" ] || [ ! -f "$picodir/bin/pico8.dat" ]; then
  if [ -f "/mnt/SDCARD/Bios/PICO8/pico8_64" ] && [ -f "/mnt/SDCARD/Bios/PICO8/pico8.dat" ]; then
    ./show_message "Copying PICO-8 files from Bios folder" -t 2
    mkdir -p "$picodir/bin"
    cp "/mnt/SDCARD/Bios/PICO8/pico8_64" "$picodir/bin/"
    cp "/mnt/SDCARD/Bios/PICO8/pico8.dat" "$picodir/bin/"
    chmod +x "$picodir/bin/pico8_64"
  else
    ./show_message "PICO-8 files are missing|Purchase them at lexaloffle.com|Put in /mnt/SDCARD/Bios/PICO8" -a "OK"
    exit 1
  fi
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUTO_RESUME_SCRIPT="$SCRIPT_DIR/auto_resume.sh"
SCREEN_MODE_FILE="$picodir/.screen_mode"
[ -f "$SCREEN_MODE_FILE" ] && SCREEN_MODE=$(cat "$SCREEN_MODE_FILE") || echo "$SCREEN_MODE" > "$SCREEN_MODE_FILE"

BITPAL_DIR="/mnt/SDCARD/Tools/$PLATFORM/BitPal.pak/bitpal_data"
BITPAL_ACTIVE_MISSIONS_DIR="$BITPAL_DIR/active_missions"
BITPAL_ACTIVE_MISSION="$BITPAL_DIR/active_mission.txt"
BITPAL_MISSION_ROM=""
BITPAL_MISSION_FILE=""
TRACK_BITPAL=0

format_cart_name() {
  local name="$1"
  name=$(echo "$name" | sed 's/\.p8\.png$//' | sed 's/\.p8$//')
  name=$(echo "$name" | sed 's/-[0-9]*$//' | sed 's/[0-9]*$//')
  
  if echo "$name" | grep -q "[-_]"; then
    local words=""
    local IFS='-_'
    for word in $name; do
      local first_char=$(echo "$word" | cut -c1 | tr '[:lower:]' '[:upper:]')
      local rest=$(echo "$word" | cut -c2-)
      words="$words$first_char$rest"
    done
    name="$words"
  else
    local first_char=$(echo "$name" | cut -c1 | tr '[:lower:]' '[:upper:]')
    local rest=$(echo "$name" | cut -c2-)
    name="$first_char$rest"
  fi
  
  echo "$name"
}

check_cart_exists() {
  local cart_name="$1"
  [ -f "$PICO8_ROMS_FOLDER/$cart_name.p8" ] && return 0
  [ -f "$PICO8_ROMS_FOLDER/$cart_name.p8.png" ] && return 0
  return 1
}

show_cart_list() {
  local cache_dir="$picodir/.lexaloffle/pico-8/bbs/carts"
  local output_file="/tmp/cached_carts.txt"
  
  > "$output_file"
  
  if [ ! -d "$cache_dir" ]; then
    mkdir -p "$cache_dir"
  fi
  
  local cart_count=$(find "$cache_dir" -maxdepth 1 -type f \( -name "*.p8" -o -name "*.p8.png" \) | wc -l)
  
  if [ "$cart_count" -eq 0 ]; then
    ./show_message "No carts found|Play games in Splore first" -t 3
    return
  fi
  
  find "$cache_dir" -maxdepth 1 -type f \( -name "*.p8" -o -name "*.p8.png" \) | sort | while read -r cart; do
    local cart_filename=$(basename "$cart")
    local display_name=$(format_cart_name "$cart_filename")
    echo "$display_name|$cart_filename" >> "$output_file"
  done
  
  while true; do
    picker_output=$(./picker "$output_file" -a "SELECT" -b "BACK" -t "Download Carts")
    picker_status=$?
    [ $picker_status = 2 ] && return
    
    local cart_option=$(echo "$picker_output" | cut -d'|' -f2)
    local cart_filename="$cart_option"
    local display_name=$(echo "$picker_output" | cut -d'|' -f1)
    local formatted_name=$(format_cart_name "$cart_filename")
    
    if check_cart_exists "$formatted_name"; then
      ./show_message "Cart already exists|Do you want to update?" -a "YES" -b "NO"
      update_status=$?
      [ $update_status = 2 ] && continue
    fi
    
    local source_file=""
    if [ -f "$cache_dir/$cart_filename" ]; then
      source_file="$cache_dir/$cart_filename"
    elif [ -f "$cache_dir/$cart_filename.p8" ]; then
      source_file="$cache_dir/$cart_filename.p8"
    elif [ -f "$cache_dir/$cart_filename.p8.png" ]; then
      source_file="$cache_dir/$cart_filename.p8.png"
    fi
    
    if [ -n "$source_file" ]; then
      cp "$source_file" "$PICO8_ROMS_FOLDER/$formatted_name.p8"
      chmod 644 "$PICO8_ROMS_FOLDER/$formatted_name.p8"
      
      if [[ "$source_file" == *.p8.png ]]; then
        cp "$source_file" "$PICO8_RES_FOLDER/$formatted_name.p8.png"
        chmod 644 "$PICO8_RES_FOLDER/$formatted_name.p8.png"
      else
        cp "$source_file" "$PICO8_RES_FOLDER/$formatted_name.p8.png"
        chmod 644 "$PICO8_RES_FOLDER/$formatted_name.p8.png"
      fi
      
      ./show_message "$formatted_name|Added to ROM folder" -t 2
    else
      ./show_message "$formatted_name|Cart not found" -t 2
    fi
  done
}

show_delete_cart_list() {
  local cache_dir="$picodir/.lexaloffle/pico-8/bbs/carts"
  local output_file="/tmp/delete_carts.txt"
  > "$output_file"
  
  # Add "Delete All" as the first option.
  echo "Delete All|delete_all" >> "$output_file"
  
  # List cart files from the cache (only *.p8 and *.p8.png).
  find "$cache_dir" -maxdepth 1 -type f \( -name "*.p8" -o -name "*.p8.png" \) | sort | while read -r cart; do
    local cart_filename=$(basename "$cart")
    local display_name=$(format_cart_name "$cart_filename")
    echo "$display_name|$cart_filename" >> "$output_file"
  done
  
  while true; do
    picker_output=$(./picker "$output_file" -a "SELECT" -b "BACK" -t "Delete Carts (Cache)")
    picker_status=$?
    [ $picker_status = 2 ] && return
    
    local selection=$(echo "$picker_output" | cut -d'|' -f2)
    
    if [ "$selection" = "delete_all" ]; then
      rm -f "$cache_dir"/*.p8
      rm -f "$cache_dir"/*.p8.png
      ./show_message "All cached carts deleted" -t 2
      return
    else
      rm -f "$cache_dir/$selection"
      local formatted_name=$(format_cart_name "$selection")
      ./show_message "$formatted_name deleted from cache" -t 2
      # Refresh the list after deletion.
      > "$output_file"
      echo "Delete All|delete_all" >> "$output_file"
      find "$cache_dir" -maxdepth 1 -type f \( -name "*.p8" -o -name "*.p8.png" \) | sort | while read -r cart; do
        local cart_filename=$(basename "$cart")
        local display_name=$(format_cart_name "$cart_filename")
        echo "$display_name|$cart_filename" >> "$output_file"
      done
    fi
  done
}

check_bitpal_missions() {
    local rom_path="$1"
    BITPAL_MISSION_ROM=""
    BITPAL_MISSION_FILE=""
    
    if is_splore "$rom_path"; then
        return 1
    fi
    
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

is_splore() {
  [ "$1" = "splore" ] && return 0
  [ -n "$1" ] && echo "$(basename "$1")" | grep -qi "splore"
}

update_auto_resume_script() {
  if is_splore "$1"; then
    sed -i "s|^ROM_PATH=.*|ROM_PATH=\"splore\"|" "$AUTO_RESUME_SCRIPT"
  else
    sed -i "s|^ROM_PATH=.*|ROM_PATH=\"$1\"|" "$AUTO_RESUME_SCRIPT"
  fi
}

remove_auto_resume_line() {
  local auto_sh_path="/mnt/SDCARD/.userdata/$PLATFORM/auto.sh"
  if [ -f "$auto_sh_path" ]; then
    sed -i '/auto_resume.sh/d' "$auto_sh_path"
  fi
}

add_to_auto_sh() {
  local f="/mnt/SDCARD/.userdata/$1/auto.sh"
  local w="$AUTO_RESUME_SCRIPT"
  [ ! -f "$f" ] && mkdir -p "$(dirname "$f")" && echo "#!/bin/sh" > "$f" && chmod +x "$f"
  grep -q "$w" "$f" || { [ -s "$f" ] && [ "$(tail -c 1 "$f" | xxd -p)" != "0a" ] && echo "" >> "$f"; echo "\"$w\"" >> "$f"; }
}

check_wifi_connectivity() {
  ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 ||
  ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 ||
  ping -c 1 -W 2 208.67.222.222 >/dev/null 2>&1 ||
  ping -c 1 -W 2 114.114.114.114 >/dev/null 2>&1 ||
  ping -c 1 -W 2 119.29.29.29 >/dev/null 2>&1
}

toggle_screen_mode() {
  SCREEN_MODE="$1"
  echo "$SCREEN_MODE" > "$SCREEN_MODE_FILE"
}

handle_orphan_sessions() {
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
          emulator="PICO-8"
          game_name=$(basename "$orphan_rom")
          game_name=$(echo "$game_name" | sed 's/([^)]*)//g' | sed 's/\.[^.]*$//' | tr '_' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^[0-9]\+[)\._ -]\+//')
          session_time=$orphan_elapsed
          hours=$((session_time / 3600))
          minutes=$(((session_time % 3600)/60))
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

  if [ -f "/mnt/SDCARD/Tools/$PLATFORM/BitPal.pak/current_session.txt" ]; then
    orphan_data=$(cat "/mnt/SDCARD/Tools/$PLATFORM/BitPal.pak/current_session.txt")
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
    
    rm -f "/mnt/SDCARD/Tools/$PLATFORM/BitPal.pak/current_session.txt"
  fi
}

update_gtt() {
  local r="$1"
  local session_duration=$2
  [ -z "$r" ] || is_splore "$r" && return
  [ ! -f "$r" ] && return
  
  if [ -f "$GTT_LIST" ]; then
    if grep -q "|$r|" "$GTT_LIST"; then
      local t="/tmp/gtt_update.txt"
      while IFS= read -r line; do
        if echo "$line" | grep -q "|$r|"; then
          local gn=$(echo "$line" | cut -d'|' -f1 | sed 's/^\[[^]]*\] //')
          local emu=$(echo "$line" | cut -d'|' -f3)
          local pc=$(echo "$line" | cut -d'|' -f4)
          local tt=$(echo "$line" | cut -d'|' -f5)
          pc=$((pc+1))
          local st=$session_duration
          tt=$((tt+st))
          local h=$((tt/3600))
          local m=$(((tt%3600)/60))
          local s=$((tt%60))
          if [ $h -gt 0 ]; then
            td="${h}h ${m}m"
          elif [ $m -gt 0 ]; then
            td="${m}m"
          else
            td="${s}s"
          fi
          local dn="[${td}] $gn"
          echo "$dn|$r|$emu|$pc|$tt|$td|launch|$st" >> "$t"
        else
          echo "$line" >> "$t"
        fi
      done < "$GTT_LIST"
      mv "$t" "$GTT_LIST"
    else
      local gn=$(basename "$r" | sed 's/([^)]*)//g; s/\.[^.]*$//; s/_/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//; s/^[0-9]\+[)\._ -]\+//')
      local st=$session_duration
      local h=$((st/3600))
      local m=$(((st%3600)/60))
      local s=$((st%60))
      if [ $h -gt 0 ]; then
        td="${h}h ${m}m"
      elif [ $m -gt 0 ]; then
        td="${m}m"
      else
        td="${s}s"
      fi
      local t="/tmp/gtt_list_temp.txt"
      local hl=$(head -n 1 "$GTT_LIST")
      echo "$hl" > "$t"
      local dn="[${td}] $gn"
      echo "$dn|$r|PICO-8|1|$st|$td|launch|$st" >> "$t"
      tail -n +2 "$GTT_LIST" >> "$t"
      mv "$t" "$GTT_LIST"
    fi
    local u="/tmp/gtt_sorted.txt"
    local hline=$(head -n 1 "$GTT_LIST")
    echo "$hline" > "$u"
    tail -n +2 "$GTT_LIST" | sort -t'|' -k5,5nr >> "$u"
    mv "$u" "$GTT_LIST"
  elif [ -d "/mnt/SDCARD/Tools/$PLATFORM/Game Time Tracker.pak" ]; then
    mkdir -p "$(dirname "$GTT_LIST")"
    echo "Game Time Tracker|__HEADER__|header" > "$GTT_LIST"
    local gn=$(basename "$r" | sed 's/([^)]*)//g; s/\.[^.]*$//; s/_/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//; s/^[0-9]\+[)\._ -]\+//')
    local st=$session_duration
    local h=$((st/3600))
    local m=$(((st%3600)/60))
    local s=$((st%60))
    if [ $h -gt 0 ]; then
      td="${h}h ${m}m"
    elif [ $m -gt 0 ]; then
      td="${m}m"
    else
      td="${s}s"
    fi
    local dn="[${td}] $gn"
    echo "$dn|$r|PICO-8|1|$st|$td|launch|$st" >> "$GTT_LIST"
  fi
  
  echo "$session_duration" > "$LAST_SESSION_FILE"
}

update_bitpal_mission() {
  local session_duration=$1
  
  if [ "$TRACK_BITPAL" -eq 1 ]; then
    echo "$session_duration" > "/mnt/SDCARD/Tools/$PLATFORM/BitPal.pak/last_session_duration.txt"
    
    if [ -f "$BITPAL_MISSION_FILE" ]; then
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
  fi
}

show_main_menu() {
  local menu_file="/tmp/main_menu.txt"
  > "$menu_file"
  
  echo "Resume Game|resume" >> "$menu_file"
  echo "Restart Game|restart" >> "$menu_file"
  echo "Open Splore|splore" >> "$menu_file"
  echo "Download Carts|download_carts" >> "$menu_file"
  echo "Delete Carts|delete_carts" >> "$menu_file"
  if [ "$SCREEN_MODE" = "standard" ]; then
    echo "Switch to Widescreen|switch_wide" >> "$menu_file"
  else
    echo "Switch to Square Mode|switch_std" >> "$menu_file"
  fi
  echo "Exit to MinUI|exit" >> "$menu_file"
  
  picker_output=$(./picker "$menu_file" -a "SELECT" -b "BACK")
  picker_status=$?
  [ $picker_status = 2 ] && return "cancel"
  
  local option=$(echo "$picker_output" | cut -d'|' -f2)
  echo "$option"
}

start_game() {
  handle_orphan_sessions
  
  echo "" > "$ACTION_FILE"
  START_TIME=$(date +%s)
  
  TRACK_BITPAL=0
  check_bitpal_missions "$1"
  if [ -n "$BITPAL_MISSION_ROM" ]; then
    BITPAL_SESSION_FILE="/mnt/SDCARD/Tools/$PLATFORM/BitPal.pak/current_session.txt"
    TRACK_BITPAL=1
  fi
  
  update_auto_resume_script "$1"
  remove_auto_resume_line
  
  (
    while true; do
      curr_time=$(date +%s)
      elapsed=$((curr_time - START_TIME))
      echo "$1|$elapsed" > "$SESSION_FILE"
      if [ "$TRACK_BITPAL" -eq 1 ]; then
        echo "$1|$elapsed" > "$BITPAL_SESSION_FILE"
      fi
      sleep 10
    done
  ) &
  BG_PID=$!
  
  echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
  mount --bind "$PICO8_ROMS_FOLDER" /mnt/SDCARD/Emus/$PLATFORM/PICO-8.pak/PICO8_Wrapper/.lexaloffle/pico-8/carts
  if [ "$SCREEN_MODE" = "widescreen" ]; then
    local geo="$(fbset | grep 'geometry' | awk '{print $2,$3}')"
    local w="$(echo "$geo" | awk '{print $1}')"
    local h="$(echo "$geo" | awk '{print $2}')"
    DRAW_RECT="-draw_rect 0,0,${w},${h}"
  else
    DRAW_RECT=""
  fi
  local rom="$1"
  if is_splore "$rom"; then
    if ! check_wifi_connectivity; then
      ./show_message "No WiFi connection|Turn on WiFi for Splore" -t 2
    fi
    pico8_64 -preblit_scale 3 -splore $DRAW_RECT &
  else
    if [ -n "$rom" ]; then
      pico8_64 -preblit_scale 3 -run "$rom" -root_path "$(dirname "$rom")" $DRAW_RECT &
    else
      local c="$(find /mnt/SDCARD/Roms/*\(PICO\) -type f \( -name '*.p8' -o -name '*.p8.png' \) | head -n 1)"
      [ -z "$c" ] && exit 1
      pico8_64 -preblit_scale 3 -run "$c" -root_path "$(dirname "$c")" $DRAW_RECT &
      CURRENT_ROM="$c"
    fi
  fi
  GAME_PID=$!

  (
    local evp="/dev/input/event1"
    while kill -0 "$GAME_PID" 2>/dev/null; do
      if timeout 0.04s "$SCRIPT_DIR/evtest" "$evp" 2>/dev/null | grep "code 116 (KEY_POWER)" | grep -q "value 1"; then
        kill -9 "$GAME_PID"
        sleep 0.5
        ./show_message "Powering off" -t 1
        if is_splore "$CURRENT_ROM"; then
          update_auto_resume_script "splore"
        else
          update_auto_resume_script "$CURRENT_ROM"
        fi
        add_to_auto_sh "$PLATFORM"
        
        END_TIME=$(date +%s)
        SESSION_DURATION=$((END_TIME - START_TIME))
        
        kill $BG_PID 2>/dev/null
        rm -f "$SESSION_FILE"
        if [ "$TRACK_BITPAL" -eq 1 ]; then
          rm -f "$BITPAL_SESSION_FILE"
        fi
        
        update_gtt "$CURRENT_ROM" "$SESSION_DURATION"
        update_bitpal_mission "$SESSION_DURATION"
        
        sync
        poweroff
        break
      fi
      sleep 0.02
    done
  ) &
  POWER_MONITOR_PID=$!

  (
    local evm="/dev/input/event3"
    while kill -0 "$GAME_PID" 2>/dev/null; do
      if timeout 0.04s "$SCRIPT_DIR/evtest" "$evm" 2>/dev/null | grep "code 316 (BTN_MODE)" | grep -q "value 1"; then
        kill -STOP "$GAME_PID"
        
        while true; do
          menu_choice=$(show_main_menu)
          
          if [ "$menu_choice" = "cancel" ]; then
            kill -CONT "$GAME_PID"
            break
          fi
          
          case "$menu_choice" in
            resume)
              kill -CONT "$GAME_PID"
              break
              ;;
            restart)
              echo "restart" > "$ACTION_FILE"
              kill -9 "$GAME_PID"
              break
              ;;
            splore)
              echo "splore" > "$ACTION_FILE"
              kill -9 "$GAME_PID"
              break
              ;;
            download_carts)
              show_cart_list
              ;;
            delete_carts)
              show_delete_cart_list
              ;;
            switch_wide)
              echo "switch_wide" > "$ACTION_FILE"
              kill -9 "$GAME_PID"
              break
              ;;
            switch_std)
              echo "switch_std" > "$ACTION_FILE"
              kill -9 "$GAME_PID"
              break
              ;;
            exit)
              echo "exit" > "$ACTION_FILE"
              kill -9 "$GAME_PID"
              break
              ;;
            *)
              kill -CONT "$GAME_PID"
              break
              ;;
          esac
        done
      fi
      sleep 0.02
    done
  ) &
  MENU_MONITOR_PID=$!

  while kill -0 "$GAME_PID" 2>/dev/null; do
    sleep 0.1
  done
  
  END_TIME=$(date +%s)
  SESSION_DURATION=$((END_TIME - START_TIME))
  
  kill "$POWER_MONITOR_PID" 2>/dev/null
  kill "$MENU_MONITOR_PID" 2>/dev/null
  kill $BG_PID 2>/dev/null
  
  rm -f "$SESSION_FILE"
  if [ "$TRACK_BITPAL" -eq 1 ]; then
    rm -f "$BITPAL_SESSION_FILE"
  fi
  
  update_gtt "$CURRENT_ROM" "$SESSION_DURATION"
  update_bitpal_mission "$SESSION_DURATION"
  
  umount /mnt/SDCARD/Emus/$PLATFORM/PICO-8.pak/PICO8_Wrapper/.lexaloffle/pico-8/carts 2>/dev/null
  echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
}

while true; do
  rm -f "$ACTION_FILE"
  start_game "$CURRENT_ROM"
  ACTION="$(cat "$ACTION_FILE" 2>/dev/null)"
  [ -z "$ACTION" ] && ACTION="none"
  case "$ACTION" in
    restart)
      ;;
    splore)
      CURRENT_ROM="splore"
      ;;
    switch_wide)
      toggle_screen_mode "widescreen"
      ;;
    switch_std)
      toggle_screen_mode "standard"
      ;;
    exit)
      break
      ;;
    none)
      break
      ;;
  esac
done
exit 0
