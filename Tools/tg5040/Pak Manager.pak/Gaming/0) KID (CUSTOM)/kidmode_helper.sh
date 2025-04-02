#!/bin/sh
# Kid Mode helper script for resume handling

# Explicitly determine the full paths to ensure they work in all contexts
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
KIDMODE_PATH="${SCRIPT_DIR}/launch.sh"
RESUME_FILE="/mnt/SDCARD/.userdata/shared/.minui/auto_resume.txt"
LAUNCHER_SCRIPT="${SCRIPT_DIR}/kidmode_launcher.sh"

# Function to create a direct launcher for handling game execution with auto-return
create_direct_launcher() {
    local emu_script="$1"
    local rom_path="$2"
    
    # Create a script that will directly handle the process flow
    cat > "$LAUNCHER_SCRIPT" << EOF
#!/bin/sh
# Direct launcher script for Kid Mode

# Make sure the auto_resume.txt is removed so MinUI doesn't try to resume again
rm -f "$RESUME_FILE"

# Create a sentinel file that will help us detect if we need to return to Kid Mode
touch "/tmp/kidmode_active"

# Launch the emulator with the game ROM
"$emu_script" "$rom_path"
GAME_EXIT_CODE=\$?

# After the game exits, directly launch kid mode
# Using exec ensures we replace this process with Kid Mode
if [ -f "/tmp/kidmode_active" ]; then
    rm -f "/tmp/kidmode_active"
    # Full explicit path to Kid Mode
    exec "$KIDMODE_PATH"
fi
EOF
    
    chmod +x "$LAUNCHER_SCRIPT"
    echo "$LAUNCHER_SCRIPT"
}

# Check if the resume file exists
if [ -f "$RESUME_FILE" ]; then
    RELATIVE_PATH=$(cat "$RESUME_FILE")
    
    # Fix the path by adding the /mnt/SDCARD prefix if needed
    if [ "${RELATIVE_PATH:0:1}" = "/" ]; then
        # Path starts with /, likely a relative path
        FULL_PATH="/mnt/SDCARD$RELATIVE_PATH"
    else
        # Path might already be full
        FULL_PATH="$RELATIVE_PATH"
    fi
    
    # If path looks valid, launch the game with our wrapper
    if [ -n "$FULL_PATH" ] && [ -f "$FULL_PATH" ]; then
        # Get the ROM folder
        ROM_DIR=$(dirname "$FULL_PATH")
        ROM_FOLDER=$(basename "$ROM_DIR")
        
        # Try to extract platform tag
        PLATFORM_TAG=$(echo "$ROM_FOLDER" | grep -o '([^)]*)' | tr -d '()')
        
        if [ -n "$PLATFORM_TAG" ]; then
            # Try main Emus path first
            EMU_PATH="/mnt/SDCARD/Emus/$PLATFORM/$PLATFORM_TAG.pak/launch.sh"
            if [ -f "$EMU_PATH" ]; then
                # Delete the resume file to prevent it from resuming on next boot
                rm -f "$RESUME_FILE"
                # Create direct launcher and run it
                LAUNCHER_PATH=$(create_direct_launcher "$EMU_PATH" "$FULL_PATH")
                exec "$LAUNCHER_PATH"
            fi
            
            # Try system path if main path not found
            EMU_PATH="/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$PLATFORM_TAG.pak/launch.sh"
            if [ -f "$EMU_PATH" ]; then
                # Delete the resume file to prevent it from resuming on next boot
                rm -f "$RESUME_FILE"
                # Create direct launcher and run it
                LAUNCHER_PATH=$(create_direct_launcher "$EMU_PATH" "$FULL_PATH")
                exec "$LAUNCHER_PATH"
            fi
        fi
    fi
fi

# If we reach here (no resume or couldn't handle resume), launch Kid Mode directly
exec "$KIDMODE_PATH"