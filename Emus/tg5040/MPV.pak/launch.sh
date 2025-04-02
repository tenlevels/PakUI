#!/bin/sh
progdir=$(dirname "$0")
cd "$progdir"
BB="$progdir/.bin/busybox"
"$BB" echo "$0 $*" > "$progdir/debug.log" 2>&1
export LD_LIBRARY_PATH="$progdir/.lib:/lib:/lib64:/usr/lib:/mnt/SDCARD/System/lib/"
"$BB" echo "Starting gptokeyb2..." >> "$progdir/debug.log" 2>&1
"$progdir/.bin/gptokeyb2" -1 "mpv" -c "keys.gptk" & 
"$BB" sleep 1
"$BB" echo 1 > /tmp/stay_awake
"$BB" echo "Launching MPV with LD_LIBRARY_PATH=$LD_LIBRARY_PATH" >> "$progdir/debug.log" 2>&1
"$BB" mkdir -p /mnt/SDCARD/Screenshots
HOME="$progdir" "$progdir/.bin/mpv" "$1" --fullscreen --audio-buffer=1 --screenshot-directory="/mnt/SDCARD/Screenshots" --screenshot-template="%F-%n" >> "$progdir/debug.log" 2>&1
"$BB" rm /tmp/stay_awake





