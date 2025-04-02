#!/bin/sh

TEMP_MENU="/tmp/psx_menu.txt"
trap 'rm -f "$TEMP_MENU"' EXIT

cd "$(dirname "$0")"
export LD_LIBRARY_PATH="/usr/trimui/lib:$LD_LIBRARY_PATH"

BASE_DIR="/mnt/SDCARD/Roms"
PICKER="./picker"
SHOW_MESSAGE="./show_message"

ensure_unique_folder() {
    local base_folder="$1"
    local suffix=2
    local test_folder="$base_folder"
    
    while [ -d "$test_folder" ]; do
        test_folder="${base_folder} ($suffix)"
        suffix=$((suffix + 1))
    done
    
    echo "$test_folder"
}

generate_cue_file() {
    local bin_file="$1"
    local base_name="${bin_file%.*}"
    local cue_file="${base_name}.cue"
    local bin_basename=$(basename "$bin_file")
    
    if [ ! -f "$cue_file" ]; then
        echo "FILE \"$bin_basename\" BINARY" > "$cue_file"
        echo "  TRACK 01 MODE2/2352" >> "$cue_file"
        echo "    INDEX 01 00:00:00" >> "$cue_file"
    fi
}

find_ps_directory() {
    PS_DIR=$(find "$BASE_DIR" -type d -name "*PS*" | grep "(PS)" | head -n 1)
    if [ -z "$PS_DIR" ]; then
        "$SHOW_MESSAGE" "Error: PlayStation directory not found.|Make sure you have a (PS) folder in Roms directory." -l a
        exit 1
    fi
    PS_DIR_NAME=$(basename "$PS_DIR")
}

count_multi_disc_chd_games() {
    local count=0
    
    for disc1 in "$PS_DIR"/*[Dd]isc*1*.chd; do
        if [ -f "$disc1" ]; then
            count=$((count + 1))
        fi
    done
    
    for disc1 in "$PS_DIR"/*\(1\)*.chd; do
        if [ -f "$disc1" ]; then
            count=$((count + 1))
        fi
    done
    
    echo "$count"
}

count_multi_disc_cue_games() {
    local count=0
    
    for disc1 in "$PS_DIR"/*[Dd]isc*1*.cue; do
        if [ -f "$disc1" ]; then
            count=$((count + 1))
        fi
    done
    
    for disc1 in "$PS_DIR"/*\(1\)*.cue; do
        if [ -f "$disc1" ]; then
            count=$((count + 1))
        fi
    done
    
    echo "$count"
}

count_missing_cue_files() {
    local count=0
    
    for bin_file in "$PS_DIR"/*.bin; do
        if [ -f "$bin_file" ]; then
            cue_file="${bin_file%.bin}.cue"
            if [ ! -f "$cue_file" ]; then
                count=$((count + 1))
            fi
        fi
    done
    
    for folder in "$PS_DIR"/*/ ; do
        if [ -d "$folder" ]; then
            for bin_file in "$folder"/*.bin; do
                if [ -f "$bin_file" ]; then
                    cue_file="${bin_file%.bin}.cue"
                    if [ ! -f "$cue_file" ]; then
                        count=$((count + 1))
                    fi
                fi
            done
        fi
    done
    
    echo "$count"
}

organize_chd_disc_games() {
    "$SHOW_MESSAGE" "Organizing CHD disc games..." &
    message_pid=$!
    
    local count=0
    
    for disc1 in "$PS_DIR"/*[Dd]isc*1*.chd; do
        if [ ! -f "$disc1" ]; then
            continue
        fi
        
        disc_filename=$(basename "$disc1")
        base_name=$(echo "$disc_filename" | sed -e 's/ ([Dd]isc [0-9][^)]*)//')
        base_name=${base_name%.chd}
        
        folder_name="$PS_DIR/$base_name"
        if [ -d "$folder_name" ] && [ -f "$folder_name/$base_name.m3u" ]; then
            if ls "$folder_name"/*.cue >/dev/null 2>&1 || ls "$folder_name"/*.bin >/dev/null 2>&1; then
                folder_name=$(ensure_unique_folder "$folder_name")
                base_name=$(basename "$folder_name")
            fi
        fi
        
        mkdir -p "$folder_name"
        
        m3u_file="$folder_name/$base_name.m3u"
        : > "$m3u_file"
        
        for disc in "$PS_DIR"/*[Dd]isc*.chd; do
            if [ -f "$disc" ]; then
                this_disc=$(basename "$disc")
                this_base=$(echo "$this_disc" | sed -e 's/ ([Dd]isc [0-9][^)]*)//')
                this_base=${this_base%.chd}
                
                if [ "$this_base" = "$base_name" ]; then
                    echo "$this_disc" >> "$m3u_file"
                    
                    if [ "$disc" != "$folder_name/$this_disc" ]; then
                        mv "$disc" "$folder_name/"
                        count=$((count + 1))
                    fi
                fi
            fi
        done
    done
    
    for disc1 in "$PS_DIR"/*\(1\)*.chd; do
        if [ ! -f "$disc1" ]; then
            continue
        fi
        
        disc_filename=$(basename "$disc1")
        base_name=$(echo "$disc_filename" | sed -e 's/ *([0-9])//')
        base_name=${base_name%.chd}
        
        folder_name="$PS_DIR/$base_name"
        if [ -d "$folder_name" ] && [ -f "$folder_name/$base_name.m3u" ]; then
            if ls "$folder_name"/*.cue >/dev/null 2>&1 || ls "$folder_name"/*.bin >/dev/null 2>&1; then
                folder_name=$(ensure_unique_folder "$folder_name")
                base_name=$(basename "$folder_name")
            fi
        fi
        
        mkdir -p "$folder_name"
        
        m3u_file="$folder_name/$base_name.m3u"
        : > "$m3u_file"
        
        for disc in "$PS_DIR"/*\([0-9]\)*.chd; do
            if [ -f "$disc" ]; then
                this_disc=$(basename "$disc")
                this_base=$(echo "$this_disc" | sed -e 's/ *([0-9])//')
                this_base=${this_base%.chd}
                
                if [ "$this_base" = "$base_name" ]; then
                    echo "$this_disc" >> "$m3u_file"
                    
                    if [ "$disc" != "$folder_name/$this_disc" ]; then
                        mv "$disc" "$folder_name/"
                        count=$((count + 1))
                    fi
                fi
            fi
        done
    done
    
    kill $message_pid 2>/dev/null
    
    if [ $count -gt 0 ]; then
        "$SHOW_MESSAGE" "Organized $count CHD game files into folders." -l a
    else
        "$SHOW_MESSAGE" "No CHD files to organize." -l a
    fi
}

generate_missing_cue_files() {
    "$SHOW_MESSAGE" "Generating missing CUE files..." &
    message_pid=$!
    
    local count=0
    
    for bin_file in "$PS_DIR"/*.bin; do
        if [ -f "$bin_file" ]; then
            cue_file="${bin_file%.bin}.cue"
            if [ ! -f "$cue_file" ]; then
                generate_cue_file "$bin_file"
                count=$((count + 1))
            fi
        fi
    done
    
    for folder in "$PS_DIR"/*/ ; do
        if [ -d "$folder" ]; then
            for bin_file in "$folder"/*.bin; do
                if [ -f "$bin_file" ]; then
                    cue_file="${bin_file%.bin}.cue"
                    if [ ! -f "$cue_file" ]; then
                        generate_cue_file "$bin_file"
                        count=$((count + 1))
                    fi
                fi
            done
        fi
    done
    
    kill $message_pid 2>/dev/null
    
    if [ $count -gt 0 ]; then
        "$SHOW_MESSAGE" "Generated $count missing CUE files." -l a
    else
        "$SHOW_MESSAGE" "No missing CUE files found." -l a
    fi
}

organize_cue_disc_games() {
    "$SHOW_MESSAGE" "Organizing BIN/CUE disc games..." &
    message_pid=$!
    
    local count=0
    
    for disc1 in "$PS_DIR"/*[Dd]isc*1*.cue; do
        if [ ! -f "$disc1" ]; then
            continue
        fi
        
        disc_filename=$(basename "$disc1")
        base_name=$(echo "$disc_filename" | sed -e 's/ ([Dd]isc [0-9][^)]*)//')
        base_name=${base_name%.cue}
        
        folder_name="$PS_DIR/$base_name"
        if [ -d "$folder_name" ] && [ -f "$folder_name/$base_name.m3u" ]; then
            if ls "$folder_name"/*.chd >/dev/null 2>&1; then
                folder_name=$(ensure_unique_folder "$folder_name")
                base_name=$(basename "$folder_name")
            fi
        fi
        
        mkdir -p "$folder_name"
        
        m3u_file="$folder_name/$base_name.m3u"
        : > "$m3u_file"
        
        for disc in "$PS_DIR"/*[Dd]isc*.cue; do
            if [ -f "$disc" ]; then
                this_disc=$(basename "$disc")
                this_base=$(echo "$this_disc" | sed -e 's/ ([Dd]isc [0-9][^)]*)//')
                this_base=${this_base%.cue}
                
                if [ "$this_base" = "${base_name% (*}" ]; then
                    echo "$this_disc" >> "$m3u_file"
                    
                    if [ "$disc" != "$folder_name/$this_disc" ]; then
                        mv "$disc" "$folder_name/"
                        count=$((count + 1))
                    fi
                    
                    bin_file="${disc%.cue}.bin"
                    if [ -f "$bin_file" ]; then
                        bin_filename=$(basename "$bin_file")
                        if [ "$bin_file" != "$folder_name/$bin_filename" ]; then
                            mv "$bin_file" "$folder_name/"
                            count=$((count + 1))
                        fi
                    fi
                fi
            fi
        done
    done
    
    for disc1 in "$PS_DIR"/*\(1\)*.cue; do
        if [ ! -f "$disc1" ]; then
            continue
        fi
        
        disc_filename=$(basename "$disc1")
        base_name=$(echo "$disc_filename" | sed -e 's/ *([0-9])//')
        base_name=${base_name%.cue}
        
        folder_name="$PS_DIR/$base_name"
        if [ -d "$folder_name" ] && [ -f "$folder_name/$base_name.m3u" ]; then
            if ls "$folder_name"/*.chd >/dev/null 2>&1; then
                folder_name=$(ensure_unique_folder "$folder_name")
                base_name=$(basename "$folder_name")
            fi
        fi
        
        mkdir -p "$folder_name"
        
        m3u_file="$folder_name/$base_name.m3u"
        : > "$m3u_file"
        
        for disc in "$PS_DIR"/*\([0-9]\)*.cue; do
            if [ -f "$disc" ]; then
                this_disc=$(basename "$disc")
                this_base=$(echo "$this_disc" | sed -e 's/ *([0-9])//')
                this_base=${this_base%.cue}
                
                if [ "$this_base" = "${base_name% (*}" ]; then
                    echo "$this_disc" >> "$m3u_file"
                    
                    if [ "$disc" != "$folder_name/$this_disc" ]; then
                        mv "$disc" "$folder_name/"
                        count=$((count + 1))
                    fi
                    
                    bin_file="${disc%.cue}.bin"
                    if [ -f "$bin_file" ]; then
                        bin_filename=$(basename "$bin_file")
                        if [ "$bin_file" != "$folder_name/$bin_filename" ]; then
                            mv "$bin_file" "$folder_name/"
                            count=$((count + 1))
                        fi
                    fi
                fi
            fi
        done
    done
    
    kill $message_pid 2>/dev/null
    
    if [ $count -gt 0 ]; then
        "$SHOW_MESSAGE" "Organized $count BIN/CUE files into folders." -l a
    else
        "$SHOW_MESSAGE" "No BIN/CUE files to organize." -l a
    fi
}

run_full_organization() {
    generate_missing_cue_files
    organize_chd_disc_games
    organize_cue_disc_games
    "$SHOW_MESSAGE" "Organization complete!" -l a
}

find_ps_directory

echo "PSX ROM Organizer|__HEADER__|header" > "$TEMP_MENU"

chd_count=$(count_multi_disc_chd_games)
cue_count=$(count_multi_disc_cue_games)
missing_cue_count=$(count_missing_cue_files)

echo "Organize All PSX ROMs|all|organize" >> "$TEMP_MENU"
echo "Organize Multi-disc CHD Games ($chd_count)|chd|organize" >> "$TEMP_MENU"
echo "Organize Multi-disc BIN/CUE Games ($cue_count)|cue|organize" >> "$TEMP_MENU"
echo "Generate Missing CUE Files ($missing_cue_count)|generate|organize" >> "$TEMP_MENU"

menu_idx=0
while true; do
    selection=$("$PICKER" "$TEMP_MENU" -i $menu_idx -b "EXIT")
    status=$?
    
    if [ -n "$selection" ]; then
        menu_idx=$(grep -n "^$selection$" "$TEMP_MENU" | cut -d: -f1 || echo "0")
        menu_idx=$((menu_idx - 1))
        [ $menu_idx -lt 0 ] && menu_idx=0
    fi
    
    [ $status -eq 1 ] || [ -z "$selection" ] && exit 0
    
    action=$(echo "$selection" | cut -d'|' -f2)
    
    case "$action" in
        header)
            "$SHOW_MESSAGE" "PSX ROM Organizer|Creates folders for multi-disc games|and generates M3U playlists.|Works with both CHD and BIN/CUE formats." -l a
            ;;
        all)
            "$SHOW_MESSAGE" "Organize All ROMs?|This will organize all multi-disc|games and generate missing CUE files." -l -a "YES" -b "NO"
            if [ $? -eq 0 ]; then
                run_full_organization
                
                chd_count=$(count_multi_disc_chd_games)
                cue_count=$(count_multi_disc_cue_games)
                missing_cue_count=$(count_missing_cue_files)
                
                echo "PSX ROM Organizer|__HEADER__|header" > "$TEMP_MENU"
                echo "Organize All PSX ROMs|all|organize" >> "$TEMP_MENU"
                echo "Organize Multi-disc CHD Games ($chd_count)|chd|organize" >> "$TEMP_MENU"
                echo "Organize Multi-disc BIN/CUE Games ($cue_count)|cue|organize" >> "$TEMP_MENU"
                echo "Generate Missing CUE Files ($missing_cue_count)|generate|organize" >> "$TEMP_MENU"
            fi
            ;;
        chd)
            "$SHOW_MESSAGE" "Organize CHD Games?|This will create folders for|multi-disc CHD games|and generate M3U files." -l -a "YES" -b "NO"
            if [ $? -eq 0 ]; then
                organize_chd_disc_games
                
                chd_count=$(count_multi_disc_chd_games)
                
                echo "PSX ROM Organizer|__HEADER__|header" > "$TEMP_MENU"
                echo "Organize All PSX ROMs|all|organize" >> "$TEMP_MENU"
                echo "Organize Multi-disc CHD Games ($chd_count)|chd|organize" >> "$TEMP_MENU"
                echo "Organize Multi-disc BIN/CUE Games ($cue_count)|cue|organize" >> "$TEMP_MENU"
                echo "Generate Missing CUE Files ($missing_cue_count)|generate|organize" >> "$TEMP_MENU"
            fi
            ;;
        cue)
            "$SHOW_MESSAGE" "Organize BIN/CUE Games?|This will create folders for|multi-disc BIN/CUE games and|generate M3U files." -l -a "YES" -b "NO"
            if [ $? -eq 0 ]; then
                organize_cue_disc_games
                
                cue_count=$(count_multi_disc_cue_games)
                
                echo "PSX ROM Organizer|__HEADER__|header" > "$TEMP_MENU"
                echo "Organize All PSX ROMs|all|organize" >> "$TEMP_MENU"
                echo "Organize Multi-disc CHD Games ($chd_count)|chd|organize" >> "$TEMP_MENU"
                echo "Organize Multi-disc BIN/CUE Games ($cue_count)|cue|organize" >> "$TEMP_MENU"
                echo "Generate Missing CUE Files ($missing_cue_count)|generate|organize" >> "$TEMP_MENU"
            fi
            ;;
        generate)
            "$SHOW_MESSAGE" "Generate Missing CUE Files?|This will create CUE files|for all BIN files without them." -l -a "YES" -b "NO"
            if [ $? -eq 0 ]; then
                generate_missing_cue_files
                
                missing_cue_count=$(count_missing_cue_files)
                
                echo "PSX ROM Organizer|__HEADER__|header" > "$TEMP_MENU"
                echo "Organize All PSX ROMs|all|organize" >> "$TEMP_MENU"
                echo "Organize Multi-disc CHD Games ($chd_count)|chd|organize" >> "$TEMP_MENU"
                echo "Organize Multi-disc BIN/CUE Games ($cue_count)|cue|organize" >> "$TEMP_MENU"
                echo "Generate Missing CUE Files ($missing_cue_count)|generate|organize" >> "$TEMP_MENU"
            fi
            ;;
    esac
done