import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/brand_tokens.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme(); // Load saved preference when the provider initializes
  }

  /// Toggle between light and dark mode
  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners(); // Notify UI immediately for animation

    // Save preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  /// Load saved theme from storage
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  ThemeData get themeData => _isDarkMode ? darkTheme : lightTheme;

  /// 🌆 Dynamic background image based on theme
  String get backgroundImage =>
      _isDarkMode ? 'assets/images/dark.png' : 'assets/images/light_mode_bg.png';

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
