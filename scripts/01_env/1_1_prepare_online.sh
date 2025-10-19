#!/usr/bin/env bash
set -euo pipefail

BASE=${BASE:-$HOME/SecureBoot_Project}
mkdir -p "$BASE"/{iso,tools,checksums/{ubuntu,popos},packages}

# ---------------------------
# Pomocnicze kolory + echo
# ---------------------------
RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'; BLU=$'\e[34m'; CLR=$'\e[0m'
info(){ printf "%s[i]%s %s\n" "$BLU" "$CLR" "$1"; }
ok(){   printf "%s[✓]%s %s\n" "$GRN" "$CLR" "$1"; }
warn(){ printf "%s[!]%s %s\n" "$YLW" "$CLR" "$1"; }
err(){  printf "%s[✗]%s %s\n" "$RED" "$CLR" "$1"; }

# ---------------------------
# Funkcja: pobieranie z fallback
# ---------------------------
download_with_fallback() {
  # $1: nazwa tablicy z kandydatami plików
  # $2: ścieżka wyjściowa
  # $3..: bazy (katalogi www)
  local -n arr=$1
  local outpath=$2
  shift 2
  local bases=("$@")
  
  if [[ -f "$outpath" ]]; then
    ok "Plik już istnieje, pomijam: $(basename "$outpath")"
    return 0
  fi
  
  for f in "${arr[@]}"; do
    for b in "${bases[@]}"; do
      local url="$b/$f"
      info "Próba: $url"
      if curl -fsIL "$url" >/dev/null 2>&1; then
        info "Pobieram: $url"
        curl -fL "$url" -o "$outpath"
        echo "$b" > "${outpath}.source.txt"
        echo "$f" > "${outpath}.filename.txt"
        ok "OK: $(basename "$outpath")"
        return 0
      fi
    done
  done
  err "Nie udało się pobrać żadnego wariantu: ${arr[*]}"
  return 1
}

# ---------------------------
# 1) Ubuntu Desktop 24.04.x
# ---------------------------
info "Pobieranie ISO Ubuntu 24.04.x (Desktop)…"
UBU_DIR_NOBLE="https://releases.ubuntu.com/noble"
UBU_DIR_OLD="https://old-releases.ubuntu.com/releases/24.04"
UBU_FILES=("ubuntu-24.04.3-desktop-amd64.iso" "ubuntu-24.04.2-desktop-amd64.iso" "ubuntu-24.04.1-desktop-amd64.iso")

download_with_fallback UBU_FILES "$BASE/iso/ubuntu-desktop-amd64.iso" "$UBU_DIR_NOBLE" "$UBU_DIR_OLD"

UBU_SRC_BASE=$(cat "$BASE/iso/ubuntu-desktop-amd64.iso.source.txt")
info "Pobieranie SHA256SUMS z: $UBU_SRC_BASE"
curl -fL "$UBU_SRC_BASE/SHA256SUMS" -o "$BASE/checksums/ubuntu/SHA256SUMS"
curl -fL "$UBU_SRC_BASE/SHA256SUMS.gpg" -o "$BASE/checksums/ubuntu/SHA256SUMS.gpg" || true
ok "Ubuntu ISO + sumy pobrane"

# ---------------------------
# 2) Pop!_OS 24.04 ISO (bezpośrednio z DO Spaces; ścieżki różnią się wariantem) ---
# Znane wzorce plików (warto mieć w razie zmian numeracji "11" → "12"):
# ---------------------------

echo "[*] Wybierz wariant Pop!_OS (nvidia/intel) [domyślnie: nvidia]: "
read -r POP_VARIANT
POP_VARIANT=${POP_VARIANT:-nvidia}
case "$POP_VARIANT" in
  nvidia|NVIDIA) POP_SUBDIR="nvidia";;
  intel|amd|INTEL|AMD) POP_SUBDIR="intel";;
  *) echo "[-] Nieznany wariant, używam 'nvidia'"; POP_SUBDIR="nvidia";;
esac

POP_CANDIDATES=(
  "https://iso.pop-os.org/22.04/amd64/nvidia/58/pop-os_22.04_amd64_nvidia_58.iso"
  "https://pop-iso.sfo2.cdn.digitaloceanspaces.com/24.04/amd64/${POP_SUBDIR}/11/pop-os_24.04_amd64_${POP_SUBDIR}_11.iso"
  "https://pop-iso.sfo2.cdn.digitaloceanspaces.com/24.04/amd64/${POP_SUBDIR}/10/pop-os_24.04_amd64_${POP_SUBDIR}_10.iso"
)
POP_SHA256_SUFFIX=".sha256"

echo "[*] Pobieranie ISO Pop!_OS 24.04 (${POP_SUBDIR})..."
for url in "${POP_CANDIDATES[@]}"; do
  if curl -fsIL "$url" >/dev/null 2>&1; then
    curl -fL "$url" -o "$BASE/iso/pop-os_24.04_amd64_${POP_SUBDIR}.iso"
    curl -fL "${url}${POP_SHA256_SUFFIX}" -o "$BASE/checksums/popos/pop-os_24.04_amd64_${POP_SUBDIR}.iso.sha256" || true
    echo "$url" > "$BASE/iso/pop-os.source.txt"
    POP_OK=1
    break
  fi
done
if [[ -z "${POP_OK:-}" ]]; then
  echo "[-] Nie udało się znaleźć bezpośredniego linku dla Pop!_OS ${POP_SUBDIR}. Wejdź ręcznie na stronę pobierania i zapisz ISO do $BASE/iso/"
  echo "   Strona: https://system76.com/pop/download/"
fi



# Klucz GPG System76 (dla weryfikacji, jeśli dostępna)
echo "[*] Pobieranie klucza GPG System76 (jeśli dostępny)..."
curl -fL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xA6CF15B0B38A8516" -o "$BASE/checksums/popos/system76.gpg" || true

# Pop!_OS — ISO ręcznie + wklejenie SHA256
info "Sprawdzam Pop!_OS ISO w: $BASE/iso/"
POP_ISO=$(ls "$BASE"/iso/pop-os_24.04_amd64_*.iso 2>/dev/null | head -n1 || true)
if [[ -n "${POP_ISO:-}" ]]; then
  echo
  echo "Znaleziono: $(basename "$POP_ISO")"
  echo "Wklej teraz **jednolinijkową** sumę SHA256 z oficjalnej strony Pop!_OS (dla TEGO wariantu) i naciśnij Enter."
  echo "(Akceptowane 64 znaki hex, bez prefiksów typu 'SHA256(...) =')"
  read -r -p "SHA256: " SHA
  # sanity-check: 64 heksów
  if [[ "$SHA" =~ ^[A-Fa-f0-9]{64}$ ]]; then
    printf "%s\n" "$SHA" > "$BASE/checksums/popos/pasted_sha256.txt"
    ok "Zapisano do checksums/popos/pasted_sha256.txt"
  else
    warn "Wygląda na niepoprawny format SHA256. Zapisuję mimo to (verfie.sh i tak spróbuje wyłuskać 64-hex)."
    printf "%s\n" "$SHA" > "$BASE/checksums/popos/pasted_sha256.txt"
  fi
else
  warn "Nie znaleziono ISO Pop!_OS. Pobierz ręcznie (NVIDIA/Intel) do: $BASE/iso/ i uruchom później verfie.sh."
fi

# ---------------------------
# 4) Etcher AppImage
# ---------------------------
info "Pobieranie Etcher 1.19.25 AppImage…"
curl -fL "https://sourceforge.net/projects/etcher.mirror/files/v1.19.25/balenaEtcher-1.19.25-x64.AppImage/download" \
  -o "$BASE/tools/balenaEtcher-1.19.25-x64.AppImage"
ok "Etcher zapisany"

# ---------------------------
# 5) Paczki .deb z Ubuntu 24.04 (noble) — wbudowany pobieracz offline
# ---------------------------
info "Zbieram .deb (efitools, sbsigntool, openssl) z Ubuntu noble do $BASE/packages (bez roota)…"

APTROOT="$BASE/apt-noble-tmp"
mkdir -p "$APTROOT"/etc/apt "$APTROOT"/var/lib/apt/lists/partial "$APTROOT"/var/cache/apt/archives/partial "$APTROOT"/var/lib/dpkg
touch "$APTROOT/var/lib/dpkg/status"

# Keyring — skopiuj z hosta (najprościej)
KEY_DEST="$APTROOT/etc/apt/trusted.gpg"
FOUND=0
for src in \
  /usr/share/keyrings/ubuntu-archive-keyring.gpg \
  /etc/apt/trusted.gpg.d/ubuntu-archive-keyring.gpg \
  /etc/apt/trusted.gpg; do
  if [[ -f "$src" ]]; then
    cp -f "$src" "$KEY_DEST"
    FOUND=1
    info "Keyring: $src -> $KEY_DEST"
    break
  fi
done
if [[ $FOUND -eq 0 ]]; then
  err "Brak keyringu Ubuntu na hoście. Zainstaluj 'ubuntu-keyring' i odpal ponownie."
  exit 2
fi

cat > "$APTROOT/etc/apt/sources.list" <<'EOF'
deb http://archive.ubuntu.com/ubuntu noble main universe
deb http://archive.ubuntu.com/ubuntu noble-updates main universe
deb http://archive.ubuntu.com/ubuntu noble-security main universe
EOF

APT_ARGS=(
  -o Dir="$APTROOT"
  -o Dir::Etc::sourcelist="sources.list"
  -o Dir::Etc::sourceparts="-"
  -o Dir::Etc::trusted="trusted.gpg"
  -o Dir::State="var/lib/apt"
  -o Dir::State::status="$APTROOT/var/lib/dpkg/status"
  -o Dir::Cache::archives="$APTROOT/var/cache/apt/archives"
  -o Debug::NoLocking=1
)

apt-get "${APT_ARGS[@]}" update
apt-get "${APT_ARGS[@]}" -y --download-only install --no-install-recommends efitools sbsigntool openssl
cp -v "$APTROOT/var/cache/apt/archives/"*.deb "$BASE/packages/" || warn "Nie znaleziono .deb do skopiowania"
rm -rf "$APTROOT"
ok "Paczki .deb zebrane (sprawdź w $BASE/packages)"

# ---------------------------
# 6) Podsumowanie
# ---------------------------
echo
ok "Pakiet offline gotowy w: $BASE"
command -v tree >/dev/null 2>&1 && tree -L 3 "$BASE" || ls -R "$BASE"

