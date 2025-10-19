# sprzątanie starej VM
sudo virsh destroy pophold-warsztat 2>/dev/null || true
sudo virsh undefine pophold-warsztat --nvram --managed-save 2>/dev/null || true
sudo rm -f /var/lib/libvirt/qemu/nvram/pophold-warsztat_VARS.fd

