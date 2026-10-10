# C630 recovery runbook

For a C630 that won't boot. The goal is to type as little as possible on the laptop itself.

## 0. First try the menu

At the GRUB menu (10 s timeout):
- the `verbose debug` entry of a kernel shows where it stops. Photograph the last screenful.
- **CONTROL** boots the installer stick's kernel and installer from the disk. If CONTROL reaches the language screen, the boot loader and DTB are fine, and the problem is the kernel or initramfs of the entry that failed.

If the screen is black **instantly**, with no text even in a verbose entry, suspect the boot loader. That's what happened in [INCIDENT-2026-10-10](INCIDENT-2026-10-10.md).

## 1. Get a shell over SSH

1. Boot the installer stick and choose **Lenovo Yoga C630 - Rescue: fix GRUB on installed Debian**.
2. Choose the root filesystem (`a81deabf-…`, the 106.7G ext4 partition) and **Execute a shell in** it.
3. On the laptop, type:
   ```
   mkdir /run/sshd
   /usr/sbin/sshd
   ```
4. From the yoga9i: `ssh -i ~/.ssh/google_compute_engine xbill@192.168.0.65` (the rescue system's address; the installed system uses .66). The host key is the laptop's own, so there's no warning.

Notes:
- Running `ssh-copy-id` from Claude Code's `!` prompt fails because it has no TTY for the password. Run it in a real terminal.
- Under the installer kernel the disk is `sda`, so partitions are `sda1`, `sda2`, … Use UUIDs.
- `efibootmgr` reports "EFI variables are not supported". That's normal on this machine.

## 2. Before rebooting out of rescue

- Make sure every file the boot needs actually reached the disk. GRUB can't replay the ext4 journal:
  ```
  sync; sudo sh -c 'fsfreeze -f / && fsfreeze -u /'
  sudo debugfs -R 'stat /boot/grub/c630.cfg' /dev/sda3     # raw-disk view, as GRUB sees it
  ```
- `sudo grub-script-check /boot/grub/c630.cfg`
- Stop the SSH listener so it doesn't block the unmount: `sudo kill $(cat /run/sshd.pid)` (your session survives until you log out).
- `exit` the shell, choose **Reboot the system**, and pull the stick when the screen goes dark.

## 3. Put back the known-working boot loader

If sid's GRUB has been reinstalled (holds removed, or a manual `grub-install`), put the stick's back:

```sh
# from this repo, copy stick/ to the laptop's /tmp/stickboot, plus the stick's vmlinuz/initrd.gz if CONTROL is wanted
sudo sh /tmp/stickboot/apply.sh     # scripts/apply.sh: backs up /boot/efi first, then installs shim + GRUB 2.12 on both ESPs
sudo c630-menu
```

The stick's own `efi.img` (inside the ISO) is what the firmware boots from the stick. Editing the stick's partition 2 changes nothing.

## 4. Full restore of the boot partitions

`backups/c630-2026-10-10/boot/efi/` is the working ESP as of 2026-10-10. Copy it over `/boot/efi/` (vfat) from rescue.
