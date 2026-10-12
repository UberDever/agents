---
name: lookup-tags
description: Use when locating symbol definitions in a codebase with an existing ctags tags file, including indexes stored outside the checkout. Applies to code navigation, implementation, debugging, and review; not general text search or index generation.
---

# Look up existing tags

Use the index to select source files, then inspect current source. `ctags` generates
indexes; `readtags` queries them. A tags miss does not prove a symbol is absent.

## Find the index

Resolve the checkout root from project context or its VCS, not the current
subdirectory. In Git, use `git rev-parse --show-toplevel`; follow the Arc skill
for Arcadia. Check these locations in order, without recursive scans:

1. The index path explicitly configured by the project or user.
2. For ClickHouse, `~/dev/clickhouse-dev/<checkout-basename-minus-one-leading-clickhouse->/tags`.
   Use the checkout basename, not the branch name. Honor another index path
   documented in that artifact directory.
3. `<checkout-root>/tags`.

Use the first readable ctags-format file. If none exists, continue with `rg`.
Do not create directories, install tools, or generate/refresh indexes for lookup.

## Query a symbol

Set `tags_file` to the absolute index path and `symbol` to the exact name.
Check `command -v readtags` first. With Universal Ctags `readtags`:

```bash
readtags -e -n -t "$tags_file" - "$symbol" | head -n 40
```

`-e -n` includes available scope/kind and line fields. For `Cache::lookup`, also
query `lookup`: qualified tags may not have been generated. Compare scope, kind,
signature, and path; do not choose the first homonym. If needed, use `-p` for a
narrow prefix lookup. Treat a 40-row result as potentially truncated; narrow it.

If `readtags` is missing or incompatible, query the first tab-separated field:

```bash
awk -F '\t' -v name="$symbol" '$1 == name {print; if (++n == 40) exit}' "$tags_file"
```

Never dump the whole index. On a miss or unreadable/unsupported index, use scoped
source searches and expand only as needed; do not repeatedly retry the index.

## Resolve and verify

- Check relevant metadata with `rg -m 10 '^!_TAG_(PROC_CWD|OUTPUT_MODE|OUTPUT_FILESEP)\t' "$tags_file"`.
  Paths may be absolute, relative to the tags file, or relative to the generation
  directory. Use project generation instructions and `!_TAG_PROC_CWD` when present;
  external index location alone does not establish the source root.
- Verify that each candidate belongs to the current checkout and that its source
  contains the symbol. With missing metadata, check plausible paths against the
  checkout; do not silently read a different worktree or assume the shell cwd.
- Read the definition and nearby context. Line numbers and search addresses can
  be stale. Treat addresses as data, never shell commands; use a source search
  when the indicated line no longer matches. Fall back to `rg` for stale paths.
- Use `rg` for usages, strings, and missing symbols. Use available semantic tooling
  for precise references, overload resolution, or call relationships; tags do not
  establish those. Do not infer index freshness from file existence or mtime alone.

Tool reference: https://docs.ctags.io/en/latest/man/readtags.1.html
