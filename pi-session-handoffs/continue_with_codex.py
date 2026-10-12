#!/usr/bin/env python3
"""Start a fresh Codex chat from a generated Pi handoff."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import shlex
import subprocess


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("handoff", type=Path, help="Generated .handoff.md file")
    parser.add_argument("--cwd", type=Path, help="Override missing or stale saved working directory")
    parser.add_argument("--dry-run", action="store_true", help="Print command without running Codex")
    args = parser.parse_args()

    bundle = Path(__file__).resolve().parent
    handoff = args.handoff.resolve()
    handoff.relative_to(bundle / "handoffs")
    manifest = json.loads((bundle / "manifest.json").read_text(encoding="utf-8"))
    relative = handoff.relative_to(bundle).as_posix()
    entry = next((item for item in manifest if item["handoff"] == relative), None)
    if entry is None:
        raise SystemExit(f"Handoff not found in manifest: {relative}")

    cwd = args.cwd.resolve() if args.cwd else Path(entry["cwd"])
    if not cwd.is_dir():
        raise SystemExit(f"Working directory does not exist: {cwd}. Pass --cwd with its current location.")
    prompt = (
        f"Read Pi handoff at {handoff}. Continue unfinished work from that history. "
        "First verify current repository state; do not replay old tool calls blindly."
    )
    command = ["codex", "-C", str(cwd), prompt]
    if args.dry_run:
        print(shlex.join(command))
        return 0
    return subprocess.run(command, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
