@echo off
path=%PATH%;%CD%\bin
rem


if exist images\preloader_raw.img (
	fastboot flash preloader_a images/preloader_raw.img 1>nul 2>nul
	fastboot flash preloader_b images/preloader_raw.img 1>nul 2>nul
	fastboot flash preloader1 images/preloader_raw.img 1>nul 2>nul
	fastboot flash preloader2 images/preloader_raw.img 1>nul 2>nul
)


fastboot set_active a
fastboot reboot

pause