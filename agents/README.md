# Shared agent setup

This directory holds personal instructions and project/language skills shared by
Codex, Claude Code, and boxed Pi. Superpowers is installed through each harness's
native plugin manager, rather than copied into `skills/`.

## Instruction loading

The current host configuration is:

| Harness | Entry point | Shared source |
| --- | --- | --- |
| Codex | `~/.codex/AGENTS.md` symlink | `~/dev/agents/agents/AGENTS.md` |
| Claude Code | `@~/dev/agents/agents/AGENTS.md` in `~/.claude/CLAUDE.md` | Same file |
| Boxed Pi | Read-only bind mount at `~/.pi/agent/AGENTS.md` | Same file |

On another host, create the Codex symlink only if its destination is absent;
otherwise inspect and reconcile the existing file. Add the import to Claude's
existing user instructions without replacing its other content:

```bash
mkdir -p ~/.codex ~/.claude
ln -s "$HOME/dev/agents/agents/AGENTS.md" "$HOME/.codex/AGENTS.md"
```

```markdown
@~/dev/agents/agents/AGENTS.md
```

Check `CODEX_HOME` and `AGENTS.override.md` if Codex loads a different profile.
Claude's wrapper imports the shared response policy without a local response-mode
override. Shared local skill discovery is separate from plugin installation.

## Response policy: ASD-STE100 plus brevity

All three harnesses must load `asd-ste100` before the first response or task action.
They should prefer concise answers and omit repetition and filler.
They must include the detail needed for accuracy and understanding. Brevity is guidance, not a minimum-length target.
STE preserves complete sentences, conditions, scope, and uncertainty.
Use Strict mode for procedures, errors, tool descriptions, and instructions between agents.
Use STE-flavored mode for explanations and other prose.

Caveman remains installed but is disabled, including for internal reasoning.
Only an explicit user request can enable it. Brevity requests do not activate it automatically.
The former Claude-only “thinking only” override was removed on 2026-10-19.

The pinned upstream files are in `skills/asd-ste100/`.
`UPSTREAM.md` records the commit, version, and MIT license.
The existing Codex and Claude symlinks and Pi mount expose this skill through the same paths as Ponytail below.
No new plugin or hook is required.

Run the included structural checks with Python 3:

```bash
python3 agents/skills/asd-ste100/scripts/ste-lint.py --selftest
python3 agents/skills/asd-ste100/scripts/ste-lint.py path/to/document.md
```

The linter checks selected structural patterns. It does not prove meaning preservation or certified STE compliance.
Keep local activation policy in `AGENTS.md`. Keep the upstream files unchanged when updating the pinned copy.

Verified on 2026-10-19: fresh Claude and boxed Pi sessions loaded ASD-STE100, then Ponytail, before reading the task fixture.
Neither session loaded caveman, despite a “Be brief” request. Codex's skill inventory reports ASD-STE100 enabled.
The linter self-test passes on the host and inside Pi. Codex's model compatibility limit remains as described below.

Upstream: https://github.com/danyuchn/asd-ste100-skill

## Ponytail: mandatory startup discipline

Startup order is **ASD-STE100 → ponytail (full) → Superpowers → task-specific
skills/work**. `AGENTS.md` makes Ponytail the first work instruction immediately
after response-mode activation, including on resumed work unless the user has
changed or disabled it. The fallback read path works inside the box as well as
on the host.

The upstream core skill is vendored unchanged at `skills/ponytail/SKILL.md`, with
its MIT license and pinned source recorded in `skills/ponytail/UPSTREAM.md`.
Existing discovery paths expose the same file:

| Harness | Skill path | Mechanism |
| --- | --- | --- |
| Codex | `~/.agents/skills/ponytail/SKILL.md` | `~/.agents` symlink to this directory |
| Claude Code | `~/.claude/skills/ponytail/SKILL.md` | `~/.claude/skills` symlink to `skills/` |
| Boxed Pi | `~/.agents/skills/ponytail/SKILL.md` | Existing read-only `pi-box/box` bind mount |

No extra plugin, lifecycle hook, mode-state file, or companion command is needed
for this instruction-and-skill integration. Startup ordering is an instruction
to the agent, not a harness-level execution barrier. Upstream plugin hooks and
review/audit commands are outside this installation's scope.

On another host, inspect existing paths before adding the corresponding symlinks
or skill-directory configuration. Keep one shared copy. For updates, review a
specific upstream commit, replace the core skill and license from that commit,
and update `UPSTREAM.md`; keep local startup policy in `AGENTS.md`.

Verify from a fresh session in each harness: request a tiny coding task without
naming either skill and inspect the transcript for ASD-STE100 then Ponytail loading
before task exploration or editing. Hooks may have injected Superpowers already;
that does not prove or disprove the agent's order of applying instructions.
Check actual reads/invocations rather than only the agent's self-report.

Before the STE policy change on 2026-10-19, fresh Claude and boxed Pi sessions loaded caveman, then
Ponytail, then the task fixture without the prompt naming either skill. Codex
`skills/list` reported Ponytail enabled at the shared path. A model-backed Codex
check could not run: the configured `gpt-6-astra` required a newer CLI, and the
previously working per-invocation `gpt-5.5` fallback was rejected for this
ChatGPT account. No persistent model setting was changed. Recheck Codex startup
behavior after resolving that CLI/model compatibility issue.

Upstream: https://github.com/DietrichGebert/ponytail

## Install Superpowers

Claude's official marketplace is already registered on this host. Install at
user scope so it applies across projects:

```bash
claude plugin install superpowers@claude-plugins-official --scope user
claude plugin list
```

If that marketplace is missing on another host, register it first:

```bash
claude plugin marketplace add anthropics/claude-plugins-official
```

Codex has a built-in official marketplace. Install directly from it:

```bash
codex plugin marketplace list --json
codex plugin list --available --json
codex plugin add superpowers@openai-curated --json
codex plugin list --json
```

Do not run `codex plugin marketplace add openai/plugins`: current Codex rejects
registering that source because `openai-curated` is a reserved marketplace name.
If Superpowers is absent, check the native `/plugins` interface and the installed
CLI's help rather than creating or editing a counterfeit official marketplace.

On this host, Codex 0.144.1's default remote-catalog mode omitted the locally
installed official plugin from both `skills/list` and fresh `codex exec`
sessions. The verified compatibility settings in `~/.codex/config.toml` are:

```toml
[features]
multi_agent = true
remote_plugin = false
```

Merge these keys into an existing feature section rather than creating a second
one. `remote_plugin = false` selects the local curated marketplace; it also turns
off remote-directory discovery, so do not apply it blindly on a host relying on
remote plugins. This host's other enabled plugins are local and remain available.
Re-evaluate the setting after a CLI update or when adopting remote plugins.

Installation is per harness. Restart existing sessions after installing or
changing instructions; a running session's skill catalog may stay unchanged.

## Workflow and duplicate skills

`AGENTS.md` explicitly overrides Superpowers' blanket approval gates for routine,
reversible changes and authorized experiments. Consequential design choices still
need agreement. Larger work uses written designs and revisable implementation
plans; small work proceeds in verifiable increments without mandatory documents.

Prefer namespaced plugin debugging and verification skills when available. The
local copies remain fallback skills for environments without Superpowers,
including the current boxed Pi setup. Do not run both copies for the same gate.
Language, project, memory, and boxed-tool skills remain applicable.

Codex's packaged plugin currently has no startup hook, so shared `AGENTS.md`
explicitly requests its `using-superpowers` bootstrap. Claude's plugin injects
that bootstrap with its SessionStart hook. An injected full bootstrap need not be
loaded again. Do not infer startup behavior from the plugin name alone.

Subagent workflows need the harness's actual agent tools. Enable Codex's
`multi_agent` feature when using those workflows; use supported tool/model names
from the current session. Installing a skill does not grant tool capabilities or
override harness restrictions.

Keep the existing ClickHouse artifact routing: specs, plans, scratch files, and
durable memory belong under the checkout's external artifact directory. Keep
MemSearch and tatr on the approved boxed execution route. Plugin installation
does not change these policies.

## Verify in fresh sessions

First check the instruction links/imports and enabled plugin inventories. Then
use disposable directories under `/tmp` for model-backed smoke checks; keep
transcripts and fixtures out of this repository's published files.

Check three behaviors separately:

1. **Bootstrap:** start a fresh session and ask it to identify the shared workflow
   and available Superpowers skills. Inspect actual skill reads/invocations or
   startup-hook output, not only the agent's assertion.
2. **Routine change:** create a tiny existing text fixture and request a precise
   reversible edit. It should inspect, perform, and verify the edit without a
   separate design gate or plan/spec files.
3. **Exploration:** ask a narrow feasibility question, explicitly authorizing a
   throwaway probe. It should gather evidence and report the answer without
   turning the spike into production work or starting the full planning chain.

Inspect output files and transcripts for expected skill selection, observed
results, redundant approval requests, and unwanted artifacts. Model-backed
checks consume the harness's normal usage allowance; they require working auth
and network access. Do not bypass sandbox or permission checks to make them pass.

The configured Codex model `gpt-6.1-sol` was rejected by this CLI's ChatGPT-account
endpoint during the 2026-10-12 checks. A per-invocation `--model gpt-5.5` allowed
the checks to run; the configured default was left unchanged. This is evidence
for the tested model and session, not proof that the default-model/account path
works. Check current account availability before choosing a fallback; do not
treat this historical model name as a permanent setup recommendation.

## Updates and versions

Use native plugin managers; do not edit versioned caches or copy individual
upstream skills to fill version gaps. For Claude:

```bash
claude plugin marketplace update claude-plugins-official
claude plugin update superpowers@claude-plugins-official --scope user
```

For Codex, use the native `/plugins` interface for available updates and consult
`codex plugin --help`. `marketplace upgrade` refreshes configured Git sources;
it is not an update command for the reserved built-in marketplace. After any
update, restart and repeat the relevant smoke checks.

Installed on 2026-10-12:

| Harness | Plugin version | Skill count | Known difference |
| --- | --- | --- | --- |
| Claude Code 2.1.292 | 6.4.1 | 15 | Includes `diagnosing-superpowers` |
| Codex CLI 0.144.1 | Manifest 6.3.0; cache revision `0722921d` | 14 | No `diagnosing-superpowers` |

Use the installed inventory as the source of truth. Marketplace releases can
lag upstream and differ between harnesses.

Codex refreshed its native cache during these checks, replacing revision
`1e285826` with `0722921d` while keeping manifest version 6.3.0. Re-scan the
inventory if a listed skill path disappears during a native refresh; do not
hardcode a cache revision in shared instructions or symlinks. Run setup smoke
checks sequentially when native cache refreshes may occur.

References:

- https://github.com/obra/superpowers
- https://developers.openai.com/codex/guides/agents-md
- https://learn.chatgpt.com/docs/developer-commands#codex-plugin
- https://code.claude.com/docs/en/memory#import-additional-files
- https://code.claude.com/docs/en/discover-plugins
