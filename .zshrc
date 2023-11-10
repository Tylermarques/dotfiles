# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.config/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git aws fzf zsh-autosuggestions zsh-syntax-highlighting docker docker-compose tmux kubectl poetry)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
alias zshconfig="nvim ~/.config/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
source $HOME/.config/aliases.zsh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


PATH="$HOME/bin:$PATH"



autoload -U +X bashcompinit && bashcompinit
source $ZSH/cache/completions/*

# Setup fzf
# ---------
if [[ ! "$PATH" == */home/tyler/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/tyler/.fzf/bin"
fi



#### NVIDIA cuDNN paths ####
export PATH="/usr/local/cuda-12.0/bin${PATH:+:${PATH}}"
export LD_LIBRARY_PATH="/usr/local/cuda-12.0/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:/opt/mssql-tools/bin"


## Cargo (rust) bin bath
export PATH=$PATH:$HOME/.cargo/bin

#### Node / NVM setup ####
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

#### Dotnet
export PATH="$PATH:$HOME/.dotnet"

source ~/.hass
source ~/.tokens
source $HOME/.config/aliases.zsh
source $HOME/.config/zoxide.zsh


export ANSIBLE_CONFIG=$HOME/.config/ansible/ansible.cfg
LS_COLORS=$LS_COLORS:'ow=1;41;30:'
export LS_COLORS
export PATH=$HOME/.config/rofi/scripts:$PATH
export TERMINAL=$HOME/.cargo/bin/alacritty
export TERM=alacritty
export LD_LIBRARY_PATH=/usr/local/lib

export ZPLUG_HOME=$HOME/.config/zplug

export XDG_CONFIG_HOME=$HOME/.config
export PATH=$PATH:$HOME/esp/xtensa-lx106-elf/bin

export RUSTC_WRAPPER=sccache

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/tyler/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/tyler/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/tyler/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/tyler/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

export WORKON_HOME="$HOME/.virtualenvs/"


# Shell-GPT integration ZSH v0.1
_sgpt_zsh() {
    _sgpt_prev_cmd=$BUFFER
    BUFFER+="⌛"
    zle -I && zle redisplay
    BUFFER=$(sgpt --shell <<< "$_sgpt_prev_cmd")
    zle end-of-line
}
zle -N _sgpt_zsh
bindkey ^y _sgpt_zsh
# Shell-GPT integration ZSH v0.1

### Task warrior Settings
export TASKRC=$XDG_CONFIG_HOME/.taskrc

# To customize prompt, run `p10k configure` or edit ~/.config/.p10k.zsh.
[[ ! -f ~/.config/.p10k.zsh ]] || source ~/.config/.p10k.zsh

export GPG_TTY=$(tty)

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/tyler/foss/gcp-cli/google-cloud-sdk/path.zsh.inc' ]; then . '/home/tyler/foss/gcp-cli/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/tyler/foss/gcp-cli/google-cloud-sdk/completion.zsh.inc' ]; then . '/home/tyler/foss/gcp-cli/google-cloud-sdk/completion.zsh.inc'; fi

# For t-smart-tmux-session-manager
export PATH=$HOME/.config/tmux/plugins/t-smart-tmux-session-manager/bin:$PATH

# Pyenv environment
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

eval "$(pyenv virtualenv-init -)"

