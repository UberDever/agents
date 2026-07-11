# Migration: existing knowledge & skills → S3 project layout

Run after `./install.sh project <dir>`. Goal: everything the project's agent needs
lives *in the project repo* — no dependence on your home dot-dirs. Do it manually or
AI-assisted (prompt at the end).

## What migrates where

| You have | Where it typically lives | Goes to | How |
|----------|--------------------------|---------|-----|
| Knowledge notes, dialogue logs, decision records | `dialogue/`, `notes/`, `docs/adr/`, scattered .md | `.memsearch/memory/` | `git mv`, then index |
| Project-relevant skills | `~/.claude/skills/`, `~/.codex/skills/`, `~/.agents/skills/` | `<project>/.agents/skills/` | copy dir, review |
| Generic personal skills (caveman, devvm-sync...) | same | stay global; Pi already reads `~/.agents/skills/` | nothing, or add others to `~/.pi/agent/settings.json` |
| Instructions / preferences | `AGENTS.md`, `CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`, rules dirs | project `AGENTS.md` (project-specific) / `~/.pi/agent/AGENTS.md` (personal) | merge by hand or AI |
| User logs, transcripts, session exports | anywhere | `.memsearch/memory/imported/` | copy, index |

## 1. Knowledge materials

Memory dir is the single source of truth. Move, don't copy (two copies drift):

```bash
cd <project>
git mv <notes-or-dialogue-files>.md .memsearch/memory/
# bulky raw materials (logs, transcripts) — separate subdir keeps daily notes clean:
mkdir -p .memsearch/memory/imported && cp <logs> .memsearch/memory/imported/
memsearch index .memsearch/memory/
memsearch search "<something you know is in there>" --top-k 3   # verify
```

Notes are chunked by markdown headers — dated/sectioned files search fine as-is, no
reformatting. Fix any references to old paths (grep for the old dir name).

### Lifetime and topology

Memory files are permanent, git-tracked project artifacts. Age states:

- `imported/` seeds — frozen archive: never edited, never deleted. Stale content is
  harmless: recall is hint-only, verified against code (charter rule).
- Daily notes — append-only; contradictions get supersession marks, not deletion.
- `memsearch compact` — the only sanctioned destruction: consolidates old dailies,
  you review the diff, git keeps pre-compact state.

Distribution — memory lives where its subject lives:

| Kind | Home | Access |
|------|------|--------|
| Project-specific (decisions, design history, gotchas) | `<project>/.memsearch/memory/` | default: collection derived from project dir, isolated per project |
| Cross-project durable (lessons, patterns, tooling) | commons repo (`~/dev/agents/.memsearch/memory/`) | `memsearch index <commons-dir> --collection commons`; from any project: `memsearch search "..." --collection commons` |
| Personal style / preferences | `~/.pi/agent/AGENTS.md` | not memory — standing instructions, always in context |

No copies between collections. Project note turns out generic → *move* to commons,
leave one-line pointer in the project's daily note.

## 2. Skills

Inventory, then decide per skill: project-specific → into repo; personal-generic →
stays home.

```bash
ls ~/.claude/skills ~/.codex/skills ~/.agents/skills 2>/dev/null
# project-specific ones:
cp -r ~/.claude/skills/<skill-name> <project>/.agents/skills/
```

Rules of thumb:

- Skill mentions the project's domain, stack, or infra → repo.
- Same skill in two home dirs → keep one copy in `.agents/skills/` (the neutral
  standard), delete duplicates. Pi warns on name collisions and keeps first found.
- Claude-flavored frontmatter is fine — Agent Skills standard is shared; review
  `allowed-tools`-style fields, Pi ignores unknown fields.

## 3. Instructions / preferences

- Project `AGENTS.md`: keep your existing lines, charter is appended below them.
  Merge in anything project-specific from `CLAUDE.md`, `.claude/rules/`, etc. Then
  delete the merged sources (single source of truth).
- Personal style (tone, language, generic habits): `~/.pi/agent/AGENTS.md` — loaded
  globally by Pi, stays out of the repo.

## 4. AI-assisted migration

Run `pi` in the project and paste:

```text
Migrate this project's agent knowledge to the S3 layout. Steps:
1. Inventory: list *.md knowledge/dialogue/notes files in this repo (outside
   .memsearch/), and skills in ~/.claude/skills, ~/.codex/skills, ~/.agents/skills.
2. Propose a table: file → destination (.memsearch/memory/ | .agents/skills/ |
   merge into AGENTS.md | stays global | ignore) with one-line reason each.
3. Wait for my approval. Then execute with git mv/cp, fix references to moved
   paths, merge instruction fragments into AGENTS.md without losing content.
4. Run: memsearch index .memsearch/memory/ and verify with a test search.
5. Show final git status; I commit myself.
Do not delete anything outside this repo; only copy from home dirs.
```

## Worked example: vetochka (~/dev/c/vetochka)

State before: `AGENTS.md` (2 lines), `dialogue/slop_field.md` (1489 lines, dated
sections), `dialogue/minimal-machine.md`, skills only in home dirs, `.codex/` empty,
`.claude/` local settings only.

```bash
cd ~/dev/agents/s3
./install.sh project ~/dev/c/vetochka

cd ~/dev/c/vetochka
git mv dialogue/slop_field.md dialogue/minimal-machine.md .memsearch/memory/
rmdir dialogue
# AGENTS.md: keep both original lines, fix pointer:
#   - Use the slopfield: .memsearch/memory/slop_field.md
memsearch index .memsearch/memory/
memsearch search "virtual semicolon layout" --top-k 3    # expect slop_field hits

# skills: nothing project-specific in home dirs today (caveman, devvm-sync, fpf,
# adopt-* are personal/other-project) → nothing to copy

git add -A && git commit -m "S1 -> S3: memsearch memory layout + charter + memory skill"
pi   # start working
```
