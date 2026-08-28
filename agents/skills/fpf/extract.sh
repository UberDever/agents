#!/usr/bin/env bash
# Extract one FPF pattern body (or list matching headings) from the vendored spec.
#
#   extract.sh C.32.ADR        -> print the full body of pattern C.32.ADR
#   extract.sh --list          -> print all top-level '## ' headings with line numbers
#   extract.sh --grep <regex>  -> print headings whose title matches <regex> (case-insensitive)
set -euo pipefail
SPEC="$(dirname "$(readlink -f "$0")")/spec/FPF-Spec.md"

case "${1:-}" in
  --list)
    grep -n '^## ' "$SPEC"
    ;;
  --grep)
    grep -in "^## .*${2:?usage: extract.sh --grep <regex>}" "$SPEC"
    ;;
  "")
    echo "usage: extract.sh <PATTERN-ID> | --list | --grep <regex>" >&2
    exit 2
    ;;
  *)
    # Pattern headings look like '## C.32.ADR - Title'. Match the ID exactly
    # (up to the following separator) so C.3 does not swallow C.30.
    id="$1"
    awk -v id="$id" '
      /^## / {
        if (found) exit
        # heading id = text between "## " and the first " -" / " —" separator
        h = $0; sub(/^## +/, "", h); sub(/ +[-—].*$/, "", h)
        gsub(/[`*]/, "", h)
        if (h == id) found = 1
      }
      found { print }
    ' "$SPEC"
    ;;
esac
