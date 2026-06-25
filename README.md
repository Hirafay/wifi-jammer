WiFi-Jammer-Automation
A lightweight Bash utility designed to automate the process of transitioning wireless network interfaces into monitor mode and simplifying the workflow of 802.11 deauthentication attacks using the aircrack-ng suite.

Overview
Managing wireless interfaces, killing conflicting network daemons, and setting channels manually can be a repetitive, error-prone process. This script automates the full lifecycle of the process:

Interface Detection: Dynamically identifies active wireless interfaces.

Process Management: Automatically identifies and kills conflicting services (like iwd or wpa_supplicant) that interfere with monitor mode.

Monitor Mode Activation: Seamlessly transitions the device into monitor mode.

Automation: Streamlines the scanning-to-attack pipeline by capturing user inputs for target BSSID and channel.

Cleanup: Includes a trap mechanism to restore the interface to managed mode and restart network services upon exit.

Features
Auto-Detection: Automatically selects the primary wireless interface.

Error Handling: Robust interface management to prevent No such device or Resource busy errors.

Clean Exit: Automatic cleanup ensures your system network services are restored immediately after the process ends.

Usage
Clone the repository:
git clone [https://github.com/yourusername/wifi-jammer.git](https://github.com/yourusername/wifi-jammer.git)

Make the script executable:
chmod +x jammer.sh

Run with root privileges:
sudo ./jammer.sh

Prerequisites
aircrack-ng suite installed on your system.

Wireless card capable of Monitor Mode and Packet Injection.
