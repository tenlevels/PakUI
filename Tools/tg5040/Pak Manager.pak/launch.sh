#!/bin/sh

TEMP_MENU="/tmp/pm_temp_menu.txt"
trap 'rm -f "$TEMP_MENU"' EXIT

cd "$(dirname "$0")"
export LD_LIBRARY_PATH="/usr/trimui/lib:$LD_LIBRARY_PATH"

PAKUI_DIR="$(pwd)"
PAK_NAME="$(basename "$PAKUI_DIR")"
PAK_NAME_NOEXT="${PAK_NAME%.pak}"
if echo "$PAK_NAME_NOEXT" | grep -q -i "manager"; then
    DISPLAY_NAME="$PAK_NAME_NOEXT"
else
    DISPLAY_NAME="$PAK_NAME_NOEXT Manager"
fi

PAKS_INSTALL_FILE="$PAKUI_DIR/paks_install.txt"
touch "$PAKS_INSTALL_FILE" 2>/dev/null

MAIN_MENU="$PAKUI_DIR/main_menu.txt"
PICKER="./picker"
SHOW_MESSAGE="./show_message"
WELCOME_FILE="$PAKUI_DIR/welcome.txt"
WELCOME_OFF_FILE="$PAKUI_DIR/welcome_off.txt"
ERROR_RETURN_TO_MAIN=0

if [ -d "/mnt/SDCARD/.userdata/trimui" ]; then
    PLATFORM="trimui"
elif [ -d "/mnt/SDCARD/.userdata/miyoo" ]; then
    PLATFORM="miyoo"
else
    PLATFORM="$(basename "$(dirname "$PAKUI_DIR")")"
fi

if [ -d "/mnt/SDCARD/Tools" ]; then
    TOOLS_BASE="/mnt/SDCARD/Tools"
else
    CURRENT_DIR="$PAKUI_DIR"
    while [ "$CURRENT_DIR" != "/" ] && [ "$(basename "$CURRENT_DIR")" != "Tools" ]; do
        CURRENT_DIR="$(dirname "$CURRENT_DIR")"
    done
    if [ "$(basename "$CURRENT_DIR")" = "Tools" ]; then
        TOOLS_BASE="$CURRENT_DIR"
    else
        "$SHOW_MESSAGE" "Error: Cannot find Tools directory" -l a
        exit 1
    fi
fi

TOOLS_DIR="$TOOLS_BASE/$PLATFORM"
ROMS_DIR="/mnt/SDCARD/Roms"

# Function to clean up display names by removing prefixes and emulator tags
clean_display_name() {
    local name="$1"
    # Remove numeric prefixes like "0) ", "00) ", etc.
    name=$(echo "$name" | sed 's/^[0-9]\+)\s*//' | sed 's/^[0-9]\+\s*//')
    # Remove emulator tags like " (RND)", " [RND]", etc.
    name=$(echo "$name" | sed 's/\s*([A-Z0-9]\+)$//' | sed 's/\s*\[[A-Z0-9]\+\]$//')
    echo "$name"
}

check_file_exists() {
    local dir="$1"
    local filename="$2"
    if [ -e "$dir/$filename" ]; then
        return 0
    fi
    for ext in .pak .sh .elf; do
        if [ -e "$dir/$filename$ext" ]; then
            return 0
        fi
    done
    return 1
}

is_pak_installed() {
    local category="$1"
    local pakname="$2"
    grep -q "^$category|$pakname|" "$PAKS_INSTALL_FILE"
    return $?
}

get_pak_location() {
    local category="$1"
    local pakname="$2"
    grep "^$category|$pakname|" "$PAKS_INSTALL_FILE" | cut -d'|' -f3
}

is_dual_install_pak() {
    local category="$1"
    local base_name="$2"
    
    if [ -f "$PAKUI_DIR/$category/${base_name}.dual.txt" ]; then
        return 0
    else
        return 1
    fi
}

# Function to check if a file should be installed in Roms only
is_roms_only_pak() {
    local category="$1"
    local base_name="$2"
    
    if [ -f "$PAKUI_DIR/$category/${base_name}.roms.txt" ]; then
        return 0
    else
        return 1
    fi
}

find_companion() {
    local dir="$1"
    local basename="$2"
    if [ -e "$dir/$basename" ]; then
        echo "$dir/$basename"
        return 0
    fi
    for ext in .pak .sh .elf; do
        if [ -e "$dir/$basename$ext" ]; then
            echo "$dir/$basename$ext"
            return 0
        fi
    done
    for file in "$dir/$basename".*; do
        [ "$file" != "$dir/$basename.txt" ] && [ "$file" != "$dir/$basename.dual.txt" ] && [ "$file" != "$dir/$basename.roms.txt" ] && [ -e "$file" ] && echo "$file" && return 0
    done
    echo ""
    return 1
}

count_paks() {
    paks_installed=$(wc -l < "$PAKS_INSTALL_FILE" | tr -d ' ')
    paks_total=0
    for category_dir in "$PAKUI_DIR"/*/; do
        category="$(basename "$category_dir")"
        for txt_file in "$category_dir"/*.txt; do
            [ -f "$txt_file" ] || continue
            paks_total=$((paks_total + 1))
        done
    done
    echo "$paks_installed $paks_total"
}

create_main_menu() {
    echo "$DISPLAY_NAME|__HEADER__|header" > "$MAIN_MENU"
    for category_dir in "$PAKUI_DIR"/*/; do
        category="$(basename "$category_dir")"
        if [ -d "$category_dir" ]; then
            total=0
            installed=0
            for txt_file in "$category_dir"/*.txt; do
                [ -f "$txt_file" ] || continue
                total=$((total + 1))
                txt_base="$(basename "$txt_file" .txt)"
                txt_base="${txt_base%.dual}" # Remove .dual suffix if present
                txt_base="${txt_base%.roms}" # Remove .roms suffix if present
                if is_pak_installed "$category" "$txt_base"; then
                    installed=$((installed + 1))
                fi
            done
            if [ $total -gt 0 ]; then
                echo "$category ($installed/$total)|$category|category" >> "$MAIN_MENU"
            fi
        fi
    done
    if [ "$(grep -c "category" "$MAIN_MENU")" -eq 0 ]; then
        echo "No categories found|none|none" >> "$MAIN_MENU"
    fi
}

create_category_menu() {
    local category="$1"
    > "$TEMP_MENU"
    for txt_file in "$PAKUI_DIR/$category"/*.txt; do
        [ -f "$txt_file" ] || continue
        txt_base="$(basename "$txt_file" .txt)"
        # Check if it's a dual install file or roms-only file
        if [ "${txt_base%.dual}" != "$txt_base" ]; then
            txt_base="${txt_base%.dual}"
        elif [ "${txt_base%.roms}" != "$txt_base" ]; then
            txt_base="${txt_base%.roms}"
        fi
        
        # Create clean display name for UI
        display_name=$(clean_display_name "$txt_base")
        
        if check_file_exists "$PAKUI_DIR/$category" "$txt_base"; then
            companion=$(find_companion "$PAKUI_DIR/$category" "$txt_base")
            if [ -n "$companion" ]; then
                echo "$display_name|$(basename "$companion")|available|$txt_base" >> "$TEMP_MENU"
            else
                echo "$display_name|$txt_base.pak|available|$txt_base" >> "$TEMP_MENU"
            fi
        else
            if is_pak_installed "$category" "$txt_base"; then
                location=$(get_pak_location "$category" "$txt_base")
                if [ "$location" = "Roms" ]; then
                    echo "$display_name [INSTALLED-Roms]|$txt_base|installed|$txt_base" >> "$TEMP_MENU"
                else
                    echo "$display_name [INSTALLED-Tools]|$txt_base|installed|$txt_base" >> "$TEMP_MENU"
                fi
            else
                echo "$display_name|$txt_base.pak|available|$txt_base" >> "$TEMP_MENU"
            fi
        fi
    done
    [ -s "$TEMP_MENU" ] || echo "No items found|none|none" >> "$TEMP_MENU"
    
    if [ -s "$TEMP_MENU" ] && ! grep -q "^No items found|" "$TEMP_MENU"; then
        sort -o "$TEMP_MENU" "$TEMP_MENU"
    fi
}

show_header_info() {
    create_main_menu
    read p_installed p_total <<EOF
$(count_paks)
EOF
    header_text="$PAK_NAME_NOEXT|Paks: $p_installed/$p_total"
    if [ -f "$WELCOME_FILE" ]; then
        "$SHOW_MESSAGE" "$header_text" -l a
    else
        "$SHOW_MESSAGE" "$header_text" -l ab -a "OK" -b "INFO"
        button_result=$?
        if [ $button_result -eq 2 ]; then
            "$SHOW_MESSAGE" "Show welcome message?|Display greeting when|starting $DISPLAY_NAME?" -l ab -a "YES" -b "NO"
            button_result=$?
            if [ $button_result -eq 0 ]; then
                if [ -f "$WELCOME_OFF_FILE" ]; then
                    mv "$WELCOME_OFF_FILE" "$WELCOME_FILE"
                else
                    echo "Welcome to $DISPLAY_NAME!|Manage your paks here.|Install (use) or uninstall (hide)." > "$WELCOME_FILE"
                fi
                "$SHOW_MESSAGE" "Welcome message enabled|You'll see it next time|you start $DISPLAY_NAME" -l a
            fi
        fi
    fi
}

show_item_info() {
    local category="$1"
    local base_name="$2"
    local status="$3"
    local actual_base_name="$4"  # This is the actual filename (with prefixes/tags)
    local desc="No description available."
    local desc_file="$PAKUI_DIR/$category/$actual_base_name.txt"
    
    # Check for different description file types
    if [ ! -f "$desc_file" ]; then
        if [ -f "$PAKUI_DIR/$category/$actual_base_name.dual.txt" ]; then
            desc_file="$PAKUI_DIR/$category/$actual_base_name.dual.txt"
        elif [ -f "$PAKUI_DIR/$category/$actual_base_name.roms.txt" ]; then
            desc_file="$PAKUI_DIR/$category/$actual_base_name.roms.txt" 
        fi
    fi
    
    if [ -f "$desc_file" ]; then
        desc=$(cat "$desc_file")
    fi
    
    if [ "$status" = "installed" ]; then
        # Get the installation location for display
        location=$(get_pak_location "$category" "$actual_base_name")
        "$SHOW_MESSAGE" "$base_name|$desc|Status: INSTALLED ($location)" -l ab -a "UNINSTALL" -b "BACK"
        button_result=$?
        if [ $button_result -eq 0 ]; then
            "$SHOW_MESSAGE" "Uninstall $base_name?|Are you sure?" -l ab -a "YES" -b "NO"
            button_result=$?
            [ $button_result -eq 0 ] && uninstall_item "$category" "$actual_base_name"
            if [ $ERROR_RETURN_TO_MAIN -eq 1 ]; then
                ERROR_RETURN_TO_MAIN=0
                return 1
            fi
        fi
    else
        # Check the installation type and show appropriate status
        if is_dual_install_pak "$category" "$actual_base_name"; then
            "$SHOW_MESSAGE" "$base_name|$desc|Status: AVAILABLE (Dual Install)" -l ab -a "INSTALL" -b "BACK"
        elif is_roms_only_pak "$category" "$actual_base_name"; then
            "$SHOW_MESSAGE" "$base_name|$desc|Status: AVAILABLE (Roms)" -l ab -a "INSTALL" -b "BACK" 
        else
            "$SHOW_MESSAGE" "$base_name|$desc|Status: AVAILABLE" -l ab -a "INSTALL" -b "BACK"
        fi
        button_result=$?
        if [ $button_result -eq 0 ]; then
            install_item "$category" "$actual_base_name"
            if [ $ERROR_RETURN_TO_MAIN -eq 1 ]; then
                ERROR_RETURN_TO_MAIN=0
                return 1
            fi
        fi
    fi
    return 0
}

install_item() {
    local category="$1"
    local base_name="$2"
    local install_location="Tools"  # Default is Tools
    local desc_file="$PAKUI_DIR/$category/$base_name.txt"
    
    # Create a clean display name for user messages
    local display_name=$(clean_display_name "$base_name")
    
    # Check for special installation types
    if is_dual_install_pak "$category" "$base_name"; then
        desc_file="$PAKUI_DIR/$category/$base_name.dual.txt"
        "$SHOW_MESSAGE" "Choose install location|for $display_name:" -l ab -a "Tools" -b "Roms"
        button_result=$?
        if [ $button_result -eq 2 ]; then
            install_location="Roms"
        else
            install_location="Tools"
        fi
    elif is_roms_only_pak "$category" "$base_name"; then
        desc_file="$PAKUI_DIR/$category/$base_name.roms.txt"
        install_location="Roms"  # Force Roms installation without prompting
    elif [ ! -f "$desc_file" ]; then
        "$SHOW_MESSAGE" "Error: Cannot find description|for $display_name in $category" -l a
        ERROR_RETURN_TO_MAIN=1
        return 1
    fi
    
    "$SHOW_MESSAGE" "Installing $display_name..." &
    message_pid=$!
    local source=$(find_companion "$PAKUI_DIR/$category" "$base_name")
    if [ -z "$source" ]; then
        kill $message_pid 2>/dev/null
        "$SHOW_MESSAGE" "Error: Source file not found|for $display_name" -l a
        ERROR_RETURN_TO_MAIN=1
        return 1
    fi
    comp_name="$(basename "$source")"
    
    # Set target directory based on installation location
    if [ "$install_location" = "Roms" ]; then
        TARGET_DIR="$ROMS_DIR"
    else
        TARGET_DIR="$TOOLS_DIR"
    fi
    
    # Check if already exists in either location
    if [ -e "$TOOLS_DIR/$comp_name" ] || [ -e "$ROMS_DIR/$comp_name" ]; then
        kill $message_pid 2>/dev/null
        
        # Determine the current location
        if [ -e "$TOOLS_DIR/$comp_name" ]; then
            current_location="Tools"
            current_path="$TOOLS_DIR/$comp_name"
        else
            current_location="Roms"
            current_path="$ROMS_DIR/$comp_name"
        fi
        
        if [ "$current_location" = "$install_location" ]; then
            "$SHOW_MESSAGE" "$display_name already exists in $current_location|Do you want to update it?" -l ab -a "YES" -b "NO"
        else
            "$SHOW_MESSAGE" "$display_name already exists in $current_location|Move to $install_location?" -l ab -a "YES" -b "NO"
        fi
        
        button_result=$?
        if [ $button_result -eq 0 ]; then
            "$SHOW_MESSAGE" "Updating $display_name..." &
            message_pid=$!
            rm -rf "$current_path"
            mv "$source" "$TARGET_DIR/"
            if [ -e "$TARGET_DIR/$comp_name" ]; then
                kill $message_pid 2>/dev/null
                # Update or add installation record
                sed -i "/^$category|$base_name|/d" "$PAKS_INSTALL_FILE"
                echo "$category|$base_name|$install_location" >> "$PAKS_INSTALL_FILE"
                "$SHOW_MESSAGE" "Successfully moved/updated|$display_name|to $install_location" -l a
                return 0
            else
                kill $message_pid 2>/dev/null
                "$SHOW_MESSAGE" "Error updating|$display_name" -l a
                ERROR_RETURN_TO_MAIN=1
                return 1
            fi
        else
            "$SHOW_MESSAGE" "Update cancelled|$display_name" -l a
            return 0
        fi
    fi
    
    # Perform the installation
    mv "$source" "$TARGET_DIR/"
    if [ -e "$TARGET_DIR/$comp_name" ]; then
        kill $message_pid 2>/dev/null
        # Add installation record with location
        echo "$category|$base_name|$install_location" >> "$PAKS_INSTALL_FILE"
        "$SHOW_MESSAGE" "Successfully installed|$display_name|to $install_location" -l a
        return 0
    else
        kill $message_pid 2>/dev/null
        "$SHOW_MESSAGE" "Error installing|$display_name" -l a
        ERROR_RETURN_TO_MAIN=1
        return 1
    fi
}

uninstall_item() {
    local category="$1"
    local base_name="$2"
    local desc_file="$PAKUI_DIR/$category/$base_name.txt"
    
    # Create a clean display name for user messages
    local display_name=$(clean_display_name "$base_name")
    
    # Check for different description file types
    if [ ! -f "$desc_file" ]; then
        if [ -f "$PAKUI_DIR/$category/$base_name.dual.txt" ]; then
            desc_file="$PAKUI_DIR/$category/$base_name.dual.txt"
        elif [ -f "$PAKUI_DIR/$category/$base_name.roms.txt" ]; then
            desc_file="$PAKUI_DIR/$category/$base_name.roms.txt"
        else
            "$SHOW_MESSAGE" "Error: Cannot find description|for $display_name in $category" -l a
            ERROR_RETURN_TO_MAIN=1
            return 1
        fi
    fi
    
    "$SHOW_MESSAGE" "Uninstalling $display_name..." &
    message_pid=$!
    
    # Determine current installation location
    local location=$(get_pak_location "$category" "$base_name")
    if [ "$location" = "Roms" ]; then
        INSTALL_DIR="$ROMS_DIR"
    else
        INSTALL_DIR="$TOOLS_DIR"
    fi
    
    local found_file=$(find_companion "$INSTALL_DIR" "$base_name")
    if [ -z "$found_file" ]; then
        kill $message_pid 2>/dev/null
        "$SHOW_MESSAGE" "File not found: $display_name|Cannot uninstall from $location" -l a
        ERROR_RETURN_TO_MAIN=1
        return 1
    fi
    
    local dest_path="$PAKUI_DIR/$category/$(basename "$found_file")"
    mv "$found_file" "$dest_path"
    if [ -e "$INSTALL_DIR/$(basename "$found_file")" ]; then
        kill $message_pid 2>/dev/null
        "$SHOW_MESSAGE" "Error uninstalling|$display_name from $location" -l a
        ERROR_RETURN_TO_MAIN=1
        return 1
    else
        kill $message_pid 2>/dev/null
        sed -i "/^$category|$base_name|/d" "$PAKS_INSTALL_FILE"
        "$SHOW_MESSAGE" "Successfully uninstalled|$display_name from $location" -l a
        return 0
    fi
}

sync_install_file() {
    local temp_file=$(mktemp)
    
    if [ -f "$PAKS_INSTALL_FILE" ]; then
        while IFS='|' read -r category pakname location; do
            if [ -n "$category" ] && [ -n "$pakname" ]; then
                # Check if it exists in the specified location
                if [ "$location" = "Roms" ]; then
                    INSTALL_DIR="$ROMS_DIR"
                else
                    INSTALL_DIR="$TOOLS_DIR"
                    location="Tools" # Default to Tools for older entries
                fi
                
                if ! check_file_exists "$PAKUI_DIR/$category" "$pakname" && check_file_exists "$INSTALL_DIR" "$pakname"; then
                    echo "$category|$pakname|$location" >> "$temp_file"
                fi
            fi
        done < "$PAKS_INSTALL_FILE"
    fi
    
    # Check for files that might be installed but not in the install file
    for category_dir in "$PAKUI_DIR"/*/; do
        category="$(basename "$category_dir")"
        for txt_file in "$category_dir"/*.txt; do
            [ -f "$txt_file" ] || continue
            txt_base="$(basename "$txt_file" .txt)"
            
            # Check if it's a dual install file or roms-only file
            if [ "${txt_base%.dual}" != "$txt_base" ]; then
                txt_base="${txt_base%.dual}"
            elif [ "${txt_base%.roms}" != "$txt_base" ]; then
                txt_base="${txt_base%.roms}"
            fi
            
            # Check Tools
            if ! check_file_exists "$PAKUI_DIR/$category" "$txt_base" && check_file_exists "$TOOLS_DIR" "$txt_base"; then
                if ! grep -q "^$category|$txt_base|" "$temp_file"; then
                    echo "$category|$txt_base|Tools" >> "$temp_file"
                fi
            fi
            
            # Check Roms
            if ! check_file_exists "$PAKUI_DIR/$category" "$txt_base" && check_file_exists "$ROMS_DIR" "$txt_base"; then
                if ! grep -q "^$category|$txt_base|" "$temp_file"; then
                    echo "$category|$txt_base|Roms" >> "$temp_file"
                fi
            fi
        done
    done
    
    mv "$temp_file" "$PAKS_INSTALL_FILE"
}

# Create Roms directory if it doesn't exist
if [ ! -d "$ROMS_DIR" ]; then
    mkdir -p "$ROMS_DIR"
fi

sync_install_file

if [ -f "$PAKUI_DIR/welcome.png" ]; then
    show.elf "$PAKUI_DIR/welcome.png" &
    sleep 2
    killall show.elf 2>/dev/null
fi

if [ -f "$WELCOME_FILE" ] && [ ! -f "$WELCOME_OFF_FILE" ]; then
    WELCOME_TEXT=$(cat "$WELCOME_FILE")
    "$SHOW_MESSAGE" "$WELCOME_TEXT" -l ab -a "OK" -b "HIDE"
    button_result=$?
    if [ $button_result -eq 2 ]; then
        mv "$WELCOME_FILE" "$WELCOME_OFF_FILE"
        "$SHOW_MESSAGE" "Welcome message hidden|You can re-enable it from|the manager info screen" -l a
    fi
elif [ ! -f "$WELCOME_FILE" ] && [ ! -f "$WELCOME_OFF_FILE" ]; then
    echo "Welcome to $DISPLAY_NAME!|Manage your packages with ease.|Install or uninstall with a click." > "$WELCOME_FILE"
    "$SHOW_MESSAGE" "Welcome to $DISPLAY_NAME!|Manage your packages with ease.|Install or uninstall with a click." -l ab -a "OK" -b "HIDE"
    button_result=$?
    if [ $button_result -eq 2 ]; then
        mv "$WELCOME_FILE" "$WELCOME_OFF_FILE"
        "$SHOW_MESSAGE" "Welcome message hidden|You can re-enable it from|the manager info screen" -l a
    fi
fi

main_idx=0
create_main_menu

while true; do
    selection=$("$PICKER" "$MAIN_MENU" -i $main_idx -b "EXIT")
    status=$?
    if [ -n "$selection" ]; then
        main_idx=$(grep -n "^$selection$" "$MAIN_MENU" | cut -d: -f1 || echo "0")
        main_idx=$((main_idx - 1))
        [ $main_idx -lt 0 ] && main_idx=0
    fi
    [ $status -eq 1 ] || [ -z "$selection" ] && exit 0
    action=$(echo "$selection" | cut -d'|' -f3)
    case "$action" in
        header)
            create_main_menu
            show_header_info
            ;;
        category)
            category=$(echo "$selection" | cut -d'|' -f2)
            create_category_menu "$category"
            category_loop=1
            menu_needs_update=0
            category_idx=0
            while [ $category_loop -eq 1 ]; do
                item_sel=$("$PICKER" "$TEMP_MENU" -i $category_idx -b "BACK")
                item_status=$?
                if [ -n "$item_sel" ]; then
                    category_idx=$(grep -n "^$item_sel$" "$TEMP_MENU" | cut -d: -f1 || echo "0")
                    category_idx=$((category_idx - 1))
                    [ $category_idx -lt 0 ] && category_idx=0
                fi
                if [ $item_status -eq 1 ] || [ -z "$item_sel" ]; then
                    category_loop=0
                    if [ $menu_needs_update -eq 1 ]; then
                        create_main_menu
                    fi
                    continue
                fi
                item_action=$(echo "$item_sel" | cut -d'|' -f3)
                case "$item_action" in
                    installed|available)
                        item_name=$(echo "$item_sel" | cut -d'|' -f2)
                        display_name=$(echo "$item_sel" | cut -d'|' -f1 | sed 's/ \[INSTALLED.*\]$//')
                        actual_name=$(echo "$item_sel" | cut -d'|' -f4)
                        if ! show_item_info "$category" "$display_name" "$item_action" "$actual_name"; then
                            category_loop=0
                            create_main_menu
                            break
                        fi
                        create_category_menu "$category"
                        menu_needs_update=1
                        ;;
                    none)
                        "$SHOW_MESSAGE" "No items in this category" -l a
                        category_loop=0
                        break
                        ;;
                esac
            done
            ;;
        none)
            "$SHOW_MESSAGE" "No categories found" -l a
            ;;
    esac
done