# Khono Recruite

Flutter recruitment app with modern red & white UI and authentication flow.

## Running the app (with latest version)

To run the app **with the latest generated version** (Ver.YYYY.MM.XYZ.ENV) in the UI:

- **Windows (PowerShell):** From this directory run `.\run.ps1`
- **Windows (Command Prompt):** From this directory run `run.bat`
- **IDE:** Run the task **"Run Flutter (with version)"** (Command Palette → Tasks: Run Task)

**Version when other branches pull from dev_main:** The file `lib/utils/app_version_generated.dart` is committed on `dev_main` with the current version. When you pull from `dev_main` into another branch, you get that file, so **plain `flutter run`** on your branch displays the latest dev_main version. On `dev_main`, after merging or before pushing, run `scripts\update_version_commit.ps1` (Windows) or `scripts/update_version_commit.sh` (Linux/macOS) to refresh the version and commit it so that everyone who pulls from dev_main sees the updated version.

Plain `flutter run` (without the run script) shows the version from `lib/utils/app_version_generated.dart`; if that file was never updated on your branch, you see `Ver.0.0.0.LOCAL`. To refresh it without committing, run `scripts/update_version_file.ps1` (Windows) or `scripts/update_version_file.sh` (Linux/macOS). The backend runs on port 5000 by default; the run script uses `http://127.0.0.1:5000` for the API.
