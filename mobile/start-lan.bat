@echo off
REM Salapify v2 launcher, LAN mode (same Wi-Fi).
REM Use this if start-app.bat (tunnel mode) fails to start the tunnel.
REM Your phone and your PC must be on the SAME Wi-Fi network for this to work.

echo === Step 1 of 3: getting the latest code and installing libraries ===
git pull --ff-only
call npm install

echo.
echo === Step 2 of 3: starting auto-sync (a second window opens, leave it open) ===
start "Salapify auto-sync" cmd /c auto-pull.bat

echo.
echo === Step 3 of 3: starting the app (LAN mode, same Wi-Fi) ===
echo Make sure your phone and PC are on the SAME Wi-Fi network.
echo Scan the QR code with Expo Go one time.
echo Press Ctrl + C here to stop the app.
echo.
call npx expo start

pause
