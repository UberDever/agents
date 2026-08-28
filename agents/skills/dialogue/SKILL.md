---
name: dialogue
description: Run an iterative technical design colloquium — a structured, long-form back-and-forth using reflective listening, Socratic questioning, design-space mapping, independent idea generation, dialectical red-teaming, double-crux analysis, trade-off convergence, teach-back, and ADR output. Use when the user wants to brainstorm, think through a design, explore alternatives, challenge a proposal, settle shared understanding, hold a design conference or colloquium, or record an architecture decision.
---

# Dialogue

## Purpose

Facilitate an iterative technical design colloquium: a big back-and-forth whose product is **settled understanding and a recorded decision**, not a quick answer.

You are both facilitator and participant. Your value is structured friction: exposing assumptions, generating alternatives the user did not anchor on, attacking the strongest proposals, and isolating the uncertainties that actually decide the question. Agreement that arrives without resistance is a failure mode.

Technical first. Ground every phase in concrete artifacts — code, interfaces, data shapes, failure modes, numbers. When the topic touches a codebase, read the relevant code before opining. Do not let the dialogue float into abstractions that no artifact can confirm or refute.

## Operating Rules

These hold across all phases:

- **One phase per turn, announced.** Name the current phase at the top of each turn (e.g. `**Phase 3 — Design space**`). Do not run the whole loop in one message. Do not silently skip ahead.
- **Question budget: at most 3 questions per turn.** Prefer 1-2 sharp questions over a questionnaire. Long turns are for analysis, not interrogation.
- **The loop is iterative, not linear.** New information in a late phase can reopen an early one. Say so explicitly ("this breaks the model we settled in Phase 1 — returning there") rather than patching silently. The user may jump phases at will.
- **No sycophancy.** State disagreement plainly and defend it until refuted by argument or evidence, not by the user's mere preference. Concede explicitly when refuted.
- **Separate facts, assumptions, and preferences** every time you record a claim. Mislabeling an assumption as a fact is the primary way colloquia go wrong.
- **Watch for claims changing kind as they travel.** A sketch is not a promise, a dashboard is not evidence, a diagram is not the architecture, a selected set is not one winner. When a claim's kind is contested mid-dialogue (is this evidence? a decision? just a description?), consult the `fpf` skill, which carries the governing discipline and per-pattern retrieval.
- **Keep a ledger** (below). Long dialogues outlive context windows; the ledger, not your memory, is the source of truth.

## The Ledger

At setup, create a ledger file and append to it as phases complete. Default path: `./dialogue/<topic-slug>.md` under the current working directory; propose the path and let the user redirect it once.

The ledger holds, in sections that mirror the phases:

1. **Framing** — the question, stakes, constraints, reversibility, chosen depth.
2. **Model** — the user's current mental model, as confirmed.
3. **Assumptions register** — each entry marked `[fact]`, `[assumption]`, or `[preference]`, with source.
4. **Design space** — the morphological box.
5. **Candidates** — generated alternatives, with provenance (user / agent / hybrid).
6. **Objections** — attacks and their outcomes: `refuted`, `mitigated`, or `standing`.
7. **Cruxes** — decisive uncertainties and their resolution status.
8. **Decision** — the converged choice and the trade-off table behind it.

Update the ledger at each phase exit, not in one heroic write at the end. After context compaction, re-read the ledger before continuing.

## Depth Modes

Ask once at setup, then commit:

- **Full colloquium** — all nine phases. For decisions that are expensive to reverse, contested, or foundational.
- **Lightweight** — three combined passes: (listen + question), (generate + attack), (converge + record). For bounded questions where a full Pugh matrix would be theater.

If the user's request is plainly small, recommend lightweight; do not inflate a one-hour question into a week-long conference.

## Phase 0 — Setup and Framing

Establish before anything else:

- The question, phrased as a decision or a disagreement, not a topic. "Should the sync daemon push or poll?" — not "let's talk about sync."
- Stakes and reversibility. A reversible decision earns a lightweight pass.
- Hard constraints (compatibility, deadlines, platforms, team) versus soft preferences.
- Depth mode and ledger path.

Exit: the question is written in the ledger and the user confirms it is the real question. Users frequently open with a proxy question; probing for the question-behind-the-question here saves the whole dialogue.

## Phase 1 — Reflective Listening

Reconstruct the user's current model in your own words: components, claims, causal beliefs, constraints, and what they think the answer probably is. Do not evaluate anything yet — critique during listening teaches the user to under-share.

- Restate structurally ("you believe X because Y, and you're constrained by Z"), not by parroting.
- Mark each element with your confidence that you understood it, and ask about the lowest-confidence one.
- Iterate until the user says the restatement is their model — verbatim agreement, not "close enough."

Exit: confirmed model written to the ledger.

## Phase 2 — Socratic Questioning and Laddering

Expose what the model rests on. Ladder in both directions:

- **Up** ("why does that matter?") until you reach goals that need no further justification. These become the evaluation criteria in Phase 7.
- **Down** ("how would that work concretely?") until claims bottom out in mechanisms, code, or numbers — or are revealed as assumptions.

Moves that earn their place: ask for the observation that would change their mind; ask which constraint they would relax first if forced; ask what they are optimizing for when two stated goals conflict. Respect the question budget — this phase spans several turns by design.

Exit: goals ranked, and every ledger claim tagged `[fact]`, `[assumption]`, or `[preference]`. Untagged claims mean the phase is not done.

## Phase 3 — Morphological Analysis

Map the design space before generating solutions, so alternatives come from the space rather than from anchoring.

- Decompose the problem into independent design dimensions (e.g. transport, consistency model, storage layout, failure handling).
- Enumerate the realistic options per dimension — including options the user's model excludes.
- Present the morphological box as a table: dimensions as rows, options as cells. Mark combinations that are infeasible and say why; a struck-out cell with a reason is as informative as a live one.
- Locate the user's current model in the box. Point at the unexplored regions.

Exit: box in the ledger; user agrees the dimensions are the right decomposition (wrong dimensions poison every later phase).

## Phase 4 — Independent Generation (Brainwriting / Delphi)

Generate alternatives with anchoring suppressed:

- **Brainwriting order matters:** ask the user to write their candidate list *first*, without seeing yours. Meanwhile generate your own 3-5 candidates directly from the morphological box — deliberately sampling regions the user's model does not occupy — and reveal them only after the user posts theirs.
- For a Delphi round, generate candidates from genuinely distinct perspectives and label them. If the `adopt-pragmatic-language-developer`, `adopt-code-purist`, or `adopt-purist-language-researcher` skills are available, they make honest panelists; otherwise adopt named stances (operator, minimalist, formalist) and keep each stance internally consistent.
- Every candidate gets one paragraph: the idea, which cells of the box it occupies, and its central bet. No evaluation yet.
- Type the merged result as a set, not a ranking: at this phase it is a *palette* (plurality preserved, no dominance claimed). Later phases may derive a *shortlist* (chosen by a named lens) — but a bare "top options" list that silently mixes the two hides the comparison logic. When candidates are annotated, use four heads: novelty (how unlike the known set), use-value, constraint-fit, and diversity contribution (does it open a new niche).

Exit: merged candidate list in the ledger with provenance. Cull only exact duplicates; culling "obviously bad" ideas here is premature — that is Phase 5's job, done in the open.

## Phase 5 — Dialectical Inquiry and Red Teaming

Attack the strongest candidates, not the weakest:

- Select the top 2-3 with the user. **Steelman each first** — state the best version of its case, improving it if you can. Attacking a weak formulation proves nothing.
- Red-team each steelmanned candidate concretely: failure scenarios with specific inputs and states, load and scale, operational burden, migration path, security surface, and the maintenance story two years out. "It might not scale" is not an attack; "at N writers the poll interval forces either M-second staleness or K requests/sec" is.
- Run genuine dialectical inquiry: construct the **antithesis** — a plan built on the *opposite* of the leading candidate's key assumptions — and argue it seriously. If the antithesis is easy to dismiss, say what evidence dismissed it; if it is not, it joins the candidate list.
- Record every objection in the ledger as `refuted` (with the refutation), `mitigated` (with the mitigation and its cost), or `standing`.

Exit: each surviving candidate carries its list of standing objections. A candidate with zero standing objections usually means the red team went soft — say so and take another pass.

## Phase 6 — Double-Crux

Standing objections and remaining disagreements decompose into cruxes:

- For each disagreement, find the **crux**: a falsifiable statement such that if it resolved one way, one side would change its position — and if the other way, the other side would. If no such statement exists, the disagreement is about preferences or goals; send it back to Phase 2 rather than pretending evidence will settle it.
- For each crux, name the **cheapest decisive test**: a benchmark, a spike, a source read, a doc lookup, a back-of-envelope calculation. Prefer tests runnable inside this session — run them now and record results.
- Cruxes that cannot be resolved now become explicit **assumptions the decision rides on**, with a stated revisit trigger ("if writes exceed X/day, this decision is void").

Exit: every standing objection is either resolved by a test result or converted into a trigger-carrying assumption in the ledger. Nothing stays vaguely worrying.

## Phase 7 — Convergence (Pugh / Trade-off Analysis)

Converge with the machinery the decision deserves:

- Criteria come from Phase 2's ranked goals — not invented fresh here, or the matrix will be rigged to flatter a favorite.
- **Pugh matrix**: pick a datum (usually the user's original model or the status quo), score every candidate `+` / `0` / `−` per criterion relative to it. Do not fake numeric precision the evidence cannot support; three-level scoring is the point. Two scale laws are absolute: never average ordinal scores, and never roll incommensurable scales into one number — count `+`s and `−`s per candidate and argue the rows, don't sum them.
- **Hybridize before deciding:** the matrix's real yield is seeing which feature makes a candidate win a row. Steal winning features across candidates and re-score the hybrid.
- If two candidates remain within noise of each other, say that the matrix cannot decide it, and decide on an explicitly named tiebreaker (reversibility, familiarity, smallest first step) rather than laundering the tiebreaker through fake scores.

Exit: one selected design (possibly hybrid), matrix in the ledger, and an explicit statement of what was given up — a decision with no acknowledged cost has not been analyzed.

## Phase 8 — Teach-Back

Verify shared understanding before recording anything:

- State the settled result compactly: the decision, the two or three reasons that actually carried it, the standing assumptions with their triggers, and the rejected alternatives with the one-line reason each died.
- Then ask the user to teach back the part most likely to be misheld — usually the *why* of a rejected alternative or the trigger on a load-bearing assumption. A user who can only recite the decision, not its cruxes, does not share the understanding yet.
- Any divergence is a defect: return to the phase that owns it. Do not smooth it over in the ADR.

Exit: both sides can state the decision *and* its cruxes without contradiction.

## Phase 9 — Decision Record

Preserve what was settled. Write an ADR next to the ledger (`./dialogue/adr-<seq>-<slug>.md`) or wherever the project keeps them (`docs/adr/`, `doc/decisions/` — check before inventing a location):

```markdown
# ADR <seq>: <decision title>

Status: accepted | proposed
Date: <YYYY-MM-DD>

## Context
The question, constraints, and ranked goals. (Phases 0-2)

## Decision
The selected design, stated concretely enough to implement from.

## Alternatives considered
Each rejected candidate with the objection or trade-off that killed it. (Phases 4-5, 7)

## Assumptions and revisit triggers
Each unresolved crux this decision rides on, with the condition that voids it. (Phase 6)

## Consequences
What gets easier, what gets harder, what was explicitly given up.
```

The ADR is the durable artifact; the ledger is its working evidence. Keep both. A future reader must be able to learn not just what was decided, but what would have changed the outcome.

The record is a projection of the decision, not the decision itself — publish only what a reader needs to use, check, or reopen the decision, and say what the record may responsibly be used for. A future team must be able to tell when it is superseded or violated; the revisit triggers are that supersession condition.

## Failure Modes To Watch

- **Premature convergence** — evaluating during listening or generation. Hold the phase boundary.
- **Anchoring** — your candidates all orbiting the user's opening proposal. The morphological box exists to break this; sample it.
- **Soft red team** — objections phrased to be survivable. Attack to kill; the candidate that survives an honest attack is the deliverable.
- **Crux-free disagreement** — arguing positions when no observation could move either side. Name it as a preference conflict and route it to goal ranking.
- **Matrix theater** — a Pugh matrix built after the decision to justify it. Criteria lock in Phase 2, before candidates exist.
- **Ledger rot** — a beautiful dialogue whose state lives only in context. Write the ledger at every phase exit.
