import sys

f = sys.argv[1]
p = "clk_ignore_unused pd_ignore_unused regulator_ignore_unused usbcore.autosuspend=-1 ignore_loglevel earlycon=efifb keep_bootcon"
r = "root=UUID=a81deabf-0654-4f68-b795-284305d26f13 ro"
find = "    search --no-floppy --fs-uuid --set=hd a81deabf-0654-4f68-b795-284305d26f13\n    devicetree ($dtbroot)/c630.dtb\n"
k = "($hd)/boot/vmlinuz-6.12.107+deb13-arm64"
i = "($hd)/boot/initrd.img-6.12.107+deb13-arm64"

add = f"""
menuentry 'DISK TEST 1: installed 6.12.107 via USB GRUB (verbose)' {{
{find}    linux    {k} {r} {p}
    initrd   {i}
}}
menuentry 'DISK TEST 2: installed 6.12.107 kernel, NO initramfs (expect root-mount panic)' {{
{find}    linux    {k} {r} {p}
}}
menuentry 'DISK TEST 3: installer kernel + installed 6.12.107 initramfs' {{
{find}    linux    /install.a64/vmlinuz {r} {p}
    initrd   {i}
}}
"""

s = open(f).read()
anchor = "set timeout=10\n"
assert anchor in s and "DISK TEST" not in s
open(f, "w").write(s.replace(anchor, anchor + add, 1))
