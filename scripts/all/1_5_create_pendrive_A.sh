#!/usr/bin/env bash
set -euo pipefail

# 1_5_create_pendrive_A.sh
# Tworzy pendrive A: Ubuntu Live + partycja TOOLS (FAT32) z narzędziami.
# Użycie:
#   sudo ./1_5_create_pendrive_A.sh /dev/sdX /ścieżka/do/ubuntu.iso /ścieżka/do/zasobów
# gdzie:
#   /dev/sdX          = urządzenie pendrive (NIE partycja!)
#   ubuntu.iso        = obraz Ubuntu (hybrydowy)
#   /ścieżka/do/zasobów = katalog z plikami do skopiowania (AppImage, .deb, dodatkowe ISO, SHA256SUMS itd.)

if [[ $EUID -ne 0 ]]; then
  echo "Uruchom jako root (sudo)." >&2
  exit 1
fi

if [[ $# -lt 3 ]]; then
  echo "Użycie: $0 /dev/sdX /path/ubuntu.iso /path/resources_dir" >&2
  exit 1
fi

DEV="$1"
ISO="$2"
RES_DIR="$3"

for f in "$DEV"; do
  [[ -b $f ]] || { echo "Urządzenie $f nie istnieje lub nie jest blokowym." >&2; exit 1; }
done
[[ -f "$ISO" ]] || { echo "Brak pliku ISO: $ISO" >&2; exit 1; }
[[ -d "$RES_DIR" ]] || { echo "Brak katalogu zasobów: $RES_DIR" >&2; exit 1; }

echo "=== PENDRIVE A — Ubuntu Live + TOOLS ==="
echo "Urządzenie: $DEV"
echo "ISO:        $ISO"
echo "Zasoby:     $RES_DIR"
echo
read -rp "UWAGA: To nadpisze ${DEV}. Wpisz DOKŁADNĄ nazwę urządzenia ($DEV), aby kontynuować: " CONF
[[ "${CONF:-}" == "$DEV" ]] || { echo "Przerwano." >&2; exit 1; }

# Odmontuj wszystko co siedzi na /dev/sdX?
echo "Odmontowuję istniejące partycje..."
lsblk -lnpo NAME,MOUNTPOINT "$DEV" | awk '$2!=""{print $1}' | xargs -r -n1 umount || true

sync

# 1) Flash ISO -> /dev/sdX
echo "Nagrywam ISO na urządzenie (to może potrwać)..."
dd if="$ISO" of="$DEV" bs=4M status=progress conv=fsync oflag=direct
sync

# Po dd: tablica partycji pochodzi z ISO; odczytaj ją ponownie
partprobe "$DEV" || true
sleep 1

# 2) Sprawdź czy jest wolne miejsce na końcu nośnika i utwórz partycję FAT32 "TOOLS"
echo "Sprawdzam możliwość utworzenia partycji TOOLS..."
# Oblicz koniec ostatniej partycji oraz rozmiar urządzenia
DEV_SIZE_B=$(blockdev --getsize64 "$DEV")
LAST_END_B=$(lsblk -bno NAME,START,SIZE "$DEV" | awk 'NR>1{end=$2+$3} END{print end+0}')
# Zapas na wyrównanie + minimalny rozmiar 512MiB
MIN_TOOLS=$((512*1024*1024))

FREE_B=$((DEV_SIZE_B - LAST_END_B))
if (( FREE_B < MIN_TOOLS )); then
  echo "Brak wystarczającego miejsca na dodatkową partycję TOOLS (>=512MiB). Pomijam tworzenie TOOLS."
  echo "Możesz użyć większego pendrive'a lub przygotować TOOLS na osobnym nośniku."
  exit 0
fi

echo "Dostępne wolne miejsce: $((FREE_B/1024/1024)) MiB — tworzę partycję FAT32 'TOOLS'."

# Ustal nazwę następnej partycji
PART_PREFIX="$DEV"
if [[ "$DEV" == *"nvme"* ]] || [[ "$DEV" == *"mmcblk"* ]]; then
  PART_PREFIX="${DEV}p"
fi

# Utwórz partycję FAT32 w wolnym zakresie
START_MB=$(( (LAST_END_B + 1024*1024 - 1) / (1024*1024) ))   # wyrównanie do 1MiB w górę
END_MB=$(( DEV_SIZE_B / (1024*1024) - 1 ))
parted -s "$DEV" unit MiB mkpart TOOLS fat32 "${START_MB}" "${END_MB}"

# Nadaj typ i stwórz system plików
TOOLS_PART="${PART_PREFIX}$(lsblk -no NAME "$DEV" | tail -n +2 | wc -l)"  # ostatnia partycja
# czasem parted nie nadaje flag, mkfs.vfat wystarczy
sleep 1
mkfs.vfat -n TOOLS "$TOOLS_PART"

# 3) Montuj i kopiuj zasoby
MNT="$(mktemp -d)"
mount "$TOOLS_PART" "$MNT"

echo "Kopiuję zasoby do $MNT (TOOLS)..."
rsync -a --info=progress2 "$RES_DIR"/ "$MNT"/

# Przydatne: utwórz skróty/README
cat > "$MNT/README_TOOLS.txt" <<EOF
Pendrive A — TOOLS
==================
Ta partycja zawiera narzędzia wspierające etap warsztatowy:
- balenaEtcher.AppImage
- paczki .deb (efitools, sbsigntool, openssl itp.)
- dodatkowe obrazy ISO, sumy SHA256
- skrypty z projektu Pop_hold
EOF

sync
umount "$MNT"
rmdir "$MNT"

echo "ZROBIONE ✅"
echo "• Pendrive startuje jako Ubuntu Live (z pierwszych partycji ISO)."
echo "• Dodatkowa partycja FAT32 'TOOLS' zawiera narzędzia pomocnicze."

