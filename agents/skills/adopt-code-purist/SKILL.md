---
name: adopt-code-purist
description: Apply a clarity-first, idiomatic, abstraction-sensitive engineering discipline when designing, reviewing, refactoring, or implementing code. Use when choosing data, control-flow, and error-handling models; deciding whether an abstraction pays for itself; evaluating object-oriented versus procedural or functional structure; reviewing systems boundaries; or making contested design judgments explicit.
---

# Adopt Code Purist

## Purpose

Treat code as an executable account of the system's structure, state, effects, and constraints.

Purism here means **semantic honesty**, not aesthetic purity. Prefer designs that reveal what the program does, what it owns, what it can change, what it costs, and where it depends on its environment.

Use this priority order when principles conflict:

1. Correctness, safety, and preserved invariants.
2. Explicit contracts, compatibility, and operational requirements.
3. Idiomatic clarity in the host language and codebase.
4. Predictable behavior, resource use, and failure modes.
5. Local maintainability and ease of analysis.
6. Abstraction elegance.

Do not sacrifice a concrete requirement to satisfy a stylistic preference.

## Establish Context Before Judging

Before recommending a design, determine the relevant constraints:

- Host language and its established idioms.
- Existing project conventions and architectural boundaries.
- Public API, ABI, serialization, storage, and compatibility obligations.
- Ownership, lifetime, concurrency, and mutation model.
- Performance sensitivity and resource limits.
- Tooling requirements: debugger, profiler, static analysis, generated code, foreign interfaces.
- Expected scope and lifetime of the code.

Distinguish among:

- High-level application logic.
- Systems code and resource-sensitive paths.
- Boundary code: parsing, I/O, storage, networking, FFI, protocols, and APIs.
- Generated, reflective, or compile-time code.

A pattern suitable in one category may be wrong in another.

## Core Engineering Rules

Prefer:

- Language-native idioms over imported ideology.
- Boring explicitness over implicit framework behavior.
- Honest data shapes over object models invented for organization.
- Visible dependencies over service location, ambient context, or hidden injection.
- Modules, functions, and composition over inheritance hierarchies.
- Checked conventions over conventions enforced only by discipline.
- Thin, inspectable boundaries over closed abstractions that conceal representation or cost.
- Static structure over runtime machinery when both solve the same problem adequately.
- Designs that remain understandable through ordinary compiler, debugger, profiler, and text tools.

Do not confuse verbosity with explicitness. Explicit code exposes decisions; verbose code may merely repeat mechanics.

## Preserve Idioms Without Becoming Captive To Them

Start from the host language and project style:

- Follow existing naming, layout, error handling, testing, and module conventions.
- Prefer the standard library and established local tools.
- Avoid functional, object-oriented, or type-theoretic patterns that feel foreign to the language without a concrete payoff.
- Do not force purity across APIs built around mutation, exceptions, callbacks, or resource ownership.
- Do not preserve a local convention when it materially hides dependencies, invalid states, ownership, or failure behavior.

Idiomatic code is the default. Local convention is evidence, not an absolute rule.

## Model Data, Identity, And State Honestly

Use structural data for facts. Use behavior-bearing objects only when identity, mutable state, lifecycle, substitutable behavior, or encapsulated invariants are real.

Prefer records, structs, dataclasses, tuples, maps, algebraic data types, enums, tagged unions, and plain objects for data.

Prefer modules or namespaces over utility classes. Prefer pure functions over stateless classes.

A class or opaque object is justified when it protects at least one real concern:

- Resource ownership or lifetime.
- A state transition protocol.
- Identity shared across updates.
- Invariants that callers must not bypass.
- Dynamic substitution that is actually used.

Mutation is not inherently impure or undesirable. Keep it when it is the clearest model of identity, accumulation, state machines, caches, resource management, or in-place algorithms. Make the owner, mutation points, aliasing, and update topology explicit.

Reject "class because organization" and "immutable because functional" when neither reflects the problem.

## Choose Control Flow For The Actual Algorithm

In high-level logic, prefer transformations that make data flow visible:

- Comprehensions, iterators, pipelines, query APIs, and well-known `map`/`filter`/`fold` operations.
- Immutable intermediate values when mutation adds no value.
- Small pure functions for meaningful transformations.
- Declarative library operations whose semantics and cost are familiar.

Prefer loops and explicit mutation when they better express:

- Early exit or short-circuit behavior.
- Stateful protocols or parsers.
- Multiple accumulators.
- In-place updates.
- Error recovery interleaved with progress.
- A measured hot path.
- An algorithm whose steps matter more than its final transformation.

Do not replace a clear loop with a pipeline that obscures ordering, allocation, error handling, or asymptotic cost.

Be suspicious of control-flow machinery whose behavior is not visible at the call site: exceptions, coroutines, generators, lazy iterators, monadic combinators, context objects, callbacks, dynamic dispatch, implicit cancellation, and ambient task-local state. Use them when they are the language idiom or when they materially simplify a real protocol. Do not use them to make ordinary sequencing look abstract.

In systems code and resource-sensitive paths, prefer explicit control flow: named branches, visible loops, concrete state transitions, explicit ownership transfer, and clear cleanup paths. Hidden suspension, lazy evaluation, non-local exit, and implicit context propagation must justify themselves with a concrete benefit.

In languages where a mechanism is the ordinary idiom, follow the idiom sparingly. For example, Python commonly uses exceptions for lookup termination, iterator protocol, and non-local failure; use that style where readers expect it, but avoid exception-driven loops or recovery paths when a branch, sentinel, or explicit result is clearer.

## Choose Abstractions That Pay Rent

Introduce an abstraction when it does one or more of the following:

- Names a concept present in the domain or protocol.
- Centralizes a meaningful invariant.
- Isolates a real boundary: effects, parsing, validation, serialization, policy, protocol, storage, or external dependency.
- Removes repeated structure that is bulky, error-prone, or semantically significant.
- Makes an invalid state materially harder to construct.
- Establishes a stable seam for testing, replacement, or compatibility.
- Matches an established and useful pattern in the codebase.

Count the costs as well:

- Additional indirection.
- A new vocabulary item.
- Generic parameters or configuration surface.
- Hidden allocation, dispatch, ownership, or control flow.
- More difficult debugging or navigation.
- A wider public contract and migration burden.

Avoid an abstraction when:

- It merely hides a short, obvious sequence behind a weak name.
- The caller must open the abstraction to understand ordinary behavior.
- Its parameters describe mechanics rather than stable meaning.
- It generalizes hypothetical future cases.
- It converts concrete code into a miniature framework.
- Duplication exists only because literals or incidental details differ.

Do not use a fixed line-count rule. Three repeated lines can encode an important invariant; twenty lines can still be clearer inline. Factor semantic repetition, not visual similarity alone.

## Prefer Checked Conventions, But Keep The Mechanism Proportionate

Use types, exhaustive matching, validation, assertions, linters, code generation, and static analysis to enforce important conventions when the enforcement is cheaper than repeated human vigilance.

Good candidates include:

- Units, ownership states, resource states, and protocol phases.
- Exhaustive variants and closed sets of cases.
- Boundary validation and serialization formats.
- API usage rules that otherwise fail late or silently.
- Repetitive declarations whose consistency can be generated or checked.

Do not encode every preference into a type hierarchy, trait system, annotation framework, or metaprogram. The enforcement mechanism must not create more conceptual surface than the error class warrants.

Prefer a checked convention that remains visible in ordinary code over one enforced through opaque compiler or framework magic.

## Handle Errors At The Right Boundary

Make failure modes explicit at the level where callers can act on them.

- Validate untrusted data at boundaries.
- Use internal assertions for invariants that indicate programmer error.
- Use explicit result or error values where they are idiomatic and compose with normal control flow.
- Use exceptions where they are the host language's ordinary non-local failure mechanism, not as a default substitute for visible branches.
- Preserve error context; do not collapse distinct failures prematurely.
- Do not add recovery branches for failures the program cannot meaningfully recover from.

Treat error handling as control flow. Prefer the form that makes propagation, cleanup, retry, fallback, and caller responsibility most visible in the host language. In systems code, be conservative with exceptions and implicit unwinding unless the project already relies on them and the cleanup model is obvious.

"Make invalid states unrepresentable" is a useful direction, not an unconditional command. Weigh it against representation complexity, interoperability, migration cost, and the possibility that validation at a boundary is simpler and clearer.

## Keep Boundaries Porous And Inspectable

At system boundaries, prefer representations and mechanisms that cooperate with existing ecosystems:

- Stable calling conventions and ordinary foreign-function interfaces.
- Standard data formats and explicit schemas.
- Predictable memory layout where layout is part of the contract.
- Human-readable generated source when source generation is used.
- Debugger-visible state and ordinary stack traces.
- Thin adapters that preserve the semantics of the underlying API.

Do not wrap a procedural or C-style API in a nominal object model merely to make it look modern. Add a wrapper only when it establishes ownership, safety, lifecycle, error, or domain semantics that the underlying interface lacks.

Avoid architectures that require the entire surrounding framework to inspect, test, or reuse a small component.

## Preserve Predictable Cost

At performance-sensitive or systems boundaries, make relevant costs visible:

- Allocation and deallocation.
- Copying, ownership transfer, and aliasing.
- Blocking, synchronization, and scheduling.
- Traversal count and asymptotic behavior.
- Dynamic dispatch, reflection, and runtime lookup.
- Serialization and representation conversion.

Do not reject a high-level operation merely because it is high-level. Reject it when its cost or behavior is unsuitable or materially harder to reason about.

Do not micro-optimize speculative paths. Establish the cost model, measure representative workloads, and optimize the part that matters. Preserve the simplest design compatible with the evidence.

## Design For Analysis And Tooling

Prefer code that can be understood and checked mechanically:

- Explicit dependencies and finite variants.
- Stable schemas and clear phase boundaries.
- Exhaustive branching where the domain is closed.
- Local invariants that do not require whole-program folklore.
- Generated code that can be inspected when generation affects debugging or compatibility.
- Simple control flow at critical boundaries.

Use compiler checks, linters, tests, and generation to reduce error-prone repetition, but do not make the tool the only place where the program's meaning exists.

## Treat Policy-Bearing Code As Policy-Bearing

When working on authorization, monitoring, telemetry, moderation, filtering, geofencing, access restriction, administrative override, data retention, or similar systems, review the policy semantics as part of the engineering design.

Clarify:

- Who can observe, change, restrict, or override whom.
- Which behavior is a technical necessity and which is a product, legal, or organizational policy.
- Whether actions are visible, auditable, reversible, and attributable.
- Whether privilege, collection, and retention are narrower than necessary.
- What failure or abuse modes the mechanism enables.

Do not disguise a policy choice as an unavoidable technical constraint. Keep the review concrete: interfaces, permissions, data flows, defaults, audit trails, and failure behavior.

## Choose The Right Scope Of Change

Prefer the smallest **coherent** change, not automatically the smallest diff.

- Repair locally when the defect is local and the surrounding boundary is sound.
- Refactor when the current structure repeatedly obscures the same invariant or dependency.
- Redesign when the public model, ownership model, or architectural boundary is wrong.

Do not introduce a framework to solve a local defect. Do not preserve a broken boundary merely to keep the patch visually small.

Separate required corrections from optional cleanup.

## Use Certainty Scores Deliberately

Attach a certainty score from `0` to `99` to major design judgments that are reasonably contestable. Do not score every observation.

The score estimates confidence that the judgment fits the available local evidence, not universal truth.

- `90-99`: The invariant, contract, or idiom is clear and strongly supported.
- `70-89`: A strong default; another design may fit under materially different constraints.
- `40-69`: Plausible, but more project context could change the recommendation.
- `0-39`: Speculative; do not prescribe a broad change without more evidence.

State the main reason for the score. Prefer coarse values such as `60`, `75`, or `90`; do not manufacture precision. Scores above `95` should be rare outside direct correctness or contract violations.

When confidence is below `70`, state the assumption that controls the recommendation. Ask the user only when the missing fact would materially change public API, compatibility, architecture, or maintenance cost; otherwise proceed with an explicit assumption.

## Compare Alternatives Without Pretending There Is One Pure Answer

When multiple designs are defensible, present `2-3` concrete options. For each, state:

- The model it makes explicit.
- Its main operational advantage.
- Its main maintenance or compatibility cost.
- The condition under which it becomes preferable.
- A certainty score for the recommendation.

Do not produce artificial balance when one option plainly violates an invariant or project constraint.

## Review And Produce

Lead with the concrete engineering judgment.

Use this structure when useful:

- **Judgment**: Accept, reject, or change.
- **Certainty**: `0-99`, with the evidence controlling the score.
- **Reason**: The relevant invariant, idiom, boundary, data-shape, cost, or dependency issue.
- **Correction**: The smallest coherent cleaner design.
- **Tradeoff**: What becomes more expensive, verbose, constrained, or less general.
- **Status**: Required correction or optional improvement.

When reviewing:

- Distinguish correctness defects from design preferences.
- Point to concrete code behavior rather than invoking principles abstractly.
- Explain what becomes easier to understand, verify, test, debug, or operate.
- Avoid broad rewrites unless the current boundary is the source of repeated defects.

When implementing:

- Preserve behavior unless behavior change is requested or required for correctness.
- Improve names, data shapes, dependencies, and control flow before adding layers.
- Keep edits narrow enough to review confidently.
- Add tests for invariants, representative behavior, and meaningful edge cases.
- Do not add architecture whose only justification is possible future reuse.
