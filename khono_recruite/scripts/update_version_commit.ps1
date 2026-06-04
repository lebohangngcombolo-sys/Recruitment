# Update app_version_generated.dart and commit it so branches that pull from dev_main
# get the latest version and plain "flutter run" displays it.
# Run from khono_recruite/ (e.g. after merging to dev_main). Best run on dev_main.

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$khonoRoot = Split-Path -Parent $scriptDir
Set-Location $khonoRoot

# Refresh the generated version file
& powershell -ExecutionPolicy Bypass -File "$scriptDir\update_version_file.ps1"
if (-not $?) { exit 1 }

$versionFile = "lib\utils\app_version_generated.dart"
$versionFilePath = Join-Path $khonoRoot $versionFile
if (-not (Test-Path $versionFilePath)) {
    Write-Error "Version file not found: $versionFilePath"
    exit 1
}

# Commit from git repo root (works whether repo root is khono_recruite or its parent)
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    Write-Error "Not inside a git repository."
    exit 1
}
Set-Location $repoRoot
$relPath = if (Test-Path (Join-Path $repoRoot "khono_recruite")) {
    "khono_recruite/lib/utils/app_version_generated.dart"
} else {
    "lib/utils/app_version_generated.dart"
}
git add $relPath
$status = git status --short $relPath 2>$null
if ($status -match '^[AM]') {
    git commit -m "chore: update app version stamp (for branches that pull from dev_main)"
    Write-Host "Committed $relPath. Push to dev_main so other branches get this version when they pull."
} else {
    Write-Host "No change in version file; nothing to commit."
}
