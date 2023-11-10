#!/bin/bash

speakers=$(pactl list sinks | grep Name | awk '/extra3/ {print $2}')
headphones=$(pactl list sinks | grep Name | awk '/stereo-game/ {print $2}')

if [[ $1 == "speakers" ]]; then
  pactl set-default-sink "$speakers"
fi

if [[ $1 == "headphones" ]]; then
  pactl set-default-sink "$headphones"
fi

