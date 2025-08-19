#!/bin/bash

# Get the current default sink
current_sink=$(wpctl status | grep -A 20 "Sinks:" | grep "\*" | awk '{print $2}' | head -1)

# Define the sink IDs - these might change, so we'll search by name instead
nvidia_sink=$(wpctl status | grep -A 20 "Sinks:" | grep -i "nvidia.*hdmi" | awk '{print $2}' | head -1 | sed 's/\.//')
analog_sink=$(wpctl status | grep -A 20 "Sinks:" | grep -i "analog stereo" | head -1 | awk '{print $2}' | head -1 | sed 's/\.//')

if [ "$current_sink" = "$nvidia_sink" ]; then
    # Switch to analog (headphones)
    wpctl set-default "$analog_sink"
    notify-send "Audio Output" "Switched to Headphones/Analog" -i audio-headphones
else
    # Switch to NVIDIA HDMI (speakers)
    wpctl set-default "$nvidia_sink"
    notify-send "Audio Output" "Switched to NVIDIA Digital Stereo (HDMI)" -i audio-speakers
fi