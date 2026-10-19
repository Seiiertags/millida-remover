@echo off
title Millida Deep Hunter
cd /d "%~dp0"
echo ========================================================
echo          MILLIDA DEEP HUNTER AND REMOVER
echo            Developer: Seiiertags
echo            Telegram: https://t.me/JesterCoderi
echo ========================================================
echo.
echo Launching deep audit and remover...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0MillidaHunter.ps1"
echo.
pause