/// Build-time app version (Ver.YYYY.MM.XYZ.ENV). Set via --dart-define=APP_VERSION=... in build.
/// In local runs without --dart-define, we fall back to a synthetic local-only value.
const String kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  // Local-only fallback when no build-time APP_VERSION is provided.
  // This intentionally does not look like a real dated build stamp.
  defaultValue: 'Ver.0.0.0.LOCAL',
);
