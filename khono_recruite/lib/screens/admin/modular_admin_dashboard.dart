import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/admin_state_provider.dart';
import 'dashboard_stats_section.dart';
import 'recent_activities_section.dart';
import 'audit_logs_section.dart';
import 'powerbi_status_section.dart';
import 'admin_sidebar.dart';

/// Modular admin dashboard that breaks down the large monolithic component
class ModularAdminDashboard extends StatefulWidget {
  final String token;

  const ModularAdminDashboard({super.key, required this.token});

  @override
  _ModularAdminDashboardState createState() => _ModularAdminDashboardState();
}

class _ModularAdminDashboardState extends State<ModularAdminDashboard>
    with SingleTickerProviderStateMixin {
  String currentScreen = "dashboard";
  bool sidebarCollapsed = false;
  late final AnimationController _sidebarAnimController;
  late final Animation<double> _sidebarWidthAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInitialData();
  }

  void _initializeAnimations() {
    _sidebarAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _sidebarWidthAnimation = Tween<double>(
      begin: 250,
      end: 60,
    ).animate(CurvedAnimation(
      parent: _sidebarAnimController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _loadInitialData() async {
    final adminProvider =
        Provider.of<AdminStateProvider>(context, listen: false);
    await Future.wait([
      adminProvider.fetchDashboardStats(),
      adminProvider.fetchRecentActivities(),
      adminProvider.checkPowerBIStatus(),
    ]);
  }

  @override
  void dispose() {
    _sidebarAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final adminProvider = Provider.of<AdminStateProvider>(context);

    return Scaffold(
      backgroundColor:
          themeProvider.isDarkMode ? Colors.black : Colors.grey.shade50,
      body: Row(
        children: [
          // Sidebar
          AdminSidebar(
            collapsed: sidebarCollapsed,
            animation: _sidebarWidthAnimation,
            currentScreen: currentScreen,
            onScreenChanged: (screen) => setState(() => currentScreen = screen),
            onToggleSidebar: () {
              setState(() => sidebarCollapsed = !sidebarCollapsed);
              if (sidebarCollapsed) {
                _sidebarAnimController.forward();
              } else {
                _sidebarAnimController.reverse();
              }
            },
          ),

          // Main Content
          Expanded(
            child: _buildMainContent(adminProvider, themeProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
      AdminStateProvider adminProvider, ThemeProvider themeProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(themeProvider),
          const SizedBox(height: 24),

          // Dashboard Content
          if (currentScreen == "dashboard") ...[
            // Statistics Section
            DashboardStatsSection(
              isLoading: adminProvider.isLoadingDashboard,
              stats: adminProvider.dashboardStats,
              onRefresh: () => adminProvider.fetchDashboardStats(),
            ),
            const SizedBox(height: 24),

            // PowerBI Status Section
            PowerBIStatusSection(
              isConnected: adminProvider.powerBIConnected,
              isChecking: adminProvider.checkingPowerBI,
              onRefresh: () => adminProvider.checkPowerBIStatus(),
            ),
            const SizedBox(height: 24),

            // Recent Activities Section
            RecentActivitiesSection(
              activities: adminProvider.recentActivities,
              isLoading: adminProvider.isLoadingDashboard,
              onViewAll: () {
                // Navigate to full activities view
              },
            ),
            const SizedBox(height: 24),

            // Audit Logs Section
            AuditLogsSection(
              isLoading: adminProvider.isLoadingAuditLogs,
              onRefresh: () => adminProvider.fetchAuditLogs(),
            ),
          ] else
            _buildOtherScreens(currentScreen),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Dashboard',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Welcome back! Here\'s what\'s happening today.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: _loadInitialData,
              icon: Icon(
                Icons.refresh,
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFC10D00).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 16,
                    color: const Color(0xFFC10D00),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Admin',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFC10D00),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOtherScreens(String screen) {
    // This would contain other screen implementations
    // For now, return a placeholder
    return Container(
      height: 400,
      child: Center(
        child: Text(
          '$screen screen coming soon...',
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
