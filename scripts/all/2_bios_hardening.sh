#!/usr/bin/env bash
# 🔐 Pop_hold! — Instrukcja ręcznej konfiguracji BIOS/UEFI (wydruk)
# Sekcja: 02_bios
# Uwaga: Ten skrypt jest szkieletem. Uzupełnij kroki zgodnie z protokołem PDF.
set -euo pipefail
cat <<'INSTR'
🔐 BIOS/UEFI — Hardening (do wykonania ręcznie):
1) Wyłącz CSM / Legacy Boot.
2) Włącz TPM 2.0 (PTT / fTPM) oraz Secure Boot (Tryb: Custom/Setup).
3) Zapisz i zrestartuj do BIOS — przygotuj się na wgrywanie kluczy użytkownika.
4) Boot order: USB (Pendrive A/B/D) -> NVMe (docelowy dysk).
5) Wyłącz zbędne interfejsy (opcjonalnie): Wake-on-LAN, PXE, nieużywane porty.
6) Hasła: ustaw hasło Administratora UEFI (zapisz w menedżerze haseł).
Druk: użyj `./bios_hardening.sh | lpr` aby wydrukować checklistę.
INSTR
