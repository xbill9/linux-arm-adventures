# Samsung Galaxy Book Go

Snapdragon 7c Gen 2 (**SC7180**, the same SoC as the Acer Aspire 1 and the trogdor Chromebooks; it is *not* SC7280). Models NP340XLA / NP345XLA. Status: **broken and offline** (as of 2026-10-10). Its keyboard misbehaves **under Windows too**.

## Start here: keyboard broken in Windows too

The keyboard is not USB. It is an I2C HID device behind the embedded controller (`ECKB` in the ACPI DSDT, touchpad `ECTC`). If it misbehaves in Windows as well as Linux, rule out the hardware and firmware before blaming Linux:

1. **Test in firmware.** Press F2 at power-on for BIOS setup and F10 for the boot selector (both often take several tries). Arrow keys and Enter go through the same keyboard.
   - If it also fails there, the cause is hardware: the keyboard ribbon cable, the keyboard itself (liquid?), or the EC. No OS fix will help.
   - If it works there but fails in Windows, the cause is Windows (driver or update).
2. **Windows side:** install everything under Windows Update → Advanced options → Optional updates, since the Samsung keyboard and touchpad drivers ship there. In Device Manager, check the I2C HID devices for Code 10. If one shows it, disable it, re-enable it, and untick "allow the computer to turn off this device".
3. **BIOS / EC firmware:** update through Samsung Update from Windows. edrex (aarch64-laptops#21, 2024) installed Samsung's firmware updates this way before trying Linux.
4. **Workaround meanwhile:** a USB keyboard works in firmware, GRUB, Windows and (via a hub) Linux.

## Windows reinstall: no input in setup

A stock Windows ARM64 installer gets **no input at all** on this machine: the internal keyboard, touchpad, a USB keyboard and a USB-C hub all stay dead. WinPE has no driver for the Qualcomm USB host controller or for the EC's I2C keyboard. The keyboard working in the BIOS while dying in setup is the signature of this. It does *not* point to failed hardware.

- Samsung publishes **no driver pack** for the Book Go: its driver-pack page covers Book3/4/5 only, and users report the drivers are not in Samsung Update either. The drivers exist only in the factory install and its recovery partition.
- Injecting drivers into `install.wim`/`boot.wim` with NTLite **still gave no input** for one user (administrator.de, NP345XLA, 2025).
- `bork.md` (pasted from another AI chat) does not hold up:
  - Option 2 needs a keyboard to use the WinRE command prompt.
  - `dism /image:X:\` targets WinPE's own RAM disk and does not load drivers into the running session (`drvload` does that).
  - Neither the "Reddit recovery image" nor the "Internet Archive driver pack" could be found or verified.

Order of attack:
1. **If the factory install or recovery partition is still on the UFS:** reach the internal WinRE (F10 → Windows Boot Manager, or three interrupted boots). It is built from the factory image, so it should have the input drivers. Then use Reset this PC → Remove everything, which is a local reinstall from the recovery image.
2. **If it has been wiped or is unusable:** harvest the drivers with Linux.
   - Boot a velvet-os stick through a USB-C hub; a USB keyboard works there.
   - Mount the Windows partition **read-only** and copy `Windows/System32/DriverStore/FileRepository` plus the recovery partition to another stick.
   - On another PC, put the drivers in `$WinPEDriver$\` at the installer's root (setup loads them automatically) and/or `dism /add-driver` them into `boot.wim` index 2 and `install.wim`.
   - Add an `autounattend.xml` so setup needs no input at all.
3. Third-party "pre-injected" ISOs only as a last resort, from a source whose hashes you can check.

**Current attempt (2026-10-10, untested):** a stock Win11 ARM64 stick whose Setup `drvload`s the harvested drivers, now including the USB stack. See [`win11-stick/`](win11-stick/README.md).

## Linux state of the art

**No upstream support.** There is no Galaxy Book Go DTS in mainline. Everything below comes from community work by hexdump0815, amcduffee, Vogtinator and others. hexdump0815, 2026-09-25: "the galaxy book go never reached a properly supported state … currently nobody is really working actively on bringing support for this system forward."

- **Images:** velvet-os imagebuilder `snapdragon_7c_woa` (Debian; a DTB menu covers the Book Go and the Aspire 1). hexdump0815 advises **not the latest image** (it "had various problems on the galaxy book go"), but a slightly older one, e.g. `251220-01` or `240107-01`.
- **Kernel:** linux-stable plus TravMurav's aspire1 changes, plus `sc7180-samsung-galaxy-book-go.draft` (887 lines, full of TODOs, with Aspire 1 reserved-memory addresses assumed).
- **ACPI boot is a dead end:** generic ACPI kernels reboot as soon as the SMMU driver loads, and without the SMMU there is no USB/keyboard (aarch64-laptops#21). Use DT boot.
- **Boot runs at EL1**, so there is no KVM (as on the X13s). slbounce is the research workaround.

| Device | State | Notes |
|---|---|---|
| Display | works; backlight PWM is PM6150L **LPG4** (`pwm-backlight` in the default DTB, slider effect by eye not yet confirmed); display bridge IRQ removed | See DEBIAN.md "Brightness", "Display bridge IRQ" |
| Keyboard | **flaky** | `geni_i2c … Bus arbitration lost, clock line undriveable` plus `i2c_hid_of` log spam, which **costs CPU** and returns after 10–15 min idle. Pressing Esc early in boot stops it. The GPIO interrupt is guessed (TLMM 32→38; "about half [of candidates] work"). **Phantom keypresses** on 20251220-01 |
| Keyboard in X11 (trixie) | needs workaround | It is detected as a mouse. Install `xserver-xorg-input-evdev` and add `/etc/X11/xorg.conf.d/52-keyboard.conf` with `MatchIsKeyboard "on"`, `MatchDevicePath "/dev/input/event*"`, `Driver "evdev"` (included in images since 251028) |
| Keyboard in Wayland | broken | libinput sees event0 as `tablet_pad`. Workaround: weston x11 backend |
| Touchpad | not working | |
| USB-A | works | |
| USB-C | works only if connected **at boot**, alongside USB-A | |
| Wi-Fi | works with Windows firmware (+ pd-mapper) | |
| Bluetooth | works with a MAC workaround | systemd oneshot `Before=bluetooth.service` running `echo \| btmgmt -i hci0 public-addr <real MAC from Windows ipconfig /all>` |
| Battery | SBS gauge at `0x0b` on `i2c@890000` (`sbs-battery`, in the default DTB); **charges** with `gbgo-charge.service` relaying the gauge's requests to the BQ25710 charger at `0x09` | See DEBIAN.md "Battery", "Charging" |
| Camera | Chicony 720p UVC on internal hub port 4, powered by TLMM 13 (gpio-hog in the default DTB) | See DEBIAN.md "Camera" |
| Audio | **speakers work** (audio DTB is the default; 16-bit stereo on tertiary MI2S); headphones and mic untested | See DEBIAN.md "Audio" |
| Video decode | Venus (H.264, VP8, VP9, HEVC, MPEG-2) works in mpv/ffmpeg via V4L2; **browsers decode in software** (no VA-API driver) | See DEBIAN.md "Video decode" |
| UFS | works | keep Windows on it (firmware source); run Linux from USB/SD |

### Booting it reliably

- Secure Boot must be off.
- USB boot is **very picky**: a SanDisk Ultra stick was seen about 1 time in 10, while a USB-C→USB-A **hub makes it 100%**. Fixing the backup GPT after `dd` (open the disk in `fdisk` and write without changes) also helps on some BIOS versions.
- Firmware sometimes adds broken `Boot00xx` variables for a stick and then ignores it (seen on the Aspire 1). Delete them from the EFI shell.
- Reliable dual-boot options:
  - Vogtinator: GRUB on the internal ESP with menu entries for Windows and USB.
  - NeonMan: EFI shell as the first boot option, with a `startup.nsh` that runs `my-startup.nsh` from any USB FAT partition, or else exits to the Windows loader.
- rEFInd fails to start on this machine.
- The firmware does not see the SD card, so `/boot` must be on USB; the rootfs can be on SD. USB rootfs showed fs corruption on 230305 (blamed on pd-mapper).
- Before experimenting, create a Windows recovery drive. No other recovery media exists for this machine.

## To find out about this unit

- Keyboard: does it work in BIOS setup / the F10 menu? (This decides hardware vs software.)
- What's installed now: Windows only, or a velvet-os image (which date), and on which disk?
- What "offline" means: no boot at all, no network, or no keyboard to log in?
- Whether a Windows recovery drive exists.

## Sources

- [aarch64-laptops/debian-cdimage#21](https://github.com/aarch64-laptops/debian-cdimage/issues/21): bring-up history, SMMU/ACPI, keyboard I2C, boot reliability
- [velvet-os/imagebuilder#136](https://github.com/velvet-os/imagebuilder/issues/136): current status thread (keyboard workarounds, BT, brightness, startup.nsh)
- [velvet-os imagebuilder snapdragon_7c_woa](https://github.com/velvet-os/imagebuilder/tree/main/systems/snapdragon_7c_woa): images, boot notes, required Windows firmware (`doc/required-firmware.md`)
- [hexdump0815 kernel readme.qc7 + draft DTS](https://github.com/hexdump0815/linux-mainline-qcom-kernel/blob/main/readme.qc7)
- [amcduffee/linux galaxy-book-go branch](https://github.com/amcduffee/linux/tree/galaxy-book-go) (2022, keyboard + USB-A in DTS)
- [TravMurav/linux aspire1](https://github.com/TravMurav/linux/tree/aspire1), [slbounce](https://github.com/TravMurav/slbounce)
- IRC #aarch64-laptops on OFTC; Book Go bring-up from [2022-10-18](https://oftc.irclog.whitequark.org/aarch64-laptops/2022-10-18#31531576)
- [Armbian forum thread](https://forum.armbian.com/topic/24464-samsung-go-book)
