# Galaxy Book Go: before the DTB boot fix (2026-10-11 10:49)

- `grub.cfg.before`, `default-grub.before`: the installer's stock GRUB setup (no `devicetree`, no `clk_ignore_unused pd_ignore_unused`, `quiet`).
- `boot/efi/`: the ESP (sda2). Taken just *after* the fix, which only moved `EFI/BOOT/fbaa64.efi` aside; that file is identical to `EFI/debian/fbaa64.efi` (sha256 `9a52f340e3c355ea…`). `Persisted_Capsules.bin` (70 MB) left out.
- On the laptop: `/root/gbgo-backup-20261011-104919/` (full ESP tar, the fallback loader, both files above).
