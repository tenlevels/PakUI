#!/bin/sh

TEMP_MENU="/tmp/capture_menu.txt"
SCREENSHOTS_MENU="/tmp/screenshots_menu.txt"
RECORDINGS_MENU="/tmp/recordings_menu.txt"
SCREENSHOT_OPTIONS="/tmp/screenshot_options_menu.txt"
RECORDING_OPTIONS="/tmp/recording_options_menu.txt"
BUTTON_LOG="/tmp/capture_button_log.txt"
MANAGE_MENU="/tmp/manage_menu.txt"
QUALITY_MENU="/tmp/quality_menu.txt"
PID_FILE="/tmp/screen_capture_pids.txt"
BUTTON_WATCHERS="/tmp/button_watchers_pids.txt"
SCREENSHOTS_DIR="/mnt/SDCARD/Screenshots"
RECORDINGS_DIR="/mnt/SDCARD/Screenrecorder"

DIR="$(dirname "$0")"
cd "$DIR"

export LD_LIBRARY_PATH="$DIR/.lib:$LD_LIBRARY_PATH"

PICKER="./picker"
SHOW_MESSAGE="./show_message"
EV="./evtest"
SCREENCAP="./screencap"
FFMPEG="./ffmpeg"
SHOW_ELF="./show.elf"
KEYBOARD="./keyboard"

trap 'rm -f "$TEMP_MENU" "$SCREENSHOTS_MENU" "$RECORDINGS_MENU" "$SCREENSHOT_OPTIONS" "$RECORDING_OPTIONS" "$BUTTON_LOG" "$MANAGE_MENU" "$QUALITY_MENU" "$BUTTON_WATCHERS"' EXIT

mkdir -p "$SCREENSHOTS_DIR" "$RECORDINGS_DIR"
[ -f "$PID_FILE" ] || touch "$PID_FILE"

VIDEO_OPTS=""
FRAMERATE="-framerate 30"

REC_FLAG="$DIR/recording_active.flag"
REC_PID="$DIR/recording_pid.txt"

rename_file() {
  local oldpath="$1"
  local dir="$(dirname "$oldpath")"
  local oldbase="$(basename "$oldpath")"
  local oldext="${oldbase##*.}"
  "$SHOW_MESSAGE" "Enter New Name|Will keep .$oldext extension" -l a
  local raw="$("$KEYBOARD" minui.ttf)"
  [ $? -ne 0 ] && return 1
  [ -z "$raw" ] && return 1
  local newbase="$raw"
  local newpath="$dir/$newbase.$oldext"
  if [ -e "$newpath" ]; then
    "$SHOW_MESSAGE" "A file named '$newbase.$oldext' already exists" -l a
    return 1
  fi
  if mv "$oldpath" "$newpath" 2>/dev/null; then
    "$SHOW_MESSAGE" "Renamed to|$newbase.$oldext" -l a
    if echo "$oldpath" | grep -q "$SCREENSHOTS_DIR"; then
      > "$SCREENSHOTS_MENU"
      echo "Screenshots|__HEADER__|header" >> "$SCREENSHOTS_MENU"
      ls -t "$SCREENSHOTS_DIR"/*.png 2>/dev/null | while read -r p; do
        local x
        x="$(basename "$p")"
        echo "$x|$p|view" >> "$SCREENSHOTS_MENU"
      done
    elif echo "$oldpath" | grep -q "$RECORDINGS_DIR"; then
      > "$RECORDINGS_MENU"
      echo "Recordings|__HEADER__|header" >> "$RECORDINGS_MENU"
      ls -t "$RECORDINGS_DIR"/*.mp4 2>/dev/null | while read -r p; do
        local x
        x="$(basename "$p")"
        echo "$x|$p|play" >> "$RECORDINGS_MENU"
      done
    fi
    return 0
  else
    "$SHOW_MESSAGE" "Rename Failed" -l a
    return 1
  fi
}

screenshot_mode() {
  local l2=0 r2=0
  for dev in /dev/input/event*; do
    [ -e "$dev" ] || continue
    "$EV" "$dev" 2>&1 | while read -r line; do
      if echo "$line" | grep -q "type 3 (EV_ABS), code 5.*value 255"; then
        l2=1
      elif echo "$line" | grep -q "type 3 (EV_ABS), code 2.*value 255"; then
        r2=1
      elif echo "$line" | grep -q "type 3 (EV_ABS), code [25].*value 0"; then
        l2=0
        r2=0
      fi
      if [ $l2 -eq 1 ] && [ $r2 -eq 1 ]; then
        local prefix="MinUI"
        if pgrep "minarch.elf" >/dev/null 2>&1 || \
           pgrep "mupen64plus" >/dev/null 2>&1 || \
           pgrep "drastic"    >/dev/null 2>&1 || \
           pgrep "PPSSPPSDL"  >/dev/null 2>&1
        then
          [ -f "/mnt/SDCARD/.userdata/shared/.minui/recent.txt" ] && prefix="$(head -n1 "/mnt/SDCARD/.userdata/shared/.minui/recent.txt" | cut -f2)"
        fi
        "$SCREENCAP" "$SCREENSHOTS_DIR/${prefix}_$(date +%m%d%y_%H%M%S).png"
        l2=0
        r2=0
      fi
    done &
    echo $! >> "$PID_FILE"
  done
}

recording_mode() {
  local l2=0 r2=0
  for dev in /dev/input/event*; do
    [ -e "$dev" ] || continue
    "$EV" "$dev" 2>&1 | while read -r line; do
      if echo "$line" | grep -q "type 3 (EV_ABS), code 5.*value 255"; then
        l2=1
      elif echo "$line" | grep -q "type 3 (EV_ABS), code 2.*value 255"; then
        r2=1
      elif echo "$line" | grep -q "type 3 (EV_ABS), code [25].*value 0"; then
        l2=0
        r2=0
      fi
      if [ $l2 -eq 1 ] && [ $r2 -eq 1 ]; then
        if [ ! -f "$REC_FLAG" ]; then
          local prefix="MinUI"
          if pgrep "minarch.elf" >/dev/null 2>&1 || \
             pgrep "mupen64plus" >/dev/null 2>&1 || \
             pgrep "drastic"    >/dev/null 2>&1 || \
             pgrep "PPSSPPSDL"  >/dev/null 2>&1
          then
            [ -f "/mnt/SDCARD/.userdata/shared/.minui/recent.txt" ] && prefix="$(head -n1 "/mnt/SDCARD/.userdata/shared/.minui/recent.txt" | cut -f2)"
          fi
          touch "$REC_FLAG"
          "$FFMPEG" -f fbdev -i /dev/fb0 $FRAMERATE $VIDEO_OPTS \
            "$RECORDINGS_DIR/${prefix}_$(date +%m%d%y_%H%M%S).mp4" &
          echo $! > "$REC_PID"
        else
          if [ -f "$REC_PID" ]; then
            kill -TERM "$(cat "$REC_PID")"
            rm -f "$REC_PID"
          fi
          rm -f "$REC_FLAG"
        fi
        l2=0
        r2=0
      fi
    done &
    echo $! >> "$PID_FILE"
  done
}

stop_all_modes() {
  if [ -f "$REC_FLAG" ]; then
    if [ -f "$REC_PID" ]; then
      kill -TERM "$(cat "$REC_PID")" 2>/dev/null
      rm -f "$REC_PID"
    fi
    rm -f "$REC_FLAG"
    sleep 1
  fi
  if [ -f "$PID_FILE" ]; then
    while read -r pid; do
      [ -n "$pid" ] && kill "$pid" 2>/dev/null
    done < "$PID_FILE"
    killall -9 ffmpeg 2>/dev/null
    killall -9 evtest 2>/dev/null
    rm -f "$PID_FILE"
    touch "$PID_FILE"
    "$SHOW_MESSAGE" "All capture modes disabled" -l a
  else
    "$SHOW_MESSAGE" "No active capture modes found" -l a
  fi
}

monitor_buttons_for_viewer() {
  rm -f "$BUTTON_WATCHERS"
  > "$BUTTON_LOG"
  for dev in /dev/input/event*; do
    [ -e "$dev" ] || continue
    "$EV" "$dev" 2>&1 | while read -r ln; do
      if   echo "$ln" | grep -q "code 304 (BTN_SOUTH).*value 1"; then echo "BTN_SOUTH" >> "$BUTTON_LOG"
      elif echo "$ln" | grep -q "code 305 (BTN_EAST).*value 1";  then echo "BTN_EAST"  >> "$BUTTON_LOG"
      elif echo "$ln" | grep -q "code 16 (ABS_HAT0X).*value";    then echo "D_PAD"     >> "$BUTTON_LOG"
      elif echo "$ln" | grep -q "code 17 (ABS_HAT0Y).*value";    then echo "D_PAD"     >> "$BUTTON_LOG"
      elif echo "$ln" | grep -q "code 1 (ABS_Y).*value";         then echo "BUTTON"    >> "$BUTTON_LOG"
      elif echo "$ln" | grep -q "code 0 (ABS_X).*value";         then echo "BUTTON"    >> "$BUTTON_LOG"
      fi
    done &
    echo $! >> "$BUTTON_WATCHERS"
  done
}

kill_viewer_watchers() {
  if [ -f "$BUTTON_WATCHERS" ]; then
    while read -r wpid; do
      kill "$wpid" 2>/dev/null
    done < "$BUTTON_WATCHERS"
    rm -f "$BUTTON_WATCHERS"
  fi
}

delete_screenshot() {
  local f="$1"
  local n
  n="$(basename "$f")"
  "$SHOW_MESSAGE" "Delete Screenshot?|$n" -l ab -a "YES" -b "NO"
  [ $? -eq 0 ] && rm -f "$f" && "$SHOW_MESSAGE" "Screenshot Deleted" -l a && return 0
  return 1
}

delete_recording() {
  local f="$1"
  local n
  n="$(basename "$f")"
  "$SHOW_MESSAGE" "Delete Recording?|$n" -l ab -a "YES" -b "NO"
  [ $? -eq 0 ] && rm -f "$f" && "$SHOW_MESSAGE" "Recording Deleted" -l a && return 0
  return 1
}

view_screenshots() {
  local c
  c="$(ls -1 "$SCREENSHOTS_DIR"/*.png 2>/dev/null | wc -l)"
  [ "$c" -eq 0 ] && "$SHOW_MESSAGE" "No screenshots found" -l a && return
  > "$SCREENSHOTS_MENU"
  echo "Screenshots|__HEADER__|header" >> "$SCREENSHOTS_MENU"
  ls -t "$SCREENSHOTS_DIR"/*.png 2>/dev/null | while read -r path; do
    local n
    n="$(basename "$path")"
    echo "$n|$path|view" >> "$SCREENSHOTS_MENU"
  done
  local idx=0
  while true; do
    local sel st
    sel="$("$PICKER" "$SCREENSHOTS_MENU" -i $idx -a "VIEW" -b "BACK" -y "OPTIONS")"
    st=$?
    [ -n "$sel" ] && idx="$(grep -n "^$sel$" "$SCREENSHOTS_MENU" | cut -d: -f1 || echo "0")"; idx=$((idx - 1))
    [ $idx -lt 0 ] && idx=0
    [ $st -eq 1 ] || [ -z "$sel" ] && break
    local file act
    file="$(echo "$sel" | cut -d'|' -f2)"
    act="$(echo "$sel" | cut -d'|' -f3)"
    if [ $st -eq 4 ]; then
      > "$SCREENSHOT_OPTIONS"
      echo "Delete Screenshot|delete|action" >> "$SCREENSHOT_OPTIONS"
      echo "Rename Screenshot|rename|action" >> "$SCREENSHOT_OPTIONS"
      echo "View Screenshot|view|action" >> "$SCREENSHOT_OPTIONS"
      local opt
      opt="$("$PICKER" "$SCREENSHOT_OPTIONS" -a "OK" -b "BACK")"
      [ $? -eq 0 ] && case "$(echo "$opt" | cut -d'|' -f2)" in
        delete)
          if delete_screenshot "$file"; then
            > "$SCREENSHOTS_MENU"
            echo "Screenshots|__HEADER__|header" >> "$SCREENSHOTS_MENU"
            ls -t "$SCREENSHOTS_DIR"/*.png 2>/dev/null | while read -r p; do
              local x
              x="$(basename "$p")"
              echo "$x|$p|view" >> "$SCREENSHOTS_MENU"
            done
            [ "$(ls -1 "$SCREENSHOTS_DIR"/*.png 2>/dev/null | wc -l)" -eq 0 ] && break
          fi
        ;;
        rename)
          if rename_file "$file"; then
            > "$SCREENSHOTS_MENU"
            echo "Screenshots|__HEADER__|header" >> "$SCREENSHOTS_MENU"
            ls -t "$SCREENSHOTS_DIR"/*.png 2>/dev/null | while read -r p; do
              local x
              x="$(basename "$p")"
              echo "$x|$p|view" >> "$SCREENSHOTS_MENU"
            done
          fi
        ;;
        view)
          killall show.elf 2>/dev/null
          monitor_buttons_for_viewer
          "$SHOW_ELF" "$file" &
          while true; do
            if grep -q "BTN_SOUTH\|BTN_EAST\|D_PAD\|BUTTON" "$BUTTON_LOG"; then
              killall show.elf 2>/dev/null
              kill_viewer_watchers
              break
            fi
            sleep 0.1
          done
        ;;
      esac
    elif [ $st -eq 0 ]; then
      case "$act" in
        header)
          "$SHOW_MESSAGE" "Screenshots Gallery|Select a screenshot to view it" -l a
        ;;
        view)
          killall show.elf 2>/dev/null
          monitor_buttons_for_viewer
          "$SHOW_ELF" "$file" &
          while true; do
            if grep -q "BTN_SOUTH\|BTN_EAST\|D_PAD\|BUTTON" "$BUTTON_LOG"; then
              killall show.elf 2>/dev/null
              kill_viewer_watchers
              break
            fi
            sleep 0.1
          done
        ;;
      esac
    fi
  done
}

view_recordings() {
  local c
  c="$(ls -1 "$RECORDINGS_DIR"/*.mp4 2>/dev/null | wc -l)"
  [ "$c" -eq 0 ] && "$SHOW_MESSAGE" "No recordings found" -l a && return
  > "$RECORDINGS_MENU"
  echo "Recordings|__HEADER__|header" >> "$RECORDINGS_MENU"
  ls -t "$RECORDINGS_DIR"/*.mp4 2>/dev/null | while read -r path; do
    local n
    n="$(basename "$path")"
    echo "$n|$path|play" >> "$RECORDINGS_MENU"
  done
  local idx=0
  while true; do
    local sel st
    sel="$("$PICKER" "$RECORDINGS_MENU" -i $idx -a "PLAY" -b "BACK" -y "OPTIONS")"
    st=$?
    [ -n "$sel" ] && idx="$(grep -n "^$sel$" "$RECORDINGS_MENU" | cut -d: -f1 || echo "0")"; idx=$((idx - 1))
    [ $idx -lt 0 ] && idx=0
    [ $st -eq 1 ] || [ -z "$sel" ] && break
    local file act
    file="$(echo "$sel" | cut -d'|' -f2)"
    act="$(echo "$sel" | cut -d'|' -f3)"
    if [ $st -eq 4 ]; then
      > "$RECORDING_OPTIONS"
      echo "Delete Recording|delete|action" >> "$RECORDING_OPTIONS"
      echo "Rename Recording|rename|action" >> "$RECORDING_OPTIONS"
      echo "Play Recording|play|action" >> "$RECORDING_OPTIONS"
      local opt
      opt="$("$PICKER" "$RECORDING_OPTIONS" -a "OK" -b "BACK")"
      [ $? -eq 0 ] && case "$(echo "$opt" | cut -d'|' -f2)" in
        delete)
          if delete_recording "$file"; then
            > "$RECORDINGS_MENU"
            echo "Recordings|__HEADER__|header" >> "$RECORDINGS_MENU"
            ls -t "$RECORDINGS_DIR"/*.mp4 2>/dev/null | while read -r p; do
              local x
              x="$(basename "$p")"
              echo "$x|$p|play" >> "$RECORDINGS_MENU"
            done
            [ "$(ls -1 "$RECORDINGS_DIR"/*.mp4 2>/dev/null | wc -l)" -eq 0 ] && break
          fi
        ;;
        rename)
          if rename_file "$file"; then
            > "$RECORDINGS_MENU"
            echo "Recordings|__HEADER__|header" >> "$RECORDINGS_MENU"
            ls -t "$RECORDINGS_DIR"/*.mp4 2>/dev/null | while read -r x; do
              local y
              y="$(basename "$x")"
              echo "$y|$x|play" >> "$RECORDINGS_MENU"
            done
          fi
        ;;
        play)
          "$SHOW_MESSAGE" "Playing Video...|Please wait" -t 1
          /mnt/SDCARD/Emus/"$PLATFORM"/MPV.pak/launch.sh "$file"
        ;;
      esac
    elif [ $st -eq 0 ]; then
      case "$act" in
        header)
          "$SHOW_MESSAGE" "Recordings Gallery|Select a recording to play" -l a
        ;;
        play)
          "$SHOW_MESSAGE" "Playing Video...|Please wait" -t 1
          /mnt/SDCARD/Emus/"$PLATFORM"/MPV.pak/launch.sh "$file"
        ;;
      esac
    fi
  done
}

choose_recording_quality() {
  > "$QUALITY_MENU"
  echo "Low (1Mbps)|low|action" >> "$QUALITY_MENU"
  echo "Medium (2Mbps)|medium|action" >> "$QUALITY_MENU"
  echo "High (3Mbps)|high|action" >> "$QUALITY_MENU"
  local sel
  sel="$("$PICKER" "$QUALITY_MENU" -a "SELECT" -b "BACK")"
  [ $? -ne 0 ] && return 1
  local c
  c="$(echo "$sel" | cut -d'|' -f2)"
  case "$c" in
    low)    VIDEO_OPTS="-b:v 1000k"; FRAMERATE="-framerate 30" ;;
    medium) VIDEO_OPTS="-b:v 2000k"; FRAMERATE="-framerate 30" ;;
    high)   VIDEO_OPTS="-b:v 3000k"; FRAMERATE="-framerate 30" ;;
    *) return 1 ;;
  esac
  return 0
}

delete_all_screenshots() {
  local n
  n="$(ls -1 "$SCREENSHOTS_DIR"/*.png 2>/dev/null | wc -l)"
  [ "$n" -eq 0 ] && "$SHOW_MESSAGE" "No screenshots to delete" -l a && return
  "$SHOW_MESSAGE" "Delete ALL Screenshots?|This will remove $n screenshots.|Are you sure?" -l ab -a "YES" -b "NO"
  [ $? -eq 0 ] && rm -f "$SCREENSHOTS_DIR"/*.png && "$SHOW_MESSAGE" "All Screenshots Deleted" -l a
}

delete_all_recordings() {
  local n
  n="$(ls -1 "$RECORDINGS_DIR"/*.mp4 2>/dev/null | wc -l)"
  [ "$n" -eq 0 ] && "$SHOW_MESSAGE" "No recordings to delete" -l a && return
  "$SHOW_MESSAGE" "Delete ALL Recordings?|This will remove $n recordings.|Are you sure?" -l ab -a "YES" -b "NO"
  [ $? -eq 0 ] && rm -f "$RECORDINGS_DIR"/*.mp4 && "$SHOW_MESSAGE" "All Recordings Deleted" -l a
}

show_management_menu() {
  > "$MANAGE_MENU"
  echo "Delete All Screenshots|del_ss|action" >> "$MANAGE_MENU"
  echo "Delete All Recordings|del_rec|action" >> "$MANAGE_MENU"
  local sel
  sel="$("$PICKER" "$MANAGE_MENU" -a "SELECT" -b "BACK")"
  [ $? -eq 0 ] && case "$(echo "$sel" | cut -d'|' -f2)" in
    del_ss) delete_all_screenshots ;;
    del_rec) delete_all_recordings ;;
  esac
}

count_screenshots() { ls -1 "$SCREENSHOTS_DIR"/*.png 2>/dev/null | wc -l; }
count_recordings()  { ls -1 "$RECORDINGS_DIR"/*.mp4 2>/dev/null | wc -l; }

update_main_menu() {
  echo "Screen Capture|__HEADER__|header" > "$TEMP_MENU"
  echo "Enable Screenshot Mode|screenshot|action" >> "$TEMP_MENU"
  echo "Enable Recording Mode|record|action" >> "$TEMP_MENU"
  echo "View Screenshots ($(count_screenshots))|view_ss|action" >> "$TEMP_MENU"
  echo "View Recordings ($(count_recordings))|view_rec|action" >> "$TEMP_MENU"
  echo "Manage Files|manage|action" >> "$TEMP_MENU"
  echo "Disable All Capture Modes|stop|action" >> "$TEMP_MENU"
}

update_main_menu
IDX=0

while true; do
  SEL="$("$PICKER" "$TEMP_MENU" -i $IDX -a "SELECT" -b "EXIT")"
  ST=$?
  [ -n "$SEL" ] && IDX="$(grep -n "^$SEL$" "$TEMP_MENU" | cut -d: -f1 || echo "0")"; IDX=$((IDX - 1))
  [ $IDX -lt 0 ] && IDX=0
  [ $ST -eq 1 ] || [ -z "$SEL" ] && exit 0
  ACT="$(echo "$SEL" | cut -d'|' -f2)"
  case "$ACT" in
    header)
      "$SHOW_MESSAGE" "Screen Capture Tool|SCREENSHOT: L2+R2|RECORDING: L2+R2" -l a
    ;;
    screenshot)
      "$SHOW_MESSAGE" "Screenshot Mode Enabled|Press L2+R2 to capture" -l a
      screenshot_mode
    ;;
    record)
      if choose_recording_quality; then
        "$SHOW_MESSAGE" "Recording Mode Enabled|Press L2+R2 to start/stop" -l a
        recording_mode
      fi
    ;;
    view_ss)
      stop_all_modes
      view_screenshots
      update_main_menu
    ;;
    view_rec)
      stop_all_modes
      view_recordings
      update_main_menu
    ;;
    manage)
      stop_all_modes
      show_management_menu
      update_main_menu
    ;;
    stop)
      stop_all_modes
    ;;
  esac
done