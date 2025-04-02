#!/bin/sh

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cd "$SCRIPT_DIR"

BASE_DIR="/mnt/SDCARD/Roms"

process_name() {
    echo "$1" | sed -E 's/\s*\([^)]*\)//g; s/\s*\[[^]]*\]//g; s/&amp;/\&/g; s/\s*:\s*/ - /g; s/\s+$//g'
}

# Show initial message
./show_message "Getting started..." &

process_xml_file() {
    local xml="$1"
    local dir=$(dirname "$xml")
    local path=""
    local system_name=$(basename "$dir" | sed -E 's/\s*\([^)]*\)//g')
    
    # Kill previous message and show current folder
    killall show_message
    ./show_message "Making map.txt for:|$system_name" &
    
    while read -r line; do
        case "$line" in
            *"<path>"*)
                path=$(echo "$line" | sed 's/.*<path>\.\///' | sed 's/<\/path>.*//')
                ;;
            *"<name>"*)
                name=$(process_name "$(echo "$line" | sed 's/.*<name>//' | sed 's/<\/name>.*//')")
                if [ ! -z "$path" ]; then
                    echo "${path}	${name}" >> "$dir/map.txt.tmp"
                    path=""
                fi
                ;;
        esac
    done < "$xml"
    
    sort "$dir/map.txt.tmp" > "$dir/map.txt"
    rm "$dir/map.txt.tmp"
}

hide_xml_files() {
    local dir="$1"
    [ -f "$dir/gamelist.xml" ] && mv "$dir/gamelist.xml" "$dir/.gamelist.xml"
    [ -f "$dir/miyoogamelist.xml" ] && mv "$dir/miyoogamelist.xml" "$dir/.miyoogamelist.xml"
}

process_directory() {
    local dir="$1"
    [ ! -d "$dir" ] && return
    for xml in "$dir"/gamelist.xml "$dir"/miyoogamelist.xml; do
        [ -f "$xml" ] && process_xml_file "$xml"
    done
    hide_xml_files "$dir"
}

for dir in "$BASE_DIR"/*; do
    process_directory "$dir"
done

killall show_message
./show_message "Done" -t 2

exit 0