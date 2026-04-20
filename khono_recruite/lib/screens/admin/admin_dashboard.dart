import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/unified_api_service.dart';
import '../../services/notification_service.dart';
import '../../services/cache_service.dart';
import '../../services/websocket_service.dart';
import '../../utils/api_endpoints.dart';
import '../../constants/brand_tokens.dart';
import 'candidate_management_screen.dart';
import 'cv_reviews_screen.dart';
import 'hm_team_collaboration_page.dart';
import 'candidate_list_screen.dart';
import 'interviews_list_screen.dart';
import '../notifications/notifications_screen.dart';
import 'job_management.dart';
import 'test_pack_management_screen.dart';
import 'user_management_screen.dart';
import '../../providers/theme_provider.dart';
import 'analytics_dashboard.dart';
import 'offer_list_screen.dart';
import 'pipeline_page.dart';
import 'admin_settings_screen.dart';
import 'profile_page.dart';
import '../../features/dashboard/dashboard_overview.dart';

// HM Color Palette
class _AdminPalette {
  static const Color primary = Color(0xFFCF2030);
  static const Color charcoal = Color(0xFF3D3F40);
  static const Color canvas = Color(0xFFF8F6F3);
  static const Color sidebarBackground = Color(0xFF3D3F40);
  static const Color scaffoldBackground = Color(0xFF0C0807);

  /// Dark mode: #3D3F40 ([charcoal]) at 60% so the background image shows through.
  static Color _darkWidgetSurface() => charcoal.withValues(alpha: 0.6);

  /// Light mode: #F8F6F3 ([canvas]) at 95% for slight transparency.
  static Color _lightWidgetSurface() => canvas.withValues(alpha: 0.95);
}

/// Normalizes shorthand paths (`images/…`, `icons/…`) to full pubspec keys.
String _adminNormalizeAssetPath(String path) {
  final p = path.trim();
  if (p.startsWith('assets/')) return p;
  if (p.startsWith('images/')) return 'assets/$p';
  if (p.startsWith('icons/')) return 'assets/$p';
  return p;
}

/// On Flutter web, [Image.asset] sometimes requests `assets/assets/…` and returns 404.
/// We load via [Image.network] using the **host root**, not [Uri.base.path] (e.g. `/login`),
/// otherwise the server returns HTML (`<!DOCTYPE…`) and decoding fails with [ImageCodecException].
Widget _adminDashboardAssetImage(
  String assetPath, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  final path = _adminNormalizeAssetPath(assetPath);
  if (kIsWeb) {
    final noLeading = path.startsWith('/') ? path.substring(1) : path;
    final url = '${Uri.base.origin}/$noLeading';
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }
  return Image.asset(
    path,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}

class AdminDashboard extends StatefulWidget {
  final String token;
  const AdminDashboard({super.key, required this.token});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  String currentScreen = "dashboard";
  bool loadingStats = true;

  int jobsCount = 0;
  int candidatesCount = 0;
  int interviewsCount = 0;
  int cvReviewsCount = 0;
  int auditsCount = 0;

  // Enhanced metrics
  int activeJobs = 0;
  int candidatesWithCV = 0;
  int upcomingInterviews = 0;
  int newApplicationsWeek = 0;
  int offeredApplications = 0;
  int acceptedOffers = 0;

  int? selectedJobId;

  // Calendar state
  DateTime focusedDay = DateTime.now();
  DateTime selectedDay = DateTime.now();

  final AdminService admin = AdminService();

  List<String> recentActivities = [];

  int unreadNotificationCount = 0;

  Timer? _statusTimer;

  // --- Audits ---
  List<Map<String, dynamic>> audits = [];
  List<_ChartData> auditTrendData = [];
  int auditPage = 1;
  int auditPerPage = 20;
  String? auditActionFilter;
  DateTime? auditStartDate;
  DateTime? auditEndDate;
  String? auditSearchQuery;
  bool loadingAudits = true;

  // Notifications for dashboard widget (status changes + upcoming interviews)
  List<Map<String, dynamic>> dashboardNotifications = [];
  bool loadingNotifications = false;

  TextEditingController auditSearchController = TextEditingController();
  DateTime? filterStartDate;
  DateTime? filterEndDate;
  String? filterAction;

  final List<String> auditActions = [
    "login",
    "logout",
    "create",
    "update",
    "delete"
  ];

  // Calendar appointments (interviews + meetings)
  List<Appointment> _calendarAppointments = [];
  bool _calendarLoading = false;

  @override
  void initState() {
    super.initState();
    _bootstrapAuthFromToken();
    fetchStats();
    fetchAudits(page: 1);
    fetchDashboardNotifications();
    _loadCalendarData();

    _statusTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      // Periodic tasks can be added here
    });

    // Setup WebSocket listeners for real-time dashboard updates
    _setupWebSocketListeners();
  }

  /// Setup WebSocket event listeners for real-time dashboard updates
  void _setupWebSocketListeners() {
    final wsService = WebSocketService();

    // Subscribe to dashboard events
    final userId = AuthService.getUserInfo().toString();
    wsService.subscribeToDashboard(userId, role: 'admin');

    // Handle interview created events
    wsService.onInterviewCreated = (data) {
      if (!mounted) return;
      debugPrint('📊 Real-time: Interview created - $data');
      setState(() {
        interviewsCount++;
        upcomingInterviews++;
        // Add to calendar appointments
        final appointment = _parseInterviewToAppointment(data);
        if (appointment != null) {
          _calendarAppointments.add(appointment);
        }
      });
      _showRealTimeNotification('New interview scheduled');
    };

    // Handle interview updated events
    wsService.onInterviewUpdated = (data) {
      if (!mounted) return;
      debugPrint('📊 Real-time: Interview updated - $data');
      _updateCalendarAppointment(data);
    };

    // Handle interview deleted events
    wsService.onInterviewDeleted = (data) {
      if (!mounted) return;
      debugPrint('📊 Real-time: Interview deleted - $data');
      final interviewId = data['id'];
      setState(() {
        interviewsCount = (interviewsCount > 0) ? interviewsCount - 1 : 0;
        upcomingInterviews =
            (upcomingInterviews > 0) ? upcomingInterviews - 1 : 0;
        _calendarAppointments.removeWhere((a) =>
            a.subject.contains('Interview:') &&
            a.subject.contains('$interviewId'));
      });
    };

    // Handle meeting created events
    wsService.onMeetingCreated = (data) {
      if (!mounted) return;
      debugPrint('📊 Real-time: Meeting created - $data');
      setState(() {
        final appointment = _parseMeetingToAppointment(data);
        if (appointment != null) {
          _calendarAppointments.add(appointment);
        }
      });
      _showRealTimeNotification('New meeting scheduled');
    };

    // Handle job status changed events
    wsService.onJobStatusChanged = (data) {
      if (!mounted) return;
      debugPrint('📊 Real-time: Job status changed - $data');
      // Refresh stats to get updated counts
      fetchStats();
    };

    // Handle CV review completed events
    wsService.onCvReviewCompleted = (data) {
      if (!mounted) return;
      debugPrint('📊 Real-time: CV review completed - $data');
      setState(() {
        cvReviewsCount++;
      });
      _showRealTimeNotification('CV review completed');
    };

    // Handle candidate applied events
    wsService.onCandidateApplied = (data) {
      if (!mounted) return;
      debugPrint('📊 Real-time: Candidate applied - $data');
      setState(() {
        candidatesCount++;
        cvReviewsCount++;
      });
      _showRealTimeNotification('New candidate application');
    };

    // Handle audit created events
    wsService.onAuditCreated = (data) {
      if (!mounted) return;
      debugPrint('📊 Real-time: Audit created - $data');
      setState(() {
        auditsCount++;
      });
    };
  }

  /// Parse interview data to calendar Appointment
  Appointment? _parseInterviewToAppointment(Map<String, dynamic> data) {
    try {
      final scheduledTimeStr = data['scheduled_time'] as String?;
      if (scheduledTimeStr == null) return null;

      final startTime = DateTime.parse(scheduledTimeStr);
      final endTime = startTime.add(const Duration(hours: 1));
      final jobTitle = data['job_title'] as String? ?? 'Interview';
      final candidateName = data['candidate_name'] as String? ?? '';

      return Appointment(
        startTime: startTime,
        endTime: endTime,
        subject:
            'Interview: $jobTitle${candidateName.isNotEmpty ? ' – $candidateName' : ''}',
        color: Colors.deepOrange,
      );
    } catch (e) {
      debugPrint('Error parsing interview data: $e');
      return null;
    }
  }

  /// Parse meeting data to calendar Appointment
  Appointment? _parseMeetingToAppointment(Map<String, dynamic> data) {
    try {
      final startTimeStr = data['start_time'] as String?;
      final endTimeStr = data['end_time'] as String?;
      if (startTimeStr == null) return null;

      final startTime = DateTime.parse(startTimeStr);
      final endTime = endTimeStr != null
          ? DateTime.parse(endTimeStr)
          : startTime.add(const Duration(hours: 1));
      final title = data['title'] as String? ?? 'Meeting';

      return Appointment(
        startTime: startTime,
        endTime: endTime,
        subject: title,
        color: Colors.blue,
      );
    } catch (e) {
      debugPrint('Error parsing meeting data: $e');
      return null;
    }
  }

  /// Update existing calendar appointment with new data
  void _updateCalendarAppointment(Map<String, dynamic> data) {
    try {
      final id = data['id']?.toString();
      if (id == null) return;

      setState(() {
        // Find and update the appointment
        for (int i = 0; i < _calendarAppointments.length; i++) {
          if (_calendarAppointments[i].subject.contains(id)) {
            final updatedAppointment = _parseInterviewToAppointment(data);
            if (updatedAppointment != null) {
              _calendarAppointments[i] = updatedAppointment;
            }
            break;
          }
        }
      });
    } catch (e) {
      debugPrint('Error updating calendar appointment: $e');
    }
  }

  /// Show real-time notification to user
  void _showRealTimeNotification(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF252525),
      ),
    );
  }

  Future<void> _bootstrapAuthFromToken() async {
    if (widget.token.isEmpty) return;
    try {
      await AuthService.saveToken(widget.token);
      final userProfile = await AuthService.getUserProfile(widget.token);
      final user = userProfile['user'] ?? userProfile;
      if (user is Map<String, dynamic>) {
        await AuthService.saveUserInfo(user);
      }
    } catch (_) {
      // Best-effort: avoid blocking dashboard load
    }
  }

  Future<void> _loadCalendarData() async {
    if (_calendarLoading) return;
    if (!mounted) return;
    setState(() => _calendarLoading = true);
    final start = DateTime(focusedDay.year, focusedDay.month, 1);
    final end = DateTime(focusedDay.year, focusedDay.month + 1, 0);
    final startStr =
        "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
    final endStr =
        "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";
    try {
      final meetingsRes = await admin.getUpcomingMeetings(
        limit: 100,
        startDate: startStr,
        endDate: endStr,
      );
      final meetings = meetingsRes['meetings'] as List<dynamic>? ?? [];
      List<Map<String, dynamic>> interviews = [];
      try {
        interviews = await admin.getInterviewsForCalendar(
          startDate: startStr,
          endDate: endStr,
        );
      } catch (_) {}
      final List<Appointment> appointments = [];
      for (final m in meetings) {
        final map = m as Map<String, dynamic>;
        final startTimeStr = map['start_time'] as String?;
        final endTimeStr = map['end_time'] as String?;
        if (startTimeStr == null) continue;
        DateTime startTime;
        DateTime endTime;
        try {
          startTime = DateTime.parse(startTimeStr);
          endTime = endTimeStr != null
              ? DateTime.parse(endTimeStr)
              : startTime.add(const Duration(hours: 1));
          if (!endTime.isAfter(startTime)) {
            endTime = startTime.add(const Duration(minutes: 15));
          }
        } catch (_) {
          continue;
        }
        appointments.add(
          Appointment(
            startTime: startTime,
            endTime: endTime,
            subject: map['title'] as String? ?? 'Meeting',
            color: Colors.blue,
          ),
        );
      }
      for (final i in interviews) {
        final scheduledStr = i['scheduled_time'] as String?;
        if (scheduledStr == null) continue;
        DateTime startTime;
        try {
          startTime = DateTime.parse(scheduledStr);
        } catch (_) {
          continue;
        }
        DateTime endTime = startTime.add(const Duration(hours: 1));
        if (!endTime.isAfter(startTime)) {
          endTime = startTime.add(const Duration(minutes: 15));
        }
        final jobTitle = i['job_title'] as String? ?? 'Interview';
        final candidateName = i['candidate_name'] as String? ?? '';
        appointments.add(
          Appointment(
            startTime: startTime,
            endTime: endTime,
            subject:
                'Interview: $jobTitle${candidateName.isNotEmpty ? ' – $candidateName' : ''}',
            color: Colors.deepOrange,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _calendarAppointments = appointments;
        _calendarLoading = false;
      });
    } catch (e) {
      debugPrint('Calendar load error: $e');
      if (!mounted) return;
      setState(() => _calendarLoading = false);
    }
  }

  Future<void> fetchDashboardNotifications() async {
    setState(() => loadingNotifications = true);
    try {
      final response = await NotificationService.getNotifications();
      if (!mounted) return;
      setState(() {
        dashboardNotifications = response.notifications;
        unreadNotificationCount = response.notifications
            .where((n) => n['read'] == false || n['read'] == null)
            .length;
        loadingNotifications = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loadingNotifications = false);
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    auditSearchController.dispose();

    // Unsubscribe from WebSocket dashboard events
    final wsService = WebSocketService();
    final userId = AuthService.getUserInfo().toString();
    wsService.unsubscribeFromDashboard(userId);

    super.dispose();
  }

  // ---------- Dashboard Stats ----------
  Future<void> fetchStats() async {
    // Try to load cached data first for instant UI
    final cachedStats =
        await CacheService().get<Map<String, dynamic>>('dashboard_stats');
    final cachedActivities =
        await CacheService().get<List<dynamic>>('recent_activities');

    if (cachedStats != null && mounted) {
      setState(() {
        _applyDashboardStats(
            cachedStats, cachedActivities?.cast<String>() ?? []);
        // Don't set loadingStats to false yet - we're still fetching fresh data
      });
    } else if (mounted) {
      setState(() => loadingStats = true);
    }

    try {
      final counts = await UnifiedApiService.getDashboardCounts();

      final res = await UnifiedApiService.makeAuthorizedRequest(
        'GET',
        ApiEndpoints.getRecentActivities,
      );

      List<String> activities = [];
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        activities = List<String>.from(data["recent_activities"] ?? []);
      }

      // Cache the fresh data
      await CacheService().set('dashboard_stats', counts,
          expiration: const Duration(minutes: 30));
      await CacheService().set('recent_activities', activities,
          expiration: const Duration(minutes: 30));

      if (mounted) {
        setState(() {
          _applyDashboardStats(counts, activities);
          loadingStats = false;
        });
      }
    } catch (e) {
      // If we have cached data, stay in offline mode
      if (cachedStats == null && mounted) {
        setState(() => loadingStats = false);
      }
      debugPrint("Error fetching dashboard stats: $e");
    }
  }

  /// Helper to apply dashboard stats to state
  void _applyDashboardStats(
      Map<String, dynamic> counts, List<String> activities) {
    jobsCount = counts["jobs"] ?? 0;
    candidatesCount = counts["candidates"] ?? 0;
    interviewsCount = counts["interviews"] ?? 0;
    cvReviewsCount = counts["cv_reviews"] ?? 0;
    auditsCount = counts["audits"] ?? 0;

    // Enhanced metrics
    activeJobs = counts["active_jobs"] ?? 0;
    candidatesWithCV = counts["candidates_with_cv"] ?? 0;
    upcomingInterviews = counts["upcoming_interviews"] ?? 0;
    newApplicationsWeek =
        (counts["recent_activity"]?["new_applications"] ?? 0) as int;
    offeredApplications = counts["offered_applications"] ?? 0;
    acceptedOffers = counts["accepted_offers"] ?? 0;

    recentActivities = activities;
  }

  Future<void> fetchAudits({int page = 1}) async {
    if (mounted) setState(() => loadingAudits = true);
    try {
      final queryParams = {
        "page": page.toString(),
        "per_page": auditPerPage.toString(),
        if (auditActionFilter != null) "action": auditActionFilter!,
        if (auditStartDate != null)
          "start_date":
              "${auditStartDate!.year}-${auditStartDate!.month.toString().padLeft(2, '0')}-${auditStartDate!.day.toString().padLeft(2, '0')}",
        if (auditEndDate != null)
          "end_date":
              "${auditEndDate!.year}-${auditEndDate!.month.toString().padLeft(2, '0')}-${auditEndDate!.day.toString().padLeft(2, '0')}",
        if (auditSearchQuery != null) "q": auditSearchQuery!,
      };
      final uri = Uri.parse("${ApiEndpoints.adminBase}/audits")
          .replace(queryParameters: queryParams);
      final res = await UnifiedApiService.makeAuthorizedRequest(
        'GET',
        uri.toString(),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            audits = List<Map<String, dynamic>>.from(data["results"]);
            auditPage = data["page"];
            auditPerPage = data["per_page"];
            auditTrendData = audits
                .map((e) => DateTime.parse(e["timestamp"]))
                .fold<Map<String, int>>({}, (map, dt) {
                  final day =
                      "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
                  map[day] = (map[day] ?? 0) + 1;
                  return map;
                })
                .entries
                .map((e) => _ChartData(e.key, e.value))
                .toList();
            loadingAudits = false;
          });
        }
      } else {
        if (mounted) setState(() => loadingAudits = false);
      }
    } catch (e) {
      if (mounted) setState(() => loadingAudits = false);
    }
  }

  void _showLogoutConfirmation(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor:
              themeProvider.isDarkMode ? _AdminPalette.charcoal : Colors.white,
          title: Text("Logout",
              style: GoogleFonts.poppins(
                  color:
                      themeProvider.isDarkMode ? Colors.white : Colors.black)),
          content: Text("Are you sure you want to logout?",
              style: GoogleFonts.poppins(
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade700)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text("Cancel",
                  style: GoogleFonts.poppins(
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade500
                          : Colors.grey.shade600)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performLogout(context);
              },
              child: Text("Logout",
                  style: GoogleFonts.poppins(color: _AdminPalette.primary)),
            ),
          ],
        );
      },
    );
  }

  void _performLogout(BuildContext context) async {
    // Do not pop: confirmation dialog already closed by onPressed. Popping again would remove the last route.
    await AuthService.logout();
    if (!mounted) return;
    context.go('/login');
  }

  // ---------- UI Build ----------
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: _AdminPalette.scaffoldBackground,
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(themeProvider.backgroundImage),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Particle overlay (subtle effect)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.1),
            ),
          ),
          // Main content
          SafeArea(
            child: Row(
              children: [
                // ---------- Fixed Sidebar ----------
                Container(
                  width: 220,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode
                        ? _AdminPalette.sidebarBackground
                        : Colors.white,
                    border: Border(
                      right: BorderSide(
                        color: themeProvider.isDarkMode
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 20, 19, 30)
                            .withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(2, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Sidebar header
                      SizedBox(
                        height: 72,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _adminDashboardAssetImage(
                              'images/logo2.png',
                              height: 40,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            _sidebarEntry(
                                'images/Home_Remote_Work_Red_Badge_White.png',
                                'Dashboard',
                                'dashboard'),
                            _sidebarEntry(
                                'assets/images/Approval_Red_Badge_White.png',
                                'Jobs',
                                'jobs'),
                            _sidebarEntry(Icons.people_outline, 'Candidates',
                                'candidates'),
                            _sidebarEntry(
                                'assets/images/red_Management_Red_Badge_White.png',
                                'Interviews',
                                'interviews'),
                            _sidebarEntry(
                                'images/Goal_Target_White_Badge_Red_Badge_White.png',
                                'CV Reviews',
                                'cv_reviews'),
                            _sidebarEntry('icons/data-analytics.png',
                                'Analytics', 'analytics'),
                            _sidebarEntry('images/Team.png',
                                'Team Collaboration', 'team_collaboration'),
                            _sidebarEntry('images/Notification_Red_White.png',
                                'Notifications', 'notifications',
                                badgeCount: unreadNotificationCount),
                            _sidebarEntry(
                                'images/innovation_brainstorm_red_badge_white.png',
                                'Settings',
                                'settings'),
                            _sidebarEntry(Icons.verified_user_outlined,
                                'Audits', 'audits'),
                            _sidebarEntry(Icons.manage_accounts_outlined,
                                'User Management', 'user_management'),
                            _sidebarEntry(Icons.person_outline,
                                'Account Profile', 'profile'),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12.0, horizontal: 8),
                        child: ElevatedButton.icon(
                          onPressed: () => _showLogoutConfirmation(context),
                          icon: const Icon(Icons.logout, size: 16),
                          label: const Text("Logout",
                              style: TextStyle(fontFamily: 'Poppins')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.isDarkMode
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.white,
                            foregroundColor: themeProvider.isDarkMode
                                ? Colors.redAccent
                                : Colors.black,
                            side: BorderSide(
                              color: themeProvider.isDarkMode
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.grey.shade300,
                            ),
                            minimumSize: const Size.fromHeight(40),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ---------- Main content ----------
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: getCurrentScreen(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.redAccent,
        onPressed: themeProvider.toggleTheme,
        tooltip: themeProvider.isDarkMode
            ? "Switch to light mode"
            : "Switch to dark mode",
        child: Icon(
          themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _sidebarEntry(dynamic icon, String label, String screenKey,
      {int? badgeCount}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final selected = currentScreen == screenKey;
    final iconColor = selected
        ? _AdminPalette.primary
        : themeProvider.isDarkMode
            ? Colors.grey.shade400
            : Colors.black;

    return InkWell(
      onTap: () => setState(() => currentScreen = screenKey),
      child: Container(
        color: selected
            ? _AdminPalette.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            _buildSidebarIcon(icon, selected, iconColor, themeProvider),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: selected
                      ? _AdminPalette.primary
                      : themeProvider.isDarkMode
                          ? Colors.grey.shade400
                          : Colors.black,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (badgeCount != null && badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _AdminPalette.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarIcon(
    dynamic icon,
    bool selected,
    Color iconColor,
    ThemeProvider themeProvider,
  ) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? _AdminPalette.primary
            : themeProvider.isDarkMode
                ? Colors.grey.shade700
                : Colors.grey.shade200,
      ),
      child: icon is IconData
          ? Icon(
              icon,
              size: 20,
              color: selected
                  ? Colors.white
                  : themeProvider.isDarkMode
                      ? Colors.white
                      : Colors.black,
            )
          : _adminDashboardAssetImage(
              icon as String,
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
    );
  }

  Widget getCurrentScreen() {
    switch (currentScreen) {
      case "dashboard":
        return DashboardOverview(
          stats: {
            "jobs": jobsCount,
            "candidates": candidatesCount,
            "interviews": interviewsCount,
            "applications": cvReviewsCount,
            "offers": acceptedOffers,
          },
          recentActivities: recentActivities,
          upcomingInterviews: _calendarAppointments
              .where((a) => a.subject.toLowerCase().contains('interview'))
              .toList(),
        );
      case "jobs":
        return JobManagement(
          onJobSelected: (jobId) {
            setState(() {
              selectedJobId = jobId;
              currentScreen = "candidates";
            });
          },
        );
      case "test_packs":
        return const TestPackManagementScreen();
      case "candidates":
        if (selectedJobId == null) {
          return const Center(
              child: Text("Please select a job first",
                  style: TextStyle(fontFamily: 'Poppins')));
        }
        return CandidateManagementScreen(jobId: selectedJobId!);
      case "interviews":
        return const InterviewListScreen();
      case "cv_reviews":
        return const CVReviewsScreen();
      case "pipeline":
        return const AdminPipelinePage(embedded: true);
      case "offers":
        return const AdminOfferListScreen(embedded: true);
      case "settings":
        return const AdminSettingsScreen(embedded: true);
      case "profile":
        return ProfilePage(token: widget.token);
      case "analytics":
        return const AnalyticsDashboard(embedded: true);
      case "notifications":
        return NotificationsScreen(onNotificationTap: _handleNotificationTap);
      case "all_candidates":
        return const CandidateListScreen();
      case "team_collaboration":
        return const HMTeamCollaborationPage();
      case "audits":
        return _placeholderScreen("Audit Logs");
      case "roles":
        return const UserManagementScreen();
      case "users":
        return const UserManagementScreen();
      default:
        return DashboardOverview(
          stats: {
            "jobs": jobsCount,
            "candidates": candidatesCount,
            "interviews": interviewsCount,
            "applications": cvReviewsCount,
            "offers": acceptedOffers,
          },
          recentActivities: recentActivities,
          upcomingInterviews: _calendarAppointments
              .where((a) => a.subject.toLowerCase().contains('interview'))
              .toList(),
        );
    }
  }

  Widget _placeholderScreen(String title) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction,
              size: 64,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade600
                  : Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Coming Soon",
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // Legacy chart widgets - using modern replacements in DashboardOverview
  Widget candidateHistogram(List<_HistogramData> data) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? _AdminPalette._darkWidgetSurface()
            : _AdminPalette._lightWidgetSurface(),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Candidates by Job Role",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color:
                      themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 153, 26, 26)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Histogram",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: const Color.fromRGBO(153, 26, 26, 1),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SfCartesianChart(
              plotAreaBorderWidth: 0,
              primaryXAxis: CategoryAxis(
                axisLine: const AxisLine(width: 0),
                majorGridLines: const MajorGridLines(width: 0),
                labelStyle:
                    const TextStyle(fontSize: 10, fontFamily: 'Poppins'),
              ),
              primaryYAxis: NumericAxis(
                axisLine: const AxisLine(width: 0),
                majorGridLines: const MajorGridLines(width: 0),
                labelStyle:
                    const TextStyle(fontSize: 10, fontFamily: 'Poppins'),
              ),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                color: const Color.fromARGB(255, 153, 26, 26),
              ),
              series: <CartesianSeries<_HistogramData, String>>[
                ColumnSeries<_HistogramData, String>(
                  dataSource: data,
                  xValueMapper: (d, _) => d.jobRole,
                  yValueMapper: (d, _) => d.candidateCount,
                  color: const Color.fromARGB(255, 153, 26, 26),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: true,
                    textStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget interviewColumnChart(List<_InterviewData> data) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? _AdminPalette._darkWidgetSurface()
            : _AdminPalette._lightWidgetSurface(),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Interview Status",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color:
                      themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 153, 26, 26)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Overview",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: const Color.fromARGB(255, 153, 26, 26),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SfCartesianChart(
              plotAreaBorderWidth: 0,
              primaryXAxis: CategoryAxis(
                axisLine: const AxisLine(width: 0),
                majorGridLines: const MajorGridLines(width: 0),
              ),
              primaryYAxis: NumericAxis(
                axisLine: const AxisLine(width: 0),
                majorGridLines: const MajorGridLines(width: 0),
              ),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                color: const Color.fromARGB(255, 153, 26, 26),
              ),
              series: <CartesianSeries<_InterviewData, String>>[
                ColumnSeries<_InterviewData, String>(
                  dataSource: data,
                  xValueMapper: (d, _) => d.status,
                  yValueMapper: (d, _) => d.count,
                  color: const Color.fromARGB(255, 153, 26, 26),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: true,
                    textStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget cvReviewsMixedChart(List<_CvReviewData> data) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? _AdminPalette._darkWidgetSurface()
            : _AdminPalette._lightWidgetSurface(),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "CV Reviews Trend",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color:
                      themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 153, 26, 26)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Weekly",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: const Color.fromARGB(255, 153, 26, 26),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SfCartesianChart(
              plotAreaBorderWidth: 0,
              primaryXAxis: CategoryAxis(
                axisLine: const AxisLine(width: 0),
                majorGridLines: const MajorGridLines(width: 0),
              ),
              primaryYAxis: NumericAxis(
                axisLine: const AxisLine(width: 0),
                majorGridLines: const MajorGridLines(width: 0),
              ),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                color: const Color.fromARGB(255, 153, 26, 26),
              ),
              series: <CartesianSeries<_CvReviewData, String>>[
                ColumnSeries<_CvReviewData, String>(
                  dataSource: data,
                  xValueMapper: (d, _) => d.week,
                  yValueMapper: (d, _) => d.reviewsCompleted,
                  name: 'Completed',
                  color: const Color.fromARGB(255, 153, 26, 26),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                LineSeries<_CvReviewData, String>(
                  dataSource: data,
                  xValueMapper: (d, _) => d.week,
                  yValueMapper: (d, _) => d.reviewsPending,
                  name: 'Pending',
                  color: Colors.orangeAccent,
                  width: 3,
                  markerSettings: const MarkerSettings(
                    isVisible: true,
                    color: Colors.orangeAccent,
                    borderWidth: 2,
                    borderColor: Colors.white,
                  ),
                ),
              ],
              legend: Legend(
                isVisible: true,
                position: LegendPosition.bottom,
                overflowMode: LegendItemOverflowMode.wrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget modernCalendarCard() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? _AdminPalette._darkWidgetSurface()
            : _AdminPalette._lightWidgetSurface(),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: themeProvider.isDarkMode
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade900.withValues(alpha: 0.3),
                  Colors.purple.shade900.withValues(alpha: 0.3),
                ],
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 153, 26, 26)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.calendar_month,
                        color: Color.fromARGB(255, 250, 250, 250), size: 22),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Today's Date",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: BrandTokens.primary,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: BrandTokens.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: StreamBuilder(
                  stream: Stream.periodic(const Duration(seconds: 1)),
                  builder: (context, snapshot) {
                    return Text(
                      DateFormat('hh:mm a').format(DateTime.now()),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        color: BrandTokens.primary,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode
                  ? _AdminPalette._darkWidgetSurface()
                  : _AdminPalette._lightWidgetSurface(),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateTime.now().day.toString(),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: BrandTokens.primary,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('MMMM yyyy').format(DateTime.now()),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final type = (notification['type']?.toString() ?? '').toLowerCase();
    setState(() {
      if (type == 'new_application' || type == 'new_candidate') {
        currentScreen = 'candidates';
      } else if (type == 'interview' ||
          type == 'feedback_reminder' ||
          type == 'feedback_received' ||
          type == 'reminder' ||
          type == 'reminder_urgent' ||
          type == 'warning') {
        currentScreen = 'interviews';
      } else if (type == 'status_update') {
        currentScreen = 'pipeline';
      } else {
        currentScreen = 'notifications';
      }
    });
  }

  Widget activitiesCard() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? _AdminPalette._darkWidgetSurface()
            : _AdminPalette._lightWidgetSurface(),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: BrandTokens.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timeline,
                    color: BrandTokens.primary, size: 20),
              ),
              const SizedBox(width: 8),
              Text("Recent Activities",
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black87)),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 120,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: recentActivities.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode
                        ? _AdminPalette._darkWidgetSurface()
                        : _AdminPalette._lightWidgetSurface(),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: BrandTokens.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          recentActivities[index],
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(DateTime.now()
                            .subtract(Duration(minutes: index * 15))),
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.grey.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget kpiCard(
    String title,
    int count,
    Color color,
    String iconPath, {
    String? subtitle,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Image.asset(
                  iconPath,
                  width: 30,
                  height: 30,
                  color: color,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "+${((count / 10) * 100).round()}%",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade500
                    : Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Data classes for charts
class _HistogramData {
  final String jobRole;
  final int candidateCount;
  _HistogramData(this.jobRole, this.candidateCount);
}

class _InterviewData {
  final String status;
  final int count;
  _InterviewData(this.status, this.count);
}

class _CvReviewData {
  final String week;
  final int reviewsCompleted;
  final int reviewsPending;
  _CvReviewData(this.week, this.reviewsCompleted, this.reviewsPending);
}

class StackedLineData {
  final String month;
  final int login;
  final int logout;
  final int create;
  final int update;
  final int delete;
  StackedLineData(this.month, this.login, this.logout, this.create, this.update,
      this.delete);
}

class _ChartData {
  final String label;
  final int value;
  _ChartData(this.label, this.value);
}
