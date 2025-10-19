#!/usr/bin/env bash
set -euo pipefail

# 3_2_secureboot_keys_gen.sh
# Generowanie kluczy Secure Boot: PK, KEK, db + .esl + .auth
# Użycie:
#   ./3_2_secureboot_keys_gen.sh "CN prefix" "O" "OU" "C"
# Przykład:
#   ./3_2_secureboot_keys_gen.sh "Pop_hold SB" "Marcin" "SecureBootLab" "PL"

CN_PREFIX="${1:-Pop_hold SB}"
ORG="${2:-Org}"
ORG_UNIT="${3:-Unit}"
C="${4:-PL}"

REQ_PKGS=(openssl cert-to-efi-sig-list sign-efi-sig-list uuidgen)
for p in "${REQ_PKGS[@]}"; do
  command -v "$p" >/dev/null || { echo "Brakuje narzędzia: $p" >&2; exit 1; }
done

BASE="${HOME}/SecureBoot_Project/secureboot"
KEYS="${BASE}/keys"
AUTH="${BASE}/auth"
CERTS="${BASE}/certs"
BIN="${BASE}/bin"

mkdir -p "$KEYS" "$AUTH" "$CERTS" "$BIN"

DATE_NOW=$(date +%Y%m%d)
VAL_DAYS=$((365*10)) # 10 lat
UUID=$(uuidgen)

gen_pair () {
  local name="$1" cn="$2"
  openssl req -new -x509 -newkey rsa:4096 -sha256 -days "$VAL_DAYS" \
    -subj "/C=${C}/O=${ORG}/OU=${ORG_UNIT}/CN=${cn}" \
    -keyout "${KEYS}/${name}.key" -out "${CERTS}/${name}.crt" -nodes
  chmod 600 "${KEYS}/${name}.key"
  echo "[OK] Wygenerowano: ${name}.key, ${name}.crt"
}

echo "=== Generuję klucze Secure Boot ==="
gen_pair "PK"  "${CN_PREFIX} Platform Key"
gen_pair "KEK" "${CN_PREFIX} Key Exchange Key"
gen_pair "db"  "${CN_PREFIX} Authorized Signature Database"

echo "=== Tworzę .esl (EFI Signature List) ==="
cert-to-efi-sig-list -g "$UUID" "${CERTS}/PK.crt"  "${BIN}/PK.esl"
cert-to-efi-sig-list -g "$UUID" "${CERTS}/KEK.crt" "${BIN}/KEK.esl"
cert-to-efi-sig-list -g "$UUID" "${CERTS}/db.crt"  "${BIN}/db.esl"

echo "=== Tworzę .auth z prawidłową hierarchią podpisów ==="
# PK.auth podpisany PK
sign-efi-sig-list -g "$UUID" -k "${KEYS}/PK.key"  -c "${CERTS}/PK.crt"  PK  "${BIN}/PK.esl"  "${AUTH}/PK_${DATE_NOW}.auth"
# KEK.auth podpisany PK
sign-efi-sig-list -g "$UUID" -k "${KEYS}/PK.key"  -c "${CERTS}/PK.crt"  KEK "${BIN}/KEK.esl" "${AUTH}/KEK_${DATE_NOW}.auth"
# db.auth podpisany KEK
sign-efi-sig-list -g "$UUID" -k "${KEYS}/KEK.key" -c "${CERTS}/KEK.crt" db  "${BIN}/db.esl"  "${AUTH}/db_${DATE_NOW}.auth"

# opcjonalnie: pusty dbx (blacklist) – użytkownik może dodać wpisy później
touch "${BIN}/dbx.esl"
sign-efi-sig-list -g "$UUID" -k "${KEYS}/KEK.key" -c "${CERTS}/KEK.crt" dbx "${BIN}/dbx.esl" "${AUTH}/dbx_${DATE_NOW}_EMPTY.auth"

echo
echo "ZROBIONE ✅"
echo "Ścieżki:"
echo "  KEYS : ${KEYS}   (klucze prywatne .key)"
echo "  CERTS: ${CERTS}  (certy .crt)"
echo "  BIN  : ${BIN}    (.esl)"
echo "  AUTH : ${AUTH}   (.auth do wgrania w BIOS/UEFI)"
echo
echo "PAMIĘTAJ: skopiuj *.key/*.crt na Pendrive C (sejf), a *.auth na Pendrive B (do BIOS)."

