---
name: work-large-codebase
description: Work safely in large C++ codebases by mapping existing structure before editing, reusing local patterns, avoiding broad refactors and duplicate abstractions, preserving local style, and choosing targeted validation. Use when Codex is asked to understand, fix, extend, refactor, review, or test code in a large or unfamiliar C++ repository, especially when the request touches existing subsystems, build/test selection, ownership boundaries, or established project conventions.
---

# Work Large Codebase

## Overview

Make the repository teach the change. First identify the local shape and precedent, then edit the smallest surface that solves the task and validate the affected behavior.

## Required Repo Map

Before editing, build and share a short repo map. Keep it brief, but include enough evidence to prevent blind changes:

- Relevant directories and files.
- Existing implementation pattern, helper API, or subsystem boundary to follow.
- Nearby tests, build targets, or validation commands likely to matter.
- Main risk or uncertainty.

For tiny tasks, 2-4 bullets are enough. If the repo map is still uncertain, inspect more before editing instead of guessing.

## Exploration

Start with fast, cheap evidence:

- Run `git status --short` before editing. Treat existing changes as user-owned unless proven otherwise.
- Use `rg`, `rg --files`, and targeted file reads before broad scans.
- If repository has a `tags` ctags file, use it for fast exact symbol lookup before broader text searches; confirm definitions and references in source because tags may be stale or incomplete.
- Search for existing symbols, error messages, tests, config names, and similar features before adding new code.
- Inspect nearby call sites, base classes, interfaces, factories, registration points, and tests.
- Prefer build files, `compile_commands.json`, CMake targets, test manifests, or CI config over assumptions about how code is built.

Stop exploring when the likely change point, local pattern, and validation path are clear. Continue exploring when two plausible implementations exist and local precedent can decide.

## Change Discipline

Keep edits narrow and idiomatic:

- Reuse existing project abstractions, naming, error handling, memory ownership, threading, logging, and test style.
- Do not create a new helper, class, layer, option, or test fixture until searching proves no suitable one exists.
- Avoid drive-by cleanup, formatting churn, dependency churn, and broad refactors unless required for the requested behavior.
- Prefer modifying the subsystem that owns the behavior over patching distant symptoms.
- Let errors propagate in the style already used by nearby code; do not hide failures behind silent fallbacks.
- Preserve ABI/API compatibility, serialization formats, CLI flags, config names, and user-visible behavior unless the task requires changing them.
- In C++, match nearby include order, namespace structure, ownership types, constness, assertions, exception style, and brace style.

When the clean fix appears larger than expected, pause and state the tradeoff before expanding scope.

## Test Selection

Choose validation from the touched surface:

- Run the narrowest existing test that covers the changed behavior.
- Add or update tests only where existing coverage is missing or cannot catch the requested behavior.
- Prefer nearby unit, integration, regression, or query tests that match local convention.
- Build or compile the smallest relevant target when C++ type/interface risk exists.
- If full validation is expensive, run targeted checks first and clearly report remaining risk.

Do not invent a test framework or new test structure when the repo already has one.

## Communication

Keep user-visible updates short and evidence-based:

- Before edits: provide the repo map.
- During work: mention only new facts that affect approach.
- Final: list changed files, behavioral result, validation run, and any untested risk.

When making a judgment call, tie it to observed repository evidence.
