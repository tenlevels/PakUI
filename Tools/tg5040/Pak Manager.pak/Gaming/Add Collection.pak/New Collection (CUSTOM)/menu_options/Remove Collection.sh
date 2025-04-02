#!/bin/sh

# Ensure MENU environment variable is set
if [ -z "$MENU" ]; then
   echo "Error: MENU environment variable not set" >&2
   exit 1
fi

# Get current collection name from the first line of the MENU file
current_name=$(head -n 1 "$MENU" | cut -d'|' -f1)

# Ask for confirmation using show_message
./show_message "Remove Collection:|Are you sure you want|to remove $current_name?" -l -a "OK" -b "CANCEL"
if [ $? -ne 0 ]; then
   exit 0
fi

# Save the current directory and its parent directory
current_dir=$(pwd)
parent_dir=$(dirname "$current_dir")

# Change to parent directory so removal doesn't affect the running script
cd "$parent_dir" || exit 1

# Remove the entire collection folder and its contents
rm -rf "$current_dir"

# Optionally, show a confirmation message (this line might not display if the folder is deleted)
./show_message "Collection '$current_name' removed successfully." -l a

exit 0
