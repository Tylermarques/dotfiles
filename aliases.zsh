alias v='nvim'
alias tx='tmuxinator ls | tail -n +2 | awk ''{OFS="\n";$1=$1}1'' | fzf'
