# Galaxy Book Go: trixie → sid (2026-10-11)

Started 13:38 with [scripts/gbgo-sid-upgrade](scripts/gbgo-sid-upgrade), run detached (`systemd-run --unit=gbgo-sid-upgrade`), log `/var/log/gbgo-sid-upgrade.log`. 1546 upgraded, 166 new, 17 removed, 10 held.

## What protects the boot (C630 lessons, [../c630/INCIDENT-2026-10-10.md](../c630/INCIDENT-2026-10-10.md))

| C630 failure | Here |
|---|---|
| sid's GRUB 2.14 blacked out every kernel | `apt-mark hold` on all `grub*` (6) and `shim*` (4) packages; the script checks each hold before touching sources. GRUB stays 2.12-9+deb13u2 |
| sid's `initramfs-tools` copies no `qcom/` firmware | [initramfs/gbgo-firmware](initramfs/gbgo-firmware) → `/etc/initramfs-tools/hooks/` adds `a630_sqe.fw`, `a630_gmu.bin` and the zap shader |
| New kernel as default | `linux-image-6.12.111+deb13-arm64` held; `GRUB_DEFAULT=gbgo-6.12.111+deb13-arm64` unchanged. A sid kernel gets its own entries (generator) and is tried with `grub-reboot` first |
| Rebuilt initramfs breaks boot | SAFE entries boot `/boot/gbgo-known-good/initrd.img-<kver>` (copies with `SHA256SUMS`, taken before any change today) |

## Backup (off the machine)

`~/backups/gbgo-2026-10-11-pre-sid/` on the yoga9i (not in this repo): `root/` = `rsync -aHAXx --numeric-ids` of `/` (7.9 GB, 345 s over Ethernet), `esp/` = `/boot/efi`. Checked: DTB, kernel, initramfs, `/etc/default/grub`, the GRUB generator and shim hash the same as live; `/etc/shadow` `root:shadow 640`, `sudo` `4755`.

Two failed attempts first, both silent: the log redirect into a root-owned folder, then no `rsync` on the yoga9i (the background job still exited 0). Check the copy, not the exit code.

## Recovery

| Symptom | Do |
|---|---|
| Menu shows, default hangs/black | hold power 10 s; pick `… SAFE` (6.12.111, known-good initramfs) or 6.12.107 |
| No GRUB menu | Debian stick on the hub, F10 → stick → **Galaxy Book Go: Rescue mode (with DTB)** → `sda3` → Execute a shell → `mkdir /run/sshd; /usr/sbin/sshd`; then put GRUB 2.12 back from `esp/` of the backup |
| Whole system broken | same rescue shell; from the yoga9i: `sudo rsync -aHAXx --numeric-ids --delete -e "ssh … -o HostKeyAlias=gbgo" --rsync-path="sudo rsync" ~/backups/gbgo-2026-10-11-pre-sid/root/ xbill@192.168.0.65:/` (into the chroot's `/`) |
