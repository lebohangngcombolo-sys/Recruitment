# Run the Flutter app with the latest generated APP_VERSION (Ver.YYYY.MM.XYZ.ENV).
# Usage: from khono_recruite, run: .\run.ps1

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir
& powershell -ExecutionPolicy Bypass -File "scripts\flutter_run_with_version.ps1"
