#!/bin/sh
SCRIPT_DIR=$(dirname "$0")
PARENT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
SDL2IMGSHOW="$PARENT_DIR/.scraper/bin/sdl2imgshow"
RES_PATH="$PARENT_DIR/.scraper/res"
DONE_IMAGE="$RES_PATH/done.png"
FOOTER_IMAGE="$RES_PATH/footer.png"
FONT_PATH="$RES_PATH/BPreplayBold.otf"
OPTIONS_FILE="$PARENT_DIR/.scraper/scripts/options.txt"
[ -f "$OPTIONS_FILE" ] && . "$OPTIONS_FILE"
DB_DIR="$PARENT_DIR/.scraper/db"
PROGRESS_FILE="$PARENT_DIR/.scraper/progress.txt"
BUTTON_LOG="/tmp/scraper_button_log.txt"
GLOBAL_QUIT_FLAG="/tmp/scraper_global_quit.txt"
> "$BUTTON_LOG"
> "$GLOBAL_QUIT_FLAG"

is_valid_rom() {
    local file="$1"
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

folder_has_roms() {
    local folder="$1"
    for f in "$folder"/*; do
        if [ -f "$f" ] && is_valid_rom "$f"; then
            return 0
        fi
    done
    return 1
}

should_exclude_folder() {
    local folder="$1"
    local name=$(basename "$folder")
    if echo "$name" | grep -qiE '\(CUSTOM\)|\(RND\)|\(GS\)'; then
        return 0
    fi
    if echo "$folder" | grep -qi "GAMESWITCHER"; then
        return 0
    fi
    if ! folder_has_roms "$folder"; then
        return 0
    fi
    return 1
}

show_image() {
    pkill -f "$SDL2IMGSHOW"
    "$SDL2IMGSHOW" -S vertical -P center -i "$1" -P bottomright -S original -i "$FOOTER_IMAGE" 2>/dev/null &
    sleep 2
    pkill -f "$SDL2IMGSHOW"
}

monitor_button_presses() {
    local EV_UTIL="$PARENT_DIR/.scraper/bin/evtest"
    pkill -f "evtest" 2>/dev/null
    for dev in /dev/input/event*; do
        [ -e "$dev" ] || continue
        "$EV_UTIL" "$dev" 2>&1 | while read -r line; do
            if echo "$line" | grep -q "code 304 (BTN_SOUTH).*value 1"; then
                echo "PAUSE" > "$BUTTON_LOG"
            fi
        done &
    done
}

check_for_pause() {
    if grep -q "PAUSE" "$BUTTON_LOG"; then
        pkill -f "$SDL2IMGSHOW"
        save_progress "$current_system" "$rom_file_name" "$file"
        > "$BUTTON_LOG"
        "$PARENT_DIR/show_message" "Scraper Paused" -l -a "RESUME" -b "QUIT"
        local choice=$?
        if [ $choice -eq 0 ]; then
            pkill -f "evtest" 2>/dev/null
            monitor_button_presses
            return 0
        else
            "$PARENT_DIR/show_message" "Scraper stopped|You can resume anytime" -l -t 2
            pkill -f "evtest"
            cleanup
            touch "$PARENT_DIR/.scraper/scraper_quit"
            echo "QUIT" > "$GLOBAL_QUIT_FLAG"
            exit 3
        fi
    fi
    return 0
}

resize_image() {
    local image_path="$1"
    local temp_path="${image_path}.temp"
    export LD_LIBRARY_PATH="$PARENT_DIR/.scraper/lib:$LD_LIBRARY_PATH"
    if "$PARENT_DIR/.scraper/bin/gm" convert "$image_path" -resize "${MAX_IMAGE_WIDTH}x${MAX_IMAGE_HEIGHT}" "$temp_path" 2>/dev/null; then
        if [ -f "$temp_path" ] && [ -s "$temp_path" ]; then
            mv "$temp_path" "$image_path"
            return 0
        fi
    fi
    [ -f "$temp_path" ] && rm -f "$temp_path"
    return 1
}

get_mapped_name() {
    local rom_file="$1"
    local rom_name
    rom_name=$(basename "$rom_file")
    local rom_dir
    rom_dir=$(dirname "$rom_file")
    local map_file=""
    if [ -f "$rom_dir/map.txt" ]; then
        map_file="$rom_dir/map.txt"
    elif [ -f "$PARENT_DIR/.scraper/bin/map.txt" ]; then
        map_file="$PARENT_DIR/.scraper/bin/map.txt"
    fi
    if [ -n "$map_file" ]; then
        local matches
        matches=$(grep -i "^${rom_name}[[:space:]]" "$map_file" | awk -F'\t' '{print $2}' | sed '/^\s*$/d' | sort -u | head -n 5)
        if [ -n "$matches" ]; then
            echo "$matches" | head -n 1
            return 0
        fi
    fi
    return 1
}


clean_rom_name() {
    local rom_name="$1"
    local base_name="${rom_name%.*}"
    local regions="USA|Europe|Japan|World|USA, Europe|Japan, USA|Japan, Europe|Europe, USA|Eu|U|J|E|W|UE|JU|JE|EU"
    local region_preserved=$(echo "$base_name" | grep -oE "\\([^)]*($regions)[^)]*\\)" | head -1)
    local cleaned1=$(echo "$base_name" | sed -E 's/\([^)]*\)//g')
    local cleaned2=$(echo "$cleaned1" | sed -E 's/\[[^]]*\]//g')
    local final_name=$(echo "$cleaned2" | sed 's/&/_/g' | sed -E 's/ +/ /g' | sed -E 's/^ +| +$//g')
    if [ -n "$region_preserved" ]; then
        final_name="$final_name $region_preserved"
    fi
    echo "$final_name"
}

find_image_name() {
    local rom_file_name="$1"
    local system_type="$2"
    local db_file="$3"
    local search_name=""
    case "$system_type" in
        ARCADE|NEOGEO|CPS1|CPS2|CPS3|MAME|FBN|FBNEO)
            local mapped_name
            mapped_name=$(get_mapped_name "$rom_file_name")
            if [ -n "$mapped_name" ]; then
                search_name="$mapped_name"
            else
                search_name=$(clean_rom_name "$rom_file_name")
            fi
            ;;
        *)
            search_name=$(clean_rom_name "$rom_file_name")
            ;;
    esac
    if [ "$IMAGE_MODE" = "BOXART" ]; then
        local region match
        for region in "$REGION_PRIORITY_1" "$REGION_PRIORITY_2" "$REGION_PRIORITY_3" "$REGION_PRIORITY_4"; do
            if [ -n "$region" ]; then
                match=$(grep -i "^$search_name.*$region.*\.png$" "$db_file" | head -n 1)
                if [ -n "$match" ]; then
                    echo "$match" | tr -d '\r' | sed 's/[[:space:]]*$//'
                    return 0
                fi
            fi
        done
        match=$(grep -i "^$search_name.*\.png$" "$db_file" | head -n 1)
        if [ -n "$match" ]; then
            echo "$match" | tr -d '\r' | sed 's/[[:space:]]*$//'
            return 0
        fi
        local fallback1
        fallback1=$(echo "$search_name" | sed 's/-//g' | sed -E 's/ +/ /g' | sed -E 's/^ +| +$//g')
        if [ "$fallback1" != "$search_name" ]; then
            for region in "$REGION_PRIORITY_1" "$REGION_PRIORITY_2" "$REGION_PRIORITY_3" "$REGION_PRIORITY_4"; do
                if [ -n "$region" ]; then
                    match=$(grep -i "^$fallback1.*$region.*\.png$" "$db_file" | head -n 1)
                    if [ -n "$match" ]; then
                        echo "$match" | tr -d '\r' | sed 's/[[:space:]]*$//'
                        return 0
                    fi
                fi
            done
            match=$(grep -i "^$fallback1.*\.png$" "$db_file" | head -n 1)
            if [ -n "$match" ]; then
                echo "$match" | tr -d '\r' | sed 's/[[:space:]]*$//'
                return 0
            fi
        fi
        local fallback2
        fallback2=$(echo "$search_name" | sed 's/-.*//' | sed -E 's/[[:space:]]*$//')
        if [ "$fallback2" != "$search_name" ]; then
            for region in "$REGION_PRIORITY_1" "$REGION_PRIORITY_2" "$REGION_PRIORITY_3" "$REGION_PRIORITY_4"; do
                if [ -n "$region" ]; then
                    match=$(grep -i "^$fallback2.*$region.*\.png$" "$db_file" | head -n 1)
                    if [ -n "$match" ]; then
                        echo "$match" | tr -d '\r' | sed 's/[[:space:]]*$//'
                        return 0
                    fi
                fi
            done
            match=$(grep -i "^$fallback2.*\.png$" "$db_file" | head -n 1)
            if [ -n "$match" ]; then
                echo "$match" | tr -d '\r' | sed 's/[[:space:]]*$//'
                return 0
            fi
        fi
        return 1
    else
        local matches=""
        local region
        for region in "$REGION_PRIORITY_1" "$REGION_PRIORITY_2" "$REGION_PRIORITY_3" "$REGION_PRIORITY_4" ""; do
            if [ -n "$region" ]; then
                matches="$matches"$'\n'"$(grep -i "^$search_name.*$region.*\.png$" "$db_file")"
            else
                matches="$matches"$'\n'"$(grep -i "^$search_name.*\.png$" "$db_file")"
            fi
        done
        matches=$(echo "$matches" | sed '/^\s*$/d' | sort -u | head -n 5)
        if [ -n "$matches" ]; then
            echo "$matches" | head -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//'
            return 0
        fi
        local fallback1
        fallback1=$(echo "$search_name" | sed 's/-//g' | sed -E 's/ +/ /g' | sed -E 's/^ +| +$//g')
        if [ "$fallback1" != "$search_name" ]; then
            matches=""
            for region in "$REGION_PRIORITY_1" "$REGION_PRIORITY_2" "$REGION_PRIORITY_3" "$REGION_PRIORITY_4" ""; do
                if [ -n "$region" ]; then
                    matches="$matches"$'\n'"$(grep -i "^$fallback1.*$region.*\.png$" "$db_file")"
                else
                    matches="$matches"$'\n'"$(grep -i "^$fallback1.*\.png$" "$db_file")"
                fi
            done
            matches=$(echo "$matches" | sed '/^\s*$/d' | sort -u | head -n 5)
            if [ -n "$matches" ]; then
                echo "$matches" | head -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//'
                return 0
            fi
        fi
        local fallback2
        fallback2=$(echo "$search_name" | sed 's/-.*//' | sed -E 's/[[:space:]]*$//')
        if [ "$fallback2" != "$search_name" ]; then
            matches=""
            for region in "$REGION_PRIORITY_1" "$REGION_PRIORITY_2" "$REGION_PRIORITY_3" "$REGION_PRIORITY_4" ""; do
                if [ -n "$region" ]; then
                    matches="$matches"$'\n'"$(grep -i "^$fallback2.*$region.*\.png$" "$db_file")"
                else
                    matches="$matches"$'\n'"$(grep -i "^$fallback2.*\.png$" "$db_file")"
                fi
            done
            matches=$(echo "$matches" | sed '/^\s*$/d' | sort -u | head -n 5)
            if [ -n "$matches" ]; then
                echo "$matches" | head -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//'
                return 0
            fi
        fi
        return 1
    fi
}

download_github_image() {
    local rom_name="$1"
    local output_path="$2"
    local repo_name="$3"
    local system_type="$4"
    local db_file="$5"
    local temp_path="${output_path}.tmp"
    local remote_image_name
    local fast_result
    local encoded_name
    local github_url
    local thorough_matches
    local tmpfile="/tmp/thorough_matches.$$"
    local image_folder
    if [ "$IMAGE_MODE" = "BOXART" ]; then
        image_folder="Named_Boxarts"
    else
        image_folder="Named_Snaps"
    fi
    mix_snap_logo() {
        if [ "$IMAGE_MODE" = "SNAPS_W_LOGO" ]; then
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
        fi
    }
    mix_snap_circle() {
        if [ "$IMAGE_MODE" = "SNAPS_CIRCLE" ]; then
            "$PARENT_DIR/.scraper/bin/gm" convert "$output_path" -resize "${MAX_IMAGE_WIDTH}x${MAX_IMAGE_WIDTH}^" -gravity center -extent "${MAX_IMAGE_WIDTH}x${MAX_IMAGE_WIDTH}" "$output_path"
            local mask="$RES_PATH/circle_mask.png"
            local mask_resized="/tmp/circle_mask_resized.$$"
            "$PARENT_DIR/.scraper/bin/gm" convert "$mask" -resize "${MAX_IMAGE_WIDTH}x${MAX_IMAGE_WIDTH}!" "$mask_resized"
            "$PARENT_DIR/.scraper/bin/gm" composite -compose CopyOpacity "$mask_resized" "$output_path" "$output_path"
            rm -f "$mask_resized"
        fi
    }
    remote_image_name=$(find_image_name "$rom_name" "$system_type" "$db_file")
    fast_result=$?
    if [ $fast_result -eq 0 ] && [ -n "$remote_image_name" ]; then
        encoded_name=$(echo "$remote_image_name" | sed 's/ /%20/g')
        github_url="https://raw.githubusercontent.com/libretro-thumbnails/${repo_name}/master/${image_folder}/${encoded_name}"
        if wget -O "$temp_path" "$github_url" 2>/dev/null; then
            if [ -f "$temp_path" ] && [ -s "$temp_path" ]; then
                mv "$temp_path" "$output_path" && resize_image "$output_path"
                if "$PARENT_DIR/.scraper/bin/gm" identify "$output_path" >/dev/null 2>&1; then
                    if [ "$IMAGE_MODE" = "SNAPS_W_LOGO" ]; then
                        mix_snap_logo
                    elif [ "$IMAGE_MODE" = "SNAPS_CIRCLE" ]; then
                        mix_snap_circle
                    fi
                    return 0
                else
                    rm -f "$output_path"
                fi
            fi
        fi
        rm -f "$temp_path"
    fi
    thorough_matches=$(find_image_names_thorough "$rom_name" "$system_type" "$db_file")
    if [ -n "$thorough_matches" ]; then
        echo "$thorough_matches" > "$tmpfile"
        while IFS= read -r match; do
            [ -z "$match" ] && continue
            encoded_name=$(echo "$match" | sed 's/ /%20/g')
            github_url="https://raw.githubusercontent.com/libretro-thumbnails/${repo_name}/master/${image_folder}/${encoded_name}"
            if wget -O "$temp_path" "$github_url" 2>/dev/null; then
                if [ -f "$temp_path" ] && [ -s "$temp_path" ]; then
                    mv "$temp_path" "$output_path" && resize_image "$output_path"
                    if "$PARENT_DIR/.scraper/bin/gm" identify "$output_path" >/dev/null 2>&1; then
                        touch /tmp/thorough_match_success
                        break
                    else
                        rm -f "$output_path"
                    fi
                fi
            fi
            rm -f "$temp_path"
        done < "$tmpfile"
        rm -f "$tmpfile"
        if [ -f /tmp/thorough_match_success ]; then
            rm -f /tmp/thorough_match_success
            if [ "$IMAGE_MODE" = "SNAPS_W_LOGO" ]; then
                mix_snap_logo
            elif [ "$IMAGE_MODE" = "SNAPS_CIRCLE" ]; then
                mix_snap_circle
            fi
            return 0
        fi
    fi
    if [ "$IMAGE_MODE" = "BOXART" ]; then
        fallback_group=$(eval echo "\$FALLBACK_GROUP_${system_type}")
        if [ -n "$fallback_group" ]; then
            OLDIFS="$IFS"
            IFS=','
            set -- $fallback_group
            IFS="$OLDIFS"
            for fallback in "$@"; do
                fallback=$(echo "$fallback" | tr -d ' ')
                fallback_line=$(echo "$SYSTEMS" | grep -E "^\(${fallback}\)")
                if [ -n "$fallback_line" ]; then
                    IFS='|' read -r fb_pattern fb_repo fb_db fb_exts <<EOF
$fallback_line
EOF
                    remote_image_name=$(find_image_name "$rom_name" "$fallback" "$DB_DIR/$fb_db")
                    fast_result=$?
                    if [ $fast_result -eq 0 ] && [ -n "$remote_image_name" ]; then
                        encoded_name=$(echo "$remote_image_name" | sed 's/ /%20/g')
                        github_url="https://raw.githubusercontent.com/libretro-thumbnails/${fb_repo}/master/${image_folder}/${encoded_name}"
                        if wget -O "$temp_path" "$github_url" 2>/dev/null; then
                            if [ -f "$temp_path" ] && [ -s "$temp_path" ]; then
                                mv "$temp_path" "$output_path" && resize_image "$output_path"
                                if "$PARENT_DIR/.scraper/bin/gm" identify "$output_path" >/dev/null 2>&1; then
                                    return 0
                                else
                                    rm -f "$output_path"
                                fi
                            fi
                        fi
                        rm -f "$temp_path"
                    fi
                    thorough_matches=$(find_image_names_thorough "$rom_name" "$fallback" "$DB_DIR/$fb_db")
                    if [ -n "$thorough_matches" ]; then
                        echo "$thorough_matches" > "$tmpfile"
                        while IFS= read -r match; do
                            [ -z "$match" ] && continue
                            encoded_name=$(echo "$match" | sed 's/ /%20/g')
                            github_url="https://raw.githubusercontent.com/libretro-thumbnails/${fb_repo}/master/${image_folder}/${encoded_name}"
                            if wget -O "$temp_path" "$github_url" 2>/dev/null; then
                                if [ -f "$temp_path" ] && [ -s "$temp_path" ]; then
                                    mv "$temp_path" "$output_path" && resize_image "$output_path"
                                    if "$PARENT_DIR/.scraper/bin/gm" identify "$output_path" >/dev/null 2>&1; then
                                        touch /tmp/thorough_match_success
                                        break
                                    else
                                        rm -f "$output_path"
                                    fi
                                fi
                            fi
                            rm -f "$temp_path"
                        done < "$tmpfile"
                        rm -f "$tmpfile"
                        if [ -f /tmp/thorough_match_success ]; then
                            rm -f /tmp/thorough_match_success
                            return 0
                        fi
                    fi
                fi
            done
        fi
    fi
    return 1
}

download_gamesdb_image() {
    if [ "$IMAGE_MODE" != "BOXART" ]; then
        return 1
    fi
    local rom_name="${1%.*}"
    local output_path="$2"
    local ENCODED_GAME
    ENCODED_GAME=$(printf "%s" "$rom_name" | sed 's/ /%20/g')
    local TEMP_SEARCH_FILE="$PARENT_DIR/.scraper/temp_search_results.html"
    wget -O "$TEMP_SEARCH_FILE" "https://thegamesdb.net/search.php?name=$ENCODED_GAME" 2>/dev/null || return 1
    local image_urls
    image_urls=$(grep -o 'https://cdn\.thegamesdb\.net/images/thumb/boxart/front/[^"]*\.jpg' "$TEMP_SEARCH_FILE")
    [ -z "$image_urls" ] && { rm -f "$TEMP_SEARCH_FILE"; return 1; }
    local first_image
    first_image=$(echo "$image_urls" | head -n 1)
    local full_image_url
    full_image_url=$(echo "$first_image" | sed 's/thumb\/boxart\/front/original\/boxart\/front/')
    wget -O "$output_path" "$full_image_url" 2>/dev/null && [ -f "$output_path" ] && [ -s "$output_path" ] && resize_image "$output_path"
    if "$PARENT_DIR/.scraper/bin/gm" identify "$output_path" >/dev/null 2>&1; then
        local result=$?
        rm -f "$TEMP_SEARCH_FILE"
        return $result
    else
        rm -f "$TEMP_SEARCH_FILE" "$output_path"
    fi
    return 1
}

save_progress() {
    if [ "${SCRAPE_SINGLE_SYSTEM:-0}" = "1" ] || [ "${USING_RESUME:-0}" = "1" ]; then
        local system="$1"
        local file="$2"
        local full_path="$3"
        echo "$system|$file|$full_path" > "$PROGRESS_FILE"
    fi
}

cleanup_hidden_files() {
    if [ -n "$ROMS_DIR" ] && [ -d "$ROMS_DIR" ]; then
        find "$ROMS_DIR" -type f -name "._*" -exec rm -f {} \;
        echo "Hidden Apple Double files cleaned up."
    fi
}

cleanup() {
    pkill -f "evtest" 2>/dev/null
    pkill -f "$SDL2IMGSHOW" 2>/dev/null
    rm -f "$BUTTON_LOG"
    rm -f "$GLOBAL_QUIT_FLAG"
    rm -f "$PARENT_DIR/.scraper/scraper_quit" 2>/dev/null
    cleanup_hidden_files
}

check_global_quit() {
    if grep -q "QUIT" "$GLOBAL_QUIT_FLAG"; then
        return 0
    fi
    return 1
}

scrape_single_system_dir() {
    local system_dir="$1"
    local system_found=0
    local matched_pattern=""
    local matched_repo=""
    local matched_db=""
    local matched_exts=""
    local system_name=$(basename "$system_dir")
    clean_system_name=$(echo "$system_name" | sed -E 's/^[0-9]+[)\._ -]+//' | sed 's/ *([^)]*)//g')
    echo "$SYSTEMS" | while IFS='|' read -r system_pattern repo_name db_file extensions; do
        [ -z "$system_pattern" ] && continue
        if echo "$system_name" | grep -qi "$system_pattern"; then
            echo "$system_pattern|$repo_name|$db_file|$extensions" > "/tmp/scraper_match.txt"
            break
        fi
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
    system_type=$(echo "$system_pattern" | sed 's/[()]//g')
    file_list=$(find "$SYSTEM_DIR" -maxdepth 1 -type f ! -name "._*" | sort)
    "$PARENT_DIR/show_message" "Scraping $clean_system_name" -t 1
    BUTTON_LOG="/tmp/scraper_button_log.txt"
    > "$BUTTON_LOG"
    monitor_button_presses
    echo "$file_list" | while read -r file; do
        check_for_pause
        [ ! -f "$file" ] && continue
        rom_file_name=$(basename "$file")
        echo "$rom_file_name" | grep -qiE "\.(${EXTENSION_PATTERN})$" || continue
        image_path="${SYSTEM_DIR}${OUTPUT_SUFFIX}/${rom_file_name}.png"
        [ -f "$image_path" ] && continue
        current_system="$system_pattern"
        save_progress "$system_pattern" "$rom_file_name" "$file"
        if download_github_image "$rom_file_name" "$image_path" "$repo_name" "$system_type" "$DB_FILE" || download_gamesdb_image "$rom_file_name" "$image_path"; then
            if [ "${SHOW_IMAGES_WHILE_SCRAPING:-1}" = "1" ]; then
                "$SDL2IMGSHOW" -S vertical -P center -i "$image_path" -P bottomright -S original -i "$FOOTER_IMAGE" -p bottomcenter -S original -f "$FONT_PATH" -s "$FONT_SIZE" -c "$TEXT_COLOR" -t "${rom_file_name%.*}" -p topcenter -S original -f "$FONT_PATH" -s "$((FONT_SIZE-4))" -c "yellow" -t "Press B to pause" 2>/dev/null &
                sleep 0.5
                pkill -f "$SDL2IMGSHOW"
            else
                "$SDL2IMGSHOW" -p center -S original -f "$FONT_PATH" -s "$FONT_SIZE" -c "$TEXT_COLOR" -t "${rom_file_name%.*}" -p topcenter -S original -f "$FONT_PATH" -s "$((FONT_SIZE-4))" -c "yellow" -t "Press B to pause" 2>/dev/null &
                sleep 0.5
                pkill -f "$SDL2IMGSHOW"
            fi
        fi
    done
    if [ ! -f "$PARENT_DIR/.scraper/scraper_quit" ]; then
        if [ "${SCRAPE_SINGLE_SYSTEM:-0}" = "1" ]; then
            rm -f "$PROGRESS_FILE"
        fi
    fi
    return 0
}

monitor_button_presses

if [ "${SCRAPE_SINGLE_SYSTEM:-0}" = "1" ] && [ -n "$SYSTEM_PATH" ]; then
    scrape_single_system_dir "$SYSTEM_PATH"
    cleanup
    exit 0
fi

if [ "${USING_RESUME:-0}" = "1" ] && [ -f "$PROGRESS_FILE" ]; then
    IFS='|' read -r RESUME_SYSTEM RESUME_FILE RESUME_PATH < "$PROGRESS_FILE"
    if [ -n "$RESUME_SYSTEM" ] && [ -n "$RESUME_PATH" ]; then
        system_dir=$(dirname "$RESUME_PATH")
        if [ -d "$system_dir" ]; then
            scrape_single_system_dir "$system_dir"
            if [ ! -f "$PARENT_DIR/.scraper/scraper_quit" ]; then
                rm -f "$PROGRESS_FILE"
                "$PARENT_DIR/show_message" "Scraping completed!" -l -t 2
            fi
            cleanup
            exit 0
        fi
    fi
fi

trap cleanup EXIT

while IFS='|' read -r system_pattern repo_name db_file extensions; do
    if check_global_quit; then
        break
    fi
    [ -z "$system_pattern" ] && continue
    MATCHING_DIR=$(find "$ROMS_DIR" -maxdepth 1 -type d -name "*${system_pattern}*" | while read -r d; do if ! should_exclude_folder "$d"; then echo "$d"; fi; done | head -n 1)
    [ -z "$MATCHING_DIR" ] && continue
    SYSTEM_DIR="$MATCHING_DIR/"
    DB_FILE="$DB_DIR/$db_file"
    EXTENSION_PATTERN=$(echo "$extensions" | sed 's/,/|/g')
    [ ! -f "$DB_FILE" ] && continue
    [ ! -d "$SYSTEM_DIR" ] && continue
    mkdir -p "${SYSTEM_DIR}${OUTPUT_SUFFIX}"
    system_type=$(echo "$system_pattern" | sed 's/[()]//g')
    file_list=$(find "$SYSTEM_DIR" -maxdepth 1 -type f ! -name "._*" | sort)
    clean_system_name=$(basename "$MATCHING_DIR" | sed -E 's/^[0-9]+[)\._ -]+//' | sed 's/ *([^)]*)//g')
    echo "$file_list" | while read -r file; do
        check_for_pause
        [ ! -f "$file" ] && continue
        rom_file_name=$(basename "$file")
        echo "$rom_file_name" | grep -qiE "\.(${EXTENSION_PATTERN})$" || continue
        image_path="${SYSTEM_DIR}${OUTPUT_SUFFIX}/${rom_file_name}.png"
        [ -f "$image_path" ] && continue
        current_system="$system_pattern"
        if download_github_image "$rom_file_name" "$image_path" "$repo_name" "$system_type" "$DB_FILE" || download_gamesdb_image "$rom_file_name" "$image_path"; then
            if [ "${SHOW_IMAGES_WHILE_SCRAPING:-1}" = "1" ]; then
                "$SDL2IMGSHOW" -S vertical -P center -i "$image_path" -P bottomright -S original -i "$FOOTER_IMAGE" -p bottomcenter -S original -f "$FONT_PATH" -s "$FONT_SIZE" -c "$TEXT_COLOR" -t "${rom_file_name%.*}" -p topcenter -S original -f "$FONT_PATH" -s "$((FONT_SIZE-4))" -c "yellow" -t "Press B to pause" 2>/dev/null &
                sleep 0.5
                pkill -f "$SDL2IMGSHOW"
            else
                "$SDL2IMGSHOW" -p center -S original -f "$FONT_PATH" -s "$FONT_SIZE" -c "$TEXT_COLOR" -t "${rom_file_name%.*}" -p topcenter -S original -f "$FONT_PATH" -s "$((FONT_SIZE-4))" -c "yellow" -t "Press B to pause" 2>/dev/null &
                sleep 0.5
                pkill -f "$SDL2IMGSHOW"
            fi
        fi
    done
    if check_global_quit; then
        break
    fi
done << EOF
$SYSTEMS
EOF

if [ ! -f "$PARENT_DIR/.scraper/scraper_quit" ] && ! grep -q "QUIT" "$GLOBAL_QUIT_FLAG"; then
    "$PARENT_DIR/show_message" "Scraping completed!" -l -t 2
fi

if [ -f "$PARENT_DIR/.scraper/scraper_quit" ] || grep -q "QUIT" "$GLOBAL_QUIT_FLAG"; then
    rm -f "$PARENT_DIR/.scraper/scraper_quit"
    cleanup
    exit 0
fi

cleanup
exit 0
