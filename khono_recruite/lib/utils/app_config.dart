class AppConfig {
  /// Compile-time configuration via --dart-define.
  /// Example: flutter run --dart-define=API_BASE="https://api.example.com"
  static const String apiBase =
      String.fromEnvironment('API_BASE', defaultValue: 'http://127.0.0.1:5001');

  /// Public API base (e.g. jobs listing). Defaults to same as apiBase so one server serves both.
  static const String publicApiBase =
      String.fromEnvironment('PUBLIC_API_BASE', defaultValue: 'http://127.0.0.1:5001');
}

/// Replace local hardcoded localhost URLs with configured values.
String localhostToEnv(String url) {
  return url
      .replaceAll('http://127.0.0.1:5001', AppConfig.apiBase)
      .replaceAll('http://127.0.0.1:5000', AppConfig.publicApiBase);
}

