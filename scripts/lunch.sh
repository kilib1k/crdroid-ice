# Подключается через source: настраивает окружение сборки и делает lunch.
source build/envsetup.sh
REL=""
if [[ -f vendor/lineage/vars/aosp_target_release ]]; then
  # shellcheck disable=SC1091
  source vendor/lineage/vars/aosp_target_release
  REL="${aosp_target_release:-}"
fi
if [[ -n "$REL" ]]; then
  lunch "lineage_${DEVICE}-${REL}-${VARIANT}" || lunch "lineage_${DEVICE}-${VARIANT}"
else
  lunch "lineage_${DEVICE}-${VARIANT}"
fi
