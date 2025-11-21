#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-$HOME/SecureBoot_Project}
cd "$BASE"

mkdir -p checksums/local

GRN=$'\e[32m'; RED=$'\e[31m'; YLW=$'\e[33m'; CLR=$'\e[0m'
pass(){ printf "%sPASS%s %s\n" "$GRN" "$CLR" "$1"; }
fail(){ printf "%sFAIL%s %s\n" "$RED" "$CLR" "$1"; }
info(){ printf "%s[i]%s %s\n"  "$YLW" "$CLR" "$1"; }

echo "== OFFLINE VERIFY =="
if ip route | grep -q '^default'; then
  info "Wykryto trasę domyślną (możliwy internet). To nie przeszkadza w weryfikacji, ale dla dyscypliny możesz odłączyć sieć."
else
  pass "Brak trasy domyślnej (offline)"
fi
echo

# ---------------------
# POP!_OS VERIFY (z pliku pasted_sha256.txt; jeśli nie ma, można wkleić ręcznie)
# ---------------------
POP_STATUS="SKIP"
POP_ISO=$(ls iso/pop-os_24.04_amd64_*.iso 2>/dev/null | head -n1 || true)

if [[ -n "${POP_ISO:-}" ]]; then
  EXP_SRC="checksums/popos/pasted_sha256.txt"
  EXP=""
  if [[ -f "$EXP_SRC" ]]; then
    info "Weryfikuję Pop!_OS z pliku $EXP_SRC"
    EXP=$(grep -oEi '[a-f0-9]{64}' "$EXP_SRC" | head -n1 || true)
  fi

  if [[ -z "$EXP" ]]; then
    info "Brak/niepoprawny $EXP_SRC – wklej SHA256 (jedna linia) i ENTER:"
    read -r EXP
    EXP=$(grep -oEi '[a-f0-9]{64}' <<<"$EXP" | head -n1 || true)
  fi

  if [[ -z "$EXP" ]]; then
    fail "Pop!_OS: nie znaleziono 64-znakowej sumy SHA256"
    POP_STATUS="FAIL"
  else
    ACT=$(sha256sum "$POP_ISO" | awk '{print $1}')
    echo "Pop!_OS expected: $EXP"
    echo "Pop!_OS actual  : $ACT"
    if [[ "$EXP" == "$ACT" ]]; then
      pass "Pop!_OS ISO"
      POP_STATUS="PASS"
    else
      fail "Pop!_OS ISO (niezgodna suma)"
      POP_STATUS="FAIL"
    fi
  fi
else
  info "Pomijam Pop!_OS (brak ISO w iso/pop-os_24.04_amd64_*.iso)."
  POP_STATUS="SKIP"
fi
echo

# ---------------------
# Dodatkowe: lokalne sumy (notatki)
# ---------------------
if [[ -f iso/dban.iso ]]; then
  sha256sum iso/dban.iso > checksums/local/dban.sha256.local
  info "Zapisano lokalną sumę DBAN -> checksums/local/dban.sha256.local"
fi
if [[ -f tools/balenaEtcher-1.19.25-x64.AppImage ]]; then
  sha256sum tools/balenaEtcher-1.19.25-x64.AppImage > checksums/local/balenaEtcher-1.19.25.sha256.local
  info "Zapisano lokalną sumę Etchera -> checksums/local/balenaEtcher-1.19.25.sha256.local"
fi
echo

# ---------------------
# PODSUMOWANIE
# ---------------------
echo "== PODSUMOWANIE =="
printf "Pop!_OS: %s\n" "$POP_STATUS"
echo

NEED_REDO=0
[[ "$POP_STATUS" == "FAIL" ]] && NEED_REDO=1

if [[ $NEED_REDO -eq 0 ]]; then
  pass "Wszystko wygląda dobrze."
  exit 0
fi

read -r -p "Wykryto błąd(y). Skasować CAŁE $BASE i pobrać na nowo? (y/N) " ans
if [[ "${ans:-N}" =~ ^[Yy]$ ]]; then
  echo
  info "Do ponownego pobrania potrzebny jest internet."
  for i in {1..30}; do
    if ip route | grep -q '^default'; then
      pass "Wykryto połączenie sieciowe."
      break
    fi
    printf "."
    sleep 2
  done
  echo
  if ! ip route | grep -q '^default'; then
    fail "Brak sieci. Podłącz internet i uruchom ręcznie prepare_offline.sh."
    exit 2
  fi

  read -r -p "Na pewno USUNĄĆ $BASE ? (TAK wpisz 'delete') " confirm
  if [[ "${confirm:-}" != "delete" ]]; then
    info "Anulowano usuwanie."
    exit 1
  fi

  rm -rf "$BASE"
  info "Skasowano $BASE."

  if [[ -f ./prepare_online.sh ]]; then
    info "Uruchamiam ./prepare_online.sh…"
    bash ./prepare_offline.sh
  elif [[ -f "$HOME/Downloads/prepare_online.sh" ]]; then
    info "Uruchamiam ~/Downloads/prepare_online.sh…"
    bash "$HOME/Downloads/prepare_online.sh"
  else
    fail "Nie znaleziono prepare_online.sh."
    echo "• Odtwórz skrypt pobierający i uruchom go ręcznie."
    exit 3
  fi

  pass "Ponowne pobranie zakończone. Uruchom ponownie: $0"
  exit 0
else
  info "Pominięto ponowne pobieranie."
  exit 1
fi

