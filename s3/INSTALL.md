# S3 install: Pi + memsearch + conventions, for any project

Reproducible instruction. Human follows top to bottom → working setup, same result
every time. Stack (see `../agent_research.md` §11): **Pi** (harness, model-agnostic,
your API keys) + **memsearch** (markdown memory + local vector index) + **conventions
charter** (design-partner behavior, plain files).

Pinned versions — bump deliberately, in `install.sh`, together:

| Component | Version | Why pinned |
|-----------|---------|------------|
| Pi (`@earendil-works/pi-coding-agent`) | 0.80.6 | young project, breaking changes land |
| memsearch (PyPI, git tag `v0.4.13`) | 0.4.13 | young project |
| Node.js >= 20, Python >= 3.10, `uv`, `git` | prereqs | — |

Network needed: install time only (npm, PyPI, one-time ONNX embedding model from
HuggingFace) + LLM API calls during work. Embeddings local (CPU, no key). All durable
state = markdown in git. Vector index = disposable cache (`~/.memsearch/milvus.db`).

## Part A — once per machine

```bash
cd ~/dev/agents/s3
./install.sh machine
```

Manual equivalent:

1. `npm install -g --ignore-scripts @earendil-works/pi-coding-agent@0.80.6`
2. `uv tool install --force "memsearch[onnx]==0.4.13"`
3. Pre-cache embedding model:
   `memsearch search warmup --collection warmup --provider onnx || true`

### Model access (pick one, or several)

- **OpenAI key (your default):** `export OPENAI_API_KEY=sk-...` in shell profile.
  In Pi: `/model` → pick GPT model. Done.
- **Other clouds:** `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `OPENROUTER_API_KEY` etc. —
  Pi picks them up the same way.
- **Local model (Ollama or any OpenAI-compatible endpoint):** create
  `~/.pi/agent/models.json`:

  ```json
  {
    "providers": {
      "local": {
        "baseUrl": "http://localhost:11434/v1",
        "api": "openai-completions",
        "apiKey": "none",
        "models": [{ "id": "qwen3-coder", "name": "qwen3-coder (local)" }]
      }
    }
  }
  ```

Optional, better recall quality (uses your OpenAI key for memory embeddings too):
`memsearch config set embedding.provider openai` — after this, indexing/search need
network. Default ONNX needs none.

## Part B — once per project

```bash
cd ~/dev/agents/s3
./install.sh project /path/to/project
```

What it does — manual equivalent:

1. `mkdir -p <project>/.memsearch/memory` — memory home. **Commit it.**
2. Appends `templates/AGENTS-charter.md` to `<project>/AGENTS.md` (creates if absent;
   idempotent — skips if marker present).
3. Copies `templates/skills/memory/` → `<project>/.agents/skills/memory/` — the memory
   discipline skill (recall at task start, distill at task end). `.agents/skills/` is
   the Agent Skills standard location: Pi, Codex, Claude Code (via symlink/settings)
   all read it.
4. Runs `memsearch index <project>/.memsearch/memory/` if seed files exist.

If the project already has knowledge materials (logs, notes, dialogue files, skills in
dot-dirs) — do `MIGRATION.md` next. For a fresh project, you are done:

```bash
cd /path/to/project && pi
```

First session sanity check: ask "what do you know about this project's design
history?" — agent should use the memory skill (`memsearch search ...`) and answer from
seeds, or say memory is empty.

## Part C — verify (using vetochka as example)

```bash
cd ~/dev/c/vetochka
memsearch search "virtual semicolon layout" --top-k 3   # expect slop_field hits
pi
# in session: discuss something small, then: /skill:memory distill
# exit, then:
cat .memsearch/memory/$(date +%F).md                    # note captured
```

## Part D — daily use

- Just `pi` in the project. Charter (AGENTS.md) makes it design-first; memory skill
  makes it recall/distill. `/skill:memory` forces recall explicitly when the model
  forgets to.
- Memory files are yours: edit/prune in any editor, then
  `memsearch index .memsearch/memory/`. Commit with the code they explain.
- Monthly (or when recall gets noisy): `memsearch compact` — LLM-consolidates old
  notes. Review diff, commit.
- Index broken? `rm ~/.memsearch/milvus.db && memsearch index .memsearch/memory/`.
  Nothing lost — data was never in the index.

## Upgrade path (documented, not installed)

Auto-capture without asking (true SEMIAUTO): Pi extension on `agent_end` appending
turn summaries to the daily file. ~100 lines TS in `.pi/extensions/`. Deferred:
skill-based discipline first; add the extension when manual `distill` becomes the
bottleneck. See research doc §10.3/P5.

## Uninstall

```bash
npm uninstall -g @earendil-works/pi-coding-agent
uv tool uninstall memsearch
rm -rf ~/.memsearch          # index cache only
# .memsearch/memory/ in projects: keep — it is your knowledge, plain markdown
```
