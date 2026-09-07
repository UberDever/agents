# ADR 001: Sync disposable ClickHouse worktrees through pooled Git snapshots

Status: accepted
Date: 2026-09-02

## Context

Replace fixed independent `clickhouse2`, `clickhouse3`, and `clickhouse4` clones
with disposable task-named linked worktrees beside the canonical
`/home/uberdever/dev/clickhouse` checkout. Local task worktrees may leave direct
submodules uninitialized. Each task must sync its exact top-level `HEAD` plus
staged, unstaged, and untracked non-ignored changes to an independent VM build
workspace faster than a recursive clone.

Repeated syncs must preserve only `ci/tmp/build` and `ci/tmp/sccache`. Other stale
VM source state may be removed or rewritten. Tool remains a small synchronous
shell workflow: `sync`, generic `run`, and destructive `reset`.

## Decision

Normal `sync` uses Git-native in-place reconciliation:

1. Keep current origin-keyed append-only superproject object pool.
2. Read direct gitlinks from task `HEAD`; source their objects from canonical
   `.git/modules` repositories, fetching missing objects into a local devvm pool.
3. Transfer only missing exact submodule commit/tree/blob closures into VM pools
   keyed by canonical submodule identity.
4. Materialize independent normal VM submodules at exact gitlink SHAs without
   initializing local task submodule worktrees or cloning from GitHub on VM.
5. Hard-reset and exhaustively clean VM superproject and submodules, preserving
   only `ci/tmp/build` and `ci/tmp/sccache`, then apply exact local overlay.
6. Keep `run` generic. A failed sync returns nonzero and is repaired by rerunning
   `sync`.
7. Keep `reset` destructive for task source and task caches while preserving
   shared object pools.

## Alternatives considered

- Independent clones: working status quo, but duplicate local repositories and
  recursive initialization cost.
- Delete/recreate source each sync: simple replacement semantics, but excessive
  filesystem I/O for ClickHouse and its direct submodules.
- VM linked worktrees: insufficient submodule and build-state isolation.
- Copy-on-write golden workspaces: potentially fast, but filesystem-specific and
  operationally larger than needed.

## Assumptions and revisit triggers

- Canonical module stores normally contain required gitlink objects. Missing
  objects are fetched; an unavailable source URL is an explicit sync failure.
- In-place reset/clean is accepted only after adversarial integration tests prove
  cache preservation and stale-state removal.
- First real task bootstrap must beat an independent recursive clone. Revisit
  transport if VM benchmark does not.
- Users do not sync and build concurrently in the same task workspace. Add locking
  only after an observed collision.
- Preserved CMake state may occasionally be incompatible. Destructive `reset` is
  the recovery rather than adding cache orchestration.

## Consequences

Disposable local worktrees stay small and need no submodule checkout. VM task
workspaces remain valid Git repositories for Praktika/CMake and retain iterative
build acceleration. Shared pools grow append-only; automatic pruning, lifecycle
registries, TTL cleanup, and Jenkins-like orchestration remain out of scope.

This ADR governs devvm worktree sync behavior. Reopen it when a stated trigger is
observed or cache paths/build workflow change.
