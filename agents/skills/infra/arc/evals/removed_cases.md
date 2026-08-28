# Removed arc eval cases

Updated: 2026-08-05

This file lists whole cases intentionally excluded from `evals.json`.
`evals.json` is the stable core: useful, non-redundant describe-only cases with
no known semantic failures in the current cross-model validation window.
Infrastructure timeouts and judge protocol errors are recorded separately from
semantic failures.

## Summary

- Whole cases excluded from `evals.json`: **12**
- Redundant with retained eval coverage: **6**
- To be replaced by executable scenarios: **2** (`25`, `33`)
- Invalid or overconstrained describe-only contracts: **2** (`27`, `32`)
- Useful but semantically unstable cases in quarantine: **2** (`46`, `55`)

## Invalid or overconstrained contracts

### Case 27 — machine-readable PR list

**Former prompt:** Хочу получить список моих PR в машиночитаемом формате и
обработать его скриптом. Покажи надёжный способ чтения результата.

**Why absent from `evals.json`:** the expectation requires
`arc pr list -o --json` and JSONL parsing, while the skill's routing section
delegates remote PR inspection and structured PR metadata to an Arcanum skill.
Luna followed that routing in process `2465850`. The prompt does not establish
a local-checkout-only constraint that would resolve the contradiction.

| Model | Runs | Semantic pass | Semantic fail | Infra/judge error |
|---|---:|---:|---:|---:|
| Terra | 3 | 3 | 0 | 0 |
| Luna | 3 | 2 | 1 | 0 |
| DeepSeek Flash | 3 | 2 | 0 | 1 timeout (`2465989`) |
| Sonnet | 1 | 1 | 0 | 0 |

**Return condition:** first choose one canonical contract: either explicitly
scope the prompt to local `arc pr list` output, or judge the Arcanum route as a
valid structured remote-list solution. Then restart the model statistics for
the revised case.

### Case 32 — history-preserving revert

**Former prompt:** Откати последний коммит, но так чтобы история сохранилась.
Не хочу переписывать историю.

**Why absent from `evals.json`:** the expectation insists on resolving and
passing a full 40-character hash, although Sonnet's `arc revert HEAD` preserves
history and directly identifies the requested last commit. The case therefore
tests a stricter implementation detail than the user-visible safety property.

| Model | Runs | Semantic pass | Semantic fail | Infra/judge error |
|---|---:|---:|---:|---:|
| Terra | 3 | 3 | 0 | 0 |
| Luna | 3 | 3 | 0 | 0 |
| DeepSeek Flash | 3 | 3 | 0 | 0 |
| Sonnet | 1 | 0 | 1 | 0 |

**Return condition:** revise the contract to accept either `arc revert HEAD`
or `arc revert <full-hash>`, while continuing to reject history-rewriting
`arc reset --hard`; then collect a fresh cross-model window.

## Useful cases in quarantine

### Case 46 — read a historical file from a subdirectory

**Former prompt:** Я в подпапке сервиса в монорепозитории Arcadia. Нужно
посмотреть содержимое `src/pages/stories/stories.integration.spec.ts` из
коммита `ce2c8ac2ebf76cfe99d488c248f4e2abf2e6650c`, хочу сравнить со своей
версией.

**Why absent from `evals.json`:** this is a valuable Arc-specific gotcha, but
Luna and DeepSeek independently recommended invalid subdirectory forms instead
of `arc show <COMMIT> <path>`. Luna used `arc show <COMMIT> -- <path>` in
process `2465803`; DeepSeek used `arc show <COMMIT>:<path>` in process
`2465989`. The latter run had no judge verdict, but manual inspection of the
captured solver response confirms the semantic failure. Earlier processes
`2465043` and `2465530` also failed this behavior.

| Model | Runs | Semantic pass | Semantic fail | Infra/judge error |
|---|---:|---:|---:|---:|
| Terra | 3 | 3 | 0 | 0 |
| Luna | 3 | 2 | 1 | 0 |
| DeepSeek Flash | 3 | 2 | 1 manual | 1 missing judge verdict on the failed response |
| Sonnet | 1 | 1 | 0 | 0 |

**Return condition:** demonstrate 100% semantic pass on a fresh validation
window after making the subdirectory-safe positional form visible to agents
that load only the early part of `SKILL.md`.

### Case 55 — amend an existing PR commit safely

**Former prompt:** В последнем коммите забыл файл `server/config_test.go`. PR
уже существует, отдельный новый коммит не нужен.

**Why absent from `evals.json`:** the useful behavior combines amend,
force-push, branch-name handling, and shared-branch safety, but models
repeatedly omit an operational `arc pull` or a sufficiently explicit check for
other developers' commits. Luna failed substantively in process `2465803`.
Terra process `2465727` did run `arc pull` and check for foreign changes, but
the judge still failed it for not separately classifying the branch as shared;
that result is retained as a borderline semantic failure. DeepSeek process
`2465989` timed out before submission. In the earlier four-run window
(`2465047`, `2465045`, `2465043`, `2465037`) the case passed twice and failed
twice; Luna process `2465530` did not submit the instance because of an
infrastructure failure.

| Model | Runs | Semantic pass | Semantic fail | Infra/judge error |
|---|---:|---:|---:|---:|
| Terra | 3 | 2 | 1 borderline | 0 |
| Luna | 3 | 2 | 1 | 0 |
| DeepSeek Flash | 3 | 2 | 0 | 1 timeout (`2465989`) |
| Sonnet | 1 | 1 | 0 | 0 |

**Return condition:** achieve 100% on a fresh cross-model window with an
explicit `arc pull` and inspection of other developers' commits before any
force-push of a shared branch.

## Redundant cases

### Case 4

**Prompt:** После rebase мне нужно сделать force-push локальной ветки, которая
называется `users/<username>/TICKET-4567`. Какую команду использовать?

**Why removed:** already-prefixed push and force-push behavior is covered by
cases `14` and `16`, including the explicit `-u users/<username>/...` target and
double-prefix protection.

### Case 8

**Prompt:** Я нахожусь на ветке `users/<username>/TICKET-4567`, изменил
`server/handler.go` и `server/handler_test.go`. Нужно запушить изменения.

**Why removed:** staging specific files and committing are covered by cases
`10` and `47`; pushing an already-prefixed branch is covered by cases `14` and
`16`.

### Case 21

**Prompt:** Создай новую ветку `fix-auth-bug` от trunk.

**Why removed:** case `47` already requires `arc checkout -b <branch> trunk`
as part of a complete create/commit/push workflow.

### Case 39

**Prompt:** Удали серверную ветку
`users/<username>/TICKET-old-feature`.

**Why removed:** case `26` covers the same remote-branch deletion command,
`arc push -d users/<username>/<branch>`.

### Case 41

**Prompt:** Хочу сквошнуть все коммиты ветки в один, но не помню сколько их
было.

**Why removed:** case `44` covers the same merge-base discovery and soft-reset
foundation in a broader commit-regrouping workflow.

### Case 48

**Prompt:** После rebase локальной ветки `TICKET-9999` без префикса
`users/<login>/` нужно запушить переписанную историю.

**Why removed:** unprefixed push recovery is covered by case `54`; the
prefixed/unprefixed force-push distinction remains covered by cases `14` and
`16`.

## Cases moved to executable scenarios

### Case 25 — ambiguous short commit hash

**Former prompt:** Я работаю в локальном Arcadia checkout. Покажи, что было в
коммите `a1b2c3d`.

**Why absent from `evals.json`:** a describe-only answer depends too much on
whether the agent invokes the installed skill. The important behavior is an
observable Arc failure and recovery, so it should be tested by executing
commands against a controlled repository.

**Replacement scenario:** `arc_short_hash_resolution`.

The scenario should:

1. Provide an Arc checkout where `a1b2c3d` is ambiguous.
2. Make a direct `arc show/log a1b2c3d` fail with `TooManyResults` or the
   equivalent ambiguous-hash error.
3. Expose a deterministic way to resolve the prefix to one full 40-character
   hash.
4. Pass only when the agent uses the full hash for the final inspection and
   does not treat the short hash as safe.

Behavior to preserve from the removed eval:

- do not pass a short hash directly to the final `arc show`/`arc log` command;
- explain or demonstrate that short hashes are ambiguous in the monorepo;
- resolve and use a full 40-character hash.

### Case 33 — discard changes in one tracked file

**Former prompt:** Я изменил файл `server/config.go`, но передумал. Верни его к
текущему состоянию ветки.

**Why absent from `evals.json`:** the critical distinction is executable: Arc
accepts `arc checkout server/config.go`, while `arc checkout -- server/config.go`
treats `--` as a literal path. A real modified-file fixture can verify both the
command and its effect without relying on a describe-only skill invocation.

**Replacement scenario:** `arc_discard_modified_file`.

The scenario should:

1. Start with tracked `server/config.go` modified in the working tree.
2. Preserve the committed contents as the expected result.
3. Make `arc checkout -- server/config.go` fail as it does in Arc.
4. Pass only when `arc checkout server/config.go` restores the committed
   contents and the file is clean afterward.
5. Fail if the agent uses a Git command or changes unrelated files.

Behavior to preserve from the removed eval:

- use `arc checkout server/config.go` without the `--` separator;
- do not use `git checkout`;
- restore only the requested file and verify the working-tree result.
