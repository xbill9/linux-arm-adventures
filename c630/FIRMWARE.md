# C630 firmware

## What's missing without it (kernel 7.2.9, 2026-10-10)

| Feature | Needs | State without it |
|---|---|---|
| GPU acceleration | `qcdxkmsuc850.mbn` (zap shader) + `qcom/a630_sqe.fw`, `a630_gmu.bin` (in `firmware-qcom-soc`) | Software rendering (llvmpipe) |
| Audio | `qcadsp850.mbn` | No sound card |
| Wi-Fi, modem | `qcdsp1v2850.mbn` (MBA), `qcdsp2850.mbn` (modem), `ipa_fws.elf`, `wlanmdsp.mbn` (served to the modem by `tqftpserv`) | No wireless device |
| Video decode | `qcvss850.mbn` | `qcom-venus` probe fails |
| Compute DSP, sensors | `qccdsp850.mbn`, `qcslpi850.mbn` | Remoteprocs offline |

The device tree (`sdm850-lenovo-yoga-c630.dtb`) asks for exactly eight files under `qcom/sdm850/LENOVO/81JL/`:
`ipa_fws.elf qcadsp850.mbn qccdsp850.mbn qcdsp1v2850.mbn qcdsp2850.mbn qcdxkmsuc850.mbn qcslpi850.mbn qcvss850.mbn`

Debian doesn't ship them. `firmware-qcom-soc` has Lenovo files for the X13s (`sc8280xp/LENOVO/21BX`) and some X1E models, but not for 81JL. They're signed for this laptop.

## Where they come from

Lenovo's Windows driver releases for the Yoga C630, mirrored by WOA-Project:
<https://github.com/WOA-Project/Qualcomm-Reference-Drivers/tree/master/Lenovo/YogaC630>

Release **200.0.19.0**, three cabinets:

| Cab | Contents used |
|---|---|
| `qcdx850.cab` (driver 26.18.10620.0, 2019-05-29) | `qcdxkmsuc850.mbn`, `qcvss850.mbn` |
| `qcsubsys850.cab` | `qcadsp850.mbn`, `qccdsp850.mbn`, `qcdsp1v2850.mbn`, `qcdsp2850.mbn`, `qcslpi850.mbn`, `WLANMDSP.MBN` |
| `qcipa850.cab` | `ipa_fws.elf` |

Unpacking with `7z x <cab>` works. No Windows needed.

```
sha256 (first 16)  file
c3ebf4d6191a09d6   ipa_fws.elf
ce4f965c42c9ba54   qcadsp850.mbn
4f45c8d6e14e655c   qccdsp850.mbn
b31e5a6261d86846   qcdsp1v2850.mbn
dfcd3302f5b1ab52   qcdsp2850.mbn
5d582357d74522ea   qcdxkmsuc850.mbn
edb1632cb8a30d85   qcslpi850.mbn
1e36a269697c9ce5   qcvss850.mbn
1bd70539aa9477e7   wlanmdsp.mbn   (WLANMDSP.MBN, lowercased)
```

These are proprietary, so they live in `c630/firmware-local/` (git-ignored) and are **not published in this repo**.

Earlier references: [aarch64-laptops/build#62](https://github.com/aarch64-laptops/build/issues/62) (the Windows `DriverStore` paths of the same files), [Celliwig/Lenovo-Yoga-c630 `yoga_fw_extract`](https://github.com/Celliwig/Lenovo-Yoga-c630/blob/master/yoga_fw_extract/yoga_fw_extract.sh) (extraction from an installed Windows), and [kcxt/c630_bootstrap](https://github.com/kcxt/c630_bootstrap) (an Arch setup that adds the zap shader and `a630_*` to the initramfs).

[rigoorozco/yoga-alarm](https://github.com/rigoorozco/yoga-alarm) (Arch Linux ARM packages, last pushed 2026-08-15) gets its firmware from a different source: [sdm845-mainline/firmware-lenovo-yoga-c630](https://gitlab.com/sdm845-mainline/firmware-lenovo-yoga-c630) at commit `6ddfd13d`, the postmarketOS package. Besides the eight DT files it ships things our cabs don't give us. None of it has been compared or tried here:

- **pd-mapper maps:** `adspr.jsn`, `adspua.jsn`, `cdspr.jsn`, `modemuw.jsn` under `81JL/`. Only matter if the userspace `pd-mapper` is ever wanted back. The in-kernel one works.
- **Variants:** `qcdsp1v2850_nm.mbn`, `qcdsp2850_nm.mbn`, `qcslpi850_cls.mbn`.
- **A different IPA blob:** `postmarketos/ipa_fws.mdt` (33 KB, sha256 `5094a6cf8546b643…`), which is not the same blob as Lenovo's `ipa_fws.elf`. yoga-alarm installs it outside the DT's `firmware-name` path, so that package isn't evidence IPA works with it. It's a candidate for [MODEM.md](MODEM.md) hypothesis 1.
- Its kernel is the `sdm845-mainline` tree (`sdm845-7.1-rc1`), not stock. The C630 delta it adds to the `sdm845.config` fragment ([yoga.config](https://github.com/rigoorozco/yoga-alarm/blob/develop/packages/linux-yoga/yoga.config)) is `UCSI_LENOVO_YOGA_C630`, `HID_LENOVO`, `QCOM_WDT`, `SPI_QCOM_GENI`, `REGULATOR_QCOM_REFGEN`, `GPIO_SHARED_PROXY` and the CrOS EC Type-C/extcon options.

## Other pieces

- **The initramfs needs the GPU firmware.** `msm` is in the initramfs and probes before the root mount. sid's initramfs-tools 0.151 copies **no** `qcom/` firmware into it, so the GPU fails even though `firmware-qcom-soc` has `a630_sqe.fw`. Fix: an initramfs hook that adds `qcom/a630_sqe.fw`, `qcom/a630_gmu.bin` and `qcom/sdm850/LENOVO/81JL/qcdxkmsuc850.mbn`.
- **PD mapper:** kernel 7.2 has the in-kernel `CONFIG_QCOM_PD_MAPPER=m`. The userspace `pd-mapper.service` (package `protection-domain-mapper`) fails with `no pd maps available`. Debian ships no `sdm845`/`sdm850` `.jsn` maps. Expect to mask the userspace one and rely on the kernel's.
- **Already installed:** `rmtfs`, `tqftpserv` and `qrtr-tools` (active). `ath10k_snoc` is loaded, waiting for the modem.
- **Bluetooth** doesn't need any of this. It loads `qca/crbtfw21.tlv` + `crnv21.bin` from `firmware-atheros`, but needs a public address set at boot. `c630-bt-addr.service` handles that (`/usr/local/sbin/c630-bt-addr`).

## Installed 2026-10-10, and what each piece needed

| Piece | Done |
|---|---|
| Firmware files | `/usr/lib/firmware/qcom/sdm850/LENOVO/81JL/` (the nine files above, checksums verified) |
| GPU firmware in the initramfs | `/etc/initramfs-tools/hooks/c630-firmware` ([initramfs/c630-firmware](initramfs/c630-firmware)) adds `qcom/a630_sqe.fw`, `qcom/a630_gmu.bin`, `…/81JL/qcdxkmsuc850.mbn`, and (since 2026-10-11) the DSP blobs `qcadsp850.mbn`, `qccdsp850.mbn`, `qcslpi850.mbn`. Without them `qcom_q6v5_pas` can probe from the initramfs, fail with `-2` and leave the DSPs offline (no sound card) |
| Userspace pd-mapper | masked. The in-kernel `qcom_pd_mapper` handles it (audio works) |
| **IPA** | **blocked on every boot** (`modprobe.blacklist=ipa`, in `c630-menu`'s `P`). **Loading `ipa_fws.elf` resets the whole SoC** about 6 s into boot. IPA is only the modem's cellular data path, so Wi-Fi doesn't need it |

### How the crash was found (bisect with one-time boots)

The first full-firmware boot reset the chip right after `systemd-udevd` started, and the log ended there. Each step was a `c630-menu --once c630-7.2.9+deb14-arm64 "modprobe.blacklist=…"` boot. A crash auto-recovers to the SAFE default.

| Test | Enabled | Result |
|---|---|---|
| full | everything | **reset** |
| 1 | GPU only | OK: renderer `FD630` |
| 2 | + adsp/cdsp/slpi (`qcom_q6v5_pas`) | OK: sound card `sdm845 - Lenovo-YOGA-C630-13Q50` |
| 3 | + modem (`qcom_q6v5_mss`) + IPA | **reset** |
| 3a | + modem, IPA blocked | OK: `wlan0` (WCN3990, `firmware-atheros` firmware-5) |
| 4 | + venus, IPA blocked | OK: `qcom-venus-decoder`/`-encoder` |
| default | all but IPA | OK: `systemctl is-system-running` = `running` |

### Undo

`sudo c630-fw-rollback` ([scripts/c630-fw-rollback](scripts/c630-fw-rollback)) moves the firmware and hook to `/root/c630-fw-rollback-<time>/`, restores the pre-firmware initramfs, unmasks pd-mapper and sets the menu to SAFE. It works from SSH or from the rescue chroot.
