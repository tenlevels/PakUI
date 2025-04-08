#!/bin/sh
cd "$(dirname "$0")"
export LD_LIBRARY_PATH=/usr/trimui/lib:$LD_LIBRARY_PATH
PLATFORM=$(basename "$(dirname "$(dirname "$0")")")
SDCARD="/mnt/SDCARD"
MINUI_SAVES_DIR="$SDCARD/Saves"
RETROARCH_DIR="$SDCARD/Saves/RETROARCH"
RETROARCH_ORIGINAL="$RETROARCH_DIR/ra_original"
MINUI_ORIGINAL="$RETROARCH_DIR/min_original"
MINUI_CONVERTED="$RETROARCH_DIR/min_converted_to_ra"
ROMS_DIR="$SDCARD/Roms"
TEMP_DIR="/tmp/save_converter"
CURRENT_MODE="RA_TO_MINUI"
CONFIG_DIR="$SDCARD/.userdata/shared"
SRM_CONFIG_FILE="$CONFIG_DIR/use_srm_saves"

mkdir -p "$RETROARCH_DIR"
mkdir -p "$RETROARCH_ORIGINAL"
mkdir -p "$MINUI_ORIGINAL"
mkdir -p "$MINUI_CONVERTED"
mkdir -p "$TEMP_DIR"
mkdir -p "$CONFIG_DIR"

cleanup() {
    rm -f "$TEMP_DIR"/*
    rm -f /tmp/keyboard_output.txt /tmp/picker_output.txt
}

handle_exit() {
    ./show_message "Exiting..." -d 1
    cleanup
    exit 0
}

toggle_minarch_srm_mode() {
    if [ -f "$SRM_CONFIG_FILE" ]; then
        rm -f "$SRM_CONFIG_FILE"
        ./show_message "Now using SAV saves" -l a
    else
        touch "$SRM_CONFIG_FILE"
        ./show_message "Now using SRM saves|(requires Sleep Mode Fork)" -l a
    fi
}

convert_ra_to_minui() {
    local srm_file="$1"
    local base_name
    base_name=$(basename "$srm_file" .srm)
    local converted=0
    
    ./show_message "Converting $base_name..." -d 1
    
    while IFS= read -r -d '' rom_dir; do
        local emulator_tag
        emulator_tag=$(echo "$rom_dir" | grep -o "([^)]*)" | tr -d "()")
        local matching_rom
        matching_rom=$(find "$rom_dir" -type f -name "$base_name.*" | head -n 1)
        
        if [ -n "$matching_rom" ]; then
            local rom_base
            rom_base=$(basename "$matching_rom")
            mkdir -p "$MINUI_SAVES_DIR/$emulator_tag"
            local minui_save="$MINUI_SAVES_DIR/$emulator_tag/$rom_base.sav"
            
            mkdir -p "$RETROARCH_ORIGINAL"
            cp "$srm_file" "$RETROARCH_ORIGINAL/"
            
            cp "$srm_file" "$minui_save"
            echo "$base_name.srm → $rom_base.sav ($emulator_tag)" >> "$TEMP_DIR/results.txt"
            converted=1
        fi
    done < <(find "$ROMS_DIR" -type d -name "*(*)" -print0)
    
    if [ $converted -eq 1 ]; then
        rm -f "$srm_file"
    else
        echo "No match: $base_name.srm" >> "$TEMP_DIR/results.txt"
        return 1
    fi
    
    return 0
}

convert_minui_to_ra() {
    local sav_file="$1"
    local emu_tag="$2"
    local rom_base=$(basename "$sav_file" .sav)
    local rom_name="${rom_base%.*}"
    
    ./show_message "Converting $rom_base..." -d 1
    
    mkdir -p "$MINUI_ORIGINAL/$emu_tag"
    cp "$sav_file" "$MINUI_ORIGINAL/$emu_tag/"
    
    mkdir -p "$MINUI_CONVERTED"
    local ra_srm="$MINUI_CONVERTED/$rom_name.srm"
    cp "$sav_file" "$ra_srm"
    
    echo "$rom_base.sav ($emu_tag) → $rom_name.srm" >> "$TEMP_DIR/results.txt"
    return 0
}

find_retroarch_saves() {
    > "$TEMP_DIR/saves.txt"
    ./show_message "Finding RetroArch saves..." -d 1
    
    find "$RETROARCH_DIR" -maxdepth 1 -type f -name "*.srm" | while read srm_file; do
        base_name=$(basename "$srm_file")
        echo "$base_name|$srm_file" >> "$TEMP_DIR/saves.txt"
    done
    
    if [ ! -s "$TEMP_DIR/saves.txt" ]; then
        ./show_message "No saves found in RETROARCH folder" -l a
        return 1
    fi
    
    return 0
}

find_minui_saves() {
    > "$TEMP_DIR/emu_dirs.txt"
    > "$TEMP_DIR/saves.txt"
    ./show_message "Finding MinUI emulator folders..." -d 1
    
    for emu_dir in $(find "$MINUI_SAVES_DIR" -mindepth 1 -maxdepth 1 -type d -not -path "*/RETROARCH" 2>/dev/null); do
        emu_name=$(basename "$emu_dir")
        echo "$emu_name|$emu_dir" >> "$TEMP_DIR/emu_dirs.txt"
        
        find "$emu_dir" -type f -name "*.sav" | while read sav_file; do
            sav_name=$(basename "$sav_file")
            echo "$sav_name ($emu_name)|$sav_file|$emu_name" >> "$TEMP_DIR/saves.txt"
        done
    done
    
    if [ ! -s "$TEMP_DIR/saves.txt" ]; then
        ./show_message "No MinUI save files found" -l a
        return 1
    fi
    
    return 0
}

convert_all_ra_to_minui() {
    > "$TEMP_DIR/results.txt"
    ./show_message "Converting all RetroArch saves..." -d 1
    
    local converted=0
    local total=0
    
    while read line; do
        srm_file=$(echo "$line" | cut -d'|' -f2)
        total=$((total + 1))
        if convert_ra_to_minui "$srm_file"; then
            converted=$((converted + 1))
        fi
    done < "$TEMP_DIR/saves.txt"
    
    if [ $converted -eq 0 ]; then
        ./show_message "No saves converted" -l a
    else
        ./show_message "$converted of $total saves converted" -l a
    fi
    
    return 0
}

convert_all_minui_to_ra() {
    > "$TEMP_DIR/results.txt"
    ./show_message "Converting all MinUI saves..." -d 1
    
    local converted=0
    local total=0
    
    while read line; do
        sav_file=$(echo "$line" | cut -d'|' -f2)
        emu_tag=$(echo "$line" | cut -d'|' -f3)
        total=$((total + 1))
        if convert_minui_to_ra "$sav_file" "$emu_tag"; then
            converted=$((converted + 1))
        fi
    done < "$TEMP_DIR/saves.txt"
    
    if [ $converted -eq 0 ]; then
        ./show_message "No saves converted" -l a
    else
        ./show_message "$converted of $total saves converted" -l a
    fi
    
    return 0
}

convert_one_ra_to_minui() {
    if [ ! -s "$TEMP_DIR/saves.txt" ]; then
        if ! find_retroarch_saves; then
            return 1
        fi
    fi
    
    save_output=$(./picker "$TEMP_DIR/saves.txt" -a "SELECT" -b "BACK")
    save_status=$?
    
    if [ $save_status -ne 0 ]; then
        return 1
    fi
    
    srm_file=$(echo "$save_output" | cut -d'|' -f2)
    base_name=$(basename "$srm_file" .srm)
    
    > "$TEMP_DIR/results.txt"
    
    if convert_ra_to_minui "$srm_file"; then
        ./show_message "Converted successfully" -l a
    else
        ./show_message "No matching ROM found" -l a
    fi
    
    return 0
}

convert_one_minui_to_ra() {
    if [ ! -s "$TEMP_DIR/saves.txt" ]; then
        if ! find_minui_saves; then
            return 1
        fi
    fi
    
    save_output=$(./picker "$TEMP_DIR/saves.txt" -a "SELECT" -b "BACK")
    save_status=$?
    
    if [ $save_status -ne 0 ]; then
        return 1
    fi
    
    sav_file=$(echo "$save_output" | cut -d'|' -f2)
    emu_tag=$(echo "$save_output" | cut -d'|' -f3)
    
    > "$TEMP_DIR/results.txt"
    
    if convert_minui_to_ra "$sav_file" "$emu_tag"; then
        ./show_message "Converted successfully" -l a
    else
        ./show_message "Conversion failed" -l a
    fi
    
    return 0
}

view_results() {
    if [ ! -s "$TEMP_DIR/results.txt" ]; then
        ./show_message "No results available" -l a
        return 1
    fi
    
    > "$TEMP_DIR/results_view.txt"
    cat "$TEMP_DIR/results.txt" | while read line; do
        echo "$line|dummy" >> "$TEMP_DIR/results_view.txt"
    done
    
    ./picker "$TEMP_DIR/results_view.txt" -a "OK" -b "BACK"
    return 0
}

toggle_mode() {
    if [ "$CURRENT_MODE" = "RA_TO_MINUI" ]; then
        CURRENT_MODE="MINUI_TO_RA"
        ./show_message "Mode: MinUI to RetroArch" -l a
    else
        CURRENT_MODE="RA_TO_MINUI"
        ./show_message "Mode: RetroArch to MinUI" -l a
    fi
    rm -f "$TEMP_DIR/saves.txt"
    return 0
}

main_menu_idx=0
while true; do
    > "$TEMP_DIR/menu.txt"
    echo "Save Converter|title" > "$TEMP_DIR/menu.txt"
    
    if [ "$CURRENT_MODE" = "RA_TO_MINUI" ]; then
        echo "Mode: RetroArch to MinUI|toggle_mode" >> "$TEMP_DIR/menu.txt"
        echo "Convert All RetroArch Saves|convert_all" >> "$TEMP_DIR/menu.txt"
        echo "Select RetroArch Save to Convert|select_one" >> "$TEMP_DIR/menu.txt"
    else
        echo "Mode: MinUI to RetroArch|toggle_mode" >> "$TEMP_DIR/menu.txt"
        echo "Convert All MinUI Saves|convert_all" >> "$TEMP_DIR/menu.txt"
        echo "Select MinUI Save to Convert|select_one" >> "$TEMP_DIR/menu.txt"
    fi
    
    if [ -f "$SRM_CONFIG_FILE" ]; then
        echo "Use SAV saves|toggle_minarch_srm" >> "$TEMP_DIR/menu.txt"
    else
        echo "Use SRM saves|toggle_minarch_srm" >> "$TEMP_DIR/menu.txt"
    fi
    
    echo "View Results|view_results" >> "$TEMP_DIR/menu.txt"
    
    picker_output=$(./picker "$TEMP_DIR/menu.txt" -i $main_menu_idx -a "SELECT" -b "EXIT")
    picker_status=$?
    
    if [ $picker_status -ne 0 ]; then
        handle_exit
    fi
    
    main_menu_idx=$(grep -n "^${picker_output%$'\n'}$" "$TEMP_DIR/menu.txt" | cut -d: -f1)
    main_menu_idx=$((main_menu_idx - 1))
    
    option=$(echo "$picker_output" | cut -d'|' -f2)
    
    case "$option" in
        "title")
            if [ "$CURRENT_MODE" = "RA_TO_MINUI" ]; then
                ./show_message "RetroArch to MinUI Save Converter" -l a
            else
                ./show_message "MinUI to RetroArch Save Converter" -l a
            fi
            ;;
        "toggle_mode")
            toggle_mode
            ;;
        "convert_all")
            if [ "$CURRENT_MODE" = "RA_TO_MINUI" ]; then
                if find_retroarch_saves; then
                    ./show_message "Convert all RetroArch saves?" -l ab -a "YES" -b "NO"
                    if [ $? -eq 0 ]; then
                        convert_all_ra_to_minui
                    fi
                fi
            else
                if find_minui_saves; then
                    ./show_message "Convert all MinUI saves?" -l ab -a "YES" -b "NO"
                    if [ $? -eq 0 ]; then
                        convert_all_minui_to_ra
                    fi
                fi
            fi
            ;;
        "select_one")
            if [ "$CURRENT_MODE" = "RA_TO_MINUI" ]; then
                convert_one_ra_to_minui
            else
                convert_one_minui_to_ra
            fi
            ;;
        "toggle_minarch_srm")
            toggle_minarch_srm_mode
            ;;
        "view_results")
            view_results
            ;;
    esac
done

cleanup
exit 0