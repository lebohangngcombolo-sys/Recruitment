import 'package:flutter/foundation.dart' show kIsWeb;

/// Default production API URL when app is served from Render (web) and not built with BACKEND_URL.
/// Set BACKEND_URL on recruitment-web and redeploy to override at build time.
const String _productionApiBase = 'https://recruitment-api-zovg.onrender.com';

class AppConfig {
  /// API base URL. Compile-time via --dart-define=API_BASE, or runtime fallback when on web and not localhost.
  /// Example: flutter run --dart-define=API_BASE="https://api.example.com"
  static String get apiBase {
    if (kIsWeb &&
        Uri.base.host != 'localhost' &&
        Uri.base.host != '127.0.0.1' &&
        Uri.base.host.isNotEmpty) {
      return _productionApiBase;
    }
    return const String.fromEnvironment(
      'API_BASE',
      defaultValue: 'http://127.0.0.1:5000',
    );
  }

  /// Public API base (e.g. jobs listing). Same logic as apiBase.
  static String get publicApiBase {
    if (kIsWeb &&
        Uri.base.host != 'localhost' &&
        Uri.base.host != '127.0.0.1' &&
        Uri.base.host.isNotEmpty) {
      return _productionApiBase;
    }
    return const String.fromEnvironment(
      'PUBLIC_API_BASE',
      defaultValue: 'http://127.0.0.1:5000',
    );
  }
}

/// Replace local hardcoded localhost URLs with configured values.
String localhostToEnv(String url) {
  return url
      .replaceAll('http://127.0.0.1:5000', AppConfig.apiBase)
      .replaceAll('http://127.0.0.1:5000', AppConfig.publicApiBase);
}
