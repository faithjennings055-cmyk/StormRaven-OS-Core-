# StormRaven OS — Ubuntu-only build (live ISO)

Ubuntu 24.04 (noble) base, Linux 6.8.0-147-generic, GNOME-less live system with StormRaven Kernel (Bifrost gateway) at /opt/stormraven and a systemd service auto-starting it at boot on port 8787.

- Branded: hostname `stormraven`, custom MOTD
- Login: user / live
- Boot menu: 1s timeout, serial console on ttyS0 too

## Reassemble
    cat StormRavenOS-ubuntu-amd64.iso.part* > StormRavenOS-ubuntu-amd64.iso
    sha256sum -c StormRavenOS-ubuntu-amd64.iso.sha256

Then write to USB: `dd if=StormRavenOS-ubuntu-amd64.iso of=/dev/sdX bs=4M status=progress` (or burn to DVD / boot in a VM).
