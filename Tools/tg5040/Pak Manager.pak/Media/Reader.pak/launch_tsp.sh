#!/bin/sh
cd $(dirname "$0")

export SCREEN_WIDTH=1280
export SCREEN_HEIGHT=720

SDL_GAMECONTROLLERCONFIG_FILE="./gamecontrollerdb.txt" ./gptokeyb -k "reader" -c "./reader.gptk" &
sleep 1
export LD_LIBRARY_PATH=$(dirname "$0")/lib:$LD_LIBRARY_PATH
./reader 2>log.txt
kill -9 $(pidof gptokeyb) 

