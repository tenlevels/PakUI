#!/bin/sh
DIR=$(dirname "$0")
. "$DIR/../../../scripts.disabled/common.sh"
. "$DIR/../../../scripts.disabled/lib/led_update.sh"

load_settings
color_value="00FF00"
effect_value="9"
color_shift_spread="60"
save_settings

update_leds

