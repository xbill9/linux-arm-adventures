# C630 hardware status

Kernel 7.2.9+deb14-arm64, Debian sid, GNOME 50 on Wayland. Checked 2026-10-10 over SSH, **before** installing the Lenovo firmware.

## Works

| Hardware | Driver / detail |
|---|---|
| Display (built-in eDP) | `msm_dpu`, `/dev/dri/card0`, `card0-eDP-1 connected`. Rendering is software only (see GPU below) |
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

## Needs the Lenovo firmware

See [FIRMWARE.md](FIRMWARE.md). The files have been found but not yet installed.

| Hardware | Missing | Kernel message |
|---|---|---|
| GPU acceleration | `qcdxkmsuc850.mbn`, and `a630_sqe.fw` **in the initramfs** | `Unable to load …/qcdxkmsuc850.mbn`, `failed to load a630_sqe.fw` |
| Audio | `qcadsp850.mbn` (adsp remoteproc) | `--- no soundcards ---` |
| Wi-Fi | modem `qcdsp1v2850.mbn` / `qcdsp2850.mbn` + `wlanmdsp.mbn` (served by `tqftpserv`); `ath10k_snoc` is loaded and waiting | no `wlan0` |
| Modem data (IPA) | `ipa_fws.elf` | `ipa … probe … failed with error -2` |
| Video decode | `qcvss850.mbn` | `qcom-venus … fail to load video firmware` |
| Compute DSP | `qccdsp850.mbn` | `cdsp` offline |
| Sensors | `qcslpi850.mbn` | `slpi` offline |

## Known noise in the logs

- `pd-mapper.service` fails (`no pd maps available`). Kernel 7.2 has the in-kernel `qcom_pd_mapper`, so the userspace one should be masked.
- `rmtfs: failed to update start state` at boot: harmless until the modem firmware is present.
- `integrity: Couldn't get UEFI db list` / `MODSIGN`: the firmware has no usable EFI variables.
- `yoga-c630-ec … Failed to create device link …`: harmless.
- `psci: [Firmware Bug]: failed to set PC mode: -3`: known on this firmware.
- `coresight-tmc … probe … failed with error -13`: debug hardware, harmless.

## Not looked at yet

Fingerprint reader, ambient light/rotation sensors (need `slpi`), suspend/resume cycle, external display over USB-C, and battery life.
