#!/usr/bin/env bash
# 🔐 Pop_hold! — Pendrive B — klucze .auth do BIOS/UEFI
# Sekcja: 03_keys_install
# Uwaga: Ten skrypt jest szkieletem. Uzupełnij kroki zgodnie z protokołem PDF.
set -euo pipefail
SRC=${SRC:-$HOME/SecureBoot_Project/keys}
MNT=${MNT:-/mnt/usb-b}
DEV=${DEV:-/dev/sdX}  # <- ustaw
sudo wipefs -a "$DEV"
sudo parted -s "$DEV" mklabel gpt mkpart p1 fat32 1MiB 100% set 1 esp on
sudo mkfs.vfat -F32 "${DEV}1"
sudo mkdir -p "$MNT"
sudo mount "${DEV}1" "$MNT"
sudo cp -v "$SRC"/{PK.auth,KEK.auth,db.auth,dbx.auth} "$MNT"/ 2>/dev/null || true
sync
sudo umount "$MNT"
echo "[✓] Pendrive B gotowy."
