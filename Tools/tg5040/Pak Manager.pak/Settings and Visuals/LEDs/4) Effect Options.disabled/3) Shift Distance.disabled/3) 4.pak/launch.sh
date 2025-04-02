#!/bin/sh
DIR=$(dirname "$0")
. "$DIR/../../../scripts.disabled/common.sh"
. "$DIR/../../../scripts.disabled/lib/led_update.sh"

load_settings
color_shift_spread="75"
save_settings
update_leds
