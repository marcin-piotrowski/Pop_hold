#!/usr/bin/env bash
set -euo pipefail

# Where libvirt keeps images (default storage pool)
IMAGES_DIR="/var/lib/libvirt/images"

# Sizes
MAIN_DISK_SIZE="80G"
USB_SIZE_A="8G"
USB_SIZE_B="2G"
USB_SIZE_C="4G"   # keys vault
USB_SIZE_D="16G"  # installer

sudo mkdir -p "$IMAGES_DIR"

echo "[1/5] Tworzenie głównego dysku systemowego..."
sudo qemu-img create -f qcow2 "$IMAGES_DIR/pophold-warsztat.qcow2" "$MAIN_DISK_SIZE"

echo "[2/5] Tworzenie wirtualnych pendrive'ów (qcow2)..."
sudo qemu-img create -f qcow2 "$IMAGES_DIR/pendriveA.qcow2" "$USB_SIZE_A"
sudo qemu-img create -f qcow2 "$IMAGES_DIR/pendriveB.qcow2" "$USB_SIZE_B"
sudo qemu-img create -f qcow2 "$IMAGES_DIR/pendriveC.qcow2" "$USB_SIZE_C"
sudo qemu-img create -f qcow2 "$IMAGES_DIR/pendriveD.qcow2" "$USB_SIZE_D"

echo "[3/5] (Opcjonalnie) Umieść ISO w katalogu obrazów:"
echo "       $IMAGES_DIR/ubuntu-24.04.1-desktop-amd64.iso"
echo "       Szybkie pobranie (jako root/sudo):"
echo "       sudo curl -L -o "$IMAGES_DIR/ubuntu-24.04.1-desktop-amd64.iso" https://releases.ubuntu.com/24.04/ubuntu-24.04.1-desktop-amd64.iso"

echo "[4/5] Upewnij się, że firmware OVMF Secure Boot jest zainstalowany:"
echo "       sudo apt install -y ovmf"

echo "[5/5] Gotowe. Dalej uruchom: ./define_and_start.sh"
