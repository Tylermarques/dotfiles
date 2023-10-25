#!/usr/bin/env zsh
################################################################################################################
#                               Hello! 
#     Welcome, you're likely here because you borked another install! Good Job! (idiot)
#     I've done it enough times to know I should automate this. So here is the script to get you back up and running.
#
################################################################################################################

##### Symlink the files here to the .config directory #########

# Items (directories or files) to be symlinked to ~/.config
config_items=( * )

# Specific files to be symlinked directly into ~/
home_items=( .zshenv .Xresources )

# Symlink items to ~/.config
for item in "${config_items[@]}"; do
    if [[ -e $item ]]; then  # The condition checks if the item exists and is not in the home_items list
        ln -s "$PWD/$item" ~/.config_test/
    else
      echo "Warning: Directory $item not found in current directory."
    fi
done

# Symlink specific files to ~/
for item in "${home_items[@]}"; do
    if [[ -e $item ]]; then
        ln -s "$PWD/$item" ~/home_test
    else
      echo "Warning: File $item not found in current directory."
    fi
done

