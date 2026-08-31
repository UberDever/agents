# ~/.bashrc -- universal, sourced on every machine.
# Ordering rule: things safe in non-interactive shells go above the interactive
# guard, everything else below it.

# --- PATH ---------------------------------------------------------------------
# Prepended, so your own binaries beat the distro's. Re-sourcing duplicates
# these entries; duplicates are harmless, so there's no guard.
PATH=$HOME/.local/bin:$HOME/apps/bin:$HOME/apps/nvim/bin:$PATH
export PATH

# Without this, `ssh host cmd` and rsync/scp source this file and anything that
# prints breaks the stream.
[[ $- == *i* ]] || return

# --- history ------------------------------------------------------------------
# Bash reads the whole history file at every shell start, so an uncapped file
# turns into startup latency: ~0.17s at 200k commands, ~0.77s at 1M.
# HISTFILESIZE counts LINES, and HISTTIMEFORMAT adds a #timestamp line per
# entry, so 200000 lines is roughly 100k commands.
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth                  # dup-of-previous + leading-space
HISTIGNORE='ls:ll:cd:pwd:exit:clear:history'
HISTTIMEFORMAT='%F %T  '
shopt -s histappend                     # append on exit, don't clobber
# lithist keeps multi-line commands intact, but only because HISTTIMEFORMAT is
# set above -- the #timestamp lines are what delimit an entry on reload. Remove
# HISTTIMEFORMAT and your for-loops come back as one history entry per line.
shopt -s cmdhist lithist

# --- shopt --------------------------------------------------------------------
# shopt -s autocd                       # `/tmp` == `cd /tmp`
shopt -s cdspell dirspell               # fix small typos in directory names
shopt -s globstar                       # **/ recursive glob
shopt -s extglob                        # !(foo) @(a|b) +(x)
shopt -s checkwinsize
shopt -s checkjobs                      # warn before exiting with running jobs
shopt -s no_empty_cmd_completion        # bare Tab doesn't scan all of $PATH
CDPATH=.:~:~/src

# --- readline -----------------------------------------------------------------
# Up/Down search history by the prefix you already typed. Two bindings each
# because cursor keys send different escapes in application mode.
bind '"\e[A": history-search-backward'
bind '"\eOA": history-search-backward'
bind '"\e[B": history-search-forward'
bind '"\eOB": history-search-forward'
# bind 'set completion-ignore-case on'
# bind 'set completion-map-case on'     # - and _ interchangeable
# bind 'set show-all-if-ambiguous on'   # one Tab, not two
bind 'set colored-stats on'
bind 'set colored-completion-prefix on'
bind 'set mark-symlinked-directories on'
bind 'set skip-completed-text on'
bind 'set enable-bracketed-paste on'
bind '"\e[1;5C": forward-word'          # ctrl-right / ctrl-left
bind '"\e[1;5D": backward-word'
# -t 0 because an interactive shell without a terminal (CI, `bash -i` in a
# pipe) makes stty print "Inappropriate ioctl for device".
[[ -t 0 ]] && stty -ixon                # free ctrl-s, which was terminal freeze

# --- fzf ----------------------------------------------------------------------
# stderr suppressed because `fzf --bash` needs fzf >= 0.48, and an old fzf would
# otherwise print an unknown-option error at every shell start.
if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash)" 2>/dev/null
    export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
fi

# --- git ----------------------------------------------------------------------
# Renamed from git_switch_recent: it lists, it doesn't switch.
# %gs prints only the reflog subject, so commit messages containing
# "checkout: moving" can't leak in. $NF is the destination ref. The rev-parse
# filter drops detached-HEAD SHAs and branches you've since deleted.
git_recent_branches() {
    git reflog --format='%gs' 2>/dev/null \
        | awk '/^checkout: moving from /{print $NF}' \
        | awk '!seen[$0]++' \
        | while read -r b; do
            git rev-parse --verify --quiet "refs/heads/$b" >/dev/null && printf '%s\n' "$b"
        done \
        | head -n "${1:-10}"
}

# --- misc functions -----------------------------------------------------------
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }
up() { local n=${1:-1} p=; ((n < 1)) && return 1; while ((n--)); do p+=../; done; cd "$p"; }
scratch() { cd "$(mktemp -d "${TMPDIR:-/tmp}/scratch.XXXX")" && pwd; }
what() { type -a "$1"; declare -f "$1" 2>/dev/null; }
# tmuxclip() { ssh -A "$MYVMADDR" 'tmux save-buffer -' | wl-copy; }

# --- prompt -------------------------------------------------------------------
# --show-current prints nothing outside a repo, nothing when detached, and
# nothing on git < 2.22. Forks git once per prompt (~1.5ms); if that ever shows
# up in a big repo, turn on core.fsmonitor there rather than optimising here.
PS1='\[\e[2m\]\w\[\e[0m\] \[\e[33m\]$(git branch --show-current 2>/dev/null)\[\e[0m\]\$ '

# Plain assignment, so this is last-write-wins: anything above that installs a
# prompt hook (direnv, conda) gets overwritten here. ~/.bashrc.local is sourced
# after, so per-machine hooks win over this one.
PROMPT_COMMAND='history -a'             # flush now; a killed terminal loses nothing

# --- per-machine escape hatch -------------------------------------------------
# Keep this file identical everywhere; put host-specific things (MYVMADDR,
# proxies, work-only paths) in ~/.bashrc.local, kept out of version control.
if [[ -r ~/.bashrc.local ]]; then
    . ~/.bashrc.local
fi

