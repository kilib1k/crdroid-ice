#!/usr/bin/env bash
# Один этап сборки с ограничением по времени.
#   build-stage.sh <deadline_epoch> [resumed=0|1] [target=bacon]
# Пишет результат в $ROM_ROOT/status: done | timeout | failed
set -uo pipefail
source "$(dirname "$0")/env.sh"
DEADLINE="$1"; RESUMED="${2:-0}"; TARGET="${3:-bacon}"
cd "$SRC"

set +u
source "$REPO_DIR/scripts/lunch.sh" || { echo failed > "$ROM_ROOT/status"; exit 1; }
set -u

if [[ "$RESUMED" == 1 ]]; then
  # Исходники свежесинхронизированы => их mtime новее out/. Делаем их "старыми",
  # чтобы ninja не пересобирал всё, что уже собрано на прошлых этапах.
  echo "[stage] выставляю старый mtime исходникам..."
  find . -path ./out -prune -o -path ./.repo -prune -o -print0 \
    | xargs -0 -P"$(nproc)" -n 5000 touch -h -d @946684800 -- 2>/dev/null || true
fi

NOW=$(date +%s); SECS=$(( DEADLINE - NOW ))
echo "[stage] на сборку осталось $(( SECS / 60 )) мин"
if (( SECS < 600 )); then echo timeout > "$ROM_ROOT/status"; exit 0; fi

JOBS=$(nproc)
timeout -s INT -k 600 "$SECS" build/soong/soong_ui.bash --make-mode "$TARGET" -j"$JOBS"
rc=$?
case $rc in
  0)   echo done    > "$ROM_ROOT/status" ;;
  124) echo timeout > "$ROM_ROOT/status" ;;
  *)   echo failed  > "$ROM_ROOT/status" ;;
esac
echo "[stage] soong_ui rc=$rc status=$(cat "$ROM_ROOT/status")"
df -h "$ROM_ROOT"; du -sh out 2>/dev/null || true
exit 0
