#!/bin/sh
# Replace X:\Drivers\load.cmd inside the Win11 ARM stick's boot.wim (index 2,
# Windows Setup) with this directory's load.cmd. Needs wimtools.
# Run with the WIN11ARM stick mounted read-write:
#   sh update-loadcmd.sh /run/media/$USER/WIN11ARM
# Backs boot.wim up next to itself first, then verifies the result.
set -e
STICK=${1:?usage: $0 <WIN11ARM mount point>}
HERE=$(cd "$(dirname "$0")" && pwd)
WIM=$STICK/sources/boot.wim
[ -f "$WIM" ] || { echo "no $WIM"; exit 1; }

# every driver load.cmd names must exist in the WIM
wimdir "$WIM" 2 --path=/Drivers | awk -F/ 'NF==3{print $3}' > /tmp/indrv.$$
grep -o 'X:\\Drivers\\[^\\]*' "$HERE/load.cmd" | sed 's/.*\\//' | sort -u | while read -r d; do
  grep -qx "$d" /tmp/indrv.$$ || { echo "not in boot.wim: $d"; rm -f /tmp/indrv.$$; exit 1; }
done
rm -f /tmp/indrv.$$

cp "$WIM" "$WIM.bak"
echo "add $HERE/load.cmd /Drivers/load.cmd" | wimupdate "$WIM" 2
mkdir -p /tmp/chk.$$
wimextract "$WIM" 2 /Drivers/load.cmd --dest-dir=/tmp/chk.$$ --no-acls >/dev/null
cmp /tmp/chk.$$/load.cmd "$HERE/load.cmd"
rm -rf /tmp/chk.$$
wimverify "$WIM"
sync
echo "OK: load.cmd updated; backup at $WIM.bak (delete it once the stick works)"
