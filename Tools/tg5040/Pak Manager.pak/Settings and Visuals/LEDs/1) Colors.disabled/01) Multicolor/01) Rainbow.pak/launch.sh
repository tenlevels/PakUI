#!/bin/sh
DIR=$(dirname "$0")
. "$DIR/../../../scripts.disabled/common.sh"
. "$DIR/../../../scripts.disabled/lib/led_update.sh"

load_settings
effect_value="11"
save_settings
update_leds


