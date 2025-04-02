#!/bin/sh


SYNCTHING="$MODULE_PATH/.bin/syncthing"
XMLSTARLET="$MODULE_PATH/.bin/xml"
SDL2IMGSHOW="$MODULE_PATH/.bin/sdl2imgshow"

TEXT_BACKGROUND_PATH="$MODULE_PATH/.res/background.png"
TEXT_FONT_PATH="$MODULE_PATH/.res/BPreplayBold.otf"
TEXT_SIZE=34
TEXT_COLOR="255,255,255"

display_message() {
    local message="$1"
    local duration="${2:-0}"
    local overlay="$3" 

    if [ "$overlay" != "1" ]; then
        killall sdl2imgshow 2>/dev/null
        sync
        sleep 0.5
    fi

    "$SDL2IMGSHOW" \
        -i "$TEXT_BACKGROUND_PATH" \
        -f "$TEXT_FONT_PATH" \
        -s "$TEXT_SIZE" \
        -c "$TEXT_COLOR" \
        -t "$message" & local pid=$!

    if [ "$duration" -gt 0 ]; then
        sleep "$duration"
        kill $pid
        sync
        sleep 0.5
    else
        echo "$pid"
    fi
}

add_folder() {
    local folder_id="$1"
    local folder_label="$2"
    local folder_path="$3"
    local device_id="$4"
    
    JSON_TEMPLATE=$(cat "$MODULE_PATH/.scripts/template.json")

    # Replace placeholders
    json_data=$(echo "$JSON_TEMPLATE" | \
        sed "s/FOLDER_ID/$folder_id/" | \
        sed "s/FOLDER_LABEL/$folder_label/" | \
        sed "s|FOLDER_PATH|$folder_path|" | \
        sed "s/DEVICE_ID/$device_id/")
    
    # Make the POST request
    curl -X POST \
        -v \
        -H "Content-Type: application/json" \
        -H "X-API-Key: $API_KEY" \
        -d "$json_data" \
        "http://localhost:8384/rest/config/folders"
}

check_folder_exists() {
    local check_path="$1"
    curl -v -s -H "X-API-Key: $API_KEY" \
        "http://localhost:8384/rest/config/folders" | \
        grep -q "\"path\": \"$check_path\""
    return $?
}
