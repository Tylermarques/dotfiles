#!/usr/bin/env bash

FLAG_FILE="/tmp/idle_muted_by_script"
STATE_FILE="/tmp/idle_mute_state"

mute() {
    # Don't mute if music/media is actively playing
    if playerctl -a status 2>/dev/null | grep -q "Playing"; then
        exit 0
    fi

    # Save current mute state
    wpctl get-volume @DEFAULT_AUDIO_SINK@ > "$STATE_FILE"

    # Mute and mark that we did it
    wpctl set-mute @DEFAULT_AUDIO_SINK@ 1
    touch "$FLAG_FILE"
}

unmute() {
    # Only unmute if we were the ones who muted
    if [[ -f "$FLAG_FILE" ]]; then
        # Only unmute if it wasn't already muted before we touched it
        if [[ -f "$STATE_FILE" ]] && ! grep -q "MUTED" "$STATE_FILE"; then
            wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
        fi
        rm -f "$FLAG_FILE" "$STATE_FILE"
    fi
}

case "$1" in
    mute) mute ;;
    unmute) unmute ;;
    *) echo "Usage: $0 {mute|unmute}" >&2; exit 1 ;;
esac
