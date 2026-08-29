
export PATH=${PATH}:/home/${USER}/.local/bin
export PATH=${PATH}:/home/${USER}/apps/bin
export PATH=${PATH}:/home/${USER}/apps/nvim/bin

eval "$(fzf --bash)"

# function tmuxclip() { ssh -A $MYVMADDR 'tmux save-buffer -' | wl-copy; }

function git_switch_recent() {
    git reflog | grep "checkout: moving" | awk '{print $8}' | awk '!x[$0]++' | head -n 10
}
