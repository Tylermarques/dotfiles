
killall -q streamdeck

# Wait until the processes have been shut down
while pgrep -u $UID -x streamdeck >/dev/null; do sleep 1; done

streamdeck --no-ui

