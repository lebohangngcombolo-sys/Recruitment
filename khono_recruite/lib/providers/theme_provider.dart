import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      _isDarkMode ? 'assets/images/dark.png' : 'assets/images/final.jpg';

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
    primaryColor: const Color(0xFF971208),
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF971208),
      secondary: const Color(0xFFCF2030),
    ),
    scaffoldBackgroundColor: const Color(0xFFF8F8F8),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF971208),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF971208),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF971208),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
  );

  // Dark Theme
  final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF14131E),
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF14131E),
      secondary: const Color(0xFF272A3D),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF14131E),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF14131E),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF14131E),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
  );
}
