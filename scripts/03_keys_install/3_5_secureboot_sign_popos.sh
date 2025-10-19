#!/usr/bin/env bash
set -euo pipefail

# 3_5_secureboot_sign_popos.sh
# Podpisuje binarki EFI na wskazanym MOUNT-POINCIE nośnika.
# Użycie:
#   sudo ./3_5_secureboot_sign_popos.sh /mnt/popos_efi ~/SecureBoot_Project/secureboot/keys/db.key ~/SecureBoot_Project/secureboot/certs/db.crt
# Wymaga: sbsign, sbverify

if [[ $# -lt 3 ]]; then
  echo "Użycie: $0 <MOUNTPOINT_EFI> <db.key> <db.crt>" >&2
  exit 1
fi

MNT="$1"
DB_KEY="$2"
DB_CRT="$3"

for p in sbsign sbverify; do
  command -v "$p" >/dev/null || { echo "Brak narzędzia: $p" >&2; exit 1; }
done

[[ -d "$MNT" ]] || { echo "Brak katalogu montowania: $MNT" >&2; exit 1; }
[[ -f "$DB_KEY" && -f "$DB_CRT" ]] || { echo "Brak kluczy: $DB_KEY / $DB_CRT" >&2; exit 1; }

EFI_DIRS=(
  "$MNT/EFI/BOOT"
  "$MNT/boot/efi/EFI/BOOT"
)
TARGET=""
for d in "${EFI_DIRS[@]}"; do
  if [[ -d "$d" ]]; then TARGET="$d"; break; fi
done

[[ -n "$TARGET" ]] || { echo "Nie znaleziono katalogu EFI/BOOT pod $MNT." >&2; exit 1; }

echo "Podpisuję pliki EFI w: $TARGET"
BACKUP="${TARGET}/__original_unsig__$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP"

shopt -s nullglob
EFI_LIST=("$TARGET"/*.efi "$TARGET"/*.EFI)
if (( ${#EFI_LIST[@]} == 0 )); then
  echo "Brak plików .efi w $TARGET" >&2
  exit 1
fi

for f in "${EFI_LIST[@]}"; do
  base=$(basename "$f")
  cp -a "$f" "$BACKUP/$base"
  sbsign --key "$DB_KEY" --cert "$DB_CRT" --output "$f" "$f"
  echo "[OK] sbsign: $base"
  sbverify --list "$f" || { echo "Weryfikacja podpisu nieudana: $base" >&2; exit 1; }
done

echo "ZROBIONE ✅"
echo "Backup oryginalnych plików bez podpisu: $BACKUP"

