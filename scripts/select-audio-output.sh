#!/bin/bash

speakers=$(pactl list sinks | grep Name | awk '/iec958/ {print $2}')
headphones=$(pactl list sinks | grep Name | awk '/hdmi/ {print $2}')

if [[ $1 == "speakers" ]]; then
  echo $speakers
  pactl set-default-sink "$speakers"
fi

if [[ $1 == "headphones" ]]; then
  echo $headphones
  pactl set-default-sink "$headphones"
fi

