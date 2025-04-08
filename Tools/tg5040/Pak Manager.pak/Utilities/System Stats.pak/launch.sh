#!/bin/sh
cd "$(dirname "$0")"
export LD_LIBRARY_PATH="/usr/trimui/lib:$LD_LIBRARY_PATH"
SHOW_MESSAGE="./show_message"
battery=$(cat /sys/class/power_supply/axp2202-battery/capacity)
storage_used=$(df -h /mnt/SDCARD | awk 'NR==2 {print $3}' | tr -d 'G')
storage_total=$(df -h /mnt/SDCARD | awk 'NR==2 {print $2}' | tr -d 'G')
storage_info="${storage_used}g/${storage_total}g"
"$SHOW_MESSAGE" "Battery: ${battery}%|SD Card: ${storage_info}" -l a