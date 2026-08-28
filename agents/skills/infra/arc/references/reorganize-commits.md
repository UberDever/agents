# Reorganize Commits Reference

## Commit options

- `arc commit -m "message"` - commit staged changes
- `arc commit -a -m "message"` - stage all tracked + commit
- `arc commit --amend` - amend previous commit (rewrites history, needs force push)
- `arc commit --no-verify` - skip pre-commit hooks
- Always use `arc add <specific-files>` over `arc add .` when possible

## Amend last commit

```bash
arc add <files>
arc commit --amend
arc info --json                         # inspect the exact local branch name
```

Before force-pushing a shared branch, run `arc pull` and inspect whether it
contains commits from other developers. Rebase on top of those commits before
overwriting the remote branch. Then choose the force-push form from the local
`branch` field:

```bash
arc push -f                                      # unprefixed local branch
arc push -f -u users/<login>/<branch>            # only if local branch is already prefixed
```

Do not use `-u <unprefixed-branch>` and do not synthesize a
`users/<login>/...` target for a normal unprefixed local branch.

## Cherry-pick

```bash
arc cherry-pick <full-40-char-hash>   # apply a single commit to current branch
```

Always use full 40-character hashes (short hashes are ambiguous in monorepo).

If cherry-pick conflicts:
1. Resolve conflicts in affected files
2. `arc add <resolved-files>`
3. `arc cherry-pick --continue`

To abort: `arc cherry-pick --abort`

## Reset

```bash
arc reset --soft HEAD~1     # undo last commit, keep changes staged
arc reset --mixed HEAD~1    # undo last commit, keep changes unstaged
arc reset --hard HEAD~1     # undo last commit, discard all changes (DESTRUCTIVE)
arc reset HEAD <file>       # unstage a file (two-param form per docs)
```

**Always pass both an explicit target AND an explicit mode flag.** Bare
`arc reset` (no args) is a no-op, not a git-style mixed reset against HEAD.

## Squash commits

**Option 1: Reset + recommit** (works in non-interactive shell, recommended for Claude Code):
1. `arc reset --soft HEAD~N` (N = number of commits to combine)
2. `arc commit -m "combined message"`
3. Apply the shared-branch check and branch-aware force-push rules from
   "Amend last commit" above.

**Option 2: Interactive rebase** (requires TTY, suggest user runs manually):
```bash
arc rebase -i HEAD~N           # opens editor with pick/squash/fixup/reword/edit/drop
# mark commits as "squash" or "fixup", save and close
# then apply the shared-branch check and branch-aware force-push rules above
```

Also supports `--autosquash` with `arc commit --fixup COMMIT` and `arc commit --squash COMMIT`.

## Squash all branch commits (when N is unknown)

When you don't know how many commits to squash:
```bash
arc reset --soft $(arc merge-base trunk HEAD)
arc commit -m "squashed message"
# then apply the shared-branch check and branch-aware force-push rules above
```

`arc merge-base trunk HEAD` returns the commit where the branch diverged from trunk,
so this squashes everything into one commit regardless of how many there are.

**Do NOT use `arc reset --soft trunk` for this.** On a sparse-mount checkout,
if the branch is far behind trunk (thousands of commits), arc refuses with
`Reset forbidden due to change outside the scope`, because moving HEAD to
current trunk would pull in files outside the mount. The `merge-base` target
stays inside the branch's own history and always works.

Common use case: accidentally committed a secret, next commit removes it,
squash both to hide the secret from branch history.

## Auto-squash at PR merge

When a PR with multiple commits is merged in Arcanum, all commits are automatically
squashed into one. Manual squashing before merge is optional.
