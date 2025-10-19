#!/usr/bin/env bash
set -euo pipefail

# 3_4_create_pendrive_C.sh
# Tworzy LUKS-owy sejf na klucze (Pendrive C).
# Użycie:
#   sudo ./3_4_create_pendrive_C.sh /dev/sdX [/ścieżka/do/secureboot]
# Domyślnie szuka w: ~/SecureBoot_Project/secureboot

if [[ $EUID -ne 0 ]]; then
  echo "Uruchom jako root." >&2; exit 1
fi

DEV="${1:-}"
SRC="${2:-$HOME/SecureBoot_Project/secureboot}"

[[ -b "$DEV" ]] || { echo "Podaj urządzenie blokowe /dev/sdX." >&2; exit 1; }

echo "UWAGA: Wszystko na $DEV zostanie usunięte!"
read -rp "Wpisz dokładnie nazwę urządzenia ($DEV) aby potwierdzić: " CONF
[[ "${CONF:-}" == "$DEV" ]] || { echo "Przerwano." >&2; exit 1; }

# Wyczyść początek, załóż GPT i jedną partycję
wipefs -a "$DEV"
parted -s "$DEV" mklabel gpt
parted -s "$DEV" mkpart KEYS 1MiB 100%

PART="$DEV"
[[ "$DEV" =~ (nvme|mmcblk) ]] && PART="${DEV}p1" || PART="${DEV}1"
partprobe "$DEV"; sleep 1

echo "Zakładam LUKS na $PART"
cryptsetup luksFormat "$PART"
cryptsetup open "$PART" keys_crypt

mkfs.ext4 -L KEYS /dev/mapper/keys_crypt

MNT="$(mktemp -d)"
mount /dev/mapper/keys_crypt "$MNT"

if [[ -d "$SRC/keys" || -d "$SRC/certs" ]]; then
  mkdir -p "$MNT/keys" "$MNT/certs"
  [[ -d "$SRC/keys"  ]] && cp -av "$SRC/keys/."  "$MNT/keys/"
  [[ -d "$SRC/certs" ]] && cp -av "$SRC/certs/." "$MNT/certs/"
fi

sync
umount "$MNT"
rmdir "$MNT"
cryptsetup close keys_crypt

echo "ZROBIONE ✅ Pendrive C gotowy (LUKS + ext4, LABEL=KEYS)."

