#!/bin/sh
SCRIPT_DIR=$(dirname "$0")
PARENT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
SDL2IMGSHOW="$PARENT_DIR/.scraper/bin/sdl2imgshow"
RES_PATH="$PARENT_DIR/.scraper/res"
DONE_IMAGE="$RES_PATH/done.png"
FOOTER_IMAGE="$RES_PATH/footer.png"
FONT_PATH="$RES_PATH/BPreplayBold.otf"
NONE_IMAGE="$RES_PATH/none.png"
[ -f "$NONE_IMAGE" ] || {
    mkdir -p "$RES_PATH"
    "$PARENT_DIR/.scraper/bin/gm" convert -size 320x240 xc:black -fill white -gravity center -pointsize 30 -annotate 0 "NO IMAGE" "$NONE_IMAGE" 2>/dev/null
}
OPTIONS_FILE="$PARENT_DIR/.scraper/scripts/options.txt"
[ -f "$OPTIONS_FILE" ] && . "$OPTIONS_FILE"
DB_DIR="$PARENT_DIR/.scraper/db"
TEMP_DIR="$PARENT_DIR/.scraper/single_game_temp"
BUTTON_LOG="$TEMP_DIR/button_log.txt"
IMAGE_SELECT_DIR="$TEMP_DIR/image_select"
TEMP_SYSTEM_LIST="$TEMP_DIR/system_list.txt"
TEMP_ROM_LIST="$TEMP_DIR/rom_list.txt"
mkdir -p "$TEMP_DIR" "$IMAGE_SELECT_DIR"
> "$BUTTON_LOG"
PROGRESS_FILE="$PARENT_DIR/.scraper/progress.txt"
PROGRESS_BACKUP="$PARENT_DIR/.scraper/progress_backup.txt"
[ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$PROGRESS_BACKUP"
ROMS_DIR="/mnt/SDCARD/Roms"

is_valid_rom() {
    local file="$1"
    echo "$file" | grep -qiE '\.png$' && { folder=$(dirname "$file"); echo "$folder" | grep -qi "pico" && return 0; }
    echo "$file" | grep -qiE '\.(txt|log|cfg|ini)$' && return 1
    echo "$file" | grep -qiE '\.(jpg|jpeg|png|bmp|gif|tiff|webp)$' && return 1
    echo "$file" | grep -qiE '\.(xml|json|md|html|css|js|map)$' && return 1
    return 0
}

folder_has_roms() {
    local folder="$1"
    for f in "$folder"/*; do
        [ -f "$f" ] && is_valid_rom "$f" && return 0
    done
    return 1
}

should_exclude_folder() {
    local folder="$1" name
    name=$(basename "$folder")
    echo "$name" | grep -qiE '\(CUSTOM\)|\(RND\)|\(GS\)' && return 0
    echo "$folder" | grep -qi "GAMESWITCHER" && return 0
    folder_has_roms "$folder" || return 0
    return 1
}

get_clean_name() {
    echo "$1" | sed -E 's/^[0-9]+[)\._ -]+//' | sed 's/ *([^)]*)//g'
}

show_image() {
    pkill -f "$SDL2IMGSHOW" 2>/dev/null
    "$SDL2IMGSHOW" -S vertical -P center -i "$1" -P bottomright -S original -i "$FOOTER_IMAGE" 2>/dev/null &
    sleep 2
    pkill -f "$SDL2IMGSHOW" 2>/dev/null
}

monitor_button_presses() {
    local EV_UTIL="$PARENT_DIR/.scraper/bin/evtest"
    pkill -f "evtest" 2>/dev/null
    sleep 0.1
    for dev in /dev/input/event*; do
        [ -e "$dev" ] || continue
        "$EV_UTIL" "$dev" 2>&1 | while read -r line; do
            echo "$line" | grep -q "code 304 (BTN_SOUTH).*value 1" && echo "BTN_SOUTH" > "$BUTTON_LOG"
            echo "$line" | grep -q "code 305 (BTN_EAST).*value 1" && echo "BTN_EAST" > "$BUTTON_LOG"
            echo "$line" | grep -q "code 16 (ABS_HAT0X).*value 1" && echo "D_PAD_RIGHT" > "$BUTTON_LOG"
            echo "$line" | grep -q "code 16 (ABS_HAT0X).*value -1" && echo "D_PAD_LEFT" > "$BUTTON_LOG"
        done &
    done
}

wait_for_button() {
    > "$BUTTON_LOG"
    local continue_waiting=true return_button=""
    while $continue_waiting; do
        [ -s "$BUTTON_LOG" ] && { return_button=$(cat "$BUTTON_LOG"); continue_waiting=false; }
        sleep 0.1
    done
    echo "$return_button"
}

resize_image() {
    local image_path="$1" temp_path="${image_path}.temp"
    export LD_LIBRARY_PATH="$PARENT_DIR/.scraper/lib:$LD_LIBRARY_PATH"
    "$PARENT_DIR/.scraper/bin/gm" convert "$image_path" -resize "${MAX_IMAGE_WIDTH}x${MAX_IMAGE_HEIGHT}" "$temp_path" 2>/dev/null && {
        [ -f "$temp_path" ] && [ -s "$temp_path" ] && mv "$temp_path" "$image_path" && return 0
    }
    [ -f "$temp_path" ] && rm -f "$temp_path"
    return 1
}

get_mapped_name() {
    local rom_file="$1" map_file="$PARENT_DIR/.scraper/bin/map.txt"
    [ -f "$map_file" ] && awk -F'\t' -v file="$rom_file" '$1 == file {print $2}' "$map_file"
}

clean_rom_name() {
    local rom_name="$1" base_name
    base_name="${rom_name%.*}"
    local regions="USA|Europe|Japan|World|USA, Europe|Japan, USA|Japan, Europe|Europe, USA|Eu|U|J|E|W|UE|JU|JE|EU"
    local region_preserved
    region_preserved=$(echo "$base_name" | grep -oE "\\([^)]*($regions)[^)]*\\)" | head -1)
    local cleaned1 cleaned2 final_name
    cleaned1=$(echo "$base_name" | sed -E 's/\([^)]*\)//g')
    cleaned2=$(echo "$cleaned1" | sed -E 's/\[[^]]*\]//g')
    final_name=$(echo "$cleaned2" | sed -E 's/ +/ /g' | sed -E 's/^ +| +$//g')
    [ -n "$region_preserved" ] && final_name="$final_name $region_preserved"
    echo "$final_name"
}

find_image_names() {
    local rom_file_name="$1" system_type="$2" db_file="$3" search_name=""
    case "$system_type" in
        ARCADE|NEOGEO|CPS1|CPS2|CPS3|MAME|FBN|FBNEO)
            local mapped_name
            mapped_name=$(get_mapped_name "$rom_file_name")
            [ -n "$mapped_name" ] && search_name="$mapped_name" || search_name=$(clean_rom_name "$rom_file_name")
            ;;
        *) search_name=$(clean_rom_name "$rom_file_name") ;;
    esac
    local matches_file="$TEMP_DIR/matches.txt"
    > "$matches_file"
    for region in "$REGION_PRIORITY_1" "$REGION_PRIORITY_2" "$REGION_PRIORITY_3" "$REGION_PRIORITY_4" ""; do
        [ -n "$region" ] && grep -i "^$search_name.*$region.*\.png$" "$db_file" >> "$matches_file" || grep -i "^$search_name.*\.png$" "$db_file" >> "$matches_file"
    done
    sort -u "$matches_file"
    rm -f "$matches_file"
}

# New: Use new IMAGE_MODE option. Matching always uses boxart DB; URL folder depends on IMAGE_MODE.
download_github_images() {
    local rom_name="$1" output_dir="$2" repo_name="$3" system_type="$4" db_file="$5" count=0
    local image_folder
    if [ "$IMAGE_MODE" = "BOXART" ]; then
        image_folder="Named_Boxarts"
    else
        image_folder="Named_Snaps"
    fi
    find_image_names "$rom_name" "$system_type" "$db_file" | while read -r remote_image_name; do
        [ -z "$remote_image_name" ] && continue
        count=$((count + 1))
        local output_path="$output_dir/github_${count}.png"
        local temp_path="${output_path}.tmp"
        local encoded_name
        encoded_name=$(echo "$remote_image_name" | sed 's/ /%20/g')
        local github_url="https://raw.githubusercontent.com/libretro-thumbnails/${repo_name}/master/${image_folder}/${encoded_name}"
        if wget -O "$temp_path" "$github_url" 2>/dev/null; then
            if [ -f "$temp_path" ] && [ -s "$temp_path" ]; then
                mv "$temp_path" "$output_path" && resize_image "$output_path"
                if [ "$IMAGE_MODE" = "SNAPS_W_LOGO" ]; then
                    mix_snap_logo "$repo_name" "$encoded_name" "$output_path"
                elif [ "$IMAGE_MODE" = "SNAPS_CIRCLE" ]; then
                    mix_snap_circle "$output_path"
                fi
                if "$PARENT_DIR/.scraper/bin/gm" identify "$output_path" >/dev/null 2>&1; then
                    echo "$output_path" >> "$output_dir/image_list.txt"
                else
                    rm -f "$output_path"
                fi
            fi
        fi
        [ -f "$temp_path" ] && rm -f "$temp_path"
    done
}

download_gamesdb_images() {
    local rom_name="${1%.*}" output_dir="$2"
    local ENCODED_GAME
    ENCODED_GAME=$(printf "%s" "$rom_name" | sed 's/ /%20/g')
    local TEMP_SEARCH_FILE="$TEMP_DIR/gamesdb_search.html"
    wget -O "$TEMP_SEARCH_FILE" "https://thegamesdb.net/search.php?name=$ENCODED_GAME" 2>/dev/null || return 1
    local count=0 image_urls
    image_urls=$(grep -o 'https://cdn\.thegamesdb\.net/images/thumb/boxart/front/[^"]*\.jpg' "$TEMP_SEARCH_FILE")
    [ -n "$image_urls" ] && echo "$image_urls" | while read -r thumb_url; do
        count=$((count + 1))
        local output_path="$output_dir/gamesdb_${count}.png"
        local full_image_url
        full_image_url=$(echo "$thumb_url" | sed 's/thumb\/boxart\/front/original\/boxart\/front/')
        if wget -O "$output_path" "$full_image_url" 2>/dev/null; then
            if [ -f "$output_path" ] && [ -s "$output_path" ] && resize_image "$output_path"; then
                if "$PARENT_DIR/.scraper/bin/gm" identify "$output_path" >/dev/null 2>&1; then
                    echo "$output_path" >> "$output_dir/image_list.txt"
                else
                    rm -f "$output_path"
                fi
            fi
        fi
    done
    rm -f "$TEMP_SEARCH_FILE"
}

mix_snap_logo() {
    local repo_name="$1" encoded_name="$2" output_path="$3"
    "$PARENT_DIR/.scraper/bin/gm" convert "$output_path" -resize "${MAX_IMAGE_WIDTH}x" "$output_path"
    local logo_width=$(( MAX_IMAGE_WIDTH * 80 / 100 ))
    local logo_url="https://raw.githubusercontent.com/libretro-thumbnails/${repo_name}/master/Named_Logos/${encoded_name}"
    local logo_temp="/tmp/logo_image.$$"
    if wget -O "$logo_temp" "$logo_url" 2>/dev/null; then
        if [ -f "$logo_temp" ] && [ -s "$logo_temp" ]; then
            "$PARENT_DIR/.scraper/bin/gm" convert "$logo_temp" -resize "${logo_width}x" "$logo_temp"
            "$PARENT_DIR/.scraper/bin/gm" convert -background none "$logo_temp" "$output_path" -append "$output_path"
            "$PARENT_DIR/.scraper/bin/gm" convert "$output_path" -resize "${MAX_IMAGE_WIDTH}x${MAX_IMAGE_HEIGHT}" "$output_path"
        fi
    fi
    rm -f "$logo_temp"
}

mix_snap_circle() {
    local output_path="$1"
    "$PARENT_DIR/.scraper/bin/gm" convert "$output_path" -resize "${MAX_IMAGE_WIDTH}x${MAX_IMAGE_WIDTH}^" -gravity center -extent "${MAX_IMAGE_WIDTH}x${MAX_IMAGE_WIDTH}" "$output_path"
    local mask="$RES_PATH/circle_mask.png"
    local mask_resized="/tmp/circle_mask_resized.$$"
    "$PARENT_DIR/.scraper/bin/gm" convert "$mask" -resize "${MAX_IMAGE_WIDTH}x${MAX_IMAGE_WIDTH}!" "$mask_resized"
    "$PARENT_DIR/.scraper/bin/gm" composite -compose CopyOpacity "$mask_resized" "$output_path" "$output_path"
    rm -f "$mask_resized"
}

image_selector() {
    local image_list="$1" output_path="$2" rom_name="$3" has_existing_image="$4"
    echo "$NONE_IMAGE" >> "$image_list"
    local num_images current_index=1
    num_images=$(wc -l < "$image_list")
    local current_image
    current_image=$(sed -n "${current_index}p" "$image_list")
    local result=1
    "$PARENT_DIR/show_message" "Select Box Art|Left/Right: Browse|A: Select|B: Cancel" -l -t 2
    "$SDL2IMGSHOW" -S vertical -P center -i "$current_image" -P bottomright -S original -i "$FOOTER_IMAGE" -p bottomcenter -S original -f "$FONT_PATH" -s "$FONT_SIZE" -c "$TEXT_COLOR" -t "${rom_name%.*}" -p topcenter -S original -f "$FONT_PATH" -s "$((FONT_SIZE-4))" -c "white" -t "Image $current_index of $num_images$([ "$current_image" = "$NONE_IMAGE" ] && echo ' (NO IMAGE)')" 2>/dev/null &
    monitor_button_presses
    local continue_selection=true button_pressed
    while $continue_selection; do
        button_pressed=$(wait_for_button)
        case "$button_pressed" in
            "D_PAD_RIGHT")
                current_index=$(( current_index < num_images ? current_index + 1 : 1 ))
                current_image=$(sed -n "${current_index}p" "$image_list")
                pkill -f "$SDL2IMGSHOW" 2>/dev/null
                "$SDL2IMGSHOW" -S vertical -P center -i "$current_image" -P bottomright -S original -i "$FOOTER_IMAGE" -p bottomcenter -S original -f "$FONT_PATH" -s "$FONT_SIZE" -c "$TEXT_COLOR" -t "${rom_name%.*}" -p topcenter -S original -f "$FONT_PATH" -s "$((FONT_SIZE-4))" -c "white" -t "Image $current_index of $num_images$([ "$current_image" = "$NONE_IMAGE" ] && echo ' (NO IMAGE)')" 2>/dev/null &
                ;;
            "D_PAD_LEFT")
                current_index=$(( current_index > 1 ? current_index - 1 : num_images ))
                current_image=$(sed -n "${current_index}p" "$image_list")
                pkill -f "$SDL2IMGSHOW" 2>/dev/null
                "$SDL2IMGSHOW" -S vertical -P center -i "$current_image" -P bottomright -S original -i "$FOOTER_IMAGE" -p bottomcenter -S original -f "$FONT_PATH" -s "$FONT_SIZE" -c "$TEXT_COLOR" -t "${rom_name%.*}" -p topcenter -S original -f "$FONT_PATH" -s "$((FONT_SIZE-4))" -c "white" -t "Image $current_index of $num_images$([ "$current_image" = "$NONE_IMAGE" ] && echo ' (NO IMAGE)')" 2>/dev/null &
                ;;
            "BTN_SOUTH")
                pkill -f "$SDL2IMGSHOW" 2>/dev/null
                pkill -f "evtest" 2>/dev/null
                result=1
                continue_selection=false
                ;;
            "BTN_EAST")
                pkill -f "$SDL2IMGSHOW" 2>/dev/null
                pkill -f "evtest" 2>/dev/null
                if [ "$current_image" = "$NONE_IMAGE" ]; then
                    [ -f "$output_path" ] && rm -f "$output_path"
                    result=2
                else
                    cp "$current_image" "$output_path"
                    result=0
                fi
                continue_selection=false
                ;;
        esac
    done
    pkill -f "$SDL2IMGSHOW" 2>/dev/null
    pkill -f "evtest" 2>/dev/null
    sleep 0.2
    return $result
}

select_and_scrape_single_game() {
    local system_dir="$1" system_name clean_system_name
    system_name=$(basename "$system_dir")
    clean_system_name=$(get_clean_name "$system_name")
    echo "$SYSTEMS" | while IFS='|' read -r system_pattern repo_name db_file extensions; do
        [ -z "$system_pattern" ] && continue
        echo "$system_name" | grep -qi "$system_pattern" && {
            echo "$system_pattern|$repo_name|$db_file|$extensions" > "/tmp/scraper_match.txt"
            break
        }
    done
    if [ -f "/tmp/scraper_match.txt" ]; then
        IFS='|' read -r system_pattern repo_name db_file extensions < "/tmp/scraper_match.txt"
        rm -f "/tmp/scraper_match.txt"
    else
        "$PARENT_DIR/show_message" "Could not determine system info for:|$clean_system_name" -l -t 2
        return 1
    fi
    SYSTEM_DIR="$system_dir/"
    DB_FILE="$DB_DIR/$db_file"
    EXTENSION_PATTERN=$(echo "$extensions" | sed 's/,/|/g')
    [ ! -f "$DB_FILE" ] && { "$PARENT_DIR/show_message" "Database file not found:|$db_file" -l -t 2; return 1; }
    [ ! -d "$SYSTEM_DIR" ] && { "$PARENT_DIR/show_message" "System directory not found" -l -t 2; return 1; }
    mkdir -p "${SYSTEM_DIR}${OUTPUT_SUFFIX}"
    local system_type
    system_type=$(echo "$system_pattern" | sed 's/[()]//g')
    file_list=$(find "$SYSTEM_DIR" -maxdepth 1 -type f ! -name "._*" | grep -Ei "\.(${EXTENSION_PATTERN})$" | sort)
    [ -z "$file_list" ] && { "$PARENT_DIR/show_message" "No ROMs found in:|$clean_system_name" -l -t 2; return 1; }
    > "$TEMP_ROM_LIST"
    echo "$file_list" | while read -r file; do
        [ ! -f "$file" ] && continue
        local rom_file_name
        rom_file_name=$(basename "$file")
        local image_path="${SYSTEM_DIR}${OUTPUT_SUFFIX}/${rom_file_name}.png"
        if [ -f "$image_path" ]; then
            echo "${rom_file_name%.*} [Has Image]|$file" >> "$TEMP_ROM_LIST"
        else
            echo "${rom_file_name%.*}|$file" >> "$TEMP_ROM_LIST"
        fi
    done
    "$PARENT_DIR/show_message" "Select a ROM to scrape" -t 1
    selected_rom=$("$PARENT_DIR/picker" "$TEMP_ROM_LIST" -b "BACK" -t "Select ROM to Scrape")
    picker_status=$?
    [ $picker_status -ne 0 ] || [ -z "$selected_rom" ] && return 1
    local selected_rom_path selected_rom_name image_path
    selected_rom_path=$(echo "$selected_rom" | cut -d'|' -f2)
    selected_rom_name=$(basename "$selected_rom_path")
    image_path="${SYSTEM_DIR}${OUTPUT_SUFFIX}/${selected_rom_name}.png"
    local has_existing_image=0
    [ -f "$image_path" ] && {
        has_existing_image=1
        "$PARENT_DIR/show_message" "This ROM already has an image.|Replace it?" -l -a "YES" -b "NO"
        [ $? -ne 0 ] && return 0
    }
    rm -rf "$IMAGE_SELECT_DIR"
    mkdir -p "$IMAGE_SELECT_DIR"
    > "$IMAGE_SELECT_DIR/image_list.txt"
    "$PARENT_DIR/show_message" "Scraping images for:|${selected_rom_name%.*}" -l -t 1
    download_github_images "$selected_rom_name" "$IMAGE_SELECT_DIR" "$repo_name" "$system_type" "$DB_FILE"
    download_gamesdb_images "$selected_rom_name" "$IMAGE_SELECT_DIR"
    if [ -s "$IMAGE_SELECT_DIR/image_list.txt" ] || [ $has_existing_image -eq 1 ]; then
        image_selector "$IMAGE_SELECT_DIR/image_list.txt" "$image_path" "${selected_rom_name%.*}" $has_existing_image
        select_result=$?
        pkill -f "$SDL2IMGSHOW" 2>/dev/null
        pkill -f "evtest" 2>/dev/null
        sleep 0.2
        case $select_result in
            0) "$PARENT_DIR/show_message" "Image saved successfully!" -l -t 1; return 0 ;;
            2) "$PARENT_DIR/show_message" "Image removed" -l -t 1; return 0 ;;
            *) "$PARENT_DIR/show_message" "No image selected" -l -t 1; return 1 ;;
        esac
    else
        "$PARENT_DIR/show_message" "No images found for this ROM" -l -t 2
        return 1
    fi
}

cleanup_hidden_files() {
    [ -d "$ROMS_DIR" ] && find "$ROMS_DIR" -type f -name "._*" -exec rm -f {} \; && echo "Hidden Apple Double files cleaned up."
}

cleanup() {
    pkill -f "evtest" 2>/dev/null
    pkill -f "$SDL2IMGSHOW" 2>/dev/null
    [ -f "$PROGRESS_BACKUP" ] && { cp "$PROGRESS_BACKUP" "$PROGRESS_FILE"; rm -f "$PROGRESS_BACKUP"; }
    rm -rf "$TEMP_DIR" 2>/dev/null
    cleanup_hidden_files
}

trap cleanup EXIT
trap cleanup INT
trap cleanup TERM

mkdir -p "$TEMP_DIR"
if [ -n "$1" ] && [ -d "$1" ]; then
    select_and_scrape_single_game "$1"
else
    > "$TEMP_SYSTEM_LIST"
    find "$ROMS_DIR" -maxdepth 1 -type d | sort | while read -r system_dir; do
        [ "$system_dir" = "$ROMS_DIR" ] && continue
        [ ! -d "$system_dir" ] && continue
        should_exclude_folder "$system_dir" || {
            dir_name=$(basename "$system_dir")
            clean_name=$(get_clean_name "$dir_name")
            echo "$clean_name|$system_dir" >> "$TEMP_SYSTEM_LIST"
        }
    done
    [ ! -s "$TEMP_SYSTEM_LIST" ] && { "$PARENT_DIR/show_message" "No system folders found" -l -t 2; cleanup; exit 1; }
    selected=$("$PARENT_DIR/picker" "$TEMP_SYSTEM_LIST" -b "BACK" -t "Select System")
    [ $? -ne 0 ] || [ -z "$selected" ] && { cleanup; exit 1; }
    selected_dir=$(echo "$selected" | cut -d'|' -f2)
    select_and_scrape_single_game "$selected_dir"
fi

pkill -f "evtest" 2>/dev/null
pkill -f "$SDL2IMGSHOW" 2>/dev/null
sleep 0.2
cleanup
exit 0
