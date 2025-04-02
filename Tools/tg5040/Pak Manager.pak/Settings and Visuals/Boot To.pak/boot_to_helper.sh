#!/bin/sh
# Boot To helper script for resume handling

SCRIPT_DIR=$(dirname "$0")
BOOT_TO_CONFIG="${SCRIPT_DIR}/boot_to.txt"
RESUME_FILE="/mnt/SDCARD/.userdata/shared/.minui/auto_resume.txt"
CLEANUP_SCRIPT="${SCRIPT_DIR}/boot_to_cleanup.sh"
LAUNCHER_SCRIPT="${SCRIPT_DIR}/boot_to_launcher.sh"
RETROARCH_WRAPPER="${SCRIPT_DIR}/retroarch_wrapper.sh"

# Check if the boot configuration exists
if [ ! -f "$BOOT_TO_CONFIG" ]; then
    # No boot option set, let MinUI handle everything normally
    exit 0
fi

# Get boot option from config file
BOOT_TYPE=$(head -n 1 "$BOOT_TO_CONFIG" | cut -d'|' -f1)
BOOT_NAME=$(head -n 1 "$BOOT_TO_CONFIG" | cut -d'|' -f2)
BOOT_PATH=$(head -n 1 "$BOOT_TO_CONFIG" | cut -d'|' -f3)

# For game type, get the ROM path
if [ "$BOOT_TYPE" = "game" ]; then
    ROM_PATH=$(head -n 1 "$BOOT_TO_CONFIG" | cut -d'|' -f4)
fi

# Create a direct launcher for handling game execution with auto-return
create_direct_launcher() {
    local emu_script="$1"
    local rom_path="$2"
    
    # Create a script that will directly handle the process flow
    cat > "$LAUNCHER_SCRIPT" << EOF
#!/bin/sh
# Direct launcher script for Boot To

# Make sure the auto_resume.txt is removed so MinUI doesn't try to resume again
rm -f "$RESUME_FILE"

# Launch the emulator with the game ROM
"$emu_script" "$rom_path"

# After the game exits (regardless of internal structure),
# directly launch our boot option
if [ "$BOOT_TYPE" = "game" ]; then
    exec "$BOOT_PATH" "$ROM_PATH"
else
    exec "$BOOT_PATH"
fi
EOF
    
    chmod +x "$LAUNCHER_SCRIPT"
    echo "$LAUNCHER_SCRIPT"
}

# Create a cleanup script that will remove itself from the emulator's launch.sh
create_cleanup_script() {
    local emu_script="$1"
    local rom_path="$2"
    
    # First create our direct launcher
    create_direct_launcher "$emu_script" "$rom_path"
    
    # Create the cleanup script that just removes the redirect and calls the launcher
    cat > "$CLEANUP_SCRIPT" << EOF
#!/bin/sh
# One-time cleanup script for Boot To

# Remove our redirect line from the emulator script
sed -i '/# BOOT_TO_REDIRECT/d' "$emu_script"

# Launch the direct launcher in foreground
exec "$LAUNCHER_SCRIPT"
EOF
    
    chmod +x "$CLEANUP_SCRIPT"
    
    # Return the path to the cleanup script
    echo "$CLEANUP_SCRIPT"
}

# Create a RetroArch wrapper script
create_retroarch_wrapper() {
    local auto_resume_path="$1"
    
    # Create a wrapper script that will run auto_resume.sh and then go to boot option
    cat > "$RETROARCH_WRAPPER" << EOF
#!/bin/sh
# RetroArch wrapper script

# Run the original auto_resume.sh 
"$auto_resume_path"

# When auto_resume.sh finishes, run our boot option
if [ "$BOOT_TYPE" = "game" ]; then
    exec "$BOOT_PATH" "$ROM_PATH"
else
    exec "$BOOT_PATH"
fi
EOF
    
    chmod +x "$RETROARCH_WRAPPER"
    
    # Return the path to the wrapper script
    echo "$RETROARCH_WRAPPER"
}

# Add a redirect to an emulator script with newline protection
add_redirect_to_emulator() {
    local emu_script="$1"
    local redirect_line="$2"
    
    # Check if the file ends with a newline
    if [ -f "$emu_script" ] && [ -s "$emu_script" ]; then
        local last_char=$(tail -c 1 "$emu_script" | hexdump -e '1/1 "%02x"')
        if [ "$last_char" != "0a" ]; then
            # Add a newline if missing
            echo "" >> "$emu_script"
        fi
    fi
    
    # Add an extra blank line for safety
    echo "" >> "$emu_script"
    
    # Add the redirect
    echo "$redirect_line" >> "$emu_script"
}

# Check if MinUI resume file exists
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
    
    # If path looks valid, modify the emulator and exit
    if [ -n "$FULL_PATH" ] && [ -f "$FULL_PATH" ]; then
        # Get the ROM folder
        ROM_DIR=$(dirname "$FULL_PATH")
        ROM_FOLDER=$(basename "$ROM_DIR")
        
        # Try to extract platform tag
        PLATFORM_TAG=$(echo "$ROM_FOLDER" | grep -o '([^)]*)' | tr -d '()')
        
        if [ -n "$PLATFORM_TAG" ]; then
            # Look for the emulator script
            EMU_PATH="/mnt/SDCARD/Emus/$PLATFORM/$PLATFORM_TAG.pak/launch.sh"
            if [ -f "$EMU_PATH" ]; then
                # Create direct launcher and run it directly
                LAUNCHER_PATH=$(create_direct_launcher "$EMU_PATH" "$FULL_PATH")
                exec "$LAUNCHER_PATH"
            fi
            
            # Try system path
            EMU_PATH="/mnt/SDCARD/.system/$PLATFORM/paks/Emus/$PLATFORM_TAG.pak/launch.sh"
            if [ -f "$EMU_PATH" ]; then
                # Create direct launcher and run it directly
                LAUNCHER_PATH=$(create_direct_launcher "$EMU_PATH" "$FULL_PATH")
                exec "$LAUNCHER_PATH"
            fi
        fi
    fi
fi

# RETROARCH SECOND: Check for RetroArch auto_resume.sh in auto.sh
for platform_dir in /mnt/SDCARD/.userdata/*; do
    if [ -d "$platform_dir" ]; then
        AUTO_SH="$platform_dir/auto.sh"
        if [ -f "$AUTO_SH" ]; then
            auto_resume_line=$(grep "auto_resume.sh" "$AUTO_SH" | grep -v "BOOT_TO_AUTO_MARKER" | head -n 1)
            
            if [ -n "$auto_resume_line" ]; then
                # Found RetroArch resume line
                
                # Extract path from quote
                AUTO_RESUME_PATH=$(echo "$auto_resume_line" | sed -n 's/.*"\(.*\)".*/\1/p')
                
                if [ -f "$AUTO_RESUME_PATH" ]; then
                    # Create a wrapper script that will execute auto_resume.sh and then go to boot option
                    WRAPPER_PATH=$(create_retroarch_wrapper "$AUTO_RESUME_PATH")
                    
                    # Execute our wrapper instead of the original auto_resume.sh
                    exec "$WRAPPER_PATH"
                fi
            fi
        fi
    fi
done

# If no resume or couldn't process it, do our boot option
if [ "$BOOT_TYPE" = "game" ]; then
    exec "$BOOT_PATH" "$ROM_PATH"
else
    exec "$BOOT_PATH"
fi