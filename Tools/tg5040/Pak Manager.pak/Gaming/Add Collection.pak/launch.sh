#!/bin/sh

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cd "$SCRIPT_DIR"

SOURCE_DIR="$SCRIPT_DIR/New Collection (CUSTOM)"
DEST_DIR="/mnt/SDCARD/Roms"

CUSTOM_FOLDER_SOURCE="$SCRIPT_DIR/CUSTOM.pak"
CUSTOM_PAK_DEST="/mnt/SDCARD/Emus/$PLATFORM"

# Ensure the source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    ./show_message "Error: Source directory not found" -t 2
    exit 1
fi

# Prompt the user to choose the destination
./show_message "Select where to install|your new collection." -t 2

OPTIONS_FILE="/tmp/collection_options.txt"
echo "Main Roms Section|roms" > "$OPTIONS_FILE"
echo "Collections Folder|collections" >> "$OPTIONS_FILE"

CHOICE=$(./picker "$OPTIONS_FILE")
DEST_CHOICE=$(echo "$CHOICE" | cut -d'|' -f2)

# Determine target directory based on user selection
if [ "$DEST_CHOICE" = "roms" ]; then
    TARGET_DIR="$DEST_DIR"
elif [ "$DEST_CHOICE" = "collections" ]; then
    # Search for a folder ending with "Collections (CUSTOM)" (ignoring any numeric prefix)
    COLLECTION_FOLDER=$(find "$DEST_DIR" -maxdepth 1 -type d -iname "*Collections (CUSTOM)" | head -n 1)
    if [ -z "$COLLECTION_FOLDER" ]; then
        # Create default folder if not found
        COLLECTION_FOLDER="$DEST_DIR/0) Collections (CUSTOM)"
        mkdir -p "$COLLECTION_FOLDER"
    fi
    TARGET_DIR="$COLLECTION_FOLDER"
else
    ./show_message "Invalid selection" -t 2
    exit 1
fi

# Check if New Collection (CUSTOM) already exists in the target
if [ -d "$TARGET_DIR/New Collection (CUSTOM)" ]; then
    ./show_message "Please rename your existing|New Collection first" -t 4
    exit 1
fi

./show_message "Installing New Collection..." &

cp -r "$SOURCE_DIR" "$TARGET_DIR/"

cp -r "$CUSTOM_FOLDER_SOURCE" "$CUSTOM_PAK_DEST"

killall show_message
./show_message "New Collection added" -t 2
exit 0
