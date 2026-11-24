#!/usr/bin/env bash
# После sync и патчей: удаляет git-объекты (~28–30 ГБ) и неиспользуемые версии clang.
# Сборке git не нужен; единственное место, где crDroid зовёт repo (build-manifest.xml),
# переключается на сохранённый pinned-манифест.
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$SRC"

# 1) build-manifest.xml: брать готовый pinned-манифест вместо `repo manifest -r`
MK=vendor/lineage/build/tasks/build-manifest_xml.mk
if [[ -f "$MK" ]]; then
  sed -i "s#python3 .repo/repo/repo manifest -o - -r#cat $ROM_ROOT/pinned.xml#" "$MK"
  echo "[prune] $MK -> pinned.xml"
fi

# 2) Лишние версии clang (оставляем дефолтную для soong, clang-stable и упомянутые в build/vendor)
CL=prebuilts/clang/host/linux-x86
if [[ -d "$CL" ]]; then
  keep="$(grep -rhoE 'clang-r[0-9]+[a-z]?' build/soong build/make/core build/make/target \
          vendor/lineage/config vendor/lineage/build 2>/dev/null | sort -u | tr '\n' ' ')"
  echo "[prune] clang оставить: $keep clang-stable"
  for d in "$CL"/clang-r*; do
    n=$(basename "$d")
    [[ " $keep " == *" $n "* ]] && continue
    echo "[prune] rm $d ($(du -sh "$d" | cut -f1))"; rm -rf "$d"
  done
fi

# 3) git-объекты
if [[ "${KEEP_GIT:-0}" != 1 ]]; then
  du -sh .repo/project-objects .repo/projects 2>/dev/null || true
  rm -rf .repo/project-objects .repo/projects
fi
df -h "$ROM_ROOT"
sudo btrfs filesystem usage -T "$ROM_ROOT" 2>/dev/null | head -8 || true
