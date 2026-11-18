# Galaxy Book Go: testing GRUB 2.14 (2026-11-18)

GRUB and shim are held at 2.12-9+deb13u2 and 16.1-2~deb13u1 ([SID.md](SID.md)). The hold came from the C630, where sid's GRUB 2.14 blacked out every kernel ([../c630/INCIDENT-2026-10-10.md](../c630/INCIDENT-2026-10-10.md)). **GRUB 2.14 has never run on this machine.** This test runs it without installing it: the packages stay held, and `EFI/BOOT` and `EFI/debian` are untouched.

## Method

| Stage | Chain | Armed by |
|---|---|---|
| grub | firmware → shim 16.1 (held) → GRUB 2.12 → **GRUB 2.14** → kernel | `gbgo-grub214-test arm` |
| shim | firmware → shim 16.1 (held) → GRUB 2.12 → **shim 16.1-2 (sid)** → **GRUB 2.14** → kernel | the boot check, after a grub PASS |

- `/boot/efi/EFI/grub214/`: `grubaa64.efi` from `grub-efi-arm64-signed` 1+2.14+5 (`503d697c5d911946…`), `shimaa64.efi` from `shim-signed` 1.51+16.1-2 (`01ee1ab90c874adc…`), `mmaa64.efi` from `shim-helpers-arm64-signed` 1+16.1+2. Unpacked with `dpkg-deb -x`, never installed. `SHA256SUMS` in the same folder.
- The live loaders are `e5446d2a09dfae3f…` (shim) and `3db6ed77b8de1677…` (GRUB 2.12). The new shim's hash differs, so the shim stage tests a different binary.
- The 2.14 image has its prefix built in as `/EFI/debian`, so it reads the same `EFI/debian/grub.cfg` stub and then `/boot/grub/grub.cfg` as 2.12 does.
- That `grub.cfg` loads modules not built into the 2.14 image (`all_video`, `png`, `bli`). From `/boot/grub/arm64-efi` those would be 2.12 modules. So [scripts/00_grub214](scripts/00_grub214) (`/etc/grub.d/`) puts a branch at the top of `grub.cfg`, before any `insmod`: under 2.14 only (`feature_gcry_hw_accel` is defined by 2.14 and not by 2.12, checked with `strings` on both images) it jumps to `EFI/grub214/grub.cfg`, which uses built-in commands only.
- [scripts/09_galaxy-book-go](scripts/09_galaxy-book-go) adds the one-time entries `gbgo-grub214-grub` and `gbgo-grub214-shim`. Each saves `g214_stage` to `grubenv` and chainloads its file.
- The 2.14 test menu boots 7.3.4+deb14 (`GRUB_DEFAULT`; booted under 2.12 on 2026-11-14 20:17, initramfs unchanged since 2026-11-13). The kernel command line carries `gbgo_grub=214 gbgo_g214=<stage>`. A second entry boots without the initramfs: a root-mount panic on screen would show the kernel handoff works.
- [scripts/gbgo-grub214-test](scripts/gbgo-grub214-test) `check` runs at boot ([system/gbgo-grub214-test.service](system/gbgo-grub214-test.service)). It records PASS only when both markers are on `/proc/cmdline`, then arms the shim stage and reboots in 2 minutes (`sudo shutdown -c` cancels). Anything else is FAIL, and the test stops. Results: `sudo gbgo-grub214-test status` (`/var/lib/gbgo-grub214/results.log`).
- A hang or black screen: hold power 10 s. GRUB 2.12 has already cleared `next_entry`, so the next boot is the normal default, and the check records FAIL.

Checked before arming: `gbgo-grub214-test verify` (hashes, `grub-script-check` on both menus, entries present, the 2.14 branch on line 9 before the first `insmod` on line 51, kernel/initrd/DTB present, no 2.14 in `EFI/BOOT` or `EFI/debian`), the existing ESP files hash-identical to before, `gbgo-boot-verify` passed.

**Not yet verified across a reboot.** Not checked: whether Secure Boot is on (`mokutil` reports no EFI variables under this kernel). Both the 2.14 GRUB and the new shim are signed, so the chain should load either way. Untested.

## Results

Pending: armed 2026-11-18 13:22 (`next_entry=gbgo-grub214-grub`).

## Clean up

Remove `/etc/grub.d/00_grub214`, `/boot/efi/EFI/grub214`, `/var/lib/gbgo-grub214`; `systemctl disable gbgo-grub214-test`; `update-grub`; `gbgo-boot-verify`.
