# Win11 ARM installer stick for the Galaxy Book Go

A stock Windows 11 ARM64 installer with the Book Go's own drivers loaded into Windows Setup. It was built on 2026-10-09; the USB drivers were added on 2026-10-10, and SMMU and PEP were removed again the same day.

**Status:** the first boot (2026-10-10, SMMU + PEP loaded first) crashed after about 2–3 drivers. The current version, without SMMU and PEP, is **untested**.

## The stick

PNY "USB 3.0 FD", 31.5 GiB, serial `AA61171F40013821`, one FAT32 partition labelled `WIN11ARM`.

| Path | What |
|---|---|
| `sources/boot.wim` | WinPE + Windows Setup, ARM64 build 26100.9457. Index 2 has `X:\Drivers` (107 driver folders + `load.cmd`) and `winpeshl.ini` |
| `sources/install.swm`, `install2.swm` | Win11 Home / Home Single Language / Pro, build 26300.9457, split for FAT32 |
| `GBGo-Drivers/` | 117 driver folders harvested from a Book Go's `DriverStore\FileRepository` |
| `autounattend.xml` | bypasses the TPM and Secure Boot checks; `DriverPaths` = `X:\Drivers` puts the drivers into the installed Windows |
| `Install-Drivers.cmd` | after install: `pnputil` adds every driver in `GBGo-Drivers/` |

`X:\Drivers` leaves out the audio APOs (`dax3_*`), the printers and the VPN tap drivers.

`sources/boot.wim` sha256: `7676045c6d8d81a6…` (current: USB, no SMMU/PEP), `b343dab7fca58753…` (USB + SMMU/PEP, crashed), `f340d2092271aafa…` (original, keyboard chain only).

The drivers are proprietary and are not in this repo.

## Boot flow

1. `winpeshl.ini` replaces WinPE's default shell. It runs `X:\Drivers\load.cmd`, then `X:\sources\setup.exe`.
2. `load.cmd` runs `drvload` on 20 drivers, in two passes, so that a driver whose parent was not ready yet gets a second chance. It logs to `X:\drvload-log.txt`. If a drive with `GBGo-Drivers` is visible, the log goes there instead, i.e. onto the stick.
3. Setup runs interactively. `autounattend.xml` handles the checks and the drivers for the installed system.

Load order (pass 1 = pass 2):

| # | Driver | Binds | Purpose |
|---|---|---|---|
| 1–17 | `qcscm`, `qcpmic`, `qcpmicgpio`, `qcspmi`, `secpmic3p`, `qcgpi`, `qcgpio`, `qcgsi`, `qci2c`, `qcspi`, `ec2`, `emuec`, `kbdhelper`, `samsungeventcontroller`, `swi2cdriver`, `tpadhelper`, `vhidevent` | | bus → EC → internal keyboard and touchpad |
| 18 | `ucmem` | `ACPI\VEN_SAM&DEV_0605` | Samsung USB-C connector manager. Added 2026-10-10 |
| 19 | `qcusbcucsi7180` (`d2ae44ab`, 3641.212) | `ACPI\QCOM08A9` | UCSI. Two versions exist; this is the newer. Added 2026-10-10 |
| 20 | `qcxhcifilter7180` | `ACPI\QCOM0826`, `URS\QCOM0897&HOST` | xHCI host. Added 2026-10-10 |

Left out: `qcusbfnssfilter7180` (USB device mode) and `rtucx22arm64` (Realtek USB NIC). Removed after the crash: `qcsmmu7180` (IOMMU, `ACPI\QCOM0200`, `QCOM0809`) and `qcpep.wd7180` (power framework, boot-start, `ACPI\QCOM0819`, `QCOM083B…083F`).

## Why the USB drivers were added

WinPE itself runs from RAM, but Setup reads `install.swm` from the stick over USB. Without the USB stack, Setup cannot find the image, and a USB keyboard is no fallback. The original `load.cmd` loaded only the internal keyboard's chain.

## Test results

| Date | `boot.wim` | Result |
|---|---|---|
| 2026-10-10 | `b343dab7fca58753…` | Crashed after about 2–3 drivers: `qcsmmu7180`, `qcpep.wd7180`, maybe `qcscm7180`. No `drvload-log.txt` on the stick, so USB never came up and the log was lost in RAM |

## Hypotheses (not yet tested)

- **SMMU or PEP caused the crash.** Both normally start at boot, and `drvload` starts them late. Not confirmed: the log is lost and the crash screen was not recorded. If the current version also crashes at its first drivers, `qcscm7180` is next in line.
- Whether inbox xHCI works on SC7180 without `qcxhcifilter7180` is unknown.
- `drvload` only loads drivers into the running WinPE. Injecting them offline with `dism /add-driver` into `boot.wim` would install them properly, but that needs a Windows machine. One NP345XLA user got no input even with NTLite injection (see `../README.md`).
- The different builds of `boot.wim` (26100) and `install` (26300) are assumed harmless.

## Testing it

Hub on the USB-C port, Secure Boot off (F2), F10 → the PNY stick.

| Result | Next |
|---|---|
| Setup appears and the internal keyboard works | install; afterwards run `Install-Drivers.cmd` from the stick |
| Keyboard works, Setup says a media driver is missing | Shift+F10, `type X:\drvload-log.txt` |
| Crashes at the driver window | note the last `[pass 1]` name on screen and any stop code |
| No input at all, internal or USB | bring the stick back; check for `drvload-log.txt` at its root |

## Files here

- `load.cmd`: the current `X:\Drivers\load.cmd` (CRLF).
- `winpeshl.ini`: as extracted from `boot.wim` index 2.
- `autounattend.xml`, `Install-Drivers.cmd`: as on the stick's root.
- `update-loadcmd.sh`: puts `load.cmd` into a mounted stick's `boot.wim` (`sh update-loadcmd.sh /run/media/$USER/WIN11ARM`). Needs `wimtools`.
