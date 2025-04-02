#!/bin/sh
export LED_MODULE_PATH="/mnt/SDCARD/Tools/tg5040/LEDs"

SCRIPT_DIR="$LED_MODULE_PATH/scripts.disabled"
CONFIG_DIR="$SCRIPT_DIR/config"
LED_CONFIG="$CONFIG_DIR/led.conf"
LED_DEFAULT_CONFIG="$CONFIG_DIR/led.defaults.conf"
LOG_FILE="$SCRIPT_DIR/log.txt"

log_message() {
    message="$*"
    output="$(date '+%Y-%m-%d %H:%M:%S') $message"
    echo "$output"
    if [ -n "$LOG_FILE" ] && [ -w "$LOG_FILE" ] || [ ! -e "$LOG_FILE" ]; then
        echo "$output" >> "$LOG_FILE"
    fi
}

save_settings() {
    log_message "saving to $LED_CONFIG"

    settings="effect_enabled effect_value active_leds bright_value color_value standby_color animation_enabled rainbow_color_spread speed_value low_batt_threshold low_batt_ind color_shift_spread"

    {
        for setting in $settings; do
            eval "value=\$$setting"
            echo "$setting=$value"
        done
    } > "$LED_CONFIG"
}

load_settings() {
    log_message "loading $LED_CONFIG and $LED_DEFAULT_CONFIG"

    # Load defaults first
    if [ -f "$LED_DEFAULT_CONFIG" ]; then
        . "$LED_DEFAULT_CONFIG"
    fi
    
    # Then override with user settings
    if [ -f "$LED_CONFIG" ]; then
        . "$LED_CONFIG"
    fi
}

enabledisable_rename() {
    folder="$1"
    action="$2"
    
    echo "renaming $folder" >> "$LOG"
    if [ ! -d "$folder" ]; then
        echo "Folder does not exist: $folder" >&2
        return 1
    fi

    new_name=""
    case "$action" in
        "disable")
            new_name=$(echo "$folder" | sed -e 's/Toggle/Enable/' -e 's/Disable/Enable/')
            ;;
        "enable")
            new_name=$(echo "$folder" | sed -e 's/Toggle/Disable/' -e 's/Enable/Disable/')
            ;;
        *)
            case "$folder" in
                *"Disable"*)
                    new_name=$(echo "$folder" | sed 's/Disable/Enable/')
                    ;;
                *"Enable"*)
                    new_name=$(echo "$folder" | sed 's/Enable/Disable/')
                    ;;
                *)
                    # No change needed
                    echo "No folder rename needed"
                    return 0
                    ;;
            esac
            ;;
    esac
    
    echo "renaming to $new_name" >> "$LOG"
    # Only rename if name would change
    if [ "$folder" != "$new_name" ]; then
        if mv "$folder" "$new_name"; then
            return 0
        else
            echo "Failed to rename folder" >&2
            return 1
        fi
    fi
}

showhide_subfolders() {
	# validate $1 is provided
	case "$2" in
		"disable")
			# Add .disabled to all folders in $DIR
			for d in "$1"/*/ ; do
				case "$d" in
					*") -"*)
						showhide_folder "$d" "disable"
						;;
					*)
						echo "Not a sub setting. Skipping."
						;;
				esac
			done 
			;;
		"enable")
			# Remove .disabled from all folders in $DIR
			for d in "$1"/*.disabled/ ; do
				case "$d" in
					*") -"*)
						showhide_folder "$d" "enable"
						;;
					*)
						echo "Not a sub setting. Skipping."
						;;
				esac
			done
			;;
		*)
			echo "Unknown parameter: $2"
			exit 1
			;;
	esac
}

showhide_folder() {
	case "$2" in
		"disable")
            if [ -d "$1" ]; then
                case "${1%/}" in
                    *.disabled) 
                        echo "Already suffixed with .disabled. Skipping."
                        ;;
                    *) 
                        mv "$1" "${1%/}.disabled"
                        ;;
                esac
            fi
			;;
		"enable")
			if [ -d "$1" ] && [ "${1%.disabled/}" != "${1%/}" ]; then
				mv "$1" "${1%.disabled/}"
			fi
			;;
		*)
			echo "Unknown parameter: $2"
			exit 1
			;;
	esac
}
