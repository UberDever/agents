#!/usr/bin/env bash
set -euo pipefail

bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "${bundle_dir}/raw"

docker run --rm \
    --mount source=pi-box-home,target=/volume,readonly \
    alpine:latest \
    tar -C /volume/.pi/agent -cf - sessions \
    | tar -C "${bundle_dir}/raw" -xf -

python3 "${bundle_dir}/pi_to_handoff.py" \
    "${bundle_dir}/raw/sessions" \
    --output "${bundle_dir}"
