#!/bin/sh
DIR=$(dirname "$0")
cd "$DIR"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <channel_name> [mode]"
    exit 1
fi

CHANNEL_NAME="$1"
MODE="${2:-five}"

YTDLP_PATH="$DIR/yt-dlp"
SDL2IMGSHOW="$DIR/sdl2imgshow"
GM="$DIR/gm"

export LD_LIBRARY_PATH="$DIR/.lib:$LD_LIBRARY_PATH"

CACHE_DIR="$DIR/channels_cache"
mkdir -p "$CACHE_DIR"
CHANNEL_CACHE_DIR="$CACHE_DIR/$CHANNEL_NAME"
mkdir -p "$CHANNEL_CACHE_DIR"
VIDEOS_CACHE="$CHANNEL_CACHE_DIR/channel_videos.txt"

find_media_player_folder() {
    for d in /mnt/SDCARD/Roms/*; do
        if [ -d "$d" ] && echo "$(basename "$d")" | grep -q "(MPV)"; then
            echo "$d"
            return 0
        fi
    done
    return 1
}

MPV_FOLDER=$(find_media_player_folder)
if [ -z "$MPV_FOLDER" ]; then
    echo "Media Player folder with (MPV) tag not found in /mnt/SDCARD/Roms"
    exit 1
fi

DOWNLOAD_BASE="$MPV_FOLDER"
DOWNLOAD_DIR="$DOWNLOAD_BASE/$CHANNEL_NAME"

mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$DOWNLOAD_DIR/.res"

MENU_FILE="/tmp/channel_videos.txt"
PROGRESS_FILE="/tmp/video_progress"

check_connectivity() {
    ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 ||
    ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 ||
    ping -c 1 -W 2 208.67.222.222 >/dev/null 2>&1 ||
    ping -c 1 -W 2 114.114.114.114 >/dev/null 2>&1 ||
    ping -c 1 -W 2 119.29.29.29 >/dev/null 2>&1
}

draw_main_status_bar() {
    PERCENT="$1"
    
    pkill -f "$SDL2IMGSHOW" 2>/dev/null
    
    "$GM" convert -size 1024x768 xc:black PNG:"/tmp/main_progress.png"
    
    if [ "$PERCENT" -eq 0 ] || [ "$PERCENT" -eq 100 ]; then
        "$GM" convert "/tmp/main_progress.png" -fill none -stroke white -strokewidth 6 \
            -draw "rectangle 212,384 812,434" PNG:"/tmp/main_progress.png"
    else
        "$GM" convert "/tmp/main_progress.png" -fill none -stroke black -strokewidth 6 \
            -draw "rectangle 212,384 812,434" PNG:"/tmp/main_progress.png"
    fi
    
    FILL_WIDTH=$((213 + PERCENT * 6))
    
    "$GM" convert "/tmp/main_progress.png" -fill white \
        -draw "rectangle 213,385 $FILL_WIDTH,433" PNG:"/tmp/main_progress.png"
    
    "$SDL2IMGSHOW" -S original -i "/tmp/main_progress.png" &
}

clean_filename() {
    echo "${1//[^a-zA-Z0-9._ -]/}"
}

is_cache_fresh() {
    if [ -f "$VIDEOS_CACHE" ]; then
        CACHE_TIME=$(stat -c %Y "$VIDEOS_CACHE")
        CURRENT_TIME=$(date +%s)
        CACHE_AGE=$((CURRENT_TIME - CACHE_TIME))
        if [ "$CACHE_AGE" -lt 3600 ]; then
            return 0
        fi
    fi
    return 1
}

check_latest_video() {
    ./show_message "Checking for New Videos|Please Wait" -t 2
    LATEST_VIDEO=$("$YTDLP_PATH" "https://www.youtube.com/$CHANNEL_NAME/videos" \
        --playlist-items 1 --skip-download --no-warnings --no-progress \
        --print "%(id)s")
    if [ -z "$LATEST_VIDEO" ]; then
        return 1
    fi
    if [ -f "$VIDEOS_CACHE" ] && grep -q "$LATEST_VIDEO" "$VIDEOS_CACHE"; then
        return 0
    fi
    return 1
}

create_video_menu() {
    if ! check_connectivity; then
        ./show_message "No Internet Connection|Please check your connection" -l a
        exit 1
    fi

    # If cache is fresh AND the latest video hasn't changed, just reuse it.
    if is_cache_fresh && check_latest_video; then
        cp "$VIDEOS_CACHE" "$MENU_FILE"
    else
        ./show_message "Getting Last Five Videos|Please Wait" -t 2
        echo "0" > "$PROGRESS_FILE"
        draw_main_status_bar 0
        sleep 1

        > "$VIDEOS_CACHE"
        "$YTDLP_PATH" "https://www.youtube.com/$CHANNEL_NAME/videos" \
            --playlist-items 1-5 \
            --skip-download --no-warnings --no-progress \
            --print "%(title)s|%(id)s|download" |
        while IFS="|" read -r title video_id _; do
            echo "$title|$video_id|download" >> "$VIDEOS_CACHE"
            VIDEO_COUNT=$(wc -l < "$VIDEOS_CACHE")
            draw_main_status_bar $((VIDEO_COUNT * 20))
            sleep 0.25
        done

        cp "$VIDEOS_CACHE" "$MENU_FILE"

        draw_main_status_bar 100
        sleep 1
        pkill -f "$SDL2IMGSHOW" 2>/dev/null
    fi
}

download_video() {
    VIDEO_TITLE="$1"
    VIDEO_ID="$2"
    CLEAN_TITLE=$(clean_filename "$VIDEO_TITLE")
    OUTPUT_FILE="$DOWNLOAD_DIR/$CLEAN_TITLE.mp4"
    THUMB_FILE="$DOWNLOAD_DIR/.res/${CLEAN_TITLE}.mp4.png"

    if [ -f "$OUTPUT_FILE" ]; then
        ./show_message "Video Already Downloaded" -l ab -a "PLAY" -b "BACK"
        if [ $? -eq 0 ]; then
            /mnt/SDCARD/Emus/$PLATFORM/MPV.pak/launch.sh "$OUTPUT_FILE"
        fi
        return
    fi

    echo "0" > "$PROGRESS_FILE"
    draw_main_status_bar 0
    sleep 2

    FILL_PERCENT=5
    while true; do
        draw_main_status_bar "$FILL_PERCENT"
        FILL_PERCENT=$((FILL_PERCENT + 5))
        if [ "$FILL_PERCENT" -gt 95 ]; then
            break
        fi
        sleep 5
    done &
    ANIMATE_PID=$!


    if "$YTDLP_PATH" -f b -o "$OUTPUT_FILE" "https://www.youtube.com/watch?v=$VIDEO_ID" 2> "$DIR/error.txt"; then
        kill "$ANIMATE_PID" 2>/dev/null
        draw_main_status_bar 100
        sleep 2
        pkill -f "$SDL2IMGSHOW" 2>/dev/null

        THUMB_URL=$("$YTDLP_PATH" "https://www.youtube.com/watch?v=$VIDEO_ID" \
            --skip-download --no-warnings --no-progress --print "%(thumbnail)s")
        if [ ! -f "$THUMB_FILE" ]; then
            if ! wget -q -O "/tmp/${VIDEO_ID}_thumb" "https://img.youtube.com/vi/$VIDEO_ID/maxresdefault.jpg"; then
                if ! wget -q -O "/tmp/${VIDEO_ID}_thumb" "https://img.youtube.com/vi/$VIDEO_ID/hqdefault.jpg"; then
                    if ! wget -q -O "/tmp/${VIDEO_ID}_thumb" "https://i.ytimg.com/vi_webp/$VIDEO_ID/maxresdefault.webp"; then
                        if [ ! -z "$THUMB_URL" ]; then
                            wget -q -O "/tmp/${VIDEO_ID}_thumb" "$THUMB_URL"
                        fi
                    fi
                fi
            fi

            if [ -f "/tmp/${VIDEO_ID}_thumb" ]; then
                "$GM" convert "/tmp/${VIDEO_ID}_thumb" -resize 300x\> "$THUMB_FILE"
                rm "/tmp/${VIDEO_ID}_thumb"
            fi
        fi

        /mnt/SDCARD/Emus/$PLATFORM/MPV.pak/launch.sh "$OUTPUT_FILE"
    else
        kill "$ANIMATE_PID" 2>/dev/null
        draw_main_status_bar 0
        sleep 2
        pkill -f "$SDL2IMGSHOW" 2>/dev/null

        ./show_message "Download Failed|B: Back and try again|A: Try updating yt-dlp" -l ab -a "UPDATE" -b "BACK"
        # If user presses A, we run the update script
        if [ $? -eq 0 ]; then
            ./update_yt_dlp.sh
        fi
    fi
}

download_latest_video() {
    if ! check_connectivity; then
        ./show_message "No Internet Connection|Please check your connection" -l a
        exit 1
    fi

    ./show_message "Getting Latest Video|Please Wait" -t 2
    LATEST_VIDEO=$("$YTDLP_PATH" "https://www.youtube.com/$CHANNEL_NAME/videos" \
        --playlist-items 1 --skip-download --no-warnings --no-progress \
        --print "%(title)s|%(id)s")

    if [ -z "$LATEST_VIDEO" ]; then
        ./show_message "Failed to Get Video|Please try again" -l a
        exit 1
    fi

    LATEST_TITLE=$(echo "$LATEST_VIDEO" | cut -d'|' -f1)
    LATEST_ID=$(echo "$LATEST_VIDEO" | cut -d'|' -f2)

    if [ ! -f "$VIDEOS_CACHE" ] || ! grep -q "$LATEST_ID" "$VIDEOS_CACHE"; then
        echo "$LATEST_VIDEO|download" > "$VIDEOS_CACHE"
    fi

    CLEAN_TITLE=$(clean_filename "$LATEST_TITLE")
    OUTPUT_FILE="$DOWNLOAD_DIR/$CLEAN_TITLE.mp4"

    if [ -f "$OUTPUT_FILE" ]; then
        ./show_message "Video Already Downloaded" -l ab -a "PLAY" -b "BACK"
        if [ $? -eq 0 ]; then
            /mnt/SDCARD/Emus/$PLATFORM/MPV.pak/launch.sh "$OUTPUT_FILE"
        fi
        return
    fi

    ./show_message "Starting Download|Please Wait" -t 2
    download_video "$LATEST_TITLE" "$LATEST_ID"
}

main() {
    if [ "$MODE" = "latest" ]; then
        download_latest_video
    else
        create_video_menu
        while true; do
            rm -f /tmp/picker_output.txt
            picker_output=$(./picker "$MENU_FILE" -b "BACK" -a "DOWNLOAD")
            picker_status=$?
            [ $picker_status -eq 2 ] && exit 0
            [ $picker_status -ne 0 ] && [ $picker_status -ne 4 ] && exit $picker_status

            if [ -z "$picker_output" ]; then
                exit 0
            fi

            title=$(echo "$picker_output" | cut -d'|' -f1)
            video_id=$(echo "$picker_output" | cut -d'|' -f2)
            action=$(echo "$picker_output" | cut -d'|' -f3)

            if [ -z "$title" ] || [ -z "$video_id" ]; then
                exit 0
            fi

            [ "$action" = "download" ] && download_video "$title" "$video_id"
        done
    fi
}

main

