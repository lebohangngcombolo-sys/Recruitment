# Run Flutter web locally with generated APP_VERSION (Ver.YYYY.MM.XYZ.ENV).
# Usage: from khono_recruite, run: powershell -ExecutionPolicy Bypass -File scripts\flutter_run_with_version.ps1
# Or from repo root: powershell -ExecutionPolicy Bypass -File khono_recruite\scripts\flutter_run_with_version.ps1

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$khonoRoot = Split-Path -Parent $scriptDir
Set-Location $khonoRoot

$apiBase = if ($env:API_BASE) { $env:API_BASE } elseif ($env:BACKEND_URL) { $env:BACKEND_URL } else { "http://127.0.0.1:5000" }
$publicBase = if ($env:PUBLIC_API_BASE) { $env:PUBLIC_API_BASE } else { $apiBase }

# Refresh lib/utils/app_version_generated.dart so plain flutter run shows correct version too
& powershell -ExecutionPolicy Bypass -File "$khonoRoot\scripts\update_version_file.ps1" | Out-Null
$appVersion = & python "scripts\generate_version.py" 2>$null
if (-not $appVersion) { $appVersion = "Ver.0.0.0.LOCAL" }
Write-Host "Running Flutter web with API_BASE=$apiBase APP_VERSION=$appVersion"

flutter run -d chrome --dart-define=API_BASE="$apiBase" --dart-define=PUBLIC_API_BASE="$publicBase" --dart-define=APP_VERSION="$appVersion"
