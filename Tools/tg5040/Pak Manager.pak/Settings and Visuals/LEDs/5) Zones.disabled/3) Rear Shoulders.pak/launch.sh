#!/bin/sh
DIR=$(dirname "$0")
. "$DIR/../../scripts.disabled/common.sh"
. "$DIR/../../scripts.disabled/lib/led_update.sh"

load_settings

# Split current active_leds into array
IFS=',' read -r led1 led2 led3 led4 << EOF
$active_leds
EOF

if [ "$led4" = "1" ]; then
    led4=0
else
    led4=1
fi


# Reconstruct the pattern
active_leds="$led1,$led2,$led3,$led4"
save_settings
update_leds
