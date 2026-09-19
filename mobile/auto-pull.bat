@echo off
REM Salapify v2 auto-sync window.
REM This quietly downloads Claude's latest changes every 15 seconds while you
REM work, so edits appear on your phone by themselves through Fast Refresh.
REM It is started automatically by start-app.bat. Leave it open. Close it to
REM stop auto-updating.

title Salapify auto-sync (leave this open)
echo Salapify auto-sync is running.
echo It downloads Claude's latest changes every 15 seconds.
echo Leave this window open. Close it to stop auto-updating.
echo.

:loop
git pull --ff-only >nul 2>&1
timeout /t 15 /nobreak >nul
goto loop
