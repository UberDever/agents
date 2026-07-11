# Agentic development for personal projects: portable design-partner survey

Date: 2026-07-11. Sources: web survey, links inline. Status: comparative overview, no
final pick.

## 1. Problem restatement

Wanted: portable **project interlocutor for design decisions**, not an autocomplete and
not an execution-first coding agent.

Criteria (short codes used in tables below):

| Code | Criterion |
|------|-----------|
| THINK | Thinking quality over speed/execution |
| INIT  | Takes initiative, asks substantive questions, spots contradictions |
| DUAL  | Can be co-author or opponent, situationally |
| NOCODE1ST | Does not jump to code; explores solution space and trade-offs first |
| MEM   | Persistent codebase + project context across sessions |
| SEMIAUTO | Memory updates semi-automatically, no big manual memory bank |
| OFFLOAD | Can unload long context, preserve design rationale |
| ACT   | Can either propose or apply changes |
| PORT  | Not tied to one IDE / model / cloud / vendor; memory and instructions portable |
| MODES | Cloud, local, hybrid all acceptable |
| LOWOPS | No registration walls, no heavy self-hosting |
| NOAUTO | Autonomous background operation not needed (non-requirement) |

## 2. Key structural insight: three separable layers

The market does not sell the wanted thing as one product. It decomposes into three
layers, each independently swappable — and portability is maximized by keeping them
separate:

1. **Harness** — the CLI/IDE agent loop (OpenCode, Claude Code, Cline, Letta Code, Pi,
   Goose, Codex CLI...). Commodity in 2026; most support MCP and plan-style modes.
2. **Memory substrate** — where cross-session knowledge lives. Ranges from plain
   markdown-in-repo (AGENTS.md/CLAUDE.md, this repo's `dialogue/slop_field.md` pattern)
   through auto-memory files to MCP memory servers (agentmemory, Cognee, mem0, Zep) and
   platform-managed stores (Letta).
3. **Interaction conventions** — the "be an opponent, don't code first" behavior. This
   is *not* a product feature anywhere; it is prompting: custom modes/rules files,
   architect/plan modes, skills. Portable if kept as plain files in repo.

Consequence: THINK/INIT/DUAL/NOCODE1ST come mostly from **model choice + conventions
layer**, not from harness choice. Harness choice determines PORT/LOWOPS/ACT. Memory
substrate choice determines MEM/SEMIAUTO/OFFLOAD.

## 3. Layer 1: harnesses

### Model-agnostic, open source

| Tool | Notes | Fit |
|------|-------|-----|
| **OpenCode** (MIT, ~180k★) | De facto OSS default; 75+ providers incl. local Ollama, mid-session provider switch; Plan/Build dual-agent split; terminal-native. Memory = static AGENTS.md-style files, no native auto-memory. [pinggy](https://pinggy.io/blog/best_open_source_cli_coding_agents/), [dev.to](https://dev.to/moksh/top-open-source-coding-agents-to-replace-claude-code-in-2026-10f7) | PORT excellent, LOWOPS excellent, SEMIAUTO absent natively — needs layer-2 add-on |
| **Cline** (CLI + VS Code/JetBrains/Zed, ~62k★) | Plan Mode explicitly asks clarifying questions before touching code; Ask Mode explores without editing; 30+ providers + local. Closest built-in match to NOCODE1ST. [pinggy](https://pinggy.io/blog/top_cli_based_ai_coding_agents/) | NOCODE1ST good, PORT good; memory still file/rules based |
| **Letta Code** (Apache-2.0, ~2.8k★) | Memory-first: persistent agent identity, memory blocks, `/init` deep-researches codebase and rewrites own memory, `/remember` for explicit reflection, skill learning; #1 model-agnostic OSS harness on Terminal-Bench. Caveats: young project; agent state lives in Letta server/API — login/account required, operational layer to run locally. [letta.com](https://www.letta.com/blog/letta-code/), [evermx](https://evermx.com/open-source/letta-code-memory-first-coding-agent), [agentmarketcap](https://agentmarketcap.ai/blog/2026/04/10/letta-code-memory-first-coding-agent-terminal-bench) | MEM/SEMIAUTO best-in-class by design; LOWOPS weak (account or self-hosted server); PORT: model-agnostic yes, but memory format is Letta-shaped |
| **Pi** (MIT, ~68k★) | Minimal harness (system prompt <1k tokens), lazy skills, readable base, unified LLM API. Good substrate for building own conventions; nothing built in for memory. [pinggy](https://pinggy.io/blog/top_cli_based_ai_coding_agents/) | Maximum transparency/hackability; everything else DIY |
| **Goose** (Apache-2.0, Linux Foundation) | Foundation-governed neutrality, MCP-extensible, model-agnostic, CLI + desktop GUI. [datalakehousehub](https://datalakehousehub.com/blog/agentic-coding-tools/) | PORT good, governance-stable; memory via MCP add-ons |
| **Aider** | Git-native pioneer; repo activity stalled since May 2026. [morphllm](https://www.morphllm.com/ai-coding-agent) | Avoid for a long-horizon companion |

### Vendor-native

| Tool | Notes | Fit |
|------|-------|-----|
| **Claude Code** | Closed source, Claude-only. But richest native memory story: CLAUDE.md (explicit, human-authored) + auto memory (agent writes learned facts back itself, ~200-line/25KB budget loaded per session) + subagent memory + skills/hooks. Reads AGENTS.md via import. Plan mode for NOCODE1ST. [docs](https://code.claude.com/docs/en/memory), [orchestrator.dev](https://orchestrator.dev/blog/2026-04-06--claude-code-agent-memory-2026/), [mindstudio](https://www.mindstudio.ai/blog/what-is-claude-code-auto-memory) | SEMIAUTO best among vendor tools; PORT fails (model lock, closed) — mitigated by memory living in plain markdown files that other agents can read |
| **Codex CLI** (Apache-2.0) | OpenAI-centric; open source but natural gravity to GPT models. | PORT middling |
| Gemini CLI | Shut down June 2026, replaced by closed-source Antigravity CLI — case study in vendor-CLI product risk. [pinggy](https://pinggy.io/blog/top_cli_based_ai_coding_agents/) | Cautionary tale for PORT |

## 4. Layer 2: memory substrates

| Approach | Examples | SEMIAUTO | PORT | LOWOPS |
|----------|----------|----------|------|--------|
| Plain files in repo | AGENTS.md, CLAUDE.md, slop-field/decision-log pattern (already in use here) | Manual or agent-assisted; goes stale, ~200-line practical cap per session load [aibuilderclub](https://www.aibuilderclub.com/blog/ai-coding-agent-memory-agentmemory) | Perfect: git, any agent, any editor | Perfect |
| Vendor auto-memory | Claude Code auto memory / MEMORY.md | High: agent writes back learned facts itself | Files readable elsewhere, but capture loop is Claude-only | Good |
| Local MCP memory server | **agentmemory** (MIT, local-first SQLite, local embeddings, auto-capture hooks for Claude Code + Codex, MCP for the rest; 95.2% R@5 LongMemEval vs mem0 68.5%, ~$10/yr) [github](https://github.com/rohitg00/agentmemory), [dev.to](https://dev.to/andrew-ooo/agentmemory-review-persistent-memory-for-ai-coding-agents-55g2); **Cognee** (pip install + API key, graph-native, MCP) [cognee](https://www.cognee.ai/blog/guides/building-an-ai-agent-best-persistent-memory-layer) | High: hooks capture observations automatically | Good: MCP works across harnesses; one store shared by several agents | Good: no external infra |
| Markdown + vector cache | **memsearch**: dated markdown files are source of truth, vector index is rebuildable cache; auto-summarize each session, background "dream" cleanup consolidates and de-stales notes [milvus](https://milvus.io/blog/claude-code-memory-memsearch.md) | High | Very good: data = plain files, index disposable | Good |
| Hosted memory platforms | Letta server, mem0 cloud, Zep | High | Weaker: state lives in platform | Registration/infra — conflicts with LOWOPS |

Notable pattern from the field: treat memory as hint, not fact — verify against real
code before acting on remembered claims. [milvus](https://milvus.io/blog/claude-code-memory-memsearch.md)

## 5. Layer 3: interaction conventions (THINK / INIT / DUAL / NOCODE1ST)

No product ships "design opponent" as a feature. Practice from architecture-AI writing:

- Treat the model as a senior-architect collaborator; feed a context pack (requirements,
  constraints, recent decision records) and demand 2–3 candidate designs with explicit
  trade-offs. [metacto](https://www.metacto.com/blogs/leveraging-ai-for-system-design-and-architecture-decisions)
- Semi-automated collection of decision records/notes into AI-friendly form is the
  highest-leverage habit; AI amplifies the maturity of the process it is given.
  [handsonarchitects](https://handsonarchitects.com/blog/2026/ai-toolset-for-software-architect-2026q1/)
- Mechanically: custom modes (architect/ask/plan), rules files, and skills — all plain
  text, all portable between harnesses that read AGENTS.md-family files.

This layer is where the "continues the project with me" behavior actually gets built:
a standing instruction set (challenge assumptions, list alternatives before code, ask
before implementing) + a decision log the agent both reads and appends to.

## 6. Criteria matrix (condensed)

Legend: ++ strong, + ok, ~ partial/DIY, − weak.

| Candidate stack | THINK* | INIT/DUAL/NOCODE1ST | MEM | SEMIAUTO | OFFLOAD | ACT | PORT | LOWOPS |
|---|---|---|---|---|---|---|---|---|
| Claude Code alone | ++ | + (plan mode + rules) | + | ++ | + (compaction, subagents) | ++ | − | + |
| OpenCode + files only | ++* | ~ (DIY modes) | ~ | − | ~ | ++ | ++ | ++ |
| OpenCode/Cline + agentmemory (MCP) | ++* | ~ | ++ | ++ | + | ++ | ++ | + |
| Letta Code | ++* | ~ | ++ | ++ | ++ | ++ | + (model-agnostic, memory Letta-shaped) | − |
| Cline (plan/ask modes) + memsearch-style files | ++* | + | + | + | + | ++ | ++ | + |
| Pi + fully DIY conventions/memory | ++* | ~ | ~ | ~ | ~ | + | ++ | ++ |

\* THINK is model-determined; every model-agnostic harness can run the strongest
current reasoning model, so they tie — the difference is whether the harness *allows*
picking it (vendor CLIs don't).

## 7. Tensions and risks

- **SEMIAUTO vs PORT is the central trade-off.** The best automatic memory loops today
  are either vendor-locked (Claude auto memory) or platform-shaped (Letta). The most
  portable memory (markdown in git) is the least automatic. MCP memory servers and
  markdown+cache hybrids (agentmemory, memsearch pattern) sit in the middle and are the
  main candidates for "both".
- **Vendor CLI product risk is real**: Gemini CLI shutdown mid-2026 stranded workflows.
  Keeping conventions + memory in repo files caps the damage of any harness dying.
- **Memory staleness** is the recurring operational cost of every SEMIAUTO system:
  contradictory or outdated notes need consolidation (Letta reflection, "dream"-style
  cleanup, or periodic manual pruning). Some maintenance is unavoidable; the question is
  minutes/month vs hours/month.
- **Young projects**: Letta Code (~2.8k★) and agentmemory (fast-rising but months old)
  carry survival risk; their plain-file/SQLite exports matter more than their features.
- **Dialogue quality is portable already**: since it lives in model + instructions, an
  interlocutor built as rules/modes/decision-log moves across harnesses nearly free.

## 8. Shortlist for hands-on trial (not a recommendation)

1. **OpenCode or Cline + agentmemory MCP + a repo "design dialogue" mode** — maximum
   portability, semi-auto memory, no accounts; conventions layer must be authored once.
2. **Letta Code** — the only tool whose *thesis* matches the request (persistent agent
   that learns the project); test whether the account/server dependency and Letta-shaped
   memory are acceptable.
3. **Claude Code as reference point** — best-integrated auto memory today; measures what
   the portable stacks must match; its markdown memory remains readable if later
   abandoned.

Sensible experiment order: author the conventions layer first (it is needed in all three
stacks and is the actual product being sought), then A/B the memory substrates under it.

---

# Part II: Pi-centered stack under a new axis — porosity, openness, sustainability

Direction chosen after Part I: **Pi as harness + a memory substrate + custom prompting
(conventions), with model fine-tuning as an extreme escalation.** This part re-evaluates
options in each layer against three new optimization targets and analyzes the
combinations.

## 9. New criteria

| Code | Criterion | Meaning |
|------|-----------|---------|
| POROUS | Porosity | System boundaries are permeable: every piece of state (memory, conventions, session history, prompts) can be read, edited, imported and exported by a human, by git, and by *other* tools. No sealed stores, no opaque loops. |
| OPEN | Openness | Open source harness, open formats, open-weight models *possible* (not mandatory); no accounts, no proprietary capture of the workflow. |
| SUSTAIN | Sustainability | Survives on a years horizon: low maintenance burden, no vendor-death exposure, graceful degradation (if any component dies, the rest keeps working), knowledge compounds instead of rotting. |

Relation to Part I codes: POROUS ≈ PORT sharpened (not just "movable" but "inspectable
and editable in place"); OPEN ⊃ LOWOPS; SUSTAIN combines vendor-risk + staleness-cost
from §7.

## 10. Options per layer

### 10.1 Layer 1: harness = Pi (assessment, not re-selection)

Pi's design is unusually aligned with all three targets:

- **POROUS**: sessions are stored as trees in a single plain JSONL file, navigable via
  `/tree`, exportable to HTML; full history survives compaction (compaction is lossy in
  context, not on disk). AGENTS.md loaded from `~/.pi/agent/`, parent dirs, and cwd;
  SYSTEM.md replaces or appends the default system prompt per-project. Extensions can
  *fully replace* the system prompt at `before_agent_start` (not just append), override
  built-in tools, customize compaction (topic-based, code-aware, different summarizer
  model), and persist state via `pi.appendEntry()`. Nothing is sealed. [pi.dev](https://pi.dev/),
  [extensions.md](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/extensions.md),
  [issue #575](https://github.com/badlogic/pi-mono/issues/575)
- **OPEN**: MIT; providers include Anthropic/OpenAI/Google/Groq/OpenRouter/**Ollama**
  and custom providers via `models.json` or extensions — open-weight local models are a
  first-class path. No account for the harness itself. [pi.dev](https://pi.dev/)
- **SUSTAIN**: minimal core (system prompt <1k tokens) means less surface to rot;
  features live in *your* extensions/skills/packages (shareable via npm or git), so the
  workflow is versioned in repo, not in a product roadmap. Risks: effectively a
  single-maintainer project; extension API still moving (breaking changes do land, e.g.
  the #575 prompt-replacement change). Mitigation: everything you build on it is plain
  TS + markdown; worst case it is readable and portable to another harness.
- **Gap to carry forward**: Pi has no native MCP client and no built-in memory —
  both are deliberately delegated to extensions ("build an extension that adds MCP
  support"). [pi.dev](https://pi.dev/)

Fallback harness if Pi dies: OpenCode (same file conventions: AGENTS.md, skills,
markdown memory all reusable). This fallback existing *is* the sustainability argument
for keeping layers 2–3 harness-agnostic.

### 10.2 Layer 2: memory substrate options

| # | Option | Mechanism on Pi | POROUS | OPEN | SUSTAIN | SEMIAUTO |
|---|--------|-----------------|--------|------|---------|----------|
| M1 | **Plain markdown in repo** (decision log, slop-field, AGENTS.md) | Native: context files auto-loaded | ++ (git, any editor, any agent) | ++ | + (manual pruning; goes stale; ~200-line load budget) | − manual |
| M2 | **Pi-native write-back extension** (custom): hooks on `agent_end` / `session_before_compact` distill session into dated markdown notes in repo | ~100–300 lines of TS; custom compaction summary doubles as memory write | ++ (output is M1 files) | ++ | + (you own the code; small enough to maintain; Pi API churn is the risk) | ++ auto-capture |
| M3 | **memsearch pattern**: markdown = source of truth, vector index = rebuildable cache, periodic "dream" consolidation [milvus](https://milvus.io/blog/claude-code-memory-memsearch.md) | M2 extension + local embedding index; retrieval as a registered tool | ++ (index is disposable, data is files) | ++ (local embeddings possible) | + (consolidation job = the maintenance cost) | ++ |
| M4 | **agentmemory / Cognee via MCP bridge** | Needs an MCP-client extension first (not native) | + (SQLite local, exportable, but store is tool-shaped, not human-prose) | ++ (MIT, local-first) | ~ (young project survival risk ×2: agentmemory *and* the MCP bridge) | ++ |
| M5 | **Hosted platforms** (Letta server, mem0 cloud, Zep) | API extension | − (state in platform) | − (accounts) | − (vendor risk) | ++ |

Reading: M5 eliminated by all three new criteria. M4 only pays off if the same memory
must be shared with *other* harnesses simultaneously. M1→M2→M3 is a single upgrade
path, not three rival products: start with files, add the write-back hook, add the
search index only when grep over markdown stops scaling. Data format never changes
across the path — that is maximum porosity and the cheapest possible migration story.

### 10.3 Layer 3: custom prompting / conventions options

All options are plain text in repo; they differ in *where they bind* and how dynamic
they are:

| # | Option | Binding | Notes |
|---|--------|---------|-------|
| P1 | **AGENTS.md** (project + `~/.pi/agent/` global) | Any harness that reads the AGENTS.md family | The portable core: design-opponent charter — challenge assumptions, enumerate 2–3 alternatives with trade-offs, ask before implementing, read/append decision log |
| P2 | **SYSTEM.md replacement** | Pi-specific | Replace the "expert coding assistant" identity wholesale with a design-partner identity; strongest lever for NOCODE1ST since the code-first framing never enters context [pi.dev](https://pi.dev/) |
| P3 | **Prompt templates / presets** | Pi-specific, trivially rewritable elsewhere | Named modes: `/design` (opponent, no edit tools active), `/build` (executor); presets can bundle model + thinking level + tools + instructions per mode |
| P4 | **Skills** | Pi + most modern harnesses | Lazy-loaded procedures: "run a design review", "write an ADR", "consolidate memory" |
| P5 | **Dynamic injection extension** | Pi-specific | `before_agent_start` injects current decision-log summary + open questions each turn; this is where layers 2 and 3 meet |

Assessment: P1+P4 are harness-portable (SUSTAIN ++); P2/P3/P5 are Pi-shaped but
degrade gracefully — their *content* is text that pastes into any other harness's rules
mechanism in minutes. Keep the words in P1-style files and let P2/P3/P5 be thin loaders
of those files: then even the Pi-specific parts are porous.

### 10.4 Layer 4 (extreme): model fine-tuning

What it would be: LoRA/QLoRA adapter on an open-weight model (Qwen3-Coder-class for
coding, 7–8B feasible on one consumer GPU, ~500–2,000 hand-curated examples for a
style/behavior tune) to bake the design-opponent persona into weights instead of
prompt. [codersera](https://codersera.com/blog/fine-tuning-llms-complete-guide-2026/),
[n1n](https://explore.n1n.ai/blog/fine-tune-llm-lora-qlora-guide-2026-2026-04-17)

Honest assessment against this project:

- **Valid use case exists**: behavior/style consistency is exactly what the field says
  fine-tuning is *for* when prompts hit a ceiling ("tune the interface, retrieve the
  content"). [bigdataboutique](https://bigdataboutique.com/blog/fine-tuning-llms-when-rag-isnt-enough)
- **But every guide's first rule applies**: don't fine-tune until prompt engineering
  has stopped paying off — and the conventions layer here is untested, so the ceiling
  is unproven. Fine-tuning for *knowledge* (project memory) is explicitly wrong: it
  teaches the model to sound like it knows, not to know. Memory stays in layer 2.
  [aidevdayindia](https://aidevdayindia.org/blogs/fine-tuning-llms-lora-qlora/fine-tuning-llms-lora-qlora.html)
- **SUSTAIN cost is the killer**: adapter locks to one base checkpoint; base models are
  obsoleted in months; real cost is data curation + eval harness + lifecycle ownership,
  not GPU hours. [bigdataboutique](https://bigdataboutique.com/blog/fine-tuning-llms-when-rag-isnt-enough)
- **OPEN paradox**: fine-tuning forces open weights (good) but ties THINK to a 7–70B
  local model — a large quality drop vs frontier reasoning models for exactly the
  criterion (THINK) ranked first in Part I.
- **One asset is free to accumulate now**: Pi session JSONL files *are* future training
  data. Curating good design-dialogue sessions costs nothing today and keeps the
  fine-tune option open without committing to it.

Verdict: keep as documented escape hatch, not a plan. Trigger condition: conventions
layer demonstrably plateaus on persona-adherence *and* a strong open-weight base has
closed the reasoning gap.

## 11. Combination analysis

Stacks composed from the options above (Pi fixed as harness):

| Stack | Composition | POROUS | OPEN | SUSTAIN | SEMIAUTO | Effort to build | Failure mode |
|-------|-------------|--------|------|---------|----------|-----------------|--------------|
| **S1** | Pi + M1 + P1/P4 | ++ | ++ | + | − | ~0 (author text) | Memory goes stale; discipline-dependent |
| **S2** | Pi + M2 + P1–P5 | ++ | ++ | + | ++ | Days (one extension) | Pi API churn breaks hook; output files survive |
| **S3** | Pi + M3 + P1–P5 | ++ | ++ | + | ++ | ~1–2 weeks | Consolidation job neglected → noise; index rebuildable |
| **S4** | Pi + M4 + P1/P4 | + | ++ | ~ | ++ | Days (MCP bridge) + dep | agentmemory dies → SQLite export back to markdown |
| **S5** | Any + fine-tuned local model | + | ++ | − | n/a | Weeks + ongoing | Base model obsoleted; adapter dead weight |
| **S6** | Reference: Claude Code + auto-memory | ~ | − | ~ | ++ | 0 | Vendor lock; files readable on exit |

Analysis of the interesting cells:

- **S1 → S2 → S3 is a monotone path**: each step adds SEMIAUTO/scale without ever
  changing the data format or sacrificing POROUS/OPEN. No other stack family has this
  property — S4's store and S6's capture loop both introduce a format/vendor boundary.
  This path is the porosity-maximizing answer.
- **S2 is the sweet spot on effort/return**: one small extension turns Pi's own
  compaction moment (which happens anyway) into a memory write. It reuses text that
  was going to be generated regardless — near-zero marginal token cost, and the
  write-back lands in git where the human can veto it in review. Sustainability
  through simplicity: fewer moving parts than any MCP arrangement.
- **S4 dominates only in a multi-harness world**: if Claude Code / OpenCode sessions
  must share one memory with Pi sessions, MCP is the neutral bus. For a single-harness
  personal setup it adds a dependency chain (bridge extension → agentmemory → its
  survival) for no porosity gain — markdown in git is *already* shared state any
  harness can read.
- **S5 composes with, not replaces, S1–S3**: adapter carries persona; files carry
  memory; conventions still needed for the parts that change weekly. Even in the
  extreme case, layers stay separate — which is the Part I thesis holding under
  pressure.
- **S6 as benchmark**: still the SEMIAUTO quality bar, but loses on every new-axis
  criterion. Its remaining role: occasional A/B reference for whether S2/S3's captured
  memory is actually as good.

## 12. Synthesis

- The three targets (porosity, openness, sustainability) are *not* in tension with each
  other here — they are jointly maximized by one principle: **all durable state is
  human-readable files in git; everything else (index, harness, even model) is a
  disposable accelerator around those files.**
- The tension from §7 (SEMIAUTO vs PORT) dissolves under this principle: Pi's extension
  hooks provide the automatic capture loop that Part I found only in vendor/platform
  tools, while writing to the most portable substrate that exists.
- Recommended order: (1) author P1/P4 conventions + M1 skeleton (decision log, memory
  dir) — this is S1, usable immediately and portable everywhere; (2) build the M2
  write-back extension — S2; (3) add M3 search/consolidation only on demonstrated need;
  (4) collect session JSONL as latent fine-tune data but defer S5 until the prompting
  ceiling is proven; (5) skip S4 unless a second harness enters daily use.

## 13. Decision record: S3 installed (2026-07-11)

Decided: install S3 directly (skipping S2 stage). Concretization:

- **M3 implementation = memsearch** ([zilliztech/memsearch](https://github.com/zilliztech/memsearch),
  MIT, pinned 0.4.13) — the memsearch *pattern* from §4 turned out to be a shipping
  tool: dated markdown source of truth, Milvus Lite local index (disposable cache),
  ONNX CPU embeddings (no API key, offline after one-time model download),
  `compact` = the "dream" consolidation step.
- **Harness = Pi** (pinned 0.80.6), models via user API keys (OpenAI default) or any
  local OpenAI-compatible endpoint. No memsearch plugin for Pi exists → integration is
  a *skill* (recall/distill discipline via memsearch CLI), not an extension. The P5
  auto-capture extension (`agent_end` → daily note) is the documented upgrade when
  manual distill becomes the bottleneck — i.e. installed stack is S3 with skill-driven
  (not hook-driven) SEMIAUTO for now.
- **Conventions**: charter appended to project `AGENTS.md` (P1) + `memory` skill in
  `.agents/skills/` (P4, Agent Skills standard — readable by Pi/Codex/Claude alike).
- **Hermeticity chosen**: pinned versions, network at install time OK, embeddings and
  index local afterwards; network during work only for LLM API calls.
- **Kit lives in this repo**: `s3/INSTALL.md` (reproducible human instruction),
  `s3/install.sh` (machine/project), `s3/templates/` (charter, memory skill),
  `s3/MIGRATION.md` (moving existing dot-dir skills/preferences/knowledge into the
  project; AI-assisted prompt included). Test site: `~/dev/c/vetochka` (S1 → S3,
  slop_field becomes memory seed).

## 14. haft (quint.codes): layer 3 productized (assessed 2026-07-11)

**What it is.** [haft](https://github.com/m0n0x41d/haft) (formerly quint-code; MIT, Go,
~1.3k★, v6.1.0 Apr 2026, single-author: Ivan Zakutnii) — "decision engineering for AI
coding tools." `/h-reason` or manual five-mode cycle (`/h-frame` → `/h-explore` →
`/h-compare` → `/h-decide` → `/h-verify`): frame problem before solving, generate
genuinely distinct alternatives, compare under enforced parity, record decision as
*contract* (invariants, claims with thresholds, rollback plan, expiry date). `/h-note`
for micro-decisions with auto-expiry. Decisions carry computed trust scores (R_eff)
that decay as evidence ages; stale evidence triggers review; failed measurements reopen
decisions. Built explicitly on **FPF** (Levenchuk) — note: an `fpf` skill already sits
in `~/.claude/skills` here, so this is a familiar methodology operationalized.
Integration: MCP server + slash commands/skills for Claude Code, Cursor, Gemini CLI,
Codex CLI/App, OpenCode, Air. Storage: local SQLite + git-tracked markdown projections
(`haft sync` for teams).

**Where it lands in the three-layer picture.**

- §5 claimed *"no product ships 'design opponent' as a feature."* haft falsifies that:
  it is exactly the conventions layer (THINK/INIT/NOCODE1ST + our charter's
  alternatives-before-code rule) shipped as an enforced product, not prose. Our
  `AGENTS-charter.md` is a manual, unenforced subset of haft's cycle; the memory
  skill's Decision/Rejected/Open distill format is a degraded decision contract.
- Against memory layer: haft is **decision memory** (structured, typed, lifecycle:
  decay/expiry/supersession), memsearch is **episodic memory** (unstructured, semantic
  recall of everything discussed). Complementary, not rivals — memsearch remembers the
  conversation, haft governs whether a recorded decision should still be trusted.
  haft's evidence-decay machinery is the automated version of our charter's manual
  rules ("memory as hint, verify against code", "supersede, don't delete").

**Against the three targets.**

- POROUS ~: direction of truth *reversed* vs memsearch — SQLite is the store, markdown
  files are *projections* of it (git-tracked, human-readable, and sync round-trips
  through them, but the live artifact graph lives in the DB). Inspectable yes;
  edit-in-any-editor-as-source-of-truth no.
- OPEN ++: MIT, local binary, no accounts, MCP-standard interface.
- SUSTAIN ~: single author, fast churn (rename quint→haft, v6→v8 roadmap, pre-alpha
  TUI/desktop). Stable surface is the MCP plugin mode. Same young-project caveat as
  Letta/agentmemory in §7: the git-tracked markdown projections matter more than the
  features.

**Fit with the installed S3 stack.** Blocker: **no Pi support** — haft speaks MCP, Pi
has no native MCP client (§10.1 gap). Wrinkle: `haft init --codex` installs its
`h-reason` skill into `~/.agents/skills/` — which Pi *discovers* — but the skill drives
MCP tools (`haft_note`, `haft_decision`, ...) that Pi can't call; partial function at
best via the `haft` CLI directly. Options, in preference order:

1. **Steal the ideas now (free):** enrich the charter/memory skill with haft's
   cheapest high-value mechanics — expiry date on every distilled decision, explicit
   "weakest link" per rejected alternative, periodic `/h-verify`-style review of open
   decisions against code. No new dependency, keeps markdown as truth.
2. **Run haft alongside on a second harness** (Codex CLI is installed): memsearch for
   episodic recall + haft for decision governance. Cost: the M4-style dependency chain
   §11 warned about, plus SQLite-as-truth porosity concession.
3. **haft on Pi via an MCP-client extension** — deferred with the rest of the P5
   extension work; revisit if (1) proves insufficient.

Meta-observation: haft's existence supports the §12 synthesis rather than undermining
it — it demonstrates the conventions layer maturing into products, and its chosen
interchange format (git-tracked markdown) converges on the same "durable state =
files in git" principle.
