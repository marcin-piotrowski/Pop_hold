# 🔐 Pop!_hold v0.2

Poniżej znajduje się kompletny protokół instalacji Pop!_OS z własnym **Secure Boot**, wraz ze skryptami automatyzującymi

---

## 1) Cel

Zainstalować **Pop!_OS** w trybie **„twierdza”**, możliwe zabzieczyć dostęp fizyczny, wstępna konfiguracja sieci:

- własne klucze **Secure Boot (PK/KEK/db/dbx)** w //TODO**zabezpieczonym UEFI**
- podpisanie bootloadera i instalacja **offline**
- kontrolowany powrót **online** dopiero po zakończeniu hardeningu wstępnego (**usb lock**, **firewall**, **VPN**, **pierwszy VM**)

---

## 2) Przebieg wysokiego poziomu

> **Ważne:** Cały proces przygotowania instalatora i podpisywania bootloadera opiera się na **jednym systemie – Pop!_OS (live)**. Unikamy miksowania środowisk (Ubuntu/Pop!_OS), żeby pliki i sumy kontrolne były spójne z obrazem instalacyjnym, a wynikowy pendrive dawał się zainstalować na Pop!_OS bez niespodzianek.

1. **ONLINE (krótko, kontrolowanie):** Pobierz Pop!_OS ISO/Etcher/paczki `.deb` i oficjalne sumy/podpisy. Złóż strukturę `~/SecureBoot_Project`.
2. **WEJŚCIE W OFFLINE:** Odłącz sieć *fizycznie* i *logicznie*. Patrz rozdział 4.
3. **Hardening BIOS**: Aktualizacja, Factory reset, Hasło dla admina i użytkownika
4. **Pop!_OS Live (Pendrive A):** Uruchom z obrazu Pop!_OS, zweryfikuj sumy ISO **offline**, wygeneruj klucze, zrób `.auth`, zeruj dyski twarde.
5. **Przygotowanie instalatora (Pendrive D):** Podpisz bootloader Pop!_OS własnym `db.key`, nagraj instalator.
6. **Instalacja Pop!_OS (OFFLINE):** Z Pendrive D.
7. **UEFI:** Ustaw Secure Boot. Wgraj `PK/KEK/db` (i opcjonalnie `dbx`) z Pendrive B.
8. **Hardening post-install (OFFLINE):** minimalna konfiguracja, zabezpieczenia startowe.
9. **Powrót ONLINE (kontrolowany):** tylko gdy zakończysz hardening, aktualizacje zaufanych repo, import kluczy GPG itp

---

## 3) Przygotuj zasoby i nośniki

### 3.1 Przygotowanie ONLINE (krótko)

**Bazowy system:** Pop!_OS (ISO live lub zainstalowany), żeby wszystkie narzędzia i sumy były zgodne z docelowym installerem.

*Skrypt*: [prepare_online.sh](scripts/01_env/1_1_prepare_online.sh)

**Użycie:**

```bash
chmod +x scripts/01_env/1_1_prepare_online.sh
./scripts/01_env/1_1_prepare_online.sh
```

Tworzy strukturę katalogów `~/SecureBoot_Project`, pobiera obraz Pop!_OS, sumy SHA256 i paczki `.deb` potrzebne do podpisania bootloadera.

### 3.2 Wejście w tryb OFFLINE

*Skrypt*: [enter_offline.sh](scripts/01_env/1_2_enter_offline.sh)

**Użycie:**

```bash
chmod +x scripts/01_env/1_2_enter_offline.sh
sudo ./scripts/01_env/1_2_enter_offline.sh
```

Co robi:

- prosi o wypięcie kabla i wyłączenie hotspotów,
- `nmcli radio all off`, `nmcli networking off`,
- opuszcza wszystkie interfejsy nieloopback,
- usuwa trasy **default**,
- sprawdza brak aktywnych tras domyślnych.

Powrót online:

```bash
sudo nmcli networking on \
 && sudo nmcli radio wifi on \
 && sudo nmcli radio wwan on \
 && sudo nmcli radio bluetooth on
```

### 3.3 Weryfikacja OFFLINE

*Skrypt*: [verify_offline.sh](scripts/01_env/1_3_verify_offline.sh)

**Użycie:**

```bash
chmod +x scripts/01_env/1_3_verify_offline.sh
./scripts/01_env/1_3_verify_offline.sh
```

Co robi:

- upewnia się, że brak trasy domyślnej,
- sprawdza Pop!_OS ISO vs `.sha256`,
- opcjonalnie zapisuje lokalne sumy dla DBAN i Etchera,
- wypisuje PASS/FAIL.
- w razie niepowodzenia pozwala pobrać jeszcze raz, po powrocie online ze skryptem [`back_online.sh`](scripts/01_env/1_4_back_online.sh)

**Uwaga:** skrypty oczekują, że `~/SecureBoot_Project/secureboot/keys` i `.../auth` są już wypełnione.

### **3.4 Pendrive A — Pop!_OS Live (warsztatowy)**

*Skrypt*: [prepare_pendrive_A.sh](scripts/01_env/1_5_create_pendrive_A.sh)

- Format: FAT32 (bootowalny Pop!_OS Live)
- Dodatki: `balenaEtcher.AppImage`, obraz Pop!_OS, pliki `.sha256`, paczki .deb (`efitools`, `sbsigntool`, `openssl`).
- Rola: *centrum dowodzenia* (generowanie kluczy, podpisy, weryfikacje, przygotowanie Pendrive D) — dzięki temu cały proces odbywa się w jednym środowisku Pop!_OS.

---

## 4) Hardening BIOS/UEFI

*(dla ASRock Z790 Taichi)*

*Skrypt*: [2_bios_hardening.sh](scripts/02_bios/2_bios_hardening.sh)

#### Cel

Zabezpieczyć warstwę **sprzętową i firmware** przed nieautoryzowanymi zmianami.  
W tym etapie *nie wgrywamy jeszcze własnych kluczy Secure Boot* – tylko tworzymy bezpieczne środowisko, które pozwoli na ich późniejsze załadowanie.

#### Przygotowanie przed wejściem do BIOS

1. Odłącz **wszystkie sieci** (Ethernet, Wi-Fi, BT, dongle).

2. Odłącz wszystkie **nośniki USB** oprócz klawiatury.

3. Przygotuj **Pendrive B** (z kluczami `.auth`) – ale **nie wkładaj go jeszcze**.

4. Jeśli płyta ma aktualizację BIOS – wykonaj ją *z Pendrive’a FAT32*, nie przez sieć.
   
   - Plik BIOS `.bin` → nagraj do pendrive’a
   
   - W BIOS → **Tools → Instant Flash**
   
   - Po aktualizacji: uruchom ponownie i **Load UEFI Defaults** (`F9`)

5. Zanotuj aktualną wersję BIOS na kartce / w notatce `bios_version.txt`.

#### Sekcja po sekcji – ustawienia bezpieczeństwa

##### **A. Main / OC Tweaker**

> Nie ingerujemy w OC ani napięcia, BIOS pozostaje stabilny i „czysty”.

- Przywróć domyślne (`F9 → Yes`)

- Nie zmieniaj nic w sekcji **OC Tweaker**

- Upewnij się, że żadne profile OC ani XMP nie są aktywne (zachowaj stabilność)

- Wyłącz „Base Frequency Boost” (jeśli aktywny)

- Sprawdź temperatury i wentylatory – mają działać poprawnie (sekcja Hardware Monitor)

##### **B. Advanced → CPU Configuration**

- **Intel Virtualization Technology** – **Enabled** *(dla VM)*
  
  > Pozwala na uruchamianie maszyn wirtualnych, ale nie wpływa negatywnie na bezpieczeństwo.

- **CFG Lock** – **Disabled**
  
  > Pozwala na późniejszą edycję microcode/bootloaderów (własne podpisy EFI).

- **C-States, C1E, C6, C7** – **Enabled (Auto)**
  
  > Energooszczędność = mniejsze ślady poboru prądu / ciepła, ale nie krytyczne.

- **Intel SpeedStep / Speed Shift** – **Enabled**

- **Legacy Game Compatibility Mode** – **Disabled**

##### **C. Advanced → Chipset Configuration**

- **Above 4G Decoding** – **Enabled**
  
  > Wymagane przy nowoczesnych GPU i Secure Boot.

- **Resizable BAR (C.A.M)** – **Enabled**
  
  > Optymalizacja pamięci PCIe, wymagana przez nowsze GPU.

- **VT-d** – **Enabled** *(potrzebne do IOMMU / VM isolation)*

- **SR-IOV Support** – **Enabled**
  
  > Dla wirtualizacji kart sieciowych / PCIe.

- **Onboard LAN (Realtek / Intel / Killer)** – **Enabled** tylko jeśli używane
  
  > Wyłącz nieużywane kontrolery sieciowe, minimalizując powierzchnię ataku.

- **Onboard Audio** – **Disabled** *(jeśli niepotrzebne)*

- **Deep Sleep** – **Disabled** *(utrudnia „cold boot attack”)*

- **Restore on AC/Power Loss** – **Power Off**

- **Onboard LED w S5** – **Disabled** *(niepotrzebne zasilanie po wyłączeniu)*

##### **D. Advanced → Storage Configuration**

- **SATA Controller** – **Enabled** *(jeśli używasz SATA)*

- **SATA Mode** – **AHCI**

- **VMD Controller** – **Disabled**, jeśli nie używasz Intel RST/VMD

- **SMART** – **Enabled** *(monitoring dysków)*

##### **E. Advanced → ACPI Configuration**

- **Wake on LAN / PCIe Devices Power On** – **Disabled**

- **USB Keyboard/Mouse Power On** – **Disabled**

- **RTC Alarm Power On** – **Disabled**

> 🔒 Te opcje uniemożliwiają zdalne lub przypadkowe wybudzanie sprzętu.

##### **F. Advanced → USB Configuration**

- **Legacy USB Support** – **UEFI Setup Only**

- **XHCI Hand-off** – **Enabled**

> Po instalacji systemu włączymy **USBGuard**, ale już tutaj ograniczamy dostępność portów.

##### **G. Advanced → Trusted Computing**

- **Security Device Support** – **Enabled**

- **SHA256 PCR Bank** – **Enabled**

- **Platform / Storage / Endorsement Hierarchy** – **Enabled**

- **Pending Operation** – **None**

- **TPM 2.0 Interface Type** – **CRB**

- **Intel PTT** – **Enabled** *(zastępuje fizyczny TPM moduł)*

> Upewnij się, że TPM pojawia się po restarcie w `Advanced → Trusted Computing`.

##### **H. Security Screen**

- **Supervisor Password** – ustaw mocne hasło BIOS-admina

- **User Password** – ustaw osobne hasło użytkownika (read-only BIOS)

- **Secure Boot** – **Disabled (na tym etapie)**

- **Intel Platform Trust Technology** – **Enabled**

> Hasła BIOS powinny być zapisane offline i przechowywane w Pendrive C lub papierowym sejfie.

##### **I. Boot Screen**

- **Fast Boot** – **Disabled**

- **CSM (Compatibility Support Module)** – **Disabled**

- **Boot from Onboard LAN** – **Disabled**

- **NumLock on Boot** – wg uznania

- **Full Screen Logo** – **Disabled** (ułatwia diagnostykę POST)

- **Boot Failure Guard** – **Enabled**

##### **J. Tools**

- **Instant Flash** – używaj tylko do aktualizacji BIOS z pendrive’a FAT32

- **SSD Secure Erase Tool** – dostępne do czyszczenia SSD (opcjonalnie DBAN offline)

- **Auto Driver Installer** – **Disabled** *(aby uniknąć połączenia online po instalacji)*

#### ✅ Checklista końcowa – „Hardening BIOS”

| Status | Kategoria                                                        | Cel                              |
| ------ | ---------------------------------------------------------------- | -------------------------------- |
| ☐      | BIOS zaktualizowany i przywrócony do domyślnych                  | Stabilna baza                    |
| ☐      | Hasło administratora i użytkownika ustawione                     | Ochrona przed fizycznym dostępem |
| ☐      | Secure Boot – *wyłączony* (do czasu załadowania własnych kluczy) | Kontrolowany moment aktywacji    |
| ☐      | PTT / TPM 2.0 włączony i widoczny                                | Wsparcie dla podpisów EFI        |
| ☐      | CSM wyłączony                                                    | Pełny UEFI-mode                  |
| ☐      | Wake-on-LAN, AC restore, USB wake – wyłączone                    | Brak zdalnego startu             |
| ☐      | Deep Sleep i LED-y w S5 wyłączone                                | Mniejsza aktywność po wyłączeniu |
| ☐      | Fast Boot wyłączony                                              | Możliwość wejścia do BIOS        |
| ☐      | Auto Driver Installer wyłączony                                  | Brak połączenia z Internetem     |

## 5) Bootowanie do warsztatu, zerowanie dysków i tworzenie medium instalacyjnego

*Skrypty*:

- [create_pendrive_B.sh](scripts/03_keys_install/3_3_create_pendrive_B.sh)
- [create_pendrive_C.sh](scripts/03_keys_install/3_4_create_pendrive_C.sh)

#### Cel

Ten etap ma przygotować **czyste, niezaufane środowisko „warsztatowe”**, w którym:

- uruchamiasz **Pop!_OS Live (Pendrive A)** całkowicie **offline**

- potwierdzasz, że sprzęt działa stabilnie

- wykonujesz **pełne zerowanie wszystkich dysków**

- przygotowujesz przestrzeń pod nową instalację z własnym Secure Boot

Dzięki temu masz pewność, że na żadnym dysku nie pozostały:

- dane poprzednich systemów

- klucze lub ślady bootloaderów

- malware w ukrytych partycjach EFI lub VMD

#### 5.1.1 – Uruchom system warsztatowy (Pop!_OS Live) i rozpocznij czyszczenie dysków

*Skrypt*: [wipe_disks.sh](scripts/03_keys_install/3_1_wipe_disks.sh)

1. Włóż **Pendrive A (Pop!_OS Live)**.

2. Upewnij się, że **Secure Boot jest nadal wyłączony**.

3. W BIOS → `Boot → Boot Option #1` ustaw pendrive jako pierwszy.

4. Uruchom ponownie i wybierz **„Try Pop!_OS (Live)”**.

5. Gdy system się załaduje, wykonaj w terminalu:
   
   `nmcli radio all off nmcli networking off ip route`
   
   ✅ upewnij się, że nie ma żadnej trasy `default` – jesteś **offline**.  
   *(lub użyj skryptu `enter_offline.sh` z protokołu punkt 3.2)*

#### 5.1.2 – Weryfikacja dysków

W terminalu uruchom:

`sudo lsblk -o NAME,SIZE,TYPE,MOUNTPOINT`

Zanotuj wszystkie urządzenia, np.:

`nvme0n1    1.0T nvme1n1    2.0T sda        32G  (pendrive warsztatowy)`

Nie pomyl pendrive’a z dyskiem systemowym!

#### 5.1.3 – Zerowanie dysków

##### **NVMe – sprzętowe wyczyszczenie (najbezpieczniejsze)**

`sudo nvme list sudo nvme sanitize /dev/nvme0n1 --sanitize-block-erase`

lub, jeśli powyższe nie zadziała:

##### **SSD/HDD – pełne nadpisanie (klasyczne)**

`sudo dd if=/dev/zero of=/dev/sda bs=4M status=progress`

#### 5.1.4 – Potwierdzenie czystości dysków

Po wyczyszczeniu uruchom:

`sudo fdisk -l`

Oczekiwany wynik:

- brak partycji,

- dyski widoczne jako „unpartitioned”.

Dla pełnej dokumentacji możesz zapisać wynik do logu:

`sudo fdisk -l > ~/wipe_log_$(date +%Y%m%d).txt`

### 5.2 Tworzenie kluczy Secure Boot i podpisywanie EFI

*Skrypt*: [secureboot_keys_gen.sh](scripts/03_keys_install/3_2_secureboot_keys_gen.sh)

#### Cel

W tym kroku tworzysz własne klucze Secure Boot (PK, KEK, db) i przygotowujesz podpisane binarki EFI, które pozwolą uruchamiać tylko *zaufane* komponenty — Twoje i nikogo innego.
Całość odbywa się **offline** z systemu **Pop!_OS Live (Pendrive A)**.

#### Struktura katalogów

Tworzymy bazowy katalog projektu (jeśli jeszcze nie istnieje):

`mkdir -p ~/SecureBoot_Project/secureboot/{keys,auth,bin,signed}`

> 💡 Wszystkie dalsze skrypty będą korzystać z tej struktury.
> 
> - `keys/` — zawiera klucze prywatne (`.key`, `.crt`)
> 
> - `auth/` — gotowe pliki `.auth` do BIOS
> 
> - `signed/` — podpisane pliki EFI
> 
> - `bin/` — tymczasowe pliki binarne EFI

#### 5.2.1 Generowanie kluczy

Użyj gotowego skryptu `3_2_secureboot_keys_gen.sh` (z folderu `scripts/03_keys_install/` lub `scripts/all/`):

> 🔒 Te klucze stanowią fundament Twojego Secure Boot.  
> Nie przechowuj ich online — po zakończeniu przenieś na **Pendrive C (archiwum kluczy prywatnych)**.

---

#### 5.2.2 Tworzenie plików `.auth`

Ten sam skrypt tworzy pakiety `.auth` dla BIOS/UEFI, więc nie trzeba przełączać się na inne narzędzia.

> 📦 Po zakończeniu przenieś folder `auth/` na **Pendrive B (klucze do BIOS)**.  
> Pendrive B powinien mieć format FAT32 (UEFI go odczyta).

---

#### 5.2.3 Podpisanie bootloadera EFI (systemd-boot / shim)

*Skrypt*: [secureboot_sign_popos.sh](scripts/03_keys_install/3_5_secureboot_sign_popos.sh)

W tym kroku podpisujemy wszystkie pliki `.efi`, które mają być uruchamiane przez UEFI — np. `systemd-bootx64.efi`, `grubx64.efi`, `shimx64.efi`.

Skrypt sam montuje i podpisuje wskazany nośnik instalatora.

> 💡 Jeśli pendrive nie jest zamontowany — zamontuj go:
> 
> `sudo mkdir -p /mnt/efi sudo mount /dev/sdX1 /mnt/efi`
> 
> (zastąp `/dev/sdX1` odpowiednim urządzeniem)

#### 🧾 Checklista końcowa – „Klucze i podpisy”

| Status | Czynność                                        | Cel                      |
| ------ | ----------------------------------------------- | ------------------------ |
| ☐      | Wygenerowano PK/KEK/db (RSA 4096-bit)           | Trzy poziomy zaufania    |
| ☐      | Utworzono pliki `.auth`                         | Gotowe do importu w UEFI |
| ☐      | Klucze `.key` / `.crt` skopiowane na Pendrive C | Sejf offline             |
| ☐      | Pliki `.auth` skopiowane na Pendrive B          | Do wgrania w BIOS        |
| ☐      | Podpisano pliki EFI Pop!_OS                     | Gotowy bootloader        |

### 5.3 Tworzenie instalatora Pop!_OS (custom-signed)

*Skrypt*: [create_pendrive_D.sh](scripts/03_keys_install/3_6_create_pendrive_D.sh)

#### Cel

Przygotować własny instalator Pop!_OS, którego bootloader (`systemd-bootx64.efi`) jest podpisany Twoim kluczem `db.key`, dzięki czemu:

- uruchomi się tylko na Twoim sprzęcie,

- z Twoim zestawem Secure Boot Keys,

- a każda niepodpisana binarka zostanie odrzucona.

Skrypt wykorzystuje ten sam obraz Pop!_OS pobrany w punkcie **3.1**, więc cały proces budowy instalatora i instalacji odbywa się w jednym, spójnym środowisku Pop!_OS.

---

#### 5.3.1 Przygotowanie pendrive’a

1. Włóż pusty pendrive (min. 8 GB).

2. Sformatuj go (lub nagraj ISO przez Etcher / `dd`):
   
   `balenaEtcher.AppImage &`
   
   lub:
   
   `sudo dd if=~/SecureBoot_Project/iso/pop-os_24.04_amd64.iso of=/dev/sdX bs=4M status=progress sync`

3. Zamontuj partycję EFI:
   
   `sudo mkdir -p /mnt/popos_efi sudo mount /dev/sdX1 /mnt/popos_efi`

---

#### 5.3.2 Podpisanie bootloadera Pop!_OS

Wykorzystaj wcześniej utworzony skrypt `sign_usb_efi_binaries.sh`:

`sudo ./sign_usb_efi_binaries.sh /mnt/popos_efi`

Upewnij się, że w folderze `/mnt/popos_efi/EFI/BOOT/` znajdują się:

`BOOTX64.EFI systemd-bootx64.efi grubx64.efi (opcjonalnie)`

Po podpisaniu zamień oryginalne pliki na podpisane:

`sudo cp ~/SecureBoot_Project/secureboot/signed/*.efi /mnt/popos_efi/EFI/BOOT/ -f`

---

#### 5.3.3 Test podpisu

Sprawdź podpis:

`sbverify --list /mnt/popos_efi/EFI/BOOT/BOOTX64.EFI`

Oczekiwany wynik:

`signature 1 issuer: /CN=Authorized Signature Database/ subject: /CN=Authorized Signature Database/`

---

#### 5.4.4 Odmontowanie i oznaczenie pendrive’a

`sudo umount /mnt/popos_efi`

Oznacz go fizycznie etykietą:  
**Pendrive D — Instalator Pop!_OS (custom-signed)**

> 💡 Po wgraniu kluczy do BIOS (Pendrive B) możesz instalować system z Pendrive D.

#### Checklista końcowa – „Instalator Pop!_OS”

| Status | Czynność                                | Cel                         |
| ------ | --------------------------------------- | --------------------------- |
| ☐      | Pendrive sformatowany lub nagrany z ISO | Przygotowanie nośnika       |
| ☐      | Bootloader EFI podpisany `db.key`       | Zaufane uruchamianie        |
| ☐      | Pliki `.efi` skopiowane z powrotem      | UEFI-ready                  |
| ☐      | Weryfikacja podpisu (`sbverify`)        | Potwierdzenie integralności |
| ☐      | Pendrive oznaczony jako „D”             | Gotowy do instalacji        |

---

## 6) Instalacja Pop!_OS (custom-signed)

- Uruchom komputer z Pendrive D
- Zainstaluj Pop!_OS z włączonym szyfrowaniem LUKS
- Po instalacji sprawdź, czy system uruchamia się tylko z Twoimi podpisami

---

## 7) Wgrywanie własnych kluczy Secure Boot do BIOS/UEFI

*Skrypt*: [load_secureboot_keys.sh](scripts/04_key_loading/4_load_secureboot_keys.sh)

### Cel

Ten etap polega na **zastąpieniu fabrycznych kluczy Secure Boot (Microsoft / OEM)** Twoim własnym zestawem:

- **PK.auth** — Platform Key (najwyższy poziom zaufania),

- **KEK.auth** — Key Exchange Key (autoryzuje zmiany),

- **db.auth** — Authorized Database (zezwala na uruchamianie podpisanych binarek).

Po tej operacji tylko binarki podpisane Twoim `db.key` (np. Twój instalator Pop!_OS) będą mogły się uruchomić.

### Wymagania

- BIOS/UEFI po hardeningu (patrz punkt 4).

- **Pendrive B** – FAT32 z folderem `auth/` zawierającym:
  
  `PK.auth KEK.auth db.auth (opcjonalnie) dbx.auth`

- Secure Boot aktualnie **wyłączony**.

- System **niepodłączony do sieci** (offline).

#### 7.1 Wejdź do BIOS

- Uruchom komputer i natychmiast naciskaj `DEL` lub `F2`.

- Przejdź do **Advanced Mode (F6)**.

- Wejdź w zakładkę **Security** → **Secure Boot**.

#### 7.2 Ustaw tryb Custom

1. Zmieniasz:
   
   `Secure Boot Mode → Custom`

2. Następnie:
   
   `Secure Boot → Enabled`

3. Zapisz (`F10`) i ponownie wejdź do BIOS (po restarcie).

> 💡 Tryb *Custom* pozwala ręcznie zarządzać kluczami (PK, KEK, db).  
> *Standard* automatycznie ładuje klucze Microsoft / OEM — unikaj tego.

#### 7.3 Włóż Pendrive B

- Podłącz **Pendrive B** z plikami `.auth` (FAT32).

- Poczekaj kilka sekund — BIOS ASRock automatycznie wykryje napęd FAT.

#### 7.4 — Wgrywanie kluczy

Wejdź kolejno w:

> **Security → Secure Boot → Key Management**

Dla każdego z trzech kluczy wykonaj:

| Klucz                    | Ścieżka BIOS                | Plik       | Komentarz                 |
| ------------------------ | --------------------------- | ---------- | ------------------------- |
| Platform Key (PK)        | `Enroll Platform Key`       | `PK.auth`  | najwyższy klucz zaufania  |
| Key Exchange Key (KEK)   | `Enroll Key Exchange Key`   | `KEK.auth` | autoryzuje zmiany w db    |
| Authorized Database (db) | `Enroll Signature Database` | `db.auth`  | określa dozwolone binarki |

*(opcjonalnie)*  
| Blacklist (dbx) | `Enroll Forbidden Signatures` | `dbx.auth` | lista zbanowanych certyfikatów (np. Microsoft UEFI CA) |

Po każdym imporcie BIOS może zapytać:

> “Are you sure you want to enroll key?”  
> → wybierz **Yes**

#### 7.5 Potwierdzenie

Wróć do ekranu Secure Boot i sprawdź, czy widzisz wpisy:

`Key Source: Modified / Custom Platform Key (PK): Present Key Exchange Key (KEK): Present Authorized Signatures (db): Present`

> 💡 Jeśli BIOS pokazuje „Factory Default” – nie zapisał nowych kluczy.  
> W takim przypadku spróbuj ponownie z opcji „Enroll from File”.

#### 7.6 Eksport kopii zapasowej (opcjonalne, ale zalecane)

W tym samym menu wybierz:

`Export Secure Boot Variables`

Wskaż Pendrive B.  
BIOS zapisze pliki `.esl` i `.auth` z aktualnymi kluczami do katalogu głównego.

#### 7.7 Test kontrolny

- Włóż **Pendrive D (custom-signed installer Pop!_OS)**.

- W zakładce **Boot** ustaw go jako pierwszy.

- Zapisz i uruchom ponownie (`F10`).

- Jeśli system się uruchamia — podpis działa poprawnie.

- Spróbuj włożyć inny nośnik (np. niesygnowany obraz live) → powinien być **zablokowany** przez UEFI.

### ✅ Checklista – „Wgrywanie kluczy Secure Boot”

| Status | Czynność                                  | Cel                             |
| ------ | ----------------------------------------- | ------------------------------- |
| ☐      | Secure Boot → Custom Mode                 | Ręczne zarządzanie kluczami     |
| ☐      | Secure Boot → Enabled                     | Aktywacja mechanizmu            |
| ☐      | PK.auth załadowany                        | Platform Key                    |
| ☐      | KEK.auth załadowany                       | Autoryzacja zmian               |
| ☐      | db.auth załadowany                        | Zaufane podpisy                 |
| ☐      | (opcjonalnie) dbx.auth załadowany         | Czarne listy (np. Microsoft CA) |
| ☐      | Pendrive B odłączony                      | Zabezpieczenie kluczy           |
| ☐      | Pendrive D działa, inne nośniki blokowane | Test poprawności                |

#### Skrypt kontrolny (dla systemu Linux po instalacji)

Po zakończeniu instalacji możesz zweryfikować klucze z poziomu systemu:

`sudo mokutil --sb-state sudo mokutil --pk sudo mokutil --kek sudo mokutil --db`

Oczekiwany wynik:

`SecureBoot enabled SecureBoot setup mode: no Platform key (PK): Present Key exchange key (KEK): Present`

#### 💡 Wskazówki bezpieczeństwa

- Pendrive B **trzymaj fizycznie oddzielnie od komputera**.

- Pendrive C (z kluczami prywatnymi) **nigdy nie podłączaj do internetu**.

- W BIOS nigdy nie włączaj opcji **Install Default Keys** — przywróci to Microsoftowe certyfikaty i unieważni całą procedurę

- Po każdej aktualizacji BIOS sprawdź, czy klucze pozostały aktywne — czasem aktualizacja przywraca klucze fabryczne

---

## 8) Hardening po instalacji (dalej OFFLINE)

- Utwórz konto awaryjne „break-glass”.
- Ustaw wymaganie hasła dla sudo.
- Włącz `auditd` i rejestrowanie zdarzeń.
- Ustal reguły wygaszania ekranu i blokady sesji.
- Włącz szyfrowanie swap.
- Zabezpiecz porty USB i fizyczne wejścia (USBGuard, BIOS).
- Ustaw fierwall
- Ustaw Wierd Guarda do tunelowania całego ruchu
- Po zakończeniu testów możesz przejść ONLINE

---

## 9) Materiały uzupełniające

#### 9.1 Czy `CMOS clear` / hard-reset (jumper / wyjęcie baterii) usuwa klucze Secure Boot?

##### Krótkie podsumowanie (najważniejsze)

- **Reset CMOS (F9 / Load UEFI Defaults)** i **wyjęcie baterii / zworka CLEAR_CMOS** zwykle *przywracają ustawienia BIOS* do wartości domyślnych, ale **nie zawsze usuwają wpisy Secure Boot zapisane w NVRAM**.

- ASRock ma w UEFI specjalne opcje do zarządzania kluczami: **„Clear Secure Boot Keys”** oraz **„Factory Key Provision” / „Install Default Secure Boot Keys”** — to one *bezpośrednio* kasują lub przywracają klucze fabryczne.

- Innymi słowy: **nie zakładaj, że sam fizyczny CMOS clear wykasuje PK/KEK/db** — lepiej się do tego nie posługiwać, jeśli chcesz zachować własne klucze.

##### Szczegóły i wyjaśnienie

- BIOS przechowuje ustawienia konfiguracyjne w obszarze CMOS (zasilanym baterią); UEFI z kolei zapisuje zmienne środowiskowe (w tym SecureBoot PK/KEK/db) w **NVRAM (UEFI variables)**. Na różnych płytach i wersjach firmware zachowanie przy fizycznym resetowaniu może się różnić — niektóre implementacje usuwają też zmienne NVRAM, inne ich nie dotykają. Dokumentacja ASRock wyraźnie opisuje oddzielne funkcje do czyszczenia/instalowania kluczy (Clear Secure Boot Keys / Install Default / Factory Key Provision), co sugeruje, że **manipulacja kluczami jest traktowana jako oddzielna operacja, niekoniecznie związana z prostym resetem CMOS**.

- Ponadto w instrukcji jest opcja **„Factory Key Provision”**, która *po platform reset* pozwala zainstalować fabryczne klucze — to znów wskazuje na to, że przywrócenie domyślnych ustawień niekoniecznie ingeruje w bazę kluczy bez wyraźnej akcji użytkownika.

##### Co robić praktycznie (zalecenia)

1. **Nie wykonuj fizycznego CMOS clear, jeśli chcesz zachować aktualne klucze**, chyba że masz pełne kopie zapasowe i plan na ich szybkie przywrócenie.

2. Zamiast tego używaj w UEFI opcji:
   
   - `Security → Secure Boot → Key Management → Export Secure Boot variables` — wyeksportuj kopię na Pendrive (ASRock pozwala eksportować zmienne).

3. **Jak sprawdzić stan po resetcie (Linux)**: po starcie systemu uruchom:
   
   `sudo mokutil --sb-state sudo efivar -l | egrep -i 'PK|KEK|db|dbx'`
   
   Jeśli wyniki pokazują obecność `PK`, `KEK`, `db` → klucze są nadal w NVRAM. (mokutil pokaże też czy SecureBoot jest enabled/disabled).

4. **Jeśli klucze „zniknęły”**:
   
   - Przywróć z kopii zapasowej utworzonej wcześniej przez BIOS (`Export Secure Boot variables`), lub
   
   - Wgraj ponownie `PK.auth`, `KEK.auth`, `db.auth` z **Pendrive B** (procedura z punktu 7).
   
   - Jeśli nie masz kopii: możesz użyć opcji `Install Default Secure Boot Keys` lub `Factory Key Provision` aby przywrócić klucze fabryczne — pamiętaj, że to **unieważni Twoje własne klucze** (wrócisz do kluczy vendor/Microsoft).

##### Krótka checklista do protokołu (dodatek do punktu 7)

- Przed resetem CMOS: **wyeksportuj Secure Boot variables** do pliku na Pendrive B.

- Jeśli musisz zrobić CMOS clear: miej przy sobie **Pendrive B (auth)** i **Pendrive C (klucze prywatne)** oraz instrukcję przywracania.

- Po każdym BIOS-reset / aktualizacji BIOS sprawdź obecność kluczy: `mokutil --sb-state` + `efivar -l`.

- Jeśli klucze zniknęły i nie chcesz kluczy fabrycznych → **przywróć z backupu** lub załaduj `PK/KEK/db` z Pendrive B.

##### Krótkie przypomnienie (ASRock, oficjalne polecenia)

- Opcja BIOS: **Install Default Secure Boot Keys** → instaluje klucze fabryczne.

- Opcja BIOS: **Clear Secure Boot Keys** → czyści domyślne klucze (dostępna w określonym stanie).

- Opcja BIOS: **Factory Key Provision** → pozwala zainstalować fabryczne klucze po platform reset.

Zawierają checklisty, fingerprinty GPG, lokalne sumy SHA256 i procedury odzyskiwania.

Zalecenie: wydrukuj krótką kartę z krokami bootowania i recovery, przechowuj ją z Pendrivem C.

#### 9.2 Skrypty

##### 9.2.1

##### 9.2.2

##### 9.2.3

##### 9.2.4

##### 9.2.5

##### 9.2.6

##### 9.2.7

##### 9.2.8

---

## 10) Bonus

Sekcja do rozbudowy. Zawierać będzie rozszerzenia takie jak:

- integracja TPM/UKI
- automatyczne aktualizacje podpisów kernela
- dodatkowe narzędzia hardeningu
- skrypt `launch_full_protocole.sh`

---
