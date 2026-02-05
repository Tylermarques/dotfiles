#!/bin/bash
# Starts protonmail-bridge then thunderbird after IMAP port is ready

IMAP_PORT=1143
TIMEOUT=600

wait_for_keyring() {
    local waited=0
    local collection
    while true; do
        collection=$(busctl --user call org.freedesktop.secrets /org/freedesktop/secrets org.freedesktop.Secret.Service ReadAlias s "default" 2>/dev/null | awk '{print $2}' | tr -d '"')
        if [ -n "$collection" ] && busctl --user get-property org.freedesktop.secrets "$collection" org.freedesktop.Secret.Collection Locked 2>/dev/null | grep -q "false"; then
            return 0
        fi
        sleep 1
        ((waited++))
        [ $waited -ge $TIMEOUT ] && return 1
    done
}

wait_for_port() {
  local waited=0
  while ! ss -tln | grep -q ":${IMAP_PORT} "; do
    sleep 1
    ((waited++))
    [ $waited -ge $TIMEOUT ] && return 1
  done
}

if ! wait_for_keyring; then
  notify-send -u critical "Mail Startup Failed" "Timed out waiting for keyring unlock"
  exit 1
fi

protonmail-bridge --non-interactive &

if ! wait_for_port; then
  notify-send -u critical "Mail Startup Failed" "Timed out waiting for Protonmail Bridge"
  exit 1
fi

thunderbird &
