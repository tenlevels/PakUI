#!/bin/sh
DIR=$(dirname "$0")
cd "$DIR"

YTDLP_PATH="$DIR/yt-dlp"
SDL2IMGSHOW="$DIR/sdl2imgshow"
GM="$DIR/gm"

export LD_LIBRARY_PATH="$DIR/.lib:$LD_LIBRARY_PATH"

CHANNELS_FILE="$DIR/channels.txt"
CHANNELS_BACKUP="$DIR/channels_backup.txt"
PICKER_OUTPUT="/tmp/picker_output.txt"
LOG_FILE="$DIR/youtube_channels.log"

###############################################################################
# Connectivity check
###############################################################################
check_connectivity() {
    ping -c 1 -W 2 8.8.8.8  >/dev/null 2>&1 ||
    ping -c 1 -W 2 1.1.1.1  >/dev/null 2>&1 ||
    ping -c 1 -W 2 208.67.222.222  >/dev/null 2>&1 ||
    ping -c 1 -W 2 114.114.114.114 >/dev/null 2>&1 ||
    ping -c 1 -W 2 119.29.29.29    >/dev/null 2>&1
}

###############################################################################
# Simple logging function
###############################################################################
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

###############################################################################
# Ensure channels files exist
###############################################################################
if [ ! -f "$CHANNELS_FILE" ]; then
    touch "$CHANNELS_FILE"
    log_message "Created channels file: $CHANNELS_FILE"
fi

if [ ! -f "$CHANNELS_BACKUP" ]; then
    touch "$CHANNELS_BACKUP"
    log_message "Created channels backup file: $CHANNELS_BACKUP"
fi

###############################################################################
# Helper to clean up user-entered URLs
###############################################################################
clean_channel_url() {
    echo "$1" | sed -E 's|^https?://||; s|www\.youtube\.com/||; s|^@||; s|/$||'
}

###############################################################################
# Validate channel by trying to fetch one item from it
###############################################################################
validate_channel_url() {
    local CHANNEL_URL="$1"
    log_message "Validating channel URL: $CHANNEL_URL"

    if ! check_connectivity; then
        log_message "No internet connection available"
        ./show_message "No Internet Connection|Please check your connection" -l a
        return 1
    fi

    CLEANED_URL=$(clean_channel_url "$CHANNEL_URL")
    log_message "Cleaned channel URL: $CLEANED_URL"

    if ! echo "$CLEANED_URL" | grep -qE '^[a-zA-Z0-9._-]+$'; then
        log_message "Invalid channel format: $CLEANED_URL"
        ./show_message "Invalid Channel Format|Please use @ChannelName format" -l a
        return 1
    fi

    log_message "Attempting to validate channel: $CLEANED_URL"
    if ! "$YTDLP_PATH" "https://www.youtube.com/@$CLEANED_URL" --playlist-items 1 \
        --skip-download --no-warnings --no-progress \
        --print "%(channel)s" >/dev/null 2>&1; then
        log_message "Channel not found: $CLEANED_URL"
        ./show_message "Channel Not Found|Please check the channel name" -l a
        return 1
    fi

    echo "$CLEANED_URL" > /tmp/valid_channel.txt
    log_message "Channel validated successfully: $CLEANED_URL"
    return 0
}

###############################################################################
# Draw a simple progress bar using GraphicsMagick + sdl2imgshow
###############################################################################
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

###############################################################################
# Build a list of channels for the main menu
###############################################################################
create_channels_menu() {
    > /tmp/channels_menu.txt
    log_message "Creating channels menu"
    if [ ! -s "$CHANNELS_FILE" ]; then
        log_message "No channels found"
        return
    fi
    cat "$CHANNELS_FILE" | while read -r channel; do
        if [ ! -z "$channel" ]; then
            echo "$channel|$channel|channel" >> /tmp/channels_menu.txt
        fi
    done
}

###############################################################################
# Build the options menu (now with 'Update yt-dlp')
###############################################################################
create_options_menu() {
    > /tmp/options_menu.txt
    echo "Add New Channel|add|action" >> /tmp/options_menu.txt
    echo "Remove Channel|remove|action" >> /tmp/options_menu.txt
    echo "Update yt-dlp|update_dlp|action" >> /tmp/options_menu.txt
}

###############################################################################
# Add a channel to channels.txt
###############################################################################
add_channel() {
    log_message "Starting add_channel function"
    ./show_message "Enter YouTube Channel|Format: @ChannelName" -t 2
    channel_input=$(./keyboard minui.ttf)
    keyboard_status=$?
    log_message "Keyboard input status: $keyboard_status"
    log_message "Keyboard input: $channel_input"

    if [ $keyboard_status -eq 0 ] && [ ! -z "$channel_input" ]; then
        CLEAN_CHANNEL=$(clean_channel_url "$channel_input")
        log_message "Cleaned channel: $CLEAN_CHANNEL"
        if validate_channel_url "$CLEAN_CHANNEL"; then
            VALIDATED_CHANNEL=$(cat /tmp/valid_channel.txt)
            if ! grep -q "^$VALIDATED_CHANNEL$" "$CHANNELS_FILE"; then
                echo "$VALIDATED_CHANNEL" >> "$CHANNELS_FILE"
                log_message "Channel added: $VALIDATED_CHANNEL"
                ./show_message "Channel Added Successfully" -l a
            else
                log_message "Channel already exists: $VALIDATED_CHANNEL"
                ./show_message "Channel Already Exists" -l a
            fi
        fi
    else
        log_message "Invalid or cancelled keyboard input"
    fi
}

###############################################################################
# Remove a channel from channels.txt
###############################################################################
remove_channel() {
    log_message "Starting remove_channel function"
    if [ ! -s "$CHANNELS_FILE" ]; then
        log_message "No channels to remove"
        ./show_message "No Channels to Remove" -l a
        return
    fi
    > /tmp/remove_menu.txt
    cat "$CHANNELS_FILE" | while read -r channel; do
        if [ ! -z "$channel" ]; then
            echo "$channel|$channel|delete" >> /tmp/remove_menu.txt
        fi
    done

    ./show_message "Select Channel to Remove" -t 2
    picker_output=$(./picker /tmp/remove_menu.txt)
    picker_status=$?
    [ $picker_status -ne 0 ] && return

    channel=$(echo "$picker_output" | cut -d'|' -f2)
    ./show_message "Remove This Channel?|$channel" -l ab -a "YES" -b "NO"
    if [ $? -eq 0 ]; then
        cp "$CHANNELS_FILE" "$CHANNELS_BACKUP"
        grep -v "^$channel$" "$CHANNELS_FILE" > "/tmp/channels_temp.txt"
        mv "/tmp/channels_temp.txt" "$CHANNELS_FILE"
        log_message "Removed channel: $channel"
        ./show_message "Channel Removed Successfully" -l a
    else
        log_message "Channel removal cancelled"
    fi
}

###############################################################################
# New function: Call update_yt_dlp.sh
###############################################################################
update_yt_dlp() {
    log_message "Starting update_yt_dlp function"
    ./update_yt_dlp.sh
}

###############################################################################
# Main loop: Picker + handling
###############################################################################
main() {
    log_message "Starting main program"
    while true; do
        killall picker 2>/dev/null
        create_channels_menu

        # Main picker with "OPTIONS" as Y button, "EXIT" as B, "SELECT" as A
        picker_output=$(./picker /tmp/channels_menu.txt -y "OPTIONS" -b "EXIT" -a "SELECT")
        picker_status=$?
        log_message "Picker output: $picker_output, status: $picker_status"

        [ $picker_status -eq 2 ] && exit 0  # If user pressed B -> EXIT

        if [ $picker_status -eq 4 ]; then
            # Y button -> Show "OPTIONS" menu
            create_options_menu
            option_output=$(./picker /tmp/options_menu.txt)
            option_status=$?
            [ $option_status -ne 0 ] && continue

            action=$(echo "$option_output" | cut -d'|' -f2)
            case "$action" in
                "add")
                    add_channel
                    ;;
                "remove")
                    remove_channel
                    ;;
                "update_dlp")
                    update_yt_dlp
                    ;;
            esac
            continue
        fi

        [ $picker_status -ne 0 ] && exit $picker_status

        # If user selected a channel from the main menu
        name=$(echo "$picker_output" | cut -d'|' -f1)
        channel=$(echo "$picker_output" | cut -d'|' -f2)
        type=$(echo "$picker_output" | cut -d'|' -f3)

        log_message "Name: $name, Channel: $channel, Type: $type"

        if [ "$type" = "channel" ]; then
            > /tmp/channel_options.txt
            echo "Get Last Five Videos|five|action" > /tmp/channel_options.txt
            echo "Download Latest Video|latest|action" >> /tmp/channel_options.txt
            ./show_message "Channel: $channel|Choose Option" -t 2

            option_output=$(./picker /tmp/channel_options.txt)
            option_status=$?
            [ $option_status -ne 0 ] && continue

            mode=$(echo "$option_output" | cut -d'|' -f2)
            log_message "Selected: $mode for channel $channel"
            ./select_channel.sh "$channel" "$mode"
        fi
    done
}

main
