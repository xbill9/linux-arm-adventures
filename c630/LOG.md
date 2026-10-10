# C630 work log

Newest last. Times are local (EDT).

## 2026-10-09 / 10, overnight

- Installed Debian 13 (trixie) arm64 from a custom installer stick (C630 DTB, `setup.sh`: GRUB to the removable path, no NVRAM, DTB hook, kernel options).
- 01:01–01:05: desktop-related packages installed on trixie (rebuilt the 6.12.111 initramfs).
- 01:12: an attempted sway + Chrome install, rejected in the UI after apt had already started. Left Chrome half-unpacked (cleaned up at 01:19).
- 01:17: added "safety net" pieces: a `42_c630_fallback` GRUB entry, `apt-mark manual` on linux-image-6.12.111, a version-aware `zz-c630-dtb` hook, and a `sync-sdd1-grub` apt hook (mirrored GRUB onto the 16M hidden ESP).
- 01:19–01:28: **trixie → sid** full-upgrade: 659 upgraded, 113 new. Kernel 7.2.9, GRUB 2.12→**2.14**.

## 2026-10-10

- 10:06: `grub-reboot` into 7.2.9. Black screen. Then every kernel black, including the "known-good" 6.12 entry. See [INCIDENT-2026-10-10.md](INCIDENT-2026-10-10.md).
- 10:35: first rescue-over-SSH session (stick → Rescue → chroot → `mkdir /run/sshd; /usr/sbin/sshd`, key `~/.ssh/google_compute_engine`).
- 10:35–10:51: wrong turns: restored the hidden ESP (not in the boot path), tried netconsole (doesn't work over `cdc_ncm`), and edited the stick's partition 2 (the stick boots its ISO `efi.img` instead).
- 11:08: `scripts/apply.sh`: put the stick's shim + GRUB 2.12 on `/boot/efi`, added a hand-written `/boot/grub/c630.cfg` with `[via …]` markers, and held the grub/shim packages.
- 11:12: the menu shows `[via sda2 EFI/debian]`, so **the firmware boots sda2**. 6.12.107 boots. **Root cause: GRUB 2.14.**
- 11:15: `c630-menu` generator: per-kernel DTB, quiet + verbose entry per kernel, CONTROL entry, `--once`, and hooks in kernel postinst/postrm and initramfs post-update.
- 11:17: project `~/linux-arm-adventures` created, boot backups pulled, published to github.com/xbill9/linux-arm-adventures.
- 11:21, 11:22: plain reboots on 6.12.107 (quiet) work, back in about 45 s.
- 11:24: the user picked **7.2.9 verbose** from the menu. It boots. Battery, USB-C (UCSI) and the BT adapter appear.
- 11:25: **7.2.9 made the default** (`/etc/default/c630-menu`). Quiet 7.2 boot works.
- 11:29: **PAM fix**: copied `/usr/lib/pam.d/{systemd-user,polkit-1}` to `/etc/pam.d/` (sid libpam 1.7.0 doesn't read `/usr/lib/pam.d`).
- 11:30: plymouth pinned out (`/etc/apt/preferences.d/no-plymouth`). 7.2.9 initramfs backed up to `/boot/c630boot/initrd-7.2.9.pre-gnome`.
- 11:30–11:36: **GNOME (gnome-core, 665 pkgs) + Chrome 155 installed** (`scripts/gnome-install.sh`). The initramfs rebuild had an identical file list. The menu regenerated itself.
- 11:45: `protection-domain-mapper`, `rmtfs`, `tqftpserv`, `qrtr-tools` installed (not by the scripts here).
- 11:46: reboot. **GDM + GNOME Wayland session up.** `pd-mapper.service` fails (no maps).
- 11:52: **Bluetooth fixed**: `c630-bt-addr.service` sets the public address `02:BF:6F:61:DD:AB`. A scan found 16 devices.
- 11:54: **firmware found**: Lenovo C630 driver cabs (WOA-Project mirror, release 200.0.19.0) contain all 8 files the DTB requests, plus `wlanmdsp.mbn`. Saved to `firmware-local/` (git-ignored). See [FIRMWARE.md](FIRMWARE.md).
- 12:00: reboot (by the user). `c630-bt-addr.service` **failed**: `Set Public Address … failed with status 0x11 (Invalid Index)`, because `hci0` exists before the chip finishes loading its firmware.
- 12:08: `c630-bt-addr` now retries every 0.5 s for up to 30 s. Bluetooth is up again. The boot-time fix is not yet verified by a reboot.
- 12:08–12:16: safety net: `c630-menu` gained SAFE entries (`modprobe.blacklist=qcom_q6v5_pas,qcom_q6v5_mss,venus_core,ipa msm.skip_gpu=1` + pre-firmware initramfs), `C630_MODE=safe|full` and `--once`. `c630-fw-rollback` added. Pre-firmware initramfs copies saved.
- 12:16: test A: `--once` into 6.12.107 → booted it, **GRUB cleared `next_entry`** (one-time boots proven). The BT fix worked at boot.
- 12:18: test B: plain reboot → **SAFE 7.2.9 by default**. No DSPs, no GPU driver, display + GDM fine.
- 12:20: firmware installed (9 files), `c630-firmware` initramfs hook, pd-mapper masked. One-time FULL boot → **SoC reset ~6 s in**, **auto-recovered to SAFE** with no user action.
- 12:24–12:33: bisect with `--once <id> "<extra args>"`: GPU OK, DSPs OK, modem+IPA reset, modem alone OK, venus OK. **Culprit: IPA.**
- 12:33: `modprobe.blacklist=ipa` on all normal entries. Default back to normal mode (`C630_MODE=full`).
- 12:34: plain reboot: **everything up**. FD630 GPU, sound card, `wlan0`, venus, all four remoteprocs running, BT, GNOME. `systemctl is-system-running` = `running`.

## Next

- Connect Wi-Fi and test throughput. Fix the random Wi-Fi MAC.
- Test speakers, mic, headphone jack, sensors, suspend/resume, and external display over USB-C.
- Look at why IPA resets the SoC (firmware version vs. kernel's IPA v3.1 support?).
