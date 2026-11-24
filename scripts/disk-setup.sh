#!/usr/bin/env bash
# Объединяет свободное место корневого диска и /mnt в один том btrfs с прозрачным
# сжатием zstd (исходники Android и out/ сжимаются примерно в 1.5–2.5 раза), плюс swap.
#   disk-setup.sh <mountpoint> <swap_gb>
set -euo pipefail
MP="${1:-/home/runner/rom}"; SWAP_GB="${2:-12}"
sudo swapoff -a || true
sudo rm -f /mnt/swapfile /swapfile || true

# swap на /mnt (ext4)
sudo fallocate -l "${SWAP_GB}G" /mnt/swapfile
sudo chmod 600 /mnt/swapfile; sudo mkswap -q /mnt/swapfile; sudo swapon /mnt/swapfile

root_free=$(df --output=avail -B1M / | tail -1)
mnt_free=$(df --output=avail -B1M /mnt | tail -1)
ROOT_IMG_MB=$(( root_free - 3072 ))   # оставить ~3 ГБ корню (apt, логи runner'а)
MNT_IMG_MB=$(( mnt_free - 512 ))
echo "root img: ${ROOT_IMG_MB} MB, mnt img: ${MNT_IMG_MB} MB"

sudo fallocate -l "${ROOT_IMG_MB}M" /pv-root.img
sudo fallocate -l "${MNT_IMG_MB}M" /mnt/pv-mnt.img
L1=$(sudo losetup --find --show /pv-root.img)
L2=$(sudo losetup --find --show /mnt/pv-mnt.img)
sudo apt-get install -y -qq btrfs-progs >/dev/null 2>&1 || true
sudo mkfs.btrfs -q -f -d single -m single -L rom "$L1" "$L2"
sudo mkdir -p "$MP"
sudo mount -o compress-force=zstd:1,noatime,space_cache=v2,commit=120 "$L1" "$MP"
sudo chown -R runner:runner "$MP"
free -h; sudo swapon --show; df -h "$MP"
sudo btrfs filesystem usage -T "$MP" | head -12 || true
