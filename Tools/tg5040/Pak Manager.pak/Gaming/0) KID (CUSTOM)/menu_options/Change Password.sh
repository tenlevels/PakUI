#!/bin/sh
# Simple Password Change with PROPER UI MESSAGES
# Place this in the menu_options folder

# Determine the parent directory where Kid Mode is installed
SCRIPT_DIR="$(cd "$(dirname "$0")/../" && pwd -P)"
PASSWORD_FILE="$SCRIPT_DIR/password.txt"

# Create default password file if it doesn't exist
if [ ! -f "$PASSWORD_FILE" ]; then
    echo "1234" > "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
fi

# CRITICAL: Make sure we're using the correct show_message path and syntax!
# Step 1: Verify current password
"$SCRIPT_DIR/show_message" "Enter current password" -l a
# Wait for message to be confirmed
sleep 1
CURRENT_PASSWORD=$("$SCRIPT_DIR/keyboard" minui.ttf)

# Get stored password
STORED_PASSWORD=$(cat "$PASSWORD_FILE")

if [ "$CURRENT_PASSWORD" != "$STORED_PASSWORD" ]; then
    "$SCRIPT_DIR/show_message" "Incorrect password!" -l a
    sleep 1
    exit 1
fi

# Step 2: Get new password - no confirmation needed
"$SCRIPT_DIR/show_message" "Enter new password" -l a
# Wait for message to be confirmed
sleep 1
NEW_PASSWORD=$("$SCRIPT_DIR/keyboard" minui.ttf)

# Minimal validation
if [ -z "$NEW_PASSWORD" ]; then
    "$SCRIPT_DIR/show_message" "Password cannot be empty!" -l a
    sleep 1
    exit 1
fi

if [ ${#NEW_PASSWORD} -lt 2 ] || [ ${#NEW_PASSWORD} -gt 8 ]; then
    "$SCRIPT_DIR/show_message" "Password must be 2-8 characters!" -l a
    sleep 1
    exit 1
fi

# Simply write the new password to the file
echo "$NEW_PASSWORD" > "$PASSWORD_FILE"

# Final confirmation message
"$SCRIPT_DIR/show_message" "Password changed to:|$NEW_PASSWORD" -l a
sleep 1

exit 0