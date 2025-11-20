#!/usr/bin/env bash
set -euo pipefail

BASE=${BASE:-$HOME/SecureBoot_Project}
mkdir -p "$BASE"/{iso,tools,checksums/popos,packages}

# ---------------------------
# Pomocnicze kolory + echo
# ---------------------------
RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'; BLU=$'\e[34m'; CLR=$'\e[0m'
info(){ printf "%s[i]%s %s\n" "$BLU" "$CLR" "$1"; }
ok(){   printf "%s[✓]%s %s\n" "$GRN" "$CLR" "$1"; }
warn(){ printf "%s[!]%s %s\n" "$YLW" "$CLR" "$1"; }
err(){  printf "%s[✗]%s %s\n" "$RED" "$CLR" "$1"; }

# ---------------------------
# 1) Pop!_OS 24.04 ISO (bezpośrednio z DO Spaces; ścieżki różnią się wariantem)
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
# 2) Etcher AppImage
# ---------------------------
info "Pobieranie Etcher 1.19.25 AppImage…"
curl -fL "https://sourceforge.net/projects/etcher.mirror/files/v1.19.25/balenaEtcher-1.19.25-x64.AppImage/download" \
  -o "$BASE/tools/balenaEtcher-1.19.25-x64.AppImage"
ok "Etcher zapisany"

# ---------------------------
# 3) Paczki .deb z repozytoriów Pop!_OS
# ---------------------------
info "Aktualizuję listę pakietów (wymaga sudo)…"
sudo apt-get update -y

info "Pobieram .deb (efitools, sbsigntool, openssl) do $BASE/packages …"
pushd "$BASE/packages" >/dev/null
for pkg in efitools sbsigntool openssl; do
  info "→ $pkg"
  if apt-get download "$pkg"; then
    ok "Zapisano $(ls -t ${pkg}_*.deb 2>/dev/null | head -n1)"
  else
    warn "Nie udało się pobrać pakietu: $pkg"
  fi
done
popd >/dev/null
ok "Paczki .deb zebrane (sprawdź w $BASE/packages)"

# ---------------------------
# 4) Podsumowanie
# ---------------------------
echo
ok "Pakiet offline gotowy w: $BASE"
command -v tree >/dev/null 2>&1 && tree -L 3 "$BASE" || ls -R "$BASE"

