@echo off
title Millida Complete Cleaner
cd /d "%~dp0"
echo ========================================================
echo          MILLIDA COMPLETE CLEANER
echo            Developer: Seiiertags
echo            Telegram: https://t.me/JesterCoderi
echo ========================================================
echo.
echo Launching cleanup script...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0MillidaCleaner.ps1"
echo.
pause