# Pi session handoff bundle

Raw Pi JSONL stays under `raw/sessions`. Generated handoffs contain initial request plus recent active-branch dialogue; transcripts contain all visible active-branch user/assistant text. Hidden thinking and bulky tool payloads remain only in raw JSONL.

Run commands below from this directory. Requires Python 3.10+, Docker for volume
export, and Codex for continuation/import. Session exports, manifests, database
snapshots, and rollout backups are local artifacts excluded from version control.

Regenerate after volume changes:

```bash
./refresh_from_volume.sh
```

List sessions in `INDEX.md`. Preview continuation command:

```bash
./continue_with_codex.py --dry-run handoffs/<workspace>/<session>.handoff.md
```

Remove `--dry-run` to start fresh Codex chat in saved working directory. New chat receives handoff as historical context; this does not mutate Codex internal session storage.

If saved working directory moved, override it explicitly:

```bash
./continue_with_codex.py handoffs/<workspace>/<session>.handoff.md --cwd /current/project/path
```

Import every handoff as its own persisted Codex thread without running a model turn:

```bash
python3 import_into_codex.py --dry-run
python3 import_into_codex.py
```

`codex_import_manifest.json` records Pi session IDs and created Codex thread IDs. Reruns skip imported sessions and continue pending ones.

Import uses the Codex app-server protocol and a model default captured when these
tools were written. Check compatibility with the installed Codex before importing.
`repair_codex_visibility.py` is a historical repair utility that appends markers to
Codex rollout files after making backups; it is not part of normal continuation.
Use its `--dry-run` and explicit `--state-db` first if repair is needed.
