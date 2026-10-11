#!/usr/bin/env python3
# Rebuild memory from a UEFI-shell "dmem ADDR LEN > mem.txt" dump (UTF-16 hex text)
# and extract every ACPI table reachable from the RSDP at 0xffffd000 into tables/.
# Usage: python3 -I acpi-from-dmem.py mem.txt mem.bin   (then: iasl -d tables/dsdt.dat)
import re, struct, sys
src, out = sys.argv[1], sys.argv[2]
txt = open(src, 'rb').read().decode('utf-16-le', errors='replace')
base = None; data = {}
for line in txt.splitlines():
    m = re.match(r'\s*([0-9A-Fa-f]{8,16}):\s+((?:[0-9A-Fa-f]{2}[ -]){15}[0-9A-Fa-f]{2})', line)
    if not m: continue
    a = int(m.group(1), 16); bs = bytes(int(x, 16) for x in re.split(r'[ -]', m.group(2)))
    data[a] = bs
    base = a if base is None else min(base, a)
end = max(data) + 16
buf = bytearray(end - base)
for a, bs in data.items(): buf[a-base:a-base+16] = bs
open(out, 'wb').write(buf)
print(f"base=0x{base:x} size=0x{len(buf):x} lines={len(data)}")
def rd(addr, n):
    o = addr - base
    if o < 0 or o + n > len(buf): return None
    return bytes(buf[o:o+n])
rsdp = rd(0xffffd000, 36)
print("RSDP sig:", rsdp[:8], "rev", rsdp[15])
xsdt = struct.unpack_from('<Q', rsdp, 24)[0]; print(f"XSDT @0x{xsdt:x}")
h = rd(xsdt, 36); ln = struct.unpack_from('<I', h, 4)[0]
x = rd(xsdt, ln); ptrs = [struct.unpack_from('<Q', x, 36+8*i)[0] for i in range((ln-36)//8)]
import os
os.makedirs('tables', exist_ok=True)
for p in ptrs:
    th = rd(p, 8)
    if th is None: print(f"  0x{p:x}: OUTSIDE dump"); continue
    sig = th[:4].decode('ascii','replace'); tl = struct.unpack_from('<I', th, 4)[0]
    t = rd(p, tl); print(f"  {sig} @0x{p:x} len={tl} {'OK' if t else 'TRUNCATED'}")
    if t:
        n = sig.lower(); i = 0
        while os.path.exists(f"tables/{n}{i or ''}.dat"): i += 1
        open(f"tables/{n}{i or ''}.dat", 'wb').write(t)
        if sig == 'FACP':
            dsdt = struct.unpack_from('<Q', t, 140)[0] if tl >= 148 else 0
            dsdt = dsdt or struct.unpack_from('<I', t, 40)[0]
            dh = rd(dsdt, 8)
            if dh:
                dl = struct.unpack_from('<I', dh, 4)[0]; d = rd(dsdt, dl)
                print(f"  DSDT @0x{dsdt:x} len={dl} {'OK' if d else 'TRUNCATED'}")
                if d: open('tables/dsdt.dat', 'wb').write(d)
            else: print(f"  DSDT @0x{dsdt:x} OUTSIDE dump")
