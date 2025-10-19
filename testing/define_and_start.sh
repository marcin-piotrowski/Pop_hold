#!/usr/bin/env bash
set -euo pipefail

DOMAIN_XML="pophold_warsztat.xml"
DOMAIN_NAME="pophold-warsztat"
NVRAM_DST="/var/lib/libvirt/qemu/nvram/${DOMAIN_NAME}_VARS.fd"
NVRAM_SRC_SECBOOT="/usr/share/OVMF/OVMF_VARS.secboot.fd"
NVRAM_SRC="/usr/share/OVMF/OVMF_VARS.fd"

# Ensure libvirt is running
sudo systemctl enable --now libvirtd || sudo systemctl enable --now libvirt-daemon

# Prepare per-VM NVRAM vars (so Secure Boot keys persist per VM)
if [[ -f "$NVRAM_SRC_SECBOOT" ]]; then
  SRC="$NVRAM_SRC_SECBOOT"
elif [[ -f "$NVRAM_SRC" ]]
then
  SRC="$NVRAM_SRC"
else
  echo "Could not find OVMF_VARS* file. Install ovmf package."
  exit 1
fi

sudo mkdir -p "$(dirname "$NVRAM_DST")"
sudo cp -n "$SRC" "$NVRAM_DST"

# Define VM
sudo virsh define "$DOMAIN_XML"

# Autostart off by default; start it now
sudo virsh start "$DOMAIN_NAME"

echo "VM '$DOMAIN_NAME' defined and started."
echo "Open Virtual Machine Manager to view the console."
