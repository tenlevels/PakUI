#!/bin/sh
cd "$(dirname "$0")"
export LD_LIBRARY_PATH="/usr/trimui/lib:$LD_LIBRARY_PATH"
SHOW_MESSAGE="./show_message"

# Get battery percentage
battery=$(cat /sys/class/power_supply/axp2202-battery/capacity)

# Get current CPU frequency in MHz
cpu_freq=$(cat /sys/devices/system/cpu/cpufreq/policy0/cpuinfo_cur_freq)
cpu_freq_mhz=$((cpu_freq / 1000))

# Get SD card storage info in the desired format
storage_used=$(df -h /mnt/SDCARD | awk 'NR==2 {print $3}' | tr -d 'G')
storage_total=$(df -h /mnt/SDCARD | awk 'NR==2 {print $2}' | tr -d 'G')
storage_info="${storage_used}g/${storage_total}g"

# Show all information in a single message
"$SHOW_MESSAGE" "Battery: ${battery}%|CPU: ${cpu_freq_mhz}MHz|SD Card: ${storage_info}" -l a