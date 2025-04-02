#!/bin/sh
if [ -z "$DEVICE" ]; then
    if [ "$PLATFORM" = "tg3040" ]; then
        DEVICE="brick"
    fi
fi

ANIMATION_PROGRAM="$LED_MODULE_PATH/scripts.disabled/bin/led_animation"
BRIGHT_SYNC="$LED_MODULE_PATH/scripts.disabled/lib/brightness_sync.sh"

HSVTORGB="$LED_MODULE_PATH/scripts.disabled/bin/hsv_to_rgb"
BATT_MON="$LED_MODULE_PATH/scripts.disabled/bin/batt_mon"
LOW_BATT_LED_SCRIPT="$LED_MODULE_PATH/scripts.disabled/lib/low_batt_led_init.sh"

BASE="/sys/class/led_anim"

# Define LED effect paths
LED_EFFECT_F1="$BASE/effect_f1"
LED_EFFECT_F2="$BASE/effect_f2"
LED_EFFECT_TOP="$BASE/effect_m"
LED_EFFECT_REAR="$BASE/effect_lr"
LED_EFFECT_REAR_L="$BASE/effect_l"
LED_EFFECT_REAR_R="$BASE/effect_r"

# Define LED color paths
LED_COLOR_F1="$BASE/effect_rgb_hex_f1"
LED_COLOR_F2="$BASE/effect_rgb_hex_f2"
LED_COLOR_TOP="$BASE/effect_rgb_hex_m"
LED_COLOR_REAR="$BASE/effect_rgb_hex_lr"
LED_COLOR_LEFT="$BASE/effect_rgb_hex_l"
LED_COLOR_RIGHT="$BASE/effect_rgb_hex_r"
# Define LED brightness paths
LED_BRIGHT_F1F2="$BASE/max_scale_f1f2"
LED_BRIGHT_TOP="$BASE/max_scale"
LED_BRIGHT_REAR="$BASE/max_scale_lr"

# Define LED cycle paths
LED_CYCLES_F1="$BASE/effect_cycles_f1"
LED_CYCLES_F2="$BASE/effect_cycles_f2"
LED_CYCLES_TOP="$BASE/effect_cycles_m"
LED_CYCLES_REAR="$BASE/effect_cycles_lr"
LED_CYCLES_REAR_L="$BASE/effect_cycles_l"
LED_CYCLES_REAR_R="$BASE/effect_cycles_r"

# Define LED duration paths
LED_DURATION_F1="$BASE/effect_duration_f1"
LED_DURATION_F2="$BASE/effect_duration_f2"
LED_DURATION_TOP="$BASE/effect_duration_m"
LED_DURATION_REAR="$BASE/effect_duration_lr"
LED_DURATION_REAR_L="$BASE/effect_duration_l"
LED_DURATION_REAR_R="$BASE/effect_duration_r"

LED_ENABLE="$BASE/effect_enable"

LED_ANIMATION_ENABLE="$BASE/anim_frames_enable"

LED_ANIMATION_FRONT_ENABLE="$BASE/anim_frames_mask_f1f2_enable"
LED_ANIMATION_TOP_ENABLE="$BASE/anim_frames_mask_m_enable"
LED_ANIMATION_REAR_ENABLE="$BASE/anim_frames_mask_lr_enable"

# Unlimited number of cycles when active
ACTIVE_CYCLES="-1"