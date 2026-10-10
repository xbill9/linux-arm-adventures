---
name: record
description: Record a finding, test result or change made to a machine into this repo's docs (topic doc + dated LOG.md entry), then commit and push. Use after anything worth keeping happens on the C630 (or another machine here), or when the user says "write that up", "log it", "note that".
---

Record: $ARGUMENTS

1. **Pick the topic doc** for the substance: `c630/HARDWARE.md` (per-device state), `QUIRKS.md` (firmware/install oddities), `FIRMWARE.md`, `MODEM.md`, `WIFI.md`, `RECOVERY.md` (procedures), `README.md` (current boot chain, kernels, disk layout). Read the relevant section first and edit it in place. Update stale statements rather than appending contradictions. Only start a new file for a genuinely new topic or a dated one-off (`INCIDENT-YYYY-MM-DD.md`, `AUDIT-YYYY-MM-DD.md`).
2. **Mark verification state honestly.** Say what was observed and how ("confirmed on 2026-10-10 by …"). Anything inferred or not yet tried is labelled "Untested", "Not yet verified", or goes under Hypotheses.
3. **Raw evidence**: save long kernel/journal output to `c630/logs/YYYY-MM-DD-<slug>.log` and link it. Run `inxi`/`journalctl` output through `-z` or redact MACs, serials and non-LAN IPs before committing, because the repo is public.
4. **LOG.md**: get the time from `date +%H:%M`, then add `- HH:MM: **<result>** …` (or `HH:MM–HH:MM`) at the end of today's `## YYYY-MM-DD` section, creating it if needed, above `## Next`. Keep it short and link to the topic doc anchor. Add or remove `## Next` items this affects.
5. **New file?** Add it to the "Layout" block in the root `README.md`.
6. Check nothing from `c630/firmware-local/` or a kernel/initrd is staged (`git status --short`), then commit with `C630: <lowercase summary>` and push.
7. Report to the user in a few lines what was recorded where.
