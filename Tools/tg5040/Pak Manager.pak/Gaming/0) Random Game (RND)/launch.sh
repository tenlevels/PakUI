##!/bin/sh
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROM_DIR="/mnt/SDCARD/Roms"
PAK_BASE_DIR="/mnt/SDCARD/.system/$PLATFORM/paks/Emus"
ADDON_PAK_DIR="/mnt/SDCARD/Emus"
VALIDATION_TIME=2
HISTORY_FILE="$SCRIPT_DIR/last_10.txt"
TIMEOUT=10

is_valid_rom() {
    local file="$1"
    local basename=$(basename "$file")
    
    if echo "$basename" | grep -q "^\."; then
        return 1
    fi
    
    if echo "$basename" | grep -q "^_"; then
        return 1
    fi
    
    if echo "$file" | grep -q "\.gitkeep$"; then
        return 1
    fi
    
    if echo "$file" | grep -qiE '\.png$'; then
        folder=$(dirname "$file")
        if echo "$folder" | grep -qi "pico"; then
            return 0
        fi
    fi
    
    if echo "$file" | grep -qiE '\.(txt|log|cfg|ini)$'; then
        return 1
    fi
    
    if echo "$file" | grep -qiE '\.(jpg|jpeg|png|bmp|gif|tiff|webp)$'; then
        return 1
    fi
    
    if echo "$file" | grep -qiE '\.(xml|json|md|html|css|js|map)$'; then
        return 1
    fi
    
    return 0
}

validate_and_play_rom() {
    local EMU_LAUNCHER="$1"
    local ROM_PATH="$2"
    
    export MINUI_NO_RECENT=1
    
    "$EMU_LAUNCHER" "$ROM_PATH" &
    local EMU_PID=$!
    sleep 1
    if ! kill -0 $EMU_PID 2>/dev/null; then
        unset MINUI_NO_RECENT
        return 1
    fi
    sleep $VALIDATION_TIME
    if ! kill -0 $EMU_PID 2>/dev/null; then
        unset MINUI_NO_RECENT
        return 1
    fi
    echo "$ROM_PATH" > "$HISTORY_FILE.tmp"
    if [ -f "$HISTORY_FILE" ]; then
        head -n 9 "$HISTORY_FILE" >> "$HISTORY_FILE.tmp"
    fi
    mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    
    wait $EMU_PID
    
    unset MINUI_NO_RECENT
    
    return 0
}

START_TIME=$(date +%s)
while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
    
    if [ $ELAPSED_TIME -ge $TIMEOUT ]; then
        exit 1
    fi
    
    SYSTEM_DIR=$(find "$ROM_DIR" -mindepth 1 -maxdepth 1 -type d \
        ! -iname "*.pak" \
        ! -iname "*\(CUSTOM\)*" \
        ! -iname "*\(RND\)*" \
        ! -iname "*\(BITPAL\)*" \
        ! -iname "*\(GS\)*" | shuf -n 1)
    if [ -z "$SYSTEM_DIR" ]; then
        exit 1
    fi
    SYSTEM_NAME=$(basename "$SYSTEM_DIR" | sed 's/.*(\(.*\))/\1/')
    SYSTEM_NAME=${SYSTEM_NAME// /}
    ROM_LIST=$(find "$SYSTEM_DIR" -type f)
    if [ -z "$ROM_LIST" ]; then
        continue
    fi
    while true; do
        CURRENT_TIME=$(date +%s)
        ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
        
        if [ $ELAPSED_TIME -ge $TIMEOUT ]; then
            exit 1
        fi
        
        RANDOM_ROM=$(echo "$ROM_LIST" | shuf -n 1)
        if ! is_valid_rom "$RANDOM_ROM"; then
            ROM_LIST=$(echo "$ROM_LIST" | grep -v "^$RANDOM_ROM$")
            if [ -z "$ROM_LIST" ]; then
                break
            fi
            continue
        fi
        
        if [ -f "$HISTORY_FILE" ] && grep -q "^$RANDOM_ROM$" "$HISTORY_FILE"; then
            ROM_LIST=$(echo "$ROM_LIST" | grep -v "^$RANDOM_ROM$")
            if [ -z "$ROM_LIST" ]; then
                break
            fi
            continue
        fi
        EMU_LAUNCHER="$PAK_BASE_DIR/$SYSTEM_NAME.pak/launch.sh"
        if [ ! -f "$EMU_LAUNCHER" ]; then
            EMU_LAUNCHER="$ADDON_PAK_DIR/$PLATFORM/$SYSTEM_NAME.pak/launch.sh"
        fi
        if [ ! -f "$EMU_LAUNCHER" ]; then
            break
        fi
        if validate_and_play_rom "$EMU_LAUNCHER" "$RANDOM_ROM"; then
            exit 0
        else
            ROM_LIST=$(echo "$ROM_LIST" | grep -v "^$RANDOM_ROM$")
            if [ -z "$ROM_LIST" ]; then
                break
            fi
        fi
    done
done
exit 1