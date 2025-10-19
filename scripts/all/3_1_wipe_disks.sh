#!/usr/bin/env bash
set -euo pipefail

# 3_1_wipe_disks.sh
# Bezlitosne czyszczenie dysków. Uwaga: destrukcyjne!
# Użycie:
#   sudo ./3_1_wipe_disks.sh /dev/nvme0n1 [/dev/sdX ...]

if [[ $EUID -ne 0 ]]; then
  echo "Uruchom jako root." >&2; exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "Użycie: $0 /dev/DYSK [więcej...]" >&2; exit 1
fi

LOG="$HOME/wipe_log_$(date +%Y%m%d_%H%M%S).txt"
echo "Log: $LOG"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | tee -a "$LOG"

echo "UWAGA: WSZYSTKIE podane dyski zostaną wyczyszczone!"
read -rp "Aby kontynuować wpisz: TAK " SURE
[[ "${SURE:-}" == "TAK" ]] || { echo "Przerwano." >&2; exit 1; }

for DEV in "$@"; do
  [[ -b "$DEV" ]] || { echo "Pomijam $DEV (nie blokowe)." | tee -a "$LOG"; continue; }

  read -rp "Potwierdź nazwę urządzenia ($DEV): " CONF
  [[ "${CONF:-}" == "$DEV" ]] || { echo "Pomijam $DEV (brak potwierdzenia)." | tee -a "$LOG"; continue; }

  echo "Odmontowuję partycje $DEV..."
  lsblk -lnpo NAME,MOUNTPOINT "$DEV" | awk '$2!=""{print $1}' | xargs -r umount || true

  if command -v nvme >/dev/null && [[ "$DEV" =~ nvme ]]; then
    echo "[NVMe] sanitize block erase: $DEV" | tee -a "$LOG"
    nvme sanitize "$DEV" --sanitize-block-erase --no-dealloc || {
      echo "[WARN] sanitize nieudany, fallback dd: $DEV" | tee -a "$LOG"
      dd if=/dev/zero of="$DEV" bs=4M status=progress oflag=direct conv=fsync
    }
  else
    echo "[DD] Nadpisuję zerami: $DEV" | tee -a "$LOG"
    dd if=/dev/zero of="$DEV" bs=4M status=progress oflag=direct conv=fsync
  fi

  sync
  echo "Po czyszczeniu: fdisk -l $DEV" | tee -a "$LOG"
  fdisk -l "$DEV" | tee -a "$LOG"
done

echo "ZROBIONE ✅ Log: $LOG"

