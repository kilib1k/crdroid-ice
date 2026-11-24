#!/usr/bin/env bash
# Применяет патчи и оверрайды из этого репозитория поверх исходников.
#   patches/<branch>/<путь/проекта>/*.patch  -> git apply в <путь/проекта>
#   overrides/<branch>/<любой/путь>           -> копируется поверх дерева исходников
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$SRC"

PDIR="$REPO_DIR/patches/$CRDROID_BRANCH"
if [[ -d "$PDIR" ]]; then
  while IFS= read -r -d '' p; do
    rel="${p#$PDIR/}"; proj="$(dirname "$rel")"
    if git -C "$proj" apply --reverse --check "$p" >/dev/null 2>&1; then
      echo "[patch] уже применён: $rel"
    elif git -C "$proj" apply --whitespace=nowarn "$p"; then
      echo "[patch] OK: $rel"
    else
      echo "::error::[patch] не применился: $rel"; exit 1
    fi
  done < <(find "$PDIR" -name '*.patch' -print0 | sort -z)
fi

ODIR="$REPO_DIR/overrides/$CRDROID_BRANCH"
if [[ -d "$ODIR" ]] && [[ -n "$(find "$ODIR" -type f ! -name .gitkeep -print -quit)" ]]; then
  rsync -a --exclude .gitkeep "$ODIR/" "$SRC/"
  echo "[override] скопированы файлы из overrides/$CRDROID_BRANCH"
fi

# Хук для правок, которые проще сделать скриптом
HOOK="$REPO_DIR/patches/$CRDROID_BRANCH/fixups.sh"
[[ -x "$HOOK" ]] && { echo "[fixups] $HOOK"; SRC="$SRC" bash "$HOOK"; }

# vendorsetup.sh из device tree применяет свои патчи (hardware/interfaces) при envsetup —
# прогоняем один раз сейчас, пока git-объекты ещё на месте.
( set +eu; source build/envsetup.sh 2>&1 | grep '\[ice-patches\]' ) || true
true
