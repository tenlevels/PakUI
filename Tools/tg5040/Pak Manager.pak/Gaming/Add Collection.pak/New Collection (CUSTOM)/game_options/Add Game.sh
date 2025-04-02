#!/bin/sh

CURRENT_DIR=$(basename "$(pwd)")
COLLECTION_NAME=$(echo "$CURRENT_DIR" | sed 's/ ([^)]*)//g' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
COLLECTION_NAME=$(echo "$COLLECTION_NAME" | sed 's/^[0-9]\+[\)\._ -]*//')
ADD_TO_TEXT="$COLLECTION_NAME|__COLLECTION__|menu_options"
BROWSE_LIST="/tmp/browse_list.txt"

cleanup() {
    rm -f /tmp/keyboard_output.txt
    rm -f /tmp/picker_output.txt
    rm -f /tmp/search_results.txt
    rm -f /tmp/add_favorites.txt
    rm -f /tmp/recent_list.txt
    rm -f "$BROWSE_LIST"
}

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

get_clean_folder_name() {
    local folder_name="$1"
    
    clean_name=$(echo "$folder_name" | sed -E 's/^[0-9]+[)\._ -]+//')
    clean_name=$(echo "$clean_name" | sed 's/ *([^)]*)//g')
    
    echo "$clean_name"
}

browse_roms() {
    local current_path="/mnt/SDCARD/Roms"
    
    while true; do
        > "$BROWSE_LIST"
        
        for d in "$current_path"/*; do
            if [ -d "$d" ] && ! should_exclude_folder "$d"; then
                dir_name=$(basename "$d")
                display_name=$(get_clean_folder_name "$dir_name")
                echo "$display_name|$d" >> "$BROWSE_LIST"
            fi
        done
        
        selection=$(./picker "$BROWSE_LIST")
        picker_status=$?
        
        if [ $picker_status -ne 0 ]; then
            if [ "$current_path" != "/mnt/SDCARD/Roms" ]; then
                current_path=$(dirname "$current_path")
                continue
            else
                return ""
            fi
        fi
        
        if [ -z "$selection" ]; then
            return ""
        fi
        
        path=$(echo "$selection" | cut -d'|' -f2)
        
        if [ -d "$path" ]; then
            selected_rom=$(./directory "$path")
            if [ -n "$selected_rom" ]; then
                echo "$selected_rom"
                return 0
            else
                continue
            fi
        fi
    done
}

add_favorite() {
    local rom_path="$1"
    
    if [ -z "$rom_path" ]; then
        echo "Error: No ROM path provided" >&2
        return 1
    fi

    name=$(basename "$rom_path")
    clean_name=$(echo "$name" | sed 's/([^)]*)//g' | sed 's/\.[^.]*$//' | tr '_' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    ./show_message "Add $clean_name|to $COLLECTION_NAME?" -l -a "YES" -b "NO"
    if [ $? = 0 ]; then
        if grep -q "|$rom_path|" "$MENU"; then
            sed -i "\|$rom_path|d" "$MENU"  
        fi

        echo "$ADD_TO_TEXT" > "/tmp/menu.$$"
        echo "$clean_name|$rom_path|launch" >> "/tmp/menu.$$"
        sed '1d' "$MENU" >> "/tmp/menu.$$"
        mv "/tmp/menu.$$" "$MENU"
    fi
    # Don't exit the script here, just return to continue the main loop
    return 0
}

add_menu_idx=0
while true; do
    echo "Building Add $COLLECTION_NAME Menu"
    echo "Browse|browse" > "/tmp/add_favorites.txt"
    echo "Search|search" >> "/tmp/add_favorites.txt"
    echo "Add From Recents|recent" >> "/tmp/add_favorites.txt"
    picker_output=$(./picker "/tmp/add_favorites.txt" -i $add_menu_idx)
    picker_status=$?
    
    if [ $picker_status -ne 0 ]; then
        cleanup
        exit 0
    fi
    
    add_menu_idx=$(grep -n "^${picker_output%$'\n'}$" "/tmp/add_favorites.txt" | cut -d: -f1)
    add_menu_idx=$((add_menu_idx - 1))

    add_method=$(echo "$picker_output" | cut -d'|' -f2)
    case "$add_method" in
        "browse")
            cleanup
            selected_rom=$(browse_roms)
            if [ -z "$selected_rom" ]; then
                continue
            fi
            echo "Adding $selected_rom to $COLLECTION_NAME"
            add_favorite "$selected_rom"
            # Don't exit here, continue the loop
            ;;
        "search") 
            search_term=$(./keyboard)
            if [ -z "$search_term" ]; then
                continue
            fi
            ./show_message "Searching for $search_term" &
            find /mnt/SDCARD/Roms -iname "*${search_term}*" | while read path; do
                if ! echo "$path" | grep -q "GAMESWITCHER"; then
                    name=$(basename "$path")
                    clean_name=$(echo "$name") 
                    echo "$clean_name|$path"
                fi
            done > /tmp/search_results.txt
            killall show_message 
            search_selection=$(./picker "/tmp/search_results.txt")
            if [ -z "$search_selection" ]; then
                continue
            fi
            selected_rom=$(echo "$search_selection" | cut -d'|' -f2)
            add_favorite "$selected_rom"
            # Don't exit here, continue the loop
            ;;
        "recent")
            RECENT_FILE="/mnt/SDCARD/.userdata/shared/.minui/recent.txt"
            if [ ! -f "$RECENT_FILE" ]; then
                continue
            fi

            > /tmp/recent_list.txt
            while IFS= read -r line; do
                if echo "$line" | grep -q '\.sh\|\.m3u\|(GS)\|GAMESWITCHER'; then
                    continue
                fi
                candidate="/mnt/SDCARD$(echo "$line" | cut -f1)"
                candidate_name=$(basename "$candidate" | sed 's/\.[^.]*$//')
                echo "$candidate_name|$candidate" >> /tmp/recent_list.txt
            done < "$RECENT_FILE"

            recents_selection=$(./picker "/tmp/recent_list.txt")
            if [ -z "$recents_selection" ]; then
                continue
            fi
            selected_rom=$(echo "$recents_selection" | cut -d'|' -f2)
            add_favorite "$selected_rom"
            # Don't exit here, continue the loop
            ;;
    esac
done

cleanup
exit 0
