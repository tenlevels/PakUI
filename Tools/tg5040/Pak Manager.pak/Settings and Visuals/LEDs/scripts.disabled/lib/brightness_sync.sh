#!/bin/sh
BASE="/sys/class/led_anim"
LED_BRIGHT_F1F2="$BASE/max_scale_f1f2"
LED_BRIGHT_TOP="$BASE/max_scale"
LED_BRIGHT_REAR="$BASE/max_scale_lr"
EFFECT_ENABLED="$BASE/effect_enable"

if [ -z "$4" ]; then
    # Monitor effect enable status
    while [ "$(cat "$EFFECT_ENABLED" 2>/dev/null)" = "1" ]; do
        echo "$1" > "$LED_BRIGHT_F1F2" 2>/dev/null
        echo "$2" > "$LED_BRIGHT_TOP" 2>/dev/null
        echo "$3" > "$LED_BRIGHT_REAR" 2>/dev/null
        sleep 1
    done
else
    # Monitor process existence
    while [ -d "/proc/$4" ]; do
        echo "$1" > "$LED_BRIGHT_F1F2" 2>/dev/null
        echo "$2" > "$LED_BRIGHT_TOP" 2>/dev/null
        echo "$3" > "$LED_BRIGHT_REAR" 2>/dev/null
        sleep 1
    done
fi

echo "0" > "$LED_BRIGHT_F1F2" 2>/dev/null
echo "0" > "$LED_BRIGHT_TOP" 2>/dev/null
echo "0" > "$LED_BRIGHT_REAR" 2>/dev/null

exit 0