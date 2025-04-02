#!/bin/sh
# gs_monitor.sh - Updated version with configurable hotkey, persistent ignore, and last.txt handling

# Set paths
DIR=$(dirname "$0")
LOG_FILE="$DIR/gs_monitor.log"
EVTEST="$DIR/evtest"
LAUNCH_SCRIPT="$DIR/launch.sh"
SCRIPT_NAME=$(basename "$0")
IGNORE_FILE="$DIR/ignore_hotkey.txt"

# Load hotkey configuration if available
if [ -f "$DIR/hotkey.conf" ]; then
    . "$DIR/hotkey.conf"
fi

# If HOTKEY is not set by hotkey.conf, set a default value
if [ -z "$HOTKEY" ]; then
    HOTKEY="F2"  # Default option; change here if desired.
fi

# Set the evtest hotkey pattern based on the HOTKEY option.
case "$HOTKEY" in
    MENU)
        # MENU button info:
        # Event: type 1 (EV_KEY), code 316 (BTN_MODE), value 1
        HOTKEY_PATTERN="code 316 (BTN_MODE), value 1"
        ;;
    L2)
        # L2 button info:
        # Event: type 3 (EV_ABS), code 2 (ABS_Z), value 255
        HOTKEY_PATTERN="code 2 (ABS_Z), value 255"
        ;;
    R2)
        # R2 button info:
        # Event: type 3 (EV_ABS), code 5 (ABS_RZ), value 255
        HOTKEY_PATTERN="code 5 (ABS_RZ), value 255"
        ;;
    F1)
        # F1 button info:
        # Event: type 1 (EV_KEY), code 317 (BTN_THUMBL), value 1
        HOTKEY_PATTERN="code 317 (BTN_THUMBL), value 1"
        ;;
    F2)
        # F2 button info:
        # Event: type 1 (EV_KEY), code 318 (BTN_THUMBR), value 1
        HOTKEY_PATTERN="code 318 (BTN_THUMBR), value 1"
        ;;
    *)
        echo "Invalid HOTKEY value: $HOTKEY" >> "$LOG_FILE"
        exit 1
        ;;
esac

echo "[$(date)] Selected hotkey option: $HOTKEY" >> "$LOG_FILE"
echo "[$(date)] Using hotkey pattern: $HOTKEY_PATTERN" >> "$LOG_FILE"

# Variable to track last execution time (for cooldown)
LAST_EXECUTION=0

# Function: Check if a game or tool is running (or within cooldown)
in_game_or_tool() {
    CURRENT_TIME=$(date +%s)
    if [ $((CURRENT_TIME - LAST_EXECUTION)) -lt 2 ]; then
        echo "[$(date)] Cooldown active – ignoring hotkey" >> "$LOG_FILE"
        return 0
    fi
    if ps | grep "/mnt/SDCARD/Roms" | grep -v "grep" > /dev/null; then
        echo "[$(date)] Game detected – ignoring hotkey" >> "$LOG_FILE"
        return 0
    fi
    
    # Modified tool detection to exclude LED-related processes
    if ps | grep "/mnt/SDCARD/Tools/tg5040" | grep -v "grep" | grep -v "$SCRIPT_NAME" | grep -v "(GS)" | grep -v "LED" | grep -v "led_" > /dev/null; then
        # Get the active tool for logging
        active_tool=$(ps | grep "/mnt/SDCARD/Tools/tg5040" | grep -v "grep" | grep -v "$SCRIPT_NAME" | grep -v "(GS)" | grep -v "LED" | grep -v "led_" | head -1)
        echo "[$(date)] Tool detected – ignoring hotkey: $active_tool" >> "$LOG_FILE"
        return 0
    fi
    
    return 1
}

# Function: Monitor for the hotkey event
monitor_hotkey() {
    while read -r line; do
        # If GS is active or persistent ignore file exists, skip processing.
        if [ -f /tmp/gs_active ] || [ -f "$IGNORE_FILE" ]; then
            continue
        fi

        # Check if the line contains our hotkey pattern
        if echo "$line" | grep -q "$HOTKEY_PATTERN"; then
            echo "[$(date)] Hotkey detected." >> "$LOG_FILE"
            if in_game_or_tool; then
                echo "[$(date)] Hotkey event ignored due to game/tool/cooldown." >> "$LOG_FILE"
            else
                echo "[$(date)] No game/tool active; launching Game Switcher." >> "$LOG_FILE"
                LAST_EXECUTION=$(date +%s)
                
                # Replace /tmp/last.txt with a blank version:
                if [ -f "$DIR/last.txt" ]; then
                    cp "$DIR/last.txt" "/tmp/last.txt"
                    echo "Replaced /tmp/last.txt with blank version" >> "$LOG_FILE"
                else
                    echo "" > "/tmp/last.txt"
                    echo "Created new blank /tmp/last.txt" >> "$LOG_FILE"
                fi

                if [ -f "$LAUNCH_SCRIPT" ]; then
                    cd "$DIR"
                    # Pass a flag to indicate we're launching from gs_monitor
                    GS_FROM_MONITOR=1 "$LAUNCH_SCRIPT" --from-monitor >> "$LOG_FILE" 2>&1 &
                else
                    echo "[$(date)] ERROR: launch.sh not found!" >> "$LOG_FILE"
                fi
            fi
            sleep 1  # Prevent rapid retriggering
        fi
    done
}

# Main process: Verify evtest exists and start monitoring input devices.
(
    if [ ! -f "$EVTEST" ]; then
        echo "[$(date)] ERROR: evtest not found at $EVTEST" >> "$LOG_FILE"
        echo "Please copy evtest to the script directory." >> "$LOG_FILE"
        exit 1
    fi

    # Kill any previous evtest processes to start clean.
    pkill -f "$EVTEST" > /dev/null 2>&1

    # Launch evtest on each input device and pipe its output to monitor_hotkey.
    for dev in /dev/input/event*; do
        [ -e "$dev" ] && "$EVTEST" "$dev" 2>/dev/null | monitor_hotkey &
    done

    echo "[$(date)] Monitoring all input devices for hotkey." >> "$LOG_FILE"

    # Keep the monitor alive indefinitely.
    while true; do
        sleep 60
        echo "[$(date)] Monitor still running." >> "$LOG_FILE"
    done
) &

exit 0