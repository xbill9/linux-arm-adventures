# Galaxy Book Go: Samsung's ACPI tables

Dumped 2026-10-11 from this unit (NP340XLA-KA3CA, BIOS `P00AJW.036`). They are the authoritative description of the board: the Windows drivers use them, and the community DTS was partly guessed. Kept local only in `acpi-local/` (git-ignored): **`MSDM` holds the laptop's Windows product key.**

## How they were dumped (no typing on the laptop)

Linux boots this machine with a DTB, so `/sys/firmware/acpi/tables` doesn't exist, `acpidump` finds nothing, and `/dev/mem` refuses the RSDP page (`CONFIG_STRICT_DEVMEM`, the tables sit inside System RAM). `/sys/firmware/efi/systab` still gives `ACPI20=0xffffd000`, inside the EFI-reserved block `0xfff22000`–`0xffffdfff`.

1. `efi-shell-aa64` (trixie, 2025.02) → `/boot/efi/EFI/gbgo-shell/shellaa64.efi`, a marker file next to it, and [efi-shell/startup.nsh](efi-shell/startup.nsh) **at the root of the ESP**.
2. A GRUB entry `gbgo-efishell` (`chainloader`), booted once with `grub-reboot`.
3. The script finds the ESP by the marker (it is `fs12`-ish here, behind many FAT partitions on the UFS LUNs), runs `dmem 0xFFF22000 0xDC000 > mem.txt` and resets. About 10 s.
4. [scripts/acpi-from-dmem.py](scripts/acpi-from-dmem.py) rebuilds the bytes and follows RSDP → XSDT → tables; `iasl -d dsdt.dat`.

Every step was first reproduced in QEMU (`qemu-system-aarch64 -M virt` + AAVMF, the Samsung's exact shim, GRUB and shell, plus 12 extra FAT disks). That caught three mistakes before they cost reboots:

- **The shell only runs `startup.nsh` from the root of a filesystem**, not from its own directory. The first real attempt sat at `Shell>`.
- **The ESP is past `fs9`** when the disk has many FAT partitions; the first script searched `fs0`–`fs9`.
- **Debian's UEFI shell has no `acpiview`** (EDK2 builds it as a separate app). `dmem` with `>` redirection works instead (UTF-16 hex text, ~10 bytes per byte).

Tables (all inside the dump): `FACP`, `DSDT` (200287 bytes), `CSRT`, `DBG2`, `GTDT`, `IORT`, `APIC`, `MCFG`, `PPTT`, `SPCR`, `TPM2`, `MSDM`, `FPDT`, `BGRT`.

## GPIO numbering: virtual pins

Qualcomm's `GIO0` (`QCOM080D`, TLMM) declares the TLMM summary interrupt three times, then direct-connect (PDC) interrupts:

| `_CRS` interrupt | GSIV | PDC pin | TLMM GPIO (kernel `sc7180_pdc_map`) |
|---|---|---|---|
| #0–#2 | `0xf0` | (summary) | |
| #3 | `0x220` | 32 | 69 |
| #4 | `0x222` | 34 | 43 |
| #5 | `0x243` | 67 | **104** |
| #6 | `0x221` | 33 | 31 |
| #7 | `0x231` | 49 | 93 |
| #8 | `0x22a` | 42 | 4 |
| #9 | `0x232` | 50 | 3 |
| #10 | `0x259` | 89 | (none) |

A `GpioInt` pin number of `0x40·k` (k ≥ 3, beyond the 120 real pins) means **direct-connect interrupt #k**. Pins below 120 are plain TLMM GPIOs. Checked against two known pins: SD card detect `0xC0` → #3 → GPIO 69 (the usual SC7180 card-detect pin), touchpad `TCPD` `0x180` → #6 → GPIO 31 (the DTB's working touchpad IRQ), and the lid: `GIO0` reads it directly as GPIO `0x5D` = 93, and its own interrupt `0x1C0` → #7 → GPIO 93, the same pin both ways.

[scripts/acpi-gpioint.py](scripts/acpi-gpioint.py) lists all of them:

| Device | Pin | → GPIO | Flags |
|---|---|---|---|
| `ECKB` (keyboard, `\_SB.I2C7` @ `0x05`, `SSEC0001`) | `0x140` | **104** | Level, ActiveLow, wake, PullUp |
| `TCPD` (touchpad) | `0x180` | 31 | |
| `ECTC` (EC touchpad device, `\_SB.I2C8`) | `0x44` | 68 | |
| `EMEC` (Samsung EC, `SAM0604`) | `0x200`, `0x0a` | 4, 10 | |
| `RTK0` | `0x100` | 43 | |
| `SDC2` card detect | `0xC0` | 69 | |
| `GIO0` itself | `0x1C0` | 93 | |
| `GIO0` `LIDR` (lid, GpioIo) | `0x5D` | 93 | |
| `UAR4`, `UARD` (UART wake) | `0x29`, `0x2D` | 41, 45 | |

## What it fixed

- **Keyboard IRQ flood** (2026-10-11): TLMM 48 → **104**, pull-up. See [DEBIAN.md](DEBIAN.md#keyboard-irq-flood-fixed-1247).

## Still to read from it

- ADSP reserved memory and the sound hardware (`AUDD`, codecs) for audio.
- Battery/charger and backlight: probably behind the EC (`EMEC`, `I2C3`/`I2C5`/`I2C6`/`I2C8` dependencies).
- `ECTC` vs `TCPD`: two touchpad devices; the DTB only has the one on GPIO 31.
