#!/bin/sh
# Make the installed Debian on the Galaxy Book Go boot with its device tree.
# Run as root on the installed system (or in its rescue chroot), with the
# installer stick's GBGO partition mounted at $GBGO (default /mnt/stick3).
# Backs up everything it changes to /root/gbgo-backup-<time>/.
set -e
GBGO=${GBGO:-/mnt/stick3}
DEF=${1:-6.12.107+deb13-arm64}
HERE=$(cd "$(dirname "$0")" && pwd)
B=/root/gbgo-backup-$(date +%Y%m%d-%H%M%S)
mkdir -p $B
tar -C / -cf $B/boot-efi.tar boot/efi
cp -a /boot/grub/grub.cfg /etc/default/grub $B/
echo "backup: $B"

install -D -m 644 $GBGO/gbgo/sc7180-samsung-galaxy-book-go.dtb /boot/dtb/sc7180-samsung-galaxy-book-go.dtb
install -m 755 $HERE/09_galaxy-book-go /etc/grub.d/09_galaxy-book-go

G=/etc/default/grub
sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=gbgo-$DEF/; s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=10/; s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"\"/" $G
grep -q '^GRUB_TIMEOUT_STYLE=' $G || echo 'GRUB_TIMEOUT_STYLE=menu' >> $G
grep -q '^GRUB_DISABLE_OS_PROBER=' $G || echo 'GRUB_DISABLE_OS_PROBER=true' >> $G

# The stick (which boots) has no fallback loader next to shim; match it.
[ -f /boot/efi/EFI/BOOT/fbaa64.efi ] && mv /boot/efi/EFI/BOOT/fbaa64.efi $B/fbaa64.efi.from-EFI-BOOT

update-grub
grub-script-check /boot/grub/grub.cfg
grep -q -- "--id gbgo-$DEF " /boot/grub/grub.cfg || { echo "FAILED: default entry gbgo-$DEF not in grub.cfg" >&2; exit 1; }
sync
fsfreeze -f / && fsfreeze -u / || echo "fsfreeze failed (chroot?); sync done"
echo "OK: default gbgo-$DEF"
