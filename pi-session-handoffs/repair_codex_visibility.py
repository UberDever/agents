#!/usr/bin/env python3
"""Make imported Pi rollouts discoverable by Codex thread/list."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import sqlite3
from typing import Any


DEFAULT_BUNDLE = Path(__file__).resolve().parent
DEFAULT_STATE_DB = Path("/home/uberdever/.codex/state_5.sqlite")
MARKER_PREFIX = "Imported historical Pi session: "


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, default=DEFAULT_BUNDLE)
    parser.add_argument("--state-db", type=Path, default=DEFAULT_STATE_DB)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--pi-id")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def has_marker(records: list[dict[str, Any]], marker: str) -> bool:
    return any(
        record.get("type") == "event_msg"
        and record.get("payload", {}).get("type") == "user_message"
        and record.get("payload", {}).get("message") == marker
        for record in records
    )


def main() -> int:
    args = parse_args()
    bundle = args.bundle.resolve()
    imported: dict[str, dict[str, Any]] = load_json(bundle / "codex_import_manifest.json")
    entries = list(imported.items())
    if args.pi_id is not None:
        entries = [entry for entry in entries if entry[0] == args.pi_id]
        if not entries:
            raise RuntimeError(f"Pi session missing from import manifest: {args.pi_id}")
    if args.limit is not None:
        entries = entries[: args.limit]

    connection = sqlite3.connect(f"file:{args.state_db}?mode=ro", uri=True)
    backup_dir = bundle / "codex_rollout_backups"
    repaired = 0
    skipped = 0

    for pi_id, metadata in entries:
        thread_id = str(metadata["thread_id"])
        row = connection.execute(
            "SELECT rollout_path FROM threads WHERE id = ?", (thread_id,)
        ).fetchone()
        if row is None:
            raise RuntimeError(f"Codex thread missing from state DB: {thread_id}")

        rollout = Path(str(row[0]))
        records = [json.loads(line) for line in rollout.read_text(encoding="utf-8").splitlines()]
        if not records or records[0].get("payload", {}).get("id") != thread_id:
            raise RuntimeError(f"Unexpected rollout identity: {rollout}")
        if not any(pi_id in json.dumps(record, ensure_ascii=False) for record in records):
            raise RuntimeError(f"Pi session ID {pi_id} missing from rollout {rollout}")

        marker = f"{MARKER_PREFIX}{pi_id}"
        if has_marker(records, marker):
            skipped += 1
            continue

        print(f"{pi_id}\t{thread_id}\t{rollout}")
        if args.dry_run:
            continue

        backup_dir.mkdir(parents=True, exist_ok=True)
        backup = backup_dir / rollout.name
        if not backup.exists():
            shutil.copy2(rollout, backup)

        event = {
            "timestamp": datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace(
                "+00:00", "Z"
            ),
            "type": "event_msg",
            "payload": {"type": "user_message", "message": marker},
        }
        with rollout.open("a", encoding="utf-8") as output:
            output.write(json.dumps(event, ensure_ascii=False, separators=(",", ":")) + "\n")
            output.flush()
        repaired += 1

    connection.close()
    print(f"repaired={repaired} skipped={skipped} selected={len(entries)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
