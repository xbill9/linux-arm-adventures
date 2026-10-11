# Galaxy Book Go: Debian 13 on the internal UFS

Status 2026-10-11 11:08: **boots from the internal disk to the GNOME login, internal keyboard works in GNOME.** Kernel `6.12.107+deb13-arm64` with the device tree from the installer stick. Windows is gone from this unit.

## The unit

| What | Value |
|---|---|
| Disk | UFS `KM5V8001DM-B622`, 119 GB, **4 KiB sectors** |
| `sda1` | 16M vfat `SYSTEM`, GPT type "Linux filesystem": Windows Boot Manager leftovers, FAT errors. Not an ESP, not used |
| `sda2` | 977M ESP, UUID `8558-31DB` |
| `sda3` | root ext4, UUID `4c31e6e7-e27c-4312-9f9a-5ad079867cbf` |
| `sda4` | swap |
| `sdb`–`sdf` | Qualcomm firmware LUNs (XBL, TZ, modemst, …). Don't touch |
| Installed | Debian 13.7 netinst, 2026-10-10 22:59 → 2026-10-11 00:23, GNOME task. Kernels 6.12.107 and 6.12.111. GRUB 2.12-9+deb13u2, shim 16.1 |
| EFI variables | not available from Linux (`efibootmgr`: not supported) |
| SSH | `ssh -o HostKeyAlias=gbgo -i ~/.ssh/google_compute_engine xbill@192.168.0.65`. The alias keeps its host key apart from the C630's, which used `.65` with the same USB Ethernet adapter |

## Why it didn't boot

The installer wrote a **stock GRUB menu: no `devicetree`, no `clk_ignore_unused pd_ignore_unused`.** Debian's kernel has no Galaxy Book Go DTB (only `sc7180-acer-aspire1.dtb`), so the kernel booted via ACPI, which resets this machine. The installed system had never booted (no journal at all). The installer stick boots because its menu loads `GBGO:/gbgo/sc7180-samsung-galaxy-book-go.dtb` (sha256 `67603128d1cc5952…`). The stick's `postinstall.sh`/`fix.sh`, which would have added the DTB to the installed system, were never run.

## The fix (2026-10-11 10:49)

[scripts/gbgo-fix-boot.sh](scripts/gbgo-fix-boot.sh), run as root in the rescue chroot with the stick's `GBGO` partition mounted:

- DTB → `/boot/dtb/sc7180-samsung-galaxy-book-go.dtb`.
- [scripts/09_galaxy-book-go](scripts/09_galaxy-book-go) → `/etc/grub.d/`: per kernel, newest first, three entries, all with the DTB and `clk_ignore_unused pd_ignore_unused`:

| Entry id | What |
|---|---|
| `gbgo-<kver>` | normal |
| `gbgo-safe-<kver>` | SAFE: `modprobe.blacklist=msm,qcom_q6v5_pas,qcom_q6v5_mss` (EFI framebuffer only, no DSPs), verbose |
| `gbgo-debug-<kver>` | `ignore_loglevel` |
| `gbgo-fwtest-<kver>` | only while `/usr/lib/firmware-gbgo-test` exists: `firmware_class.path` points there, for one-time firmware tests |

- `/etc/default/grub`: `GRUB_DEFAULT=gbgo-6.12.107+deb13-arm64`, `GRUB_TIMEOUT=10`, `GRUB_TIMEOUT_STYLE=menu`, no `quiet`, `GRUB_DISABLE_OS_PROBER=true`. The stock entries (no DTB) are still below ours; don't pick them.
- `EFI/BOOT/fbaa64.efi` moved aside, so the disk's `EFI/BOOT` holds exactly what the stick's does (shim + GRUB, byte-identical). Otherwise shim runs the fallback loader, which tries to write EFI boot variables.

Checked before the reboot: boot loader hashes equal the stick's; `grub-script-check`; the default id exists; the DTB hash; `grub.cfg` and the DTB visible with `debugfs` on the raw disk; UFS, I2C keyboard and PMIC drivers in both initramfs images; the rescue system (same kernel + DTB) drives the display with `msm` + `panel_edp` + `ti_sn65dsi86`, so `msm` is proven.

Result: the first boot from the internal disk reached `systemctl is-system-running` = `running` and the GDM login.

**Not yet tested:** kernel 6.12.111 (its entries exist, the default is pinned to .107), and the SAFE entries.

Backups: `/root/gbgo-backup-20261011-104919/` on the laptop, and [backups/2026-10-11-before-dtb-fix/](backups/2026-10-11-before-dtb-fix/README.md).

## Keyboard misidentified as a tablet pad (fixed 11:07)

The internal keyboard (`hid-over-i2c 0CF2:9028 Keyboard`, `event0`) also reports a stray `ABS` axis, so udev's `input_id` tags it `ID_INPUT_TABLET=1` and `ID_INPUT_TABLET_PAD=1`. libinput then reports `Capabilities: tablet-pad`, and GNOME (Wayland) gets no key presses from it. The text console was unaffected.

Fix: [system/61-gbgo-keyboard.rules](system/61-gbgo-keyboard.rules) → `/etc/udev/rules.d/`. It clears both tablet tags and sets the keyboard tags. **It must match the `input0` node as well as `event0`**: the first version matched only `event*`, udev showed `event0` clean, and libinput still said `tablet-pad`, because it also reads the parent's tags. With both: `libinput list-devices` → `Capabilities: keyboard pointer`, and the keyboard types at the GDM login.

A running GNOME keeps the old classification until it restarts (log out, or restart `gdm3` **only when nobody is logged in**: a restart on 11:07 closed a session that had just been opened).

Still seen in the kernel log: `i2c_hid_of 6-0005: i2c_hid_get_input: incomplete report (11/33026)`, a burst at ~47 s after boot. The research notes ([README.md](README.md)) report this flood returning after idle and costing CPU.

## Since then

- 11:46: normal entries get `loglevel=3` (`GRUB_CMDLINE_LINUX_DEFAULT`). The keyboard's `incomplete report` errors were flooding the console; `quiet` alone (loglevel 4) still shows errors. SAFE and debug entries stay verbose.
- 11:50: Samsung firmware: Wi-Fi, GPU, venus. See [FIRMWARE.md](FIRMWARE.md).

## Suspend (tested 13:03)

`s2idle` only. One cycle, from the GDM login screen, with `pm_debug_messages` on: `systemctl suspend` at 13:03:06, **woken by Shift on the built-in keyboard** after ~10 s (`PM: Triggering wakeup from IRQ 136` = `msmgpio 104`, the keyboard IRQ fixed above), devices resumed in 0.6 s. Wi-Fi reconnected, Bluetooth up, Ethernet stayed up.

Resume warnings: `i2c_hid_of 6-0005: failed to change power setting` (keyboard; it had just delivered the wake key, typing after resume not yet re-checked) and `usb 1-1.2.5 … usb_dev_resume … -5` (the hub's VIA Billboard device `2109:8888`, no driver; it re-enumerates, harmless).

Wake sources: keyboard (tested), touchpad and power key (marked, untested). **The lid is not a wake source yet** (no `wakeup-source` on `switch-lid`; GPIO 93 is PDC-capable, PDC pin 49), so lid close still only locks. Not measurable: battery drain while suspended (no battery driver).

## Power button and lid (fixed 13:01); RTC left off

Both came from the DTB, built by [scripts/gbgo-dtb-patch](scripts/gbgo-dtb-patch) together with the keyboard fix (`8012d6d42635b0e3…`, verified on the raw disk):

- **Power button:** the draft DTB disables `pon@800` (`qcom,pm8998-pon`), so `pm8941-pwrkey` never bound. Enabled; `resin` (volume-down) stays off. Test: one press gave `KEY_POWER` 1 then 0, and GNOME's power-off dialog. **That dialog powers off by itself after 60 s unless you press Cancel** (it did, at 12:59).
- **Lid:** no node at all. ACPI `LID0._LID` returns the raw level of GPIO 93 (`1` = open), so a new `gpio-keys` node: `SW_LID` on `tlmm 93`, `GPIO_ACTIVE_LOW`. Test: lid open reads open; close → `SW_LID 1`, open → `SW_LID 0`.
- **Suspend is untested**, so for now ([system/logind/gbgo-no-suspend.conf](system/logind/gbgo-no-suspend.conf) → `/etc/systemd/logind.conf.d/`) closing the lid **locks** the screen, and ([system/gschema/90-gbgo-power-button.gschema.override](system/gschema/90-gbgo-power-button.gschema.override) → `/usr/share/glib-2.0/schemas/`, then `glib-compile-schemas`) the power button shows the **power-off dialog**. Both defaults would suspend.
- **RTC: tested and left disabled.** With `rtc@6000` enabled (`rtc-pm8xxx`), the PMIC counter reads **1970-01-03** (Samsung's firmware keeps its offset elsewhere; it showed the date as Oct 9 while it was Oct 11), and `CONFIG_RTC_HCTOSYS` set the system clock to 1970 at boot until NTP. With `CONFIG_RTC_SYSTOHC` it would also have written NTP time into the counter ~11 min after sync, changing what the firmware shows; the driver was unbound before that happened, so the counter was never written. Without an RTC, systemd-timesyncd restores the last saved time at boot and NTP corrects it. Writing the counter (`hwclock --systohc`) would fix boots but make the firmware show ~2083; not done.

Verified on a normal boot (13:01): `pm8941_pwrkey` and `gpio-keys` present, no `/sys/class/rtc`, 0 keyboard flood lines, Wi-Fi, Bluetooth, GPU `FD618`, `running`.

## Keyboard IRQ flood (fixed 12:47)

The draft DTB gives the keyboard `interrupts-extended = <&tlmm 48 IRQ_TYPE_LEVEL_LOW>`, with the comment "this one is wrong, the proper one has not been found yet". GPIO 48 sits low permanently, so the level interrupt never clears: `i2c_hid_of 6-0005: i2c_hid_get_input: incomplete report (11/65535)` (or `11/33026`) about **1100 times a second**, 785,000 lines in 14 minutes, ~7 % CPU. Keys only worked because of that constant polling.

What didn't find it: GPIO 48 stays low with the driver unbound and after reading the device; GPIO 32 (amcduffee's DTS) is the touchpad power enable; edge-watching all 73 free input GPIOs while typing showed nothing (73 and 109 toggle ~20 Hz on their own).

What did: Samsung's ACPI tables ([ACPI.md](ACPI.md)). `ECKB` uses `GpioInt(Level, ActiveLow, PullUp)` on virtual pin `0x140` = direct-connect interrupt #5 = PDC 67 = **TLMM 104**. GPIO 104 was left as an **output, low** by the boot firmware (no Linux driver claimed it). As an input with pull-up it idles high, and a HID `RESET` to the keyboard pulls it low: the spec's reset interrupt.

Fix: [scripts/gbgo-dtb-patch](scripts/gbgo-dtb-patch) (`/usr/local/sbin/`) builds the DTB from the stick's draft with exactly three changed lines: the keyboard IRQ `0x30` → `0x68`, and its pin config `gpio48` → `gpio104`, `bias-disable` → `bias-pull-up`. Tested with a one-time `gbgo-dtbtest-<kver>` entry (the generator lists it while `<dtb>.test` exists): **0 flood lines**, IRQ 104 at 1 after boot and 13 after a few key presses, keys seen by `evtest`. Then installed as `/boot/dtb/sc7180-samsung-galaxy-book-go.dtb` (`08381461ecc64922…`, verified on the raw disk); the stick's original is `….dtb.orig` (`67603128d1cc5952…`).

Reinstalling from the stick (`gbgo-fix-boot.sh`) copies the stick's original DTB, so run `gbgo-dtb-patch /boot/dtb/sc7180-samsung-galaxy-book-go.dtb.orig /boot/dtb/sc7180-samsung-galaxy-book-go.dtb` afterwards.

`loglevel=3` (11:46) is no longer needed for the flood; left in place.

## Bluetooth (fixed 12:03)

The WCN3991 loads its firmware from `firmware-atheros` (`qca/crbtfw32.tlv`, `crnv32u.bin`, `QCA setup on UART is completed`) and then stays **unconfigured**: `hciconfig` shows `DOWN RAW` with a junk address (`00:00:00:00:5A:AD` or `39:98:00:00:5A:AD`), `btmgmt config` shows `missing options: public-address`, and BlueZ lists no adapter. Nothing supplies a public address (none in the DT). Same situation as the C630.

Fix: [scripts/gbgo-bt-addr](scripts/gbgo-bt-addr) (`/usr/local/sbin/`) + [system/gbgo-bt-addr.service](system/gbgo-bt-addr.service) (`Before=bluetooth.service`). It sets a stable, locally administered address from `/etc/machine-id` (this unit: `02:33:FD:7E:34:33`), only while `public-address` is missing, retrying for up to 30 s.

**Trap: `btmgmt` (bluez 5.82, trixie) hangs forever when stdin is `/dev/null`**, which is what systemd gives a service. Over SSH (stdin a pipe) the same call answers at once, so the script worked by hand and failed at every boot (`try 1: config:` empty, each call hitting its timeout). `echo | timeout 3 btmgmt …` fixes it. The C630's `c630-bt-addr` calls `btmgmt` without this and works there (sid's bluez); not checked why.

Verified across a reboot: address set at 10.3 s on the first try, `hci0` `UP RUNNING`, `bluetoothctl show` → `Powered: yes`; a 12 s scan (before the reboot) saw 6 devices. **Not yet tested:** pairing and audio to a headset.

## Recovery

| Problem | Do |
|---|---|
| Default entry hangs or goes black | Hold power 10 s, power on; at the GRUB menu (10 s) pick `… SAFE` or `… verbose debug` |
| No GRUB menu | Stick on the hub, F10 → stick → **Galaxy Book Go: Rescue mode (with DTB)** → `sda3` → Execute a shell → `mkdir /run/sshd; /usr/sbin/sshd`. Host keys, the SSH key and `/etc/sudoers.d/90-xbill` are already in place |
| Undo the boot fix | From `/root/gbgo-backup-20261011-104919/`: restore `grub` → `/etc/default/grub`, remove `/etc/grub.d/09_galaxy-book-go`, move `fbaa64.efi.from-EFI-BOOT` back to `/boot/efi/EFI/BOOT/fbaa64.efi`, `update-grub` |
| Undo all DTB fixes (keyboard, power button, lid) | `cp /boot/dtb/sc7180-samsung-galaxy-book-go.dtb.orig /boot/dtb/sc7180-samsung-galaxy-book-go.dtb` |
| Undo Bluetooth address | `systemctl disable gbgo-bt-addr` |
| Undo the keyboard rule | `rm /etc/udev/rules.d/61-gbgo-keyboard.rules`, reboot |

The rescue chroot has no `/dev/pts`, so `su` and root logins over SSH can't work from it; that is why `90-xbill` (passwordless sudo) exists.

## Next

- Audit 2026-10-11: [AUDIT-2026-10-11.md](AUDIT-2026-10-11.md) (missing firmware, Wi-Fi/BT packages, no battery/backlight/audio in the DT, keyboard IRQ flood).

- Hold `grub*` and `shim*` (`apt-mark hold`) as on the C630, so an upgrade can't swap the boot loader. Not done yet.
- Test 6.12.111 once with `grub-reboot gbgo-6.12.111+deb13-arm64`, then decide the default.
- Change root's password (it was typed into a chat transcript).
- Touchpad, Wi-Fi (needs Windows firmware; this unit's Windows is gone), Bluetooth address, audio, brightness: see the table in [README.md](README.md).
