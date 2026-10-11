#!/usr/bin/env python3
# List every GpioInt/GpioIo descriptor in a decompiled DSDT (including the raw
# RBUF byte buffers Qualcomm DSDTs use), with device, flags and pin.
# Usage: python3 -I acpi-gpioint.py dsdt.dsl
import re, sys
# Find every GpioInt/GpioIo descriptor (0x8C) in RBUF byte dumps and in decoded GpioInt() macros.
txt = open(sys.argv[1]).read()
dev = None; out = []
lines = txt.splitlines()
for i, l in enumerate(lines):
    m = re.search(r'Device \((\w+)\)', l)
    if m: dev = m.group(1)
    if re.search(r'GpioInt|GpioIo', l):
        blk = ' '.join(x.strip() for x in lines[i:i+8])
        pins = re.findall(r'\{\s*//\s*Pin list\s*(0x[0-9A-Fa-f]+)', blk) or re.findall(r'Pin list\s*(0x[0-9A-Fa-f]+)', blk)
        out.append((dev, 'macro', l.strip()[:60], pins))
    if 'Name (RBUF, Buffer' in l or re.search(r'Name \(\w+, Buffer \(0x', l):
        hexb = []
        for k in range(i+1, min(i+40, len(lines))):
            if '})' in lines[k]: break
            hexb += re.findall(r'0x([0-9A-Fa-f]{2})', lines[k].split('//')[0])
        b = bytes(int(x,16) for x in hexb)
        j = 0
        while j < len(b) - 3:
            if b[j] == 0x8C:
                ln = b[j+1] | b[j+2]<<8
                d = b[j:j+3+ln]
                if len(d) >= 0x17:
                    typ = d[4]; iflags = d[7]|d[8]<<8; ppull = d[9]
                    pto = d[14]|d[15]<<8; rso = d[17]|d[18]<<8
                    pin = d[pto]|d[pto+1]<<8 if pto+1 < len(d) else None
                    src = d[rso:].split(b'\0')[0].decode('ascii','replace') if rso < len(d) else '?'
                    out.append((dev, 'GpioInt' if typ==0 else 'GpioIo', f"flags=0x{iflags:02x} pull={ppull} src={src}", [hex(pin) if pin is not None else '?']))
                j += 3 + ln
            else:
                j += 1
for o in out: print(o)
