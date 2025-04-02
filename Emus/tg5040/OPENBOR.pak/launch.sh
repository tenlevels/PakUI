#!/bin/sh

while :; do
    syncsettings.elf
done &
LOOP_PID=$!
echo $0 $*
#source /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh
progdir=`dirname "$0"`
cd $progdir
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$progdir

./OpenBOR "$1"

kill $LOOP_PID

