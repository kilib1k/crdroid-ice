#!/usr/bin/env bash
# Распаковывает out/ из частей, полученных с прошлого этапа.
set -euo pipefail
source "$(dirname "$0")/env.sh"
mkdir -p "$SRC"
ls -lh "$ROM_ROOT/parts"
cat "$ROM_ROOT/parts"/out.tar.zst.* | zstd -d -T0 -q | tar -C "$SRC" -xf -
rm -rf "$ROM_ROOT/parts"
du -sh "$SRC/out"; df -h "$ROM_ROOT"
