#!/bin/sh
# Open files from a GUI file manager (Thunar etc.) in nvim, inside a single
# shared tmux session named "edit", displayed in Alacritty.
#
# - First open: creates the "edit" session with nvim and opens Alacritty on it.
# - Later opens: adds a new tmux window running nvim to the same session and
#   focuses the existing Alacritty window (or reopens one if it was closed).
#
# Wired up via applications/nvim-tmux.desktop and mimeapps.list.

SESSION=edit
CLASS=nvim-edit

# Start nvim in the directory of the first file so :e, fzf, etc. feel natural.
if [ -n "$1" ]; then
    cwd=$(dirname "$1")
else
    cwd=$HOME
fi

if tmux has-session -t "=$SESSION" 2>/dev/null; then
    tmux new-window -t "$SESSION:" -c "$cwd" -- nvim "$@"
else
    tmux new-session -d -s "$SESSION" -c "$cwd" -- nvim "$@"
    # tmux.conf sets detach-on-destroy off globally; for this session we want
    # the Alacritty window to close when the last nvim exits, not hop to
    # another session.
    tmux set-option -t "$SESSION" detach-on-destroy on
fi

if [ -n "$(tmux list-clients -t "=$SESSION" 2>/dev/null)" ]; then
    # Session already has a terminal attached; bring it to the front.
    command -v hyprctl >/dev/null 2>&1 && hyprctl dispatch focuswindow "class:$CLASS" >/dev/null
    exit 0
fi

exec alacritty --class "$CLASS" -e tmux attach-session -t "=$SESSION"
