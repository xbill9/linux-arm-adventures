# C630 firmware quirks and keyboard lockups

BIOS `9UCN34WW(V3.01)`, 2019-06-19 (AMI, EFI 2.6). Collected 2026-10-10 from the installer log (`/var/log/installer/syslog`) and the 22 boots in the journal. Quirks already written up elsewhere are only linked here.

## Keyboard lockups during the initial install

**Reported by the user:** during the initial install, the **built-in keyboard** and the **Lenovo USB-C receiver** keyboard locked up.

**No log shows a lockup.** The only installer log on disk is from the run that finished (installed 2026-10-09 22:58). It has no i2c-hid errors, no USB disconnects and no resets. The built-in keyboard (`6243:0001`), the touchpad, the touchscreen and a USB keyboard (the Megawin, not the Lenovo receiver) all came up and stayed up. Earlier attempts left no logs.

**What changed between the stick's first menu and the run that finished:**

| | Kernel options |
|---|---|
| Stick's original `grub.cfg` ([backups/…/root/usb-efi-debian-grub.cfg.orig](backups/c630-2026-10-10/root/usb-efi-debian-grub.cfg.orig)) | `clk_ignore_unused pd_ignore_unused` |
| Installer run that finished (installer syslog line 84) | `clk_ignore_unused pd_ignore_unused` **`regulator_ignore_unused usbcore.autosuspend=-1`** |

Both added options have been on every boot entry since (`P=` in [scripts/c630-menu](scripts/c630-menu) and [scripts/apply.sh](scripts/apply.sh)). None of the 22 journal boots since then shows a keyboard lockup.

**Likely mechanism (not reproduced):**

- **Built-in keyboard and touchpad, `regulator_ignore_unused`.** Every i2c-hid device logs `supply vdd not found, using dummy regulator` and `supply vddl not found`. The DT doesn't say which rails power them, so Linux sees those rails as unused. About 30 s after boot, the regulator core switches unused rails off unless `regulator_ignore_unused` is set. That would cut the keyboard and touchpad partway into the installer: they work at first, then go dead. `clk_ignore_unused` and `pd_ignore_unused` do the same job for clocks and power domains (the I2C engines' clocks, for example).
- **USB keyboards, `usbcore.autosuspend=-1`.** With autosuspend on, an idle USB device or hub is suspended after 2 s and has to wake itself on a keypress. A receiver or hub that doesn't wake looks like a dead keyboard until it's replugged.

**To confirm it:** make a one-time test entry that leaves out `regulator_ignore_unused`. `c630-menu --once` can only add options, so this needs a menu change. Then wait more than 30 s at the GDM prompt before typing. Repeat with `usbcore.autosuspend=-1` left out, using the USB receiver. Keep SSH open, because the keyboard may not work.

**Where the keyboard actually is** (HARDWARE.md had this wrong before 2026-10-10):

| Device | Bus | Notes |
|---|---|---|
| Keyboard `hid-over-i2c 6243:0001` | `i2c-11` (`a8c000.i2c`), address `0x5c`, IRQ on TLMM GPIO 92 | The same HID device also carries `Wireless Radio Control` and the **HID sensor hub** (`accel_3d`). `systemd-logind` watches it for system buttons |
| Touchpad `06CB:CD3E` | `i2c-3`, `0x2c` | `3-0015` is the other model variant's address, so it stays unbound |
| Touchscreen + pen `04F3:279F` | `i2c-5`, `0x10` | `IRQ triggered but there's no data` at every boot. Harmless |
| EC (`lenovo_yoga_c630`, battery, UCSI) | `i2c-1` (`884000.i2c`), `0x70` | Not the keyboard |

## The weird GRUB setup (install time)

Each of these cost at least one reboot. Details are in [INCIDENT-2026-10-10.md](INCIDENT-2026-10-10.md) and [RECOVERY.md](RECOVERY.md).

- **From the stick, the firmware boots the ISO's internal `efi.img`, not the stick's partition 2.** Edits to partition 2 do nothing.
- **The stick's GRUB finds itself by a file, not a UUID** (`search --file /.disk/id/a0bf5d39-…`), and finds the DTB with a second search for `/c630.dtb`. The three `Yoga C630:` entries load it with `devicetree`. **The stock Debian menu is pulled in underneath** (`source $prefix/${grub_cpu}-efi/grub.cfg`), and its entries load **no DTB**. Without a DTB the kernel gets ACPI only, so those entries don't work on this machine.
- **The installer's `---` split:** kernel options go after `---`. Everything before it (`grub-installer/force-efi-extra-removable=true grub2/update_nvram=false grub2/force_efi_extra_removable=true preseed/late_command=/cdrom/c630/setup.sh`) is a debconf preseed, which the kernel passes to the installer ("Unknown kernel command line parameters … will be passed to user space"). Options after `---` are copied onto the installed system's command line.
- **On the disk, the firmware boots only the removable path on sda2** (`EFI/BOOT/BOOTAA64.EFI`). It ignores the hand-built 16M ESP that holds GRUB as `EFI/Microsoft/Boot/bootmgfw.efi`, and it has no NVRAM boot entries.
- **GRUB 2.14 (sid) black-screens every kernel.** GRUB 2.12 from the stick works and is held.

## Firmware quirks

| Quirk | Evidence | Effect / workaround |
|---|---|---|
| **The RTC is never set** | `rtc-pm8xxx … setting system clock to 1970-01-03T…` at every boot. `/sys/class/rtc/rtc0` reads 1970-01-03 (ticking). The DT node has no `allow-set-time`, so Linux never writes it | **The clock is wrong until NTP syncs.** It starts from the last-shutdown time in `/var/lib/systemd/timesync/clock`. The installer log is stamped `Jan 3 03:05` (1970). The oldest boot in the journal was logged as **2026-04-13**, probably systemd's built-in minimum time. Boot 0 on 2026-10-10 was logged as starting 14:30:24, but it really started about 15:40 (uptime). The clock stepped at the first NTP contact (15:46:36, over Wi-Fi). **Journal times before the first NTP sync in a boot are wrong**, and so are `--since`/`--until` filters on them. Offline TLS and apt can fail on a stale clock |
| **No EFI variables at runtime** | `integrity: Couldn't get size: 0x8000000000000003` (`EFI_UNSUPPORTED`), `MODSIGN: Couldn't get UEFI db list`. `efibootmgr`: "EFI variables are not supported" | Only the removable boot path works, and `grub2/update_nvram=false` is needed. See [README.md](README.md#boot-chain-as-of-2026-10-10) |
| **The EFI Memory Attributes table is garbage** | `efi: memattr: Unexpected EFI Memory Attributes descriptor size …` / `table version …`, with a different value nearly every boot: `0`, `1818326128` (`0x6c617470`, ASCII `ptal`), `-1347440896` (`0xafafaf00`, a fill pattern), `1080035085` | The firmware hands over uninitialised memory. The kernel ignores the table. Harmless |
| **SMBIOS says the firmware isn't UEFI** | fwupd: `SMBIOS BIOS Characteristics Extension Byte 2 is invalid -- UEFI specification is unsupported, but /sys/firmware/efi exists!` | fwupd won't offer UEFI capsule updates. BIOS updates would need Windows or Lenovo's own tool |
| **The hardware watchdog tops out at 32 s** | `qcom_wdt`: `max_timeout` 32. `Failed to set watchdog hardware timeout to 10min: Invalid argument` at every shutdown | systemd's default 10-minute shutdown watchdog is rejected, so a hung shutdown isn't caught. `RebootWatchdogSec=30s` in `system.conf` would fit. Not changed. The runtime watchdog still resets the SoC on a hard lockup (that's how the IPA crash recovers) |
| **PSCI PC mode** | `psci: OSI mode supported.` then `[Firmware Bug]: failed to set PC mode: -3` | The kernel stays in OS-initiated mode. Known on this firmware |
| **No MAC addresses provisioned** | Wi-Fi: `ath10k_snoc … invalid MAC address; choosing random` at every boot. Bluetooth: no public address | Handled by the stable per-network MAC ([WIFI.md](WIFI.md)) and `c630-bt-addr.service` |
| **USB-C firmware repeats alt modes** | `ucsi_yoga_c630 … Firmware bug: duplicate partner altmode SVID 0xff01` about every 0.5 s with a dock plugged in | Floods the log. See [HARDWARE.md](HARDWARE.md#known-noise-in-the-logs) |
| **6.12 only: a clock WARNING at boot** | `WARNING … drivers/clk/clk.c:1200 clk_core_disable` from `dsi_phy_driver_probe` (msm), 4× on every 6.12.107/6.12.111 boot, never on 7.2.9 | The display still comes up. Another reason to stay on 7.2 |
| **IPA firmware resets the SoC** | GSI timeouts → RPMh timeout → hard lockup → watchdog reset | Blocked. See [MODEM.md](MODEM.md) |

## Suspend (s2idle) and the resume lockup storm

Only `s2idle` is offered (`/sys/power/mem_sleep` = `[s2idle]`). It has run once, without anyone asking for it: **GNOME's idle timer suspends the machine** (`sleep-inactive-ac-type` and `sleep-inactive-battery-type` are `'suspend'`). This time it was the GDM greeter's `gsd-power`, at 12:49:22.

- Suspended 12:49:22, resumed 13:00:25 (what woke it isn't logged).
- On resume: **19 `Watchdog detected hard LOCKUP` reports** for CPUs 0, 4 and 5. Every backtrace has the CPU parked in `cpuidle_enter_s2idle`, so this looks like the hard-lockup detector misfiring across s2idle rather than a real hang. Then **31× `geni_i2c 884000.i2c: error turning SE resources:-13`** on the EC's I2C bus, plus `HS-PHY not in L2` on both USB controllers.
- **It came back.** Tasks restarted at 13:00:25, and the user logged in at 13:01:23. The machine was reset 3 minutes later by the deliberate `modprobe ipa` test, so nothing after that was checked (battery and USB-C over the EC bus, Wi-Fi, audio).
- Log: [logs/2026-10-10-s2idle-resume-lockup.log](logs/2026-10-10-s2idle-resume-lockup.log).

**Open:** decide whether auto-suspend stays on (`gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'`, and the same for GDM's own settings), or run a deliberate suspend test: `systemctl suspend`, then check `journalctl -k -b` and that the EC (battery, UCSI) still answers. `nmi_watchdog=0` would tell whether the lockup reports are only the detector.
