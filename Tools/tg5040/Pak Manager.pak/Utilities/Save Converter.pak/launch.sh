#!/bin/sh
cd "$(dirname "$0")"
export LD_LIBRARY_PATH=/usr/trimui/lib:$LD_LIBRARY_PATH
PLATFORM=$(basename "$(dirname "$(dirname "$0")")")
SDCARD="/mnt/SDCARD"
MINUI_SAVES_DIR="$SDCARD/Saves"
RETROARCH_SAVES="$SDCARD/Tools/$PLATFORM/RetroArch.pak/.retroarch/saves"
ROMS_DIR="$SDCARD/Roms"
RETROARCH_BACKUP="$MINUI_SAVES_DIR/RetroArch"
TEMP_DIR="/tmp/save_converter"
CURRENT_SOURCE="MinUI"
mkdir -p "$RETROARCH_BACKUP"
mkdir -p "$TEMP_DIR"
cleanup() {
    rm -f "$TEMP_DIR"/*
    rm -f /tmp/keyboard_output.txt /tmp/picker_output.txt
}
handle_exit() {
    ./show_message "Exiting..." -d 1
    cleanup
    exit 0
}
convert_save() {
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
            local rom_ext
            rom_ext=$(echo "$matching_rom" | rev | cut -d'.' -f1 | rev)
            mkdir -p "$MINUI_SAVES_DIR/$emulator_tag"
            local minui_save="$MINUI_SAVES_DIR/$emulator_tag/$base_name.$rom_ext.sav"
            cp "$srm_file" "$minui_save"
            if [ "$CURRENT_SOURCE" = "MinUI" ]; then
                mv "$srm_file" "$RETROARCH_BACKUP/"
            else
                cp "$srm_file" "$RETROARCH_BACKUP/"
            fi
            echo "$base_name.srm → $base_name.$rom_ext.sav ($emulator_tag)" >> "$TEMP_DIR/results.txt"
            converted=1
        fi
    done < <(find "$ROMS_DIR" -type d -name "*(*)" -print0)
    if [ $converted -eq 0 ]; then
        echo "No match: $base_name.srm" >> "$TEMP_DIR/results.txt"
        return 1
    fi
    return 0
}
find_retroarch_saves() {
    > "$TEMP_DIR/saves.txt"
    ./show_message "Finding RetroArch saves..." -d 1
    find "$RETROARCH_SAVES" -type f -name "*.srm" | while read srm_file; do
        base_name=$(basename "$srm_file")
        echo "$base_name|$srm_file" >> "$TEMP_DIR/saves.txt"
    done
    if [ ! -s "$TEMP_DIR/saves.txt" ]; then
        ./show_message "No RetroArch saves found" -l a
        return 1
    fi
    return 0
}
find_minui_saves() {
    > "$TEMP_DIR/saves.txt"
    ./show_message "Finding MinUI saves..." -d 1
    find "$MINUI_SAVES_DIR" -maxdepth 1 -type f -name "*.srm" | while read srm_file; do
        base_name=$(basename "$srm_file")
        echo "$base_name|$srm_file" >> "$TEMP_DIR/saves.txt"
    done
    if [ ! -s "$TEMP_DIR/saves.txt" ]; then
        ./show_message "No MinUI saves found" -l a
        return 1
    fi
    return 0
}
convert_all() {
    > "$TEMP_DIR/results.txt"
    ./show_message "Converting all saves..." -d 1
    local converted=0
    local total=0
    while read line; do
        srm_file=$(echo "$line" | cut -d'|' -f2)
        total=$((total + 1))
        if convert_save "$srm_file"; then
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
convert_one() {
    if [ ! -s "$TEMP_DIR/saves.txt" ]; then
        if [ "$CURRENT_SOURCE" = "RetroArch" ]; then
            if ! find_retroarch_saves; then
                return 1
            fi
        else
            if ! find_minui_saves; then
                return 1
            fi
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
    if convert_save "$srm_file"; then
        ./show_message "Converted successfully" -l a
    else
        ./show_message "No matching ROM found" -l a
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
browse_roms() {
    > "$TEMP_DIR/rom_dirs.txt"
    ./show_message "Finding ROM folders..." -d 1
    for rom_dir in $(find "$ROMS_DIR" -type d -name "*(*)" 2>/dev/null); do
        dir_name=$(basename "$rom_dir")
        echo "$dir_name|$rom_dir" >> "$TEMP_DIR/rom_dirs.txt"
    done
    if [ ! -s "$TEMP_DIR/rom_dirs.txt" ]; then
        ./show_message "No ROM folders found" -l a
        return 1
    fi
    rom_dir_output=$(./picker "$TEMP_DIR/rom_dirs.txt" -a "SELECT" -b "BACK")
    rom_dir_status=$?
    if [ $rom_dir_status -ne 0 ]; then
        return 1
    fi
    rom_dir=$(echo "$rom_dir_output" | cut -d'|' -f2)
    dir_name=$(echo "$rom_dir_output" | cut -d'|' -f1)
    > "$TEMP_DIR/roms.txt"
    ./show_message "Listing ROMs..." -d 1
    find "$rom_dir" -type f -not -path "*/\.*" | sort | while read rom_file; do
        base_name=$(basename "$rom_file")
        echo "$base_name|$rom_file" >> "$TEMP_DIR/roms.txt"
    done
    if [ ! -s "$TEMP_DIR/roms.txt" ]; then
        ./show_message "No ROMs found" -l a
        return 1
    fi
    ./picker "$TEMP_DIR/roms.txt" -a "OK" -b "BACK"
    return 0
}
toggle_source() {
    if [ "$CURRENT_SOURCE" = "RetroArch" ]; then
        CURRENT_SOURCE="MinUI"
        ./show_message "Source: MinUI Saves Folder" -l a
    else
        CURRENT_SOURCE="RetroArch"
        ./show_message "Source: RetroArch Saves Folder" -l a
    fi
    rm -f "$TEMP_DIR/saves.txt"
    return 0
}
main_menu_idx=0
while true; do
    > "$TEMP_DIR/menu.txt"
    echo "Save Converter|title" > "$TEMP_DIR/menu.txt"
    echo "Source: $CURRENT_SOURCE Saves Folder|toggle_source" >> "$TEMP_DIR/menu.txt"
    echo "Convert All Saves|convert_all" >> "$TEMP_DIR/menu.txt"
    echo "Select Save to Convert|select_one" >> "$TEMP_DIR/menu.txt"
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
            ./show_message "srm to sav converter" -l a
            ;;
        "toggle_source")
            toggle_source
            ;;
        "convert_all")
            if [ "$CURRENT_SOURCE" = "RetroArch" ]; then
                if find_retroarch_saves; then
                    ./show_message "Convert all RetroArch saves?" -l ab -a "YES" -b "NO"
                    if [ $? -eq 0 ]; then
                        convert_all
                    fi
                fi
            else
                if find_minui_saves; then
                    ./show_message "Convert all MinUI saves?" -l ab -a "YES" -b "NO"
                    if [ $? -eq 0 ]; then
                        convert_all
                    fi
                fi
            fi
            ;;
        "select_one")
            convert_one
            ;;
        "view_results")
            view_results
            ;;
    esac
done
cleanup
exit 0