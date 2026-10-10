# C630 hardware status

Kernel 7.2.9+deb14-arm64, Debian sid, GNOME 50 on Wayland. Checked 2026-10-10 over SSH. Lenovo firmware installed at 12:34; IPA blocked.

## Works

| Hardware | Driver / detail |
|---|---|
| Display (built-in eDP) | `msm_dpu`, `/dev/dri/card0`, `card0-eDP-1 connected` |
| **GPU acceleration** | Adreno 630, Mesa freedreno: renderer `FD630` (zap shader + `a630_*` from the initramfs) |
| **Audio** | adsp running. Card `sdm845 - Lenovo-YOGA-C630-13Q50`. Speakers/mic not yet tested. **One speaker amp (`wsa881x` `sdw:…:00:4`) failed a register read at boot** on 2026-10-10. A left/right test is needed. See [QUIRKS.md](QUIRKS.md#other-hardware-issues). **Possible fix if speakers or headphones are silent:** [yoga-alarm](https://github.com/rigoorozco/yoga-alarm/tree/develop/packages/alsa-ucm-conf-yoga-c630) replaces `ucm2/Qualcomm/sdm845/HiFi-MM1.conf` to add the `RX INT0_1`/`RX INT1_1` speaker routes and the `RX INT1_1`/`RX INT2_1 INTERP` headphone routes that the generic WCD934x sequences leave out, and pins both sinks to S16LE/48 kHz/2 ch in WirePlumber. Untested here |
| **Wi-Fi** | modem running, `wlan0` (WCN3990, ath10k_snoc, `firmware-atheros` api 5). **Connects** on 2.4 GHz. 5 GHz DFS channels were refused under regdomain `00`, now fixed with `regdom.conf`. See [WIFI.md](WIFI.md). The hardware MAC is random each boot (`invalid MAC address`), so NetworkManager uses a **stable per-network MAC** instead ([system/NetworkManager/c630-wifi-mac.conf](system/NetworkManager/c630-wifi-mac.conf)) |
| Captive portals (Starbucks etc.) | `network-manager-config-connectivity-debian` (checks `network-test.debian.org`), so GNOME prompts to sign in and opens Chrome. Fallback: the **Wi-Fi Login** launcher ([desktop/wifi-login.desktop](desktop/wifi-login.desktop), opens `http://neverssl.com/`). GNOME 50 has no built-in portal window |
| **Video decode/encode** | `qcom-venus-decoder`, `qcom-venus-encoder` |
| Compute DSP, sensor DSP | cdsp, slpi running. Sensors not yet tested |
| Keyboard | `hid-over-i2c 6243:0001` on `i2c-11` (`11-005c`). The same HID device carries `Wireless Radio Control` and the HID sensor hub (accelerometer). Locked up during the install before `regulator_ignore_unused`/`usbcore.autosuspend=-1` were added. See [QUIRKS.md](QUIRKS.md) |
| Touchpad | `hid-over-i2c 06CB:CD3E` (Mouse, Touchpad) on `3-002c` |
| Touchscreen + pen | `hid-over-i2c 04F3:279F` (+ `Stylus`). The pen battery shows as `hid-0018:04F3:279F…-battery` |
| Lid / buttons | `gpio-keys`, `pm8941_pwrkey`, plus the keyboard device's system buttons |
| Battery | `yoga-c630-battery` (Compal PABAS0241231, Li-ion): 55.55 Wh full of 60 Wh design (≈93 %). No `capacity` file: the percentage comes from `energy_now`/`energy_full` |
| AC adapter | `yoga-c630-adapter`, online |
| USB-C (both ports) | `ucsi_yoga_c630`; `typec` `port0`, `port1` with partner/cable. Also DisplayPort alt mode (`typec_displayport`) |
| EC | `lenovo_yoga_c630` (7.2 only; not in Debian's 6.12) |
| Bluetooth | WCN3990 over UART, `qca/crbtfw21.tlv` + `qca/crnv21.bin`. **Needs a public address at boot** (`c630-bt-addr.service`), then works. A scan found 16 devices |
| Camera | `Integrated Camera` (UVC, `/dev/video0`, `/dev/video1`). Detected; capture not tested |
| USB Ethernet | `cdc_ncm` (`enxf8e43b0fecaf`). netconsole does **not** work over it |
| Suspend | `s2idle` only (`mem_sleep: [s2idle]`). GNOME's idle timer suspended it once. It resumed with a burst of hard-LOCKUP watchdog reports and EC I2C errors, then worked. See [QUIRKS.md](QUIRKS.md#suspend-s2idle-and-the-resume-lockup-storm) |
| Accelerometer | `accel_3d` (HID sensor over I2C). `monitor-sensor` reported orientation and tilt on 2026-10-10, but **`iio-sensor-proxy` can crash at boot** (SIGSEGV, the unit is left `failed`), and then nothing rotates the screen. See [QUIRKS.md](QUIRKS.md#other-hardware-issues) |
| Vulkan | Mesa Turnip, `Turnip Adreno (TM) 630` |
| Storage | UFS (`ufshcd-qcom`), SK hynix `KLUDG4U1EA-B0C1`, 128 GB |
| CPU frequency | `qcom-cpufreq-hw`, `schedutil`. 0.3–1.77 GHz little cores, 0.83–2.84 GHz big cores |
| Swap | `/dev/sda4` (6 GB, priority -1) + zram `/dev/zram0` (3.7 GB, priority 100, `systemd-zram-generator`) |

## Doesn't work / blocked

| Hardware | Why |
|---|---|
| IPA (modem cellular data offload) | Loading `ipa_fws.elf` hard-locks the SoC (GSI timeouts, then an RPMh timeout, then a watchdog reset), at boot and on a running system. Blocked with `modprobe.blacklist=ipa`. See [MODEM.md](MODEM.md) |
| Fingerprint reader | Not visible to Linux: no USB device and nothing in the DT. `fprintd` won't help |
| Ambient light / proximity | `monitor-sensor` reports none. They would come from the sensor DSP (slpi), which needs `hexagonrpcd` (0.4.0-2 in sid, not installed) plus libssc |
| VA-API | No driver (`vainfo` fails). Expected: Venus is a V4L2 mem2mem device. Use `ffmpeg -c:v h264_v4l2m2m` (also hevc, vp8, vp9, mpeg2/4, vc1) |
| LTE data | The modem runs (IMEI, UMTS/LTE, SIM slot, QMI over QRTR all work), but there's no data path without IPA. No SIM inserted yet. See [MODEM.md](MODEM.md) |

## Known noise in the logs

Firmware-level quirks (RTC stuck in 1970, garbage EFI memory-attribute table, 32 s watchdog, SMBIOS claiming no UEFI) are in [QUIRKS.md](QUIRKS.md).

- `pd-mapper.service` is masked (the in-kernel `qcom_pd_mapper` is used). `rmtfs` fails only in SAFE mode, where the modem is blocked.
- `ath10k … failed to load ath10k/WCN3990/hw1.0/firmware-6.bin`: it probes newer APIs first, then uses firmware-5.
- `integrity: Couldn't get UEFI db list` / `MODSIGN`: the firmware has no usable EFI variables.
- `yoga-c630-ec … Failed to create device link …`: harmless.
- `psci: [Firmware Bug]: failed to set PC mode: -3`: known on this firmware.
- `coresight-tmc … probe … failed with error -13`: debug hardware, harmless.
- `ucsi_yoga_c630 … con1: Firmware bug: duplicate partner altmode SVID 0xff01 at offset N`: repeats about every 0.5 s while a USB-C dock (VIA Labs hub + billboard) is plugged in, so the DisplayPort alt mode is read again and again. Harmless, but it floods the log. Watch it during external display testing.
- `ath10k … failed to load ath10k/pre-cal-snoc-…` and `cal-snoc-18800000.wifi.bin`: optional calibration files. Board data comes from `board-2.bin`.
- `qcom-q6v5-mss … failed to load msadp`: a modem debug-policy file that ships with no device.
- `MultiMedia1: no backend DAIs enabled … missing … UCM profile`: logged before UCM loads. `alsa-ucm-conf` has `Qualcomm/sdm845/Lenovo-YOGA-C630-13Q50.conf`, and PipeWire shows the Speaker, Headphones and Mic.
- `i2c 3-0015` (hid-over-i2c) has no driver: it's the touchpad address for the other model variant. This unit's touchpad is `3-002c`.
- Platform devices with no driver bound: `ipa` (blocked), `gmu` (attaches through the GPU driver), `dcc` and `pil-reloc` (debug and info). The deferred probe list is empty.

## Extra tools installed (2026-10-10)

`ffmpeg` (V4L2 decoder test), `linux-cpupower`, `sysstat` (`sar` collection enabled), `systemd-zram-generator`, `kexec-tools` (no auto-kexec on reboot: `LOAD_KEXEC` unset, no kexec units, so `c630-menu --once` boots are unaffected), `pipewire-libcamera`.

Skipped as not relevant: `thermald`/`tuned` (temperatures are 35–41 °C at idle), `smartmontools`/`hdparm` (storage is UFS), `bluez-firmware` (Bluetooth uses `firmware-atheros`), `sof-firmware`.

## Not looked at yet

`hexagonrpcd` for the slpi sensors, suspend/resume cycle, external display over USB-C, and battery life.
