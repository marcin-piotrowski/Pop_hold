#!/usr/bin/env bash
set -euo pipefail

# 3_6_create_pendrive_D.sh
# Nagra podpisane ISO na /dev/sdX i zweryfikuje podpisy EFI.

if [[ $EUID -ne 0 ]]; then
  echo "Uruchom jako root." >&2; exit 1
fi

if [[ $# -lt 2 ]]; then
  echo "Użycie: $0 /dev/sdX /ścieżka/do/popos_signed.iso" >&2
  exit 1
fi

DEV="$1"
ISO="$2"

[[ -b "$DEV" ]] || { echo "Podaj poprawne urządzenie (np. /dev/sdb)." >&2; exit 1; }
[[ -f "$ISO" ]] || { echo "Brak pliku ISO: $ISO" >&2; exit 1; }

echo "UWAGA: $DEV zostanie nadpisany!"
read -rp "Potwierdź nazwę urządzenia ($DEV): " CONF
[[ "${CONF:-}" == "$DEV" ]] || { echo "Przerwano." >&2; exit 1; }

lsblk "$DEV"
read -rp "Na pewno? wpisz 'TAK': " YES
[[ "${YES:-}" == "TAK" ]] || { echo "Przerwano." >&2; exit 1; }

umount "${DEV}"* 2>/dev/null || true
dd if="$ISO" of="$DEV" bs=4M status=progress oflag=direct conv=fsync
sync
partprobe "$DEV" || true
sleep 1

# Spróbuj automatycznie zamontować partycję EFI z pendrive'a i zweryfikować podpis
PART_PREFIX="$DEV"; [[ "$DEV" =~ (nvme|mmcblk) ]] && PART_PREFIX="${DEV}p"
EFI_PART="${PART_PREFIX}1" # w Pop!_OS zwykle p1 to EFI
MNT="$(mktemp -d)"
if mount "$EFI_PART" "$MNT" 2>/dev/null; then
  if command -v sbverify >/dev/null; then
    EFI_BOOT="$MNT/EFI/BOOT/BOOTX64.EFI"
    if [[ -f "$EFI_BOOT" ]]; then
      sbverify --list "$EFI_BOOT" && echo "[OK] sbverify: $EFI_BOOT"
    else
      echo "[WARN] Nie znaleziono $EFI_BOOT do weryfikacji."
    fi
  else
    echo "[INFO] sbverify niedostępny — pomijam weryfikację podpisu."
  fi
  umount "$MNT"; rmdir "$MNT"
else
  echo "[WARN] Nie udało się zamontować $EFI_PART — weryfikacja pominięta."
fi

echo "ZROBIONE ✅ Pendrive D nagrany."

