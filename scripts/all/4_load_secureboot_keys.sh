#!/usr/bin/env bash
# 🔐 Pop_hold! — Wgrywanie kluczy Secure Boot do BIOS/UEFI (prowadzenie krok po kroku)
# Sekcja: 04_key_loading
# Uwaga: Ten skrypt jest szkieletem. Uzupełnij kroki zgodnie z protokołem PDF.
set -euo pipefail
cat <<'STEPS'
🔐 Wgrywanie kluczy do BIOS/UEFI (z Pendrive B):
1) Uruchom komputer i wejdź do ustawień UEFI (Del/F2).
2) Ustaw Secure Boot Mode: Custom/Setup.
3) Wybierz 'Enroll keys' / 'Manage Keys' i wskaż pliki z Pendrive B:
   • PK.auth  • KEK.auth  • db.auth  • (opcjonalnie) dbx.auth
4) Zapisz zmiany, zrestartuj i zweryfikuj, że Secure Boot jest aktywny.
5) Następnie z Pendrive D zainstaluj Pop!_OS (podpisany).
STEPS
