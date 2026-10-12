---
name: tatr
description: Use when the user asks to record, find, organize, decompose, update, or close project intents, initiatives, tasks, issues, or TODOs in a tatr-managed project; when design rationale needs preserving; or when a finding deserves tracking. Also /skill:tatr.
---

# tatr

Track work and its rationale in a git-tracked `tasks/` folder. For small–medium projects,
use **Intent → Initiative → Task**: purpose, chosen undertaking, concrete work.
**A parent justifies its children; it does not merely contain them.**

Spec: https://github.com/tsoding/tatr (README).
Run from the project root. On the host, invoke every command below through
`~/dev/agents/pi-box/box tatr`; inside the box, use `tatr` directly.
Check availability inside the box first. If missing, consult the user for source,
version, and installation instructions; do not install or fall back to host tatr.
Edit task Markdown directly in the project.

## Semantics

| Kind | Question | Meaning and minimum description |
|---|---|---|
| `INTENT` | What should become or remain true, and why? | A desired condition independent of a particular solution. Record **Why** and **Desired condition**. It may be enduring or satisfiable. |
| `INITIATIVE` | What undertaking are we choosing to advance this intent? | A bounded approach that can succeed, fail, or be abandoned without invalidating its intent. Record **Why this approach** and **Done when**. |
| `TASK` | What specific work moves us forward? | An independently meaningful unit with an observable output: behavior, evidence, or a decision. State the work and **Done when**; explain its contribution when not obvious from the parent. |

These are semantic roles, not size bands. An initiative is not merely a task with children.
An intent survives a change of approach; an initiative names that approach; a task produces
something needed to carry it out. Proposed approaches remain proposals until confirmed.

The project is the implicit root, not another record. Use `Intent → Initiative → Task`,
or `Intent → Task` for work that needs no separate undertaking. Do not manufacture an
initiative for a small fix. Small execution steps are checkboxes in the owning record,
not another level. Split work only when the pieces warrant independent tracking.

Categories such as `parser`, `optimizer`, or `storage` are tags, not parents.
`bug`, `research`, `blocked`, and transient/recurring distinctions also do not create levels.
“Storage” is a category; “Preserve committed data through process crashes” is an intent.
Choose titles that express the actual purpose, approach, or work—not generic “improvements.”

A short description is enough; do not generate empty sections, arbitrary metrics, schedules,
or estimates. When the purpose is unknown, capture a task provisionally at the root with an
`Open (agent)` question about placement. Do not invent user intent to complete the hierarchy.

## Layout and parentage

```text
tasks/
  tags                 # optional: "<tag> [,] <description>" per line
  README.md            # created by `tatr init`
  <HUID>/TASK.md       # every kind uses this layout; attachments beside TASK.md
```

HUID = UTC timestamp `YYYYMMDD-HHMMSS`. The optional suffix `-[a-zA-Z0-9-]*` is for per-person IDs
in a team, not for collisions: on collision take the next free second. Never renumber a task once referenced.

Keep folders flat. `KIND` and `PARENT` below are **this skill's conventions**, using the
extra properties ignored by tatr. Read the Markdown metadata to reconstruct the tree;
do not assume native hierarchy commands or TQL filters for these properties.

- Intents have no `PARENT`. Initiatives have one intent parent. Tasks have one initiative
  or intent parent; provisional, untriaged tasks may omit it.
- A parent must exist in this project's `tasks/`. Reject missing parents, self-parenting,
  cycles, and incompatible kinds before saving. Do not silently attach work to a closed parent.
- `PARENT` is the sole structural relationship. Derive children from it; store no duplicate
  child lists, multiple parents, or dependency graph. Reference other records as evidence
  or context only. `tatr ref` finds mentions, not necessarily children.
- For cross-cutting work, choose its primary justification as parent and describe secondary
  benefits in the body. Do not duplicate the work under several intents.

## TASK.md

```markdown
# <title>

- STATUS: OPEN|CLOSED
- PRIORITY: <int>
- TAGS: <tags, comma/whitespace separated>
- KIND: INTENT|INITIATIVE|TASK
- PARENT: <HUID>

<brief description appropriate to the kind, with provenance on claims>
```

Choose one value for `STATUS` and `KIND`; omit `PARENT` where specified above.
Other properties remain allowed. No duplicate properties: if present, the last one wins.
Only two statuses exist; anything finer goes into tags. PRIORITY is a sort key only,
not an absolute rating. Default is 100. Keep attachments small and link them from TASK.md.
History lives in git (`git log`/`git blame` on TASK.md); do not add changelogs.

### Examples: language and database development

Illustrative titles, not decisions about the current project:

```text
Language project
└── INTENT: Make program behavior consistent across execution backends
    ├── INITIATIVE: Specify and align integer-overflow behavior
    │   ├── TASK: Specify overflow behavior for integer arithmetic
    │   └── TASK: Add interpreter/compiler conformance cases
    └── TASK: Fix inconsistent signed-division behavior in the interpreter

Database project
└── INTENT: Preserve committed data through process crashes
    ├── INITIATIVE: Establish a crash-tested WAL recovery path
    │   ├── TASK: Specify acknowledgement and WAL flush ordering
    │   └── TASK: Inject process crashes around WAL replay
    └── TASK: Fix recovery's handling of a truncated WAL tail
```

For the database initiative, a minimal description could be:

```markdown
- Why this approach (agent): Proposal: exercise the WAL recovery path under controlled process crashes to expose recovery failures before deployment.
- Done when (agent): The crash model and expected recovered state are specified, and the agreed crash cases pass with reproducible evidence.
- Open (agent): Does the required guarantee include power loss, or only process termination?
```

The question remains open; it is not permission to assume either guarantee.
Keep rationale and completion evidence equally concrete for compiler semantics, query
correctness, performance experiments, and rejected designs. Do not invent successful results.

## Working with the tree

1. **Recall before writing.** Run `tatr ls`; check closed records when relevant to reuse or
   reopening. Read the matching record and its ancestors before proposing changes. Search
   project memory when needed; verify hits against the source files.
2. **Classify and place.** Reuse an existing record where possible. Choose kind by meaning
   and parent by justification. Create parents only when there is a distinct purpose or
   undertaking worth recording; distinguish user decisions from agent proposals.
3. **Record just enough.** After `tatr new`, immediately replace its scaffold description,
   set kind and parent, and write the relevant rationale and completion condition.
   Capture alternatives, exclusions, assumptions, and risks when they actually matter.
4. **Update at the right scope.** Intent owns motivation and desired conditions; initiative
   owns approach, trade-offs, and scope; task owns implementation findings and verification.
   Keep each claim at its narrowest useful scope and reference it rather than copying it.
5. **Verify and report.** Check metadata and parentage for changed records, update affected
   rationale, reindex, and report the HUIDs touched. For an overview, show each record once
   with kind, HUID, title, and status; make provisional root tasks visible.

### Completion is not automatic

- Close a task when its completion condition is supported by evidence. For cancellation
  or supersession, record that outcome instead of implying successful completion.
- Closing every task does not establish that an initiative achieved its result. Evaluate
  that result separately and record evidence, shortfalls, or why the undertaking ended.
- Closing an initiative does not close its intent. Standing intents stay open even when
  no work is pending; close an intent only when satisfied or explicitly retired.
- Before closing a parent, review open descendants. Keep the parent open or deliberately
  resolve/reparent the remaining work. Never cascade closure or silently discard work.

### Existing records

Do not bulk-reorganize the project merely because this skill was loaded. Unchanged legacy
records remain valid. When editing one, inspect its meaning and set `KIND`/`PARENT` explicitly;
missing `KIND` means unclassified, not proof that the record is a leaf task.
An old `epic` representing a bounded undertaking becomes an initiative; a categorical epic
needs semantic review, not automatic relabeling as an intent. Remove the redundant `epic`
tag on converted records. Preserve HUIDs, claims, attachments, and references. Keep existing
`items.md` checklists when useful; promote an item only when it warrants its own record.

## Commands

| Goal | Command |
|-|-|
| create `tasks/` | `tatr init` |
| new record of any kind | `tatr new [-t tag ...] [-p prio] [-s suffix] Title words` |
| list open | `tatr ls [QUERY]` |
| list closed | `tatr ls -c [QUERY]` |
| sort ascending / by id | `-a` / `-id` |
| counts | `tatr summary [-c]` |
| path of a record | `tatr find <HUID> -path-only` |
| who references a record | `tatr ref <HUID>` |
| remove tags in bulk | `tatr untag -t tag QUERY` |

`tatr new` only scaffolds the file (description "No description."). Edit TASK.md immediately.
Set `KIND` and `PARENT` by editing, not invented CLI flags. To close, edit `STATUS: CLOSED`.
CLI listings and counts cover all records, including intents and initiatives; do not present
them as counts of executable tasks or as progress toward an intent.

## TQL (query for `ls`/`untag`)

```text
:bug                      tag
:bug and not :ui          boolean ops: and, or, not
[ :a or :b ] and :c       group with square brackets, never parens
not tagged / any          untagged / everything
priority lt 50            compare: lt le gt ge eq ne
20260824-215300           a single task by HUID
```

Do not use square brackets inside tag names. Keep tag vocabulary small; document new tags
in `tasks/tags`. Do not mirror `KIND` or parentage into tags.

## Tasks as project memory

Where a project keeps its record in `tasks/`, these records are the source of truth for
design work, as important as the code. `docs/` holds user-facing docs. There is no separate
memory folder.

- State current knowledge as a plain list, not quotes or transcripts:
  `- Decision (user, YYYY-MM-DD): ...`, `- Rejected (user): ...`,
  `- Open (agent): ...`, `- [fact] (agent): ...`.
- Provenance on every claim: `(user)` ruled or stated; `(agent)` finding or proposal, not
  ruled; `(user+agent)` jointly confirmed. Kind where useful: `[fact]`, `[assumption]`,
  `[direction]`. Cite code, tests, or other evidence for findings. Do not turn an agent
  proposal into a user decision or report an unchecked hypothesis as a fact.
- Never delete a claim. Supersede in place: `~~old claim~~ superseded by <ruling> (date)`.
  Append discovered details as work proceeds; preserve rejected approaches and their reasons.
- Session artifacts (notes, dialogues, drafts) go into the folder of the record the session
  followed. Longer notes are dated files there, `YYYY-MM-DD.md`.
- Docs, notes, and commits reference records by HUID; code references HUIDs instead of
  carrying loose TODOs. `tatr ref` can then locate the references.
- A project may keep a top-level `archive/` for garbage-collected artifacts: transient notes
  whose outcome now lives in a TASK.md. Same folder layout with approximate HUIDs, grouped
  by meaning, a `SUMMARY.md` per folder. Repoint references when archiving. Never index it;
  grep it last. Closed tasks remain at their stable paths in `tasks/`.

Recall and indexing use memsearch with the project's own collection, set once in `.memsearch.toml`:

```sh
box memsearch config set milvus.collection <project> --project
box memsearch index tasks/ docs/
box memsearch search "<query>" --top-k 5
```

Here `box` is `~/dev/agents/pi-box/box` on the host. Never use the shared default collection.
Treat search hits as hints and verify against code and docs. Reindex after changing tasks;
report an unavailable indexer rather than claiming indexing succeeded.

## Credits

tatr and its task format are by Alexey Kutepov (tsoding), https://github.com/tsoding/tatr, GPL-2.0.
The storage and CLI guidance is adapted from the supplied skill's README paraphrase;
the Intent → Initiative → Task convention is an addition, not an upstream tatr feature.
Do not copy tatr's code, README text, or cover art (CC BY-NC) into projects.
