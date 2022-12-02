@echo off
if not exist bin (
	echo.Error: Invalid path,keep the batch file and rom file on the same path
	pause
	exit
)
set PATH=
set PATH=%SystemRoot%\System32;%CD%\bin
setlocal enableDelayedExpansion
set who=%0
if [%1] == [] (
	call :USAGE
	goto EOF
) else (
	set romFile=%1
	goto MAIN
)


:USAGE
echo.
echo.Usage:
echo.    erofs2ext4Converter.bat ^<miui_official_recovery_rom^>
echo.
pause
exit /b 1



:MAIN
if not exist !romFile! (
	call :USAGE
	goto EOF
)
for /f "tokens=*" %%i in ('busybox date ^+%%s') do (set startTime=%%i)
echo.Target:!romFile!
rd /s /q tmp 1>nul 2>nul
rd /s /q config 1>nul 2>nul
rd /s /q vendor 1>nul 2>nul
rd /s /q system 1>nul 2>nul
rd /s /q product 1>nul 2>nul
rd /s /q system_ext 1>nul 2>nul
for /f "tokens=*" %%i in ('busybox basename !romFile!') do (set romName=%%i)
echo.Unpacking paylaod.bin from !romName!
7z x -y !romFile! payload.bin -otmp 1>nul 2>nul || call :ERROR "Invalid file" "You may choose a package that contains payload.bin"
echo.Extracting images from paylaod.bin
echo.This will take a few minutes,be patient
payload-dumper-go -o tmp/images tmp/payload.bin 1>nul 2>nul || call :ERROR "Failed to extract payload.bin" "Is it a miui recovery rom package?"
echo.Images was extracted to tmp/images
del tmp\payload.bin
md tmp\config
md tmp\output
for /f "tokens=2 delims==" %%i in ('type bin\configure.txt ^|findstr subpartition') do (set superList=%%i)
for /f "tokens=2 delims==" %%i in ('type bin\configure.txt ^|findstr exclusion_list') do (set exclusionList=%%i)
echo.Possible super subpartition list:!superList!
echo.Exclusion list:!exclusionList!
for %%i in (!exclusionList!) do (
	set pname=%%i
	if exist tmp\images\!pname!.img (
		echo.Super subpartition !pname! in exclusion list,skipping
		move tmp\images\!pname!.img tmp\output\ 1>nul 2>nul
	)
)
set pname=
for %%i in (!superList!) do (
	set pname=%%i
	if exist tmp\images\!pname!.img (
		echo.Super subpartition !pname! detected
		echo.Erofs unpacking !pname!.img...
		erofsUnpack tmp/images/!pname!.img 1>nul 2>nul
		busybox sed -i "s/\[/\\\[/g" config/!pname!_file_contexts
		::if exist tmp\system\system\etc\selinux\plat_file_contexts busybox cat tmp/system/system/etc/selinux/plat_file_contexts>>config/!pname!_file_contexts
		move config\*!pname!* tmp\config\ 1>nul 2>nul
		move !pname! tmp\ 1>nul 2>nul
		del tmp\images\!pname!.img
	)
)
echo.Delete some APKs to ensure successful packaging
busybox rm -rf tmp/vendor/data-app/*
busybox rm -rf tmp/product/data-app/*
busybox rm -rf tmp/product/app/Updater
busybox rm -rf tmp/product/app/MiuiUpdater
busybox rm -rf tmp/product/priv-app/Updater
busybox rm -rf tmp/product/priv-app/MiuiUpdater
busybox rm -rf tmp/system/system/app/Updater
busybox rm -rf tmp/system/system/app/MiuiUpdater
busybox rm -rf tmp/system/system/priv-app/Updater
busybox rm -rf tmp/system/system/priv-app/MiuiUpdater
busybox rm -rf tmp/system/system/data-app/*

set pname=
set totalSize=0
for %%i in (!superList!) do (
	set pname=%%i
	set persize=
	if not exist tmp\!pname! if not exist tmp\output\!pname!.img (
		set persize=0
	)
	if exist tmp\!pname! (
		for /f "tokens=*" %%i in ('busybox du -sb tmp/!pname! ^|busybox tr -cd 0-9') do (set persize=%%i)
	)
	if exist tmp\output\!pname!.img (
		for /f "tokens=*" %%i in ('busybox du -sb tmp/output/!pname!.img ^|busybox tr -cd 0-9') do (set persize=%%i)
	)
	echo.Checking !pname! size: !persize!
	for /f "tokens=*" %%i in ('echo.!totalSize! + !persize! ^|busybox bc') do (set totalSize=%%i)
)
for /f "tokens=*" %%i in ('echo.!totalSize! + 369098752 ^|busybox bc') do (set totalSize=%%i)
echo.Total size of super partition:!totalSize!
busybox bash -c "[ !totalSize! -gt 9126805504 ] && return 1 ||return 0"
if "!errorlevel!" NEQ "0" (
	echo.Warninng:Size of images is larger than super size
	echo.Delete some system apps...
	busybox rm -rf tmp/product/app/mab
	busybox rm -rf tmp/product/priv-app/mab
	busybox rm -rf tmp/system/system/app/mab
	busybox rm -rf tmp/system/system/app/MIpay
	busybox rm -rf tmp/system/system/priv-app/mab
	busybox rm -rf tmp/system/system/priv-app/MIpay
	busybox rm -rf tmp/product/app/AnalyticsCore
	busybox rm -rf tmp/product/app/MIpay
	busybox rm -rf tmp/product/priv-app/AnalyticsCore
	busybox rm -rf tmp/product/priv-app/MIpay
	busybox rm -rf tmp/system/system/app/AnalyticsCore
	busybox rm -rf tmp/system/system/priv-app/AnalyticsCore
	busybox rm -rf tmp/product/app/*Browser
	busybox rm -rf tmp/product/priv-app/*Browser
	busybox rm -rf tmp/system/system/app/*Browser
	busybox rm -rf tmp/system/system/priv-app/*Browser
	busybox rm -rf tmp/product/app/*BugReport
	busybox rm -rf tmp/product/priv-app/*BugReport
	busybox rm -rf tmp/system/system/app/*BugReport
	busybox rm -rf tmp/system/system/priv-app/*BugReport
	busybox rm -rf tmp/product/app/Service
	busybox rm -rf tmp/product/priv-app/Service
	busybox rm -rf tmp/system/system/app/Service
	busybox rm -rf tmp/system/system/priv-app/Service
	busybox rm -rf tmp/product/app/MiService
	busybox rm -rf tmp/product/priv-app/MiService
	busybox rm -rf tmp/system/system/app/MiService
	busybox rm -rf tmp/system/system/priv-app/MiService
	busybox rm -rf tmp/product/app/*Music
	busybox rm -rf tmp/product/priv-app/*Music
	busybox rm -rf tmp/system/system/app/*Music
	busybox rm -rf tmp/system/system/priv-app/*Music
)

set pname=
for %%i in (!superList!) do (
	set pname=%%i
	if exist tmp\!pname! (
		set extraSize=134217728
		rem 100663296
		if "!pname!" == "system_ext" set extraSize=67108864
		for /f "tokens=*" %%i in ('busybox du -sb tmp/!pname! ^|busybox tr -cd 0-9') do (set dusize=%%i)
		for /f "tokens=*" %%i in ('echo.!extraSize! + !dusize! ^|busybox bc') do (set size=%%i)
		echo.Repacking !pname!.img with ext4 format,size: !size!
		make_ext4fs -J -T 0 -l !size! -C tmp/config/!pname!_fs_config -a !pname! -L !pname! tmp/output/!pname!.img tmp/!pname! 1>nul 2>nul
		::make_ext4fs -J -T 0 -S tmp/config/!pname!_file_contexts -l !size! -C tmp/config/!pname!_fs_config -a !pname! -L !pname! tmp/output/!pname!.img tmp/!pname! 1>nul 2>nul
		if not exist tmp\output\!pname!.img (
			make_ext4fs -J -T 0 -S tmp/config/!pname!_file_contexts -l !size! -C tmp/config/!pname!_fs_config -a !pname! -L !pname! tmp/output/!pname!.img tmp/!pname!
			call :ERROR "Failed to repack !pname!.img with ext4 format" "Details are above"
		)
	)
)

set size=
set pname=
set lpargs= -F --virtual-ab --output tmp/output/super.img --metadata-size 65536 --super-name super --metadata-slots 3 --device super:9126805504 --group=qti_dynamic_partitions_a:9126805504 --group=qti_dynamic_partitions_b:9126805504
for %%i in (!superList!) do (
	set pname=%%i
	if exist tmp\output\!pname!.img (
		for /f "tokens=*" %%i in ('busybox du -sb tmp/output/!pname!.img ^|busybox tr -cd 0-9') do (set size=%%i)
		set args=--partition !pname!_a:readonly:!size!:qti_dynamic_partitions_a --image !pname!_a=tmp/output/!pname!.img --partition !pname!_b:readonly:0:qti_dynamic_partitions_b
		set lpargs=!lpargs! !args!
	)
)
lpmake !lpargs! || call :ERROR "Failed to pack super.img" "Maybe out of space?Edit the erofs2ext4Converter.bat and remove something else from system or other partition"

set dirname=erofs2ext4_%date:~5,2%%date:~8,2%_!RANDOM!
md !dirname!
move tmp\images !dirname! 1>nul 2>nul
move tmp\output\super.img !dirname!\images\ 1>nul 2>nul
copy bin\install_update.bat !dirname! 1>nul 2>nul
copy bin\install_format.bat !dirname! 1>nul 2>nul

for /f "tokens=1 delims=." %%i in ('dir /b !dirname!\images ^|findstr -v "preload super"') do (
	set fwimg=%%i
	busybox sed -i "/rem/i fastboot flash !fwimg!_b images\/!fwimg!.img" !dirname!/install_format.bat
	busybox sed -i "/rem/i fastboot flash !fwimg!_a images\/!fwimg!.img" !dirname!/install_format.bat
	busybox sed -i "/rem/i fastboot flash !fwimg!_b images\/!fwimg!.img" !dirname!/install_update.bat
	busybox sed -i "/rem/i fastboot flash !fwimg!_a images\/!fwimg!.img" !dirname!/install_update.bat
)
busybox unix2dos !dirname!/install_format.bat
busybox unix2dos !dirname!/install_update.bat
md !dirname!\bin
copy bin\adb.exe !dirname!\bin\ 1>nul 2>nul
copy bin\fastboot.exe !dirname!\bin\ 1>nul 2>nul
copy bin\AdbWinApi.dll !dirname!\bin\ 1>nul 2>nul
copy bin\AdbWinUsbApi.dll !dirname!\bin\ 1>nul 2>nul
copy bin\libwinpthread-1.dll !dirname!\bin\ 1>nul 2>nul
rd /s /q tmp 1>nul 2>nul
rd /s /q config 1>nul 2>nul
echo.Enjoy your rom with fastboot flash in the folder:!dirname!
for /f "tokens=*" %%i in ('busybox date ^+%%s') do (set endTime=%%i)
for /f "tokens=*" %%i in ('echo.!endTime!-!startTime! ^|busybox bc') do (set spendTime=%%i)
echo.All done,took !spendTime! s
pause
goto EOF

:ERROR
echo.
echo.Error: - %1
echo._Tips: - %2
echo.
pause
exit

:EOF