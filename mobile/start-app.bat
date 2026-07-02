@echo off
REM Salapify v2 launcher for Windows. Double-click this file once.
REM It does everything for you:
REM   1) downloads the latest code and installs anything new
REM   2) opens a small auto-sync window that keeps pulling Claude's changes,
REM      so new edits appear on your phone by themselves (Fast Refresh)
REM   3) starts the app in tunnel mode and shows a QR code
REM You scan the QR with Expo Go one time. After that, just leave it running.

echo === Step 1 of 3: getting the latest code and installing libraries ===
git pull --ff-only
call npm install

echo.
echo === Step 2 of 3: starting auto-sync (a second window opens, leave it open) ===
start "Salapify auto-sync" cmd /c auto-pull.bat

echo.
echo === Step 3 of 3: starting the app in tunnel mode ===
echo Scan the QR code with Expo Go one time.
echo After that you are done: Claude's changes refresh on your phone by themselves.
echo Press Ctrl + C here to stop the app. Close the auto-sync window to stop updates.
echo.
call npx expo start --tunnel

pause
