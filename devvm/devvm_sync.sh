#!/usr/bin/env bash
# Performance-first, explicit VM snapshots. `run` never syncs.
set -euo pipefail

MYVM_LOGIN=uberdever
MYVM_IP6=2a02:6b8:c02:900:0:fdb6:0:106
PROTOCOL=shallow-snapshot-v1

usage() {
    cat >&2 <<'EOF'
Usage:
  devvm_sync.sh sync [remote-dir]
  devvm_sync.sh run [remote-dir] -- <command>
  devvm_sync.sh reset [remote-dir]
  devvm_sync.sh branches

sync  explicitly installs the current top-level Git snapshot plus staged,
      unstaged, and untracked overlays. It never copies local submodule edits.
run   executes in the existing VM checkout; it never syncs.
reset removes this VM checkout, its state, and its build caches. It preserves
      the shared append-only Git object pool used by other workspaces.
branches reports local uberdever/* branches across sibling clickhouse workspaces.
         Remote-tracking refs are deliberately excluded.
EOF
}
die() { echo "[devvm_sync] error: $*" >&2; exit 1; }
q() { printf '%q' "$1"; }

[[ $# -gt 0 ]] || { usage; exit 2; }
mode=$1; shift
case $mode in sync|run|reset|branches) ;; *) usage; exit 2 ;; esac

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "must run inside a git work tree"
repo_root=$(git rev-parse --show-toplevel)
repo_name=$(basename "$repo_root")
remote_dir=${REMOTE_DIR:-$repo_name}
if [[ $mode == run && ${1:-} != -- && $# -gt 0 ]]; then remote_dir=$1; shift; fi
if [[ $mode == sync || $mode == reset ]] && [[ $# -gt 0 ]]; then remote_dir=$1; shift; fi
if [[ $mode == run ]]; then
    [[ ${1:-} == -- ]] || { usage; exit 2; }
    shift
    [[ $# -gt 0 ]] || die "run needs a command after --"
elif [[ $# -ne 0 ]]; then
    usage; exit 2
fi

ssh_target="${MYVM_LOGIN}@${MYVM_IP6}"
control_path="${XDG_RUNTIME_DIR:-/tmp}/devvm-sync-${MYVM_LOGIN}@${MYVM_IP6//:/_}"
ssh_opts=(-A -6 -o ControlMaster=auto -o ControlPersist=10m -o ControlPath="$control_path")
remote_base="${remote_dir}.devvm-sync"

# Workspaces cloned from the same origin share immutable objects, but never
# refs, indexes, worktrees, submodules, or build directories.
origin_identity=$(git config --get remote.origin.url 2>/dev/null || printf '%s' "$repo_name")
pool_key=$(printf '%s' "$origin_identity" | sha256sum | awk '{print substr($1, 1, 20)}')
remote_pool=${DEVVM_OBJECT_POOL:-"$(dirname "$remote_dir")/.devvm-objects-$pool_key.git"}

remote_bash() { local vars=$1; ssh "${ssh_opts[@]}" "$ssh_target" "$vars bash -s"; }

profile_step() {
    local label=$1 start
    shift
    if [[ -z ${DEVVM_SYNC_PROFILE:-} ]]; then
        "$@"
        return
    fi
    start=$(date +%s%3N)
    "$@"
    echo "[devvm_sync] profile $label: $(( $(date +%s%3N) - start ))ms"
}

submodule_paths() {
    [[ -f $repo_root/.gitmodules ]] || return 0
    git config --file "$repo_root/.gitmodules" --get-regexp '^submodule\..*\.path$' 2>/dev/null |
        while IFS=' ' read -r _ path; do printf '%s\0' "$path"; done
}

check_local_submodules() {
    local path
    local -a paths
    mapfile -d '' paths < <(submodule_paths)
    ((${#paths[@]})) || return 0

    # One superproject status scan detects an uninitialized module, gitlink
    # drift, index/worktree edits, and untracked files inside every direct
    # module. Do not spawn one Git process per ClickHouse submodule.
    if [[ -n $(git status --porcelain --ignore-submodules=none -- .gitmodules "${paths[@]}") ]]; then
        die "direct submodules and .gitmodules must be initialized and clean; local submodule changes are not synced"
    fi
}

snapshot_objects() {
    # Exact closure needed to check out COMMIT, excluding gitlink commit IDs:
    # submodules are separately fetched by normal Git submodule machinery.
    local commit=$1
    {
        printf '%s\n' "$commit"
        git rev-parse "$commit^{tree}"
        git ls-tree -r -t "$commit" | awk '$2 != "commit" { print $3 }'
    } | sort -u
}

read_remote_file() {
    local path=$1
    ssh "${ssh_opts[@]}" "$ssh_target" "test -s $(q "$path") && cat $(q "$path") || true"
}

ensure_remote_layout() {
    remote_bash "WORKTREE=$(q "$remote_dir") STATE=$(q "$remote_base") POOL=$(q "$remote_pool") PROTOCOL=$(q "$PROTOCOL")" <<'REMOTE'
set -euo pipefail
mkdir -p "$STATE" "$(dirname "$POOL")"
[[ -d $POOL ]] || git init --bare "$POOL" >/dev/null
if [[ ! -e $WORKTREE ]]; then
    mkdir -p "$(dirname "$WORKTREE")"
    git init "$WORKTREE" >/dev/null
elif ! git -C "$WORKTREE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "[devvm_sync] invalid VM checkout; run reset" >&2
    exit 1
elif [[ -e $STATE/protocol ]] && [[ $(cat "$STATE/protocol") != "$PROTOCOL" ]]; then
    echo "[devvm_sync] VM checkout uses an older sync protocol; run reset" >&2
    exit 1
elif [[ ! -e $STATE/protocol ]] && [[ -e $WORKTREE/.git ]]; then
    echo "[devvm_sync] VM checkout is not managed by this protocol; run reset" >&2
    exit 1
fi
# The pool is append-only. Each workspace owns its own refs/index/shallow file.
# Do not use it as an alternate: Praktika mounts only the workspace into its
# container, so the pool's parent-directory path is invisible there.
git_dir=$(git -C "$WORKTREE" rev-parse --absolute-git-dir)
rm -f "$git_dir/objects/info/alternates"
printf '%s\n' "$PROTOCOL" > "$STATE/protocol"
REMOTE
}

pool_has_commit() {
    local head=$1
    ssh "${ssh_opts[@]}" "$ssh_target" \
        "git --git-dir=$(q "$remote_pool") cat-file -e $(q "$head^{commit}")" >/dev/null 2>&1
}

send_snapshot_objects() {
    local head=$1 previous=$2 objects_file old_file
    if pool_has_commit "$head"; then
        echo "[devvm_sync] object snapshot already in shared pool: $head"
        return
    fi

    objects_file=$(mktemp)
    if [[ -n $previous ]] && git cat-file -e "$previous^{commit}" 2>/dev/null; then
        old_file=$(mktemp)
        snapshot_objects "$previous" >"$old_file"
        comm -23 <(snapshot_objects "$head") "$old_file" >"$objects_file"
        rm -f "$old_file"
        # The exact new commit is needed even when its tree is unchanged.
        { printf '%s\n' "$head"; cat "$objects_file"; } | sort -u >"$objects_file.new"
        mv "$objects_file.new" "$objects_file"
        echo "[devvm_sync] sending incremental shallow snapshot"
    else
        snapshot_objects "$head" >"$objects_file"
        echo "[devvm_sync] sending initial shallow snapshot"
    fi

    # index-pack installs only immutable objects in the shared pool. No refs
    # are ever written there, so parallel workspace syncs cannot race on refs.
    git pack-objects --stdout <"$objects_file" |
        ssh "${ssh_opts[@]}" "$ssh_target" \
            "git --git-dir=$(q "$remote_pool") index-pack --stdin --fix-thin --keep=devvm-sync >/dev/null"
    rm -f "$objects_file"
}

link_pool_packs() {
    # Hard links keep every workspace's object database Docker-visible while
    # retaining one physical copy of immutable pool packs on the VM filesystem.
    remote_bash "WORKTREE=$(q "$remote_dir") POOL=$(q "$remote_pool")" <<'REMOTE'
set -euo pipefail
git_dir=$(git -C "$WORKTREE" rev-parse --absolute-git-dir)
mkdir -p "$git_dir/objects/pack"
find "$POOL/objects/pack" -maxdepth 1 -type f -print0 |
while IFS= read -r -d '' pack; do
    ln -f "$pack" "$git_dir/objects/pack/${pack##*/}"
done
REMOTE
}

materialize_head() {
    local head=$1 branch=$2
    remote_bash "WORKTREE=$(q "$remote_dir") STATE=$(q "$remote_base") HEAD=$(q "$head") BRANCH=$(q "$branch")" <<'REMOTE'
set -euo pipefail
cd "$WORKTREE"
# Never silently delete an ordinary untracked source file that blocks a tracked
# path in the requested snapshot. Ignored cache paths are intentionally left
# alone; users repair such unusual collisions manually.
# Check all potential blockers through one cat-file process. Invoking
# cat-file once per untracked directory made ClickHouse re-syncs spend tens of
# seconds repeatedly traversing the source tree.
blockers=$(mktemp)
while IFS= read -r -d '' path; do
    printf '%s:%s\n' "$HEAD" "$path"
done < <(git ls-files --others --exclude-standard -z) |
    git cat-file --batch-check='%(objecttype)' > "$blockers"
if grep -qv ' missing$' "$blockers"; then
    rm -f "$blockers"
    echo "[devvm_sync] an untracked VM path blocks the requested tracked snapshot; repair it manually" >&2
    exit 1
fi
rm -f "$blockers"

# Keeping every snapshot head shallow is deliberate: this executor must never
# acquire or traverse source history, even after branch switches.
touch "$STATE/shallow"
grep -Fxq "$HEAD" "$STATE/shallow" || printf '%s\n' "$HEAD" >> "$STATE/shallow"
git_dir=$(git rev-parse --absolute-git-dir)
cp "$STATE/shallow" "$git_dir/shallow"

if [[ -n $BRANCH ]]; then
    git update-ref "$BRANCH" "$HEAD"
    git symbolic-ref HEAD "$BRANCH"
else
    git checkout --detach "$HEAD" >/dev/null
fi
git -c submodule.recurse=false reset --hard "$HEAD" >/dev/null
printf '%s\n' "$HEAD" > "$STATE/last-head"
REMOTE
}

apply_overlay() {
    local head=$1
    if ! git diff --cached --quiet "$head" --; then
        echo "[devvm_sync] applying staged overlay"
        git diff --cached --binary "$head" -- |
            ssh "${ssh_opts[@]}" "$ssh_target" \
                "cd $(q "$remote_dir") && git apply --index --whitespace=nowarn -"
    fi
    if ! git diff --quiet --; then
        echo "[devvm_sync] applying unstaged overlay"
        git diff --binary -- |
            ssh "${ssh_opts[@]}" "$ssh_target" \
                "cd $(q "$remote_dir") && git apply --whitespace=nowarn -"
    fi

    local -a untracked=()
    mapfile -d '' untracked < <(git ls-files --others --exclude-standard -z)
    if ((${#untracked[@]})); then
        echo "[devvm_sync] incrementally syncing ${#untracked[@]} untracked paths"
        # rsync's quick check (size + mtime) avoids retransmitting unchanged
        # generated source trees. No --delete: stale VM files and build caches
        # remain by contract. Excluding nested .git directories avoids copying
        # unrelated repository metadata. --quiet prevents path/content leaks to
        # the terminal or task log; transport is SSH.
        printf '%s\0' "${untracked[@]}" |
            rsync -a --quiet --from0 --files-from=- --exclude='.git/' \
                -e "ssh -A -6 -o ControlMaster=auto -o ControlPersist=10m -o ControlPath=$control_path" \
                "$repo_root/" "${MYVM_LOGIN}@[${MYVM_IP6}]:$remote_dir/"
    fi
}

missing_gitmodule_entries() {
    local path url
    while IFS= read -r path; do
        if git config --file .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk '{print $2}' | grep -Fxq "$path"; then
            continue
        fi
        url=$(git config --get "submodule.$path.url" 2>/dev/null || true)
        [[ -n $url ]] || die "gitlink $path has no .gitmodules entry or local submodule URL"
        printf '[submodule "%s"]\n\tpath = %s\n\turl = %s\n' "$path" "$path" "$url"
    done < <(git ls-tree -r HEAD | awk '$2 == "commit" { print $4 }')
}

install_compat_gitmodules() {
    local tmp
    tmp=$(mktemp)
    missing_gitmodule_entries >"$tmp"
    if [[ -s $tmp ]]; then
        # Some existing ClickHouse commits retain a gitlink after its .gitmodules
        # entry was removed. The local checkout has its URL in .git/config;
        # recreate only that missing entry in the disposable VM worktree so
        # Praktika's `git submodule sync` can operate.
        ssh "${ssh_opts[@]}" "$ssh_target" "cat > $(q "$remote_base/compat.gitmodules")" <"$tmp"
        remote_bash "WORKTREE=$(q "$remote_dir") COMPAT=$(q "$remote_base/compat.gitmodules")" <<'REMOTE'
set -euo pipefail
[[ -s $COMPAT ]] && cat "$COMPAT" >> "$WORKTREE/.gitmodules"
REMOTE
    else
        ssh "${ssh_opts[@]}" "$ssh_target" "rm -f $(q "$remote_base/compat.gitmodules")"
    fi
    rm -f "$tmp"
}

submodule_marker() {
    local head=$1
    {
        git ls-tree -r "$head" | awk '$2 == "commit" { print $3 " " $4 }'
        git show "$head:.gitmodules" 2>/dev/null || true
        missing_gitmodule_entries
    } | sha256sum | awk '{print $1}'
}

sync_submodules() {
    local head=$1 marker previous
    install_compat_gitmodules
    marker=$(submodule_marker "$head")
    previous=$(read_remote_file "$remote_base/submodules.marker")
    local changed=0
    [[ $marker == "$previous" ]] || changed=1

    remote_bash "WORKTREE=$(q "$remote_dir") MARKER=$(q "$marker") STATE=$(q "$remote_base") CHANGED=$changed" <<'REMOTE'
set -euo pipefail
cd "$WORKTREE"
git_dir=$(git rev-parse --absolute-git-dir)
mapfile -t paths < <(git config --file .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk '{print $2}')
repair=0
for path in "${paths[@]}"; do
    [[ -e $path ]] || continue
    # A prior interrupted cleanup or old sync version can leave a worktree
    # .git file pointing at a missing .git/modules entry. It is not a usable
    # cache; remove only that broken VM module and recreate it below.
    if ! git -C "$path" rev-parse --git-dir >/dev/null 2>&1; then
        echo "[devvm_sync] repairing broken submodule cache: $path" >&2
        rm -rf -- "$path" "$git_dir/modules/$path"
        repair=1
    fi
done

# A build can leave tracked submodule files modified (or a previous repair can
# leave files absent) while the gitlink marker remains unchanged. Restore only
# those modules to their recorded gitlinks; --force changes tracked content but
# keeps ignored build caches.
dirty=0
if ((${#paths[@]})) && [[ -n $(git status --porcelain --ignore-submodules=none -- "${paths[@]}") ]]; then
    dirty=1
fi
if ((CHANGED || repair || dirty)); then
    echo "[devvm_sync] refreshing normal shallow submodules" >&2
    git -c protocol.file.allow=always submodule sync
    git -c protocol.file.allow=always submodule update --init --force --depth=1 --single-branch
fi
printf '%s\n' "$MARKER" > "$STATE/submodules.marker"
REMOTE
}

sync_repo() {
    local head branch previous
    cd "$repo_root"
    profile_step local-submodules check_local_submodules
    head=$(git rev-parse HEAD)
    branch=$(git symbolic-ref --quiet HEAD || true)
    previous=$(read_remote_file "$remote_base/last-head")

    echo "[devvm_sync] workspace: $repo_root"
    echo "[devvm_sync] VM checkout: $remote_dir"
    profile_step remote-layout ensure_remote_layout
    profile_step objects send_snapshot_objects "$head" "$previous"
    profile_step object-links link_pool_packs
    profile_step materialize materialize_head "$head" "$branch"
    profile_step overlay apply_overlay "$head"
    profile_step submodules sync_submodules "$head"
    echo "[devvm_sync] sync complete"
}

reset_remote() {
    echo "[devvm_sync] removing VM workspace and caches: $remote_dir"
    echo "[devvm_sync] shared object pool is preserved: $remote_pool"
    remote_bash "WORKTREE=$(q "$remote_dir") STATE=$(q "$remote_base")" <<'REMOTE'
set -euo pipefail
[[ -n $WORKTREE && $WORKTREE != / ]] || {
    echo "[devvm_sync] refusing to reset an empty or root workspace path" >&2
    exit 1
}

# Docker jobs can leave __pycache__ and pytest-xdist _gw*_instance directories
# owned by root. First use the normal host cleanup; if it cannot remove those
# leftovers, use a root container only for this explicitly destructive reset.
if ! rm -rf -- "$WORKTREE"; then
    echo "[devvm_sync] host cleanup hit root-owned files; using Docker cleanup" >&2
    image=$(docker images --format '{{.Repository}}:{{.Tag}}' 'clickhouse/binary-builder' |
        grep -v ':<none>$' | head -n1 || true)
    image=${image:-alpine:3.20}
    docker run --rm --volume "$WORKTREE":/work "$image" \
        sh -c 'rm -rf /work/* /work/.[!.]* /work/..?*'
    rm -rf -- "$WORKTREE"
fi
rm -rf -- "$STATE"
REMOTE
    echo "[devvm_sync] reset complete; run sync next"
}

report_branches() {
    local parent workspace name active branch head line number=0
    local -a branches
    parent=$(dirname "$repo_root")

    echo "Local custom branches only (refs/heads/uberdever/*); fetched remote refs are excluded."
    echo "Branches are ordered by their latest commit. ACTIVE identifies the branch currently used by that workspace."
    for workspace in "$parent"/clickhouse*; do
        [[ -d $workspace ]] || continue
        name=$(basename "$workspace")
        [[ $name =~ ^clickhouse([0-9]+)?$ ]] || continue
        git -C "$workspace" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
        mapfile -t branches < <(git -C "$workspace" for-each-ref --format='%(refname:short)' --sort=-committerdate refs/heads/uberdever/)
        ((${#branches[@]})) || continue

        active=$(git -C "$workspace" symbolic-ref -q --short HEAD || true)
        [[ $active == uberdever/* ]] || active=""
        head=$(git -C "$workspace" rev-parse --short HEAD)
        printf '\n%s  HEAD %s\n' "$workspace" "$head"
        [[ -n $active ]] && printf '  ACTIVE  %s\n' "$active"
        for branch in "${branches[@]}"; do
            number=$((number + 1))
            line=$(git -C "$workspace" log -1 --format='%h  %cs  %s' "refs/heads/$branch")
            if [[ $branch == "$active" ]]; then
                printf '  * [%02d] %s  %s\n' "$number" "$branch" "$line"
            else
                printf '    [%02d] %s  %s\n' "$number" "$branch" "$line"
            fi
        done
    done
}

run_remote() {
    local command runner log_dir
    if [[ $# -eq 1 ]]; then command=$1; else printf -v command '%q ' "$@"; fi
    log_dir="$remote_base"
    runner='cd "$1" || exit; mkdir -p "$2"; bash -lc "$3" 2>&1 | tee "$2/last-run.log"; exit "${PIPESTATUS[0]}"'
    echo "[devvm_sync] running without sync in $remote_dir: $command"
    echo "[devvm_sync] live output; VM log: $log_dir/last-run.log"
    ssh -tt "${ssh_opts[@]}" "$ssh_target" \
        "bash -c $(q "$runner") _ $(q "$remote_dir") $(q "$log_dir") $(q "$command")"
}

case $mode in
    sync) sync_repo ;;
    run) run_remote "$@" ;;
    reset) reset_remote ;;
    branches) report_branches ;;
esac
