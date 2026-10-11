# Galaxy Book Go: trixie → sid (2026-10-11)

Started 13:38 with [scripts/gbgo-sid-upgrade](scripts/gbgo-sid-upgrade), run detached (`systemd-run --unit=gbgo-sid-upgrade`), log `/var/log/gbgo-sid-upgrade.log`. 1546 upgraded, 166 new, 17 removed, 10 held.

## Result (14:07)

Upgrade finished 14:03:53, `Result=success`, all 1712 packages set up, no dpkg errors. Now: systemd 262, GNOME 50.5, `initramfs-tools` 0.151, kernel 7.2.9+deb14 installed (not yet booted). GRUB 2.12-9+deb13u2 and shim 16.1 unchanged and held.

[scripts/gbgo-boot-verify](scripts/gbgo-boot-verify) (`/usr/local/sbin/`, run before any reboot) passed every check: GRUB/shim versions and holds, **all 9 ESP files hash-identical to the pre-upgrade backup**, `grub.cfg` syntax and default entry (DTB, `clk_ignore_unused pd_ignore_unused`, kernel, initrd), DTB/initrd/`grub.cfg` identical on the raw disk, known-good copies intact, every initramfs with storage/keyboard/display modules and 3/3 GPU firmware.

**`initramfs-tools` 0.151 rebuilt the initramfs of every installed kernel** (13:57), including the default 6.12.111. Compared with the known-good copy: 0 modules or firmware files gone, 17 new; the GPU firmware is in, thanks to the hook. Its first two runs had false FAILs from my own bugs (a `+` in the kernel version used as an awk regex; `pinctrl-sc7180` is built in, `=y`, and the regulator module is `qcom-rpmh-regulator`); confirmed by hand, then fixed.

First boot under sid (14:06, 6.12.111): `running`, no failed units; modem DSP up, Wi-Fi associated, Bluetooth `02:33:FD:7E:34:33` powered, venus, GPU `FD618`, keyboard (`keyboard pointer`, 0 flood lines), touchpad, power key, lid.

Changes sid brought:

- **Wi-Fi is now `wld0`**, not `wlan0` (systemd naming scheme v261, `ID_NET_NAME_ONBOARD`). `gbgo-wifi-kick` checked `/sys/class/net/wlan0` and only caught it by luck before the rename; it now checks for any netdev under `/sys/class/ieee80211/phy*/device/net/`.
- **`sudo` no longer has `/usr/local/sbin` in its path**: call the gbgo scripts by full path.
- While `openssh-server` was being upgraded, SSH connections were reset during key exchange for a few minutes; GNOME and its terminal were "wonky" until the run ended (old and new libraries mixed). Both expected; the upgrade itself kept going.

**Kernel 7.2.9 (14:10):** one-time boot passed everything; made the default. Its initramfs is saved as known-good. See [AUDIT-2026-10-11.md](AUDIT-2026-10-11.md#re-scan-1414-sid-kernel-729deb14).

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
