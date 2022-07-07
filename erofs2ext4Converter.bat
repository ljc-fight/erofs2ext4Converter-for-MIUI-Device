@echo off
setlocal 
title erofs2ext4Converter batch


if not exist bin\Windows (
	echo.This is not the special directory !
	set exitcode=1
	goto End
)
fsutil 1>nul 2>nul
if "%errorlevel%" neq "0" (
	echo.Command "fsutil" is not supported on your device !
	set exitcode=1
	goto End
)
if "%1" == "--help"  set Error="Get help"                             &goto Usage
if "%1" == "-h"      set Error="Get help"                             &goto Usage
if "%1" == ""        set Error="Not defined the first argument"       &goto Usage
if not exist "%1" bin\Windows\cecho {04}File is not exist !{0F}{\n}   &goto End
set zipFile=%1




:CheckIFMIUIROM
for /f "delims=" %%i in ('echo.%zipFile% ^|bin\Windows\busybox grep "miui_"') do (set checkMIUI=%%i)
if "%checkMIUI%" == "" set UnsopportedReason="This may not be a MIUI ROM" &goto Unsopported
for /f "delims=" %%i in ('bin\Windows\busybox basename %checkMIUI%') do (set baseName=%%i)
for /f "delims=" %%i in ('echo.%baseName% ^|bin\Windows\busybox cut -d "_" -f 2') do (set deviceCode=%%i)
for /f "delims=" %%i in ('echo.%baseName% ^|bin\Windows\busybox cut -d "_" -f 3') do (set romVersion=%%i)
for /f "delims=" %%i in ('echo.%baseName% ^|bin\Windows\busybox cut -d "_" -f 5 ^|bin\Windows\busybox cut -d "." -f 1') do (set androidVersion=%%i)
bin\Windows\cecho {0E}ROM information{0F}{\n}
if "%deviceCode%" == "" (
	set deviceCode=unknown
) else (
	bin\Windows\cecho {0A}DeviceCode: %deviceCode%{0F}{\n}
)
if "%romVersion%" == "" (
	set romVersion=unknown
) else (
	bin\Windows\cecho {0A}ROMVersion: %romVersion%{0F}{\n}
)
if "%androidVersion%" == "" (
	set androidVersion=unknown
) else (
	bin\Windows\cecho {0A}AndroidVersion: %androidVersion%{0F}{\n}
)




:Cleanup
echo.Clean workspace...
rd /s /q tmp 1>nul 2>nul
rd /s /q odm 1>nul 2>nul
rd /s /q config 1>nul 2>nul
rd /s /q system 1>nul 2>nul
rd /s /q vendor 1>nul 2>nul
rd /s /q product 1>nul 2>nul
rd /s /q system_ext 1>nul 2>nul
rd /s /q vendor_dlkm 1>nul 2>nul
del odm.img 1>nul 2>nul
del system.img 1>nul 2>nul
del vendor.img 1>nul 2>nul
del product.img 1>nul 2>nul
del system_ext.img 1>nul 2>nul
del vendor_dlkm.img 1>nul 2>nul




:Convert
echo.Target: %zipFile%
echo.Unpack zip file...
bin\Windows\7z x -y %zipFile% -otmp 1>nul 2>nul|| (
	set UnsopportedReason="Cannot open the file as archive !" 
	goto Unsopported
)
if not exist tmp\payload.bin (
	set UnsopportedReason="Unsopported device !"
	goto Unsopported
)
echo.Unpack payload.bin...
echo.This will take a few minutes
bin\Windows\payload_dumper -o tmp/images tmp/payload.bin 1>nul 2>nul
echo.payload.bin was unpacked !
del /s /q tmp\payload.bin


:: Unpack vendor.img to check fstab
bin\Windows\erofsUnpack tmp/images/vendor.img
for /f "delims=" %%i in ('bin\Windows\busybox cat vendor/etc/fstab.* ^|bin\Windows\busybox grep system ^|bin\Windows\busybox grep ext4 ^|bin\Windows\busybox awk NR^=^=1') do (set isSupportExt4FS=%%i)
if "isSupportExt4FS" == "" (
	set UnsopportedReason="This device's fstab dose not support ext4 filesystem !"
	rd /s /q tmp
	rd /s /q vendor
	rd /s /q config
	goto Unsopported
)
del /s /q tmp\images\vendor.img
if exist tmp\images\odm.img (
	bin\Windows\erofsUnpack tmp/images/odm.img
	del /s /q tmp\images\odm.img
)
if exist tmp\images\system.img (
	bin\Windows\erofsUnpack tmp/images/system.img
	del /s /q tmp\images\system.img
)
if exist tmp\images\product.img (
	bin\Windows\erofsUnpack tmp/images/product.img
	del /s /q tmp\images\product.img
)
if exist tmp\images\vendor_dlkm.img (
	bin\Windows\erofsUnpack tmp/images/vendor_dlkm.img
	del /s /q tmp\images\vendor_dlkm.img
)
if exist tmp\images\system_ext.img (
	bin\Windows\erofsUnpack tmp/images/system_ext.img
	del /s /q tmp\images\system_ext.img
)


:: The text "lost+found" in config files will cause error when repacking ext4 image
::bin\Windows\busybox sed -i "/+found/d" config/*file_contexts
::bin\Windows\busybox sed -i "/+found/d" config/*fs_config
bin\Windows\busybox sed -i "s/\[/\\\[/g" config/*file_contexts
bin\Windows\busybox sed -i "s/+/\\+/g" config/*file_contexts

rd /s /q system\system\media\theme\miui_mod_icons\com.google.android.apps.nbu
rd /s /q system\system\media\theme\miui_mod_icons\dynamic\com.google.android.apps.nbu

:: if the size of image is bigger than 4G ,it may unbootable after repacking image
rd /s /q system\system\data-app
md system\system\data-app


:: Repack dynamic partition by make_ext4fs
if exist odm (
	echo.Repack odm image
	bin\Windows\make_ext4fs -J -T 1640966400 -S config/odm_file_contexts -l 134217728 -C config/odm_fs_config -L odm -a odm odm.img odm
	if exist odm.img (
		bin\Windows\cecho {0A}Repack partition odm successfully !{0F}{\n}
	) else (
		bin\Windows\cecho {04}Failed to repack partition odm !{0F}{\n}
		goto FailedToRepack
	)
)
if exist vendor_dlkm (
	echo.Repack vendor_dlkm image
	bin\Windows\make_ext4fs -J -T 1640966400 -S config/vendor_dlkm_file_contexts -l 134217728 -C config/vendor_dlkm_fs_config -L vendor_dlkm -a vendor_dlkm vendor_dlkm.img vendor_dlkm
	if exist vendor_dlkm.img (
		bin\Windows\cecho {0A}Repack partition vendor_dlkm successfully !{0F}{\n}
	) else (
		bin\Windows\cecho {04}Failed to repack partition vendor_dlkm !{0F}{\n}
		goto FailedToRepack
	)
)

setlocal enabledelayedexpansion

:: Use fsutil to ctreate empty file
if exist system (
	echo.Repack system image
	fsutil file createnew system\system.txt 288435456 1>nul 2>nul
	for /f "delims=" %%i in ('bin\Windows\busybox du -sb system ^|bin\Windows\busybox tr -cd 0-9') do (set systemSize=%%i)
	del system\system.txt
	echo.Size of partition system: !systemSize!
	bin\Windows\make_ext4fs -J -T 1640966400 -S config/system_file_contexts -l !systemSize! -C config/system_fs_config -L system -a system system.img system
	if exist system.img (
		bin\Windows\cecho {0A}Repack partition system successfully !{0F}{\n}
	) else (
		bin\Windows\cecho {04}Failed to repack partition system !{0F}{\n}
		goto FailedToRepack
	)
)
if exist vendor (
	echo.Repack vendor image
	fsutil file createnew vendor\vendor.txt 178435456 1>nul 2>nul
	for /f "delims=" %%i in ('bin\Windows\busybox du -sb vendor ^|bin\Windows\busybox tr -cd 0-9') do (set vendorSize=%%i)
	del vendor\vendor.txt
	echo.Size of partition vendor: !vendorSize!
	bin\Windows\make_ext4fs -J -T 1640966400 -S config/vendor_file_contexts -l !vendorSize! -C config/vendor_fs_config -L vendor -a vendor vendor.img vendor
	if exist vendor.img (
		bin\Windows\cecho {0A}Repack partition vendor successfully !{0F}{\n}
	) else (
		bin\Windows\cecho {04}Failed to repack partition vendor !{0F}{\n}
		goto FailedToRepack
	)
)
if exist product (
	echo.Repack product image
	fsutil file createnew product\product.txt 67108864 1>nul 2>nul
	for /f "delims=" %%i in ('bin\Windows\busybox du -sb product ^|bin\Windows\busybox tr -cd 0-9') do (set productSize=%%i)
	del product\product.txt
	echo.Size of partition product: !productSize!
	bin\Windows\make_ext4fs -J -T 1640966400 -S config/product_file_contexts -l !productSize! -C config/product_fs_config -L product -a product product.img product
	if exist product.img (
		bin\Windows\cecho {0A}Repack partition product successfully !{0F}{\n}
	) else (
		bin\Windows\cecho {04}Failed to repack partition product !{0F}{\n}
		goto FailedToRepack
	)
)
if exist system_ext (
	echo.Repack system_ext image
	fsutil file createnew system_ext\system_ext.txt 67108864 1>nul 2>nul
	for /f "delims=" %%i in ('bin\Windows\busybox du -sb system_ext ^|bin\Windows\busybox tr -cd 0-9') do (set systemExtSize=%%i)
	del system_ext\system_ext.txt
	echo.Size of partition system_ext: !systemExtSize!
	bin\Windows\make_ext4fs -J -T 1640966400 -S config/system_ext_file_contexts -l !systemExtSize! -C config/system_ext_fs_config -L system_ext -a system_ext system_ext.img system_ext
	if exist system_ext.img (
		bin\Windows\cecho {0A}Repack partition system_ext successfully !{0F}{\n}
	) else (
		bin\Windows\cecho {04}Failed to repack partition system_ext !{0F}{\n}
		goto FailedToRepack
	)
)




:MakeSuperImage

:: odm system vendor product system_ext vendor_dlkm
if exist odm.img if exist system.img if exist vendor.img if exist product.img if exist system_ext.img if exist vendor_dlkm.img (
	bin\Windows\lpmake -F --virtual-ab --output super.img --metadata-size 65536 --super-name super --metadata-slots 3 --device super:9126805504 --group=qti_dynamic_partitions_a:9126805504 --group=qti_dynamic_partitions_b:9126805504 --partition odm_a:readonly:134217728:qti_dynamic_partitions_a --image odm_a=odm.img --partition system_a:readonly:!systemSize!:qti_dynamic_partitions_a --image system_a=system.img --partition vendor_a:readonly:!vendorSize!:qti_dynamic_partitions_a --image vendor_a=vendor.img --partition product_a:readonly:!productSize!:qti_dynamic_partitions_a --image product_a=product.img --partition system_ext_a:readonly:!systemExtSize!:qti_dynamic_partitions_a --image system_ext_a=system_ext.img --partition vendor_dlkm_a:readonly:134217728:qti_dynamic_partitions_a --image vendor_dlkm_a=vendor_dlkm.img --partition odm_b:readonly:0:qti_dynamic_partitions_b --partition system_b:readonly:0:qti_dynamic_partitions_b --partition vendor_b:readonly:0:qti_dynamic_partitions_b --partition product_b:readonly:0:qti_dynamic_partitions_b --partition system_ext_b:readonly:0:qti_dynamic_partitions_b --partition vendor_dlkm_b:readonly:0:qti_dynamic_partitions_b

)

:: odm system vendor product vendor_dlkm
if exist odm.img if exist system.img if exist vendor.img if exist product.img if not exist system_ext.img if exist vendor_dlkm.img (
	bin\Windows\lpmake -F --virtual-ab --output super.img --metadata-size 65536 --super-name super --metadata-slots 3 --device super:9126805504 --group=qti_dynamic_partitions_a:9126805504 --group=qti_dynamic_partitions_b:9126805504 --partition odm_a:readonly:134217728:qti_dynamic_partitions_a --image odm_a=odm.img --partition system_a:readonly:!systemSize!:qti_dynamic_partitions_a --image system_a=system.img --partition vendor_a:readonly:!vendorSize!:qti_dynamic_partitions_a --image vendor_a=vendor.img --partition product_a:readonly:!productSize!:qti_dynamic_partitions_a --image product_a=product.img --partition vendor_dlkm_a:readonly:134217728:qti_dynamic_partitions_a --image vendor_dlkm_a=vendor_dlkm.img --partition odm_b:readonly:0:qti_dynamic_partitions_b --partition system_b:readonly:0:qti_dynamic_partitions_b --partition vendor_b:readonly:0:qti_dynamic_partitions_b --partition product_b:readonly:0:qti_dynamic_partitions_b --partition vendor_dlkm_b:readonly:0:qti_dynamic_partitions_b

)

:: odm system vendor product system_ext
if exist odm.img if exist system.img if exist vendor.img if exist product.img if exist system_ext.img if not exist vendor_dlkm.img (
	bin\Windows\lpmake -F --virtual-ab --output super.img --metadata-size 65536 --super-name super --metadata-slots 3 --device super:9126805504 --group=qti_dynamic_partitions_a:9126805504 --group=qti_dynamic_partitions_b:9126805504 --partition odm_a:readonly:134217728:qti_dynamic_partitions_a --image odm_a=odm.img --partition system_a:readonly:!systemSize!:qti_dynamic_partitions_a --image system_a=system.img --partition vendor_a:readonly:!vendorSize!:qti_dynamic_partitions_a --image vendor_a=vendor.img --partition product_a:readonly:!productSize!:qti_dynamic_partitions_a --image product_a=product.img --partition system_ext_a:readonly:!systemExtSize!:qti_dynamic_partitions_a --image system_ext_a=system_ext.img --partition odm_b:readonly:0:qti_dynamic_partitions_b --partition system_b:readonly:0:qti_dynamic_partitions_b --partition vendor_b:readonly:0:qti_dynamic_partitions_b --partition product_b:readonly:0:qti_dynamic_partitions_b --partition system_ext_b:readonly:0:qti_dynamic_partitions_b

)

:: odm system vendor product
if exist odm.img if exist system.img if exist vendor.img if exist product.img if not exist system_ext.img if not exist vendor_dlkm.img (
	bin\Windows\lpmake -F --virtual-ab --output super.img --metadata-size 65536 --super-name super --metadata-slots 3 --device super:9126805504 --group=qti_dynamic_partitions_a:9126805504 --group=qti_dynamic_partitions_b:9126805504 --partition odm_a:readonly:134217728:qti_dynamic_partitions_a --image odm_a=odm.img --partition system_a:readonly:!systemSize!:qti_dynamic_partitions_a --image system_a=system.img --partition vendor_a:readonly:!vendorSize!:qti_dynamic_partitions_a --image vendor_a=vendor.img --partition product_a:readonly:!productSize!:qti_dynamic_partitions_a --image product_a=product.img --partition odm_b:readonly:0:qti_dynamic_partitions_b --partition system_b:readonly:0:qti_dynamic_partitions_b --partition vendor_b:readonly:0:qti_dynamic_partitions_b --partition product_b:readonly:0:qti_dynamic_partitions_b

)

:: system vendor product system_ext
if not exist odm.img if exist system.img if exist vendor.img if exist product.img if exist system_ext.img if not exist vendor_dlkm.img (
	bin\Windows\lpmake -F --virtual-ab --output super.img --metadata-size 65536 --super-name super --metadata-slots 3 --device super:9126805504 --group=qti_dynamic_partitions_a:9126805504 --group=qti_dynamic_partitions_b:9126805504 --partition system_a:readonly:!systemSize!:qti_dynamic_partitions_a --image system_a=system.img --partition vendor_a:readonly:!vendorSize!:qti_dynamic_partitions_a --image vendor_a=vendor.img --partition product_a:readonly:!productSize!:qti_dynamic_partitions_a --image product_a=product.img --partition system_ext_a:readonly:!systemExtSize!:qti_dynamic_partitions_a --image system_ext_a=system_ext.img --partition system_b:readonly:0:qti_dynamic_partitions_b --partition vendor_b:readonly:0:qti_dynamic_partitions_b --partition product_b:readonly:0:qti_dynamic_partitions_b --partition system_ext_b:readonly:0:qti_dynamic_partitions_b

)

:: system vendor product
if not exist odm.img if exist system.img if exist vendor.img if exist product.img if not exist system_ext.img if not exist vendor_dlkm.img (
	bin\Windows\lpmake -F --virtual-ab --output super.img --metadata-size 65536 --super-name super --metadata-slots 3 --device super:9126805504 --group=qti_dynamic_partitions_a:9126805504 --group=qti_dynamic_partitions_b:9126805504 --partition system_a:readonly:!systemSize!:qti_dynamic_partitions_a --image system_a=system.img --partition vendor_a:readonly:!vendorSize!:qti_dynamic_partitions_a --image vendor_a=vendor.img --partition product_a:readonly:!productSize!:qti_dynamic_partitions_a --image product_a=product.img --partition system_b:readonly:0:qti_dynamic_partitions_b --partition vendor_b:readonly:0:qti_dynamic_partitions_b --partition product_b:readonly:0:qti_dynamic_partitions_b
)


if exist super.img (
	bin\Windows\cecho {0A}Pack super.img successfully !{0F}{\n}
) else (
	bin\Windows\cecho {04}Failed to pack super.img !{0F}{\n}
	goto FailedToRepack
)
setlocal disabledelayedexpansion


:Usage
echo.
echo.Error reason: %ERROR%
echo.
bin\Windows\cecho {0E}Usage: erofs2ext4Converter.bat ^<filePath^>{0F}{\n}
goto End




:Unsopported
echo.
echo.Error info :
bin\Windows\cecho {04}    %UnsopportedReason% {0F}{\n}
echo.
goto end




:FailedToRepack
setlocal disabledelayedexpansion
bin\Windows\cecho {04}Failed to repack logical partition !{0F}{\n}




:End
if "%exitcode%" == "1" pause