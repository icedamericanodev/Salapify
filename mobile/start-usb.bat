@echo off
REM Salapify v2 USB launcher. Use this when your phone is plugged in by cable,
REM USB debugging is ON, and the phone is in File transfer mode.
REM This connects the app over the cable, so it does not depend on Wi-Fi.

set ADB=C:\Users\carla\platform-tools\adb.exe

echo === Checking the phone is connected ===
"%ADB%" devices
echo.
echo If you do NOT see your phone with the word "device" next to it above,
echo look at your phone for an "Allow USB debugging" popup and tap Allow,
echo then close this window and double-click this file again.
echo.

echo === Linking the phone to the PC over the cable ===
"%ADB%" reverse tcp:8081 tcp:8081

echo === Getting the latest code and installing libraries ===
git pull --ff-only
call npm install

echo === Starting auto-sync (a second window opens, leave it open) ===
start "Salapify auto-sync" cmd /c auto-pull.bat

echo.
echo === Starting the app over USB ===
echo IMPORTANT: do NOT scan a QR code this time.
echo When the menu appears below, press the letter  a  in this window.
echo That opens the app on your plugged-in phone.
echo.
call npx expo start

pause
