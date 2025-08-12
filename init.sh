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
config_items=( * .* )
config_items=(${config_items:#.})   # Remove '.' from the list
config_items=(${config_items:#..})  # Remove '..' from the list

# Directories to ignore when symlinking
ignored_dirs=(.git)

# Specific files to be symlinked directly into ~/
home_items=( .zshenv .Xresources .gitconfig .claude )

# Symlink items to ~/.config
for item in "${config_items[@]}"; do
    if [[ -e $item ]]; then
        # Check if item exists and is not in the ignored directories list
        if [[ ! " ${ignored_dirs[@]} " =~ " $item " ]]; then
            if [[ -e ~/.config/$item ]]; then
                if [[ -L ~/.config/$item ]]; then
                    echo "Warn: ~/.config/$item symlink already exists"
                else
                    echo "Error: ~/.config/$item already exists, refusing to overwrite"
                fi
            else
                ln -s "$PWD/$item" ~/.config/
                # The success messages are a bit much
                # echo "SUCCESS: Symlinked $item to ~/.config"
            fi
        fi
    else
        echo "Warning: Item $item not found in current directory."
    fi
done

# Symlink specific files to ~/
for item in "${home_items[@]}"; do
    if [[ -e $item ]]; then
        if [[ -e ~/$item ]]; then
            if [[ -L ~/$item ]]; then
                echo "Warn: ~/$item symlink already exists"
            else
                echo "Error: ~/$item already exists, refusing to overwrite"
            fi
        else
            ln -s "$PWD/$item" ~/
            # The success messages are a bit much
            # echo "SUCCESS: Symlinked $item to home"
        fi
    else
        echo "Warning: File $item not found in current directory."
    fi
done

# Enable the automount of the NFS from Tailscale
mkdir /mnt/nfs
systemctl link "$PWD/services/mnt-nfs.automount" "$PWD/services/mnt-nfs.mount";
systemctl enable --now mnt-nfs.automount
