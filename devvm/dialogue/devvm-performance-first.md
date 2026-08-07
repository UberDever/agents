# Devvm performance-first redesign — dialogue ledger

## Framing

- [fact] Current implementation creates private bare mirrors on the VM for the top-level repository and every initialized submodule, then separately materializes normal working repositories from them.
- [fact] `sync` currently transfers refs/objects to both a mirror and a working repository, recursively, and applies overlays afterward.
- [preference] Performance must lead the redesign; the current sync is too slow.
- [fact] There are three separate local ClickHouse workspaces used for parallel development.
- [preference] Each VM target needs only a strict checkout of that workspace's selected branch/HEAD for build/test, not a browsable copy of all branches.
- [preference] Submodule local changes are rare and will not be part of the normal sync contract; the main repository commit is the Git transfer unit.
- [decision pending] Choose a faster replication/materialization model without losing the required main-worktree snapshot semantics.

## Model

The workload is three independent, parallel, branch-specific ClickHouse build/test workspaces. The VM is a disposable executor for each workspace, not a Git server or branch browser. Main-repository committed state and local overlay matter; recursively reproducing local submodule worktrees does not justify its cost.

## Requirements

1. [requirement, user] Optimize normal sync performance first; a slower first sync is acceptable.
2. [requirement, user] Maintain three independent, fixed local-workspace → VM-directory mappings for parallel work.
3. [requirement, user] VM is a build/test executor for the selected branch/HEAD, not a remote Git browser.
4. [requirement, user] Sync top-level committed state plus staged, unstaged, and untracked overlays.
5. [requirement, user] Do not push anything to any origin. An unpushed local main-repo commit may be transferred only to the corresponding VM.
6. [requirement, user] Do not clone/fetch complete history from any origin. Multiple origins are configuration metadata, not sync sources.
7. [requirement, evidence] VM `HEAD` must be the exact local commit SHA: local Praktika obtains SHA through `git rev-parse HEAD` (`ci/praktika/runner.py`). Synthetic commits are invalid.
8. [requirement, user] Normal sync must not clean VM paths, including ignored build caches and stale untracked files. Conflicts are repaired manually.
9. [requirement, user] Local submodules must be clean. Do not transfer local submodule changes; fail clearly if they exist.
10. [requirement, derived] Normal submodules must remain valid Git submodules for build/CI tools.

## Compatibility spike — daily commands

- [fact, source inspection] Local Praktika derives the run SHA only through `git rev-parse HEAD` (`ci/praktika/runner.py`).
- [fact, source inspection] The amd build job uses `git submodule sync`, `init`, and `update --depth=1 --single-branch` (`ci/jobs/build_clickhouse.py`); it does not require main-repo history in its local path.
- [fact, source inspection] Integration job parameters use `info.sha` as a value and the supplied built-binary path (`ci/jobs/integration_test_check.py`); no main-repo history operation was found.
- [fact, source inspection] Local Praktika checks `git diff-index ... HEAD` for workflow-file changes (`ci/praktika/native_jobs.py`), which needs the `HEAD` tree/index but not ancestors.
- [judgment] A repository containing the exact `HEAD` commit and tree, marked shallow, is compatible with the three named daily commands. Certainty: 85. This excludes performance/release/backport workflows, which explicitly run `git fetch --unshallow`, `git log`, or `git rev-list`.

## Shallow-object spike

- [fact, local experiment] Packed only the exact source commit object, its root/subtree objects, and non-submodule blobs into a new repository; marked that commit in `.git/shallow`; `reset --hard` produced the exact source `HEAD`, a clean tree, and `git fsck --connectivity-only` passed.
- [fact, local experiment] A subsequent commit was installed by packing only the new commit plus object IDs absent from the prior snapshot tree. The destination retained the exact new SHA, shallow boundary, source change, and passed connectivity fsck.
- [measurement, non-representative small repo] Initial pack: 2215 bytes; one-file incremental pack: 1375 bytes.
- [judgment] Exact-SHA shallow snapshots are technically viable. Certainty: 95. Remaining work is transport/integration and a normal-submodule initialization check.

## Proposed architecture — shallow workspace snapshots

Each local workspace maps one-to-one to an independent VM directory and adjacent devvm state directory. The VM directory is a normal Git checkout, not a mirror or worktree linked to a bare cache.

1. Preflight: reject uninitialized, modified, or untracked local submodules.
2. Snapshot transport: retain only the selected top-level `HEAD` commit/tree/blob closure. On the first sync send that closure; later send `HEAD` plus tree/blob object IDs absent from the prior snapshot closure. Install packs with `git index-pack`; retain exact SHA and record shallow boundaries.
3. Materialization: set only the selected local branch ref (or detached HEAD), then `reset --hard` to exact `HEAD`. No remote refs, origin fetches, histories, or branch mirrors are created.
4. Overlay: apply staged diff with `git apply --index`, working diff with `git apply`, then copy untracked non-ignored files. Never clean stale VM files.
5. Submodules: maintain ordinary `.git/modules` submodules. A marker containing gitlinks plus `.gitmodules` identity skips update when unchanged. On a change, run normal shallow `git submodule update`; fail rather than replicate local submodule state.
6. State: per-workspace `last-head`, shallow-boundary list, gitlink marker, and task log. No state is shared across the three workspaces.
7. Repair: explicit `reset` deletes that workspace checkout, its build caches, and its state; next `sync` rebuilds it. It preserves the shared object pool.

## Implementation and validation

- [fact] Replaced the mirror/worktree implementation with the shallow-snapshot protocol in `devvm_sync.sh`.
- [fact] Validated against a normal parent/submodule repository: exact shallow HEAD, standard `git submodule update --init --recursive`, staged overlay, unstaged overlay, untracked overlay, and an incremental committed snapshot all passed.
- [fact] Validated a second VM workspace at the same commit: it detected the shared pool object and transferred no main Git snapshot pack.
- [fact] Smoke workspaces were reset after validation; shared append-only object pools were intentionally retained.
- [fact, ClickHouse integration test] An isolated `clickhouse3` shallow sync completed: exact `HEAD`, shallow main repository, all direct submodules initialized, and the real local tracked/untracked overlay appeared on the VM.
- [measurement, ClickHouse integration test] Initial immediate re-sync took 44 seconds, dominated by retransmitting 15 untracked top-level directories (approximately 145 MiB, including `contrib/wasmtime` at 89 MiB) and per-submodule status checks.
- [fact, correction] Replaced tar overlay transfer with quiet SSH `rsync` without `--delete`; unchanged untracked source trees are no longer retransmitted and no names/content are emitted to logs. Replaced one-process-per-submodule preflight with one superproject status scan.
- [measurement, ClickHouse integration test] Post-correction no-op-with-overlay re-sync profile: local submodule validation 1.7s, main materialization 1.0s, overlay including incremental rsync 2.3s; total approximately 5.2s.
