#!/usr/bin/env bash
# S3 stack installer: Pi + memsearch + conventions. See INSTALL.md for the human story.
# Usage:
#   ./install.sh machine              # once per machine
#   ./install.sh project <dir>        # once per project
set -euo pipefail

PI_VERSION="0.80.6"
MEMSEARCH_VERSION="0.4.13"

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHARTER_MARKER="<!-- s3-charter -->"

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }

need() { command -v "$1" >/dev/null 2>&1 || die "missing prerequisite: $1"; }

machine() {
  need npm; need uv; need git; need python3

  node_major="$(node -e 'console.log(process.versions.node.split(".")[0])' 2>/dev/null || echo 0)"
  [ "$node_major" -ge 20 ] || die "Node.js >= 20 required (found major: $node_major)"

  info "Installing Pi ${PI_VERSION}"
  npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@${PI_VERSION}"

  info "Installing memsearch ${MEMSEARCH_VERSION} (ONNX local embeddings)"
  uv tool install --force "memsearch[onnx]==${MEMSEARCH_VERSION}"

  info "Pre-caching ONNX embedding model (one-time HuggingFace download)"
  memsearch search warmup --collection warmup --provider onnx >/dev/null 2>&1 || true

  info "Machine setup done. Configure model access (see INSTALL.md Part A), e.g.:"
  echo "    export OPENAI_API_KEY=sk-...   # in your shell profile"
}

project() {
  local proj="${1:-}"
  [ -n "$proj" ] || die "usage: ./install.sh project <dir>"
  proj="$(cd "$proj" && pwd)" || die "no such directory: $1"
  command -v memsearch >/dev/null 2>&1 || die "run './install.sh machine' first"

  info "Memory home: $proj/.memsearch/memory"
  mkdir -p "$proj/.memsearch/memory"

  info "Conventions charter -> AGENTS.md"
  if [ -f "$proj/AGENTS.md" ] && grep -qF "$CHARTER_MARKER" "$proj/AGENTS.md"; then
    echo "    charter already present, skipping"
  else
    { [ -f "$proj/AGENTS.md" ] && printf '\n'; cat "$KIT_DIR/templates/AGENTS-charter.md"; } \
      >> "$proj/AGENTS.md"
  fi

  info "Memory skill -> .agents/skills/memory/"
  mkdir -p "$proj/.agents/skills"
  cp -r "$KIT_DIR/templates/skills/memory" "$proj/.agents/skills/"

  if find "$proj/.memsearch/memory" -name '*.md' | grep -q .; then
    info "Indexing existing memory seeds"
    (cd "$proj" && memsearch index .memsearch/memory/)
  fi

  info "Project setup done. Next:"
  echo "    - knowledge/skills migration: see MIGRATION.md"
  echo "    - commit: .memsearch/memory/ .agents/ AGENTS.md"
  echo "    - start:  cd $proj && pi"
}

case "${1:-}" in
  machine) machine ;;
  project) shift; project "$@" ;;
  *) die "usage: ./install.sh machine | ./install.sh project <dir>" ;;
esac
