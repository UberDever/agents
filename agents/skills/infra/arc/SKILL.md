---
name: arc
# Maintainer note (stripped by YAML parsers — not visible to the model):
# Keep `description` focused on trigger routing only — Arcadia VCS signals,
# obvious exclusions, and the handoff boundary with `arcanum-go`. Keep
# procedural details, command syntax, pitfalls, and long
# trigger examples in the body of this skill or in `references/` so the
# frontmatter stays below loader limits.
description: >
  Use this skill for any version-control action in an Arcadia monorepo,
  including explicit VCS commands and coding tasks involving branches or
  commits. Trigger on any Arcadia VCS signal: Russian forms of коммит, ветка,
  пуш, or транк; trunk; ticket keys such as SHCP-1234; a.yandex-team.ru links;
  PR or pull-request IDs; commit hashes; requests to list changed files or
  discard tracked-file changes; arc CLI; or git commands that may target
  Arcadia. Covers branches, commits, push/pull, rebase, PR
  creation/update/review, diff, log, squash, stash, revert, blame, status, and
  history-preserving tracked-file move/copy/split. Detect Arcadia by .arc/,
  .arcignore, or root a.yaml. Do not use for GitHub, GitLab, SVN, SVG arcs,
  architecture, or Noah's Ark. For review comments, CI checks, labels,
  deploy-testing, or remote-only PR inspection, use arcanum-go.
user-invocable: false
author: astarta0
idp-product: arc
ya:
  preset:
    permissions:
      bash:
        "arc --version": allow
        "arc add *": allow
        "arc blame *": allow
        "arc branch *": allow
        "arc checkout *": allow
        "arc cherry-pick *": allow
        "arc commit": allow
        "arc commit *": allow
        "arc cp *": allow
        "arc diff": allow
        "arc diff *": allow
        "arc info": allow
        "arc info *": allow
        "arc log": allow
        "arc log *": allow
        "arc merge-base *": allow
        "arc mv *": allow
        "arc pr changes": allow
        "arc pr changes *": allow
        "arc pr checkout": allow
        "arc pr checkout *": allow
        "arc pr create": allow
        "arc pr create *": allow
        "arc pr history": allow
        "arc pr history *": allow
        "arc pr list": allow
        "arc pr list *": allow
        "arc pr merge": allow
        "arc pr merge *": allow
        "arc pr publish": allow
        "arc pr publish *": allow
        "arc pr status": allow
        "arc pr status *": allow
        "arc pull": allow
        "arc pull *": allow
        "arc push": allow
        "arc push *": allow
        "arc rebase": allow
        "arc rebase *": allow
        "arc reflog *": allow
        "arc reset *": allow
        "arc rm *": allow
        "arc show *": allow
        "arc stash": allow
        "arc stash *": allow
        "arc status": allow
        "arc status *": allow
        "arc submit": allow
        "arc submit *": allow
---

# When to Delegate to an Arcanum Skill

Use **`arcanum-go`** for Arcanum-side tasks. Throughout this skill, every reference to "the Arcanum skill" means `arcanum-go`.

Use an Arcanum skill (not this one) when the task requires:
- **Review comments** — post, reply, resolve inline comments on a PR
- **CI/checks** — view check status, logs, failed tasks, trigger re-runs
- **Labels** — add/remove PR labels
- **Deploy-testing** — trigger deploy to testing environment
- **Reading PR remotely** — fetch diffs, files, and metadata as structured JSON without local checkout

Stay in `arc` for: commit, push, rebase, branch operations, creating/discarding PRs, local diffs (`arc diff -B`).

When both sides can do it (PR status, changed files, diff): prefer `arc` if you have a local checkout, prefer the Arcanum skill for remote-only access or when you need to post comments afterward.

# Arc VCS — Background Knowledge

Arc is a lightweight version control system for Arcadia monorepo. It stores data in the cloud and uses virtual filesystem instead of downloading the entire repo.

## Detecting an Arc Repository

A project uses arc (NOT git) if ANY of these are true:
- `.arc/` directory exists at the repo root
- `.arcignore` file exists
- `a.yaml` file exists (Arcadia CI configuration)

When arc is detected: NEVER use `git` or `gh` commands. Use `arc` CLI instead.
If an `arc` command fails with an unexpected error, check the correct syntax with `arc <command> --help` before retrying.

## Key Differences from Git

- **Always use full hashes** — short SHAs yield `ambiguous` in a monorepo with millions of objects. `arc log --oneline` prints full hashes, copy them as-is
- **Main branch is `trunk`** (not `main` or `master`)
- **Branch naming:** server branches live under `users/<login>/...`. Name the local branch **without** the prefix, using the format `TICKET-1234-short-description` (e.g., `TICKET-1234-fix-login-bug`); arc adds the namespace on push. See "double-prefix" in Monorepo Pitfalls.
- **Lazy fetch:** no need to run `arc fetch` before `pull`/`checkout`, it happens automatically
- **`arc cp`** preserves copy history, use it instead of plain file copy when moving/copying tracked files
- **`.arcignore`** uses the same format as `.gitignore`
- **PR target** defaults to `trunk`
- **`arc submit`** = create branch + commit + push + create PR in one command
- **`arc info --json`** shows current branch, commit hash, author info

## Scenarios

### Push changes
When user asks to push, commit, or send changes:
1. `arc status` — check working directory
2. If the branch already has a PR, verify that auto-publish is disabled before
   uploading. If it is enabled or cannot be verified, stop and ask the user:
   even a bare push can publish a new iteration through persistent PR settings.
3. `arc add <specific-files>` — stage changed files (never `arc add .`)
4. `arc commit -m "message"` — commit with descriptive message (always pass -m)
5. `arc push` — for a normal unprefixed local branch (the recommended convention, e.g. `TICKET-1234-fix-bug`) bare `arc push` is correct and arc adds the `users/<login>/` namespace; this is the common case, don't add `-u`. Only if the branch name **itself already begins with** `users/<login>/` (check `arc info --json` field `branch`) add an explicit `arc push -u users/<login>/<branch>`, otherwise the bare push doubles the prefix (see Monorepo Pitfalls).
6. **Shared branch safety:** before force push, `arc pull` first to check for others' commits

Choose the push form from the current **local branch name**, without inventing a server name:

| Current local branch | Normal push | Force push after rebase |
|---|---|---|
| `TICKET-1234-fix` (unprefixed) | `arc push` | `arc push -f` |
| `users/<login>/TICKET-1234-fix` (already prefixed) | `arc push -u users/<login>/TICKET-1234-fix` | `arc push -f -u users/<login>/TICKET-1234-fix` |

For an unprefixed branch, **never synthesize** `users/<login>/<branch>` and never add `-u`; arc adds the server namespace itself.

For push mechanics and double prefix details, read `references/push-changes.md`.

For every push recovery path, trust `arc info --json` field `branch`, not the
error wording. If the local branch is unprefixed, keep the target implicit and
use bare `arc push` / `arc push -f`; never suggest `arc branch -u` or an
explicit `users/<login>/...` target. Use explicit `-u users/<login>/<branch>`
only when the local branch name itself already has that prefix.

### Create or update PR
When user asks to create a PR or send for review:
1. Ensure changes are committed. **Don't run a separate `arc push` first** — `arc pr create` pushes for you.
2. Create a draft/unpublished PR by default with `arc pr create --publish=disabled --no-commits -m "description"`. The first line passed through `-m` or `-F` becomes the PR title and nothing else — the body is only what follows the blank line, so the two never overlap. Keep that first line a short human-readable title (~100 characters): Arcanum silently truncates the title around 300 characters, mid-word, while still reporting success, so a multi-sentence first line surfaces as an unreadably long title cut off mid-phrase. Use `--publish` instead of `--publish=disabled` only when the user explicitly asks in the current request to publish, send to review, or enable auto-merge. Never omit `-m` because that opens an editor. Keep `--no-commits` with a hand-written/curated `-m` description; otherwise arc appends the branch commit messages and duplicates the body (see the `-m` gotcha in `references/create-update-pr.md`). For a normal unprefixed branch this just works; only if the branch name already begins with `users/<login>/` pass it to the PR command itself with `--push users/<login>/<branch>` (not a separate `arc push`) to avoid the double prefix (see Monorepo Pitfalls).
3. For updating: just push new commits, PR updates automatically
4. Or use `arc submit -m "commit message"` for the streamlined flow (branch + commit + push + PR). Here `-m` is the message of the commit that `submit` creates. `arc submit` does **not** support `--no-commits`; when the user requires an exact curated PR description without appended commit messages, use `arc pr create --no-commits -m "description"` instead.
5. For auto-merge after all checks, use `arc pr create --publish --merge --no-commits -m "description"`. `--push` only uploads the branch; it does not replace the explicit `--publish` requested by the user.
6. For release branch PR with a curated description: `arc pr create --publish --no-commits --to <release-branch> -m "desc"`
7. To manage labels, check CI, or trigger deploy-testing on an existing PR, switch to `arcanum-go`
8. To close an open PR without merging it, use `arc pr discard <pr-id>`. The PR ID is positional; do not pass `--id`, and do not delegate this VCS action to an Arcanum skill.
9. After creation, run `arc pr status --json <pr-id>` and verify that `summary` exactly matches the intended first line — compare the full string, not its prefix, since an over-long title is cut at the tail and a truncated one still looks plausible at a glance. A created URL is not sufficient verification. If the title is wrong, treat PR creation as incomplete and correct it through the Arcanum skill (`ya tool arcanum pr update-summary --id <pr-id> --summary "..."`, and `ya tool arcanum pr update-description --id <pr-id> --description "..."` for the body) before reporting success.

For all PR flags (--merge, --auto, --to, --stack), stacked PRs, and release branch targeting, read `references/create-update-pr.md`.

### Submit changes (streamlined)
When user wants the simplest path from code to PR:
1. `arc submit -m "description"` — from trunk: creates branch + commits all tracked files + pushes + creates PR
2. `arc submit` — from existing submit-branch: commits + pushes + updates PR iteration (no -m needed)
3. `arc submit -m "desc" path/to/file` — submit only specific files
4. If conflicts: resolve files, `arc add <files>`, then `arc submit` again (or `arc submit --abort`)
5. `arc submit --new -m "desc"` — create independent PR from same trunk point
6. `arc pr select` — TUI to switch between submit-created branches (requires TTY)

For conflict handling details, --stack, and branch naming, read `references/submit-changes.md`.

### Review a PR
When user asks to look at, review, or check a PR:
1. `arc pr status <pr-id>` — get PR metadata (do NOT use `arc pr view`, it opens browser)
2. `arc pr changes <pr-id> | wc -l` — assess PR size
3. Small PR (<2K lines): `arc pr changes <pr-id>` — read diff directly
4. Large PR (>2K lines): `arc pr checkout <pr-id>` — checkout and read files
5. Get changed file list: `arc pr changes <pr-id> | grep "^diff --git"`
6. To post review comments, check CI, or manage labels, switch to `arcanum-go`

For review strategy details, read `references/review-pr.md`.

### Diff and code review
When user asks for diff, changes, or code review:
1. `arc diff -B` — merge-base diff (what PR will introduce). DEFAULT for reviews
2. `arc diff -B --stat` — quick overview with file/line counts
3. `arc diff -B --name-only` — only filenames (what changed in the branch)
4. `arc diff -B -- path/to/file` — specific file diff
5. Never `arc diff trunk` — direct diff, hangs on large divergence (>3000 commits)
6. Never range notation `arc diff trunk..HEAD` — silently gives empty output

For verified syntax table and all diff flags, read `references/review-diff.md`.

### Switch branches
When user asks to switch, checkout, or go to a branch:
1. `arc checkout <branch>` — switch to local branch
2. `arc checkout users/<login>/<TICKET>` — switch to ticket branch (lazy fetch pulls from server)
3. `arc checkout -b <name> trunk` — create new branch from trunk. `<name>` is the unprefixed local name following the `TICKET-1234-short-description` convention (e.g., `TICKET-1234-fix-login-bug`).
4. `arc branch -d <name>` — delete local branch (NEVER `arc branch <name>` without flag, it creates!)
5. `arc push -d users/<login>/<branch>` — delete remote branch
6. Never search with `arc branch -a | grep` — try direct checkout first

For branch listing, renaming, deletion, and shared branch safety, read `references/switch-branches.md`.

### Move, copy, or split tracked files
When user asks to move, rename, copy, or split tracked files:
1. Pure move/rename: use `arc mv <old> <new>` to preserve history.
   Do not offer `arc cp <old> <new>` followed by `arc rm <old>` as a rename
   fallback: that is copy/delete, not a pure tracked rename.
2. Copy/split one tracked file into several files: run `arc cp <old> <new>` for each new file first, then edit each copy down to the lines that belong there. Always `arc cp` from the original — never chain copies from an already-edited copy, that breaks the direct history link to the source.
3. Decide what happens to the original:
   - **Full split** — original is fully replaced: make `N` copies, then `arc rm <old>` after editing.
   - **Partial split** — original keeps part of its content: make `N-1` copies and trim the original down to its remaining part.
4. If the user's intent between full vs partial split is unclear from the request, ask via `AskUserQuestion` before proceeding.
5. Do not create split files with plain `cp`, editor copy-paste, or `apply_patch` Add File when line history matters.
6. Verify with `arc status --short`: split files should show `C old -> new`; a removed original should also show `D old`.

### Check state
When user asks about current status, branch, or recent history:
1. `arc info --json` field `branch` — current branch (NOT `arc branch --show-current`)
2. `arc status` — working tree status
3. `arc log -n 5` — last 5 commits (NOT `arc log -5`)
4. `arc branch -a -v` — all branches with hashes
5. `arc log trunk..HEAD` — commits on the current branch excluding trunk.
   Range notation works in `arc log`; do NOT replace it with unsupported
   git-style `arc log HEAD --not trunk`.

For arc info fields, log options, range notation, and commit details, read `references/check-state.md`.

### Rebase and sync
When user asks to rebase, sync, or update from trunk:
1. `arc pull trunk` — pull latest trunk without switching branches
2. `arc rebase trunk` — rebase current branch on trunk
3. If conflicts: resolve, `arc add <files>`, `arc rebase --continue`
4. `arc push -f` — force push after rebase (use `arc push -f -u users/<login>/<branch>` if the current branch name is already prefixed, so arc doesn't double the prefix)
5. **Shared branch safety:** before force push, `arc pull` to check for others' commits
6. If rebase went wrong: before using `arc reset --hard ORIG_HEAD`, explicitly
   warn that `--hard` permanently discards all current staged and unstaged
   changes. Check `arc status` first and preserve needed work with
   `arc stash push -m "before rebase recovery"`; then reset to restore the
   pre-rebase state.

For step-by-step rebase workflow, --onto, recovery, and shared branch safety, read `references/rebase-sync.md`.

### Stash changes
When user needs to save work temporarily:
1. `arc stash push -m "description"` — save uncommitted changes with label
2. `arc stash pop` — restore the most recent stash
3. `arc stash list` — view saved stashes

For stash apply vs pop, partial stash, and common patterns, read `references/stash-changes.md`.

### Reorganize commits
When user wants to squash, amend, or restructure commit history:
1. **Amend last commit:** `arc add <files>` + `arc commit --amend`
2. **Squash N commits:** `arc reset --soft HEAD~N` + `arc commit -m "combined message"` (works in non-interactive shell)
3. **Interactive rebase:** `arc rebase -i HEAD~N` exists but requires TTY (opens editor), suggest user runs manually
4. **Cherry-pick:** `arc cherry-pick <full-40-char-hash>` (always full hash)
5. After any history rewrite: `arc push -f` (force push required)

For commit options, reset modes, cherry-pick, and squash details, read `references/reorganize-commits.md`.

### Resolve conflicts
When rebase, cherry-pick, or merge produces conflicts:
1. `arc status` — identify conflicted files
2. Open each file, resolve `<<<<<<<` / `=======` / `>>>>>>>` markers
3. `arc add <resolved-files>` — mark as resolved
4. Continue: `arc rebase --continue` / `arc cherry-pick --continue` / `arc commit`
5. To abort: `arc <operation> --abort`
6. Auto-resolve: `arc rebase trunk -X theirs` keeps branch changes on conflict, `-X ours` keeps trunk

For per-operation continue/abort, --skip, -X strategies, and submit conflict specifics, read `references/resolve-conflicts.md`.

### Revert and undo
When user wants to undo a commit or discard file changes:
1. `arc revert <full-hash>` — create a reverse commit (safe, preserves history)
2. `arc checkout <file>` — discard uncommitted changes in a file (do NOT use `--` separator, see Gotchas)
3. `arc checkout <COMMIT> <file>` — restore file to state at a specific commit (do NOT use `--` separator)
4. `arc reset --hard ORIG_HEAD` — undo last rebase or reset operation. Before
   recommending it, explicitly warn that `--hard` permanently discards all
   current staged and unstaged changes.

For revert with conflicts, file recovery patterns, and reset modes, read `references/revert-undo.md`.

### Blame and investigate
When user asks who changed code, when something broke, or to search history:
1. `arc blame <file>` — show per-line authorship (`--json` for structured output)
2. `arc log -- <file>` — commits that touched a specific file
3. `arc log -S "string"` — find commits that added or removed a string
4. `arc log --grep "pattern"` — search commit messages

For blame flags, log filters, and history search patterns, read `references/blame-investigate.md`.

## Gotchas: arc ≠ git

Arc accepts many git-style flags without error but produces wrong or empty output. Others fail with cryptic messages. Before using an unfamiliar flag, run `arc <command> --help`. The table below lists the most common traps.

| Goal | git / gh (WRONG for arc) | arc (CORRECT) |
|------|--------------------------|---------------|
| Strip ANSI colors from PR list | `arc pr list --no-color` | `arc pr list` (no ANSI by default; `--no-color` is unsupported) |
| List only my PRs | `arc pr list --mine` | `arc pr list -o` |
| Log excluding trunk commits | `arc log HEAD --not trunk` | `arc log trunk..HEAD` |
| View PR details in terminal | `arc pr view <id>` (opens browser) | `arc pr status <id>` or `arc pr list --ticket <KEY> --json` |
| Three-dot diff | `arc diff trunk...HEAD` (silent empty output) | `arc diff -B --stat` |
| Last N commits | `arc log -5` | `arc log -n 5` |
| Custom log format | `arc log --format="%H %s"` (prints literal string) | `arc log --oneline` or `arc log --format="{commit.short} {title}"` (arc-style, experimental) |
| Get current branch name | `arc branch --show-current` | `arc info --json` field `branch` |
| Range notation in diff | `arc diff trunk..HEAD` (silent empty output) | `arc diff -B` or `arc diff trunk HEAD` (positional args) |
| Diff stat vs trunk | `arc diff --stat trunk` | Hangs when trunk diverged >3000 commits. Use `arc diff -B --stat` (stable <1s) |
| Extract file from a commit | `arc show COMMIT:path/file` with a path relative to CWD | The path after the colon is **root-relative** and works from any directory; a CWD-relative one errors — or silently prints a same-named file from the root. See Monorepo Pitfalls |
| Push from a branch named `users/<login>/...` | `arc push` (creates `users/<login>/users/<login>/...`) | Name local branch without prefix; if you are already on a prefixed branch, push it explicitly with `arc push -u users/<login>/<branch>` (add `-f` for force). See "double-prefix" in Monorepo Pitfalls |
| Checkout a ticket branch | `arc branch -a \| grep TICKET` | Directly `arc checkout users/<login>/<TICKET>`, lazy fetch will pull from server |
| Create PR without interactive editor | `arc pr create` (without -m) | Without `-m` arc opens an editor. Always use `arc pr create -m "..."` |
| Push with set-upstream | `arc push --set-upstream` (without parameter) | Breaks. Use `arc push -u <branch-name>` instead |
| Squash commits (non-interactive) | `arc rebase -i` (works but opens editor, requires TTY) | `arc reset --soft HEAD~N` + `arc commit -m "msg"` (no editor, works in scripts and CI) |
| Mixed reset to HEAD | `arc reset` (no args, expecting git-style mixed reset) | No-op in arc. Always pass explicit target AND mode: `arc reset --mixed HEAD~1`, `arc reset --soft <commit>`, `arc reset HEAD <file>` (unstage). There is no documented default mode |
| Reset branch onto far-behind trunk | `arc reset --soft trunk` (on a branch thousands of commits behind trunk) | Fails with `Reset forbidden due to change outside the scope` on sparse-mount. Use `arc reset --soft $(arc merge-base trunk HEAD)` instead |
| Separate revision from paths | `arc checkout <COMMIT> -- <file>`, `arc show <COMMIT> -- <path>` | Only `arc checkout` and `arc show` reject `--` as separator and treat it as a literal path (error: `path '--' did not match`). Always use positional args for these two: `arc checkout <COMMIT> <file>`, `arc show <COMMIT> <path>` — but note that for `arc show` the positional pair filters the commit's diff by path; file content comes from `arc show <COMMIT>:<root-relative path>`. Other commands (`arc diff`, `arc log`, `arc reset`, `arc blame`) accept `--` normally |
| Extract blob by ref | `arc cat-file blob <ref>` | No equivalent. Use `arc checkout <COMMIT> <file>` to restore into working directory, or `arc show <COMMIT>:<path from the repo root>` |

## Monorepo Pitfalls

In Arcadia you almost always work from a subdirectory, not from the repo root.

### `arc show` — the two forms resolve the path differently

**`arc show <COMMIT>:<path>` takes the path from the repository ROOT**, whatever your cwd: `arc show abc123:services/myservice/file.js` prints that file's content from anywhere. A cwd-relative path there is the trap, and it does not reliably announce itself — the lookup still happens at the root, so from `/repo/services/myservice/` `arc show abc123:file.js` either fails (arc re-reads the whole argument as a working-copy path: `error: no path 'services/myservice/abc123:file.js'`) or, when the root happens to hold a `file.js` of its own, **silently prints that other file**. Always write the path from the root.

**`arc show <COMMIT> <path>` takes the path from CWD — and never prints content.** It is `git show <commit> -- <path>`: the commit header plus that path's diff. Aim it at a commit that did not touch the path (pointing at `trunk` usually does) and only the header comes out, which reads as "the command is broken".

**Reading a file at a commit (simplest first):**
1. **`arc show <COMMIT>:<path from the repo root>`** — prints the content to stdout, from any cwd.
2. **`arc checkout <COMMIT> <path>`** — restores file into working directory (do NOT use `--` separator)
3. **`cp` before reset** — if files are in the working directory, copy to `/tmp` first

### Short hashes are ambiguous

In a monorepo with millions of objects, a 7-character SHA yields `TooManyResults: short SHA1 is ambiguous`. If a user provides a short hash, do NOT pass it to arc commands directly. Find the full hash first:

```bash
arc log --oneline | grep "^a1b2c3d"    # find full hash by prefix
# then use the full 40-character hash in subsequent commands
```

### `arc push` doubles the prefix for `users/` branches

Arc namespaces server branches under `users/<login>/` automatically. If the local branch name already contains that prefix, push (and `arc pr create --publish`, and `arc submit`) duplicates it: `users/<login>/users/<login>/TICKET`.

Fix at the root: name local branches without the prefix and with a short description (`TICKET-1234-fix-bug`, not `users/<login>/TICKET-1234`).

For a normal **unprefixed** local branch (the default, recommended case) this never happens — bare `arc push` / `arc push -f` is correct and you should **not** add `-u`. Only when you are **already on a prefixed branch** (the user names one, or `arc info --json` shows `branch` starting with `users/<login>/`) pass the name explicitly so arc doesn't re-add the namespace:

```bash
arc push -u users/<login>/<branch>                              # plain push
arc push -f -u users/<login>/<branch>                           # force push (e.g. after rebase)
arc pr create --publish --push users/<login>/<branch> -m "..."  # when creating a PR — use this flag, not a separate arc push
```

For full mechanics, read `references/push-changes.md`.

## Self-Check Rules

1. **Don't guess flags** — if a flag is borrowed from git by analogy, check `arc <command> --help` first.
2. **Checkout ticket branches directly** — don't search via `arc branch -a` and grep. Try `arc checkout users/<username>/<TICKET>` directly. Lazy fetch will pull from server.
3. **Empty output = suspicious** — in git, empty output usually means "no changes". In arc it often means "wrong syntax". If a command ran without errors but produced no output, double-check the syntax.
4. **Use `--json`** — reliable way to get data from `arc pr list`. Its output is JSONL (one JSON object per non-empty line), not one JSON array. Parse it line by line, for example with `python3 -c 'import json,sys; rows=[json.loads(line) for line in sys.stdin if line.strip()]'`.
5. **Full hashes required** — if user gives a short hash, resolve it to full 40-char via `arc log --oneline | grep` before passing to any arc command.
6. **Keep it simple** — if files are already in the working directory, use `cp` to `/tmp` instead of `arc show COMMIT:PATH`.
7. **`arc checkout` and `arc show` reject `--` as separator** — pass revision and path as positional arguments for these two. Other arc commands (`arc diff`, `arc log`, `arc reset`, `arc blame`) accept `--` in git style.
8. **`arc reset` is not git reset** — always pass both an explicit target (`HEAD`, `HEAD~N`, a commit, or `$(arc merge-base trunk HEAD)`) AND an explicit mode (`--soft` / `--mixed` / `--hard`). Bare `arc reset` is a no-op.
9. **Re-check branch-aware push syntax before answering** — an unprefixed local branch must use bare `arc push` / `arc push -f`; reject any draft answer that adds `-u <unprefixed-branch>` or invents `users/<login>/...`.
10. **File content at a revision comes from `arc show <COMMIT>:<path>` with the path written from the repo root** — it works from any directory, while a CWD-relative path after the colon either errors or silently yields a same-named root file. The space-separated `arc show <COMMIT> <path>` takes its path from CWD, filters the commit's diff by it and never prints content — do not offer it as the subdirectory workaround.
