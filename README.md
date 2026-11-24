# crdroid-ice

Сборка **crDroid** для **Redmi A1 / Redmi A1+ / POCO C50** (кодовое имя `ice`, MediaTek Helio A22 / MT6761) на **бесплатных GitHub Actions**. Это полноценный device-specific ROM, не GSI.

> Неофициальная экспериментальная сборка. Перед прошивкой обязательно сделайте бэкап разделов `nvram`, `nvdata`, `nvcfg`, `persist`, `protect1/2`. Без них после неудачной прошивки можно потерять IMEI.

## Что используется

| Компонент | Репозиторий | Ветка |
|---|---|---|
| ROM | [crdroidandroid/android](https://github.com/crdroidandroid/android) | `15.0` (Android 15) / `14.0` (Android 14) |
| Device tree | [Jagatg/android_device_xiaomi_ice](https://github.com/Jagatg/android_device_xiaomi_ice) | `lineage-22.2` |
| Vendor blobs | [Jagatg/proprietary_android_device_xiaomi_ice](https://github.com/Jagatg/proprietary_android_device_xiaomi_ice) | `lineage-22.2` |
| Kernel (исходники, ядро в tree — prebuilt) | [Jagatg/android_kernel_xiaomi_ice](https://github.com/Jagatg/android_kernel_xiaomi_ice) | `lineage-23.0` |
| MTK HAL | [Jagatg/android_hardware_mediatek](https://github.com/Jagatg/android_hardware_mediatek) | `17.0` |
| MTK sepolicy | [LineageOS/android_device_mediatek_sepolicy_vndr](https://github.com/LineageOS/android_device_mediatek_sepolicy_vndr) | `lineage-22.2` / `lineage-21` |

Device tree написан под LineageOS 22.2 (Android 15), поэтому **рекомендуемая ветка — `15.0` (crDroid 11)**. Ветка `14.0` (crDroid 10, Android 14) экспериментальная: в tree есть зависимости от Android 15 (`prebuilts/vndk/v34`, патчи composer v34), которые для A14 приходится обходить в `patches/14.0`.

## Как запустить сборку

1. **Actions → Build crDroid (ice) → Run workflow**.
2. Выберите ветку (`15.0` или `14.0`) и вариант (`userdebug` по умолчанию).
3. Ждите. Сборка идёт по этапам. Готовый ROM появится во вкладке **Releases**, а также в artifact `crdroid-ice-<ветка>` у запуска.

**Статус:** Check config проходит для обеих веток — `15.0` и `14.0` (sync ~16 мин, `m nothing` ~12 мин). Полная сборка до получения zip пока не подтверждена.

Проверить конфигурацию без полной сборки (около 1 часа) можно через **Actions → Check config (ice)**: там выполняются `repo sync`, `lunch` и `m nothing`, то есть полный разбор Android.bp/Makefile без компиляции. Эта проверка также запускается автоматически при push в `manifests/`, `patches/`, `overrides/`, `scripts/`.

## Как это укладывается в бесплатные Actions

У бесплатного runner'а для публичного репозитория 4 vCPU, 16 ГБ RAM, один диск около 145 ГБ (после очистки ~130 ГБ свободно) и лимит 6 часов на job. Полный checkout crDroid весит ~97 ГБ, а сборка требует ещё десятки ГБ и длится дольше 6 часов на 4 ядрах, поэтому:

- **Место.** `free-space.sh` удаляет предустановленные SDK (.NET, Android SDK, Haskell, CodeQL, Docker-образы, JVM и т. д.). `disk-setup.sh` создаёт образ на всё свободное место, форматирует его в **btrfs** и монтирует в `/home/runner/rom` с `compress-force=zstd:1`. Исходники качаются с `--depth=1`, ненужные проекты (cts, эмуляторы, kernel prebuilts, cuttlefish, darwin/mingw тулчейны, чужие qcom-caf и т. п.) вырезаются через `manifests/<ветка>/remove.xml`, а после sync удаляются git-объекты (`.repo/projects`, `.repo/project-objects`) и неиспользуемые версии clang. В итоге исходники занимают ~31 ГБ на диске, свободно ~80 ГБ под `out/`.
- **Память.** swapfile 24 ГБ + (если доступен) zram 8 ГБ zstd, процессам runner'а выставлен `oom_score_adj=-1000`, чтобы OOM killer не убил сам job во время `soong_build`.
- **Время.** Сборка разбита на цепочку из 8 этапов (`build.yml` → `stage.yml`). Каждый этап:
  1. скачивает `out/` предыдущего этапа (artifact, zstd, части по 1.9 ГБ);
  2. синхронизирует исходники по **pinned-манифесту**, зафиксированному на первом этапе, чтобы ревизии во всех этапах совпадали;
  3. ставит всем исходникам старый mtime (2000-01-01), чтобы ninja не пересобирал уже собранное;
  4. собирает `m bacon` примерно до 5 часов от старта job и затем мягко останавливает ninja (SIGINT);
  5. если не успел, удаляет исходники, пакует `out/` и передаёт его следующему этапу.
  
  Как только `m bacon` завершится успешно, этап публикует Release, а остальные этапы пропускаются. Ожидаемо нужно 3–5 этапов, то есть примерно 15–25 часов реального времени.

## Структура

```
.github/workflows/
  build.yml        — полная сборка (цепочка этапов)
  stage.yml        — один этап (reusable workflow)
  check.yml        — быстрая проверка конфигурации
manifests/<ветка>/ice.xml   — local_manifests (device/vendor/kernel/MTK)
patches/<ветка>/<путь проекта>/*.patch  — патчи поверх исходников (git apply)
patches/<ветка>/fixups.sh   — скриптовые правки (если нужны)
overrides/<ветка>/...       — файлы, копируемые поверх дерева исходников
scripts/                    — free-space, setup-runner, sync, apply-patches, build-stage, pack/unpack, collect
```

## Прошивка (кратко)

1. Разблокированный загрузчик и стоковая прошивка MIUI/HyperOS на базе Android 12 (V13.x) — от неё берётся firmware.
2. Бэкап разделов (см. предупреждение выше).
3. Прошивка: `boot.img` из релиза (recovery встроен в boot, `BOARD_USES_RECOVERY_AS_BOOT`) → загрузка в recovery → `adb sideload crDroidAndroid-*.zip` → Format data.
4. `vbmeta.img` при необходимости: `fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img`.

## Если сборка упала

- У упавшего этапа есть artifact `error-log-stage-N` с `out/error.log`.
- Исправление кладите в `patches/<ветка>/...` или `overrides/<ветка>/...`, сначала гоняйте **Check config**, потом полную сборку.
- Device tree активно развивается, поэтому ошибки могут появиться после очередного коммита в upstream. В таком случае зафиксируйте ревизию через атрибут `revision="<sha>"` в `manifests/<ветка>/ice.xml`.

## Благодарности

[Jagatg](https://github.com/Jagatg) за device/vendor/kernel tree для ice, команде crDroid и LineageOS.
