#!/bin/bash
# Airpod Pro 2
# DEVICE_MAC="00:F3:9F:72:EC:4C" # Replace with your device's MAC address

# Airpod Pro 3
DEVICE_MAC="74:77:86:0E:08:38" # Replace with your device's MAC address
# Check if the device is connected
IS_CONNECTED=$(echo -e "info $DEVICE_MAC\nexit" | bluetoothctl | grep "Connected:" | awk '{print $2}')

if [ "$IS_CONNECTED" == "yes" ]; then
  bluetoothctl disconnect $DEVICE_MAC
  notify-send "AirPods Pro" "Disconnected" -i audio-headphones
else
  bluetoothctl connect $DEVICE_MAC
  notify-send "AirPods Pro" "Connected" -i audio-headphones
fi
