# C630 Wi-Fi

`wlan0` is the WCN3990 (`ath10k_snoc`, firmware `WLAN.HL.2.1-01288`, api 5). It needs the modem remoteproc running (see [FIRMWARE.md](FIRMWARE.md)). First connected on 2026-10-10, on a Starbucks hotspot.

## Problem: 5 GHz association refused (regdomain `00`)

At boot the regulatory domain is the world default:

```
$ cat /sys/module/cfg80211/parameters/ieee80211_regdom
00
```

NetworkManager picked the strongest BSS for the SSID, which was on **channel 112 (5560 MHz, a DFS channel)**. The AP refused the association, then stopped answering authentication:

```
wlan0: RX AssocResp from ae:17:d8:07:9a:8d (capab=0x1501 status=18 aid=1388)
wlan0: ae:17:d8:07:9a:8d denied association (code=18)
wlan0: send auth to ae:17:d8:07:9a:8d (try 3/3)
wlan0: authentication with ae:17:d8:07:9a:8d timed out
```

Status 18 means "station doesn't support the BSS's basic rates". With world regdomain, DFS channels are no-initiate-radiation and the capabilities the radio advertises there are restricted. The same SSID on 2.4 GHz connected immediately.

## Fixes

1. **Pin the profile to 2.4 GHz**. This works right away:
   ```sh
   nmcli con modify "Starbucks WiFi" 802-11-wireless.band bg
   ```
   To undo it: `802-11-wireless.band ""`. Better for 5 GHz is to pin a non-DFS BSS (channel 36–48 or 149–165) with `802-11-wireless.bssid`.

2. **Make the US regdomain permanent.** `cfg80211` is a module (`kernel/net/wireless/cfg80211.ko.xz`), not built in and not in the initramfs, so a modprobe option is enough and the initramfs doesn't need rebuilding:
   ```sh
   sudo cp system/regdom.conf /etc/modprobe.d/regdom.conf   # options cfg80211 ieee80211_regdom=US
   /usr/sbin/modprobe -c | grep ieee80211_regdom          # check it's parsed
   ```
   This takes effect from the next boot. Within a session, the kernel also picks up `US` from the AP's country element once associated (`iw reg get` → `country US: DFS-FCC`). **Not yet verified across a reboot.**

## Captive portals

The Starbucks portal is a Meraki splash page (`na.network-auth.com/splash/...`). Any plain-HTTP request returns a `307` to it:

```sh
curl -s --interface wlan0 -o /dev/null -w '%{http_code} %{redirect_url}\n' http://neverssl.com/
```

**Watch for the USB tether.** When the iPhone is USB-tethered (`enx…`, 172.20.10.0/28), its default route has metric 100, compared with 20600 for `wlan0`. The browser and the connectivity check use the tether, so the portal never appears. Unplug it (or `nmcli con down "Wired connection 1"`), then open `http://neverssl.com` and accept.

## Gotchas

- `iw` is installed but lives in `/usr/sbin`, which isn't on the user `PATH`. Call it as `/usr/sbin/iw`.
- The MAC is random each boot (`ath10k_snoc 18800000.wifi: invalid MAC address; choosing random`), and NetworkManager also randomizes per connection. Captive-portal logins won't survive a reboot until this is fixed.
- `pre-cal-snoc-…` / `cal-snoc-18800000.wifi.bin` load failures are harmless (see [HARDWARE.md](HARDWARE.md)).
