
PATH=${PATH}:/home/${USER}/.local/bin
PATH=${PATH}:/home/${USER}/apps/bin
PATH=${PATH}:/home/${USER}/apps/nvim

eval "$(fzf --bash)"

# function tmuxclip() { ssh -A $MYVMADDR 'tmux save-buffer -' | wl-copy; }

function git_switch_recent() {
    git reflog | grep "checkout: moving" | awk '{print $8}' | awk '!x[$0]++' | head -n 10
}
