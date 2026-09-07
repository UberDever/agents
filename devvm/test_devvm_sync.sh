#!/usr/bin/env bash
set -euo pipefail

script=${1:-"$(cd "$(dirname "$0")" && pwd)/devvm_sync.sh"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

export GIT_AUTHOR_NAME=devvm-test
export GIT_AUTHOR_EMAIL=devvm-test@example.invalid
export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME
export GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL

fake_bin="$test_root/bin"
real_git=$(command -v git)
module_cached="$test_root/module-cached"
module_fetched="$test_root/module-fetched"
main="$test_root/main"
task="$test_root/clickhouse-task"
remote="$test_root/remote/clickhouse-task"
mkdir -p "$fake_bin"

git init -q "$module_cached"
printf 'cached module\n' >"$module_cached/cached.txt"
git -C "$module_cached" add cached.txt
git -C "$module_cached" commit -qm cached

git init -q "$module_fetched"
printf 'fetched module\n' >"$module_fetched/fetched.txt"
git -C "$module_fetched" add fetched.txt
git -C "$module_fetched" commit -qm fetched

git init -q "$main"
printf 'base staged\n' >"$main/staged.txt"
printf 'base unstaged\n' >"$main/unstaged.txt"
printf '*.ignored\nci/tmp/\n' >"$main/.gitignore"
git -C "$main" add staged.txt unstaged.txt .gitignore
git -C "$main" commit -qm base
git -C "$main" -c protocol.file.allow=always submodule add -q "$module_cached" deps/cached
git -C "$main" -c protocol.file.allow=always submodule add -q "$module_fetched" deps/fetched
git -C "$main" commit -qam submodules

# Cached module remains available locally even though the committed URL is
# intentionally unusable. The second module exercises on-demand local fetching.
git -C "$main" config -f .gitmodules submodule.deps/cached.url "$test_root/unavailable"
git -C "$main" add .gitmodules
git -C "$main" commit -qm 'retire cached module URL'
git -C "$main" worktree add -q -b task "$task"
rm -rf -- "$main/.git/modules/deps/fetched"

cat >"$fake_bin/ssh" <<'MOCK_SSH'
#!/usr/bin/env bash
set -euo pipefail
while (($#)); do
    case $1 in
        -o|-i|-p|-l) shift 2 ;;
        -*) shift ;;
        *) break ;;
    esac
done
(($#)) || exit 2
shift
if (($#)); then
    exec bash -c "$*"
fi
exec bash
MOCK_SSH

cat >"$fake_bin/rsync" <<'MOCK_RSYNC'
#!/usr/bin/env bash
set -euo pipefail
args=("$@")
count=${#args[@]}
source_dir=${args[count-2]}
destination=${args[count-1]}
destination=${destination#*]:}
while IFS= read -r -d '' path; do
    [[ $path != .git && $path != */.git && $path != */.git/* ]] || continue
    mkdir -p "$destination/$(dirname "$path")"
    cp -a "$source_dir/$path" "$destination/$path"
done
MOCK_RSYNC

# Reproduce GitHub's false authentication failure on HTTP/2 upload-pack POST
# while keeping every Git operation real. Missing-module fetch must use HTTP/1.1.
cat >"$fake_bin/git" <<'MOCK_GIT'
#!/usr/bin/env bash
set -euo pipefail
is_target_fetch=false
has_http_1_1=false
is_clean=false
for ((i = 1; i <= $#; ++i)); do
    [[ ${!i} == fetch ]] && is_target_fetch=true
    [[ ${!i} == clean ]] && is_clean=true
    if [[ ${!i} == http.version=HTTP/1.1 && $i -gt 1 ]]; then
        previous=$((i - 1))
        [[ ${!previous} == -c ]] && has_http_1_1=true
    fi
done
if $is_target_fetch && [[ " $* " == *" $DEVVM_TEST_HTTP_1_1_URL "* ]] && ! $has_http_1_1; then
    echo "simulated HTTP/2 POST authentication failure" >&2
    exit 86
fi
if $is_clean && [[ -e ${DEVVM_TEST_ROOT_OWNED_PATH:-} ]]; then
    echo "warning: failed to remove ${DEVVM_TEST_ROOT_OWNED_PATH}: Permission denied" >&2
    exit 1
fi
exec "$DEVVM_TEST_REAL_GIT" "$@"
MOCK_GIT

cat >"$fake_bin/docker" <<'MOCK_DOCKER'
#!/usr/bin/env bash
set -euo pipefail
case ${1:-} in
    images)
        printf 'clickhouse/binary-builder:test\n'
        ;;
    run)
        shift
        volume="" workdir=""
        while (($#)); do
            case $1 in
                --rm) shift ;;
                --volume) volume=$2; shift 2 ;;
                --workdir) workdir=$2; shift 2 ;;
                -*) echo "unsupported fake docker option: $1" >&2; exit 2 ;;
                *) shift; break ;;
            esac
        done
        [[ $volume == *:/work && $workdir == /work && ${1:-} == git ]] || exit 2
        shift
        [[ ${1:-} == -c && ${2:-} == safe.directory=/work ]] || exit 2
        shift 2
        cd "${volume%:/work}"
        exec "$DEVVM_TEST_REAL_GIT" "$@"
        ;;
    *) exit 2 ;;
esac
MOCK_DOCKER
chmod +x "$fake_bin/ssh" "$fake_bin/rsync" "$fake_bin/git" "$fake_bin/docker"

printf 'local staged\n' >"$task/staged.txt"
git -C "$task" add staged.txt
printf 'local unstaged\n' >"$task/unstaged.txt"
printf 'local untracked\n' >"$task/untracked.txt"

run_sync() {
    PATH="$fake_bin:$PATH" \
    DEVVM_REMOTE_ROOT="$test_root/remote" \
    DEVVM_LOCAL_SUBMODULE_OBJECT_ROOT="$test_root/local-submodule-pools" \
    DEVVM_SUBMODULE_OBJECT_ROOT="$test_root/remote/submodule-pools" \
    DEVVM_TEST_HTTP_1_1_URL="$module_fetched" \
    DEVVM_TEST_REAL_GIT="$real_git" \
    DEVVM_TEST_ROOT_OWNED_PATH="$remote/root-owned.ignored" \
        bash "$script" sync
}

run_reset() {
    PATH="$fake_bin:$PATH" \
    DEVVM_REMOTE_ROOT="$test_root/remote" \
    DEVVM_LOCAL_SUBMODULE_OBJECT_ROOT="$test_root/local-submodule-pools" \
    DEVVM_SUBMODULE_OBJECT_ROOT="$test_root/remote/submodule-pools" \
    DEVVM_TEST_HTTP_1_1_URL="$module_fetched" \
    DEVVM_TEST_REAL_GIT="$real_git" \
        bash "$script" reset
}

(
    cd "$task"
    run_sync
)

[[ ! -e $task/deps/cached/.git ]]
[[ ! -e $task/deps/fetched/.git ]]
[[ $(git -C "$remote/deps/cached" rev-parse HEAD) == $(git -C "$task" ls-tree HEAD deps/cached | awk '{print $3}') ]]
[[ $(git -C "$remote/deps/fetched" rev-parse HEAD) == $(git -C "$task" ls-tree HEAD deps/fetched | awk '{print $3}') ]]

# Praktika runs this sequence. Exact pooled checkouts must require no network,
# even when `.gitmodules` now points the cached module at a retired URL.
git -C "$remote" submodule sync --quiet
GIT_TERMINAL_PROMPT=0 git -C "$remote" -c protocol.file.allow=always \
    submodule update --init --force --depth=1 --single-branch

mkdir -p "$remote/ci/tmp/build" "$remote/ci/tmp/sccache"
printf 'keep build\n' >"$remote/ci/tmp/build/cache"
printf 'keep sccache\n' >"$remote/ci/tmp/sccache/cache"
printf 'delete ignored\n' >"$remote/stale.ignored"
printf 'delete untracked\n' >"$remote/stale.txt"
mkdir -p "$remote/root-owned.ignored"
printf 'delete root-owned simulation\n' >"$remote/root-owned.ignored/cache.pyc"
printf 'dirty module\n' >"$remote/deps/cached/cached.txt"
printf 'delete module junk\n' >"$remote/deps/cached/junk.txt"
printf 'dirty remote tracked\n' >"$remote/unstaged.txt"

(
    cd "$task"
    run_sync
)

test -f "$remote/ci/tmp/build/cache"
test -f "$remote/ci/tmp/sccache/cache"
test ! -e "$remote/stale.ignored"
test ! -e "$remote/stale.txt"
test ! -e "$remote/root-owned.ignored"
test ! -e "$remote/deps/cached/junk.txt"
cmp "$task/staged.txt" "$remote/staged.txt"
cmp "$task/unstaged.txt" "$remote/unstaged.txt"
cmp "$task/untracked.txt" "$remote/untracked.txt"
test -z "$(git -C "$remote/deps/cached" status --porcelain)"
test -z "$(git -C "$remote/deps/fetched" status --porcelain)"
if git -C "$remote" diff --cached --quiet --exit-code -- staged.txt; then
    echo "expected staged overlay is missing" >&2
    exit 1
fi
if git -C "$remote" diff --quiet --exit-code -- unstaged.txt; then
    echo "expected unstaged overlay is missing" >&2
    exit 1
fi

top_pool=$(find "$test_root/remote" -maxdepth 1 -type d -name '.devvm-objects-*.git' -print -quit)
test -n "$top_pool"
(
    cd "$task"
    run_reset
)
test ! -e "$remote"
test ! -e "$remote.devvm-sync"
test -d "$top_pool"
test -d "$test_root/remote/submodule-pools"

other_commit=$(git -C "$task" ls-tree HEAD deps/fetched | awk '{print $3}')
git -C "$task" update-index --add --cacheinfo "160000,$other_commit,deps/cached"
if (
    cd "$task"
    run_sync
); then
    echo "expected staged gitlink change to be rejected" >&2
    exit 1
fi
git -C "$task" reset -q HEAD -- deps/cached

printf 'devvm sync integration test passed\n'
