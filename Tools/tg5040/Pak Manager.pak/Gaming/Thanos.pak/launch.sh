#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
ROM_BASE_DIR="/mnt/SDCARD/Roms"
AVENGERS_LIST="$SCRIPT_DIR/avengers.txt"

if [ -s "$AVENGERS_LIST" ]; then
    ./show_message "Avengers to the rescue" &
    
    while IFS= read -r hidden_path; do
        [ -z "$hidden_path" ] && continue
        dir="$(dirname "$hidden_path")"
        base="$(basename "$hidden_path")"
        visible="$(echo "$base" | sed 's/^\.//')"
        mv "$dir/$base" "$dir/$visible" 2>/dev/null
    done < "$AVENGERS_LIST"
    
    rm -f "$AVENGERS_LIST"
    
    killall show_message
    exit 0
fi

./show_message "Thanos snapped his fingers" &

> "$AVENGERS_LIST"

find "$ROM_BASE_DIR" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r folder; do
    case "$(basename "$folder")" in
        *"(BITPAL)"*|*"(GS)"*|*"(RND)"*|*"(CUSTOM)"*|*.pak) continue ;;
    esac
    find "$folder" -type f ! -path '*/.res/*' 2>/dev/null
done > /tmp/thanos_candidates.txt

COUNT="$(wc -l < /tmp/thanos_candidates.txt)"
if [ "$COUNT" -eq 0 ]; then
    killall show_message
    exit 0
fi

HALF=$(( COUNT / 2 ))

while IFS= read -r file; do
    [ -z "$file" ] && continue
    echo "$RANDOM $file"
done < /tmp/thanos_candidates.txt | sort -n | cut -d' ' -f2- | head -n "$HALF" > /tmp/thanos_chosen.txt

while IFS= read -r f; do
    [ -z "$f" ] && continue
    dir="$(dirname "$f")"
    base="$(basename "$f")"
    if [ -f "$f" ]; then
        mv "$f" "$dir/.${base}" 2>/dev/null && echo "$dir/.${base}" >> "$AVENGERS_LIST"
    fi
done < /tmp/thanos_chosen.txt

rm -f /tmp/thanos_candidates.txt /tmp/thanos_chosen.txt

killall show_message
exit 0