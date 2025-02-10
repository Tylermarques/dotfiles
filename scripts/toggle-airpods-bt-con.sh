#!/bin/bash
DEVICE_MAC="00:F3:9F:72:EC:4C" # Replace with your device's MAC address

# Check if the device is connected
IS_CONNECTED=$(echo -e "info $DEVICE_MAC\nexit" | bluetoothctl | grep "Connected:" | awk '{print $2}')

if [ "$IS_CONNECTED" == "yes" ]; then
  bluetoothctl disconnect $DEVICE_MAC
else
  bluetoothctl connect $DEVICE_MAC
fi
