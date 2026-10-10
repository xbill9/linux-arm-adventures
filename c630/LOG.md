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
- 12:58: modem investigation: `qmicli -d qrtr://0` works. LTE model (IMEI, `umts, lte`, SIM slot present, no SIM). ModemManager finds no modem.
- 13:03: `sudo modprobe ipa` on the running system: the IPA driver initialized, the GSI timed out about 3 s later, then an RPMh timeout and a **hard lockup**. The watchdog reset it and it came back on its own in about 50 s (IPA blocked). Not a boot-ordering problem. Log saved: `logs/2026-10-10-ipa-modprobe-crash.log`. See [MODEM.md](MODEM.md).
- 13:11–13:19: **`gsi-loader = "modem"` test** (patched DTB, one-time boot via the new `c630-dtbtest-<kver>` menu entry; the forced reboot was needed because the GNOME session was blocking shutdown). `modprobe ipa`: no lockup. Modem restart: IPA sees all modem events, but the modem never loads/signals GSI, so there's no `rmnet_ipa0`. Safe but inert. The C630 got 192.168.0.65 from DHCP on this boot. See [MODEM.md](MODEM.md).
- 13:24: **captive portals**: installed `network-manager-config-connectivity-debian`. Wi-Fi gets a stable per-network MAC (`wifi.cloned-mac-address=stable`, since the hardware MAC is random each boot). Added a "Wi-Fi Login" launcher (`xdg-open http://neverssl.com/`, Chrome is the default browser).
- 13:26–13:34: audio tests. The speaker tone played without errors (whether it was audible isn't confirmed). The "Mic" in UCM is the **headset** mic (AMIC2), which hisses at −18 dBFS with nothing plugged in. A DMIC scan found activity only on **DMIC2/DMIC3**. Voice test pending.
- 13:35: audit of drivers, firmware, hardware and system tools: [AUDIT-2026-10-10.md](AUDIT-2026-10-10.md).
- 13:38: **DNS broken by my 13:24 `nmcli general reload conf`** (NetworkManager emptied `/etc/resolv.conf`; ifupdown/dhcpcd owns the Ethernet). Restored `nameserver 192.168.0.1`.
- 13:40: installed `apt-listbugs`, `needrestart`, `linux-perf`, `gpiod`, `pavucontrol`, `timeshift` (57 packages, nothing in the boot path, holds intact).
- 15:46: **first Wi-Fi connection** (Starbucks). The 5 GHz channel-112 (DFS) BSS refused the association (`code=18`), then auth timed out. Regdomain was `00`. Pinned the profile to 2.4 GHz (`802-11-wireless.band bg`), and it connected (172.16.225.64/22). The Meraki captive portal was found, but the USB tether's default route (metric 100) hides it. See [WIFI.md](WIFI.md).
- 15:50: `/etc/modprobe.d/regdom.conf` → `options cfg80211 ieee80211_regdom=US` (cfg80211 is a module, not in the initramfs). Not yet verified across a reboot. `iw` turned out to be installed already, at `/usr/sbin/iw` (not on the user PATH).
- 16:04–16:16: **screen kept dimming after ~30 s idle** although GNOME had `idle-dim=false` and blank set to Never. Debug-restarted `gsd-power` (GNOME 51, `gnome-settings-daemon` 51.0-2): it arms `dim callback for 30s` regardless of `idle-dim`, `idle-brightness` (100 made no difference) or `idle-delay` (7200 made no difference), then calls `org.gnome.Shell.Brightness.SetDimming true` (backlight 2882 → 1256). Cause: the power profile was **power-saver** (on AC, battery full). `powerprofilesctl set balanced` → no dim in the next minute. Settings restored (`idle-brightness` 30, `idle-delay` 0). Seen on the way: `iio-sensor-proxy` segfaults at boot (no ambient light sensor anyway, only `accel_3d`); the battery exposes no `capacity` file; kbd-backlight dim fails harmlessly (no kbd backlight).
- 16:25: **timeshift disabled: too slow.** It had been set up as rsync to `/dev/sdb3`, which is `/` itself (no protection from disk loss), with daily/weekly/boot schedules and an apt `DPkg::Pre-Invoke` hook (`/usr/local/sbin/c630-apt-snapshot`) that snapshots before every package change. Neither snapshot ever finished (rsync sat at 0%); two partial ones (14:07, 16:18) left **12 GB** in `/timeshift/snapshots`. Turned off all `schedule_*` in `/etc/timeshift/timeshift.json` (backup: `timeshift.json.bak-2026-10-10`), removed `/etc/cron.d/timeshift-{hourly,boot}`, and renamed the hook to `/etc/apt/apt.conf.d/05c630-timeshift.disabled` (apt ignores `*.disabled`). The package is still installed. Note: any `timeshift` command re-adds the cron files while a schedule is on in the config.
- 16:30: deleted `/timeshift` (the two partial snapshots). `/` went from 24G used to 12G.
- 16:30–16:40: **firmware quirks and keyboard lockups written up** in [QUIRKS.md](QUIRKS.md), from the installer log and all 22 journal boots. The keyboards that locked up during the install (built-in and Lenovo USB-C receiver, as the user reported) predate `regulator_ignore_unused usbcore.autosuspend=-1`. Neither option is in the stick's original `grub.cfg`, and both are on every entry now. The **RTC never gets set** (reads 1970-01-03), so journal times before the first NTP sync are wrong: today's 14:30 boot really started about 15:40. Also found: GNOME's idle timer **suspended the machine at 12:49**, and it resumed at 13:00 with 19 hard-LOCKUP watchdog reports (CPUs in `cpuidle_enter_s2idle`) and 31 EC I2C errors, but came back. Log: `logs/2026-10-10-s2idle-resume-lockup.log`. HARDWARE.md had the keyboard device wrong (it listed the touchpad), now fixed.
- 16:45: **other hardware issues** added to [QUIRKS.md](QUIRKS.md#other-hardware-issues): `iio-sensor-proxy` segfaults at boot (the unit is left `failed`, so no auto-rotate), speaker amp `wsa881x :00:4` failed a register read, and the modem logs `port failed halt` on every stop. Storage, Wi-Fi firmware, USB and thermal are clean.
- 16:54: **reviewed [rigoorozco/yoga-alarm](https://github.com/rigoorozco/yoga-alarm)** (Arch Linux ARM packages for the C630, last pushed 2026-08-15). Useful: a UCM speaker/headphone routing fix ([HARDWARE.md](HARDWARE.md)), the postmarketOS firmware set with pd-mapper `.jsn` maps and a different IPA blob ([FIRMWARE.md](FIRMWARE.md), [MODEM.md](MODEM.md) hypothesis 1), and its kernel config delta. Nothing tried yet.

## Next

- Fix the resolv.conf fight for good: let NetworkManager manage the USB Ethernet (see AUDIT).
- Built-in mic: voice test on DMIC2/DMIC3, then mic bias/gain, then a UCM `Mic (internal)` device.
- Screen dim: confirm it stays off on `balanced` over a longer idle and across a reboot.
- Wi-Fi: reboot and confirm regdomain `US` at boot. Retry 5 GHz (non-DFS BSS). Test throughput.
- Suspend: decide on GNOME/GDM idle auto-suspend, then a deliberate `systemctl suspend` test (EC, Wi-Fi, audio after resume). See [QUIRKS.md](QUIRKS.md#suspend-s2idle-and-the-resume-lockup-storm).
- Confirm the keyboard-lockup cause: a one-time boot without `regulator_ignore_unused`, then without `usbcore.autosuspend=-1`, with SSH open.
- Speakers: `speaker-test -c2 -t wav`, and check both WSA881x amps play. If silent, try yoga-alarm's UCM routing (see [HARDWARE.md](HARDWARE.md)) with `dpkg-divert` on `HiFi-MM1.conf` so an `alsa-ucm-conf` upgrade doesn't silently undo it.
- `iio-sensor-proxy`: make it survive boot (restart on failure, or install `hexagonrpcd`).
- Test mic, headphone jack, sensors, and external display over USB-C.
- IPA/LTE data: test the hypotheses in [MODEM.md](MODEM.md) (firmware build, `gsi-loader = "modem"`, interconnect votes). A SIM is needed for an end-to-end test.
