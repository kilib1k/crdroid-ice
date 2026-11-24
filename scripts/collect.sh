#!/usr/bin/env bash
# Собирает готовые файлы прошивки в $ROM_ROOT/release
set -euo pipefail
source "$(dirname "$0")/env.sh"
P="$SRC/out/target/product/$DEVICE"
D="$ROM_ROOT/release"; mkdir -p "$D"
shopt -s nullglob
for f in "$P"/crDroidAndroid-*.zip "$P"/*-"$DEVICE"-*.zip; do
  [[ "$f" == *-ota-* || "$f" == *target_files* ]] && continue
  cp -v "$f" "$D/"
done
for f in boot.img dtbo.img vbmeta.img vbmeta_system.img vbmeta_vendor.img super_empty.img; do
  [[ -f "$P/$f" ]] && cp -v "$P/$f" "$D/"
done
( cd "$D" && sha256sum * > SHA256SUMS )
ls -lh "$D"
