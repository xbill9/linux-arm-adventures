# C630 hardware status

Kernel 7.2.9+deb14-arm64, Debian sid, GNOME 50 on Wayland. Checked 2026-10-10 over SSH. Lenovo firmware installed at 12:34; IPA blocked.

## Works

| Hardware | Driver / detail |
|---|---|
| Display (built-in eDP) | `msm_dpu`, `/dev/dri/card0`, `card0-eDP-1 connected` |
| **GPU acceleration** | Adreno 630, Mesa freedreno: renderer `FD630` (zap shader + `a630_*` from the initramfs) |
| **Audio** | adsp running. Card `sdm845 - Lenovo-YOGA-C630-13Q50`. Speakers/mic not yet tested |
| **Wi-Fi** | modem running, `wlan0` (WCN3990, ath10k_snoc, `firmware-atheros` api 5). The MAC is random each boot (`invalid MAC address`). Not yet connected |
| **Video decode/encode** | `qcom-venus-decoder`, `qcom-venus-encoder` |
| Compute DSP, sensor DSP | cdsp, slpi running. Sensors not yet tested |
| Keyboard, touchpad | `hid-over-i2c 06CB:CD3E` (Mouse, Touchpad) |
| Touchscreen + pen | `hid-over-i2c 04F3:279F` (+ `Stylus`). The pen battery shows as `hid-0018:04F3:279F…-battery` |
| Lid / buttons | `gpio-keys`, `pm8941_pwrkey`, `hid-over-i2c 6243:0001` |
| Battery | `yoga-c630-battery` (Compal PABAS0241231, Li-ion): 55.55 Wh full of 60 Wh design (≈93 %) |
| AC adapter | `yoga-c630-adapter`, online |
| USB-C (both ports) | `ucsi_yoga_c630`; `typec` `port0`, `port1` with partner/cable. Also DisplayPort alt mode (`typec_displayport`) |
| EC | `lenovo_yoga_c630` (7.2 only; not in Debian's 6.12) |
| Bluetooth | WCN3990 over UART, `qca/crbtfw21.tlv` + `qca/crnv21.bin`. **Needs a public address at boot** (`c630-bt-addr.service`), then works. A scan found 16 devices |
| Camera | `Integrated Camera` (UVC, `/dev/video0`, `/dev/video1`). Detected; capture not tested |
| USB Ethernet | `cdc_ncm` (`enxf8e43b0fecaf`). netconsole does **not** work over it |
| Suspend | `s2idle` only (`mem_sleep: [s2idle]`). Resume not tested |

## Doesn't work / blocked

| Hardware | Why |
|---|---|
| IPA (modem cellular data offload) | Loading `ipa_fws.elf` resets the SoC. Blocked with `modprobe.blacklist=ipa`. See [FIRMWARE.md](FIRMWARE.md) |

## Known noise in the logs

- `pd-mapper.service` is masked (the in-kernel `qcom_pd_mapper` is used). `rmtfs` fails only in SAFE mode, where the modem is blocked.
- `ath10k … failed to load ath10k/WCN3990/hw1.0/firmware-6.bin`: it probes newer APIs first, then uses firmware-5.
- `integrity: Couldn't get UEFI db list` / `MODSIGN`: the firmware has no usable EFI variables.
- `yoga-c630-ec … Failed to create device link …`: harmless.
- `psci: [Firmware Bug]: failed to set PC mode: -3`: known on this firmware.
- `coresight-tmc … probe … failed with error -13`: debug hardware, harmless.

## Not looked at yet

Fingerprint reader, ambient light/rotation sensors (need `slpi`), suspend/resume cycle, external display over USB-C, and battery life.
