@echo -off
# Galaxy Book Go: dump the memory holding the ACPI tables (RSDP at 0xffffd000,
# inside the EFI-reserved block 0xfff22000-0xffffdfff) to \EFI\gbgo-shell\acpi\mem.txt
# on the ESP, then reset. Debian's UEFI shell has no acpiview, so this uses dmem.
# Must be at the ROOT of the ESP: the shell only runs startup.nsh from there.
# The ESP is not fs0 on this machine (many FAT partitions), so find it by a marker.
echo gbgo: script start
for %a in fs0 fs1 fs2 fs3 fs4 fs5 fs6 fs7 fs8 fs9 fs10 fs11 fs12 fs13 fs14 fs15 fs16 fs17 fs18 fs19 fs20 fs21 fs22 fs23 fs24 fs25 fs26 fs27 fs28 fs29 fs30 fs31 fs32 fs33 fs34 fs35 fs36 fs37 fs38 fs39
  if exist %a:\EFI\gbgo-shell\gbgo-acpi.marker then
    echo gbgo: found marker on %a
    %a:
    cd \EFI\gbgo-shell
    if not exist acpi then
      mkdir acpi
    endif
    cd acpi
    map > map.txt
    dmem 0xFFF22000 0xDC000 > mem.txt
    echo done > done.txt
    echo gbgo: dump finished
    reset
  endif
endfor
echo gbgo: marker not found
reset
