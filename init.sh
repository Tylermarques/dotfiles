#!/usr/bin/env zsh
################################################################################################################
#                               Hello! 
#     Welcome, you're likely here because you borked another install! Good Job! (idiot)
#     I've done it enough times to know I should automate this. So here is the script to get you back up and running.
#
################################################################################################################
#
#######################################     NOTES     ##########################################################
#     I use this repo https://github.com/erikw/restic-automatic-backup-scheduler#optional-features + restic to 
#     back up my PC to Backblaze.

##### Symlink the files here to the .config directory #########

# Items (directories or files) to be symlinked to ~/.config
config_items=( * )

# Specific files to be symlinked directly into ~/
home_items=( .zshenv .Xresources )

# Symlink items to ~/.config
for item in "${config_items[@]}"; do
    if [[ -e $item ]]; then  # The condition checks if the item exists and is not in the home_items list
        if [[ -e ~/.config/$item || -L ~/.config/$item ]]; then
            echo "Error: ~/.config/$item already exists, refusing to overwrite"
        else
            ln -s "$PWD/$item" ~/.config/
        fi
    else
      echo "Warning: Directory $item not found in current directory."
    fi
done

# Symlink specific files to ~/
for item in "${home_items[@]}"; do
    if [[ -e $item ]]; then
        if [[ -e ~/$item || -L ~/$item ]]; then
            echo "Error: ~/$item already exists, refusing to overwrite"
        else
            ln -s "$PWD/$item" ~/
        fi
    else
      echo "Warning: File $item not found in current directory."
    fi
done


