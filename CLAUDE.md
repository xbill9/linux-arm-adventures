# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Notes and scripts for running Debian on Windows-on-ARM laptops. **This repo lives on the Lenovo Yoga C630 it documents** (hostname `debian`). Docs edits and live system changes happen on the same machine, and a bad boot change or a reboot ends this session.

## Don't break the boot

- **Never unhold `grub*`/`shim*`** (`apt-mark hold`). GRUB 2.14 from sid blacks out every kernel. Only GRUB 2.12 from the stick works.
- The firmware boots `/boot/efi/EFI/BOOT/BOOTAA64.EFI` and ends at `/boot/grub/c630.cfg`, which `c630-menu` generates. `update-grub`'s `grub.cfg` is not what boots, so don't fix boot problems there.
- Every entry needs these kernel options: `clk_ignore_unused pd_ignore_unused regulator_ignore_unused usbcore.autosuspend=-1`, plus a DTB. Normal entries also need `modprobe.blacklist=ipa`. **Loading `ipa` resets the whole SoC**, including through a manual `modprobe ipa`.
- **Use UUIDs, never `/dev/sdX`.** The UFS has shown up as `sda`, `sdb` and `sdd` on different boots. UUIDs: root `a81deabf-0654-4f68-b795-284305d26f13`, the ESP the firmware boots `3BA7-7161`. `E725-516C` is a decoy ESP the firmware does not use.
- Test a risky change with a one-time boot (`sudo c630-menu --once <entry-id> ["extra args"]`), never by changing the default. Verify every file the boot depends on first (hashes, `grub-script-check`). Every reboot costs minutes.
- **Reboot only after the user confirms.** Before rebooting, run `sudo journalctl --flush; sync`.
- Recovery when it doesn't boot: `c630/RECOVERY.md`.

## Where things go

- Findings go in the topic doc: `c630/HARDWARE.md`, `QUIRKS.md`, `FIRMWARE.md`, `MODEM.md` or `WIFI.md`. `c630/LOG.md` gets a short dated entry that links to it.
- LOG.md: newest last, `- HH:MM:` bullets under `## YYYY-MM-DD`, local time. Take the time from `date +%H:%M`, not a guess. Keep `## Next` at the bottom up to date.
- Raw kernel logs go in `c630/logs/YYYY-MM-DD-<slug>.log`. A new file gets a line in the root `README.md` "Layout" block.
- **Mark what wasn't verified** ("Untested", "Not yet verified across a reboot", "## Hypotheses (not yet tested)"). Stating unverified things as fact has already cost rescue boots (`INCIDENT-2026-10-10.md`).
- Style: short declarative sentences, tables for status, backticks for paths, commands and kernel messages, ISO dates, sha256 shortened to 16 hex digits followed by `…`.

## Never commit

- `c630/firmware-local/`. It holds proprietary Lenovo/Qualcomm firmware, and the repo is public. Only hashes and source URLs go in the docs.
- Kernels, initrds or tarballs under `c630/backups/` (see `.gitignore`).

## Scripts

- POSIX `#!/bin/sh` with `set -e`, and a header comment saying what the script does and how to run it.
- The repo is the source of truth. **Edit only the repo copy**, then tell the user which file to install where (`/usr/local/sbin/`, `/etc/initramfs-tools/hooks/`, `/etc/systemd/system/`, `/etc/modprobe.d/`). Don't copy it to the live path yourself.

## Git

- Commit subject: `C630: <lowercase summary>`, with `;` joining several topics. Use the machine prefix for other machines.
- **Push after every commit** (`main`, origin `xbill9/linux-arm-adventures`).
