#!/usr/bin/env bash
set -euo pipefail

# 1_4_back_online.sh
# Kontrolowany powrót ONLINE

command -v nmcli >/dev/null || { echo "Wymagany nmcli (NetworkManager)." >&2; exit 1; }

echo "Włączam networking w NM..."
nmcli networking on || true
nmcli radio wifi on || true
nmcli radio wwan on || true
nmcli radio bluetooth on || true

# Podnieś znane połączenia automatycznie
echo "Podnoszę dostępne profile (auto)..."
nmcli -t -f NAME,UUID,DEVICE c show --active || true
nmcli dev status

# Spróbuj DHCP na interfejsach 'connected (externally)'
for IF in $(nmcli -t -f DEVICE,STATE dev | awk -F: '$2 ~ /disconnected|unmanaged/ {next} {print $1}'); do
  nmcli dev connect "$IF" || true
done

sleep 2
echo "Trasy routingu:"
ip route || true

# DNS sanity
RES="/etc/resolv.conf"
if ! grep -Eqi 'nameserver' "$RES"; then
  echo "Brak nameserver w $RES — dodaję 1.1.1.1 i 9.9.9.9 tymczasowo."
  printf "nameserver 1.1.1.1\nnameserver 9.9.9.9\n" | sudo tee "$RES" >/dev/null
fi

echo "Test łączności (ping, http)..."
ping -c1 1.1.1.1 >/dev/null 2>&1 && echo "[OK] ping 1.1.1.1" || echo "[WARN] ping 1.1.1.1 fail"
curl -s --max-time 5 https://deb.debian.org >/dev/null && echo "[OK] HTTP test" || echo "[WARN] HTTP test fail"

echo "Gotowe ✅"

