---
title: "Debian sid on a Samsung Galaxy Book Go, Written on the Galaxy Book Go"
published: false
description: "A step by step guide to Debian sid with kernel 7.2 and GNOME on the Snapdragon 7c Gen 2 Galaxy Book Go, a laptop with no upstream device tree. Firmware from the Windows driver store, a keyboard interrupt read out of Samsung's ACPI tables, and an article written, checked and built on the machine it describes."
tags: linux, debian, arm64, laptop
cover_image: https://raw.githubusercontent.com/xbill9/linux-arm-adventures/main/articles/galaxy-book-go-debian/cover.32c31be5.jpg
---

This article provides a step by step guide to running Debian sid on a Samsung Galaxy Book Go, the Snapdragon 7c Gen 2 Windows-on-ARM laptop. A small set of POSIX shell scripts and one device tree patch turn a community draft into a machine that runs a daily desktop.

https://github.com/xbill9/linux-arm-adventures

**Kernel 7.2.9, GNOME 50.5 on Wayland, GPU acceleration, video decode, Wi-Fi, Bluetooth, the keyboard, touchpad, power button, lid and suspend all work. Audio, battery reporting and brightness do not. This article was written, fact-checked and built on the laptop it describes.**

---

#### What Is the Problem?

The Galaxy Book Go has no upstream support. Mainline Linux has no device tree for it, and Debian's kernel ships only the Acer Aspire 1 tree for the same SoC (SC7180). The community device tree is a draft with Aspire 1 memory addresses and a keyboard interrupt its own comment calls wrong.

ACPI is no way out. A generic ACPI kernel reboots the machine as soon as the SMMU driver loads, and without the SMMU there is no USB and no keyboard. So the laptop boots with a device tree, and every missing node in that tree is a missing device.

Samsung publishes no driver pack for it either. The only copy of the signed firmware is the factory Windows install.

---

#### The Dog Food Test

A port that boots to a login screen proves the boot path. A port that the author uses to write about it proves the keyboard, the desktop, the network and the toolchain all at once, for hours.

This article was drafted in GNOME Terminal on the Galaxy Book Go, by a native arm64 Claude Code running in the local Wayland session, with the repository on the internal UFS disk. The capture below was taken from that session:

```
$ cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name
SAMSUNG ELECTRONICS CO., LTD.
Galaxy Book Go (Wi-Fi)

$ uname -r
7.2.9+deb14-arm64

$ loginctl show-session 2 -p Type -p Remote
Remote=no
Type=wayland

$ file -bL ~/.local/bin/claude | cut -d, -f1-2
ELF 64-bit LSB executable, ARM aarch64

$ systemctl is-system-running
running
```

The same capture also shows where the laptop strains. It has 3.4 GiB of usable memory, and 1.3 GiB was in swap while this was written, with a browser, GNOME and the assistant open together.

---

#### At This Point You Should Have…

- A Galaxy Book Go (NP340XLA or NP345XLA), Secure Boot off.
- A Debian 13 installer stick for the Book Go that carries the community device tree, `sc7180-samsung-galaxy-book-go.dtb`.
- A USB-C hub with a USB keyboard and a USB Ethernet adapter. USB boot is unreliable straight into the port and reliable through a hub.
- The Windows `DriverStore\FileRepository` from a Book Go, copied off before Windows was wiped.
- A second machine with SSH access, for the rescue path.

---

#### Step 1 — Put the Device Tree in the Boot Menu

The installer writes a stock GRUB menu. It has no `devicetree` line and no `clk_ignore_unused pd_ignore_unused`, so the installed kernel boots through ACPI and the machine resets. The installed system had never booted: its journal was empty.

The fix is a GRUB generator, `scripts/09_galaxy-book-go`, installed as `/etc/grub.d/09_galaxy-book-go` so it runs before `10_linux`. Per kernel it writes three entries, each with the device tree and the clock options:

| Entry id | What it is for |
| :--- | :--- |
| `gbgo-<kver>` | normal boot |
| `gbgo-safe-<kver>` | no GPU or DSP drivers, known-good initramfs, verbose |
| `gbgo-debug-<kver>` | `ignore_loglevel` |

`GRUB_DEFAULT` names an entry id, never a position, and the menu waits 10 seconds. Every risky change after this is tried once with `grub-reboot <id>`, so a hang falls back to the default on the next power cycle.

The first boot from the internal disk reached `running` and the GDM login.

---

#### Step 2 — Make GNOME See the Keyboard

The text console took key presses, and GNOME took none. The internal keyboard (`hid-over-i2c 0CF2:9028`) reports a stray `ABS` axis, so udev tags it `ID_INPUT_TABLET_PAD`, and libinput hands it to GNOME as a tablet pad.

A udev rule clears the tags:

```
ACTION!="remove", SUBSYSTEM=="input", ATTRS{name}=="hid-over-i2c 0CF2:9028 Keyboard", ENV{ID_INPUT_TABLET}="", ENV{ID_INPUT_TABLET_PAD}="", ENV{ID_INPUT_KEYBOARD}="1", ENV{ID_INPUT_KEY}="1"
```

It must match the `input0` node as well as `event0`. libinput reads the parent's tags too, so a rule on `event*` alone leaves the device classified as a tablet pad. With both, `libinput list-devices` reports `Capabilities: keyboard pointer`.

---

#### 🔎 Tip: Do Not Restart GDM With Someone Logged In

A running GNOME keeps the old device classification until it restarts. Restarting `gdm3` closes every open session. Log out instead.

---

#### Step 3 — Take the Firmware From Windows

The device tree asks for four Samsung-signed files under `qcom/sc7180/samsung/galaxy-book-go/`, and Wi-Fi needs a fifth. All five are in the Windows driver store. Where several driver versions sat side by side, the newest was taken:

| File | Runs | Version |
| :--- | :--- | :--- |
| `qcdxkmsuc7180.mbn` | GPU zap shader | 27.20.0910 |
| `qcmpss7180_nm.mbn` | modem DSP, which hosts Wi-Fi | 1.0.0800.8 |
| `wlanmdsp.mbn` | Wi-Fi firmware, served to the modem | 1.0.0970 |
| `qcvss7180.mbn` | video decode and encode | 27.20.0910 |
| `qcadsp7180.mbn` | audio DSP | 1.0.0750.3, held back |

A bad firmware file can reset a Qualcomm SoC on every boot. So nothing went into `/usr/lib/firmware` before it had run once:

1. Stage the files in `/root/gbgo-fw-staging/`.
2. Point `/sys/module/firmware_class/parameters/path` at the staging directory. That lasts for the running boot only.
3. Start each remote processor by hand and read the log.
4. For the GPU, which retries only at boot, use a one-time GRUB entry with `firmware_class.path` on the kernel command line.
5. Install with `gbgo-firmware install`, which also has `promote` and `rollback`.

The modem came up and `ath10k_snoc` reported `WLAN.HL.3.2.2.c10-00767`. Venus bound its decoder and encoder. The GPU came up as `FD618` and gnome-shell left software rendering.

The audio DSP failed safely: `segment outside memory range`, `Boot failed: -22`. Samsung's image loads at `0x90b00000`, and the draft tree reserves the Aspire 1's region at `0x8e400000`. It stays out of `/usr/lib/firmware` until the tree is fixed.

---

#### Step 4 — Win the Wi-Fi Boot Race

On some boots Wi-Fi took about 60 seconds, and on others 17. The modem asks `tqftpserv` for `wlanmdsp.mbn` a few milliseconds after the service starts. If it asks first, the WLAN start stalls, and the modem's watchdog crashes it after 40 seconds (`DOG detects stalled initialization`). The kernel restarts it, and the second try works.

`gbgo-wifi-kick` runs after `rmtfs` and `tqftpserv`. If no Wi-Fi interface exists 10 seconds later, it stops and starts the modem's remote processor:

```
for r in /sys/class/remoteproc/remoteproc*; do
  [ "$(cat "$r/name")" = "$NAME" ] && R=$r
done
[ "$(cat "$R/state")" = running ] && echo stop > "$R/state"
sleep 2
echo start > "$R/state"
```

It checks for any interface under `/sys/class/ieee80211/phy*/device/net/`, never for a name. Under sid the interface is `wld0`. The restart was tested by hand. The service has not yet had to fire during a real boot.

---

#### Step 5 — Give Bluetooth an Address

The WCN3991 loads `qca/crbtfw32.tlv` from `firmware-atheros` and stays unconfigured, because nothing supplies a public address. `gbgo-bt-addr` sets a stable, locally administered one derived from `/etc/machine-id`, before `bluetooth.service` starts.

`btmgmt` from bluez 5.82 waits forever when its standard input is `/dev/null`, which is what systemd gives a service. Over SSH the same command returns at once. The script feeds it an empty pipe:

```
bm() { echo | timeout 3 btmgmt -i hci0 "$@" 2>&1; }
```

```
$ bluetoothctl show | head -1
Controller 02:33:FD:7E:34:33 (public)
```

---

#### Step 6 — Read the Keyboard Interrupt From Samsung's ACPI Tables

The keyboard worked, at a price. The draft tree wires its interrupt to TLMM GPIO 48, level-low, and GPIO 48 sits low permanently. The interrupt never clears, so the driver polls the keyboard about 1100 times a second:

```
i2c_hid_of 6-0005: i2c_hid_get_input: incomplete report (11/65535)
```

That was 785,000 log lines in 14 minutes and about 7 % of a CPU. Watching all 73 free input GPIOs while typing showed nothing.

Samsung's ACPI tables describe the board for the Windows drivers. Linux boots with a device tree here, so `/sys/firmware/acpi/tables` is empty and `/dev/mem` refuses the page. The UEFI shell can read it. A one-time GRUB entry chainloads Debian's `shellaa64.efi`, and a `startup.nsh` at the root of the ESP dumps the EFI-reserved block holding the tables and resets:

```
dmem 0xFFF22000 0xDC000 > mem.txt
```

`acpi-from-dmem.py` rebuilds the bytes and follows RSDP → XSDT → DSDT. The keyboard device, `ECKB`, declares:

```
GpioInt(Level, ActiveLow, PullUp) pin 0x140
```

On Qualcomm's ACPI, a pin of `0x40·k` above the 120 real pins means direct-connect interrupt number *k*. `0x140` is interrupt 5, which is PDC pin 67, which is **TLMM GPIO 104**. The mapping checks out against three known pins: the SD card detect, the touchpad and the lid.

`gbgo-dtb-patch` builds the tree from the draft with three changed keyboard lines: interrupt `0x30` → `0x68`, pin `gpio48` → `gpio104`, `bias-disable` → `bias-pull-up`. After the change:

```
$ grep hid-over-i2c /proc/interrupts
 147:        799          0          0          0          0          0          0          0  msmgpio   104 Level     hid-over-i2c
 148:       4645          0          0          0          0          0          0          0  msmgpio    31 Level     hid-over-i2c

$ journalctl -k -b | grep -c "incomplete report"
0
```

The 799 interrupts on GPIO 104 are every key pressed since this boot, including the request that started this article.

---

#### 🔎 Tip: Rehearse Firmware Scripts in QEMU

The shell dump was run first in `qemu-system-aarch64 -M virt` with AAVMF, the laptop's own shim, GRUB and UEFI shell, and twelve extra FAT disks. That rehearsal showed three things before any reboot of the laptop:

- The shell runs `startup.nsh` only from the root of a filesystem.
- With many FAT partitions, the ESP sits past `fs9`, so the script searches by a marker file.
- Debian's UEFI shell has no `acpiview`. `dmem` with `>` redirection works.

---

#### Step 7 — Add the Power Button and the Lid

The same patch script adds two more devices to the tree:

- **Power button.** The draft disables `pon@800`, so `pm8941-pwrkey` never binds. Enabling it gives `KEY_POWER` and GNOME's power-off dialog.
- **Lid.** The draft has no node. ACPI `LID0` returns the raw level of GPIO 93, `1` for open, so a `gpio-keys` node reports `SW_LID` on TLMM 93, active low.

Suspend is `s2idle` only. One cycle from the login screen resumed in 0.6 s, woken by Shift on the built-in keyboard, with Wi-Fi, Bluetooth and Ethernet back. Wake by lid is still missing, so closing the lid locks the screen.

The PMIC clock was tested and left off. It reads 1970-01-03, because Samsung keeps the offset elsewhere, and it set the system clock to 1970 at boot. systemd-timesyncd and NTP keep the time instead.

---

#### Step 8 — Upgrade to sid Without Touching the Boot

A Lenovo Yoga C630 running the same plan lost its boot when sid's GRUB 2.14 blacked out every kernel. The Book Go upgrade was built around that:

| Risk | Protection |
| :--- | :--- |
| sid replaces GRUB 2.12 and shim | `apt-mark hold` on all six `grub*` and four `shim*` packages |
| sid's `initramfs-tools` drops `qcom/` firmware | an initramfs hook adds the GPU firmware and zap shader |
| a new kernel becomes the default | the old kernel is held and stays default until a one-time boot passes |
| a rebuilt initramfs breaks boot | SAFE entries boot copies saved in `/boot/gbgo-known-good/` with `SHA256SUMS` |
| everything breaks | an `rsync` of `/` and the ESP on another machine, checked by hash |

`gbgo-boot-verify` runs before every reboot. It checks the holds, hashes all nine ESP files against the backup, runs `grub-script-check`, confirms the default entry carries the tree and the options, reads the tree, initramfs and `grub.cfg` off the raw disk, and lists the storage, keyboard and display modules and the GPU firmware inside every initramfs.

The upgrade set up 1712 packages with no dpkg errors. GRUB stayed at 2.12:

```
$ dpkg-query -W grub-efi-arm64-bin
grub-efi-arm64-bin	2.12-9+deb13u2
```

Kernel 7.2.9 passed a one-time boot and became the default. On 7.2.9 the GPU loads after the root mount, so the zap shader failure seen on 6.12 is gone.

---

#### 🔎 Tip: Three Names That Change Under You

- **Disk.** The root partition was `sda3` at install and is `sdc3` today. Every boot entry uses `UUID=`.
- **Wi-Fi.** sid's systemd renames `wlan0` to `wld0` a few seconds into boot.
- **sudo path.** sid's `sudo` no longer includes `/usr/local/sbin`. Call the scripts by full path.

`apt autoremove` after the upgrade would also have removed the fallback kernel and `mesa-va-drivers`. Both are now marked manual.

---

#### What Works?

| Hardware | State |
| :--- | :--- |
| GPU | 🟢 Adreno 618, `FD618`, `simple_ondemand` |
| Video | 🟢 venus decoder and encoder |
| Wi-Fi | 🟢 5 GHz, 80 MHz, with Samsung's modem firmware |
| Bluetooth | 🟢 with `gbgo-bt-addr`. ⚠️ Pairing and audio untested |
| Keyboard, touchpad | 🟢 keyboard on GPIO 104, touchpad on GPIO 31 |
| Power button, lid | 🟢 lid locks the screen |
| Suspend | ⚠️ `s2idle`, one cycle tested, the lid does not wake it |
| USB-C | ⚠️ works if plugged at boot. No UCSI node |
| Audio | ❌ ADSP memory region wrong, no sound node |
| Battery | ❌ no `power_supply`, nothing in the tree |
| Brightness | ❌ no backlight device. PM6150L LPG3 is the likely PWM, untested |
| Camera | ❌ no camera in the tree |

---

#### Compare and Contrast

| | Yoga C630 | Galaxy Book Go |
| :--- | :--- | :--- |
| SoC | Snapdragon 850 (SDM850) | Snapdragon 7c Gen 2 (SC7180) |
| Device tree | 🥇 upstream, in Debian's kernel | 🥈 community draft, patched |
| Firmware source | Lenovo package mirrors | Windows driver store |
| Audio, battery | 🥇 work | ❌ missing |
| Blocking driver | `ipa` resets the SoC | none found |
| Boot loader | GRUB 2.12 held | GRUB 2.12 held |

---

#### So, Is It a Daily Driver?

For writing, terminals, a browser and SSH, yes. This article is the test: the keyboard, the Wayland desktop, Wi-Fi and the assistant ran together for the whole session without a fault.

Three gaps decide where it stops. With no battery reading, nothing warns before the laptop dies. With no brightness control, the screen stays at the firmware's level. With no audio, calls and video need a Bluetooth headset, which is untested. And 3.4 GiB of memory pushes a browser plus a desktop into swap.

---

#### Summary

The goal of this article was to run a current Debian with a full desktop on a laptop that has no upstream support, and then use it. The key to the solution was treating Samsung's Windows install as the reference: its driver store supplied the firmware, and its ACPI tables supplied the keyboard interrupt the community tree had guessed. The results were:

- 🟢 Debian sid, kernel 7.2.9 and GNOME Shell 50.5 on Wayland, with GPU acceleration, video, Wi-Fi, Bluetooth, keyboard, touchpad, power button and lid.
- 🟢 The keyboard interrupt flood is gone: 0 `incomplete report` lines per boot.
- 🟢 The sid upgrade left the boot path byte-identical, checked by script before each reboot.
- 🟢 This article was written, fact-checked and built on the machine.
- ❌ Audio, battery and brightness need device tree work that has not started.
- ⚠️ Suspend has one tested cycle, and the Wi-Fi restart service has not yet fired on a real boot.

Scope: one Galaxy Book Go (NP340XLA-KA3CA, Wi-Fi model, BIOS `P00AJW.036`), Debian sid as of 2026-10-11, Samsung firmware from the Windows driver store, brought up over two days, with the dog food session on 2026-10-12.

The strategy for bringing up Debian on the Galaxy Book Go was validated with an incremental step by step approach.

---

#### References

- Repository: https://github.com/xbill9/linux-arm-adventures
- Galaxy Book Go notes: [galaxy-book-go/](https://github.com/xbill9/linux-arm-adventures/tree/main/galaxy-book-go)
- Debian on the Yoga C630, the companion article: [c630-debian](https://github.com/xbill9/linux-arm-adventures/tree/main/articles/c630-debian)
- Bring-up history: [aarch64-laptops/debian-cdimage#21](https://github.com/aarch64-laptops/debian-cdimage/issues/21)
- Current community status: [velvet-os/imagebuilder#136](https://github.com/velvet-os/imagebuilder/issues/136)
- Draft device tree: [hexdump0815/linux-mainline-qcom-kernel](https://github.com/hexdump0815/linux-mainline-qcom-kernel/blob/main/readme.qc7)
