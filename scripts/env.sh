# Общие переменные. Подключается всеми скриптами: source scripts/env.sh
export ROM_ROOT="${ROM_ROOT:-/home/runner/rom}"   # фиксированный путь: ninja хранит абсолютные пути
export SRC="${ROM_ROOT}/src"
export CRDROID_BRANCH="${CRDROID_BRANCH:-15.0}"
export DEVICE="${DEVICE:-ice}"
export VARIANT="${VARIANT:-userdebug}"
export REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Одинаковые значения во всех этапах, чтобы kati/soong не считали окружение изменённым
export BUILD_USERNAME=kilib1k
export BUILD_HOSTNAME=crdroid-ice-ci
export TZ=UTC
export LC_ALL=C.UTF-8
export USE_CCACHE=0
export SKIP_ABI_CHECKS=true
export PATH="${HOME}/bin:${PATH}"
