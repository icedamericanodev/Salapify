@echo off
REM Salapify v2 helper for Windows.
REM This does the whole routine in one go:
REM   1) pull the latest code from GitHub
REM   2) install any new libraries
REM   3) start the app
REM You can double click this file, or type start-app.bat in the mobile folder.

echo.
echo === Step 1 of 3: getting the latest code ===
git pull

echo.
echo === Step 2 of 3: installing libraries (safe to run every time) ===
call npm install

echo.
echo === Step 3 of 3: starting the app ===
echo When the QR code appears, scan it with Expo Go.
echo Press Ctrl + C here to stop the app later.
echo.
call npx expo start

REM Keep the window open if something stops early, so you can read any message.
pause
