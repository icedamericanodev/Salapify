@echo off
REM Salapify v2 WEB PREVIEW. Runs the app in your PC's web browser.
REM No phone, no Expo Go, no Wi-Fi, no cable. The easiest way to see the app.
REM Note: phone-only features (notifications, fingerprint, camera) do not work
REM in a browser, but all the screens and layout do.

echo === Step 1 of 3: getting the latest code and installing libraries ===
git pull --ff-only
call npm install

echo.
echo === Step 2 of 3: starting auto-sync (a second window opens, leave it open) ===
start "Salapify auto-sync" cmd /c auto-pull.bat

echo.
echo === Step 3 of 3: opening the app in your web browser ===
echo A browser tab should open at  http://localhost:8081
echo If it does not open by itself, open that address in Chrome or Edge.
echo Press Ctrl + C here to stop.
echo.
call npx expo start --web

pause
