#!/bin/sh
DIR=$(dirname "$0")
. "$DIR/../../scripts.disabled/common.sh"
. "$DIR/../../scripts.disabled/lib/led_update.sh"

load_settings

# Split current active_leds into array
IFS=',' read -r led1 led2 led3 led4 << EOF
$active_leds
EOF

# Toggle led1 and led2 together (0 becomes 1, 1 becomes 0)
if [ "$led1" = "1" ]; then
    led1=0
    led2=0
else
    led1=1
    led2=1
fi


# Reconstruct the pattern
active_leds="$led1,$led2,$led3,$led4"
save_settings
update_leds
