import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class PillSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool enabled;
  final FocusNode? focusNode;

  const PillSearchBar({
    super.key,
    this.hintText = "Search...",
    this.onChanged,
    this.controller,
    this.enabled = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: (themeProvider.isDarkMode
            ? const Color(0xFF14131E)
            : Colors.white.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: themeProvider.isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: themeProvider.isDarkMode
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontFamily: 'Poppins',
            color: themeProvider.isDarkMode
                ? Colors.grey.shade400
                : Colors.grey.shade700,
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Image.asset(
              'assets/images/SearchRed.png',
              width: 30,
              height: 30,
            ),
          ),
          filled: false,
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(40),
          ),
          contentPadding: const EdgeInsets.symmetric(
              vertical: 14, horizontal: 10),
        ),
        cursorColor: Colors.redAccent,
        style: TextStyle(
          fontFamily: 'Poppins',
          color: themeProvider.isDarkMode
              ? Colors.white
              : Colors.black.withValues(alpha: 0.8),
          fontSize: 14,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
