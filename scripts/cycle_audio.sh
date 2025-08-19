#!/bin/bash

# Get the current default sink
current_sink=$(wpctl status | grep -A 20 "Sinks:" | grep "\*" | awk '{print $2}' | head -1)

# Define the sink IDs - these might change, so we'll search by name instead
nvidia_sink=$(wpctl status | grep -A 20 "Sinks:" | grep -i "nvidia.*hdmi" | awk '{print $2}' | head -1 | sed 's/\.//')
analog_sink=$(wpctl status | grep -A 20 "Sinks:" | grep -i "analog stereo" | head -1 | awk '{print $2}' | head -1 | sed 's/\.//')
airpods_sink=$(wpctl status | grep -A 20 "Sinks:" | grep -i "airpods" | awk '{print $2}' | head -1 | sed 's/\.//')

# Check if AirPods are connected and available
airpods_available=false
if [ -n "$airpods_sink" ]; then
    airpods_available=true
fi

# Cycling logic
if [ "$airpods_available" = true ]; then
    # Three-way cycle: NVIDIA -> Analog -> AirPods -> NVIDIA
    if [ "$current_sink" = "$nvidia_sink" ]; then
        wpctl set-default "$analog_sink"
        notify-send "Audio Output" "Switched to Headphones/Analog" -i audio-headphones
    elif [ "$current_sink" = "$analog_sink" ]; then
        wpctl set-default "$airpods_sink"
        notify-send "Audio Output" "Switched to AirPods Pro" -i audio-headphones
    else
        wpctl set-default "$nvidia_sink"
        notify-send "Audio Output" "Switched to NVIDIA Digital Stereo (HDMI)" -i audio-speakers
    fi
else
    # Two-way cycle when AirPods not available: NVIDIA <-> Analog
    if [ "$current_sink" = "$nvidia_sink" ]; then
        wpctl set-default "$analog_sink"
        notify-send "Audio Output" "Switched to Headphones/Analog" -i audio-headphones
    else
        wpctl set-default "$nvidia_sink"
        notify-send "Audio Output" "Switched to NVIDIA Digital Stereo (HDMI)" -i audio-speakers
    fi
fi