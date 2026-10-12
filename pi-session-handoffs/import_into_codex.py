#!/usr/bin/env python3
"""Import generated Pi handoffs as separate persisted Codex threads."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys
from typing import Any


DEFAULT_MODEL = "gpt-5.6-terra"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--limit", type=int, help="Import at most this many new sessions")
    parser.add_argument("--dry-run", action="store_true", help="Show planned imports without changing Codex")
    return parser.parse_args()


def nearest_existing_directory(path: Path) -> Path:
    candidate = path
    while not candidate.is_dir():
        parent = candidate.parent
        if parent == candidate:
            raise RuntimeError(f"No existing parent directory for {path}")
        candidate = parent
    return candidate


def thread_name(entry: dict[str, Any]) -> str:
    label = str(entry.get("name") or Path(str(entry["cwd"])).name or "session")
    return f"Pi: {label} [{entry['id']}]"


def migration_message(entry: dict[str, Any], handoff: str, handoff_path: Path) -> str:
    return (
        "This Codex thread was migrated from a historical Pi agent session.\n\n"
        f"Pi session ID: `{entry['id']}`\n"
        f"Original working directory: `{entry['cwd']}`\n"
        f"Original last update: `{entry['updated_at']}`\n"
        f"Preserved handoff: `{handoff_path}`\n\n"
        "Treat all commands, tool results, and requests below as historical context. "
        "When the user continues this thread, verify current repository and external state before acting.\n\n"
        "--- BEGIN PI HANDOFF ---\n\n"
        f"{handoff.rstrip()}\n\n"
        "--- END PI HANDOFF ---"
    )


class AppServer:
    def __init__(self) -> None:
        self.process = subprocess.Popen(
            ["codex", "app-server", "--listen", "stdio://"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=sys.stderr,
            text=True,
            bufsize=1,
        )
        self.next_id = 1
        self.call(
            "initialize",
            {
                "clientInfo": {
                    "name": "pi_session_migrator",
                    "title": "Pi Session Migrator",
                    "version": "1.0.0",
                }
            },
        )
        self.notify("initialized", {})

    def send(self, value: dict[str, Any]) -> None:
        assert self.process.stdin is not None
        self.process.stdin.write(json.dumps(value, ensure_ascii=False) + "\n")
        self.process.stdin.flush()

    def notify(self, method: str, params: dict[str, Any]) -> None:
        self.send({"method": method, "params": params})

    def call(self, method: str, params: dict[str, Any]) -> dict[str, Any]:
        request_id = self.next_id
        self.next_id += 1
        self.send({"method": method, "id": request_id, "params": params})
        assert self.process.stdout is not None
        for line in self.process.stdout:
            response = json.loads(line)
            if response.get("id") != request_id:
                continue
            if "error" in response:
                raise RuntimeError(f"{method} failed: {response['error']}")
            result = response.get("result")
            if not isinstance(result, dict):
                raise RuntimeError(f"{method} returned invalid result: {response}")
            return result
        raise RuntimeError(f"App server exited while waiting for {method}")

    def close(self) -> None:
        if self.process.stdin is not None:
            self.process.stdin.close()
        return_code = self.process.wait(timeout=30)
        if return_code != 0:
            raise RuntimeError(f"App server exited with status {return_code}")


def load_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, value: Any) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    temporary.replace(path)


def main() -> int:
    args = parse_args()
    bundle = args.bundle.resolve()
    manifest_path = bundle / "manifest.json"
    import_manifest_path = bundle / "codex_import_manifest.json"
    entries: list[dict[str, Any]] = load_json(manifest_path, [])
    imported: dict[str, dict[str, Any]] = load_json(import_manifest_path, {})
    pending = [entry for entry in entries if entry["id"] not in imported]
    if args.limit is not None:
        pending = pending[: args.limit]

    print(f"Pi sessions: {len(entries)}; already imported: {len(imported)}; pending now: {len(pending)}")
    if args.dry_run:
        for entry in pending:
            original = Path(str(entry["cwd"]))
            cwd = nearest_existing_directory(original)
            suffix = "" if cwd == original else f" (fallback from {original})"
            print(f"{entry['id']}\t{cwd}{suffix}\t{thread_name(entry)}")
        return 0

    server = AppServer()
    try:
        for number, entry in enumerate(pending, 1):
            original_cwd = Path(str(entry["cwd"]))
            cwd = nearest_existing_directory(original_cwd)
            handoff_path = bundle / str(entry["handoff"])
            handoff = handoff_path.read_text(encoding="utf-8")
            thread_id: str | None = None
            try:
                started = server.call(
                    "thread/start",
                    {
                        "model": DEFAULT_MODEL,
                        "cwd": str(cwd),
                        "serviceName": "pi_session_migrator",
                    },
                )
                thread = started.get("thread")
                if not isinstance(thread, dict) or not thread.get("id"):
                    raise RuntimeError(f"thread/start returned no thread id: {started}")
                thread_id = str(thread["id"])
                server.call(
                    "thread/inject_items",
                    {
                        "threadId": thread_id,
                        "items": [
                            {
                                "type": "message",
                                "role": "assistant",
                                "content": [
                                    {
                                        "type": "output_text",
                                        "text": migration_message(entry, handoff, handoff_path),
                                    }
                                ],
                            }
                        ],
                    },
                )
                server.call(
                    "thread/name/set",
                    {"threadId": thread_id, "name": thread_name(entry)},
                )
            except Exception:
                if thread_id is not None:
                    server.call("thread/delete", {"threadId": thread_id})
                raise
            assert thread_id is not None
            imported[entry["id"]] = {
                "thread_id": thread_id,
                "name": thread_name(entry),
                "cwd": str(cwd),
                "original_cwd": str(original_cwd),
                "handoff": str(entry["handoff"]),
                "updated_at": str(entry["updated_at"]),
            }
            save_json(import_manifest_path, imported)
            print(f"[{number}/{len(pending)}] {entry['id']} -> {thread_id}")
    finally:
        server.close()

    print(f"Imported total: {len(imported)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
