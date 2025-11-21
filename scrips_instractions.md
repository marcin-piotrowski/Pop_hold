### 🧱 **ETAP 1 — Przygotowanie środowiska warsztatowego (Pendrive A)**

| Nazwa skryptu          | Opis                                                                                                                                                           | Plik                     | Punkt protokołu |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ | --------------- |
| `prepare_online.sh`    | Tworzy strukturę `~/SecureBoot_Project`, pobiera obraz Pop!_OS, sumy SHA256, pakiety `.deb` (efitools, sbsigntool, openssl) i Etcher do pracy nad Secure Boot w środowisku Pop!_OS. | 1_1_prepare_online.sh    | 3.1             |
| `enter_offline.sh`     | Przełącza system w tryb offline – odłącza sieć, blokuje Wi-Fi, usuwa trasy routingu i potwierdza brak połączenia.                                               | 1_2_enter_offline.sh     | 3.2             |
| `verify_offline.sh`    | W trybie offline sprawdza integralność pobranych plików (ISO, narzędzi, pakietów) i potwierdza brak sieci.                                                      | 1_3_verify_offline.sh    | 3.3             |
| `back_online.sh`       | Przywraca połączenia Wi-Fi/Ethernet, odtwarza konfigurację sieci i testuje łączność.                                                                            | 1_4_back_online.sh       | 3.3             |
| `create_pendrive_A.sh` | Formatuje Pendrive A (Pop!_OS Live + tools), nagrywa ISO i kopiuje pakiety (`efitools`, `sbsigntool`, `openssl`, `balenaEtcher.AppImage`).                     | 1_5_create_pendrive_A.sh | 3.4             |

---

### 💽 **ETAP 2 — Hardening BIOS/UEFI**

| Nazwa skryptu       | Opis                                                                                                    | Plik                | Punkt protokołu |
| ------------------- | ------------------------------------------------------------------------------------------------------- | ------------------- | --------------- |
| `bios_hardening.sh` | Wyświetla i drukuje szczegółową instrukcję ręcznej konfiguracji BIOS/UEFI zgodnie z zasadami hardeningu – bez automatycznych zmian. | 2_bios_hardening.sh | 4               |

---

### 🧾 **ETAP 3 — Przygotowanie nośników, kluczy Secure Boot i instalatora Pop!_OS**

| Nazwa skryptu              | Opis                                                                                     | Plik                         | Punkt protokołu |
| -------------------------- | ---------------------------------------------------------------------------------------- | ---------------------------- | --------------- |
| `wipe_disks.sh`            | Zeruje i czyści dyski przed generacją kluczy (z potwierdzeniem urządzenia, `shred`/`dd if=/dev/zero`). | 3_1_wipe_disks.sh            | 5.1             |
| `secureboot_keys_gen.sh`   | Generuje pary kluczy PK/KEK/db i certyfikaty X.509, tworzy pakiety `.auth` dla BIOS/UEFI. | 3_2_secureboot_keys_gen.sh   | 5.2.1, 5.2.2    |
| `create_pendrive_B.sh`     | Przygotowuje Pendrive B (FAT32) do wgrywania kluczy do BIOS, kopiując pliki `.auth` (PK, KEK, db, dbx). | 3_3_create_pendrive_B.sh     |                 |
| `create_pendrive_C.sh`     | Tworzy Pendrive C (ext4/LUKS) do bezpiecznego przechowywania kluczy `.key` i `.crt`.      | 3_4_create_pendrive_C.sh     |                 |
| `secureboot_sign_popos.sh` | Podpisuje bootloader i jądro Pop!_OS kluczem `db.key`, tworząc podpisany obraz ISO dla bezpiecznego bootowania. | 3_5_secureboot_sign_popos.sh | 5.2.3           |
| `create_pendrive_D.sh`     | Tworzy finalny Pendrive D z podpisanym obrazem Pop!_OS przy użyciu Etchera lub `dd`, gotowy do instalacji systemu. | 3_6_create_pendrive_D.sh     | 5.3             |

---

### 🔐 **ETAP 4 — Wgrywanie kluczy Secure Boot do BIOS/UEFI**

| Nazwa skryptu             | Opis                                                                                                            | Plik                      | Punkt protokołu |
| ------------------------- | --------------------------------------------------------------------------------------------------------------- | ------------------------- | --------------- |
| `load_secureboot_keys.sh` | Prowadzi użytkownika przez proces wgrywania kluczy `.auth` (PK, KEK, db, dbx) z Pendrive B do BIOS/UEFI, wyświetlając kolejne kroki na ekranie. | 4_load_secureboot_keys.sh | 7               |
