#!/bin/sh
set -eu

memsearch config set embedding.provider onnx >/dev/null
exec pi "$@"
