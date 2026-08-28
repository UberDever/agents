# Create & Update PR Reference

## Create PR (streamlined)

```bash
arc checkout trunk
# make changes
arc submit -m "PR title and description"
```

`arc submit` = create branch + commit + push + create PR in one command.

## Create PR (step by step)

```bash
arc checkout -b TICKET-1234 trunk        # local name without users/<login>/ prefix
# make changes
arc add <specific-files>
arc commit -m "commit message"
arc pr create --publish --no-commits -F /tmp/TICKET-1234-pr.md
```

`arc pr create --publish` pushes the branch automatically as `users/<login>/TICKET-1234` and publishes the review iteration. No separate `arc push` is needed. The default `--push` behavior only uploads the branch; it is not a substitute for `--publish` when the user explicitly asks to send the PR for review.

For the double-prefix trap when local branch is already prefixed, see `push-changes.md`. Quick fallback: `arc pr create --publish --no-commits --push users/<login>/TICKET-1234 -m "..."`.

## Update an existing PR

Push new commits. The PR updates automatically.
```bash
arc add <specific-files>
arc commit -m "update"
arc push
# or: arc push --publish   # push + auto-publish iteration
# or: arc submit
```

## PR flags

| Flag | Command | Effect |
|------|---------|--------|
| `--publish` | `arc pr create`, `arc submit` | Publish review iteration immediately (default: `upload`) |
| `--publish=ci-success` | `arc pr create`, `arc submit` | Auto-publish iteration only after CI passes |
| `-m "message"` | both | PR message for `arc pr create` (first line becomes the title); commit message for `arc submit`. **Always pass `-m` or `-F`** to avoid an interactive editor when creating a PR |
| `-F <file>` | both | Read the message from a file. Prefer this for a multiline PR title and description |
| `--no-commits` | `arc pr create` only | Do not append commit messages to the PR description. **Unsupported by `arc submit`** |
| `--merge` | `arc pr create`, `arc submit` | Auto-merge after all checks pass |
| `--auto` | `arc pr create`, `arc submit` | Equivalent to `--merge --publish --no-code-review` |
| `--to <branch>` | `arc pr create`, `arc submit` | Target branch (default: trunk) |
| `--stack` | `arc submit` | Create stacked PR (depends on current branch's PR) |
| `--new` | `arc submit` | Force create new PR instead of updating current |
| `-r USER` | both | Add reviewer (can be used multiple times) |
| `--label LABEL` | both | Add label (can be used multiple times) |

### PR message title contract (`-m` and `-F`)

**The first line is the PR title, and only the title.** This applies to both inline `-m` and file-based `-F`. arc splits the message the way it splits a commit message: the first line becomes the PR `summary`, everything after the blank line becomes the `description`. The two fields are **disjoint** — the first line does not also appear in the body. Write the body as standalone prose, not as a continuation of the title sentence.

**The title is silently truncated at roughly 300 characters.** Arcanum cuts it mid-word, with no warning and no error, and `arc pr create` still prints a PR URL and reports success. Measured on `arc pr create --no-commits -m`: a 287-character first line was stored intact, while a 310-character one came back as 299 characters with its last two words gone. Keep the first line a short human-readable title (~100 characters) and move the explanation into the body. The usual way this goes wrong is a multi-sentence first line: the whole paragraph lands in the title, and the PR then reads as an unreadably long "description" that stops mid-phrase.

Verify after creating rather than trusting the URL — `arc pr status <pr-id> --json` returns `summary` and `description` as separate fields, so their contents and lengths show at once whether the split and the title survived:

```bash
arc pr status <pr-id> --json | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['summary']), repr(d['summary'])); print(len(d['description']))"
```

**Commit messages auto-appended → duplicated-looking description.** By default `arc pr create` appends the branch commit message(s) to the PR description — for a single-commit branch this is the full message body (title, paragraphs, even the `Co-Authored-By` trailer), not just the subject line. So if your `-m` already restates what the commit message says, the PR description ends up with the same explanation twice. When you provide a hand-written description, **always pass `--no-commits`** to keep the description exactly as written:

```bash
arc pr create --publish --no-commits -F /tmp/TICKET-1234-pr.md
```

Do not copy `--no-commits` to `arc submit`: that flag is unsupported there, and `submit -m` supplies the message of the new commit rather than a separately curated PR description. If the exact PR text matters and the intended changes are already committed, use `arc pr create` as shown above.

If a PR already has a duplicated description, or a title that overflowed into the ~300-character cut, fix it without recreating the PR. `arc pr` has no edit mode — its modes are `create`, `merge`, `publish`, `discard`, `status`, `changes`, `checkout`, `history`, `list`, `view`, `select` — so this goes through the Arcanum CLI (the `arcanum-go` skill), where the two fields are set separately and the id is passed through `--id`:

```bash
ya tool arcanum pr update-summary --id <pr-id> --summary "Short human-readable title"
ya tool arcanum pr update-description --id <pr-id> --description "Curated body text"
```

## PR to release branch

When targeting a branch other than trunk:
```bash
arc pr create --publish --no-commits --to releases/2024.1 -m "Cherry-pick fix for release"
```

## Stacked PRs

For dependent changes split across multiple PRs:
```bash
# On first feature branch, PR already exists
arc checkout -b second-feature
# make changes
arc submit --stack -m "Part 2: depends on first-feature"
```

## Close/discard a PR

```bash
arc pr discard <pr-id>
```

Closes the PR without merging.

## Find PR for current branch

```bash
arc pr list                            # shows PRs related to current branch
arc pr status --branch <branch-name>   # PR info for a specific branch
```

## Post-creation: labels, CI, deploy

After creation, use the `arcanum` skill for labels, CI checks, and deploy-testing.
