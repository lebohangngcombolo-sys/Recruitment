@echo off
REM Run the Flutter app with the latest generated APP_VERSION.
REM Usage: from khono_recruite, run: run.bat
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "scripts\flutter_run_with_version.ps1"
