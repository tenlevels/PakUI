#!/bin/sh
cd "$(dirname "$0")"
export LD_LIBRARY_PATH=/usr/trimui/lib:$LD_LIBRARY_PATH
export PLATFORM="$(basename "$(dirname "$(dirname "$0")")")"
SCRIPT_DIR="$(pwd)"
SCRAPER_SCRIPT="$SCRIPT_DIR/.scraper/scripts/scraper.sh"
GAME_SCRAPER_SCRIPT="$SCRIPT_DIR/.scraper/scripts/game_scraper.sh"
OPTIONS_FILE="$SCRIPT_DIR/.scraper/scripts/options.txt"
[ -f "$OPTIONS_FILE" ] && . "$OPTIONS_FILE"
SCRAPER_LIST="/tmp/scraper_list.txt"
OPTIONS_LIST="/tmp/options_list.txt"
REGIONS_LIST="/tmp/regions_list.txt"
HEIGHT_LIST="/tmp/height_list.txt"
WIDTH_LIST="/tmp/width_list.txt"
PROGRESS_FILE="$SCRIPT_DIR/.scraper/progress.txt"

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

check_boxart_status() {
    boxart_off=$(find "/mnt/SDCARD/Roms" -mindepth 2 -type d -name ".res_off" 2>/dev/null)
    if [ -n "$boxart_off" ]; then
        ./show_message "Box Art is Off|Enable box art for scraping?" -l -a "YES" -b "NO"
        if [ $? -eq 0 ]; then
            find "/mnt/SDCARD/Roms" -mindepth 2 -type d -name ".res_off" -exec sh -c 'mv "$1" "$(dirname "$1")/.res"' sh {} \; 2>/dev/null
            return 0
        else
            return 1
        fi
    fi
    return 0
}

# New function to delete all existing images in .res folders
delete_existing_images() {
    local scope="$1" # Can be "all" or a specific system directory
    local count=0
    
    if [ "$scope" = "all" ]; then
        # Delete images from all system .res folders
        ./show_message "Delete ALL existing images?" -l -a "YES" -b "NO"
        if [ $? -eq 0 ]; then
            ./show_message "Deleting all images..." -t 1
            find "/mnt/SDCARD/Roms" -mindepth 2 -type d -name ".res" -exec sh -c 'find "$1" -type f -name "*.png" -delete' sh {} \; 2>/dev/null
            count=$(find "/mnt/SDCARD/Roms" -mindepth 2 -type d -name ".res" -exec sh -c 'ls -1 "$1"/*.png 2>/dev/null | wc -l' sh {} \; | awk '{s+=$1} END {print s}')
            ./show_message "All images deleted!" -t 1
            return 0
        fi
    else
        # Delete images from a specific system's .res folder
        local system_name=$(basename "$scope")
        local clean_system_name=$(echo "$system_name" | sed -E 's/^[0-9]+[)\._ -]+//' | sed 's/ *([^)]*)//g')
        
        ./show_message "Delete all $clean_system_name images?" -l -a "YES" -b "NO"
        if [ $? -eq 0 ]; then
            ./show_message "Deleting $clean_system_name images..." -t 1
            find "$scope/.res" -type f -name "*.png" -delete 2>/dev/null
            ./show_message "All $clean_system_name images deleted!" -t 1
            return 0
        fi
    fi
    
    return 1
}

check_connectivity() {
    ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 ||
    ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 ||
    ping -c 1 -W 2 208.67.222.222 >/dev/null 2>&1 ||
    ping -c 1 -W 2 114.114.114.114 >/dev/null 2>&1 ||
    ping -c 1 -W 2 119.29.29.29 >/dev/null 2>&1
}

check_wifi_status() {
    if ! check_connectivity; then
        ./show_message "No WiFi Connection|Internet access required.|Try again?" -l -a "RETRY" -b "EXIT"
        if [ $? -eq 0 ]; then
            if check_connectivity; then
                ./show_message "WiFi Connected" -l -a "OK"
                return 0
            else
                ./show_message "Still No Connection|Check WiFi settings." -l -a "OK"
                return 1
            fi
        else
            return 1
        fi
    fi
    return 0
}

run_scraper() {
    if [ -x "$SCRAPER_SCRIPT" ]; then
        "$SCRAPER_SCRIPT"
        local scraper_status=$?
        build_menu
        return $scraper_status
    else
        ./show_message "Error|Scraper script not found." -l -a "OK"
        return 1
    fi
}

run_system_scraper() {
    if [ -x "$SCRAPER_SCRIPT" ]; then
        export SCRAPE_SINGLE_SYSTEM="1"
        export SYSTEM_PATH="$1"
        "$SCRAPER_SCRIPT"
        local scraper_status=$?
        build_menu
        return $scraper_status
    else
        ./show_message "Error|Scraper script not found." -l -a "OK"
        return 1
    fi
}

# Function to show overwrite options for an individual system
select_system_to_scrape() {
    SYSTEM_LIST="/tmp/scraper_system_list.txt"
    > "$SYSTEM_LIST"
    find "/mnt/SDCARD/Roms" -maxdepth 1 -type d | sort | while read -r system_dir; do
        [ "$system_dir" = "/mnt/SDCARD/Roms" ] && continue
        [ ! -d "$system_dir" ] && continue
        if ! should_exclude_folder "$system_dir"; then
            dir_name=$(basename "$system_dir")
            clean_name=$(echo "$dir_name" | sed -E 's/^[0-9]+[)\._ -]+//' | sed 's/ *([^)]*)//g')
            echo "$clean_name|$system_dir" >> "$SYSTEM_LIST"
        fi
    done
    if [ ! -s "$SYSTEM_LIST" ]; then
        ./show_message "No system folders found" -l -t 2
        return 1
    fi
    selected=$(./picker "$SYSTEM_LIST" -b "BACK" -t "Select System to Scrape")
    picker_status=$?
    rm -f "$SYSTEM_LIST"
    if [ $picker_status -ne 0 ] || [ -z "$selected" ]; then
        return 1
    fi
    selected_dir=$(echo "$selected" | cut -d'|' -f2)
    system_name=$(basename "$selected_dir")
    clean_system_name=$(echo "$system_name" | sed -E 's/^[0-9]+[)\._ -]+//' | sed 's/ *([^)]*)//g')
    
    # Add overwrite options menu
    SCRAPE_OPTIONS="/tmp/scrape_options.txt"
    > "$SCRAPE_OPTIONS"
    echo "Scrape without overwriting|normal" >> "$SCRAPE_OPTIONS"
    echo "Delete existing & scrape new|overwrite" >> "$SCRAPE_OPTIONS"
    
    scrape_choice=$(./game_picker "$SCRAPE_OPTIONS" -b "CANCEL" -t "Scrape $clean_system_name")
    if [ $? -eq 0 ] && [ -n "$scrape_choice" ]; then
        scrape_action=$(echo "$scrape_choice" | cut -d'|' -f2)
        
        case "$scrape_action" in
            "normal")
                run_system_scraper "$selected_dir"
                return $?
                ;;
            "overwrite")
                if delete_existing_images "$selected_dir"; then
                    run_system_scraper "$selected_dir"
                    return $?
                fi
                ;;
        esac
    fi
    
    return 1
}

# Modified function to show overwrite options for all systems
scrape_all_systems() {
    SCRAPE_OPTIONS="/tmp/scrape_options.txt"
    > "$SCRAPE_OPTIONS"
    echo "Scrape without overwriting|normal" >> "$SCRAPE_OPTIONS"
    echo "Delete existing & scrape new|overwrite" >> "$SCRAPE_OPTIONS"
    
    scrape_choice=$(./game_picker "$SCRAPE_OPTIONS" -b "CANCEL" -t "Scrape All Systems")
    if [ $? -eq 0 ] && [ -n "$scrape_choice" ]; then
        scrape_action=$(echo "$scrape_choice" | cut -d'|' -f2)
        
        case "$scrape_action" in
            "normal")
                export SCRAPE_SINGLE_SYSTEM="0"
                export USING_RESUME="0"
                export ROMS_DIR="/mnt/SDCARD/Roms"
                ./show_message "Scraping All Systems" -l -t 2
                run_scraper
                ;;
            "overwrite")
                if delete_existing_images "all"; then
                    export SCRAPE_SINGLE_SYSTEM="0"
                    export USING_RESUME="0"
                    export ROMS_DIR="/mnt/SDCARD/Roms"
                    ./show_message "Scraping All Systems" -l -t 2
                    run_scraper
                fi
                ;;
        esac
    fi
}

check_resume_available() {
    if [ -f "$PROGRESS_FILE" ]; then
        IFS='|' read -r system_pattern rom_file path < "$PROGRESS_FILE"
        if [ -n "$system_pattern" ]; then
            if [ -n "$path" ]; then
                system_dir=$(dirname "$path")
                system_name=$(basename "$system_dir")
                clean_system_name=$(echo "$system_name" | sed -E 's/^[0-9]+[)\._ -]+//' | sed 's/ *([^)]*)//g')
                echo "$clean_system_name"
            else
                echo "$system_pattern"
            fi
            return 0
        fi
    fi
    return 1
}

change_region_priority() {
    local priority_num="$1"
    local current_region=""
    case "$priority_num" in
        1) current_region="$REGION_PRIORITY_1" ;;
        2) current_region="$REGION_PRIORITY_2" ;;
        3) current_region="$REGION_PRIORITY_3" ;;
        4) current_region="$REGION_PRIORITY_4" ;;
    esac
    > "$REGIONS_LIST"
    echo "USA$([ "$current_region" = "USA" ] && echo " (current)")|USA" >> "$REGIONS_LIST"
    echo "Europe$([ "$current_region" = "Europe" ] && echo " (current)")|Europe" >> "$REGIONS_LIST"
    echo "Japan$([ "$current_region" = "Japan" ] && echo " (current)")|Japan" >> "$REGIONS_LIST"
    echo "World$([ "$current_region" = "World" ] && echo " (current)")|World" >> "$REGIONS_LIST"
    region_choice=$(./game_picker "$REGIONS_LIST" -b "BACK" -t "Priority $priority_num Region")
    region_status=$?
    if [ $region_status -eq 0 ] && [ -n "$region_choice" ]; then
        new_region=$(echo "$region_choice" | cut -d'|' -f2)
        sed -i 's/^REGION_PRIORITY_'"$priority_num"'=.*/REGION_PRIORITY_'"$priority_num"'="'"$new_region"'"/' "$OPTIONS_FILE"
        ./show_message "Region $priority_num: $new_region" -t 1
        [ -f "$OPTIONS_FILE" ] && . "$OPTIONS_FILE"
    fi
}

toggle_image_mode() {
    > "$OPTIONS_LIST"
    echo "Boxart|BOXART" >> "$OPTIONS_LIST"
    echo "Circle Snaps|SNAPS_CIRCLE" >> "$OPTIONS_LIST"
    echo "Regular Snaps|SNAPS" >> "$OPTIONS_LIST"
    echo "Reg Snap w Logo|SNAPS_W_LOGO" >> "$OPTIONS_LIST"
    image_choice=$(./game_picker "$OPTIONS_LIST" -b "BACK" -t "Select Image Mode")
    if [ $? -eq 0 ] && [ -n "$image_choice" ]; then
        new_mode=$(echo "$image_choice" | cut -d'|' -f2)
        sed -i 's/^IMAGE_MODE=.*/IMAGE_MODE="'"$new_mode"'"/' "$OPTIONS_FILE"
        ./show_message "Image Mode: $new_mode" -t 1
        [ -f "$OPTIONS_FILE" ] && . "$OPTIONS_FILE"
    fi
}

toggle_display_mode() {
    > "$OPTIONS_LIST"
    echo "Show Box Art While Scraping|1" >> "$OPTIONS_LIST"
    echo "Text Only Mode (Faster)|0" >> "$OPTIONS_LIST"
    mode_choice=$(./game_picker "$OPTIONS_LIST" -b "BACK" -t "Display Mode")
    mode_status=$?
    if [ $mode_status -eq 0 ] && [ -n "$mode_choice" ]; then
        new_mode=$(echo "$mode_choice" | cut -d'|' -f2)
        sed -i 's/^SHOW_IMAGES_WHILE_SCRAPING=.*/SHOW_IMAGES_WHILE_SCRAPING='"$new_mode"'/' "$OPTIONS_FILE"
        if [ "$new_mode" = "1" ]; then
            ./show_message "Display Mode: Box Art" -t 1
        else
            ./show_message "Display Mode: Text Only" -t 1
        fi
        [ -f "$OPTIONS_FILE" ] && . "$OPTIONS_FILE"
    fi
}

change_max_width() {
    > "$WIDTH_LIST"
    MAX_WIDTH_DIR="$SCRIPT_DIR/.scraper/max_width"
    for width_file in "$MAX_WIDTH_DIR"/*.txt; do
        if [ -f "$width_file" ]; then
            width_value=$(basename "$width_file" .txt)
            echo "$width_value px|$width_file" >> "$WIDTH_LIST"
        fi
    done
    sort -t'|' -k1,1n "$WIDTH_LIST" -o "$WIDTH_LIST"
    width_choice=$(./game_picker "$WIDTH_LIST" -b "BACK" -t "Select Max Width")
    width_status=$?
    if [ $width_status -eq 0 ] && [ -n "$width_choice" ]; then
        width_file=$(echo "$width_choice" | cut -d'|' -f2)
        new_width=$(basename "$width_file" .txt)
        sed -i 's/^MAX_IMAGE_WIDTH=.*/MAX_IMAGE_WIDTH='"$new_width"'/' "$OPTIONS_FILE"
        ./show_message "Width: ${new_width}px" -t 1
        [ -f "$OPTIONS_FILE" ] && . "$OPTIONS_FILE"
    fi
}

change_max_height() {
    > "$HEIGHT_LIST"
    MAX_HEIGHT_DIR="$SCRIPT_DIR/.scraper/max_height"
    for height_file in "$MAX_HEIGHT_DIR"/*.txt; do
        if [ -f "$height_file" ]; then
            height_value=$(basename "$height_file" .txt)
            echo "$height_value px|$height_file" >> "$HEIGHT_LIST"
        fi
    done
    sort -t'|' -k1,1n "$HEIGHT_LIST" -o "$HEIGHT_LIST"
    height_choice=$(./game_picker "$HEIGHT_LIST" -b "BACK" -t "Select Max Height")
    height_status=$?
    if [ $height_status -eq 0 ] && [ -n "$height_choice" ]; then
        height_file=$(echo "$height_choice" | cut -d'|' -f2)
        new_height=$(basename "$height_file" .txt)
        sed -i 's/^MAX_IMAGE_HEIGHT=.*/MAX_IMAGE_HEIGHT='"$new_height"'/' "$OPTIONS_FILE"
        ./show_message "Height: ${new_height}px" -t 1
        [ -f "$OPTIONS_FILE" ] && . "$OPTIONS_FILE"
    fi
}

show_options_menu() {
    local return_to_options=true
    while $return_to_options; do
        > "$OPTIONS_LIST"
        echo "Display Mode: $([ "${SHOW_IMAGES_WHILE_SCRAPING:-1}" = "1" ] && echo "Box Art" || echo "Text Only")|display" >> "$OPTIONS_LIST"
        echo "Image Mode: $IMAGE_MODE|image_mode" >> "$OPTIONS_LIST"
        echo "Max Height: ${MAX_IMAGE_HEIGHT}px|max_height" >> "$OPTIONS_LIST"
        echo "Max Width: ${MAX_IMAGE_WIDTH}px|max_width" >> "$OPTIONS_LIST"
        echo "Priority 1 Region: $REGION_PRIORITY_1|priority1" >> "$OPTIONS_LIST"
        echo "Priority 2 Region: $REGION_PRIORITY_2|priority2" >> "$OPTIONS_LIST"
        echo "Priority 3 Region: $REGION_PRIORITY_3|priority3" >> "$OPTIONS_LIST"
        echo "Priority 4 Region: $REGION_PRIORITY_4|priority4" >> "$OPTIONS_LIST"
        options_output=$(./game_picker "$OPTIONS_LIST" -b "BACK" -t "Scraper Options")
        options_status=$?
        if [ $options_status -eq 1 ] || [ -z "$options_output" ]; then
            return_to_options=false
            continue
        fi
        if [ $options_status -eq 0 ] && [ -n "$options_output" ]; then
            option_action=$(echo "$options_output" | cut -d'|' -f2)
            case "$option_action" in
                priority1) change_region_priority 1 ;;
                priority2) change_region_priority 2 ;;
                priority3) change_region_priority 3 ;;
                priority4) change_region_priority 4 ;;
                display) toggle_display_mode ;;
                image_mode) toggle_image_mode ;;
                max_width) change_max_width ;;
                max_height) change_max_height ;;
            esac
        fi
    done
}

build_menu() {
    > "$SCRAPER_LIST"
    echo "Boxart Scraper|__HEADER__|header" >> "$SCRAPER_LIST"
    resume_system=$(check_resume_available)
    if [ $? -eq 0 ]; then
        echo "Resume scraping $resume_system|resume" >> "$SCRAPER_LIST"
    fi
    echo "Scrape All Systems|all" >> "$SCRAPER_LIST"
    echo "Select System to Scrape|system" >> "$SCRAPER_LIST"
    echo "Scrape Single Game|singlegame" >> "$SCRAPER_LIST"
}

main() {
    build_menu
    if ! check_boxart_status; then
        cleanup
        exit 0
    fi
    if ! check_wifi_status; then
        cleanup
        exit 0
    fi
    if [ ! -x "$SCRAPER_SCRIPT" ]; then
        ./show_message "Error|Scraper not found at:|$SCRAPER_SCRIPT" -l -a "OK"
        cleanup
        exit 1
    fi
    menu_idx=0
    while true; do
        picker_output=$(./game_picker "$SCRAPER_LIST" -i $menu_idx -x "START" -y "OPTIONS" -b "EXIT" -t "Boxart Scraper")
        picker_status=$?
        if [ -n "$picker_output" ]; then
            menu_idx=$(grep -n "^${picker_output%$'\n'}$" "$SCRAPER_LIST" | cut -d: -f1 || echo "0")
            menu_idx=$((menu_idx - 1))
            [ $menu_idx -lt 0 ] && menu_idx=0
        fi
        if [ $picker_status -eq 1 ] || [ $picker_status -eq 2 ]; then
            break
        fi
        if [ $picker_status -eq 0 ] || [ $picker_status -eq 3 ]; then
            if echo "$picker_output" | grep -q "^Boxart Scraper|"; then
                show_options_menu
                continue
            else
                action=$(echo "$picker_output" | cut -d'|' -f2)
                case "$action" in
                    "all")
                        scrape_all_systems
                        ;;
                    "system")
                        select_system_to_scrape
                        ;;
                    "singlegame")
                        if [ -x "$GAME_SCRAPER_SCRIPT" ]; then
                            "$GAME_SCRAPER_SCRIPT"
                            build_menu
                        else
                            ./show_message "Game scraper not found at:|$GAME_SCRAPER_SCRIPT" -l -a "OK"
                        fi
                        ;;
                    "resume")
                        if [ -f "$PROGRESS_FILE" ]; then
                            resume_system=$(check_resume_available)
                            ./show_message "Resuming scraping" -l -t 2
                            export SCRAPE_SINGLE_SYSTEM="0"
                            export USING_RESUME="1"
                            export ROMS_DIR="/mnt/SDCARD/Roms"
                            cp "$PROGRESS_FILE" "$PROGRESS_FILE.bak"
                            run_scraper
                            if [ -f "$SCRIPT_DIR/.scraper/scraper_quit" ] && [ ! -f "$PROGRESS_FILE" ]; then
                                cp "$PROGRESS_FILE.bak" "$PROGRESS_FILE"
                            fi
                            rm -f "$PROGRESS_FILE.bak"
                            build_menu
                        fi
                        ;;
                esac
            fi
        elif [ $picker_status -eq 4 ]; then
            show_options_menu
        fi
    done
    cleanup
}

cleanup() {
    rm -f "$SCRAPER_LIST" "$OPTIONS_LIST" "$REGIONS_LIST" "$HEIGHT_LIST" "$WIDTH_LIST" "/tmp/scrape_options.txt"
}

trap cleanup EXIT
main