---
name: boot-test
description: Prepare and run a risky boot experiment on the C630 (extra kernel args, a patched device tree, a new kernel or initramfs) as a one-time boot that falls back to the known-good default.
disable-model-invocation: true
---

Boot experiment: $ARGUMENTS

The default menu entry must stay untouched. A hang plus a power cycle has to land back on the known-good default.

1. **Pick the mechanism:**
   - Extra kernel args: `sudo c630-menu --once c630-<kver> "<args>"`.
   - Device tree change: copy `/boot/c630boot/dtb-<kver>` to `/boot/c630boot/dtb-<kver>.test` and patch it with `fdtput`. Confirm with `fdtget`/`dtc -I dtb -O dts | diff` that only the intended property changed. Run `sudo c630-menu` (it adds `c630-dtbtest-<kver>`), then `sudo c630-menu --once c630-dtbtest-<kver>`.
   - New kernel or initramfs: check `/boot/c630boot/dtb-<kver>` exists and that `/boot/grub/c630.cfg` has its entry, then `--once` that entry.
2. **Verify before rebooting:**
   - `grub-script-check /boot/grub/c630.cfg`.
   - The `--once` entry id exists in `c630.cfg`.
   - `grub-editenv /boot/grub/grubenv list` shows the one-time entry.
   - The default (`/etc/default/c630-menu`) is unchanged.
   - Hashes of anything copied into `/boot`.
3. **Make a crash cheap:** `sudo journalctl --flush; sync; sudo sh -c 'fsfreeze -f / && fsfreeze -u /'`.
4. Write down now, in `c630/LOG.md`, what is being tested and what success and failure look like. The session ends at reboot.
5. Commit and push (`C630: …`).
6. **Ask the user to confirm the reboot**, then `sudo systemctl reboot`. If GNOME blocks shutdown, say so. Don't force it without asking.
7. Tell the user what to check after the boot: `journalctl -b -1 -k` if it crashed and fell back, `cat /proc/cmdline` to see which entry booted, and the specific success signal.
