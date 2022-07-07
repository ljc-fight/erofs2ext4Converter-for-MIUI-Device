@echo off
title FATSBOOT FlashScript
setlocal enabledelayedexpansion
for /f "delims=" %%i in ('platform-tools\busybox ls images ^|platform-tools\busybox grep -v super ^|platform-tools\busybox grep -v preloader ^|platform-tools\busybox cut -d "." -f 1') do (
set partitionName=%%i
platform-tools\fastboot flash !partitionName!_ab images/!partitionName!.img
)
if exist images\preloader_raw.img (
	platform-tools\fastboot flash preloader1 images/preloader_raw.img
	platform-tools\fastboot flash preloader2 images/preloader_raw.img
)
if exist images\super.img (
	platform-tools\fastboot flash super images/super.img
)
bin\fastboot erase userdata
bin\fastboot erase metadata
bin\fastboot set_active a
bin\fastboot reboot
pause