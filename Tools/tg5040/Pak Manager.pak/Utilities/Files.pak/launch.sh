#!/bin/sh
cd $(dirname "$0")

export LD_LIBRARY_PATH=$(dirname "$0")/lib:$LD_LIBRARY_PATH

./gptokeyb -k "DinguxCommander" -c "./DinguxCommander.gptk" &
sleep 1
./DinguxCommander
kill -9 "$(pidof gptokeyb)"