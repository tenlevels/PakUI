#!/bin/sh
CONNECTING_IMAGE="/mnt/SDCARD/Tools/$PLATFORM/Moonlight.pak/res/connecting.png"
NO_WIFI_IMAGE="/mnt/SDCARD/Tools/$PLATFORM/Moonlight.pak/res/nowifi.png"

show_image() {
   show.elf "$1" &
   sleep 2
   pkill -f "show.elf"
}

check_connectivity() {
   ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 ||
   ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 ||
   ping -c 1 -W 2 208.67.222.222 >/dev/null 2>&1 ||
   ping -c 1 -W 2 114.114.114.114 >/dev/null 2>&1 ||
   ping -c 1 -W 2 119.29.29.29 >/dev/null 2>&1
}

show_image "$CONNECTING_IMAGE"

if ! check_connectivity; then
   show_image "$NO_WIFI_IMAGE"
   exit 1
fi

progdir=`dirname "$0"`
cd $progdir
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$progdir
echo 1 > /tmp/stay_awake
./moonlightui
rm /tmp/stay_awake