# Push Mechanics Reference

## Basic push

```bash
arc push                               # pushes current branch as users/<login>/<local-name>
arc push --publish                     # push + auto-publish PR iteration
arc push --wait                        # push and wait until PR is updated in Arcanum
```

The bare form works only when the local branch is named without the `users/<login>/` prefix (e.g., `TICKET-1234-fix-bug`). Arc adds the namespace automatically on push.

## Double prefix problem (detailed)

Arc namespaces server branches under `users/<login>/` automatically. If the local branch already contains that prefix, push duplicates it: `users/<login>/users/<login>/TICKET`. Same trap affects `arc pr create --publish` (creates a PR pointing at the doubled name) and `arc submit`.

Root-cause fix — keep the local branch name short:

```bash
arc checkout -b TICKET-1234-fix-bug trunk  # local name without prefix
arc push                                    # pushes as users/<login>/TICKET-1234-fix-bug
```

Fallback when the local branch is already prefixed:

```bash
arc push -u users/<login>/TICKET-1234-fix-bug                              # plain push
arc push -f -u users/<login>/TICKET-1234-fix-bug                           # force push
arc pr create --publish --push users/<login>/TICKET-1234-fix-bug -m "..."  # PR creation
```

## Force push safety

Force push rewrites remote history. Before force pushing on a shared branch:

1. `arc pull` first to check for other developers' commits
2. If pull reveals new commits you didn't make, rebase on top of them
3. Only then force push: `arc push -f` (or `arc push -f -u users/<login>/<branch>` if local branch is prefixed)

On personal branches (only you work on them), force push is safe without pull.

## --set-upstream quirk

`arc push --set-upstream` without a branch argument breaks. Use the short form: `arc push -u <branch-name>`. Only needed when local branch is already prefixed; otherwise bare `arc push` works.

## When force push is required

After any history-rewriting operation:
- `arc rebase`
- `arc commit --amend`
- `arc reset` (when commits were removed)
- Squash via `arc reset --soft HEAD~N` + recommit

## Common push errors

### "pushed 0 commit(s)"

Not an error. Arc push works in two phases: (1) upload commit objects, (2) move branch
pointer. If commits were already uploaded earlier (e.g., pushed to a wrong branch name),
the second push uploads 0 new commits but still moves the pointer correctly.
Verify with `arc pr list` that the PR looks right.

### "branch 'X' already exist and should be merged before update"

Remote branch diverged from local. Fix:
```bash
arc info --json                           # inspect the local branch field
arc pull                                  # inspect remote commits before overwriting
arc push -f                               # if the local branch is unprefixed
arc branch -u users/<login>/<branch>      # only if the local branch is already prefixed
arc push -f -u users/<login>/<branch>     # only for that already-prefixed local branch
```
Warning: this overwrites the remote branch. If the remote has changes you need,
fetch them first into a separate branch.

Do not choose the explicit `-u users/<login>/<branch>` form from this error
message alone. For a normal unprefixed local branch, Arc adds the namespace and
bare `arc push -f` remains the correct form.

### "branch 'X' should be merged into 'Y' before push"

Misleading message, arc has no merge operation. Inspect `arc info --json` and
apply the same branch-name rule: bare `arc push -f` for an unprefixed local
branch; explicit `arc push -f -u users/<login>/<branch>` only when the local
branch itself is already prefixed.

### Pull after someone else's force push

When a collaborator force-pushed to your shared branch:
```bash
arc reset --hard arcadia/users/<login>/<branch>
```
