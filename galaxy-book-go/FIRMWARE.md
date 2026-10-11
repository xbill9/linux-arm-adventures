# Galaxy Book Go firmware

Status 2026-10-11 11:50: **Wi-Fi, GPU acceleration and video decode/encode work** with Samsung's own firmware. The audio DSP doesn't (wrong reserved memory in the DTB). Bluetooth: not yet.

## Source

Debian doesn't ship Samsung-signed sc7180 firmware. The files come from a Book Go's Windows `DriverStore\FileRepository`, harvested onto the PNY Win11 stick (`GBGo-Drivers/`, see [win11-stick/README.md](win11-stick/README.md)). The stick was mounted read-only. Several driver versions sit side by side; the newest of each was taken:

| File | Driver folder | Version | sha256 |
|---|---|---|---|
| `qcdxkmsuc7180.mbn` | `qcdx7180.inf_arm64_49745b7d6ae686e6` | 27.20.0910, 2022-04-05 | `ab040159aee7ab7e…` |
| `qcvss7180.mbn` | same | same | `280ed4a092017770…` |
| `qcmpss7180_nm.mbn` | `qcsubsys_ext_mpss7180.inf_arm64_e782b05b88d201c7` | 1.0.0800.8, 2022-09-29 | `a4016412a5071a95…` |
| `wlanmdsp.mbn` | `qcwlan7180.inf_arm64_c95a2a1e36575e8e` | 1.0.0970, 2023-03-17 | `7688eea1c1371528…` |
| `qcadsp7180.mbn` | `qcsubsys_ext_adsp7180.inf_arm64_aa5edc10eae1a672` | 1.0.0750.3, 2023-03-13 | `d795ab4f25f3e477…` |

Older copies on the stick: `qcdx7180` 27.20.0800 (2021-07-07; zap `871fc5df934adf59…`, vss `17465758e211ee91…`), `qcwlan7180` 1.0.0800 (`360a134e9a954895…`) and 1.0.0910 (`26bc1c6a2e46f398…`). Also there and unused: `qcmpss7180_BTU.mbn` (64 MB), `qccdsp7180.mbn` (no cdsp node in the DTB), `ipa_fws.elf` (IPA is disabled in the DTB; this is the Wi-Fi-only model), HDCP/PlayReady trustlets.

Proprietary: kept in `galaxy-book-go/firmware-local/` (git-ignored) and `/root/gbgo-fw-staging/` on the laptop, never in this repo.

## What the GPU needs

Kernel 6.12's `msm` uses `a630_sqe.fw` + `a630_gmu.bin` for the Adreno 618 (both in `firmware-qcom-soc`) and the zap shader from the DTB. **There is no `a618_gmu.bin`**; the 2026-10-11 audit guessed wrong. With the zap shader: `/sys/class/devfreq/5000000.gpu` exists (`simple_ondemand`, 180 MHz idle), no `gpu hw init failed`, and gnome-shell maps `libgallium` instead of software rendering.

## How it was tested (no boot loops)

The C630 lesson: one bad firmware file (IPA) reset the SoC on every boot. So nothing went into `/usr/lib/firmware` before it had run once.

1. Staged in `/root/gbgo-fw-staging/`. `/sys/module/firmware_class/parameters/path` pointed there **for the running boot only**; journal flushed and `fsfreeze` before each step.
2. Audio DSP: `echo start > …/remoteproc1/state` → `segment outside memory range`, `Boot failed: -22`. No crash. See below.
3. Modem DSP: up, `ath10k_snoc` reports `WLAN.HL.3.2.2.c10-00767` (2023-02-09), `wlan0` associated with the saved network.
4. Venus: bind → `qcom-venus-decoder`, `qcom-venus-encoder`.
5. Zap shader: `msm` stops retrying GPU init within a boot, so it was tested with a **one-time GRUB entry** (`gbgo-fwtest-<kver>`, `firmware_class.path=/usr/lib/firmware-gbgo-test`, via `grub-reboot`). A hang would have fallen back to the default without it. It booted; GPU up.
6. Then installed for good with [scripts/gbgo-firmware](scripts/gbgo-firmware) (`/usr/local/sbin/`): `install`, `promote` (test → real path, removes the test entry), `rollback`.

Installed: `/usr/lib/firmware/qcom/sc7180/samsung/galaxy-book-go/{qcdxkmsuc7180,qcmpss7180_nm,qcvss7180,wlanmdsp}.mbn`. Verified across a reboot of the default entry: `running`, no failed units, GPU, venus, `wlan0`.

## `wlanmdsp.mbn` is needed

The modem fetches it from `tqftpserv` (QRTR TFTP). `tqftpserv` also looks in `firmware_class.path`, which is why Wi-Fi worked during the staging test even though the file wasn't installed. Without it: modem `running`, no `qmi chip_id`, no `wlan0`. The `invalid path /readonly/vendor/firmware…/wlanmdsp.mbn, rejecting` lines are the modem's first guesses and are harmless.

## Boot race: modem vs `tqftpserv`

The modem powers up a few ms after `rmtfs`/`tqftpserv` start. When it asks for `wlanmdsp.mbn` before `tqftpserv` answers, the WLAN start stalls and **the modem's watchdog crashes it after 40 s** (`DOG detects stalled initialization`). The kernel's recovery restarts it, and the second try works: Wi-Fi after ~60 s. Other boots win the race (Wi-Fi at 17 s).

[scripts/gbgo-wifi-kick](scripts/gbgo-wifi-kick) + [system/gbgo-wifi-kick.service](system/gbgo-wifi-kick.service) (`After=rmtfs tqftpserv`): if `wlan0` hasn't appeared 10 s after the services, restart the modem. The restart itself was tested live; **the service has not yet had to fire during a real boot** (the one verified boot won the race and it logged `wlan0 present`).

## Audio DSP: wrong reserved memory

| | Firmware loads at | DTB reserves |
|---|---|---|
| ADSP | `0x90b00000`–`0x93900000` | `adsp@8e400000`, size `0x2800000` (to `0x90c00000`) |
| MPSS | `0x86000000`–`0x88000000` | `mpss@86000000`, size `0x2000000`: matches |

The draft DTB took the Aspire 1's layout. Samsung's ADSP region ends exactly where `wlan@93900000` begins, so the fix is likely `adsp@90b00000` size `0x2e00000`. **Not done:** it needs a DTB change and a reboot, and audio also needs a sound node the DTB doesn't have. `qcadsp7180.mbn` stays out of `/usr/lib/firmware` until then.

## Undo

`sudo gbgo-firmware rollback` moves the files to `/root/gbgo-fw-rollback-<time>/`; `sudo systemctl disable gbgo-wifi-kick`. Reboot.
