#!/usr/bin/env bash
# Совместимость device tree / hardware/mediatek (написаны под Android 15+) с Android 14 (crDroid 10).
set -euo pipefail
cd "$SRC"

# 1) hardware/mediatek: thermal AIDL использует тип модуля vintf_fragment (Android 15+).
#    Device tree ice этот HAL не ставит — удаляем.
rm -rf hardware/mediatek/aidl/thermal && echo "[fixups-14] removed hardware/mediatek/aidl/thermal"
