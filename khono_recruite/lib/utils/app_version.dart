import 'package:flutter/material.dart';

import 'app_version_generated.dart';

/// Build-time app version (Ver.YYYY.MM.XYZ.ENV). Set via --dart-define=APP_VERSION=... in build.
/// When not set, [kDisplayVersion] uses [kGeneratedAppVersion] from app_version_generated.dart.
const String kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'Ver.0.0.0.LOCAL',
);

/// Version string to show in the UI. Prefers build-time APP_VERSION; else the generated file.
String get kDisplayVersion =>
    kAppVersion != 'Ver.0.0.0.LOCAL' ? kAppVersion : kGeneratedAppVersion;

/// Widget that displays the current app version (generated format Ver.YYYY.MM.XYZ.ENV).
class AppVersionText extends StatelessWidget {
  const AppVersionText({super.key, this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(kDisplayVersion, style: style);
  }
}
