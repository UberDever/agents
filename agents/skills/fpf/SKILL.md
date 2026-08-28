---
name: fpf
description: Apply the distilled core of the First Principles Framework (FPF, Levenchuk) — a thinking discipline for keeping hard technical, research, and design reasoning coherent. Use when the user mentions FPF or first principles framework; when reasoning must survive delegation, review, or time; when claims, evidence, decisions, descriptions, and work are getting mixed; when comparing options needs declared criteria; or when a claim's kind is contested (is this evidence, a decision, or just a diagram?). Includes per-pattern retrieval from the full vendored spec.
---

# FPF — First Principles Framework, Distilled

## Purpose

This skill is a distillation of the First Principles Framework (https://github.com/ailev/FPF): a pattern language for keeping difficult project reasoning explicit, reviewable, and improvable. The full spec is ~95,000 lines and cannot be loaded; this file carries its load-bearing core in plain language, and the vendored spec (pinned, `spec/PINNED-COMMIT`) serves per-pattern lookups when a distinction here needs its exact normative form.

Use the distillation as a working discipline. Reach into the spec only when a specific claim becomes load-bearing. Never import FPF jargon into user-facing documents unless the specific pattern was consulted and citing it makes the reasoning easier to check.

## The Failure Mode FPF Exists To Prevent

Projects rarely fail because nobody had an idea. They fail because **the idea changes kind as it travels**:

- a sketch becomes a promise;
- a dashboard becomes evidence;
- a model output becomes permission;
- a selected set becomes one winner;
- a method description becomes performed work;
- a diagram becomes the architecture;
- a safety case becomes safety;
- a clever metaphor becomes an ontology.

The sentence still sounds the same, but the project has silently changed what it is allowed to claim or do. Every move below is a defense against one form of this drift. Rough early language is fine while it is only recognition text; the discipline activates when the same words begin to drive work, commitment, evidence, architecture, or choice.

## The Kernel Moves

### 1. Name the entity of concern first

Before reasoning, name the project entity the reasoning is *about* (FPF: holon / EntityOfConcern) — the system, organization, body of knowledge, work occurrence, or agent arrangement, treated as a whole with parts. Most confused discussions are about three entities wearing one name: the product, the description of the product, and the team changing it are not the same thing. Once the entity is named, ask which question about it is actually live: structure, claim, decision, evidence, description, work, or improvement.

### 2. Keep the description ladder distinct

The entity, its **description**, a **view** of that description for one concern, the **publication** form (document, dashboard, diagram, card), and the **carrier** (file, wiki page) are different objects, and each publication has a **reliance boundary** — what it may responsibly be used for. Hence: a diagram is not the architecture; a dashboard is not evidence by itself; a model card is not model safety; a generated explanation is not the system it explains. Multiple views of one entity are a strength, provided no view silently replaces another or the entity itself.

### 3. Unbundle sentences that cross boundaries

When a sentence enters an API doc, contract, SLO, safety case, review gate, or any text people will act on, it often does several jobs at once: define a term, state what a mechanism admits, assign a commitment, claim evidence, publish a view, move responsibility. Bundled jobs make the sentence uncheckable, and later disagreement gets resolved by politics instead of inspection. Unpack it: one claim kind per statement — definition, admissibility, commitment, evidence, work effect, publication, or decision.

### 4. Keep design and run apart

Role, method (way of doing), method description (document about the way), plan, performed work, evidence of the work, decision, and gate are **eight different objects**. The most expensive collapses: treating the plan as the work, the method description as the performed work, the gate passage as the work's success, and the monitor as evidence of success. When reporting status, say which of these objects the statement is about.

### 5. Meaning is local-first; translation is explicit

A term belongs to a bounded context before it travels. Different teams may legitimately mean different things by "service," "done," or "validated." Do not flatten meanings across contexts; build an explicit bridge that says how the meanings correspond and **what structure the translation loses**. A translation with undeclared loss is how cross-team agreements quietly diverge.

### 6. Build small closed worlds with reopen conditions

The world is open — new evidence, better models, shifting state of the art. Action still needs local closure: a release, gate, or review must decide what is enough *for the next action*. The discipline is to make closure explicit and bounded: declare the context, what is relied on, what boundary is crossed, and — critically — the **reopen condition** under which this closure is no longer enough. Strictness is local; a closed world without a reopen condition is dogma.

### 7. Return sets, not winners

Premature convergence on one favorite is the default failure of both teams and LLMs. Generate enough candidates before converging, and when publishing results of a search or comparison, return a **typed set**: a *palette* (plurality preserved, no ranking claimed), a *front* (non-dominated under declared criteria), an *archive* (retained for coverage and stepping stones), or a *shortlist* (chosen from a named source set by a named lens). Say which type you are returning; a bare "best option" hides the comparison logic. Evaluate generated candidates on four heads: **novelty** (how unlike the known set), **use-value** (what it achieves now), **constraint-fit** (satisfies the must-constraints), **diversity contribution** (does it open a new niche). Make the explore-vs-exploit policy explicit: state when the search widens versus refines rather than letting mood decide it.

### 8. Say what "better" means before optimizing

Improvement and comparison need a declared characteristic space: which characteristics, what units and scale, which direction is better, relative to what baseline. Two hard rules from the spec worth keeping verbatim: **never average ordinal scores**, and **no mixed-scale roll-ups** — a single number summed from incommensurable scales is not a comparison, it is a rhetorical device. Quality stays multi-dimensional until an explicit, declared rule collapses it.

### 9. Trust is calibrated, not felt

Reliance on a claim should depend on four declared things: the **evidence** behind it, its **freshness** (claims decay; a benchmark from last year is a claim about last year), its **scope** (the context it was established in), and its **intended use** (what decision it may support). "The dashboard proves it" fails all four at once. When a claim crosses a context boundary or ages past its freshness window, its reliance boundary shrinks until refreshed.

### 10. Think through writing; give outputs places to land

Serious reasoning needs objects that can be inspected — writing the record *is* the thinking, not documentation after it. A problem card separates a complaint from a usable problem; a comparison frame forces "compared by what"; a term sheet stops silent meaning-flattening. This matters doubly with LLMs: fluent generated prose is not project reasoning until it lands in a typed form — a candidate set, an evidence gap, a naming card, a decision record — where it can be checked against the kind of work it claims to perform.

### 11. Build arrangements, don't hunt biases

Bias-hunting is corrective and relies on vigilance. The constructive stance: build reasoning arrangements in which whole classes of mistakes become structurally hard — separate objects for plan and work make plan/reality confusion difficult; typed set results make single-winner bias visible; declared characteristic spaces make rigged comparisons inspectable. When you catch a reasoning error, prefer adding the missing structure over adding a warning.

### 12. Declare constraints, free the search (the Bitter Lesson stance)

Prefer general, scale-amenable methods over hand-crafted procedure scripts — but translate that into architecture, not blind automation: state goals, constraints, budgets, and checks explicitly, then let humans or agents search freely *within* those bounds. Separate design-time constraints (prohibited actions, risk budgets, evidence minima, acceptance criteria) from run-time prescription of every step. Where a bespoke heuristic is chosen over a general method, record why (regulation, a scale probe showed the general method flat, genuine context specificity) — a silent waiver is how brittleness accumulates.

### 13. Repair wording that drives work, via ontology not synonyms

When a phrase in a spec, contract, or dashboard starts governing action and feels overloaded, the repair path is: notice the wording doing too much → recover the entity and claim kind behind it → recover the ontology (kinds, context, time, evidence, use) *before* changing words → apply a formal lens only if it clarifies what is preserved and lost → rewrite as a plain reader line plus checkable fields → state what may now be done and what remains blocked. Success is not "sounds precise"; success is the reader still has a usable move.

## The One Small Habit

If nothing else survives from this skill: **when a project sentence starts to matter, ask what kind of entity it is about, what kind of claim it is making, what that claim may responsibly be used for, and what would reopen it.** The habit is small; everything above is its support structure.

## Going Deeper: Retrieval Into The Full Spec

The complete spec is vendored at `spec/FPF-Spec.md` (pinned commit in `spec/PINNED-COMMIT`; upstream is self-described "eternal alpha," so re-pin deliberately, never track head silently). Extract single patterns with the bundled script — pattern bodies run 150–400 lines, safe to load individually:

```bash
~/.agents/skills/fpf/extract.sh C.32.ADR          # one pattern body by ID
~/.agents/skills/fpf/extract.sh --grep 'decision' # find pattern IDs by title keyword
~/.agents/skills/fpf/extract.sh --list            # all 300+ headings with line numbers
```

Router — from working question to the pattern IDs to extract first:

| Working question | Extract first |
|---|---|
| Architecture: design, review, decide | `C.32.P2S`, `C.30`, `C.32.PAD`, `C.32.ADR` |
| Write rules / methods / process docs | `A.6`, `A.15`, `C.24`, `E.18` |
| Compare alternatives, choose locally | `A.19`, `C.11`, `C.18`, `C.19`, `G.5` |
| Vague situation → usable problem | `C.22.2`, `A.16`, `B.4.1` |
| Define "better," run improvement | `A.19.ECS`, `E.22`, `E.23`, `C.16` |
| Costly / hard-to-reverse action | `A.10`, `B.3`, `A.20`, `A.21`, `C.28` |
| Timing, freshness, staleness, rhythm | `C.27`, `A.10`, `G.11` |
| Causality, model outputs used for action | `C.28`, `A.10`, `B.3` |
| Many views/dashboards of one thing | `E.17`, `A.6.2`, `A.6.4`, `A.7` |
| Naming and terms across teams | `F.17`, `F.18`, `F.19`, `E.10` |
| Wording that drives work needs repair | `E.10`, `E.10.ARCH`, `A.6.P`, `F.18` |
| Should we build a formal/math model? | `C.29`, `A.6.0`, `B.3.5` |
| State-of-the-art / option portfolio | `G.0`, `G.1`, `G.5`, `G.11`, `A.19` |
| Generative search vocabulary (NQD, sets) | `A.0`, `C.17`, `C.18`, `C.19` |

Family map for orientation: **A** kernel (holons, contexts, roles, methods, work, architecture, comparison foundations) · **B** evidence, assurance, trust, abduction, problem cues · **C** major extensions (measurement, math modeling, architecture, time, causality, quality) · **D** ethics and multi-scale value · **E** FPF's own constitution (pattern form, lexical discipline, improvement loops) · **F** naming, term sheets, bridges · **G** state-of-the-art, portfolios, benchmarks, refresh.

## Composition With The Dialogue Skill

The `dialogue` skill runs the colloquium loop; this skill supplies its claim discipline. During a dialogue session: Phase 2's fact/assumption/preference tagging is move 3 in miniature; Phase 4's candidate generation should return typed sets and evaluate on the four heads (move 7); Phase 7's matrix obeys move 8's scale laws; Phase 9's ADR should carry reopen conditions (move 6). When a colloquium stalls on "what kind of claim is this?", extract the governing pattern and settle it.

## Boundaries

- This is a thinking discipline, not paperwork: apply a move when the cost of drift exceeds the cost of the structure, and skip it when feedback is fast, vocabulary is stable, and the decision is cheap to reverse. FPF's own test.
- The distillation, not the spec, is the default working surface. If a distilled move here contradicts an extracted pattern body, the pattern body wins for that claim — and this file should be updated.
- Do not speak FPF-internal dialect (`U.Holon`, `CG-frame`, `ReferencePlane`, pattern IDs) to users or in documents unless the pattern was actually consulted; plain language first is FPF's own stated usage rule.
