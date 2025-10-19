# Pop_hold! v0.2 — VMM Setup Pack

This pack contains ready-to-import libvirt assets for Virtual Machine Manager (VMM).

## Files

- `pophold_warsztat.xml` — domain XML for the workshop VM (OVMF + 4 USB pendrives)
- `create_volumes.sh` — creates qcow2 volumes (main disk + A/B/C/D pendrives)
- `define_and_start.sh` — defines the VM from XML and starts it

## Quick start

1. Copy files to your host and make scripts executable:
   
   ```bash
   chmod +x create_volumes.sh define_and_start.sh
   ```

2. Create volumes (disks):
   
   ```bash
   ./create_volumes.sh
   ```

3. (Optional) Put Ubuntu ISO at:
   `/var/lib/libvirt/images/ubuntu-24.04.1-desktop-amd64.iso`

4. Define and start the VM:
   
   ```bash
   ./define_and_start.sh
   ```

5. Open **Virtual Machine Manager**, select **pophold-warsztat**, and proceed with the protocol testing.

### Notes

- If your distro uses different OVMF paths, edit them in `pophold_warsztat.xml` and `define_and_start.sh`:
  - Common variants:
    - `/usr/share/OVMF/OVMF_CODE.secboot.fd` (Secure Boot)
    - `/usr/share/OVMF/OVMF_CODE.fd` (no SB)
    - VARS counterpart: `/usr/share/OVMF/OVMF_VARS.secboot.fd` or `/usr/share/OVMF/OVMF_VARS.fd`
- The 4 pendrives are empty qcow2 disks; your in-VM scripts will partition/format and fill them.
- Network is attached to the default libvirt NAT; when testing offline scripts, use them to bring interfaces down **inside** the guest.
- You can change RAM/CPU counts directly in the XML before defining the VM.

### Test env VM diagram

![](/home/gp/Documents/Sec/Pop_hold!/testing/c660a7bf-e1e2-47dd-a6ab-e3c844e00b34.png)

Have fun and break nothing ;)
