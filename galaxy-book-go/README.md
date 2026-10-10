# Samsung Galaxy Book Go

Snapdragon 7c Gen 2. Status: **broken, not yet investigated** (as of 2026-10-10).

## To find out first

- What's broken: no boot at all, black screen after GRUB, boots but no display/keyboard/network, or something else?
- What's installed: distro and release, kernel, how it was installed (which stick or image)
- Boot chain: which ESP(s) exist, and **which one the firmware actually runs** (use `[via …]` markers, see the C630 lessons)
- Whether the firmware can write EFI variables
- Which DTB it boots with, and where it comes from (upstream kernel, hand-built, …)
- Network path for rescue-over-SSH (USB Ethernet adapter? Its driver matters, since `cdc_ncm` breaks netconsole on the C630)

## Notes

_(nothing yet)_
