#!/bin/sh
# Make the C630's disk boot the way the installer stick does.
# Run as root inside the rescue chroot, with the stick files in /tmp/stickboot.
set -e
S=/tmp/stickboot
U=a81deabf-0654-4f68-b795-284305d26f13
P="clk_ignore_unused pd_ignore_unused regulator_ignore_unused usbcore.autosuspend=-1"
DBG="ignore_loglevel earlycon=efifb keep_bootcon"
TS=$(date +%Y%m%d-%H%M%S)

echo "== verify stick files"
sha256sum $S/* | cut -c1-16,65-
cmp $S/c630.dtb /boot/c630-6.12.dtb && echo "stick dtb == /boot/c630-6.12.dtb"
cmp $S/vmlinuz /boot/vmlinuz-6.12.107+deb13-arm64 && echo "stick kernel == disk vmlinuz-6.12.107" || echo "stick kernel DIFFERS from disk vmlinuz-6.12.107"

echo "== /boot/c630boot"
mkdir -p /boot/c630boot
cp $S/vmlinuz $S/initrd.gz $S/c630.dtb /boot/c630boot/

echo "== /boot/grub/c630.cfg"
cat > /boot/grub/c630.cfg <<EOF
# Hand-written C630 menu, modelled on the installer stick's. Not touched by update-grub.
set default=0
set timeout=10
search --no-floppy --fs-uuid --set=root $U

menuentry "[via \$c630_from] 1: Debian 6.12.107 (disk kernel + disk initramfs, verbose)" {
    devicetree /boot/c630boot/c630.dtb
    linux  /boot/vmlinuz-6.12.107+deb13-arm64 root=UUID=$U ro $P $DBG
    initrd /boot/initrd.img-6.12.107+deb13-arm64
}
menuentry "[via \$c630_from] 2: CONTROL - stick kernel + installer (should reach the language screen)" {
    devicetree /boot/c630boot/c630.dtb
    linux  /boot/c630boot/vmlinuz rescue/enable=true --- $P
    initrd /boot/c630boot/initrd.gz
}
menuentry "[via \$c630_from] 3: Debian 6.12.107 kernel, NO initramfs (expect a root-mount panic)" {
    devicetree /boot/c630boot/c630.dtb
    linux  /boot/vmlinuz-6.12.107+deb13-arm64 root=UUID=$U ro $P $DBG
}
menuentry "[via \$c630_from] 4: full generated Debian menu" {
    configfile /boot/grub/grub.cfg
}
EOF

stub() {  # $1 = file, $2 = label
  cp -a "$1" "$1.bak-$TS" 2>/dev/null || true
  cat > "$1" <<EOF
search.fs_uuid $U root
set prefix=(\$root)'/boot/grub'
set c630_from="$2"
export c630_from
configfile \$prefix/c630.cfg
EOF
}

echo "== sda2 (/boot/efi): stick shim + GRUB 2.12, stick-style EFI/BOOT"
E=/boot/efi/EFI
mkdir -p /boot/efi-backup-$TS && cp -a $E /boot/efi-backup-$TS/
mkdir -p /boot/efi-backup-$TS/removed-from-BOOT
for f in fbaa64.efi mmaa64.efi BOOTAA64.CSV; do
  [ -f $E/BOOT/$f ] && mv $E/BOOT/$f /boot/efi-backup-$TS/removed-from-BOOT/
done
cp $S/bootaa64.efi $E/BOOT/BOOTAA64.EFI
cp $S/grubaa64.efi $E/BOOT/grubaa64.efi
cp $S/bootaa64.efi $E/debian/shimaa64.efi
cp $S/grubaa64.efi $E/debian/grubaa64.efi
stub $E/BOOT/grub.cfg "sda2 EFI/BOOT"
stub $E/debian/grub.cfg "sda2 EFI/debian"

echo "== hidden ESP (bootmgfw): already GRUB 2.12, point its menu at c630.cfg"
M=$(mktemp -d)
mount /dev/disk/by-uuid/E725-516C $M
cmp $S/grubaa64.efi $M/EFI/Microsoft/Boot/bootmgfw.efi && echo "hidden bootmgfw.efi == stick GRUB" || echo "hidden bootmgfw.efi DIFFERS from stick GRUB"
stub $M/EFI/Microsoft/Boot/grub.cfg "hidden bootmgfw"
sync; umount $M; rmdir $M

echo "== keep sid from replacing GRUB/shim again"
apt-mark hold $(dpkg-query -W -f '${Package}\n' 'grub*' 'shim*' 2>/dev/null | sort -u) >/dev/null
apt-mark showhold

sync
echo "== done"
