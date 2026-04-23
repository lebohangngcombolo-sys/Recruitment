import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';

/// Navigation item configuration
class AdminNavItem {
  final String title;
  final String iconAsset; // Light mode icon
  final String? iconAssetDark; // Dark mode icon (optional)
  final String screen;
  final int? badgeCount;

  const AdminNavItem({
    required this.title,
    required this.iconAsset,
    this.iconAssetDark,
    required this.screen,
    this.badgeCount,
  });
}

/// Section configuration
class AdminNavSection {
  final String? title;
  final List<AdminNavItem> items;

  const AdminNavSection({this.title, required this.items});
}

/// Reusable Admin Sidebar with full dark/light mode support
class AdminSidebar extends StatelessWidget {
  final Animation<double> animation;
  final String currentScreen;
  final Function(String) onScreenChanged;
  final List<AdminNavSection> sections;
  final String userName;

  const AdminSidebar({
    super.key,
    required this.animation,
    required this.currentScreen,
    required this.onScreenChanged,
    required this.sections,
    this.userName = 'Admin User',
  });

  // Color helper methods - Unified with candidate sidebar design
  // Dark mode background: #2A2A2A, Light mode: #E6E6E8
  Color _sidebarBackground(bool isDark) =>
      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE6E6E8);

  // Sidebar border color
  Color _sidebarBorder(bool isDark) =>
      isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);

  // Primary text color
  Color _onSurface(bool isDark) => isDark ? Colors.white : Colors.black;

  // Muted/secondary text color
  Color _onSurfaceMuted(bool isDark) =>
      isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.7);

  // Hairline divider color
  Color _hairline(bool isDark) => isDark ? Colors.white24 : Colors.black26;

  // Selected item background
  Color _selectedBg(bool isDark) => const Color(0xFFC10D00);

  // Menu item label color
  Color _sideItemLabel(bool isDark, bool isActive) {
    if (isActive) return Colors.white;
    return isDark
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.black.withValues(alpha: 0.85);
  }

  static const Color _primaryColor = Color(0xFFCF2030);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: 192,
          decoration: BoxDecoration(
            color: _sidebarBackground(isDark),
            border: Border(
              right: BorderSide(
                color: _sidebarBorder(isDark),
              ),
            ),
          ),
          child: Column(
            children: [
              // Header
              _buildHeader(isDark),

              // Navigation Items
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: sections
                        .map((section) => _buildSection(section, isDark))
                        .toList(),
                  ),
                ),
              ),

              // Footer
              _buildFooter(isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(top: 24, bottom: 16),
          child: Column(
            children: [
              if (true) ...[
                // Brand
                Image.asset(
                  'assets/icons/Dashboard/khono.png',
                  width: 181,
                  height: 34,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                // Welcome message
                Text(
                  'Welcome to\nAutomated Recruitment Workflow',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 9.27,
                    fontWeight: FontWeight.w600,
                    color: _onSurface(isDark),
                    height: 1.08,
                    letterSpacing: 0.01,
                    fontFeatures: const [FontFeature('smcp')],
                  ),
                ),
              ],
            ],
          ),
        ),
        // Hairline divider like candidate sidebar
        Container(
          margin: EdgeInsets.zero,
          child: Container(
            height: 1,
            color: _hairline(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(AdminNavSection section, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.title != null) ...[
          Padding(
            padding: EdgeInsets.zero,
            child: Text(
              section.title!,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9.86,
                fontWeight: FontWeight.w600,
                color: _onSurfaceMuted(isDark),
                fontFeatures: const [FontFeature('smcp')],
              ),
            ),
          ),
        ],
        ...section.items.map((item) => _buildNavItem(item, isDark)),
      ],
    );
  }

  Widget _buildNavItem(AdminNavItem item, bool isDark) {
    final isSelected = currentScreen == item.screen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onScreenChanged(item.screen),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 31,
          padding: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: isSelected ? _selectedBg(isDark) : Colors.transparent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3.69),
              bottomLeft: Radius.circular(3.69),
            ),
          ),
          child: Row(
            children: [
              _buildIcon(item, isSelected, isDark, item.badgeCount),
              if (true) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9.86,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: _sideItemLabel(isDark, isSelected),
                      fontFeatures: const [FontFeature('smcp')],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(
      AdminNavItem item, bool isSelected, bool isDark, int? badgeCount) {
    // Choose appropriate icon asset based on theme
    final String assetToUse = isDark && item.iconAssetDark != null
        ? item.iconAssetDark!
        : item.iconAsset;

    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        children: [
          Image.asset(
            assetToUse,
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
          if (badgeCount != null && badgeCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Column(
      children: [
        // Divider
        Divider(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade300,
          height: 1,
          indent: 0,
          endIndent: 0,
        ),
        const SizedBox(height: 0),
        // Account Profile
        _buildNavItem(
          AdminNavItem(
            title: 'Account Profile',
            iconAsset: 'assets/icons/Dashboard/account_profile.png',
            screen: 'profile',
          ),
          isDark,
        ),
        // Logout
        Padding(
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onScreenChanged('logout'),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3.69),
                bottomLeft: Radius.circular(3.69),
              ),
              child: Container(
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3.69),
                    bottomLeft: Radius.circular(3.69),
                  ),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icons/Dashboard/logout.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                    if (true) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Logout',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9.86,
                            fontWeight: FontWeight.w500,
                            color: _sideItemLabel(isDark, false),
                            fontFeatures: const [FontFeature('smcp')],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 0),
      ],
    );
  }
}
