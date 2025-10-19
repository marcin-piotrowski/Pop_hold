#!/usr/bin/env bash
# enter_offline.sh — Hard offline mode for installation/hardening sessions
# This script helps you transition to an offline state in a controlled way.
# It will:
#  1) Prompt you to unplug Ethernet/disable hotspots,
#  2) Turn off all radios (Wi‑Fi/Bluetooth) via nmcli,
#  3) Disable NetworkManager networking for the session,
#  4) Bring down all non-loopback interfaces,
#  5) Flush default routes,
#  6) Verify that no default route remains.
#
# Usage:
#   chmod +x enter_offline.sh
#   sudo ./enter_offline.sh
#
# Notes:
# - The script makes only session-scoped changes (no permanent config files).
# - To go back online, either reboot OR run:
#     sudo nmcli networking on && sudo nmcli radio wifi on && sudo nmcli radio wwan on && sudo nmcli radio bluetooth on
#     # Optionally bring interfaces up again:
#     for d in $(ip -o link show | awk -F': ' '{print $2}' | grep -v -E '^(lo|ifb|veth|docker|br-|virbr|vmnet|vbox|zt|tailscale)'); do #       sudo ip link set dev "$d" up 2>/dev/null || true; done
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[!] Please run as root (use: sudo $0)"
  exit 1
fi

echo "== ENTER OFFLINE MODE =="
echo "[i] This will temporarily disable all networking for this session."
echo "    Close browsers and any apps that could auto-reconnect."
echo

echo "[1/6] Current device status:"
nmcli device status || true
echo

read -r -p "[2/6] Unplug ALL Ethernet cables and turn off any phone hotspots, then press ENTER to continue..." _

echo "[3/6] Turning off radios (Wi‑Fi / WWAN / Bluetooth) with nmcli..."
nmcli radio all off || true

echo "[4/6] Disabling NetworkManager networking for this session..."
nmcli networking off || true

echo "[5/6] Bringing down non-loopback network interfaces..."
# Collect likely physical/virtual interfaces but avoid loopback and common virtuals
for dev in $(ip -o link show | awk -F': ' '{print $2}' | grep -v -E '^(lo|ifb|veth|docker|br-|virbr|vmnet|vbox|zt|tailscale)'); do
  ip link set dev "$dev" down 2>/dev/null || true
done

echo "[6/6] Flushing default routes (if any)..."
ip route | awk '/^default/ {print $0}' && true
ip route del default 2>/dev/null || true

echo
echo "[✓] Verifying that no default route is present..."
if ip route | grep -q '^default'; then
  echo "[X] A default route still exists. You are NOT fully offline."
  echo "    Run 'ip route' and inspect any remaining defaults, then manually remove them."
  exit 2
else
  echo "[OK] No default route found."
fi

echo
echo "== OFFLINE MODE ACTIVE =="
echo "Tip: You can double-check with: ip route | grep '^default' (should return nothing)"
echo "To re-enable networking later, either reboot OR run:"
echo "  sudo nmcli networking on && sudo nmcli radio wifi on && sudo nmcli radio wwan on && sudo nmcli radio bluetooth on"
exit 0
