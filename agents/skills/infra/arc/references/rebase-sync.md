# Rebase & Sync Reference

## Sync with trunk

```bash
arc checkout trunk       # switch to trunk
arc pull                 # pull latest changes
arc checkout <branch>    # switch back to feature branch
arc rebase trunk         # rebase on top of fresh trunk
```

Or without switching:
```bash
arc pull trunk           # pull trunk while on any branch
arc rebase trunk         # rebase current branch onto trunk
```

## After rebase

Force push is required because rebase rewrites commit hashes:
```bash
arc info --json                          # inspect the local branch field
arc push -f                              # normal unprefixed local branch
arc push -f -u users/<login>/<branch>   # only if the local branch itself is already prefixed
```

Do not add `-u users/<login>/<branch>` merely because a push reports remote
divergence. The local `branch` value controls the form: an unprefixed branch
uses bare `arc push -f`; an already-prefixed local branch needs the explicit
target to avoid a double prefix.

## Conflict resolution during rebase

If `arc rebase trunk` produces conflicts:
1. `arc status` to see conflicted files
2. Edit each file, resolve `<<<<<<<` / `=======` / `>>>>>>>` markers
3. `arc add <resolved-files>`
4. `arc rebase --continue`
5. Repeat until all commits are replayed

To abort: `arc rebase --abort` (returns to pre-rebase state).

## Shared branch safety

Before force pushing on a branch where others may commit:
1. `arc pull` first to check for new commits
2. If new commits appear, rebase on top of them
3. Only then use `arc push -f` for an unprefixed local branch, or the explicit
   `arc push -f -u users/<login>/<branch>` form when the local branch itself is
   already prefixed.

On personal branches, force push is safe without pull.

## Pull options

```bash
arc pull                 # pull current branch
arc pull trunk           # pull trunk (can run from any branch)
arc pull --rebase        # pull + rebase instead of merge
```

## Recovery: undo a rebase

Previous branch state is saved in `ORIG_HEAD`:
```bash
arc status
arc reset --hard ORIG_HEAD
```

Before running the reset, explicitly warn that `--hard` permanently discards
all current staged and unstaged changes. If any local work must survive the
recovery, save it first with `arc stash push -m "before rebase recovery"`.

## Rebase --onto (change branch base)

When branch B was based on branch A, and you want B based on trunk instead:
```bash
arc rebase --onto trunk A B
```

General form: `arc rebase --onto <new-base> <old-base> <branch>`.

## Reflog (local state history)

```bash
arc reflog show -n 5    # last 5 state changes (checkout, rebase, reset, etc.)
```

Useful for debugging what happened to the repository.
