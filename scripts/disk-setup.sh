#!/usr/bin/env bash
# Объединяет свободное место корневого диска и /mnt в один том btrfs с прозрачным
# сжатием zstd (исходники Android и out/ сжимаются примерно в 1.5–2.5 раза), плюс swap.
#   disk-setup.sh <mountpoint> <swap_gb>
set -euo pipefail
MP="${1:-/home/runner/rom}"; SWAP_GB="${2:-12}"
sudo swapoff -a || true
sudo rm -f /mnt/swapfile /swapfile || true

# swap на /mnt (ext4)
SWAPF=/mnt/swapfile
sudo fallocate -l "${SWAP_GB}G" "$SWAPF"
sudo chmod 600 "$SWAPF"; sudo mkswap -q "$SWAPF"; sudo swapon -p 0 "$SWAPF"

# zram (сжатый swap в RAM) с более высоким приоритетом — необязательно
( set +e
  sudo modprobe zram 2>/dev/null
  Z=$(sudo zramctl --find --size 8G --algorithm zstd 2>/dev/null)
  [[ -n "$Z" ]] && sudo mkswap -q "$Z" && sudo swapon -p 100 "$Z" && echo "zram: $Z"
) || echo "zram недоступен — пропускаю"
sudo sysctl -qw vm.swappiness=100 vm.overcommit_memory=1 || true

# Не дать OOM-killer'у убить агент GitHub Actions (иначе job "canceled")
for p in $(pgrep -f 'Runner.Listener|Runner.Worker|actions-runner' || true); do
  echo -1000 | sudo tee /proc/$p/oom_score_adj >/dev/null 2>&1 || true
done

df -h / /mnt || true
ROOT_DEV=$(df --output=source / | tail -1); MNT_DEV=$(df --output=source /mnt | tail -1)
root_free=$(df --output=avail -B1M / | tail -1)
IMGS=()
if [[ "$ROOT_DEV" != "$MNT_DEV" ]]; then
  mnt_free=$(df --output=avail -B1M /mnt | tail -1)
  MNT_IMG_MB=$(( mnt_free - 1024 ))
  echo "/mnt — отдельный диск ($MNT_DEV): img ${MNT_IMG_MB} MB"
  sudo fallocate -l "${MNT_IMG_MB}M" /mnt/pv-mnt.img; IMGS+=(/mnt/pv-mnt.img)
else
  echo "/mnt на том же разделе, что и / — используем один образ"
fi
ROOT_IMG_MB=$(( root_free - 5120 ))   # оставить ~5 ГБ корню (логи runner'а, apt, /tmp)
echo "root ($ROOT_DEV): img ${ROOT_IMG_MB} MB"
sudo fallocate -l "${ROOT_IMG_MB}M" /pv-root.img; IMGS+=(/pv-root.img)
LOOPS=()
for img in "${IMGS[@]}"; do LOOPS+=("$(sudo losetup --find --show "$img")"); done
sudo apt-get install -y -qq btrfs-progs >/dev/null 2>&1 || true
sudo mkfs.btrfs -q -f -d single -m single -L rom "${LOOPS[@]}"
sudo mkdir -p "$MP"
sudo mount -o compress-force=zstd:1,noatime,space_cache=v2,commit=120 "${LOOPS[0]}" "$MP"
sudo chown -R runner:runner "$MP"
free -h; sudo swapon --show; df -h "$MP"
sudo btrfs filesystem usage -T "$MP" | head -12 || true
