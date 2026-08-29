---
name: devvm-sync
description: Use the local devvm sync workflow for ClickHouse development when Codex, Claude, or CodeAssistant needs to hand off build/test commands to the user, avoid running heavy ClickHouse tests locally, or explicitly run/iterate tests on the development VM. Trigger on requests mentioning devvm, devvm sync, remote ClickHouse tests, VM builds, `~/dev/agents/devvm/devvm_sync.sh`, or workflows where the agent should edit locally while the user syncs and tests manually.
---

# Devvm Sync

## Core Rule

Use the canonical script from the local repository root:

```bash
~/dev/agents/devvm/devvm_sync.sh
```

For ClickHouse:

```bash
export REMOTE_DIR=/mnt/devssd/dev/clickhouse
```

`sync` is explicit. **`run` never syncs.**

## Interface

```bash
devvm_sync.sh sync [remote-dir]
devvm_sync.sh run [remote-dir] -- <command>
devvm_sync.sh reset [remote-dir]
devvm_sync.sh branches
```

Normal handoff:

```bash
export REMOTE_DIR=/mnt/devssd/dev/clickhouse
~/dev/agents/devvm/devvm_sync.sh sync
~/dev/agents/devvm/devvm_sync.sh run -- \
  python3 -m ci.praktika run "Build (amd_binary)" --param build
```

`branches` scans sibling `clickhouse`, `clickhouse2`, ... local workspaces and
reports only local `refs/heads/uberdever/*` branches. It assigns each listed
branch one global number, marks the active branch for each workspace, and
orders branches by latest commit, so fetched
remote-tracking branches cannot be mistaken for local development branches:

```bash
~/dev/agents/devvm/devvm_sync.sh branches
```

`run` streams foreground output and writes its latest VM log to:

```text
$REMOTE_DIR.devvm-sync/last-run.log
```

It has no detached task supervisor. Ctrl-C normally interrupts the SSH PTY and
foreground command, but there is no later `status`/`cancel` command.

## Daily Praktika Commands

Verified against local `clickhouse` `master` (`8ed0c76020b72a60447c1de65c87f08e4a1a2205`):

```bash
# Incremental amd binary build. Omit --param build to run the job's normal
# stages from scratch.
python3 -m ci.praktika run "Build (amd_binary)" --param build

# Current workflow alias. It maps to the configured non-required integration
# job; --test selects an integration test and --path supplies the built binary.
python3 -m ci.praktika run "integration" \
  --test tests/integration/test_delete_on_cluster_inactive_replica/test.py \
  --path /mnt/devssd/dev/clickhouse/ci/tmp/build/programs/clickhouse

# Current stateless parameterized job.
python -m ci.praktika run "Stateless tests (amd_debug, parallel)" \
  --test 00754_alter_modify_order_by_replicated_zookeeper_long \
  --path /mnt/devssd/dev/clickhouse/ci/tmp/build/programs/
```

Run them through devvm without implicit sync, for example:

```bash
~/dev/agents/devvm/devvm_sync.sh run -- \
  python3 -m ci.praktika run "Build (amd_binary)" --param build
```

The `integration` alias is unavailable on older ClickHouse branches. For those
branches, use the legacy parameterized job name (the `1/5` batch is intentional):

```bash
python -m ci.praktika run "Integration tests (amd_binary, 1/5)" \
  --path /mnt/devssd/dev/clickhouse/ci/tmp/build/programs/clickhouse
```

`Integration tests (amd_binary, 1/5)` was not found on current master, so use
it only as the old-branch fallback; use the `integration` alias on newer trees.

## Sync Contract

A successful `sync` installs:

- the exact local top-level `HEAD` SHA as a shallow VM repository;
- selected local branch or detached HEAD only, not mirrored history/refs;
- top-level staged, unstaged, and untracked non-ignored overlays;
- direct, normal Git submodules under `.git/modules` when committed gitlinks
  change.

It deliberately does **not**:

- push to or fetch main-repository origins;
- copy local submodule edits;
- clean stale VM files, ignored build caches, or stale VM untracked files.

Untracked overlays use quiet SSH `rsync` without `--delete`: unchanged files
are not retransmitted, and file names/content are not printed by devvm.

The VM must have normal direct submodules for Praktika/CMake. Nested vendor
submodules may remain uninitialized, matching ClickHouse build jobs.

Local direct submodules and `.gitmodules` must be clean. Sync fails rather
than copying local submodule state.

## Object Pool and Workspaces

Git objects are stored in an append-only VM object pool derived from the local
`origin` URL. Multiple workspace directories from the same origin reuse those
immutable objects.

Each workspace retains independent:

- checkout, refs, index, and shallow boundaries;
- submodule worktrees and metadata;
- build caches and devvm state.

Thus `clickhouse`, `clickhouse2`, and `clickhouse3` can sync independently.
Do not sync a workspace while a build in that same workspace is running.

Separate-workspace sync and build are safe. Two Praktika builds are currently
not safe in parallel on one VM because Praktika uses the VM-global Docker name
`praktika`.

## Submodule Compatibility and Repair

Some historical ClickHouse commits retain a gitlink after its `.gitmodules`
entry disappeared. If local `.git/config` has that submodule URL, sync adds a
disposable compatibility entry to the VM `.gitmodules`; this lets Praktika's
`git submodule sync` work. It does not alter the local repository.

If a VM submodule `.git` link points to a missing `.git/modules/...` cache,
sync removes only that broken VM module/cache and reinitializes it normally.

## Migration and Reset

For migration from the older worktree/mirror implementation, or a broken VM
checkout:

```bash
export REMOTE_DIR=/mnt/devssd/dev/clickhouse
~/dev/agents/devvm/devvm_sync.sh reset
~/dev/agents/devvm/devvm_sync.sh sync
```

`reset` deletes only that VM workspace checkout, state, and build caches. It
preserves the shared object pool and never changes the local repository. If a
Docker job left root-owned `__pycache__` or pytest-xdist `_gw*_instance`
directories, reset falls back to a root Docker container to remove the
workspace contents; reset is therefore explicitly destructive by design.

Use manual cleanup only when requested. To remove nested untracked Git
repositories locally, Git requires double force:

```bash
git clean -ffd -- contrib
```

Normal sync intentionally does not delete stale VM untracked files; clean
those explicitly or use `reset` when required.

## Managed VM `dev` tmux Session

The VM's shared `dev` tmux session maps windows to workspaces:

```text
dev:0  /mnt/devssd/dev/clickhouse
dev:1  /mnt/devssd/dev/clickhouse2
dev:2  /mnt/devssd/dev/clickhouse3
dev:3  /mnt/devssd/dev/clickhouse4
```

When explicitly asked to control one, inspect it non-interactively first:

```bash
tmux capture-pane -p -t dev:2 -S -40
tmux send-keys -t dev:2 'pwd; git rev-parse --show-toplevel HEAD' Enter
tmux capture-pane -p -t dev:2 -S -20
```

Only send a build command after the captured path and HEAD confirm the intended
workspace. Never send keys to an unknown pane, kill the user's `dev` session,
or start concurrent Praktika builds. Prefer a new, agent-owned tmux session for
long-running builds; this mapping is for selecting and inspecting a workspace,
not a substitute for persistent build logs and completion checks.

## Persistent Build Monitoring

For an explicitly requested long-running VM build, do not keep the SSH `run`
command attached. Start it in a new, workspace-specific tmux session and tee
its output to `/tmp`; use the requested start stage (for a resumed build,
`--param build`), never silently omit it:

```bash
tmux new-session -d -s clickhouse-amd-build \
  'cd /mnt/devssd/dev/clickhouse && set -o pipefail && \
   python3 -m ci.praktika run "Build (amd_binary)" --param build 2>&1 | \
   tee /tmp/clickhouse-amd-binary-build.log; \
   status=${PIPESTATUS[0]}; echo BUILD_EXIT=$status; exec bash'
```

Start and inspect tmux only through `devvm_sync.sh run`; `run` still does not
sync. Check periodically (for example, every five minutes) with
`tmux capture-pane` and the persisted log, sleeping between checks. Completion
is established by the `BUILD_EXIT=<status>` marker, not merely by the session's
existence (the pane deliberately remains open after the command). Do not start
a second Praktika build while one is active. Once completion has been recorded,
remove the persistent pane:

```bash
tmux kill-session -t clickhouse-amd-build
```

## Agent Policy

Default: edit locally and hand the user explicit `sync`, then `run` commands.
Do not run devvm commands yourself unless the user explicitly asks to run,
test, debug, or iterate on the VM.

When explicitly running remotely:

1. use this script, not raw remote setup;
2. never imply `run` syncs;
3. report command/result and concise relevant failures;
4. do not paste huge build logs or file contents/secrets.
