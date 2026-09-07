#!/usr/bin/env bash
# Performance-first, explicit VM snapshots. `run` never syncs.
set -euo pipefail

MYVM_LOGIN=uberdever
MYVM_IP6=2a02:6b8:c02:900:0:fdb6:0:106
PROTOCOL=worktree-snapshot-v2

usage() {
    cat >&2 <<'EOF'
Usage:
  devvm_sync.sh sync [remote-dir]
  devvm_sync.sh run [remote-dir] -- <command>
  devvm_sync.sh reset [remote-dir]

sync  explicitly installs the current top-level Git snapshot plus staged,
      unstaged, and untracked overlays. Local submodules may be uninitialized;
      initialized local submodules must be clean and are never copied.
run   executes in the existing VM checkout; it never syncs.
reset removes this VM checkout, its state, and its build caches. It preserves
      shared append-only Git object pools used by other workspaces.
EOF
}
die() { echo "[devvm_sync] error: $*" >&2; exit 1; }
q() { printf '%q' "$1"; }

[[ $# -gt 0 ]] || { usage; exit 2; }
mode=$1; shift
case $mode in sync|run|reset) ;; *) usage; exit 2 ;; esac

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "must run inside a git work tree"
repo_root=$(git rev-parse --show-toplevel)
repo_name=$(basename "$repo_root")
remote_root=${DEVVM_REMOTE_ROOT:-/mnt/devssd/dev}
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
[[ $remote_dir == /* ]] || remote_dir="$remote_root/$remote_dir"
[[ -n $remote_dir && $remote_dir != / ]] || die "refusing an empty or root VM workspace path"

ssh_target="${MYVM_LOGIN}@${MYVM_IP6}"
control_path="${XDG_RUNTIME_DIR:-/tmp}/devvm-sync-${MYVM_LOGIN}@${MYVM_IP6//:/_}"
ssh_opts=(-A -6 -o ControlMaster=auto -o ControlPersist=10m -o ControlPath="$control_path")
remote_base="${remote_dir}.devvm-sync"

# Workspaces cloned from the same origin share immutable objects, but never
# refs, indexes, worktrees, submodule checkouts, or build directories.
origin_identity=$(git config --get remote.origin.url 2>/dev/null || printf '%s' "$repo_name")
pool_key=$(printf '%s' "$origin_identity" | sha256sum | awk '{print substr($1, 1, 20)}')
remote_pool=${DEVVM_OBJECT_POOL:-"$(dirname "$remote_dir")/.devvm-objects-$pool_key.git"}
remote_submodule_pools=${DEVVM_SUBMODULE_OBJECT_ROOT:-"$(dirname "$remote_dir")/.devvm-submodule-objects"}
git_common_dir=$(git rev-parse --path-format=absolute --git-common-dir)
local_submodule_pools=${DEVVM_LOCAL_SUBMODULE_OBJECT_ROOT:-"$git_common_dir/devvm-sync-submodules"}

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
    local -a paths initialized=()
    mapfile -d '' paths < <(submodule_paths)

    if ! git diff --quiet -- .gitmodules || ! git diff --cached --quiet HEAD -- .gitmodules; then
        die ".gitmodules changes are not supported by devvm sync"
    fi
    if git diff --raw -- | awk '$1 == ":160000" || $2 == "160000" { found=1 } END { exit !found }' ||
       git diff --cached --raw HEAD -- | awk '$1 == ":160000" || $2 == "160000" { found=1 } END { exit !found }'; then
        die "staged or unstaged gitlink changes are not supported by devvm sync"
    fi
    ((${#paths[@]})) || return 0

    # Linked task worktrees intentionally leave submodules uninitialized. Check
    # only paths that contain their own Git repository, using one superproject
    # status scan rather than hundreds of per-module Git processes.
    for path in "${paths[@]}"; do
        [[ -e $repo_root/$path/.git ]] && initialized+=("$path")
    done
    ((${#initialized[@]})) || return 0
    if [[ -n $(git status --porcelain --ignore-submodules=none -- "${initialized[@]}") ]]; then
        die "initialized local submodules must be clean"
    fi
}

submodule_url() {
    local path=$1 key name path_value url=""
    while IFS=' ' read -r key path_value; do
        [[ $path_value == "$path" ]] || continue
        name=${key#submodule.}
        name=${name%.path}
        url=$(git config --get "submodule.$name.url" 2>/dev/null || true)
        [[ -n $url ]] || url=$(git config --file .gitmodules --get "submodule.$name.url" 2>/dev/null || true)
        break
    done < <(git config --file .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null || true)
    [[ -n $url ]] || url=$(git config --get "submodule.$path.url" 2>/dev/null || true)
    [[ -n $url ]] || die "gitlink $path has no submodule URL"
    printf '%s\n' "$url"
}

submodule_source_repo() {
    local path=$1 commit=$2 url=$3 key=$4 candidate pool
    candidate="$git_common_dir/modules/$path"
    if git --git-dir="$candidate" cat-file -e "$commit^{commit}" 2>/dev/null; then
        printf '%s\n' "$candidate"
        return
    fi

    pool="$local_submodule_pools/$key.git"
    if [[ ! -d $pool ]]; then
        mkdir -p "$(dirname "$pool")"
        git init --bare "$pool" >/dev/null
    fi
    if ! git --git-dir="$pool" cat-file -e "$commit^{commit}" 2>/dev/null; then
        echo "[devvm_sync] fetching missing submodule object: $path $commit" >&2
        # GitHub edge may return a false 401 for HTTP/2 upload-pack POST.
        if ! GIT_TERMINAL_PROMPT=0 git -c http.version=HTTP/1.1 -c protocol.file.allow=always --git-dir="$pool" \
            fetch --no-tags --depth=1 "$url" "$commit"; then
            die "cannot fetch submodule $path at $commit from $url"
        fi
    fi
    printf '%s\n' "$pool"
}

snapshot_objects_from() {
    # Exact closure needed to check out COMMIT, excluding gitlink commit IDs:
    # nested submodules are separately transferred through their own pools.
    local repository=$1 commit=$2
    {
        printf '%s\n' "$commit"
        git --git-dir="$repository" rev-parse "$commit^{tree}"
        git --git-dir="$repository" ls-tree -r -t "$commit" | awk '$2 != "commit" { print $3 }'
    } | sort -u
}

snapshot_objects() { snapshot_objects_from "$(git rev-parse --absolute-git-dir)" "$1"; }

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

# Exact source reconciliation. Preserve only build acceleration state and
# desired submodule roots; each submodule is reset and cleaned separately.
clean_args=(-ffdx -e ci/tmp/build/ -e ci/tmp/sccache/)
while IFS=$'\t' read -r _ _ path _; do
    [[ -n $path ]] && clean_args+=(-e "$path/")
done < "$STATE/submodules.manifest.new"

clean_worktree() {
    local image
    if git clean "${clean_args[@]}" >/dev/null 2>&1; then
        return
    fi

    echo "[devvm_sync] host cleanup hit root-owned files; using Docker cleanup" >&2
    image=$(docker images --format '{{.Repository}}:{{.Tag}}' 'clickhouse/binary-builder' |
        grep -v ':<none>$' | head -n1 || true)
    [[ -n $image ]] || {
        echo "[devvm_sync] no clickhouse/binary-builder image available for root cleanup" >&2
        return 1
    }
    docker run --rm --volume "$WORKTREE":/work --workdir /work "$image" \
        git -c safe.directory=/work clean "${clean_args[@]}" >/dev/null
    git clean "${clean_args[@]}" >/dev/null
}

clean_worktree

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
clean_worktree
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
        # generated source trees. Stale VM files were removed during exact
        # reconciliation. Excluding nested .git directories avoids copying
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

prepare_submodule_snapshots() {
    local head=$1 manifest=$2 sha path url key source
    : >"$manifest"
    while IFS=' ' read -r sha path; do
        [[ $path != *[[:space:]]* ]] || die "submodule paths containing whitespace are unsupported: $path"
        url=$(submodule_url "$path")
        [[ $url != *$'\t'* && $url != *$'\n'* ]] || die "submodule URL contains unsupported control characters: $path"
        key=$(printf '%s' "$url" | sha256sum | awk '{print substr($1, 1, 20)}')
        source=$(submodule_source_repo "$path" "$sha" "$url" "$key")
        printf '%s\t%s\t%s\t%s\t%s\n' "$sha" "$key" "$path" "$url" "$source" >>"$manifest"
    done < <(git ls-tree -r "$head" | awk '$2 == "commit" { print $3 " " $4 }')
}

send_submodule_snapshot() {
    local commit=$1 key=$2 path=$3 source=$4 pool objects_file
    pool="$remote_submodule_pools/$key.git"
    echo "[devvm_sync] sending submodule snapshot: $path $commit"
    objects_file=$(mktemp)
    snapshot_objects_from "$source" "$commit" >"$objects_file"
    git --git-dir="$source" pack-objects --stdout <"$objects_file" |
        ssh "${ssh_opts[@]}" "$ssh_target" \
            "mkdir -p $(q "$(dirname "$pool")"); test -d $(q "$pool") || git init --bare $(q "$pool") >/dev/null; git --git-dir=$(q "$pool") index-pack --stdin --fix-thin --keep=devvm-sync >/dev/null"
    rm -f "$objects_file"
}

send_submodule_snapshots() {
    local manifest=$1 commit key path url source identity missing
    local -A sources paths
    while IFS=$'\t' read -r commit key path url source; do
        identity="$commit:$key"
        sources["$identity"]=$source
        paths["$identity"]=$path
    done <"$manifest"

    missing=$(mktemp)
    remote_bash "STATE=$(q "$remote_base") POOLS=$(q "$remote_submodule_pools")" >"$missing" <<'REMOTE'
set -euo pipefail
while IFS=$'\t' read -r commit key path _; do
    git --git-dir="$POOLS/$key.git" cat-file -e "$commit^{commit}" 2>/dev/null ||
        printf '%s\t%s\t%s\n' "$commit" "$key" "$path"
done < "$STATE/submodules.manifest.new"
REMOTE
    while IFS=$'\t' read -r commit key path; do
        identity="$commit:$key"
        send_submodule_snapshot "$commit" "$key" "${paths[$identity]:-$path}" "${sources[$identity]}"
    done <"$missing"
    rm -f "$missing"
}

upload_submodule_manifest() {
    local manifest=$1
    cut -f1-4 "$manifest" |
        ssh "${ssh_opts[@]}" "$ssh_target" "cat > $(q "$remote_base/submodules.manifest.new")"
}

sync_submodules() {
    install_compat_gitmodules
    remote_bash "WORKTREE=$(q "$remote_dir") STATE=$(q "$remote_base") POOLS=$(q "$remote_submodule_pools")" <<'REMOTE'
set -euo pipefail
cd "$WORKTREE"
git_dir=$(git rev-parse --absolute-git-dir)
manifest="$STATE/submodules.manifest.new"
old_manifest="$STATE/submodules.manifest"
desired=$(mktemp)
cut -f3 "$manifest" >"$desired"

valid_path() {
    [[ -n $1 && $1 != /* && $1 != .. && $1 != ../* && $1 != */../* ]]
}

# Remove module metadata only for gitlinks no longer present. The superproject
# clean removes their old working paths.
if [[ -f $old_manifest ]]; then
    while IFS=$'\t' read -r _ _ old_path _; do
        valid_path "$old_path" || { echo "[devvm_sync] invalid old submodule path: $old_path" >&2; exit 1; }
        grep -Fxq "$old_path" "$desired" || rm -rf -- "$git_dir/modules/$old_path"
    done <"$old_manifest"
fi

while IFS=$'\t' read -r commit key path url; do
    valid_path "$path" || { echo "[devvm_sync] invalid submodule path: $path" >&2; exit 1; }
    pool="$POOLS/$key.git"
    git --git-dir="$pool" cat-file -e "$commit^{commit}" 2>/dev/null || {
        echo "[devvm_sync] missing VM submodule object: $path $commit" >&2
        exit 1
    }

    # Register URL in the superproject without fetching. This keeps later
    # Praktika `git submodule sync` calls compatible with normal submodules.
    git submodule init -- "$path" >/dev/null

    if [[ ! -e $path/.git ]] || ! git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "[devvm_sync] materializing submodule: $path" >&2
        rm -rf -- "$path" "$git_dir/modules/$path"
        mkdir -p "$(dirname "$path")"
        git init -q "$path"
        module_git=$(git -C "$path" rev-parse --absolute-git-dir)
        git -C "$path" config remote.origin.url "$url"
        mkdir -p "$module_git/objects/pack"
        find "$pool/objects/pack" -maxdepth 1 -type f -print0 |
        while IFS= read -r -d '' pack; do
            ln -f "$pack" "$module_git/objects/pack/${pack##*/}"
        done
        printf '%s\n' "$commit" >"$module_git/shallow"
        git -C "$path" checkout --detach "$commit" >/dev/null
        git submodule absorbgitdirs -- "$path" >/dev/null
    fi

    module_git=$(git -C "$path" rev-parse --absolute-git-dir)
    rm -f "$module_git/objects/info/alternates"
    mkdir -p "$module_git/objects/pack"
    find "$pool/objects/pack" -maxdepth 1 -type f -print0 |
    while IFS= read -r -d '' pack; do
        ln -f "$pack" "$module_git/objects/pack/${pack##*/}"
    done
    touch "$module_git/shallow"
    grep -Fxq "$commit" "$module_git/shallow" || printf '%s\n' "$commit" >>"$module_git/shallow"
    git -C "$path" config remote.origin.url "$url"
    git -C "$path" reset --hard "$commit" >/dev/null
    git -C "$path" clean -ffdx >/dev/null
    [[ $(git -C "$path" rev-parse HEAD) == "$commit" ]] || {
        echo "[devvm_sync] wrong submodule HEAD after materialization: $path" >&2
        exit 1
    }
done <"$manifest"

mv "$manifest" "$old_manifest"
rm -f "$desired"
REMOTE
}

sync_repo() {
    local head branch previous submodule_manifest
    cd "$repo_root"
    profile_step local-submodules check_local_submodules
    head=$(git rev-parse HEAD)
    branch=$(git symbolic-ref --quiet HEAD || true)
    previous=$(read_remote_file "$remote_base/last-head")
    submodule_manifest=$(mktemp)
    trap 'rm -f "${submodule_manifest:-}"' EXIT
    profile_step local-submodule-objects prepare_submodule_snapshots "$head" "$submodule_manifest"

    echo "[devvm_sync] workspace: $repo_root"
    echo "[devvm_sync] VM checkout: $remote_dir"
    profile_step remote-layout ensure_remote_layout
    profile_step objects send_snapshot_objects "$head" "$previous"
    profile_step object-links link_pool_packs
    profile_step submodule-manifest upload_submodule_manifest "$submodule_manifest"
    profile_step submodule-objects send_submodule_snapshots "$submodule_manifest"
    profile_step materialize materialize_head "$head" "$branch"
    profile_step submodules sync_submodules
    profile_step overlay apply_overlay "$head"
    rm -f "$submodule_manifest"
    trap - EXIT
    echo "[devvm_sync] sync complete"
}

reset_remote() {
    echo "[devvm_sync] removing VM workspace and caches: $remote_dir"
    echo "[devvm_sync] shared object pool is preserved: $remote_pool"
    echo "[devvm_sync] shared submodule object pools are preserved: $remote_submodule_pools"
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
esac
