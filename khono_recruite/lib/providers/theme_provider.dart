import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/brand_tokens.dart';

/// Persistent app brightness (survives logout; auth clears other prefs only).
const String kThemeModePrefKey = 'khono_theme_mode';
const String kLegacyIsDarkPrefKey = 'isDarkMode';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode;
  bool get isDarkMode => _isDarkMode;

  /// [initialIsDark] should match disk (set from [loadSavedIsDark] in [main]).
  ThemeProvider({required bool initialIsDark}) : _isDarkMode = initialIsDark {
    _reconcileWithDisk();
  }

  /// Read saved theme before [runApp] so the first frame matches preference.
  static Future<bool> loadSavedIsDark() async {
    final prefs = await SharedPreferences.getInstance();
    return _readIsDarkFromPrefs(prefs);
  }

  static bool _readIsDarkFromPrefs(SharedPreferences prefs) {
    final mode = prefs.getString(kThemeModePrefKey)?.toLowerCase().trim();
    if (mode == 'dark') return true;
    if (mode == 'light') return false;
    return prefs.getBool(kLegacyIsDarkPrefKey) ?? false;
  }

  Future<void> _writeTheme(bool dark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kThemeModePrefKey, dark ? 'dark' : 'light');
    await prefs.setBool(kLegacyIsDarkPrefKey, dark);
  }

  /// Migration: copy legacy bool → string key; keep both keys aligned.
  Future<void> _reconcileWithDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final disk = _readIsDarkFromPrefs(prefs);
    if (disk != _isDarkMode) {
      _isDarkMode = disk;
      notifyListeners();
    }
    await _writeTheme(_isDarkMode);
  }

  /// Toggle between light and dark mode
  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    await _writeTheme(_isDarkMode);
  }

  ThemeData get themeData => _isDarkMode ? darkTheme : lightTheme;

  /// 🌆 Dynamic background image based on theme
  String get backgroundImage => _isDarkMode
      ? 'assets/images/dark.png'
      : 'assets/icons/niice_wrld_white_bg.png';

  // Consistent text colors across the app
  Color get headerTextColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get bodyTextColor => _isDarkMode ? Colors.white70 : Colors.black54;
  Color get subtitleTextColor =>
      _isDarkMode ? Colors.white60 : Colors.grey.shade600;
  Color get accentTextColor => _isDarkMode ? Colors.white : Colors.black87;

  // Consistent text styles
  TextStyle get headerTextStyle => TextStyle(
        color: headerTextColor,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      );

  TextStyle get subHeaderTextStyle => TextStyle(
        color: headerTextColor,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  TextStyle get bodyTextStyle => TextStyle(
        color: bodyTextColor,
        fontSize: 14,
      );

  // Light Theme
  final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: BrandTokens.primary,
    colorScheme: ColorScheme.light(
      primary: BrandTokens.primary,
      secondary: BrandTokens.primaryDeep,
    ),
    scaffoldBackgroundColor: const Color(0xFFF8F8F8),
    appBarTheme: AppBarTheme(
      backgroundColor: BrandTokens.primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: BrandTokens.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BrandTokens.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(BrandTokens.buttonRadius)),
        ),
      ),
    ),
  );

  // Dark Theme
  final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: BrandTokens.primaryDeep,
    colorScheme: ColorScheme.dark(
      primary: BrandTokens.primaryDeep,
      secondary: BrandTokens.darkSurface,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: AppBarTheme(
      backgroundColor: BrandTokens.primaryDeep,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: BrandTokens.primaryDeep,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BrandTokens.primaryDeep,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(BrandTokens.buttonRadius)),
        ),
      ),
    ),
  );
}
