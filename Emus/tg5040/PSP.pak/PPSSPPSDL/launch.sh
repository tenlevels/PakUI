#!/bin/sh

mydir=`dirname "$0"`

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$mydir
export HOME=$mydir

#uneeded lib path from trimui, adding to check if needed later
#export SDL_GAMECONTROLLERCONFIG_FILE=OLDPWD=/mnt/SDCARD/Emus/tg5040/PSP.pak/PPSSPPSDL/assets/gamecontrollerdb.txt
#export LD_LIBRARY_PATH=./:/mnt/SDCARD:/mnt/SDCARD/lib:/mnt/UDISK:/usr/trimui/lib/:/usr/miyoo/lib:/customer/lib/:/config/lib/:/lib:/usr/lib::/mnt/SDCARD/Emus/PPSSPP
#export OLDPWD=/mnt/SDCARD/Emus/tg5040/PSP.pak/PPSSPPSDL

cd $mydir

echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo 1416000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq

./PPSSPPSDL "$1"


