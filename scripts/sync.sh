#!/usr/bin/env bash
# Синхронизация исходников crDroid + device/vendor/kernel для ice.
#   sync.sh            — по локальному манифесту (первый этап), сохраняет pinned.xml
#   sync.sh pinned.xml — по зафиксированному манифесту (последующие этапы)
set -euo pipefail
source "$(dirname "$0")/env.sh"
PINNED="${1:-}"
mkdir -p "$SRC"; cd "$SRC"

repo init -q --depth=1 --no-clone-bundle --git-lfs \
  -u https://github.com/crdroidandroid/android.git -b "$CRDROID_BRANCH"

JOBS=$(( $(nproc) * 4 ))
SYNC_ARGS=(-c -j"$JOBS" --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune --fail-fast)

if [[ -n "$PINNED" ]]; then
  rm -rf .repo/local_manifests
  cp "$PINNED" .repo/manifests/pinned.xml
  sync_cmd=(repo sync -m pinned.xml "${SYNC_ARGS[@]}")
else
  mkdir -p .repo/local_manifests
  cp "$REPO_DIR/manifests/$CRDROID_BRANCH/"*.xml .repo/local_manifests/
  sync_cmd=(repo sync "${SYNC_ARGS[@]}")
fi

for try in 1 2 3; do
  if "${sync_cmd[@]}"; then break; fi
  echo "::warning::repo sync, попытка $try не удалась — повтор"
  [[ $try == 3 ]] && exit 1
  sleep 20
done

if [[ -z "$PINNED" ]]; then
  repo manifest -r -o "$ROM_ROOT/pinned.xml"
  echo "Pinned manifest: $ROM_ROOT/pinned.xml"
fi
du -sh "$SRC" 2>/dev/null || true
df -h "$ROM_ROOT"
