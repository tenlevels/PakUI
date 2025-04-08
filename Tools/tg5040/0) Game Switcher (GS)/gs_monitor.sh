#!/bin/sh

DIR=$(dirname "$0")
EVTEST="$DIR/evtest"
LAUNCH_SCRIPT="$DIR/launch.sh"
SCRIPT_NAME=$(basename "$0")
IGNORE_FILE="$DIR/ignore_hotkey.txt"

if [ -f "$DIR/hotkey.conf" ]; then
    . "$DIR/hotkey.conf"
fi

if [ -z "$HOTKEY" ]; then
    HOTKEY="F2"
fi

case "$HOTKEY" in
    SELECT)
        HOTKEY_PATTERN="code 314 (BTN_SELECT), value 1"
        ;;
    START)
        HOTKEY_PATTERN="code 315 (BTN_START), value 1"
        ;;
    L2)
        HOTKEY_PATTERN="code 2 (ABS_Z), value 255"
        ;;
    R2)
        HOTKEY_PATTERN="code 5 (ABS_RZ), value 255"
        ;;
    F1)
        HOTKEY_PATTERN="code 317 (BTN_THUMBL), value 1"
        ;;
    F2)
        HOTKEY_PATTERN="code 318 (BTN_THUMBR), value 1"
        ;;
    *)
        exit 1
        ;;
esac

LAST_EXECUTION=0

in_game_or_tool() {
    CURRENT_TIME=$(date +%s)
    if [ $((CURRENT_TIME - LAST_EXECUTION)) -lt 2 ]; then
        return 0
    fi
    if ps | grep "/mnt/SDCARD/Roms" | grep -v "grep" > /dev/null; then
        return 0
    fi
    
    if ps | grep "/mnt/SDCARD/Tools/tg5040" | grep -v "grep" | grep -v "$SCRIPT_NAME" | grep -v "(GS)" | grep -v "LED" | grep -v "led_" > /dev/null; then
        return 0
    fi
    
    return 1
}

monitor_hotkey() {
    while read -r line; do
        if [ -f /tmp/gs_active ] || [ -f "$IGNORE_FILE" ]; then
            continue
        fi

        if echo "$line" | grep -q "$HOTKEY_PATTERN"; then
            if in_game_or_tool; then
                :
            else
                LAST_EXECUTION=$(date +%s)
                
                if [ -f "$DIR/last.txt" ]; then
                    cp "$DIR/last.txt" /tmp/last.txt
                else
                    echo "" > /tmp/last.txt
                fi

                if [ -f "$LAUNCH_SCRIPT" ]; then
                    cd "$DIR"
                    GS_FROM_MONITOR=1 "$LAUNCH_SCRIPT" --from-monitor &
                else
                    :
                fi
            fi
            sleep 1
        fi
    done
}

(
    if [ ! -f "$EVTEST" ]; then
        exit 1
    fi

    pkill -f "$EVTEST" > /dev/null 2>&1

    for dev in /dev/input/event*; do
        [ -e "$dev" ] && "$EVTEST" "$dev" 2>/dev/null | monitor_hotkey &
    done

    while true; do
        sleep 60
    done
) &

exit 0
