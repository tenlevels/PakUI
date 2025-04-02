#!/bin/sh
#!/bin/sh
PAK_PATH=$(dirname "$0")
MODULE_PATH=$(readlink -f "$PAK_PATH/../..")

AUTO_PATH="/mnt/SDCARD/.userdata/$PLATFORM/auto.sh"

. "$MODULE_PATH/scripts.disabled/common.sh"
. "$MODULE_PATH/scripts.disabled/lib/led_update.sh"

load_settings
effect_enabled="0"
animation_enabled="0"
reset_animations
reset_effects
reset_brightness
apply_standby_color "00FF33"

# hide everything, unhide install pak
configure_disabled_folders
showhide_folder "$LED_MODULE_PATH/0) Enable.pak/" "disable"
showhide_folder "$LED_MODULE_PATH/0) Disable.pak/" "disable"
showhide_folder "$LED_MODULE_PATH/Install.pak.disabled/" "enable"
showhide_folder "$LED_MODULE_PATH/9) Tools/" "disable"
# remove led startup script to system auto.sh
sed -i '/led_startup.sh/d' "$AUTO_PATH"
rm "$MODULE_PATH/scripts.disabled/config/led.conf"
