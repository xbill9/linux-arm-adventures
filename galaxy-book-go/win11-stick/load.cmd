@echo off
title Loading Galaxy Book Go drivers (minimal + USB)...
set LOG=X:\drvload-log.txt
for %%d in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do if exist %%d:\GBGo-Drivers set LOG=%%d:\drvload-log.txt
echo ==== %DATE% %TIME% ====>>"%LOG%"
echo [pass 1] qcsmmu7180.inf_arm64_fb45a758baf0c0f3
echo [pass 1] START qcsmmu7180.inf_arm64_fb45a758baf0c0f3>>"%LOG%"
drvload X:\Drivers\qcsmmu7180.inf_arm64_fb45a758baf0c0f3\qcsmmu7180.inf >>"%LOG%" 2>&1
echo [pass 1] qcpep.wd7180.inf_arm64_8c2bf704ae20b939
echo [pass 1] START qcpep.wd7180.inf_arm64_8c2bf704ae20b939>>"%LOG%"
drvload X:\Drivers\qcpep.wd7180.inf_arm64_8c2bf704ae20b939\qcpep.wd7180.inf >>"%LOG%" 2>&1
echo [pass 1] qcscm7180.inf_arm64_c15e0d2e13cf9827
echo [pass 1] START qcscm7180.inf_arm64_c15e0d2e13cf9827>>"%LOG%"
drvload X:\Drivers\qcscm7180.inf_arm64_c15e0d2e13cf9827\qcscm7180.inf >>"%LOG%" 2>&1
echo [pass 1] qcpmic7180.inf_arm64_ab07463b3509bf1a
echo [pass 1] START qcpmic7180.inf_arm64_ab07463b3509bf1a>>"%LOG%"
drvload X:\Drivers\qcpmic7180.inf_arm64_ab07463b3509bf1a\qcpmic7180.inf >>"%LOG%" 2>&1
echo [pass 1] qcpmicgpio7180.inf_arm64_63fc9cff076ea2c3
echo [pass 1] START qcpmicgpio7180.inf_arm64_63fc9cff076ea2c3>>"%LOG%"
drvload X:\Drivers\qcpmicgpio7180.inf_arm64_63fc9cff076ea2c3\qcpmicgpio7180.inf >>"%LOG%" 2>&1
echo [pass 1] qcspmi7180.inf_arm64_757ebdaf4b2db7ed
echo [pass 1] START qcspmi7180.inf_arm64_757ebdaf4b2db7ed>>"%LOG%"
drvload X:\Drivers\qcspmi7180.inf_arm64_757ebdaf4b2db7ed\qcspmi7180.inf >>"%LOG%" 2>&1
echo [pass 1] secpmic3p.inf_arm64_201875b1619b0375
echo [pass 1] START secpmic3p.inf_arm64_201875b1619b0375>>"%LOG%"
drvload X:\Drivers\secpmic3p.inf_arm64_201875b1619b0375\secpmic3p.inf >>"%LOG%" 2>&1
echo [pass 1] qcgpi7180.inf_arm64_e9ab834b54154a9d
echo [pass 1] START qcgpi7180.inf_arm64_e9ab834b54154a9d>>"%LOG%"
drvload X:\Drivers\qcgpi7180.inf_arm64_e9ab834b54154a9d\qcgpi7180.inf >>"%LOG%" 2>&1
echo [pass 1] qcgpio7180.inf_arm64_555685db7b4d675c
echo [pass 1] START qcgpio7180.inf_arm64_555685db7b4d675c>>"%LOG%"
drvload X:\Drivers\qcgpio7180.inf_arm64_555685db7b4d675c\qcgpio7180.inf >>"%LOG%" 2>&1
echo [pass 1] qcgsi7180.inf_arm64_d224cc415fe52737
echo [pass 1] START qcgsi7180.inf_arm64_d224cc415fe52737>>"%LOG%"
drvload X:\Drivers\qcgsi7180.inf_arm64_d224cc415fe52737\qcgsi7180.inf >>"%LOG%" 2>&1
echo [pass 1] qci2c7180.inf_arm64_2c63c49b2547af75
echo [pass 1] START qci2c7180.inf_arm64_2c63c49b2547af75>>"%LOG%"
drvload X:\Drivers\qci2c7180.inf_arm64_2c63c49b2547af75\qci2c7180.inf >>"%LOG%" 2>&1
echo [pass 1] qcspi7180.inf_arm64_88e8bd005052a090
echo [pass 1] START qcspi7180.inf_arm64_88e8bd005052a090>>"%LOG%"
drvload X:\Drivers\qcspi7180.inf_arm64_88e8bd005052a090\qcspi7180.inf >>"%LOG%" 2>&1
echo [pass 1] ec2.inf_arm64_5d895d280ce62499
echo [pass 1] START ec2.inf_arm64_5d895d280ce62499>>"%LOG%"
drvload X:\Drivers\ec2.inf_arm64_5d895d280ce62499\ec2.inf >>"%LOG%" 2>&1
echo [pass 1] emuec.inf_arm64_b2c2615cdf2a8df7
echo [pass 1] START emuec.inf_arm64_b2c2615cdf2a8df7>>"%LOG%"
drvload X:\Drivers\emuec.inf_arm64_b2c2615cdf2a8df7\emuec.inf >>"%LOG%" 2>&1
echo [pass 1] kbdhelper.inf_arm64_4565cb1b8919470e
echo [pass 1] START kbdhelper.inf_arm64_4565cb1b8919470e>>"%LOG%"
drvload X:\Drivers\kbdhelper.inf_arm64_4565cb1b8919470e\kbdhelper.inf >>"%LOG%" 2>&1
echo [pass 1] samsungeventcontroller.inf_arm64_176d499e99d8e474
echo [pass 1] START samsungeventcontroller.inf_arm64_176d499e99d8e474>>"%LOG%"
drvload X:\Drivers\samsungeventcontroller.inf_arm64_176d499e99d8e474\samsungeventcontroller.inf >>"%LOG%" 2>&1
echo [pass 1] swi2cdriver.inf_arm64_7e27b755ecb17904
echo [pass 1] START swi2cdriver.inf_arm64_7e27b755ecb17904>>"%LOG%"
drvload X:\Drivers\swi2cdriver.inf_arm64_7e27b755ecb17904\swi2cdriver.inf >>"%LOG%" 2>&1
echo [pass 1] tpadhelper.inf_arm64_f60442f501c7abd8
echo [pass 1] START tpadhelper.inf_arm64_f60442f501c7abd8>>"%LOG%"
drvload X:\Drivers\tpadhelper.inf_arm64_f60442f501c7abd8\tpadhelper.inf >>"%LOG%" 2>&1
echo [pass 1] vhidevent.inf_arm64_ad77cd790ee66818
echo [pass 1] START vhidevent.inf_arm64_ad77cd790ee66818>>"%LOG%"
drvload X:\Drivers\vhidevent.inf_arm64_ad77cd790ee66818\vhidevent.inf >>"%LOG%" 2>&1
echo [pass 1] ucmem.inf_arm64_cf35fd1d7ac98804
echo [pass 1] START ucmem.inf_arm64_cf35fd1d7ac98804>>"%LOG%"
drvload X:\Drivers\ucmem.inf_arm64_cf35fd1d7ac98804\ucmem.inf >>"%LOG%" 2>&1
echo [pass 1] qcusbcucsi7180.inf_arm64_d2ae44ab02b37b6e
echo [pass 1] START qcusbcucsi7180.inf_arm64_d2ae44ab02b37b6e>>"%LOG%"
drvload X:\Drivers\qcusbcucsi7180.inf_arm64_d2ae44ab02b37b6e\qcusbcucsi7180.inf >>"%LOG%" 2>&1
echo [pass 1] qcxhcifilter7180.inf_arm64_39faba6210deaa83
echo [pass 1] START qcxhcifilter7180.inf_arm64_39faba6210deaa83>>"%LOG%"
drvload X:\Drivers\qcxhcifilter7180.inf_arm64_39faba6210deaa83\qcxhcifilter7180.inf >>"%LOG%" 2>&1
echo [pass 2] qcsmmu7180.inf_arm64_fb45a758baf0c0f3
echo [pass 2] START qcsmmu7180.inf_arm64_fb45a758baf0c0f3>>"%LOG%"
drvload X:\Drivers\qcsmmu7180.inf_arm64_fb45a758baf0c0f3\qcsmmu7180.inf >>"%LOG%" 2>&1
echo [pass 2] qcpep.wd7180.inf_arm64_8c2bf704ae20b939
echo [pass 2] START qcpep.wd7180.inf_arm64_8c2bf704ae20b939>>"%LOG%"
drvload X:\Drivers\qcpep.wd7180.inf_arm64_8c2bf704ae20b939\qcpep.wd7180.inf >>"%LOG%" 2>&1
echo [pass 2] qcscm7180.inf_arm64_c15e0d2e13cf9827
echo [pass 2] START qcscm7180.inf_arm64_c15e0d2e13cf9827>>"%LOG%"
drvload X:\Drivers\qcscm7180.inf_arm64_c15e0d2e13cf9827\qcscm7180.inf >>"%LOG%" 2>&1
echo [pass 2] qcpmic7180.inf_arm64_ab07463b3509bf1a
echo [pass 2] START qcpmic7180.inf_arm64_ab07463b3509bf1a>>"%LOG%"
drvload X:\Drivers\qcpmic7180.inf_arm64_ab07463b3509bf1a\qcpmic7180.inf >>"%LOG%" 2>&1
echo [pass 2] qcpmicgpio7180.inf_arm64_63fc9cff076ea2c3
echo [pass 2] START qcpmicgpio7180.inf_arm64_63fc9cff076ea2c3>>"%LOG%"
drvload X:\Drivers\qcpmicgpio7180.inf_arm64_63fc9cff076ea2c3\qcpmicgpio7180.inf >>"%LOG%" 2>&1
echo [pass 2] qcspmi7180.inf_arm64_757ebdaf4b2db7ed
echo [pass 2] START qcspmi7180.inf_arm64_757ebdaf4b2db7ed>>"%LOG%"
drvload X:\Drivers\qcspmi7180.inf_arm64_757ebdaf4b2db7ed\qcspmi7180.inf >>"%LOG%" 2>&1
echo [pass 2] secpmic3p.inf_arm64_201875b1619b0375
echo [pass 2] START secpmic3p.inf_arm64_201875b1619b0375>>"%LOG%"
drvload X:\Drivers\secpmic3p.inf_arm64_201875b1619b0375\secpmic3p.inf >>"%LOG%" 2>&1
echo [pass 2] qcgpi7180.inf_arm64_e9ab834b54154a9d
echo [pass 2] START qcgpi7180.inf_arm64_e9ab834b54154a9d>>"%LOG%"
drvload X:\Drivers\qcgpi7180.inf_arm64_e9ab834b54154a9d\qcgpi7180.inf >>"%LOG%" 2>&1
echo [pass 2] qcgpio7180.inf_arm64_555685db7b4d675c
echo [pass 2] START qcgpio7180.inf_arm64_555685db7b4d675c>>"%LOG%"
drvload X:\Drivers\qcgpio7180.inf_arm64_555685db7b4d675c\qcgpio7180.inf >>"%LOG%" 2>&1
echo [pass 2] qcgsi7180.inf_arm64_d224cc415fe52737
echo [pass 2] START qcgsi7180.inf_arm64_d224cc415fe52737>>"%LOG%"
drvload X:\Drivers\qcgsi7180.inf_arm64_d224cc415fe52737\qcgsi7180.inf >>"%LOG%" 2>&1
echo [pass 2] qci2c7180.inf_arm64_2c63c49b2547af75
echo [pass 2] START qci2c7180.inf_arm64_2c63c49b2547af75>>"%LOG%"
drvload X:\Drivers\qci2c7180.inf_arm64_2c63c49b2547af75\qci2c7180.inf >>"%LOG%" 2>&1
echo [pass 2] qcspi7180.inf_arm64_88e8bd005052a090
echo [pass 2] START qcspi7180.inf_arm64_88e8bd005052a090>>"%LOG%"
drvload X:\Drivers\qcspi7180.inf_arm64_88e8bd005052a090\qcspi7180.inf >>"%LOG%" 2>&1
echo [pass 2] ec2.inf_arm64_5d895d280ce62499
echo [pass 2] START ec2.inf_arm64_5d895d280ce62499>>"%LOG%"
drvload X:\Drivers\ec2.inf_arm64_5d895d280ce62499\ec2.inf >>"%LOG%" 2>&1
echo [pass 2] emuec.inf_arm64_b2c2615cdf2a8df7
echo [pass 2] START emuec.inf_arm64_b2c2615cdf2a8df7>>"%LOG%"
drvload X:\Drivers\emuec.inf_arm64_b2c2615cdf2a8df7\emuec.inf >>"%LOG%" 2>&1
echo [pass 2] kbdhelper.inf_arm64_4565cb1b8919470e
echo [pass 2] START kbdhelper.inf_arm64_4565cb1b8919470e>>"%LOG%"
drvload X:\Drivers\kbdhelper.inf_arm64_4565cb1b8919470e\kbdhelper.inf >>"%LOG%" 2>&1
echo [pass 2] samsungeventcontroller.inf_arm64_176d499e99d8e474
echo [pass 2] START samsungeventcontroller.inf_arm64_176d499e99d8e474>>"%LOG%"
drvload X:\Drivers\samsungeventcontroller.inf_arm64_176d499e99d8e474\samsungeventcontroller.inf >>"%LOG%" 2>&1
echo [pass 2] swi2cdriver.inf_arm64_7e27b755ecb17904
echo [pass 2] START swi2cdriver.inf_arm64_7e27b755ecb17904>>"%LOG%"
drvload X:\Drivers\swi2cdriver.inf_arm64_7e27b755ecb17904\swi2cdriver.inf >>"%LOG%" 2>&1
echo [pass 2] tpadhelper.inf_arm64_f60442f501c7abd8
echo [pass 2] START tpadhelper.inf_arm64_f60442f501c7abd8>>"%LOG%"
drvload X:\Drivers\tpadhelper.inf_arm64_f60442f501c7abd8\tpadhelper.inf >>"%LOG%" 2>&1
echo [pass 2] vhidevent.inf_arm64_ad77cd790ee66818
echo [pass 2] START vhidevent.inf_arm64_ad77cd790ee66818>>"%LOG%"
drvload X:\Drivers\vhidevent.inf_arm64_ad77cd790ee66818\vhidevent.inf >>"%LOG%" 2>&1
echo [pass 2] ucmem.inf_arm64_cf35fd1d7ac98804
echo [pass 2] START ucmem.inf_arm64_cf35fd1d7ac98804>>"%LOG%"
drvload X:\Drivers\ucmem.inf_arm64_cf35fd1d7ac98804\ucmem.inf >>"%LOG%" 2>&1
echo [pass 2] qcusbcucsi7180.inf_arm64_d2ae44ab02b37b6e
echo [pass 2] START qcusbcucsi7180.inf_arm64_d2ae44ab02b37b6e>>"%LOG%"
drvload X:\Drivers\qcusbcucsi7180.inf_arm64_d2ae44ab02b37b6e\qcusbcucsi7180.inf >>"%LOG%" 2>&1
echo [pass 2] qcxhcifilter7180.inf_arm64_39faba6210deaa83
echo [pass 2] START qcxhcifilter7180.inf_arm64_39faba6210deaa83>>"%LOG%"
drvload X:\Drivers\qcxhcifilter7180.inf_arm64_39faba6210deaa83\qcxhcifilter7180.inf >>"%LOG%" 2>&1
echo ALL DONE>>"%LOG%"
ping -n 8 127.0.0.1 >nul
