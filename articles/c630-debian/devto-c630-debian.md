---
title: "Debian sid on a Lenovo Yoga C630: Held GRUB, One-Time Boots and the IPA Reset"
published: false
description: "A step by step guide to running Debian sid with kernel 7.2 and GNOME on the Snapdragon 850 Yoga C630: which boot loader the firmware runs, why GRUB 2.14 blacks out every kernel, a generated boot menu with one-time test boots, the Lenovo firmware, and the one driver that resets the SoC."
tags: linux, debian, arm64, laptop
cover_image: https://raw.githubusercontent.com/xbill9/linux-arm-adventures/main/articles/c630-debian/cover.f29f1bde.jpg
---

This article provides a step by step guide to running Debian sid on a Lenovo Yoga C630, the Snapdragon 850 Windows-on-ARM laptop from 2018. A small set of POSIX shell scripts is built to keep the boot recoverable while the kernel, firmware and desktop change underneath it.

https://github.com/xbill9/linux-arm-adventures

**Kernel 7.2.9, GNOME on Wayland, GPU acceleration, audio, Wi-Fi, Bluetooth, video decode, battery and both USB-C ports all work. LTE data is the one thing blocked, because loading the modem's IPA driver resets the whole SoC.**

---

#### What Is the Problem?

The C630 boots Linux through a firmware built for Windows. It hands the kernel ACPI tables that Linux cannot use, it cannot store EFI variables, and its real-time clock is never set. Each of these breaks a different step of a normal Debian install.

The kernel side is in good shape. Debian's 7.2 kernel ships the C630 device tree, the embedded controller driver (`lenovo_yoga_c630`) and the USB-C driver (`ucsi_yoga_c630`). The hard parts are the boot loader, the proprietary firmware and one driver.

---

#### At This Point You Should Have…

- A Lenovo Yoga C630 (model 81JL) with Debian installed from a C630 installer stick that carries a shim, GRUB 2.12 and the device tree.
- A second machine on the same network, with an SSH key already installed on the C630.
- A USB Ethernet adapter. Wi-Fi needs firmware that Debian does not ship.

---

#### Step 1 — Find the Boot Loader the Firmware Runs

This laptop has two EFI system partitions on its UFS disk:

| Partition | Size | Holds | Booted by the firmware |
| :--- | :--- | :--- | :--- |
| 1 (`E725-516C`) | 16M | GRUB named `EFI/Microsoft/Boot/bootmgfw.efi` | ❌ no |
| 2 (`3BA7-7161`) | 977M | `/boot/efi`, shim at `EFI/BOOT/BOOTAA64.EFI` | 🟢 yes |

The firmware has no NVRAM boot entries and `efibootmgr` reports `EFI variables are not supported`. It boots only the removable path, `EFI/BOOT/BOOTAA64.EFI`, on partition 2.

The way to know which loader runs is to make every loader say its own name. Each `grub.cfg` stub sets a variable before handing over to the shared menu:

```
search.fs_uuid a81deabf-0654-4f68-b795-284305d26f13 root
set prefix=($root)'/boot/grub'
set c630_from="sda2 EFI/debian"
export c630_from
configfile $prefix/c630.cfg
```

Every menu entry title starts with `[via $c630_from]`. The menu on screen read `[via sda2 EFI/debian]`, which settles it.

---

#### 🔎 Tip: The Installer Stick Has the Same Trap

From the stick, the firmware boots the ISO's internal `efi.img`. Editing the stick's partition 2 changes nothing on the next boot.

---

#### Step 2 — Hold GRUB 2.12

A trixie to sid upgrade installed GRUB 2.14 and a new shim. After it, every kernel went black the instant GRUB handed over, including a 6.12 kernel, with no output even with `ignore_loglevel earlycon=efifb`.

GRUB is the cause, and the evidence is that nothing else changed:

- `vmlinuz-6.12.107` on disk is byte-identical to the stick's kernel, which boots.
- The device tree is byte-identical to the stick's.
- The 6.12.107 initramfs was built the day before the upgrade and was untouched.

The same three files fail under GRUB 2.14 and boot under GRUB 2.12. Why 2.14 fails on this firmware is not known. Its newer Linux EFI handoff is a suspect, not investigated.

The fix is to copy the stick's shim and GRUB 2.12 back onto `/boot/efi` (`scripts/apply.sh`) and hold every package that could replace them:

```
$ apt-mark showhold
grub-common
grub-efi-arm64
grub-efi-arm64-bin
grub-efi-arm64-signed
grub-efi-arm64-unsigned
grub2-common
shim-helpers-arm64-signed
shim-signed
shim-signed-common
shim-unsigned
```

The held packages are at 2.14-4. They stay installed, and the hold stops them reinstalling themselves over the 2.12 binary on the ESP.

---

#### Step 3 — Generate a Boot Menu That `update-grub` Does Not Touch

`update-grub` still writes `/boot/grub/grub.cfg`, and nothing boots from it. What boots is `/boot/grub/c630.cfg`, written by `c630-menu` (`c630/scripts/c630-menu`). For every installed kernel it writes four entries, each with that kernel's own device tree:

| Entry | What it is for |
| :--- | :--- |
| quiet | the default |
| `verbose debug` | `ignore_loglevel earlycon=efifb keep_bootcon`, shows where a boot stops |
| `SAFE` | no Qualcomm firmware, pre-firmware initramfs |
| `TEST device tree` | a patched DTB, for experiments |

A `CONTROL` entry boots the installer stick's own kernel and installer from the disk. If it reaches the language screen, the boot loader and DTB are fine and the fault is in the kernel or initramfs of the entry that failed.

The menu regenerates itself from hooks in `/etc/kernel/postinst.d`, `/etc/kernel/postrm.d` and `/etc/initramfs/post-update.d`, and it refuses to write a menu whose default kernel has no entry.

Every entry carries the same kernel options. This is the default entry as booted:

```
$ cat /proc/cmdline
BOOT_IMAGE=/boot/vmlinuz-7.2.9+deb14-arm64 root=UUID=a81deabf-0654-4f68-b795-284305d26f13 ro clk_ignore_unused pd_ignore_unused regulator_ignore_unused usbcore.autosuspend=-1 modprobe.blacklist=ipa quiet
```

`clk_ignore_unused pd_ignore_unused regulator_ignore_unused` stop Linux switching off clocks, power domains and regulators the device tree does not claim. The keyboards locked up during the install before `regulator_ignore_unused usbcore.autosuspend=-1` were added, and none of the 22 boots since has shown a lockup. That cause is likely, not reproduced.

Use the root UUID, never a device name. The UFS has shown up as `sda`, `sdb` and `sdd` on different boots.

---

#### Step 4 — Test Every Risky Change With a One-Time Boot

A test boot that hangs must come back to a working default on the next power cycle. GRUB 2.12 can write `grubenv` at boot, so the menu clears the one-time entry before booting it:

```
if test -s $prefix/grubenv; then
  load_env
  if test -n "$next_entry"; then
    set default="$next_entry"
    set next_entry=
    set once="$c630_once_args"
    export once
    set c630_once_args=
    save_env next_entry c630_once_args
  fi
fi
```

`$once` is appended to every `linux` line, so a one-time boot can also carry extra kernel options:

```
sudo c630-menu --once c630-7.2.9+deb14-arm64 "modprobe.blacklist=qcom_q6v5_mss"
```

A SoC reset during that boot recovers by itself, because the watchdog resets the chip and GRUB boots the default.

---

#### Step 5 — Move to Kernel 7.2

Debian's 6.12 kernel boots, but it has no battery or USB-C drivers and it logs four `clk_core_disable` warnings from the display driver on every boot. The 7.2.9 kernel from sid has neither problem:

| | 6.12.107 | 7.2.9 |
| :--- | :--- | :--- |
| Boots | 🟢 yes | 🟢 yes 🥇 |
| Battery, AC adapter | ❌ no driver | 🟢 `yoga-c630-battery`, 55.55 Wh full of 60 Wh design |
| USB-C (both ports) | ❌ no driver | 🟢 `ucsi_yoga_c630`, DisplayPort alt mode |
| Embedded controller | ❌ no driver | 🟢 `lenovo_yoga_c630` |
| Display clock warnings | ⚠️ 4 per boot | 🟢 none |

7.2.9 is the default in `/etc/default/c630-menu`. 6.12 stays in the menu as the fallback.

---

#### Step 6 — Install GNOME on sid

`gnome-core` and Google Chrome's arm64 package install with `scripts/gnome-install.sh`. Two sid problems need fixing alongside:

- **PAM:** sid's `libpam` 1.7.0 does not read `/usr/lib/pam.d`, so `systemd-user` and `polkit-1` fall back to the generic rules. Copy both files to `/etc/pam.d/`, and check them again after a `systemd` or `polkitd` upgrade.
- **Plymouth:** `gnome-core` pulls it in, and it changes the initramfs. Pin it out with `Pin-Priority: -1` in `/etc/apt/preferences.d/no-plymouth`.

```
$ gnome-shell --version
GNOME Shell 50.5
```

---

#### Step 7 — Fix the Bluetooth Address

The WCN3990 Bluetooth controller comes up with no public address, because none is provisioned. `c630-bt-addr` derives a stable, locally administered one from `/etc/machine-id`. `hci0` appears before the chip finishes loading its firmware, so the script retries every 0.5 s for up to 30 s:

```
for i in $(seq 1 60); do
  if btmgmt -i hci0 public-addr "02:$h" 2>&1 | grep -q "complete"; then
    echo "hci0 public address 02:$h set after $i tries"; exit 0
  fi
  sleep 0.5
done
```

```
$ bluetoothctl show
Controller 02:BF:6F:61:DD:AB (public)
	Powered: yes
```

A systemd unit, `c630-bt-addr.service`, runs it at boot.

---

#### Step 8 — Install the Lenovo Firmware

The device tree asks for eight signed files under `qcom/sdm850/LENOVO/81JL/`. Debian does not ship them. They come from Lenovo's Windows driver release 200.0.19.0, mirrored by WOA-Project, in three cabinet files that `7z x` unpacks with no Windows needed:

| Cabinet | Files | Enables |
| :--- | :--- | :--- |
| `qcdx850.cab` | `qcdxkmsuc850.mbn`, `qcvss850.mbn` | GPU zap shader, video |
| `qcsubsys850.cab` | `qcadsp850.mbn`, `qccdsp850.mbn`, `qcdsp1v2850.mbn`, `qcdsp2850.mbn`, `qcslpi850.mbn`, `WLANMDSP.MBN` | audio, modem, Wi-Fi, sensor DSPs |
| `qcipa850.cab` | `ipa_fws.elf` | modem data path |

The files are proprietary, so the repository records only their sha256 sums and source URL.

**The GPU firmware must be in the initramfs.** `msm` loads before the root filesystem mounts, and sid's initramfs-tools copies no `qcom/` firmware. An initramfs hook (`c630/initramfs/c630-firmware`) adds `qcom/a630_sqe.fw`, `qcom/a630_gmu.bin` and the zap shader.

**Mask the userspace `pd-mapper.service`.** Debian has no `.jsn` maps for this SoC, so it fails. The in-kernel `qcom_pd_mapper` in 7.2 does the job.

---

#### Step 9 — Bisect the Reset Down to One Driver

The first boot with all the firmware reset the SoC about 6 s in, right after `systemd-udevd` started. Each step below is one `c630-menu --once` boot that blocks a different set of drivers:

| Test | Enabled | Result |
| :--- | :--- | :--- |
| full | everything | ❌ Reset |
| 1 | GPU only | 🟢 Renderer `FD630` |
| 2 | + adsp, cdsp, slpi | 🟢 Sound card `sdm845 - Lenovo-YOGA-C630-13Q50` |
| 3 | + modem + IPA | ❌ Reset |
| 3a | + modem, IPA blocked | 🟢 `wlan0` |
| 4 | + venus, IPA blocked | 🟢 `qcom-venus-decoder`, `qcom-venus-encoder` |

IPA is the hardware data path between the LTE modem and Linux. Every normal entry now carries `modprobe.blacklist=ipa`, and the modem itself still runs, because Wi-Fi depends on it.

---

#### Why Does IPA Reset the SoC?

`modprobe ipa` on a running system fails the same way, only slower. The cause is in the driver and its firmware, at any point in the boot:

```
[1361.110] ipa 1e40000.ipa: IPA driver initialized
[1364.556] ipa 1e40000.ipa: GSI command 0 for event ring 2 timed out, state 1
[1364.648] [dpu error]enc35 frame done timeout
[1371.361] Error sending AMC RPMH requests (-110)
[1372.024] watchdog: CPU1: Watchdog detected hard LOCKUP on cpu 2
```

The driver comes up. About 3 s later the GSI, IPA's DMA engine, stops answering commands. The display stalls, then the RPMh resource manager stops answering, and the whole SoC hard-locks. The watchdog resets it, and the default entry is back up in about 50 s.

Setting `qcom,gsi-loader = "modem"` in a test device tree stops the lockup. In that mode Linux waits for the modem to load the GSI firmware, and the Lenovo modem firmware never does, so no `rmnet_ipa0` interface appears. Safe, but no data.

Two hypotheses are untested. The Lenovo `ipa_fws.elf` may be a different build from the one the upstream driver was written against, and postmarketOS ships a different IPA blob that is a candidate. Or an interconnect or power vote for IPA may be missing from the device tree.

---

#### 🔎 Tip: Make a Crash Test Cost Nothing

The watchdog reset takes several seconds, so the kernel log of the failed boot survives in `journalctl -b -1 -k`. Flush and freeze the filesystem before a test that may lock up:

```
sudo journalctl --flush; sync; sudo sh -c 'fsfreeze -f / && fsfreeze -u /'
```

---

#### Step 10 — Get Wi-Fi Onto 5 GHz

`wlan0` is the WCN3990 on `ath10k_snoc`. At boot the regulatory domain is the world default, `00`, and an access point on channel 112, a DFS channel, refused the association:

```
wlan0: ae:17:d8:07:9a:8d denied association (code=18)
```

The same network on 2.4 GHz connected at once. `cfg80211` is a module loaded after the initramfs, so one modprobe option sets the country with no initramfs rebuild:

```
options cfg80211 ieee80211_regdom=US
```

That file is `/etc/modprobe.d/regdom.conf`. Not yet verified across a reboot.

The Wi-Fi MAC address is random on every boot (`invalid MAC address; choosing random`), so NetworkManager uses a stable MAC per network (`wifi.cloned-mac-address=stable`). A captive portal login should then survive a reboot. Not yet verified.

---

#### What Works?

```
$ glxinfo -B | grep -E 'renderer|Accelerated'
    Accelerated: yes
OpenGL renderer string: FD630
```

| Hardware | State |
| :--- | :--- |
| GPU | 🟢 Works. Adreno 630, Mesa freedreno `FD630`, Vulkan on Turnip |
| Audio | 🟢 Sound card up. ⚠️ One WSA881x speaker amp failed a register read. Both speakers playing is untested |
| Wi-Fi | 🟢 Works on 2.4 GHz. ⚠️ 5 GHz DFS needs the regulatory domain set |
| Bluetooth | 🟢 Works with `c630-bt-addr` |
| Video | 🟢 Works through V4L2 decode and encode. No VA-API, so use `h264_v4l2m2m` |
| Camera | 🟢 Works, 1280×720 MJPEG at about 29 fps |
| Battery, USB-C | 🟢 Work on 7.2 |
| Keyboard backlight | ⚠️ Partial. Fn+Space toggles it in firmware. Linux cannot see it |
| Suspend | ⚠️ Partial, `s2idle` only. It resumed once with 19 hard-lockup watchdog reports, then worked |
| LTE data | ❌ Blocked with IPA. The modem answers QMI over `qrtr://0` |
| Fingerprint reader | ❌ Not visible to Linux |

---

#### Firmware Quirks Worth Knowing

| Quirk | Effect |
| :--- | :--- |
| The RTC is never set and reads 1970-01-03 | Journal times before the first NTP sync of each boot are wrong |
| No EFI variables at runtime | Only the removable boot path works |
| SMBIOS claims the firmware is not UEFI | fwupd offers no capsule updates |
| The hardware watchdog tops out at 32 s | systemd's 10-minute shutdown watchdog is rejected |
| No MAC addresses provisioned | Random Wi-Fi MAC, no Bluetooth address |

---

#### How Do You Recover When It Does Not Boot?

The runbook (`c630/RECOVERY.md`) keeps typing on the laptop to two lines:

1. Boot the installer stick, choose Rescue, pick the root filesystem and open a shell in it.
2. Type `mkdir /run/sshd` and `/usr/sbin/sshd`.

Everything else happens over SSH from the second machine. Before rebooting out of rescue, check every file the boot depends on as GRUB will see it. GRUB cannot replay the ext4 journal, so `debugfs -R 'stat /boot/grub/c630.cfg'` reads the raw disk, and `grub-script-check` parses the menu.

---

#### Summary

The goal of this article was to run a current Debian with a full desktop on the Yoga C630 without losing the ability to boot. The key to the solution was a boot path that stays fixed while everything above it changes: a held GRUB 2.12, a generated menu with a SAFE entry per kernel, and one-time boots for every risky change. The results were:

- 🟢 Debian sid, kernel 7.2.9 and GNOME Shell 50.5 on Wayland, with GPU acceleration, audio, Wi-Fi, Bluetooth, video decode, camera, battery and USB-C.
- 🟢 One-time boots recover by themselves from a SoC reset, which turned a firmware install into a bisect.
- ❌ GRUB 2.14 blacks out every kernel on this firmware. The cause inside GRUB is unknown.
- ❌ Loading IPA resets the SoC, so LTE data is blocked.
- ⚠️ Speakers, suspend and the 5 GHz fix across a reboot are not yet tested.

Scope: one C630 (81JL, BIOS `9UCN34WW`), Debian sid as of 2026-10-10, Lenovo firmware release 200.0.19.0, tested in one day, with no SIM in the modem.

The strategy for bringing up Debian on the Yoga C630 was validated with an incremental step by step approach.

---

#### References

- Repository: https://github.com/xbill9/linux-arm-adventures
- Lenovo C630 firmware mirror: [WOA-Project/Qualcomm-Reference-Drivers](https://github.com/WOA-Project/Qualcomm-Reference-Drivers/tree/master/Lenovo/YogaC630)
- postmarketOS C630 firmware: [sdm845-mainline/firmware-lenovo-yoga-c630](https://gitlab.com/sdm845-mainline/firmware-lenovo-yoga-c630)
- Arch Linux ARM packages for the C630: [rigoorozco/yoga-alarm](https://github.com/rigoorozco/yoga-alarm)
- Earlier C630 firmware notes: [aarch64-laptops/build#62](https://github.com/aarch64-laptops/build/issues/62)
