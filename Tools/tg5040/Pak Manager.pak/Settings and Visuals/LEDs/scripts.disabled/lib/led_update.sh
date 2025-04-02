#!/bin/sh

# Define file paths
LOG="$LED_MODULE_PATH/scripts.disabled/led_log.txt"

. "$LED_MODULE_PATH/scripts.disabled/lib/env.sh"

# determine if single color or multi color
update_leds() {
    if [ "$effect_value" -ge 0 ] && [ "$effect_value" -le 7 ]; then
        effect_enabled="1"
        animation_enabled="0"
        save_settings
        reset_animations
        reset_brightness
        apply_effects
        configure_effect_folders       
    else
        effect_enabled=0
        animation_enabled="1"
        save_settings
        reset_effects
        reset_brightness
        apply_animation
        configure_animation_folders
    fi
    }

apply_animation() {
    log_message "checking for and killing existing process"

    killall animation.sh 2>/dev/null
    killall led_animation 2>/dev/null
    killall brightness_sync.sh 2>/dev/null

    log_message "parsing active led states"
	# Parse active LED states
    IFS=','
    set -- $active_leds
    f1_active=$1
    f2_active=$2
    top_active=$3
    rear_active=$4

    # Disable single color effects
    echo 0 > "$LED_ENABLE"

    # Enable these unknown settings
    echo 1 > "$BASE/anim_frames_len"
    echo -1 > "$BASE/anim_frames_cycle"

    log_message "configuring LEDs"
    # Configure front LEDs
    if [ "$f1_active" -eq 1 ] || [ "$f2_active" -eq 1 ]; then
		# Disable single color effects
		echo 4 > "$LED_EFFECT_F1"
		echo 4 > "$LED_EFFECT_F2"
		echo 0 > "$LED_ANIMATION_FRONT_ENABLE"
		echo "$bright_value" > "$LED_BRIGHT_F1F2"
    else
        echo 0 > "$LED_EFFECT_F1"
        echo 0 > "$LED_EFFECT_F2"
		echo 0 > "$LED_BRIGHT_F1F2"
        echo 0 > "$LED_ANIMATION_FRONT_ENABLE"
    fi

    # Configure top LEDs
    if [ "$top_active" -eq 1 ]; then
		# Disable single color effects
		echo 4 > "$LED_EFFECT_TOP"
		echo 0 > "$LED_ANIMATION_TOP_ENABLE"
		echo "$bright_value" > "$LED_BRIGHT_TOP"
    else
        echo 0 > "$LED_EFFECT_TOP"
		echo 0 > "$LED_BRIGHT_TOP"
        echo 0 > "$LED_ANIMATION_TOP_ENABLE"
    fi

    # Configure top LEDs
    if [ "$rear_active" -eq 1 ]; then
		# Disable single color effects
        echo 4 > "$LED_EFFECT_REAR"
        echo 4 > "$LED_EFFECT_REAR_L"
        echo 4 > "$LED_EFFECT_REAR_R" 
		echo 0 > "$LED_ANIMATION_REAR_ENABLE"
		echo "$bright_value" > "$LED_BRIGHT_REAR"
    else
        echo 0 > "$LED_EFFECT_REAR"
		echo 0 > "$LED_BRIGHT_REAR"
        echo 0 > "$LED_ANIMATION_REAR_ENABLE"
    fi
    
	# Determine color spacing and speed based on speed value
    log_message "getting spacing and sleep times based on speed"
	case "$speed_value" in
		"HIGHEST")
			hue_increment=12
			sleep=0.1
            position_increment=6
			;;
		"HIGH")
			hue_increment=5
			sleep=0.1
            position_increment=3
			;;
		"MEDIUM")
			hue_increment=2
			sleep=0.1
            position_increment=2
			;;
		"LOW")
			hue_increment=1
			sleep=0.2
            position_increment=1
			;;
		"LOWEST")
			hue_increment=1
			sleep=0.25
            position_increment=1
			;;
		*)
			hue_increment=5
            sleep=0.1
            position_increment=1
			;;
	esac


    front_bright=$(( $f1_active * $bright_value ))
    top_bright=$(( $top_active * $bright_value ))
    rear_bright=$(( $rear_active * $bright_value ))

	# Start animation based on animation effect
    log_message "starting animation"
    case "$effect_value" in
        "8")
            log_message "color shift"
            $ANIMATION_PROGRAM $effect_value $hue_increment $sleep $color_value $color_shift_spread & animation_pid=$!
            $BRIGHT_SYNC $front_bright $top_bright $rear_bright $animation_pid &
            ;;
        "9")
            log_message "static color shift"
            $ANIMATION_PROGRAM $effect_value $color_value $color_shift_spread & animation_pid=$!
            $BRIGHT_SYNC $front_bright $top_bright $rear_bright $animation_pid &
            ;;

        "10")
            log_message "single color chase"
            $ANIMATION_PROGRAM $effect_value $color_value $position_increment & animation_pid=$!
            $BRIGHT_SYNC $front_bright $top_bright $rear_bright $animation_pid &
            ;;

        "11")
            log_message "static rainbow"
            $ANIMATION_PROGRAM $effect_value $rainbow_color_spread & animation_pid=$!
            $BRIGHT_SYNC $front_bright $top_bright $rear_bright $animation_pid &
            ;;
        "12")
            log_message "scrolling rainbow"
            $ANIMATION_PROGRAM $effect_value $hue_increment $sleep $rainbow_color_spread & animation_pid=$!
            $BRIGHT_SYNC $front_bright $top_bright $rear_bright $animation_pid &
            ;;
        
        "13")
            log_message "sequential rainbow"
            $ANIMATION_PROGRAM $effect_value $hue_increment $sleep & animation_pid=$!
            $BRIGHT_SYNC $front_bright $top_bright $rear_bright $animation_pid &
            ;;
        "14")
            log_message "rainbow chase"
            $ANIMATION_PROGRAM $effect_value $hue_increment $sleep $rainbow_color_spread $position_increment & animation_pid=$!
            $BRIGHT_SYNC $front_bright $top_bright $rear_bright $animation_pid &
            ;;

        *)
            log_message "Invalid animation effect"
            ;;
    esac
}


apply_effects() {
    # Parse active LED states
    IFS=','
    set -- $active_leds
    f1_active=$1
    f2_active=$2
    top_active=$3
    rear_active=$4
	
    killall brightness_sync.sh 2>/dev/null

    # Set duration based on effect
    DURATION=$(get_duration "$effect_value" "$speed_value")

    # Disable current config
    echo 0 > "$LED_ENABLE"
    
    if [ "$DEVICE" = "brick" ]; then
        configure_brick_effect
    else
        echo "$ACTIVE_CYCLES" > "$LED_CYCLES_REAR"
        echo "$ACTIVE_CYCLES" > "$LED_CYCLES_REAR_L"
        echo "$ACTIVE_CYCLES" > "$LED_CYCLES_REAR_R"
        echo "$DURATION" > "$LED_DURATION_REAR"
        echo "$DURATION" > "$LED_DURATION_REAR_L"
        echo "$DURATION" > "$LED_DURATION_REAR_R"
        echo "$color_value" > "$LED_COLOR_REAR"   
        echo "$effect_value" > "$LED_EFFECT_REAR"
        echo "$effect_value" > "$LED_EFFECT_REAR_L"
        echo "$effect_value" > "$LED_EFFECT_REAR_R"
        echo "$bright_value" > "$LED_BRIGHT_TOP"
    fi
    # Re-enable new config
    echo 1 > "$LED_ENABLE"

    front_bright=$(( $f1_active * $bright_value ))
    top_bright=$(( $top_active * $bright_value ))
    rear_bright=$(( $rear_active * $bright_value ))

    $BRIGHT_SYNC $front_bright $top_bright $rear_bright &
}


apply_standby_color() {
    # Validate hex color code format
    case "$1" in
        [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])
            # if effects are enabled, don't update LEDs. standby color will be set
            # when effects are disabled or when device starts up
            if [ "$animation_enabled" = "0" ] && [ "$effect_enabled" = "0" ]; then
                # Disable any existing effects
                echo 0 > "$LED_ENABLE"
                
                # Set RGB color for both LEDs
                echo "$1" > "$LED_COLOR_F1"
                echo "$1" > "$LED_COLOR_F2"

                # Set single cycle
                echo 1 > "$LED_CYCLES_F1"
                echo 1 > "$LED_CYCLES_F2"

                # Set duration
                echo "2000" > "$LED_DURATION_F1"
                echo "2000" > "$LED_DURATION_F2"

                # Set breathing effect
                echo 2 > "$LED_EFFECT_F1"
                echo 2 > "$LED_EFFECT_F2"
                
                # Run in background
                (
                    echo 20 > "$LED_BRIGHT_F1F2"
                    echo 1 > "$LED_ENABLE"
                    sleep 1
                    echo 0 > "$LED_BRIGHT_F1F2"
                ) &
            fi
            ;;
        *)
            echo "Usage: apply_standby_color HEXCOLOR" 
            exit 1
            ;;
    esac
}

reset_animations() {
    killall animation.sh 2>/dev/null
    killall led_animation 2>/dev/null
    killall brightness_sync.sh 2>/dev/null

    echo 0 > "$BASE/anim_frames_len" 2>/dev/null
	echo 0 > "$BASE/anim_frames_cycle" 2>/dev/null
	echo 0 > "$BASE/anim_frames_fps" 2>/dev/null
    echo 0 > "$LED_ANIMATION_FRONT_ENABLE" 2>/dev/null
	echo 0 > "$LED_ANIMATION_TOP_ENABLE" 2>/dev/null
	echo 0 > "$LED_ANIMATION_REAR_ENABLE" 2>/dev/null
    blank_frame=""
    for i in $(seq 0 22); do
        blank_frame="${blank_frame}000000 "
    done
	echo "$blank_frame" > "$BASE/anim_frames_hex" 2>/dev/null
    echo "$blank_frame" > "$BASE/frame_hex" 2>/dev/null
	echo 0 > "$BASE/anim_frames_enable" 2>/dev/null
}

reset_effects() {
    killall brightness_sync.sh 2>/dev/null

	echo 0 > "$LED_CYCLES_F1" 2>/dev/null
	echo 0 > "$LED_CYCLES_F2" 2>/dev/null
	echo 0 > "$LED_CYCLES_TOP" 2>/dev/null
	echo 0 > "$LED_CYCLES_REAR" 2>/dev/null
	echo 0 > "$LED_CYCLES_REAR_L" 2>/dev/null
	echo 0 > "$LED_CYCLES_REAR_R" 2>/dev/null
    echo 2000 > "$LED_DURATION_F1" 2>/dev/null
    echo 2000 > "$LED_DURATION_F2" 2>/dev/null
    echo 2000 > "$LED_DURATION_TOP" 2>/dev/null
    echo 2000 > "$LED_DURATION_REAR" 2>/dev/null
    echo 2000 > "$LED_DURATION_REAR_L" 2>/dev/null
    echo 2000 > "$LED_DURATION_REAR_R" 2>/dev/null
	echo 000000 > "$LED_COLOR_F1" 2>/dev/null
    echo 000000 > "$LED_COLOR_F2" 2>/dev/null
	echo 000000 > "$LED_COLOR_TOP" 2>/dev/null
	echo 000000 > "$LED_COLOR_REAR" 2>/dev/null
	echo 000000 > "$LED_COLOR_LEFT" 2>/dev/null
	echo 000000 > "$LED_COLOR_RIGHT" 2>/dev/null
    blank_frame=""
    for i in $(seq 0 22); do
        blank_frame="${blank_frame}000000 "
    done
    echo "$blank_frame" > "$BASE/frame_hex" 2>/dev/null
	echo 0 > "$LED_EFFECT_F1" 2>/dev/null
	echo 0 > "$LED_EFFECT_F2" 2>/dev/null
	echo 0 > "$LED_EFFECT_TOP" 2>/dev/null
	echo 0 > "$LED_EFFECT_REAR" 2>/dev/null
	echo 0 > "$LED_EFFECT_REAR_L" 2>/dev/null
	echo 0 > "$LED_EFFECT_REAR_R" 2>/dev/null
    echo 0 > "$LED_ENABLE" 2>/dev/null
}

reset_brightness() {
	echo 0 > "$LED_BRIGHT_F1F2"
	echo 0 > "$LED_BRIGHT_TOP"
	echo 0 > "$LED_BRIGHT_REAR"
}

reset_low_battery_ind() {
    killall batt_mon 2>/dev/null
    killall low_batt_led 2>/dev/null
    enabledisable_rename "$LED_MODULE_PATH/9) Tools/1) Low Battery Indicator/0) Disable.pak" "disable"

}

get_animation_status() {
    # First check overall animation enable
    if [ "$(cat "$LED_ANIMATION_ENABLE")" = "0" ]; then
        return 0
    fi

    # If animation is enabled, check if any LEDs have brightness
    if [ "$(cat "$LED_BRIGHT_F1F2")" != "0" ] || [ "$(cat "$LED_BRIGHT_TOP")" != "0" ] || [ "$(cat "$LED_BRIGHT_REAR")" != "0" ]; then
        # At least one LED is bright, check individual animation enables
        if [ "$(cat "$LED_ANIMATION_FRONT_ENABLE")" = "1" ] || [ "$(cat "$LED_ANIMATION_TOP_ENABLE")" = "1" ] || [ "$(cat "$LED_ANIMATION_REAR_ENABLE")" = "1" ]; then
            return 1
        fi
    fi

    return 0
}

update_brightness() {
    
    # Parse active LED states
    IFS=','
    set -- $active_leds
    f1_active=$1
    f2_active=$2
    top_active=$3
    rear_active=$4

    front_bright=$(( $f1_active * $bright_value ))
    top_bright=$(( $top_active * $bright_value ))
    rear_bright=$(( $rear_active * $bright_value ))

    killall brightness_sync.sh 2>/dev/null

	echo "$front_bright" > "$LED_BRIGHT_F1F2"
	echo "$top_bright" > "$LED_BRIGHT_TOP"
	echo "$rear_bright" > "$LED_BRIGHT_REAR"

    if [ "$effect_value" -ge 0 ] && [ "$effect_value" -le 7 ]; then
        $BRIGHT_SYNC $front_bright $top_bright $rear_bright &
    else
        ANIMATION_PID=$(pgrep -f "led_animation")
        [ ! -z "$ANIMATION_PID" ] && $BRIGHT_SYNC $front_bright $top_bright $rear_bright $ANIMATION_PID &
    fi
}

update_color() {
    if [ "$effect_value" -ge 0 ] && [ "$effect_value" -le 10 ]; then
        if [ "$effect_value" -gt 7 ] && [ "$effect_value" -le 9 ]; then
            if [ "$color_value" = "FFFFFF" ]; then
                effect_value=4
            fi
        fi
        update_leds
    else
        effect_value=4
        save_settings
        update_leds
    fi
}

get_duration() {
    local effect=$1
    local speed=$2

    case "$effect:$speed" in
        "2:LOW")    echo "6000" ;;
        "2:MEDIUM") echo "5000" ;;
        "2:HIGH")   echo "2000" ;;
        "5:LOW")    echo "5000" ;;
        "5:MEDIUM") echo "3000" ;;
        "5:HIGH")   echo "1000" ;;
        "6:LOW"|"7:LOW")       echo "5000" ;;
        "6:MEDIUM"|"7:MEDIUM") echo "2000" ;;
        "6:HIGH"|"7:HIGH")     echo "1000" ;;
        *)          echo "2000" ;;  # Default duration
    esac
}

get_animation_speed() {
    case "$1" in
        "HIGH")   echo "5 0.1" ;;
        "MEDIUM") echo "2 0.1" ;;
        "LOW")    echo "1 0.2" ;;
        "LOWEST") echo "1 0.25" ;;
        *)        echo "5 0.1" ;;  # Default
    esac
}


configure_effect_folders() {
    showhide_folder "$LED_MODULE_PATH/3) Effects (Single).disabled/" "enable"
    showhide_folder "$LED_MODULE_PATH/3) Effects (Multi)/" "disable"
    if [ "$effect_value" = 4 ]; then
        showhide_folder "$LED_MODULE_PATH/4) Effect Options/" "disable"
    else
        showhide_folder "$LED_MODULE_PATH/4) Effect Options.disabled/" "enable"
        showhide_folder "$LED_MODULE_PATH/4) Effect Options/1) Speed.disabled/" "enable"
        showhide_folder "$LED_MODULE_PATH/4) Effect Options/2) Rainbow Width/" "disable"
        showhide_folder "$LED_MODULE_PATH/4) Effect Options/3) Shift Distance/" "disable"
    fi
    if [ "$color_value" = "FFFFFF" ]; then
        showhide_folder "$LED_MODULE_PATH/3) Effects (Single)/0) Color Shift.pak/" "disable"
        showhide_folder "$LED_MODULE_PATH/3) Effects (Single)/1) Color Shift Static.pak/" "disable"
    else
        showhide_folder "$LED_MODULE_PATH/3) Effects (Single)/0) Color Shift.pak.disabled/" "enable"
        showhide_folder "$LED_MODULE_PATH/3) Effects (Single)/1) Color Shift Static.pak.disabled/" "enable"    
    fi        
    if [ "$DEVICE" != "brick" ]; then
        showhide_folder "$LED_MODULE_PATH/5) Zones/" "disable"
    fi
    enabledisable_rename "$LED_MODULE_PATH/0) Enable.pak" "enable"    
}

# 8 = single color chase
# 9 - static rainbow
# 10 - rainbow marquee
# 11 - sequential rainbow
# 12 - rainbow chase

configure_animation_folders() {
    showhide_folder "$LED_MODULE_PATH/4) Effect Options.disabled/" "enable"
    if [ "$effect_value" -ge 8 ] && [ "$effect_value" -le 10 ]; then
        showhide_folder "$LED_MODULE_PATH/3) Effects (Single).disabled/" "enable"
        showhide_folder "$LED_MODULE_PATH/3) Effects (Multi)/" "disable"
        if [ "$effect_value" = 9 ]; then
            showhide_folder "$LED_MODULE_PATH/4) Effect Options/1) Speed/" "disable"
            
        else
            showhide_folder "$LED_MODULE_PATH/4) Effect Options/1) Speed.disabled/" "enable"
        fi  
        showhide_folder "$LED_MODULE_PATH/4) Effect Options/2) Rainbow Width/" "disable"
        if [ "$color_value" != "FFFFFF" ]; then
            showhide_folder "$LED_MODULE_PATH/4) Effect Options/3) Shift Distance.disabled/" "enable"
            showhide_folder "$LED_MODULE_PATH/3) Effects (Single)/0) Color Shift.pak.disabled/" "enable"
            showhide_folder "$LED_MODULE_PATH/3) Effects (Single)/1) Color Shift Static.pak.disabled/" "enable"
        else
            showhide_folder "$LED_MODULE_PATH/4) Effect Options/3) Shift Distance/" "disable"
            showhide_folder "$LED_MODULE_PATH/3) Effects (Single)/0) Color Shift.pak/" "disable"
            showhide_folder "$LED_MODULE_PATH/3) Effects (Single)/1) Color Shift Static.pak/" "disable"
        fi
        if [ "$effect_value" = 10 ]; then
            showhide_folder "$LED_MODULE_PATH/4) Effect Options/3) Shift Distance/" "disable"
            
        else
            showhide_folder "$LED_MODULE_PATH/4) Effect Options/3) Shift Distance.disabled/" "enable"
        fi        
    else
        showhide_folder "$LED_MODULE_PATH/3) Effects (Single)/" "disable"
        showhide_folder "$LED_MODULE_PATH/3) Effects (Multi).disabled/" "enable"
        showhide_folder "$LED_MODULE_PATH/4) Effect Options/3) Shift Distance/" "disable" 
        if [ "$effect_value" != 11 ]; then
            showhide_folder "$LED_MODULE_PATH/4) Effect Options/1) Speed.disabled/" "enable"
        else
            showhide_folder "$LED_MODULE_PATH/4) Effect Options/1) Speed/" "disable"
        fi

        if [ "$effect_value" != 13 ]; then
            showhide_folder "$LED_MODULE_PATH/4) Effect Options/2) Rainbow Width.disabled/" "enable"
        else
            showhide_folder "$LED_MODULE_PATH/4) Effect Options/2) Rainbow Width/" "disable"
        fi
    fi
    if [ "$DEVICE" != "brick" ]; then
        showhide_folder "$LED_MODULE_PATH/5) Zones/" "disable"
    fi
    enabledisable_rename "$LED_MODULE_PATH/0) Enable.pak" "enable"
}

configure_disabled_folders() {
    enabledisable_rename "$LED_MODULE_PATH/0) Disable.pak" "disable"
    showhide_folder "$LED_MODULE_PATH/1) Colors/" "disable"
    showhide_folder "$LED_MODULE_PATH/2) Brightness/" "disable"
    showhide_folder "$LED_MODULE_PATH/3) Effects (Single)/" "disable"
    showhide_folder "$LED_MODULE_PATH/3) Effects (Multi)/" "disable"
    showhide_folder "$LED_MODULE_PATH/4) Effect Options/" "disable"
    showhide_folder "$LED_MODULE_PATH/5) Zones/" "disable"    
}

configure_enabled_folders() {
    showhide_folder "$LED_MODULE_PATH/1) Colors.disabled/" "enable"
    showhide_folder "$LED_MODULE_PATH/2) Brightness.disabled/" "enable"
    if [ "$effect_value" -le 7 ]; then
        configure_effect_folders
    else
        configure_animation_folders
    fi
    if [ "$DEVICE" != "brick" ]; then
        showhide_folder "$LED_MODULE_PATH/5) Zones/" "disable"
    else
        showhide_folder "$LED_MODULE_PATH/5) Zones.disabled/" "enable"
    fi
    enabledisable_rename "$LED_MODULE_PATH/0) Enable.pak" "enable"
}

configure_brick_effect() {
    # Configure front LEDs
    if [ "$f1_active" -eq 1 ] || [ "$f2_active" -eq 1 ]; then
        echo "$ACTIVE_CYCLES" > "$LED_CYCLES_F1"
        echo "$ACTIVE_CYCLES" > "$LED_CYCLES_F2"
        echo "$DURATION" > "$LED_DURATION_F1"
        echo "$DURATION" > "$LED_DURATION_F2"
		echo "$color_value" > "$LED_COLOR_F1"
        echo "$color_value" > "$LED_COLOR_F2"
        echo "$effect_value" > "$LED_EFFECT_F1"
        echo "$effect_value" > "$LED_EFFECT_F2"
		echo "$bright_value" > "$LED_BRIGHT_F1F2"
    else
		echo "0" > "$LED_CYCLES_F1"
        echo "0" > "$LED_CYCLES_F2"
        echo "000000" > "$LED_COLOR_F1"
        echo "000000" > "$LED_COLOR_F2"
        echo "0" > "$LED_EFFECT_F1"
        echo "0" > "$LED_EFFECT_F2"
        echo "0" > "$LED_BRIGHT_F1F2"
    fi
    
    # Configure top LED
    if [ "$top_active" -eq 1 ]; then
        echo "$ACTIVE_CYCLES" > "$LED_CYCLES_TOP"
        echo "$DURATION" > "$LED_DURATION_TOP"
        echo "$color_value" > "$LED_COLOR_TOP"
        echo "$effect_value" > "$LED_EFFECT_TOP"
        echo "$bright_value" > "$LED_BRIGHT_TOP"
    else
	    echo "0" > "$LED_CYCLES_TOP"
        echo "000000" > "$LED_COLOR_TOP"
        echo "0" > "$LED_EFFECT_TOP"
		echo "0" > "$LED_BRIGHT_TOP"
    fi
    
    # Configure rear LEDs
    if [ "$rear_active" -eq 1 ]; then
        echo "$ACTIVE_CYCLES" > "$LED_CYCLES_REAR"
        echo "$ACTIVE_CYCLES" > "$LED_CYCLES_REAR_L"
        echo "$ACTIVE_CYCLES" > "$LED_CYCLES_REAR_R"
        echo "$DURATION" > "$LED_DURATION_REAR"
        echo "$DURATION" > "$LED_DURATION_REAR_L"
        echo "$DURATION" > "$LED_DURATION_REAR_R"
		echo "$color_value" > "$LED_COLOR_REAR"   
        echo "$effect_value" > "$LED_EFFECT_REAR"
        echo "$effect_value" > "$LED_EFFECT_REAR_L"
        echo "$effect_value" > "$LED_EFFECT_REAR_R"
		echo "$bright_value" > "$LED_BRIGHT_REAR"
    else
	    echo "0" > "$LED_CYCLES_REAR"
        echo "0" > "$LED_CYCLES_REAR_L"
        echo "0" > "$LED_CYCLES_REAR_R"
        echo "000000" > "$LED_COLOR_REAR"
        echo "0" > "$LED_EFFECT_REAR"
        echo "0" > "$LED_BRIGHT_REAR"
    fi
}