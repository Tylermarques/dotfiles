########################################################
#                               Hello! 
#             Welcome, you're likely here because you borked another install! Good Job! (idiot)
#             I've done it enough times to know I should automate this. So here is the script to get you back up and running.

# Symlink the files here to the .config directory
#!/usr/bin/env zsh

# Fetch the list of directories in the current directory
dirs=( */ )

# Remove trailing slashes from directory names
dirs=(${dirs%/})

# Iterate over the directories and create symlinks
for dir in $dirs; do
  if [[ -d $dir ]]; then
    ln -s $PWD/$dir ~/.config_test/
  else
    echo "Warning: Directory $dir not found in current directory."
  fi
done

