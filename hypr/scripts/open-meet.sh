#!/bin/bash
# Opens meet.google.com in GoodStart container on workspace 6
# To skip Firefox confirmation prompt: set OPEN_URL_IN_CONTAINER_SIGNING_KEY env var

CONTAINER="GoodStart"
URL="https://meet.google.com"
WORKSPACE=6
EXT_URL="ext+container:name=$CONTAINER&url=$URL"

hyprctl --instance 0 dispatch workspace "$WORKSPACE"

firefox_addr=$(hyprctl --instance 0 clients -j | jq -r ".[] | select(.workspace.id == $WORKSPACE and .class == \"firefox\") | .address" | head -1)

if [ -n "$firefox_addr" ]; then
    hyprctl --instance 0 dispatch focuswindow "address:$firefox_addr"
    sleep 0.3
    firefox "$EXT_URL"
else
    firefox --new-window "$EXT_URL"
fi
