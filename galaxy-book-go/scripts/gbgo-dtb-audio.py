#!/usr/bin/python3
"""Add audio to a Galaxy Book Go DTB: gbgo-dtb-audio.py <in.dtb> <out.dtb>

Run on the DTB gbgo-dtb-patch produced. Prints the dts diff. Sources:
  * ADSP reserved memory: Samsung's qcadsp7180.mbn loads at 0x90b00000-0x93900000
    (FIRMWARE.md); the draft reserves the Aspire 1's 0x8e400000 + 0x2800000, so
    remoteproc refused it ("segment outside memory range"). The region is grown
    to end at wlan@93900000 and keeps its start, so nothing it covered before is
    handed back to Linux.
  * Headset codec: ACPI RTK0 = 10EC5682 on IC10 (0xa8c000) at 0x1a, 400 kHz,
    GpioInt edge on virtual pin 0x100 = TLMM 43, supply LDO15_A 1.8 V (PEP).
  * Speaker amp: ACPI WSAR (SAM0609) has no bus address; AUDD drives TLMM 21 and
    20 as outputs. 20 is the display bridge regulator in this tree, so the amp
    enable is taken to be 21. Modelled as a MAX98357A, as on the Aspire 1.
  * I2S: primary MI2S for the codec, tertiary for the amp. The kernel's
    qcom,sc7180-qdsp6-sndcard driver handles exactly these two. Samsung's ACDB
    (Speaker_cal.acdb, Headset_cal.acdb in the qcacsp_ss7180 driver) confirms the
    ports: SPEAKER_OUT on 0x1004 (TERTIARY_MI2S_RX), HEADSET_SPKR_STEREO on
    0x1000 (PRIMARY_MI2S_RX), with identical I2S fields. Primary RX uses sd line 1
    (TLMM 56, measured), so tertiary RX uses sd line 1 too (TLMM 66); the Aspire
    1's sd line 0 on tertiary gave data on TLMM 65 and a silent speaker.
"""
import re, subprocess, sys, tempfile, os, shutil, atexit

src, out = sys.argv[1], sys.argv[2]
tmp = tempfile.mkdtemp()
atexit.register(shutil.rmtree, tmp, True)
dts_in = os.path.join(tmp, "in.dts")
subprocess.run(["dtc", "-q", "-I", "dtb", "-O", "dts", "-o", dts_in, src], check=True)
lines = open(dts_in).read().split("\n")
orig = list(lines)

def find(path):
    """Line index of the node's opening line and of its closing '};'."""
    stack, start = [], None
    for i, l in enumerate(lines):
        s = l.strip()
        m = re.match(r"^(?:[\w]+: )?([\w,.@+-]+|/) \{$", s)
        if m:
            stack.append((m.group(1), i))
            p = "/" + "/".join(n for n, _ in stack[1:])
            if p == path:
                start = i
        elif s == "};" and stack:
            n, j = stack.pop()
            if j == start:
                return start, i
    sys.exit(f"node not found: {path}")

def indent(i):
    return re.match(r"^\t*", lines[i]).group(0)

def prop(path, name):
    a, b = find(path)
    d = len(indent(a)) + 1
    for i in range(a + 1, b):
        if len(indent(i)) == d and re.match(rf"^\t*{re.escape(name)}( =|;)", lines[i]):
            return i
    return None

def set_prop(path, name, value):
    """value None = boolean property."""
    a, _ = find(path)
    text = indent(a) + "\t" + (f"{name};" if value is None else f"{name} = {value};")
    i = prop(path, name)
    if i is None:
        lines.insert(a + 1, text)
    else:
        lines[i] = text

def add_child(path, block):
    _, b = find(path)
    pre = indent(b) + "\t"
    lines[b:b] = [""] + [pre + l if l else l for l in block.strip("\n").split("\n")]

used = {int(h, 16) for h in re.findall(r"phandle = <(0x[0-9a-f]+)>", "\n".join(lines))}
nxt = max(used) + 1
def new_ph():
    global nxt
    nxt += 1
    return f"0x{nxt - 1:x}"

def phandle(path):
    i = prop(path, "phandle")
    if i is not None:
        return re.search(r"<(0x[0-9a-f]+)>", lines[i]).group(1)
    ph = new_ph()
    set_prop(path, "phandle", f"<{ph}>")
    return ph

TLMM = "/soc@0/pinctrl@3500000"
I2C = "/soc@0/geniqup@ac0000/i2c@a8c000"
APR = "/soc@0/remoteproc@62400000/glink-edge/apr"
AFE, ASM, ADM = APR + "/service@4/dais", APR + "/service@7/dais", APR + "/service@8/routing"
L15A = "/soc@0/rsc@18200000/regulators-0/ldo15"

# sanity: the nodes are what this script assumes
for path, needle in [(AFE, "qcom,q6afe-dais"), (ASM, "qcom,q6asm-dais"),
                     (ADM, "qcom,q6adm-routing"), (I2C, "qcom,geni-i2c")]:
    a, b = find(path)
    assert any(needle in l for l in lines[a:b]), path
i = prop(L15A, "regulator-min-microvolt")
assert i is not None and "0x1b7740" in lines[i], "ldo15 is not 1.8 V"

tlmm, l15a = phandle(TLMM), phandle(L15A)
afe, asm, adm = phandle(AFE), phandle(ASM), phandle(ADM)

# 1. ADSP reserved memory: 0x8e400000 .. 0x93900000
ri = prop("/reserved-memory/adsp@8e400000", "reg")
assert "<0x00 0x8e400000 0x00 0x2800000>" in lines[ri], lines[ri]
lines[ri] = lines[ri].replace("0x2800000>", "0x5500000>")

# 2. pin states: the MI2S ones exist in the SoC tree (checked: same pins and
#    functions as the Aspire 1); the amp enable and codec IRQ are new
pins = {}
for name, node, want in [
    ("pri", "pri-mi2s-active-state", '"gpio53", "gpio54", "gpio55", "gpio56"; function = "mi2s_0"'),
    ("mclk", "pri-mi2s-mclk-active-state", '"gpio57"; function = "lpass_ext"'),
    ("ter", "ter-mi2s-active-state", '"gpio63", "gpio64", "gpio65", "gpio66"; function = "mi2s_2"'),
]:
    a, b = find(f"{TLMM}/{node}")
    got = " ".join(l.strip() for l in lines[a + 1:b])
    assert f"pins = {want};" in got, (node, got)
    pins[name] = phandle(f"{TLMM}/{node}")
for name, node, block in [
    ("amp", "amp-sd-mode-default-state", 'pins = "gpio21";\nfunction = "gpio";\ndrive-strength = <0x10>;\nbias-disable;'),
    ("irq", "codec-irq-default-state", 'pins = "gpio43";\nfunction = "gpio";\ndrive-strength = <0x02>;\nbias-disable;'),
]:
    pins[name] = new_ph()
    body = "\n".join("\t" + l for l in block.split("\n"))
    add_child(TLMM, f"{node} {{\n{body}\n\tphandle = <{pins[name]}>;\n}};")

# 3. MI2S ports on the ADSP: primary RX/TX, tertiary RX
add_child(AFE, "dai@16 {\n\treg = <0x10>;\n\tqcom,sd-lines = <0x01>;\n};")
add_child(AFE, "dai@17 {\n\treg = <0x11>;\n\tqcom,sd-lines = <0x00>;\n};")
add_child(AFE, "dai@20 {\n\treg = <0x14>;\n\tqcom,sd-lines = <0x01>;\n};")

# 3b. front ends on the ADSP: one dai@N per MultiMedia link below. Without
#     children q6asm-dai fails ("No dais found in DT") and the card never binds.
for k in range(4):
    add_child(ASM, f"dai@{k} {{\n\treg = <0x{k:02x}>;\n}};")

# 4. headset codec on i2c@a8c000
set_prop(I2C, "status", '"okay"')
set_prop(I2C, "clock-frequency", "<0x61a80>")
codec = new_ph()
add_child(I2C, f"""codec@1a {{
\tcompatible = "realtek,rt5682i";
\treg = <0x1a>;
\t#sound-dai-cells = <0x01>;
\tinterrupt-parent = <{tlmm}>;
\tinterrupts = <0x2b 0x03>;
\tpinctrl-0 = <{pins["irq"]}>;
\tpinctrl-names = "default";
\tAVDD-supply = <{l15a}>;
\tDBVDD-supply = <{l15a}>;
\tLDO1-IN-supply = <{l15a}>;
\trealtek,jd-src = <0x01>;
\tphandle = <{codec}>;
}};""")

# 5. speaker amp and sound card, at the root
amp = new_ph()
link = lambda n, lname, cpu, codec_dai: f"""{n} {{
\tlink-name = "{lname}";
\tcpu {{
\t\tsound-dai = <{afe} {cpu}>;
\t}};
\tplatform {{
\t\tsound-dai = <{adm}>;
\t}};
\tcodec {{
\t\tsound-dai = <{codec_dai}>;
\t}};
}};"""
mm = "\n".join(f"""multimedia{k}-dai-link {{
\tlink-name = "MultiMedia{k}";
\tcpu {{
\t\tsound-dai = <{asm} 0x0{k - 1}>;
\t}};
}};""" for k in (1, 2, 3, 4))
sound = f"""sound {{
\tcompatible = "qcom,sc7180-qdsp6-sndcard";
\tmodel = "Samsung-Galaxy-Book-Go";
\tpinctrl-0 = <{pins["pri"]} {pins["mclk"]} {pins["ter"]}>;
\tpinctrl-names = "default";
\taudio-routing = "Headphone Jack", "HPOL", "Headphone Jack", "HPOR";
{mm}
{link("primary-rx-dai-link", "Primary MI2S Playback", "0x10", codec + " 0x00")}
{link("primary-tx-dai-link", "Primary MI2S Capture", "0x11", codec + " 0x00")}
{link("tertiary-rx-dai-link", "Tertiary MI2S Playback", "0x14", amp)}
}};"""
add_child("/", f"""audio-codec {{
\tcompatible = "maxim,max98357a";
\tsdmode-gpios = <{tlmm} 0x15 0x00>;
\tpinctrl-0 = <{pins["amp"]}>;
\tpinctrl-names = "default";
\t#sound-dai-cells = <0x00>;
\tphandle = <{amp}>;
}};""")
add_child("/", "\n".join(sound.split("\n")))

dts_out = os.path.join(tmp, "out.dts")
open(dts_out, "w").write("\n".join(lines))
subprocess.run(["diff", "-u", dts_in, dts_out])
subprocess.run(["dtc", "-q", "-I", "dts", "-O", "dtb", "-o", out, dts_out], check=True)
print(f"wrote {out}")
