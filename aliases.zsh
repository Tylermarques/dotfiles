alias v='nvim'
alias v-config='nvim ~/.config/astrovim/lua/user/init.lua'
alias tx="tmuxinator ls | tail -n +2 | awk '{OFS=\"\n\";\$1=\$1}1' | fzf | xargs tmuxinator start \$1"
alias k='kubectl'
alias tv='tidy-viewer'
# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')" && paplay /usr/share/sounds/gnome/default/alerts/glass.ogg'
alias weather='curl wttr.in/YTZ'
alias pdb='python3 -m pdb'
# The below only works on my linux pc, as it uses restic to backup to backblaze
alias backup-status='restic -r b2:tpc-backup:/ snapshots --password-file ~/.restic/restic_pass'
alias heather-temp='ipmitool -I lanplus -H 192.168.0.120 -U root -P $(bw get password 423c8535-306e-43c3-927a-afaa014ef6d2) sdr type temperature'

heather-fan-speed() {
  if [ -n "$1" ]
  then

    hex_num=$(echo "obase=16; ibase=10; $1:u" | bc)
    ipmitool -I lanplus -H 192.168.0.120 -U $(bw get username 423c8535-306e-43c3-927a-afaa014ef6d2) -P $(bw get password 423c8535-306e-43c3-927a-afaa014ef6d2) raw 0x30 0x30 0x02 0xff 0x$hex_num
  else
    echo "Need to provide a number between 0 and 100"
  fi
}