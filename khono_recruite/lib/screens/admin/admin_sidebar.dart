import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

/// Modular admin sidebar component
class AdminSidebar extends StatelessWidget {
  final bool collapsed;
  final Animation<double> animation;
  final String currentScreen;
  final Function(String) onScreenChanged;
  final VoidCallback onToggleSidebar;

  const AdminSidebar({
    super.key,
    required this.collapsed,
    required this.animation,
    required this.currentScreen,
    required this.onScreenChanged,
    required this.onToggleSidebar,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: animation.value,
          decoration: BoxDecoration(
            color:
                themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
            border: Border(
              right: BorderSide(
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade800
                    : Colors.grey.shade200,
              ),
            ),
          ),
          child: Column(
            children: [
              // Header
              _buildHeader(themeProvider),

              // Navigation Items
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildNavigationSection(
                        title: collapsed ? null : 'Main',
                        items: _getMainNavigationItems(),
                        themeProvider: themeProvider,
                      ),
                      _buildNavigationSection(
                        title: collapsed ? null : 'Management',
                        items: _getManagementNavigationItems(),
                        themeProvider: themeProvider,
                      ),
                      _buildNavigationSection(
                        title: collapsed ? null : 'Analytics',
                        items: _getAnalyticsNavigationItems(),
                        themeProvider: themeProvider,
                      ),
                      _buildNavigationSection(
                        title: collapsed ? null : 'Settings',
                        items: _getSettingsNavigationItems(),
                        themeProvider: themeProvider,
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              _buildFooter(themeProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: themeProvider.isDarkMode
                ? Colors.grey.shade800
                : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!collapsed) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFC10D00),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Admin Panel',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ] else
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFC10D00),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 20,
              ),
            ),
          IconButton(
            onPressed: onToggleSidebar,
            icon: Icon(
              collapsed ? Icons.expand_more : Icons.expand_less,
              size: 20,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationSection({
    required String? title,
    required List<NavigationItem> items,
    required ThemeProvider themeProvider,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),
          ),
        ],
        ...items.map((item) => _buildNavigationItem(item, themeProvider)),
      ],
    );
  }

  Widget _buildNavigationItem(
      NavigationItem item, ThemeProvider themeProvider) {
    final isSelected = currentScreen == item.screen;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onScreenChanged(item.screen),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFC10D00).withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected
                      ? const Color(0xFFC10D00)
                      : themeProvider.isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFFC10D00)
                            : themeProvider.isDarkMode
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: themeProvider.isDarkMode
                ? Colors.grey.shade800
                : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        children: [
          if (!collapsed) ...[
            Text(
              'Khono Recruit',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Admin Dashboard v1.0',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade500
                    : Colors.grey.shade500,
              ),
            ),
          ] else
            Icon(
              Icons.admin_panel_settings,
              size: 20,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
            ),
        ],
      ),
    );
  }

  List<NavigationItem> _getMainNavigationItems() {
    return [
      NavigationItem(
        title: 'Dashboard',
        icon: Icons.dashboard_outlined,
        screen: 'dashboard',
      ),
      NavigationItem(
        title: 'Candidates',
        icon: Icons.people_outline,
        screen: 'candidates',
      ),
      NavigationItem(
        title: 'Jobs',
        icon: Icons.work_outline,
        screen: 'jobs',
      ),
      NavigationItem(
        title: 'Applications',
        icon: Icons.description_outlined,
        screen: 'applications',
      ),
    ];
  }

  List<NavigationItem> _getManagementNavigationItems() {
    return [
      NavigationItem(
        title: 'Interviews',
        icon: Icons.calendar_today_outlined,
        screen: 'interviews',
      ),
      NavigationItem(
        title: 'Offers',
        icon: Icons.card_giftcard_outlined,
        screen: 'offers',
      ),
      NavigationItem(
        title: 'CV Reviews',
        icon: Icons.rate_review_outlined,
        screen: 'cv_reviews',
      ),
      NavigationItem(
        title: 'Test Packs',
        icon: Icons.quiz_outlined,
        screen: 'test_packs',
      ),
    ];
  }

  List<NavigationItem> _getAnalyticsNavigationItems() {
    return [
      NavigationItem(
        title: 'Analytics',
        icon: Icons.analytics_outlined,
        screen: 'analytics',
      ),
      NavigationItem(
        title: 'Reports',
        icon: Icons.assessment_outlined,
        screen: 'reports',
      ),
      NavigationItem(
        title: 'Pipeline',
        icon: Icons.account_tree_outlined,
        screen: 'pipeline',
      ),
    ];
  }

  List<NavigationItem> _getSettingsNavigationItems() {
    return [
      NavigationItem(
        title: 'Users',
        icon: Icons.manage_accounts_outlined,
        screen: 'users',
      ),
      NavigationItem(
        title: 'Settings',
        icon: Icons.settings_outlined,
        screen: 'settings',
      ),
      NavigationItem(
        title: 'Profile',
        icon: Icons.person_outline,
        screen: 'profile',
      ),
    ];
  }
}

class NavigationItem {
  final String title;
  final IconData icon;
  final String screen;

  NavigationItem({
    required this.title,
    required this.icon,
    required this.screen,
  });
}
