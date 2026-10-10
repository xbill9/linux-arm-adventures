# C630 LTE modem

Status 2026-10-10: **the modem runs and answers QMI. Mobile data is blocked, because IPA locks up the SoC.** No SIM is inserted yet (the unit has a slot).

## What works

The modem (`qcom_q6v5_mss`, firmware `qcdsp1v2850.mbn` + `qcdsp2850.mbn`) boots and is reachable over QRTR with `qmicli -d qrtr://0`:

| Query | Result |
|---|---|
| `--dms-get-ids` | IMEI `8694410XXXXXXXX (redacted)`, ESN `0` |
| `--dms-get-revision` | `MPSS-12044-SDM845_V6_0318  1  [Aug 23 2018 14:00:00]` |
| `--dms-get-capabilities` | Networks `umts, lte`. SIM `supported`. Max RX 100 Mb/s, TX 50 Mb/s. `non-simultaneous-cs-ps` |
| `--uim-get-card-status` | Slot 1: `error: no-atr-received (3)` (no SIM inserted) |
| `--dms-get-operating-mode` | `shutting-down` (not yet understood; re-check with a SIM) |

`qrtr-lookup` lists the full cellular service set: NAS (3), WDS (1), DMS (2), UIM (11), WMS (5), Voice (9), CAT2 (10), QoS (4), WDA (26), DPM (47), DSD (42), Location (16), IMS (33, 77), plus **IPA control (49)** and the ath10k WLAN service (69).

ModemManager 1.24.2 is active but reports `No modems were found`. It most likely needs the IPA data port (`rmnet_ipa0`) to create a modem. Not verified.

## What fails: IPA

IPA (`ipa` driver, `qcom,sdm845-ipa`, firmware `ipa_fws.elf` from `qcipa850.cab`) is the hardware data path between the modem and Linux. Loading it **always** brings the machine down:

- **At boot** (full-firmware boot, 12:20): the SoC reset about 6 s in, with no log saved.
- **On a running system** with the modem fully up (`sudo modprobe ipa` at uptime ~1361 s, 13:03): the same failure, just slower. Full log: [logs/2026-10-10-ipa-modprobe-crash.log](logs/2026-10-10-ipa-modprobe-crash.log).

So it is **not** a boot-ordering problem. What the log shows:

```
[1361.108] ipa 1e40000.ipa: channel 4 limited to 256 TREs
[1361.110] ipa 1e40000.ipa: IPA driver initialized          <- GSI firmware loaded, driver up
[1364.556] ipa 1e40000.ipa: GSI command 0 for event ring 2 timed out, state 1
           ... same for event rings 0-3 and channels 3-6 ...
[1364.558] ipa 1e40000.ipa: GSI command 1 for channel 4 timed out, state 2
[1364.648] [dpu error]enc35 frame done timeout              <- display stalls
[1371.360] WARNING: drivers/soc/qcom/rpmh.c:386 at rpmh_write_batch
           (cpufreq -> OPP -> icc_set_bw -> qcom_icc_bcm_voter_commit -> rpmh_write_batch)
[1371.361] Error sending AMC RPMH requests (-110)
[1372.024] watchdog: CPU1: Watchdog detected hard LOCKUP on cpu 2
```

**The sequence:** the driver initializes, the GSI (IPA's DMA engine) stops answering commands about 3 s later, then the RPMh resource manager stops answering too. That shows up as an interconnect bandwidth vote from cpufreq timing out, after the display has already stalled, and the whole SoC hard-locks. The watchdog resets it, and the menu's default (IPA blocked) comes back up by itself in about 50 s.

Device tree (`sdm850-lenovo-yoga-c630.dtb`, from the 7.2.9 kernel package):
`compatible = "qcom,sdm845-ipa"`, `qcom,gsi-loader = "self"` (Linux loads the GSI firmware through TrustZone), `firmware-name = "qcom/sdm850/LENOVO/81JL/ipa_fws.elf"`, `interconnect-names = "memory" "imem" "config"`, `clock-names = "core"`.

## Hypotheses (not yet tested)

1. **The firmware doesn't match what the Linux driver expects.** `ipa_fws.elf` comes from Lenovo's Windows driver (`qcipa850.cab`, release 200.0.19.0). The GSI may hang if it isn't the build the upstream SDM845 IPA v3.5.1 support was written against. Next: compare with any `ipa_fws` that upstream linux-firmware or other SDM845 devices ship, and try an older cab release.
2. **Loader mode.** Try `qcom,gsi-loader = "modem"`, so the modem's firmware loads GSI instead of Linux. Test it as a one-time boot with a patched copy of the DTB (`fdtput -t s … qcom,gsi-loader modem`), keeping the current DTB as the default.
3. **Interconnect / power votes.** The lockup goes through RPMh. A missing or wrong IPA interconnect or power-domain vote could stall the bus. Check what the upstream DTS and kernel commits say about C630/SDM845 IPA and whether anyone has LTE data working on a C630.

## How to test safely

- Normal boots have `modprobe.blacklist=ipa` (from `c630-menu`). A manual `sudo modprobe ipa` still loads it, because a blacklist only stops automatic loading.
- **Before a test:** `sudo journalctl --flush; sync; sudo sh -c 'fsfreeze -f / && fsfreeze -u /'`. Then a lockup costs nothing: the watchdog resets, and the default boot (IPA blocked) comes back.
- The crash log survives in `journalctl -b -1 -k`, because the lockup takes several seconds.
- DT experiments: copy `/boot/c630boot/dtb-<kver>`, patch it, add a one-off menu entry, and boot it with `c630-menu --once`.
