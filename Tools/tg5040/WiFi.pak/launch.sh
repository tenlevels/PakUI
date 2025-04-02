#!/bin/sh

cd "$(dirname "$0")"
export LD_LIBRARY_PATH="/usr/trimui/lib:$LD_LIBRARY_PATH"

NETWORKS_DIR="./networks"
CONFIG_FILE="/etc/wifi/wpa_supplicant.conf"
WIFI_ENABLED_FLAG="./wifi_enabled"
CONNECTION_TIMEOUT=10
CONNECTION_RETRY_DELAY=0.5
TMP_PREFIX="wifi_"
MENU_FILE="${TMP_PREFIX}menu.txt"
SCAN_FILE="${TMP_PREFIX}scan.txt"
NETWORKS_FILE="${TMP_PREFIX}networks_found.txt"
SAVED_FILE="${TMP_PREFIX}saved_networks.txt"
OPTIONS_FILE="${TMP_PREFIX}options.txt"

mkdir -p "$NETWORKS_DIR"

get_wifi_state() {
    [ -f /sys/class/net/wlan0/operstate ] && cat /sys/class/net/wlan0/operstate || echo "down"
}

has_ip_address() {
    ip addr show wlan0 | grep -q "inet "
}

get_current_ssid() {
    if [ "$(get_wifi_state)" = "up" ] && has_ip_address; then
        iw wlan0 link | grep 'SSID' | cut -d: -f2- | xargs
    fi
}

get_signal_strength() {
    iw wlan0 link | grep 'signal' | awk '{print $2 " dBm"}'
}

get_network_key() {
    echo "$1" | sed 's/[^a-zA-Z0-9]/_/g'
}

cleanup_temp_files() {
    rm -f ./${TMP_PREFIX}*.txt
}

create_empty_config() {
    cat > "$CONFIG_FILE" << 'EOF'
ctrl_interface=/etc/wifi/sockets
update_config=1
EOF
}

restart_network_interface() {
    killall -q wpa_supplicant
    killall -q udhcpc
    sleep 1
    wpa_supplicant -B -i wlan0 -c "$CONFIG_FILE"
    sleep 2
    (udhcpc -i wlan0 -n) &
}

wait_for_connection() {
    local attempt=0
    while [ $attempt -lt $CONNECTION_TIMEOUT ]; do
        has_ip_address && return 0
        attempt=$((attempt + 1))
        sleep $CONNECTION_RETRY_DELAY
    done
    return 1
}

enable_wifi() {
    ./show_message "Enabling WiFi..." &
    rfkill unblock wifi 2>/dev/null
    ip link set wlan0 up
    sleep 1
    local connected=0
    for conf_file in "$NETWORKS_DIR"/*.conf; do
        [ -f "$conf_file" ] || continue
        local ssid
        ssid=$(grep 'ssid=' "$conf_file" | cut -d'"' -f2)
        [ -z "$ssid" ] && continue
        cat > "$CONFIG_FILE" << EOF
ctrl_interface=/etc/wifi/sockets
update_config=1

$(cat "$conf_file")
EOF
        restart_network_interface
        if wait_for_connection; then
            connected=1
            break
        fi
    done
    killall show_message
    if [ $connected -eq 1 ]; then
        touch "$WIFI_ENABLED_FLAG"
        ./show_message "Connected to|$ssid" -t 3
    else
        ./show_message "WiFi enabled|No networks connected" -t 3
        touch "$WIFI_ENABLED_FLAG"
    fi
    return 0
}

disable_wifi() {
    ./show_message "Disabling WiFi..." &
    killall -q udhcpc
    killall -q wpa_supplicant
    ip link set wlan0 down
    rm -f "$WIFI_ENABLED_FLAG"
    create_empty_config
    killall show_message
    ./show_message "WiFi disabled" -t 2
}

toggle_wifi() {
    if [ "$(get_wifi_state)" = "up" ]; then
        disable_wifi
    else
        enable_wifi
    fi
}

show_network_info() {
    local state
    state=$(get_wifi_state)
    local ssid
    ssid=$(get_current_ssid)
    if [ "$state" = "up" ] && [ -n "$ssid" ]; then
        local signal
        signal=$(get_signal_strength)
        local ip
        ip=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        ./show_message "Network: $ssid|Signal: $signal|IP: $ip" -l a
    else
        ./show_message "Not connected to any network" -l a
    fi
}

forget_network() {
    local ssid="$1"
    local key
    key=$(get_network_key "$ssid")
    if [ -f "$NETWORKS_DIR/$key.conf" ]; then
        rm -f "$NETWORKS_DIR/$key.conf"
        ./show_message "Network forgotten:|$ssid" -t 2
        [ "$(get_current_ssid)" = "$ssid" ] && disable_wifi
    else
        ./show_message "Network not found in saved list" -t 2
    fi
}

scan_networks() {
    if [ "$(get_wifi_state)" != "up" ]; then
        ./show_message "Turning on WiFi for scanning..." -t 2
        rfkill unblock wifi 2>/dev/null
        ip link set wlan0 up
        sleep 1
    fi
    ./show_message "Scanning for networks..." &
    rm -f ./$SCAN_FILE ./$NETWORKS_FILE
    for scan_attempt in 1 2; do
        iw dev wlan0 scan | while read -r line; do
            case "$line" in
                *"SSID: "*) 
                    local s
                    s=$(echo "$line" | cut -d':' -f2- | sed 's/^[ \t]*//')
                    [ -n "$s" ] && \
                    if [ -f "$NETWORKS_DIR/$(get_network_key "$s").conf" ]; then
                        echo "$s (Saved)|saved|$s" >> ./$SCAN_FILE
                    else
                        echo "$s|network|$s" >> ./$SCAN_FILE
                    fi
                ;;
            esac
        done
        sleep 1
    done
    [ -f ./$SCAN_FILE ] && awk -F'|' '!seen[$3]++' ./$SCAN_FILE > ./$NETWORKS_FILE
    killall show_message
    [ ! -s ./$NETWORKS_FILE ] && ./show_message "No networks found|Try again?" -l a && return 1
    local picker_output
    picker_output=$(./picker ./$NETWORKS_FILE) || return 1
    local selected_ssid
    selected_ssid=$(echo "$picker_output" | cut -d'|' -f3)
    [ -z "$selected_ssid" ] && ./show_message "Invalid network selection" -t 2 && return 1
    if [ -f "$NETWORKS_DIR/$(get_network_key "$selected_ssid").conf" ]; then
        connect_to_saved_network "$selected_ssid"
    else
        connect_to_new_network "$selected_ssid"
    fi
}

connect_to_new_network() {
    local ssid="$1"
    ./show_message "Enter password for|$ssid" -t 2
    local password
    password=$(./keyboard minui.ttf)
    [ $? -ne 0 ] || [ -z "$password" ] && ./show_message "No password entered" -t 2 && return 1
    cat > "$CONFIG_FILE" << EOF
ctrl_interface=/etc/wifi/sockets
update_config=1

network={
    ssid="$ssid"
    psk="$password"
    key_mgmt=WPA-PSK
}
EOF
    ./show_message "Connecting to|$ssid" &
    restart_network_interface
    local connected=0
    if wait_for_connection; then
        connected=1
    fi
    killall show_message
    if [ $connected -eq 1 ]; then
        ./show_message "Connected to|$ssid|Save this network?" -l -a "YES" -b "NO"
        [ $? -eq 0 ] && save_network "$ssid" "$password"
        touch "$WIFI_ENABLED_FLAG"
    else
        ./show_message "Failed to connect to|$ssid" -l a
    fi
}

connect_to_saved_network() {
    local ssid="$1"
    local key
    key=$(get_network_key "$ssid")
    [ ! -f "$NETWORKS_DIR/$key.conf" ] && ./show_message "Network configuration not found" -t 2 && return 1
    local block
    block=$(cat "$NETWORKS_DIR/$key.conf")
    cat > "$CONFIG_FILE" << EOF
ctrl_interface=/etc/wifi/sockets
update_config=1

$block
EOF
    ./show_message "Connecting to|$ssid" &
    restart_network_interface
    local connected=0
    if wait_for_connection; then
        connected=1
    fi
    killall show_message
    if [ $connected -eq 1 ]; then
        ./show_message "Connected to|$ssid" -t 3
        touch "$WIFI_ENABLED_FLAG"
    else
        ./show_message "Failed to connect to|$ssid" -l a
    fi
}

show_main_menu() {
    > ./$MENU_FILE
    local state
    state=$(get_wifi_state)
    local ssid
    ssid=$(get_current_ssid)
    [ "$state" = "up" ] && [ -n "$ssid" ] && echo "Connected to $ssid|info" >> ./$MENU_FILE
    if [ "$state" = "up" ]; then
        echo "Disable WiFi|toggle" >> ./$MENU_FILE
    else
        echo "Enable WiFi|toggle" >> ./$MENU_FILE
    fi
    echo "Scan Networks|scan" >> ./$MENU_FILE
    echo "Manage Networks|saved" >> ./$MENU_FILE
    local picker_output
    picker_output=$(./picker ./$MENU_FILE) || return 1
    local selection
    selection=$(echo "$picker_output" | cut -d'|' -f2)
    case "$selection" in
        info) show_network_info ;;
        toggle) toggle_wifi ;;
        scan) scan_networks ;;
        saved) show_saved_networks_menu ;;
    esac
    return 0
}

show_saved_networks_menu() {
    [ ! "$(ls -A "$NETWORKS_DIR")" ] && ./show_message "No saved networks" -t 2 && return
    > ./$SAVED_FILE
    list_saved_networks > ./$SAVED_FILE
    [ ! -s ./$SAVED_FILE ] && ./show_message "No valid saved networks found" -t 2 && return
    local picker_output
    picker_output=$(./picker ./$SAVED_FILE) || return
    local selected_ssid
    selected_ssid=$(echo "$picker_output" | cut -d'|' -f3)
    > ./$OPTIONS_FILE
    if [ "$(get_current_ssid)" = "$selected_ssid" ]; then
        echo "Disconnect|disconnect|$selected_ssid" >> ./$OPTIONS_FILE
    else
        echo "Connect|connect|$selected_ssid" >> ./$OPTIONS_FILE
    fi
    echo "Forget Network|forget|$selected_ssid" >> ./$OPTIONS_FILE
    picker_output=$(./picker ./$OPTIONS_FILE) || return
    local action
    action=$(echo "$picker_output" | cut -d'|' -f2)
    local target
    target=$(echo "$picker_output" | cut -d'|' -f3)
    case "$action" in
        connect) connect_to_saved_network "$target" ;;
        disconnect) disable_wifi ;;
        forget) forget_network "$target" ;;
    esac
}

save_network() {
    local ssid="$1"
    local password="$2"
    local key
    key=$(get_network_key "$ssid")
    cat > "$NETWORKS_DIR/$key.conf" << EOF
network={
    ssid="$ssid"
    psk="$password"
    key_mgmt=WPA-PSK
}
EOF
}

list_saved_networks() {
    local current_ssid
    current_ssid=$(get_current_ssid)
    for conf_file in "$NETWORKS_DIR"/*.conf; do
        [ -f "$conf_file" ] || continue
        local ssid
        ssid=$(grep 'ssid=' "$conf_file" | cut -d'"' -f2)
        [ -n "$ssid" ] && \
        if [ "$ssid" = "$current_ssid" ]; then
            echo "$ssid (Connected)|network|$ssid"
        else
            echo "$ssid|network|$ssid"
        fi
    done
}

setup_autostart() {
    [ -z "$PLATFORM" ] && \
    if [ -d "/mnt/SDCARD/.userdata/trimui" ]; then
        PLATFORM="trimui"
    elif [ -d "/mnt/SDCARD/.userdata/miyoo" ]; then
        PLATFORM="miyoo"
    else
        PLATFORM="trimui"
    fi
    SCRIPT_DIR="$(readlink -f "$(dirname "$0")")"
    AUTO_DIR="/mnt/SDCARD/.userdata/$PLATFORM"
    AUTO_PATH="$AUTO_DIR/auto.sh"
    cat > "$SCRIPT_DIR/wifi_autostart.sh" << 'EOF'
#!/bin/sh
cd "$(dirname "$0")"
if [ -f "./wifi_enabled" ]; then
    rfkill unblock wifi 2>/dev/null
    ip link set wlan0 up
    sleep 1
    NETWORKS_DIR="./networks"
    CONFIG_FILE="/etc/wifi/wpa_supplicant.conf"
    has_ip_address() {
        ip addr show wlan0 | grep -q "inet "
    }
    connected=0
    for conf_file in "$NETWORKS_DIR"/*.conf; do
        [ -f "$conf_file" ] || continue
        ssid=$(grep 'ssid=' "$conf_file" | cut -d'"' -f2)
        [ -z "$ssid" ] && continue
        cat > "$CONFIG_FILE" << CFG
ctrl_interface=/etc/wifi/sockets
update_config=1

$(cat "$conf_file")
CFG
        killall -q wpa_supplicant
        killall -q udhcpc
        sleep 1
        wpa_supplicant -B -i wlan0 -c "$CONFIG_FILE"
        sleep 2
        (udhcpc -i wlan0 -n) &
        attempt=0
        while [ $attempt -lt 10 ]; do
            has_ip_address && connected=1 && break
            attempt=$((attempt + 1))
            sleep 0.5
        done
        [ $connected -eq 1 ] && break
    done
    [ $connected -eq 0 ] && wpa_supplicant -B -i wlan0 -c "$CONFIG_FILE"
else
    ip link set wlan0 down
    killall -q wpa_supplicant
    killall -q udhcpc
fi
EOF
    chmod +x "$SCRIPT_DIR/wifi_autostart.sh"
    mkdir -p "$AUTO_DIR"
    [ ! -f "$AUTO_PATH" ] && echo "#!/bin/sh" > "$AUTO_PATH" && chmod +x "$AUTO_PATH"
    sed -i '/wifi_autostart/d' "$AUTO_PATH"
    echo "\"$SCRIPT_DIR/wifi_autostart.sh\"" >> "$AUTO_PATH"
}

main() {
    setup_autostart
    [ -f "$WIFI_ENABLED_FLAG" ] && [ "$(get_wifi_state)" = "down" ] && enable_wifi
    while true; do
        show_main_menu || break
    done
    cleanup_temp_files
    killall -q show_message
    exit 0
}

main