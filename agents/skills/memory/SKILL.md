---
name: memory
description: Recall and distill persistent project memory stored in .memsearch/memory/ (dated markdown, semantically indexed). Use at the start of design discussions, when past decisions/rationale/debugging history might be relevant, when the user references earlier work, or at the end of a substantive session to record decisions. Also triggered by /skill:memory [recall QUERY | distill].
---

# Project memory

Memory = dated markdown files in `.memsearch/memory/` (source of truth; git-tracked unless project instructions keep it external).
`memsearch` CLI provides hybrid semantic+keyword search over them. The vector index is
a disposable cache — never treat it as the data.

## Project scope and setup

Use a separate collection per project, selected by `.memsearch.toml` in the
project root. Keep embedding and database settings shared in global config.
Preserve an existing project collection; for a new one, choose a stable, unique
name using letters, digits, and underscores, starting with a letter or underscore
(e.g. `vetochka`). Do not use the shared default collection for project memory.

The memory root is normally the repository root, with notes in
`.memsearch/memory/`. If user/project instructions specify an external artifact
root (such as ClickHouse), keep both notes and `.memsearch.toml` there instead;
follow its collection naming rule and do not add external memory to the PR.
Always run configuration, indexing, search, expansion, and stats from this same
memory root, including after a branch switch.

Run MemSearch where it is installed. In Pi's container, use `memsearch` directly;
from this setup's host, use `~/dev/agents/pi-box/box memsearch` instead of the host
executable. Change to the memory root before invoking `box`: it bind-mounts its
caller's working directory. Read and append Markdown directly in that root.

Before any index/search, check that the selected root's `.memsearch.toml` sets
`milvus.collection`; initialize it if absent, preserving other settings. If the
boxed tool is missing, consult the user for installation instructions.

Once per project, from the host (replace path and collection name):

```bash
cd ~/dev/vetochka
mkdir -p .memsearch/memory
~/dev/agents/pi-box/box memsearch config set milvus.collection vetochka --project
~/dev/agents/pi-box/box memsearch config get milvus.collection
```

This writes the project override, preserving shared model/database settings:

```toml
[milvus]
collection = "vetochka"
```

Then, from that same root:

```bash
~/dev/agents/pi-box/box memsearch index .memsearch/memory/
~/dev/agents/pi-box/box memsearch search "what did we decide about retries?" --top-k 5
~/dev/agents/pi-box/box memsearch stats
```

Changing the collection does not move existing indexed memories. Reindex that
project's Markdown into its selected collection; leave old/shared collections
intact. Explicit `--collection` overrides project config: omit it for normal
project operations and remove any hardcoded shared collection from those commands.
Do not fall back to a shared/default or commons collection. Cross-project lessons
stay in the project where they were recorded unless the user explicitly relocates
them; label their scope in the note.

Configuration reference: https://zilliztech.github.io/memsearch/home/configuration/

## Project-specific roots

- Ordinary projects: repository root, `.memsearch.toml`, and `.memsearch/memory/`.
  Use a unique project collection; keep embedding/database settings global.
- ClickHouse: follow the shared AGENTS.md checkout-to-artifact-directory mapping.
  Both config and notes live under that external root; collection uses its
  `clickhouse_` naming rule. Branch switches do not change this root.
- This agents repository: repository root and collection `agents`. These are
  this project's notes, not an automatic commons fallback for other projects.

## Recall

Use the box prefix for these command forms when running from the host.

1. Search: `memsearch search "<query>" --top-k 5` from the selected memory root.
2. Need full context of a hit: `memsearch expand <chunk_hash>` from the same root.
3. Nothing relevant → say so and continue; do not invent memories or search other
   collections automatically. If Markdown exists but the cache is empty, index it.
4. Treat results as hints. Verify remembered claims against the current code/docs
   before relying on them — memory goes stale.

## Distill (end of substantive session, or on request)

1. Append to `.memsearch/memory/YYYY-MM-DD.md` (today's date; create if missing) a
   section:

   ```markdown
   ## <topic> (HH:MM)
   - Decision (user): <what was decided and why>
   - Rejected (user+agent): <alternatives and why not>
   - Open: <questions left unresolved>
   ```

2. Mark provenance on every claim, as in the `dialogue` skill: `(user)` — the
   user ruled or stated it; `(agent)` — assistant finding or proposal, not yet
   ruled; `(user+agent)` — jointly developed and confirmed. Where it sharpens a
   claim, also tag its kind: `[fact]`, `[assumption]`, `[preference]`,
   `[direction]` (stated as a lean, not a hard ruling).
3. Only durable knowledge: decisions, rationale, constraints discovered, gotchas.
   No play-by-play, no code listings (reference files/commits instead).
4. Contradicts an earlier entry? Do not delete old one; mark it
   `~~superseded~~ by <today's entry>` in place.
5. Re-index: `memsearch index .memsearch/memory/`.
6. For repository-local memory, remind the user to commit the memory file and
   project config with related changes. Keep external memory/config out of the PR.
