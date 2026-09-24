---
name: tatr
description: Track project tasks/issues with tatr (tsoding/tatr) — a git-tracked `tasks/` folder of per-task TASK.md files, plus the `tatr` CLI. Use when the user asks to record, list, find, update or close a task/issue/TODO, or when a finding should be tracked rather than left as a loose TODO. Also /skill:tatr.
---

# tatr

Spec: https://github.com/tsoding/tatr (README).
Run from the project root. On the host, invoke every command below through
`~/dev/agents/pi-box/box tatr`; inside the box, use `tatr` directly.
Check availability inside the box first. If missing, consult the user for source,
version, and installation instructions; do not install or fall back to host tatr.
Edit task Markdown directly in the project.

## Layout

```
tasks/
  tags                 # optional: "<tag> [,] <description>" per line
  README.md            # created by `tatr init`
  <HUID>/TASK.md       # one folder per task; attachments beside TASK.md
```

HUID = UTC timestamp `YYYYMMDD-HHMMSS`, optional suffix `-[a-zA-Z0-9-]*`.
On collision wait a second and retry. Never renumber or rename a task.

## TASK.md

```markdown
# <title>

- STATUS: OPEN|CLOSED
- PRIORITY: <int>
- TAGS: <tags, comma/whitespace separated>
- <OTHER>: <value>     # extra properties allowed; the tool ignores them

<description>
```

- Only two statuses. Anything finer goes into TAGS.
- PRIORITY is a sort key only, not an absolute rating. Default is 100.
- No duplicate properties. If present, the last one wins.
- Append discovered details to the description as work proceeds.
- Keep attachments small, since they are committed. Link them from TASK.md.
- History lives in git (`git log`/`git blame` on TASK.md). Don't add changelogs.

## Commands

| Goal | Command |
|-|-|
| create `tasks/` | `tatr init` |
| new task | `tatr new [-t tag ...] [-p prio] [-s suffix] Title words` |
| list open | `tatr ls [QUERY]` |
| list closed | `tatr ls -c [QUERY]` |
| sort ascending / by id | `-a` / `-id` |
| counts | `tatr summary [-c]` |
| path of a task | `tatr find <HUID> -path-only` |
| who references a task | `tatr ref <HUID>` (greps the repo) |
| remove tags in bulk | `tatr untag -t tag QUERY` |

`tatr new` only scaffolds the file (description "No description."). Edit TASK.md right after
to write the real description. To close a task, set `STATUS: CLOSED` by editing the file.

## TQL (query for `ls`/`untag`)

```
:bug                      tag
:bug and not :ui          boolean ops: and, or, not
[ :a or :b ] and :c       group with square brackets, never parens
not tagged / any          untagged / everything
priority lt 50            compare: lt le gt ge eq ne
20260824-215300           a single task by HUID
```

Don't use square brackets inside tag names.

## Discipline

- Before creating a task, run `tatr ls` and look for an existing one to update instead.
- One task per issue. Titles should be concrete. The description says what is known and where,
  with provenance (user ruling vs agent finding).
- Reference tasks by HUID from docs/notes/commits. `tatr ref` then finds them.
- Keep tag vocabulary small. Document new tags in `tasks/tags`.
- Creating or closing a task is a repo change. Report which HUIDs you touched.

## Credits

tatr and its task format are by Alexey Kutepov (tsoding), https://github.com/tsoding/tatr, GPL-2.0.
This skill paraphrases its README. Don't copy tatr's code, README text or cover art (CC BY-NC) into projects.
