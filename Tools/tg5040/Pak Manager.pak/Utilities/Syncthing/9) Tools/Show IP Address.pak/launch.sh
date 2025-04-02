#!/bin/sh

DIR="$(dirname "$0")"
TOOLS_PATH="$(dirname "$DIR")"
export MODULE_PATH="$(dirname "$TOOLS_PATH")"

. "$MODULE_PATH/.scripts/common.sh"

ip_addr=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

if [ -z $ip_addr ]; then
    ip_addr="NA"
fi

display_message "IP Address: $ip_addr" 7