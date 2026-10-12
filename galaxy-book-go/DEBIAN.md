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
- 2026-10-12 12:07: **zram swap.** At 11:59 Chrome (23 processes, 831 MB) and Chromium (11, 552 MB) ran together; 802 MiB of 3.4 GiB was available, 2.0 GiB sat in the disk swap (`sdc4`), and `vmstat` showed swap-ins every second. Installed `systemd-zram-generator` 1.2.1 with [system/zram-generator.conf](system/zram-generator.conf) → `/etc/systemd/zram-generator.conf`: `zram-size = ram`, `zstd`, priority 100, so it fills before the disk swap. Result: `/dev/zram0` 3.4G zstd, prio 100. After `systemctl restart systemd-zram-setup@zram0` the swap stays off until `systemctl start dev-zram0.swap`. Verified across a reboot (17:13: `/dev/zram0` 3.4G, prio 100, 2.1G in use).

## Audio (speakers work; audio DTB is the default, 2026-10-12 17:12)

User report: no sound at all. `aplay -l`: no soundcards; `adsp` remoteproc offline.

What the hardware is, from Samsung's ACPI tables (`acpi-local/tables/dsdt.dsl`) and the Aspire 1 device tree (same SoC, upstream audio):

| Part | Galaxy Book Go (ACPI) | Acer Aspire 1 (upstream DT) |
|---|---|---|
| Headset codec | `RTK0` = `10EC5682` on `IC10` (`0xa8c000`) at `0x1a`, 400 kHz, `GpioInt` edge on virtual pin `0x100` = TLMM 43, supply `LDO15_A` 1.8 V (PEP) | `realtek,rt5682i` on `i2c@a8c000` at `0x1a`, IRQ TLMM 28, `ldo15` |
| Speaker amp | not declared (`WSAR` = `SAM0609` is the Wi-Fi SAR device: `_DEP` on `QWLN`); `AUDD` drives TLMM 21 and 20 as outputs | `maxim,max98357a`, sdmode TLMM 23 |
| I2S | not determinable: the boot firmware leaves every MI2S pin in `func0` | primary MI2S → codec, tertiary MI2S → amp |

The draft DTB has `i2c@a8c000` disabled, no codec, no amp, no sound card, and the ADSP region of the Aspire 1. TLMM 20 is the display bridge regulator in this DTB, so the amp enable is taken to be TLMM 21.

[scripts/gbgo-dtb-audio.py](scripts/gbgo-dtb-audio.py) builds the audio DTB from the installed one (+125 −2 lines): ADSP region `0x8e400000` grown to `0x5500000` (ends at `wlan@93900000`, covers Samsung's `0x90b00000`–`0x93900000`), `i2c@a8c000` on with the RT5682, a MAX98357A on TLMM 21, MI2S ports 16/17/20 on `q6afe`, and a `qcom,sc7180-qdsp6-sndcard` with the Aspire 1's links. That driver handles exactly primary + tertiary MI2S, which is why the Aspire 1 layout is the first guess. **The port mapping is unverified.**

### First test boot (12:56)

The audio DTB boots. The ADSP region is `0x8e400000..0x938fffff`, the RT5682 probes as `9-001a`, and nothing hangs. No sound card, for two reasons:

| Problem | Seen | Fix |
|---|---|---|
| ADSP firmware missing from the initramfs | The remoteproc starts at 2.8 s, from the initramfs: `request_firmware failed: -2`, `adsp offline`. It does not retry once the root filesystem is mounted | [initramfs/gbgo-firmware](initramfs/gbgo-firmware) adds `qcadsp7180.mbn`. `gbgo-boot-verify` now reports it (`1/1 ADSP firmware`) |
| No front ends on `q6asm` | After `echo start > /sys/class/remoteproc/remoteproc1/state` by hand: `remote processor adsp is now up`, APR services 3, 4, 7 and 8 appear, then `q6asm-dai …: No dais found in DT`. The card stays deferred (`MultiMedia1: error getting cpu dai name`) | `gbgo-dtb-audio.py` adds `dai@0`…`dai@3` under `service@7/dais`, one per MultiMedia link |

Samsung's `qcadsp7180.mbn` boots in the grown region: this is the first time the ADSP has run on this machine.

### Armed (13:11)

- `/boot/dtb/sc7180-samsung-galaxy-book-go.dtb.test` = the rebuilt audio DTB (`e69a154a6b31eb65…`, same on the raw disk). It differs from the first one by the four `dai@N` nodes only.
- `/boot/initrd.img-7.2.9+deb14-arm64` rebuilt with `qcadsp7180.mbn`. `gbgo-boot-verify` passes (raw disk matches, rebuilt initrd keeps every module and firmware, `1 new`). The 6.12 initrds are unchanged.
- On the default DTB the ADSP will now find its firmware in the initramfs and fail with `segment outside memory range`, as it did from the root filesystem (tested harmless 2026-10-11). Not yet verified from the initramfs.

Test: `sudo grub-reboot gbgo-dtbtest-7.2.9+deb14-arm64`, flush, reboot. Then `sudo gbgo-audio-check play` ([scripts/gbgo-audio-check](scripts/gbgo-audio-check)): ADSP state, codec and card probe, routes MultiMedia1 to both MI2S ports, plays a tone. **The port mapping is still unverified**: the card may bind and stay silent. A hang or a reset falls back to the default entry on the next power cycle.

### Second test boot (13:15): card up, no sound yet

The audio DTB plus the new initramfs: `adsp running` from the initramfs at 7.7 s, APR services 3, 4, 7, 8, the RT5682 on `9-001a`, and card 0 `SamsungGalaxyBo` with `MultiMedia1`…`4`. No errors.

| Check | Result |
|---|---|
| PipeWire | Saw the card as `Built-in Audio` with only `off` and `pro-audio` (no UCM), stayed on `off`, so the browsers played into `Dummy Output`. `wpctl set-profile <card> 1` gives the sink `Built-in Audio Pro` on `hw:0,0`, and the streams moved to it. Whether WirePlumber keeps the profile across a reboot is not yet verified |
| RT5682 headphone output | `HPOL` and `HPOR Playback Switch` start **off** (muted). Switched on by hand; headphones not yet tested |
| DMA | `hw_ptr` advances 48000 frames per second while playing |
| Pin mux | TLMM 53–56 `mi2s_0`, 57 `lpass_ext` (MCLK), 63–66 `mi2s_2`, 21 `gpio` out high (amp enable), 20 out high |
| Pin levels, one port routed at a time (200 reads of the pad each) | Primary: clock 53, word select 54, MCLK 57 toggle; data on **56** (sd line 1) with a tone, flat with `/dev/zero`. Tertiary: 63, 64 toggle; data on **65** (sd line 0) with a tone, flat with silence |
| Both ports routed together | Only tertiary carried data; primary data stayed flat. `gbgo-audio-check` now plays each port on its own |
| Speakers, tertiary only, 440 Hz for 10 s, 30 s and 2 min | **Silent** (user) |

So the SoC side delivers audio to both I2S ports, and the speaker amp doesn't play what tertiary MI2S sends it.

What it isn't, from an I2C scan (`i2cdetect -r`) checked against the DSDT's decoded `I2cSerialBus` resources (most are raw `Buffer`s): no amplifier is declared on any bus. The unclaimed devices that answer are the EC (`EMEC` at `0x14`, `0x33` on `888000` and `a84000`, `0x09`/`0x0b` battery and charger on `890000`) and the EC touchpad (`ECTC`, `0x62` on `a84000`). `0x60` and `0x63` on `a84000` are not in the DSDT. So the amp is driven by GPIO enables plus I2S, as modelled, and the open question is its port, data line and enable.

#### Hypotheses (not yet tested)

- The amp listens on another data line or port: tertiary sd line 1 (TLMM 66), or primary sd line 0 (TLMM 55). Each needs a DTB change and a test boot.
- The two `AUDD` enables (TLMM 20 and 21) are left and right amps. Both already read high, so the enable alone doesn't explain the silence.
- Samsung's Windows audio packages (the `SAMM0811`/`SAMM0813` children of `AUDD`, and the Qualcomm audio driver) record the port layout. They are in `GBGo-Drivers/` on the PNY `WIN11ARM` stick ([win11-stick/README.md](win11-stick/README.md)), not on this machine.

The DSDT was rebuilt into `acpi-local/` from `/root/gbgo-efishell-20261011-124435/gbgo-shell/acpi/mem.txt` (the earlier copy had been lost).

### Samsung's Windows audio config (14:25)

From the drivers harvested onto the PNY stick (`GBGo-Drivers/`, copied to the git-ignored `firmware-local/win-audio/`):

- `qcauddev_sec7180.inf` (`ADCM\VEN_SAMM&DEV_0812&SUBSYS_C199144D`): `ExternalSpeakerCodec = 0` for speaker device `0x45` (a plain I2S amp, no codec), `ExternalHeadsetCodec = 1` for `0x0A`/`0x08` (the RT5682). The speaker's power sequence enables PEP component `0x0B`, then sets **both** `AUDD` GPIOs (index 0 = TLMM 21, index 1 = TLMM 20). Both read high here already.
- `qcacsp_ss7180` holds the ACDB (`Speaker_cal.acdb`, `Headset_cal.acdb`, …, `QCMSNDDB` chunk files; `workspaceFile.qwsp` is encrypted). `DPROPLUT` maps device, property and `DATAPOOL` offset; property `0x113b7` is the device's port record:

| Device | Name | Port | Fields after the port |
|---|---|---|---|
| `0x45` | `SPEAKER_OUT` | `0x1004` TERTIARY_MI2S_RX | `2 1 1 3 2 0 100 1 0` |
| `0x0a` | `HEADSET_SPKR_STEREO` | `0x1000` PRIMARY_MI2S_RX | `2 1 1 3 2 0 500 1 0` |
| `0x09` | `HEADSET_SPKR_MONO` | `0x1000` PRIMARY_MI2S_RX | `1 0 1 1 1 0 100 1 0` |
| `0x08` | `HEADSET_MIC` | `0x1007` **QUATERNARY_MI2S_TX** | `1 1 1 1 1 0 100 2 0` |

The ports in the audio DTB are right for playback. The speaker's I2S fields equal the headset's, while the DTB had primary RX on sd line 1 and tertiary RX on sd line 0 (the Aspire 1's). The field meanings are not decoded; the inference is "same config as primary", i.e. sd line 1. The headset mic is on quaternary MI2S, not primary TX as in the DTB.

### Third test boot armed (14:28)

- [scripts/gbgo-dtb-audio.py](scripts/gbgo-dtb-audio.py): `dai@20` (tertiary RX) `qcom,sd-lines` `<0>` → `<1>`. The rebuilt DTB differs from the second test DTB by that one line.
- `/boot/dtb/sc7180-samsung-galaxy-book-go.dtb.test` = `dcec14ea0cd6c37b…`, same on the raw disk. The previous one is `….test.sd0` (`e69a154a6b31eb65…`). `gbgo-boot-verify`: all checks pass.
- `grub-reboot gbgo-dtbtest-7.2.9+deb14-arm64` set.

Expected: speaker data on TLMM 66 and sound from the speakers. After boot: `wpctl set-profile <card> 1` (Pro Audio), then `sudo /usr/local/sbin/gbgo-audio-check play`. Untested.

### Third test boot (14:39): data on TLMM 66, still silent

The DTB with tertiary RX on sd line 1 is booted (`dai@20` `qcom,sd-lines = <0x01>` in `/proc/device-tree`). Card 0 up, PipeWire on `Built-in Audio Pro`, Chrome playing YouTube into it with `TERT_MI2S_RX Audio Mixer MultiMedia1` on.

| Pin (tertiary MI2S) | High, of 200 reads |
|---|---|
| 63 clock | 107 |
| 64 word select | 109 |
| 65 sd line 0 | 0 |
| 66 sd line 1 | 86 |

So the speaker data now goes out on the line Samsung's config implies, and the speakers stay silent (user).

The supply: of `AUDD`'s PEP components (`\_SB.PEP0.APCC`), only two carry power resources: component 1 votes `PPP_RESOURCE_ID_BUCK_BOOST1_C` (PM6150L BOB) on at `0x324B00` = 3.296 V, component 2 votes `LDO15_A` 1.8 V (the RT5682's). Component `0x0B`, which the speaker's power sequence enables, has no resources. In Linux `bob` has no consumer (`use 0`, 3032 mV, state `unknown`), so the AP never votes it on. The amp running off BOB is the hypothesis.

PipeWire opens `hw:0,0` as 8 channels `S24_LE`, quantum 1024 at 48 kHz, no errors in the user journal. YouTube stutter in the same session: the Chrome renderer at 81 % CPU (software video decode), 528 MiB available, 1.4 GiB in swap. Not audio.

### Fourth test boot armed (15:27)

- [scripts/gbgo-dtb-audio.py](scripts/gbgo-dtb-audio.py): `bob` gets `regulator-always-on`, `regulator-boot-on` and `regulator-min-microvolt` 3296000 (max stays 3960000). The DTB differs from the third test DTB by those three properties.
- `/boot/dtb/sc7180-samsung-galaxy-book-go.dtb.test` = `d5ce6f87d7a1058d…`, same on the raw disk. The third one is `….test.sd1` (`dcec14ea0cd6c37b…`). `gbgo-boot-verify`: all checks pass. `grub-reboot gbgo-dtbtest-7.2.9+deb14-arm64` set.

Expected: `bob` state `enabled` at 3296 mV, sound from the speakers with tertiary routed. Untested.

### Fourth test boot (15:34): speakers play 16-bit audio

`bob` is `enabled` at 3320 mV (the step above 3296 mV), `use 1`.

| Stream to tertiary MI2S | Speakers (user) |
|---|---|
| PipeWire, `hw:0,0` 8 ch `S24_LE`, 440 Hz tone, 10 s and 30 s | silent |
| `speaker-test -D hw:0,1 -c 2 -F S16_LE`, MultiMedia2 routed to tertiary | **tone heard** |
| `-F S32_LE` | refused by the PCM (`Sample format not available`) |

So the amp plays 16-bit stereo and stays silent on the 8-channel 24-bit stream. Whether BOB is needed as well is not tested: the 16-bit stream was never played with BOB off.

Fix, 16:59:

- [system/wireplumber/51-gbgo-audio.conf](system/wireplumber/51-gbgo-audio.conf) → `/etc/wireplumber/wireplumber.conf.d/`: card profile `pro-audio`, and the output node opened as `S16LE`, 2 channels, `FL FR`, named `Speakers`. After restarting PipeWire and WirePlumber, `hw_params` reads `S16_LE`, 2 channels, and a tone through the default sink plays from the speakers (user).
- `TERT_MI2S_RX Audio Mixer MultiMedia1` on, saved with `alsactl store` (`alsa-restore.service` restores it). Verified across a reboot (17:13).

Default, 17:12: `/boot/dtb/sc7180-samsung-galaxy-book-go.dtb` = the audio DTB (`d5ce6f87d7a1058d…`), same on the raw disk; the previous default is `….dtb.noaudio` (`8012d6d42635b0e3…`). `gbgo-boot-verify`: all checks pass. The 6.12 entries use the same DTB, and their initrds have no ADSP firmware, so the ADSP stays offline there. **Booting the audio DTB on 6.12 is not yet verified.** Recovery: pick a 6.12 entry or edit the entry's `devicetree` line to `….dtb.noaudio` in GRUB.

### First default boot (17:13)

Kernel 7.2.9 on the audio DTB as the default entry: `adsp` up at 7.8 s from the initramfs, BOB `enabled` at 3320 mV (`use 1`), card 0 `SamsungGalaxyBo`, `TERT_MI2S_RX Audio Mixer MultiMedia1` restored `on`, PipeWire's default sink `Speakers`. Sound from the speakers after the reboot (user, 17:30).

Still open: headphones (RT5682 on primary MI2S, `HPOL`/`HPOR` muted by default), the internal mic (quaternary MI2S TX per Samsung's ACDB; the DTB has primary TX), and whether BOB is needed.

## Video decode (17:20)

Venus decodes H.264, VP8, VP9, HEVC and MPEG-2 (`v4l2-ctl --list-formats-out` on `/dev/video0`) and encodes H.264, VP8 and HEVC. No VA-API driver exists for it: `vainfo` tries `msm_drv_video.so` and fails (`vaInitialize failed`).

ffmpeg 9.0.2, 20 s of 1080p30 test pattern (600 frames), Chrome running alongside:

| Clip | Decoder | Wall | User CPU |
|---|---|---|---|
| H.264 6 Mb/s | `h264` (software) | 2.42 s | 11.62 s |
| H.264 6 Mb/s | `h264_v4l2m2m` (Venus) | 7.42 s | 0.43 s |
| VP9 4 Mb/s | `vp9` (software) | 2.92 s | 10.85 s |
| VP9 4 Mb/s | `vp9_v4l2m2m` (Venus) | 7.56 s | 0.45 s |

Venus runs at about 80 frames a second here, at about 1/25 of the CPU.

| Player | Uses Venus? | Seen |
|---|---|---|
| mpv 0.41 `--hwdec=v4l2m2m-copy` + yt-dlp | **yes** | `Using hardware decoding (v4l2m2m-copy)`. YouTube 1080p60 H.264, 720p60 H.264 and 1080p60 VP9, 20 s each, `--vo=null`: 0 dropped frames, about 5.2 s user + 2.2–2.5 s sys per run including yt-dlp. On screen not yet measured |
| Google Chrome 155, Chromium 154 | no | Neither opens `/dev/video0` (`fuser`), with or without `--enable-features=AcceleratedVideoDecodeLinuxGL,VaapiVideoDecoder,UseChromeOSDirectVideoDecoder,V4L2FlatStatefulVideoDecoder`. Linux Chrome's hardware path is VA-API, which has no driver here |
| Firefox ESR 153, `media.hardware-video-decoding.force-enabled` | starts, then falls back | `MOZ_LOG`: `V4L2 FFmpeg init successful` with `h264_v4l2m2m`, one frame out with `pts=-9223372036854775808` (no timestamp), then `FFmpeg decoder rejects requested type 'video/avc'` and the software decoder. Cause not investigated |

So YouTube in a browser decodes in software: the Chrome renderer at 47–81 % CPU, with 854 MiB available and 2.1 GiB in zram during the test. Smoothest route measured: `mpv --hwdec=v4l2m2m-copy <youtube url>`. In a browser, H.264 costs the software decoder less than VP9 or AV1 (not measured here).

## Other drivers that misbehave (17:17 boot)

| Driver | Seen | State |
|---|---|---|
| `ti_sn65dsi86` (display bridge) | `irq 147: nobody cared`, IRQ on TLMM 11 disabled after 100,001 interrupts; `Failed to read IRQ status: -6`; `geni_i2c 880000.i2c: Bus arbitration lost` on its bus | Fixed 17:41: see "Display bridge IRQ" |
| `ath10k_snoc` | `chan info: invalid frequency 0 (idx 41 out of bounds)`, twice per boot; `invalid MAC address; choosing random` | Wi-Fi works. The MAC changes every boot |
| `qcom-qmp-combo-phy` | `unable to determine orientation & mode from data-lanes` | USB-C needs the device plugged at boot (no UCSI node) |
| `rt5682` | `supply VBAT/MICVDD not found, using dummy regulator` | Probes; headphones untested |

Missing from the draft DTB: battery and charger, brightness (no backlight device), camera. Battery and camera found 17:45; see below.

## Display bridge IRQ (fixed, default 17:41)

The draft keeps the Aspire 1's bridge interrupt: `ti,sn65dsi86` on `tlmm 11`, `IRQ_TYPE_LEVEL_HIGH`, with pin config `edp-bridge-irq-default-state` (pull-down). On this board GPIO 11 reads `in high` with that pull-down, so the level interrupt never clears and the kernel disables it at every boot (`irq 147: nobody cared`, 100,001 counts). Samsung's DSDT has no GPIO interrupt for the bridge: the only GPIO descriptors near the display are `MON0` `GpioIo` 36 (`acpi-gpioint.py`). The panel has run with the IRQ disabled since the first boot.

Fix 5 in [scripts/gbgo-dtb-patch](scripts/gbgo-dtb-patch): the bridge node loses `interrupt-parent`, `interrupts` and the IRQ pin config from `pinctrl-0`. The rebuilt default chain (`gbgo-dtb-patch` on `.dtb.orig`, then `gbgo-dtb-audio.py`) reproduces the current default byte for byte without fix 5 (`d5ce6f87d7a1058d…`); with it, the DTB differs by those three lines only.

- `/boot/dtb/sc7180-samsung-galaxy-book-go.dtb.test` = `a547e6a4bf115e62…`, same on the raw disk. `gbgo-boot-verify`: all checks pass. `grub-reboot gbgo-dtbtest-7.2.9+deb14-arm64` set.
- Test boot (17:35): no `interrupts` in the bridge node (`/proc/device-tree`), no `0-002c` line in `/proc/interrupts`, 0 `nobody cared`, 0 `Failed to read IRQ status`, 0 `geni_i2c 880000.i2c` lines. The panel probes (`AUO B140HTN02.0`), eDP `connected`, `running`. Kernel warnings at `-p warning`: 62 on the previous boot, 26 on this one. ADSP `running`, `Speakers` sink present.
- Default, 17:41: `/boot/dtb/sc7180-samsung-galaxy-book-go.dtb` = `a547e6a4bf115e62…`, same on the raw disk; the previous default is `….dtb.bridgeirq` (`d5ce6f87d7a1058d…`). `gbgo-boot-verify`: all checks pass. Not yet booted as the default.

## Battery (found live 17:45)

The EC's smart battery gauge answers at `0x0b` on `i2c@890000` (`i2c-4`); the DSDT's `EMEC` lists I2C resources to `0x09` and `0x0b` there. SBS word registers read with `i2cget -y 4 0x0b <reg> w`: temperature `0x0ba0` (24.5 °C), voltage `0x1da6` (7590 mV), current 0, relative charge `0x1b` (27 %), remaining `0x059b` (1435 mAh), full `0x1504` (5380 mAh), design `0x14c8` (5320 mAh), design voltage `0x1e28` (7720 mV), cycles 8. Block reads fail (`Adapter does not have SMBus block read capability`). `0x09` answers `0xffff` to the SBS charger registers.

`echo sbs-battery 0x0b > /sys/bus/i2c/devices/i2c-4/new_device` binds `sbs-battery` (`I2C adapter does not support I2C_FUNC_SMBUS_READ_BLOCK_DATA`, then it falls back): `sbs-4-000b`, `CAPACITY=27`, `MANUFACTURER=SDI`, `MODEL_NAME=4432D53`, manufactured 2021-07-09, `STATUS=Not charging`. UPower lists `battery_sbs_4_000b`, `pending-charge`, 27 %. Whether the charger was connected at the time was not recorded. No AC adapter device exists.

Fix 6 in [scripts/gbgo-dtb-patch](scripts/gbgo-dtb-patch): `battery@b`, `sbs,sbs-battery`, under `i2c@890000`. In the test DTB armed at 17:49, untested from the DTB.

## Camera (found live 17:47)

The DSDT puts `ICAM` at `_ADR 4` under the internal USB hub `EHUB` (`USB0.RHUB.PRT1.EHUB`, the `0424:2514` hub). `EHUB._PS0` sets `\_SB.GIO0.CAME = One`, `_PS4` sets it to zero. `CAME` is a `GpioIo` field, output only, on `GIO0` pin `0x0D` = **TLMM 13**. The boot firmware leaves GPIO 13 `out low`, and hub port 4 reads `not attached`.

`gpioset -c gpiochip0 13=1`: `usb 1-1.4: Product: 720p HD Camera`, `Manufacturer: Chicony`, `04f2:b72f`, `uvcvideo` binds, `/dev/video2` and `/dev/video3` (Venus keeps `video0` and `video1`). YUYV up to 1280x720, MJPG. ffmpeg captured a 1280x720 frame from `/dev/video2`.

Fix 7 in [scripts/gbgo-dtb-patch](scripts/gbgo-dtb-patch): a `gpio-hog` under the TLMM node holds GPIO 13 high from boot (`camera-power`). The camera stays powered whenever the system is up; its draw is not measured. In the test DTB armed at 17:49, untested from the DTB.

## Test boot armed (17:49): battery, camera, backlight

`/boot/dtb/sc7180-samsung-galaxy-book-go.dtb.test` = `GBGO_BACKLIGHT=1 gbgo-dtb-patch` on `.dtb.orig`, then `gbgo-dtb-audio.py`: `edbc2a9eeae7e0e4…`, same on the raw disk. It adds to the default: fix 6 (battery), fix 7 (camera hog), and the untested backlight (PM6150L LPG enabled, `pwm-backlight` on LPG3). `gbgo-boot-verify`: all checks pass. `grub-reboot gbgo-dtbtest-7.2.9+deb14-arm64` set.

Expected: `/sys/class/power_supply/sbs-4-000b`, the camera on `1-1.4`, `/sys/class/backlight/backlight` with the screen still lit. Untested. If the backlight takes the wrong channel the screen can go dark; the next power cycle boots the default.

### Test boot (17:49): battery, camera and backlight devices all present

- Battery: `battery@b` in `/proc/device-tree`, `sbs-4-000b` registered, capacity 30 % (27 % at 17:45), UPower `pending-charge`. 3 `driver failed to report 'charge_full'/'energy_full' property: -6` in the first minute, none in the next 20 s. **Charge state is wrong**: `CURRENT_NOW` (SBS `0x0a`) reads 0 on every read and `BatteryStatus` reads `0x00c0` (initialized, discharging), so the status is `Not charging` while the charge rose from 27 % to 30 %. `AverageCurrent` (`0x0b`) reads `0x0029`…`0x0024` (41…36 mA). No AC adapter device.
- Camera: `1-1.4` Chicony `04f2:b72f` enumerated at boot, `uvcvideo` bound, runtime-suspended while idle.
- Backlight: `/sys/class/backlight/backlight`, `max_brightness` 4095, brightness 2048. The screen is lit. Whether brightness changes the screen: not yet checked by eye.
- 31 kernel warnings at `-p warning` (26 on the default DTB). `running`, no failed units.

## Brightness (in progress, 13:20)

No `/sys/class/backlight`. Findings:

- The panel (`edp-panel` behind the SN65DSI86 bridge) has **no AUX backlight**: DPCD `0x701 = 0x18` (self-test caps only), `0x702 = 0`.
- Samsung's panel config (`GPU0._ROM`, XML, local in `acpi-local/panelcfg.xml`): `BacklightType 1`, `BacklightPmicControlType 3`, `BacklightPmicNum 2`, `BacklightPMICBankSelect 0`, 9-bit PWM at 6250 Hz, default 80 %. Its `DSIInitSequence` also programs the bridge's PWM (`0x5F = 0x80`, `0xA5 = 0x02`).
- **Bridge PWM: tested live, no effect.** `pwmchip0` is `ti_sn65dsi86.pwm`; driving it at 100/20/100/50/100 % and 100/10/100 % (registers then match Windows' sequence) left the screen unchanged.
- **PMIC LPG: the likely one.** PM6150L `gpio6` is the only PM6150L pin the firmware leaves in a special function (`out func1`), and of the PM6150L LPG channels only **LPG3** (`0xb300`) is running: enable `0x86` (output on, PWM source), value `0x1FF` = 100 % of 9 bits. The draft DTB disables the LPG (`qcom,pm6150l-lpg`), so Linux can't change it.
- Next: `GBGO_BACKLIGHT=1 gbgo-dtb-patch` enables the LPG and adds `pwm-backlight` on channel index 2 (LPG3) at 160000 ns, not linked to the panel. **Untested**; a one-time test boot was armed and then disarmed for the sid upgrade.

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
