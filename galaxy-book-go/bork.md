 your external USB keyboard and mouse are completely dead too, you are stuck because generic Windows installation environments (WinPE) do not have the basic Qualcomm USB-host controller and I2C drivers built-in for this laptop.
Since you have absolutely no way to send input to the screen right now, you have two options to fix this:

Option 1: Use the Community Pre-Injected ISO (Easiest)

Members of the Galaxy Book community ran into this exact roadblock and built custom Windows installer images that have the official Qualcomm chipset, USB, keyboard, and trackpad drivers already baked directly into the installation files (boot.wim and install.wim).
1. On a working computer, go to the Galaxy Book Go Windows ARM Recovery Reddit Thread.
2. Download the custom Samsung Recovery or Windows 11 image provided by the community for the Galaxy Book Go.
3. Download the official flashing tool Rufus.
4. Insert a USB drive, open Rufus, select your downloaded disk image, keep all settings at default, and click Start.
5. Plug this newly created USB drive into the USB-C port of your Galaxy Book Go (the device specifically prefers booting from its USB-C slots).
6. Turn it on, tap F2 to enter BIOS, disable Secure Boot, save and exit.
7. Boot up tapping F10 repeatedly, choose your USB drive, and your built-in keyboard and trackpad will instantly start working on the Windows install screen.

Option 2: Manually Inject Drivers via Command Prompt (Advanced)

If you already have a standard Windows ARM64 USB installer plugged in, you can try to force-inject the missing driver package using another flash drive and Windows' deployment tools.
1. Download the Samsung Galaxy Book Go Qualcomm Driver Pack from the Internet Archive on another PC.
2. Extract the driver folder onto a second USB flash drive formatted as FAT32 or NTFS.
3. Plug both your Windows installation USB and your driver USB into the Galaxy Book Go (you will need a USB hub).
4. Boot into your frozen Windows installation screen. Since your keyboard doesn't work, you will have to crash-boot the laptop 3 times using the power button until it forces itself into the Windows Recovery Environment (Advanced Troubleshooting).
5. If you can navigate into Troubleshoot > Advanced Options > Command Prompt, type the following command to find your driver USB letter (e.g., E: or F:):cmd
diskpart
list volume
exit
Use code with caution.
6. Force-install the driver package dynamically into your active Windows setup session using DISM:cmd
dism /image:X:\ /add-driver /driver:E:\ /recurse
Use code with caution.
(Replace X:\ with your target operating system drive letter and E:\ with your USB driver folder letter).
7. Restart the machine, and the setup environment will pick up the controllers and light up your inputs.
Do you have access to another working computer and a spare USB flash drive right now to build the community recovery image? Let me know so we can walk through Option 1 step-by-step!

