#!/bin/sh
DIR=$(dirname "$0")
. "$DIR/../../../scripts.disabled/common.sh"
. "$DIR/../../../scripts.disabled/lib/led_update.sh"

load_settings
standby_color="FFFF00"
apply_standby_color "$standby_color"
save_settings

