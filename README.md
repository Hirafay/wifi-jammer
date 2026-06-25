
 */

# WiFi-Jammer-Automation

A lightweight Bash utility designed to automate the lifecycle of transitioning wireless network interfaces into monitor mode, streamlining the workflow of 802.11 deauthentication testing using the `aircrack-ng` suite.

## Overview
Managing wireless interfaces, suppressing conflicting network daemons, and manually configuring channel hopping is often a repetitive and error-prone process. This script provides a centralized management layer to handle the lifecycle of wireless network operations:

* Interface Detection: Dynamically identifies active wireless interfaces.
* Daemon Management: Programmatically suppresses conflicting background services (e.g., iwd, wpa_supplicant).
* Monitor Mode Orchestration: Executes the necessary kernel-level commands to transition hardware into monitor mode safely.
* Attack Streamlining: Simplifies the transition from reconnaissance to targeted deauthentication.
* Graceful Termination: Implements a trap mechanism to ensure the interface is returned to managed mode and network services are restored automatically.

## Features
* Auto-Detection: Automatically selects the primary wireless interface.
* Robust Error Handling: Mitigates common hardware-level race conditions.
* System Integrity: Ensures system network services are restored immediately upon process termination.

## Prerequisites
* Dependency: `aircrack-ng` suite installed on the host system.
* Hardware: Wireless network interface card (NIC) supporting Monitor Mode and Packet Injection.

## Usage
1. Clone the repository:
   git clone https://github.com/yourusername/wifi-jammer.git
   cd wifi-jammer

2. Assign execution permissions:
   chmod +x jammer.sh

3. Execute with root privileges:
   sudo ./jammer.sh
