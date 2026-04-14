import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
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
import '../../widgets/admin_dashboard_components.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/themed_surface_card.dart';
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

  bool sidebarCollapsed = false;
  late final AnimationController _sidebarAnimController;
  late final Animation<double> _sidebarWidthAnimation;

  // Power BI status
  bool powerBIConnected = false;
  bool checkingPowerBI = true;
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

  // ---------- Profile image state ----------
  XFile? _profileImage;
  Uint8List? _profileImageBytes;
  String _profileImageUrl = "";
  final String apiBase = ApiEndpoints.candidateBase;

  // Calendar appointments (interviews + meetings)
  List<Appointment> _calendarAppointments = [];
  bool _calendarLoading = false;

  // Team collaboration data
  List<Map<String, dynamic>> _teamCollaborationItems = [];
  bool _loadingTeamCollaboration = true;

  // Department distribution data
  List<DepartmentData> _departmentDistribution = [];
  bool _loadingDepartments = true;

  String? _userName;

  /// Use role-based name when stored name is null, empty, or a placeholder (e.g. "Deployed Admin").
  String _effectiveWelcomeName(String? name) {
    if (name == null || name.trim().isEmpty) return 'Admin';
    if (name.toLowerCase().contains('deployed')) return 'Admin';
    return name.trim();
  }

  @override
  void initState() {
    super.initState();
    _userName = AuthService.getCachedDisplayName();
    _bootstrapAuthFromToken();
    fetchStats();
    fetchPowerBIStatus();
    fetchAudits(page: 1);
    fetchProfileImage();
    fetchDashboardNotifications();
    _loadCalendarData();
    _fetchTeamCollaboration();
    _fetchDepartmentDistribution();

    _statusTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      fetchPowerBIStatus();
    });

    _sidebarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _sidebarWidthAnimation = Tween<double>(begin: 260, end: 72).animate(
      CurvedAnimation(parent: _sidebarAnimController, curve: Curves.easeInOut),
    );

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
      _fetchDepartmentDistribution();
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
      if (mounted)
        setState(() => _userName = AuthService.getCachedDisplayName());
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

  Future<void> _fetchTeamCollaboration() async {
    setState(() => _loadingTeamCollaboration = true);
    try {
      final data = await admin.getTeamCollaborationUsers();
      if (!mounted) return;

      // Extract collaboration items from response
      final items = data['collaboration_items'] ??
          data['users'] ??
          data['activities'] ??
          [];

      setState(() {
        _teamCollaborationItems = List<Map<String, dynamic>>.from(items);
        _loadingTeamCollaboration = false;
      });
    } catch (e) {
      debugPrint('Team collaboration load error: $e');
      if (!mounted) return;
      setState(() => _loadingTeamCollaboration = false);
    }
  }

  Future<void> _fetchDepartmentDistribution() async {
    setState(() => _loadingDepartments = true);
    try {
      // Fetch jobs with stats to get department information
      final data = await admin.listJobsEnhanced(perPage: 100);
      if (!mounted) return;

      final jobs = data['jobs'] as List<dynamic>? ?? [];
      final departments = _calculateDepartmentDistribution(jobs);

      setState(() {
        _departmentDistribution = departments;
        _loadingDepartments = false;
      });
    } catch (e) {
      debugPrint('Department distribution load error: $e');
      if (!mounted) return;
      setState(() => _loadingDepartments = false);
    }
  }

  List<DepartmentData> _calculateDepartmentDistribution(List<dynamic> jobs) {
    // Group jobs by department and count
    final Map<String, int> counts = {};
    for (final job in jobs) {
      if (job is Map<String, dynamic>) {
        final dept = job['department'] ?? job['category'] ?? 'Unknown';
        counts[dept] = (counts[dept] ?? 0) + 1;
      }
    }

    if (counts.isEmpty) {
      return [];
    }

    final total = counts.values.reduce((a, b) => a + b);
    final colors = [
      const Color(0xFF81829B),
      const Color(0xFF6095CC),
      const Color(0xFFEA990C),
      const Color(0xFFE7BF2D),
      const Color(0xFF6CA510),
      const Color(0xFFC10D00),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
    ];

    // Sort by count descending and take top 5
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(5).map((e) {
      final index = sorted.indexOf(e);
      return DepartmentData(
        e.key,
        total > 0 ? e.value / total : 0.0,
        colors[index % colors.length],
      );
    }).toList();
  }

  Future<void> fetchDashboardNotifications() async {
    setState(() => loadingNotifications = true);
    try {
      final response = await NotificationService.getNotifications();
      if (!mounted) return;
      setState(() {
        dashboardNotifications = response.notifications;
        loadingNotifications = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loadingNotifications = false);
    }
  }

  @override
  void dispose() {
    _sidebarAnimController.dispose();
    _statusTimer?.cancel();
    auditSearchController.dispose();

    // Unsubscribe from WebSocket dashboard events
    final wsService = WebSocketService();
    final userId = AuthService.getUserInfo().toString();
    wsService.unsubscribeFromDashboard(userId);

    super.dispose();
  }

  // ---------- Profile Image Methods ----------
  Future<void> fetchProfileImage() async {
    try {
      final profileRes = await http.get(
        Uri.parse("$apiBase/profile"),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json'
        },
      );

      if (profileRes.statusCode == 200) {
        final data = json.decode(profileRes.body)['data'];
        final candidate = data['candidate'] ?? {};
        setState(() {
          _profileImageUrl = candidate['profile_picture'] ?? "";
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile image: $e");
    }
  }

  Future<void> uploadProfileImage() async {
    if (_profileImage == null) return;
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("$apiBase/upload_profile_picture"),
      );
      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          kIsWeb
              ? _profileImageBytes!
              : File(_profileImage!.path).readAsBytesSync(),
          filename: _profileImage!.name,
        ),
      );

      var response = await request.send();
      final respStr = await response.stream.bytesToString();
      final respJson = json.decode(respStr);

      if (response.statusCode == 200 && respJson['success'] == true) {
        setState(() {
          _profileImageUrl = respJson['data']['profile_picture'];
          _profileImage = null;
          _profileImageBytes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile picture updated")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Upload failed: ${response.statusCode}")));
      }
    } catch (e) {
      debugPrint("Profile image upload error: $e");
    }
  }

  ImageProvider<Object> _getProfileImageProvider() {
    if (_profileImage != null) {
      if (kIsWeb) return MemoryImage(_profileImageBytes!);
      return FileImage(File(_profileImage!.path));
    }
    if (_profileImageUrl.isNotEmpty) return NetworkImage(_profileImageUrl);
    return const AssetImage("assets/images/profile_placeholder.png");
  }

  // ---------- Dashboard Stats & PowerBI ----------
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

  Future<void> fetchPowerBIStatus() async {
    if (mounted) setState(() => checkingPowerBI = true);
    try {
      final res = await UnifiedApiService.makeAuthorizedRequest(
        'GET',
        ApiEndpoints.getPowerBIStatus,
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            powerBIConnected = data["connected"] ?? false;
          });
        }
      } else {
        if (mounted) setState(() => powerBIConnected = false);
      }
    } catch (e) {
      if (mounted) setState(() => powerBIConnected = false);
    } finally {
      if (mounted) setState(() => checkingPowerBI = false);
    }
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
    final navigatorContext = context;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Logout", style: TextStyle(fontFamily: 'Poppins')),
          content: const Text("Are you sure you want to logout?",
              style: TextStyle(fontFamily: 'Poppins')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child:
                  const Text("Cancel", style: TextStyle(fontFamily: 'Poppins')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performLogout(navigatorContext);
              },
              child: const Text("Logout",
                  style: TextStyle(color: Colors.red, fontFamily: 'Poppins')),
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
      // 🌆 Dynamic background implementation
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(themeProvider.backgroundImage),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // ---------- Collapsible Sidebar ----------
              AnimatedBuilder(
                animation: _sidebarAnimController,
                builder: (context, child) {
                  final width = _sidebarWidthAnimation.value;
                  return Container(
                    width: width,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      border: Border(
                        right: BorderSide(
                            color: themeProvider.isDarkMode
                                ? Colors.white.withValues(alpha: 0.1)
                                : const Color(0xFFE0E0E0),
                            width: 1),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: sidebarCollapsed
                                        ? Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: themeProvider.isDarkMode
                                                  ? const Color(0xFF2D2D2D)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.08),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'K',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: themeProvider
                                                              .isDarkMode
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF1A1A1A),
                                                    ),
                                                  ),
                                                  Container(
                                                    width: 14,
                                                    height: 3,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFC10D00),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              1),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.fromLTRB(
                                                16, 14, 16, 14),
                                            decoration: BoxDecoration(
                                              color: themeProvider.isDarkMode
                                                  ? const Color(0xFF2D2D2D)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.08),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Column(
                                                      children: [
                                                        Text(
                                                          'K',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: themeProvider
                                                                    .isDarkMode
                                                                ? Colors.white
                                                                : const Color(
                                                                    0xFF1A1A1A),
                                                          ),
                                                        ),
                                                        Container(
                                                          width: 12,
                                                          height: 3,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: const Color(
                                                                0xFFC10D00),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        1),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Text(
                                                      'HONOLOGY',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: themeProvider
                                                                .isDarkMode
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF1A1A1A),
                                                        letterSpacing: 2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Automated Recruitment\nWorkflow',
                                                  textAlign: TextAlign.center,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w500,
                                                    color:
                                                        themeProvider.isDarkMode
                                                            ? Colors.white60
                                                            : const Color(
                                                                0xFF666666),
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                ),
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    sidebarCollapsed
                                        ? Icons.arrow_forward_ios
                                        : Icons.arrow_back_ios,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  onPressed: toggleSidebar,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              _sidebarEntry(
                                  'assets/images/Home_Remote_Work_Red_Badge_White.png',
                                  'Home',
                                  'dashboard'),
                              _sidebarEntry(
                                  'assets/images/Approval_Red_Badge_White.png',
                                  'Jobs',
                                  'jobs'),
                              _sidebarEntry('assets/images/candidates.png',
                                  'Candidates', 'all_candidates'),
                              _sidebarEntry(
                                  'assets/images/red_Management_Red_Badge_White.png',
                                  'Interviews',
                                  'interviews'),
                              _sidebarEntry(
                                  'assets/images/Goal_Target_White_Badge_Red_Badge_White.png',
                                  'CV Reviews',
                                  'cv_reviews'),
                              _sidebarEntry('assets/icons/data-analytics.png',
                                  'Analytics', 'analytics'),
                              _sidebarEntry('assets/icons/teamC.png',
                                  'Team Collaboration', 'team_collaboration'),
                              _sidebarEntry(
                                  'assets/images/Notification_Red_White.png',
                                  'Notifications',
                                  'notifications'),
                              _sidebarEntry(
                                  'assets/images/innovation_brainstorm_red_badge_white.png',
                                  'Settings',
                                  'settings'),
                              _sidebarEntry(
                                  Icons.person_outline, 'Profile', 'profile'),
                              _sidebarEntry('assets/images/deadline.png',
                                  'Audits', 'audits'),
                              _sidebarEntry(
                                  'assets/images/Warning_Error_Red_Badge_White.png',
                                  'Role Access',
                                  'roles'),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12.0, horizontal: 8),
                          child: Column(
                            children: [
                              if (!sidebarCollapsed)
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(
                                            () => currentScreen = 'profile');
                                      },
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.grey.shade200,
                                        backgroundImage:
                                            _getProfileImageProvider(),
                                        child: null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Admin User",
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: themeProvider.isDarkMode
                                              ? Colors.white
                                              : Colors.grey.shade800,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Center(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => currentScreen = 'profile');
                                    },
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.grey.shade200,
                                      backgroundImage:
                                          _getProfileImageProvider(),
                                      child: null,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              if (!sidebarCollapsed)
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _showLogoutConfirmation(context),
                                  icon: const Icon(Icons.logout, size: 16),
                                  label: const Text("Logout",
                                      style: TextStyle(fontFamily: 'Poppins')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: themeProvider.isDarkMode
                                        ? const Color(0xFF2D2D2D)
                                        : Colors.white,
                                    foregroundColor: BrandTokens.primary,
                                    side:
                                        BorderSide(color: Colors.grey.shade300),
                                    minimumSize: const Size.fromHeight(40),
                                  ),
                                )
                              else
                                IconButton(
                                  onPressed: () =>
                                      _showLogoutConfirmation(context),
                                  icon: const Icon(Icons.logout,
                                      color: Colors.grey),
                                ),
                              const SizedBox(height: 16),
                              // Version label
                              if (!sidebarCollapsed)
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: themeProvider.isDarkMode
                                            ? const Color(0xFF444444)
                                            : const Color(0xFFE0E0E0),
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Ver 2026.03.AA1_SIT',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: themeProvider.isDarkMode
                                            ? Colors.white54
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // ---------- Main content ----------
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: themeProvider.isDarkMode
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.05),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Greeting section
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Admin Dashboard",
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: themeProvider.isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF1A1A1A),
                                  ),
                                ),
                                Text(
                                  "Hello, ${_effectiveWelcomeName(_userName)}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: themeProvider.isDarkMode
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : const Color(0xFF666666),
                                  ),
                                ),
                              ],
                            ),

                            // Action icons
                            Row(
                              children: [
                                // Mail icon
                                _buildTopBarIconButton(
                                  icon: Icons.mail_outline,
                                  onPressed: () {},
                                  themeProvider: themeProvider,
                                ),
                                const SizedBox(width: 12),
                                // Notification icon
                                _buildTopBarIconButton(
                                  icon: Icons.notifications_none_outlined,
                                  onPressed: () => setState(
                                      () => currentScreen = 'notifications'),
                                  badgeCount: dashboardNotifications.length,
                                  themeProvider: themeProvider,
                                ),
                                const SizedBox(width: 24),
                                // Theme Toggle (relocated to right)
                                Row(
                                  children: [
                                    Icon(
                                      themeProvider.isDarkMode
                                          ? Icons.dark_mode
                                          : Icons.light_mode,
                                      color: themeProvider.isDarkMode
                                          ? Colors.amber
                                          : Colors.grey.shade700,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Switch(
                                      value: themeProvider.isDarkMode,
                                      onChanged: (value) {
                                        themeProvider.toggleTheme();
                                      },
                                      activeThumbColor: Colors.redAccent,
                                      inactiveTrackColor: Colors.grey.shade300,
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                // Power BI Status
                                _buildPowerBIStatus(themeProvider),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(child: getCurrentScreen()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.redAccent,
        onPressed: fetchStats,
        tooltip: "Refresh stats",
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildTopBarIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ThemeProvider themeProvider,
    int? badgeCount,
  }) {
    final isDark = themeProvider.isDarkMode;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(icon,
                color: isDark ? Colors.white70 : const Color(0xFF666666)),
            onPressed: onPressed,
            tooltip: icon == Icons.mail_outline ? "Messages" : "Notifications",
          ),
        ),
        if (badgeCount != null && badgeCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFC10D00),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                badgeCount > 9 ? '9+' : badgeCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPowerBIStatus(ThemeProvider themeProvider) {
    return InkWell(
      onTap: fetchPowerBIStatus,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: (powerBIConnected ? Colors.green : Colors.red)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (powerBIConnected ? Colors.green : Colors.red)
                .withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            if (checkingPowerBI)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.blue),
              )
            else
              Icon(
                Icons.bar_chart,
                color: powerBIConnected ? Colors.green : Colors.red,
                size: 16,
              ),
            const SizedBox(width: 8),
            Text(
              "Power BI",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: powerBIConnected ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void toggleSidebar() {
    setState(() {
      sidebarCollapsed = !sidebarCollapsed;
      if (sidebarCollapsed) {
        _sidebarAnimController.forward();
      } else {
        _sidebarAnimController.reverse();
      }
    });
  }

  Widget _sidebarEntry(dynamic icon, String label, String screenKey) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final selected = currentScreen == screenKey;
    final isDark = themeProvider.isDarkMode;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => setState(() => currentScreen = screenKey),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFC10D00) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFFC10D00).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              icon is IconData
                  ? Icon(
                      icon,
                      size: 20,
                      color: selected
                          ? Colors.white
                          : (isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700),
                    )
                  : Image.asset(
                      icon as String,
                      width: 20,
                      height: 20,
                      color: selected
                          ? Colors.white
                          : (isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700),
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.insert_drive_file_outlined,
                        size: 20,
                        color: selected ? Colors.white : Colors.grey,
                      ),
                    ),
              if (!sidebarCollapsed) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : (isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700),
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

  Widget getCurrentScreen() {
    switch (currentScreen) {
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
        return auditsScreen();
      case "roles":
        return const UserManagementScreen();
      case "users":
        return const UserManagementScreen();
      default:
        return dashboardOverview(context);
    }
  }

  /// ------------------- AUDITS SCREEN -------------------
  Widget auditsScreen() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final List<StackedLineData> stackedAuditData = [
      StackedLineData('Jan', 12, 8, 5, 3, 2),
      StackedLineData('Feb', 15, 10, 7, 4, 3),
      StackedLineData('Mar', 18, 12, 9, 6, 4),
      StackedLineData('Apr', 14, 9, 6, 5, 3),
      StackedLineData('May', 20, 15, 11, 7, 5),
      StackedLineData('Jun', 22, 16, 12, 8, 6),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.analytics_outlined,
                      color: BrandTokens.primary, size: 28),
                  SizedBox(width: 8),
                  Text(
                    "Audit Analytics Dashboard",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: BrandTokens.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Icon(Icons.history, color: BrandTokens.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      "${audits.length} Records",
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          color: BrandTokens.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search and filters
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: auditSearchController,
                  decoration: InputDecoration(
                    hintText: "Search audit logs...",
                    hintStyle: const TextStyle(fontFamily: 'Poppins'),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: (themeProvider.isDarkMode
                            ? const Color(0xFF14131E)
                            : Colors.white)
                        .withValues(alpha: 0.9),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (val) {
                    auditSearchQuery = val;
                    fetchAudits(page: 1);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: (themeProvider.isDarkMode
                          ? const Color(0xFF14131E)
                          : Colors.white)
                      .withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: auditActionFilter,
                    hint: const Text("Action Type",
                        style: TextStyle(fontFamily: 'Poppins')),
                    items: [null, ...auditActions]
                        .map((e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(e ?? "All",
                                  style:
                                      const TextStyle(fontFamily: 'Poppins')),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() => auditActionFilter = val);
                      fetchAudits(page: 1);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stacked Line Chart for Audits
          ThemedSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 300,
              child: loadingAudits
                  ? const ThemedLoadingState(
                      message: 'Loading audit analytics...',
                    )
                  : SfCartesianChart(
                      title: ChartTitle(
                          text: "Audit Activity Trend - Stacked Lines",
                          textStyle: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: themeProvider.isDarkMode
                                  ? Colors.white
                                  : Colors.black87)),
                      plotAreaBorderWidth: 0,
                      primaryXAxis: CategoryAxis(
                        axisLine: const AxisLine(width: 1, color: Colors.grey),
                        majorGridLines: const MajorGridLines(width: 0),
                        labelStyle: TextStyle(
                            fontFamily: 'Poppins',
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black54),
                      ),
                      primaryYAxis: NumericAxis(
                        axisLine: const AxisLine(width: 1, color: Colors.grey),
                        majorGridLines: MajorGridLines(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        labelStyle: TextStyle(
                            fontFamily: 'Poppins',
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black54),
                      ),
                      tooltipBehavior: TooltipBehavior(
                        enable: true,
                        color: BrandTokens.primary,
                        borderColor: BrandTokens.primary,
                        textStyle: const TextStyle(
                            color: Colors.white, fontFamily: 'Poppins'),
                      ),
                      legend: Legend(
                        isVisible: true,
                        position: LegendPosition.bottom,
                        overflowMode: LegendItemOverflowMode.wrap,
                      ),
                      series: <CartesianSeries<StackedLineData, String>>[
                        StackedLineSeries<StackedLineData, String>(
                          dataSource: stackedAuditData,
                          xValueMapper: (data, _) => data.month,
                          yValueMapper: (data, _) => data.login,
                          name: 'Login',
                          color: BrandTokens.primary,
                          width: 3,
                          markerSettings: const MarkerSettings(isVisible: true),
                        ),
                        StackedLineSeries<StackedLineData, String>(
                          dataSource: stackedAuditData,
                          xValueMapper: (data, _) => data.month,
                          yValueMapper: (data, _) => data.logout,
                          name: 'Logout',
                          color: Colors.orangeAccent,
                          width: 3,
                          markerSettings: const MarkerSettings(isVisible: true),
                        ),
                        StackedLineSeries<StackedLineData, String>(
                          dataSource: stackedAuditData,
                          xValueMapper: (data, _) => data.month,
                          yValueMapper: (data, _) => data.create,
                          name: 'Create',
                          color: Colors.green,
                          width: 3,
                          markerSettings: const MarkerSettings(isVisible: true),
                        ),
                        StackedLineSeries<StackedLineData, String>(
                          dataSource: stackedAuditData,
                          xValueMapper: (data, _) => data.month,
                          yValueMapper: (data, _) => data.update,
                          name: 'Update',
                          color: BrandTokens.primary,
                          width: 3,
                          markerSettings: const MarkerSettings(isVisible: true),
                        ),
                        StackedLineSeries<StackedLineData, String>(
                          dataSource: stackedAuditData,
                          xValueMapper: (data, _) => data.month,
                          yValueMapper: (data, _) => data.delete,
                          name: 'Delete',
                          color: Colors.purpleAccent,
                          width: 3,
                          markerSettings: const MarkerSettings(isVisible: true),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Audit Log List
          ThemedSurfaceCard(
            padding: const EdgeInsets.all(12),
            child: loadingAudits
                ? const ThemedLoadingState(
                    message: 'Loading audit logs...',
                  )
                : audits.isEmpty
                    ? const ThemedEmptyState(
                        title: 'No audit logs found',
                        subtitle: 'Try changing your search or filters',
                        icon: Icons.history,
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        separatorBuilder: (_, __) =>
                            Divider(color: Colors.grey.shade200, height: 1),
                        itemCount: audits.length,
                        itemBuilder: (context, index) {
                          final audit = audits[index];
                          final action = audit['action'] ?? 'Unknown';
                          final timestamp = audit['timestamp'] ?? '';
                          final user = audit['user'] ?? 'System';
                          final icon = {
                                "login": Icons.login,
                                "logout": Icons.logout,
                                "create": Icons.add_circle_outline,
                                "update": Icons.edit_outlined,
                                "delete": Icons.delete_outline
                              }[action] ??
                              Icons.info_outline;

                          final color = {
                                "login": Colors.green,
                                "logout": Colors.orange,
                                "create": Colors.blueAccent,
                                "update": Colors.purpleAccent,
                                "delete": Colors.redAccent
                              }[action] ??
                              Colors.grey;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Icon(icon, color: color),
                            ),
                            title: Text(
                              "${action.toUpperCase()} • $user",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins'),
                            ),
                            subtitle: Text(
                              timestamp,
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontFamily: 'Poppins'),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                action,
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: color,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget dashboardOverview(BuildContext context) {
    if (loadingStats) {
      return const ThemedLoadingState(
        message: "Loading dashboard statistics...",
      );
    }

    // Filter appointments for interviews specifically
    final interviewsList = _calendarAppointments
        .where((a) => a.subject.toLowerCase().contains('interview'))
        .map((a) => {
              'job_title': a.subject.replaceFirst('Interview: ', ''),
              'candidate_name': '',
              'scheduled_time':
                  DateFormat('MMMM dd yyyy (HH:mm a)').format(a.startTime),
              'is_new': a.startTime.difference(DateTime.now()).inDays <= 1,
            })
        .toList();

    // Convert notifications to string list
    final updatesList = dashboardNotifications
        .map((n) => n['message'] as String? ?? 'New update')
        .toList();

    // Create CV trend data from real stats
    final cvTrendList = [
      CVData('Week 1', newApplicationsWeek),
      CVData('Week 2', cvReviewsCount),
      CVData('Week 3', interviewsCount),
      CVData('Week 4', offeredApplications),
      CVData('Week 5', acceptedOffers),
    ];

    // Create interview status data
    final interviewStatusDataList = [
      StatusData('Scheduled', upcomingInterviews, const Color(0xFF81829B)),
      StatusData('Pending', interviewsCount - upcomingInterviews,
          const Color(0xFF6095CC)),
      StatusData('Completed', 0, const Color(0xFF6CA510)),
    ];

    return Container(
      color: Colors.transparent,
      child: RefreshIndicator(
        onRefresh: () async {
          // Refresh all dashboard data
          await fetchStats();
          await _loadCalendarData();
          await _fetchTeamCollaboration();
          await _fetchDepartmentDistribution();
          await fetchDashboardNotifications();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Redundant header removed as it's now in the global TopBar
              const SizedBox(height: 8),
              // Row 1: Total Jobs, Candidates, Interviews
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: 'Total Jobs',
                      value: jobsCount.toString(),
                      subtitle:
                          'Additional description information can be included.',
                      icon: Icons.work_outline,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(
                      title: 'Candidates',
                      value: candidatesCount.toString(),
                      subtitle:
                          'Additional description information can be included.',
                      icon: Icons.people_outline,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(
                      title: 'Interviews',
                      value: interviewsCount.toString(),
                      subtitle:
                          'Additional description information can be included.',
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Row 2: Applications, Offers
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: MetricCard(
                      title: 'Applications',
                      value: cvReviewsCount.toString(),
                      subtitle:
                          'Additional description information can be included.',
                      icon: Icons.send_outlined,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: MetricCard(
                      title: 'Offers',
                      value: offeredApplications.toString(),
                      subtitle:
                          'Additional description information can be included.',
                      icon: Icons.trending_up,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Empty third slot to maintain 3-column alignment
                  const Expanded(flex: 1, child: SizedBox.shrink()),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        UpcomingInterviewsCard(
                          interviews: interviewsList,
                          onViewAll: () =>
                              setState(() => currentScreen = 'interviews'),
                        ),
                        const SizedBox(height: 20),
                        JobsByDepartmentCard(
                          departments: _departmentDistribution,
                          isLoading: _loadingDepartments,
                        ),
                        const SizedBox(height: 20),
                        InterviewStatusCard(statuses: interviewStatusDataList),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        RecentUpdatesCard(
                          updates: updatesList,
                          onViewAll: () =>
                              setState(() => currentScreen = 'notifications'),
                        ),
                        const SizedBox(height: 20),
                        CVReviewTrendCard(weeklyData: cvTrendList),
                        const SizedBox(height: 20),
                        TeamCollaborationCard(
                          items: _teamCollaborationItems,
                          isLoading: _loadingTeamCollaboration,
                          onViewAll: () => setState(
                              () => currentScreen = 'team_collaboration'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DashboardCalendarCard(
                focusedDay: focusedDay,
                appointments: _calendarAppointments,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget departmentRadialChart(List<_DepartmentData> data) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white)
                .withValues(alpha: 0.9),
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
                "Jobs by Department",
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
                  color: BrandTokens.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Distribution",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: BrandTokens.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SfCircularChart(
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    color: BrandTokens.primary,
                  ),
                  series: <CircularSeries>[
                    RadialBarSeries<_DepartmentData, String>(
                      dataSource: data,
                      xValueMapper: (d, _) => d.department,
                      yValueMapper: (d, _) => d.count,
                      maximumValue: 50,
                      trackOpacity: 0.3,
                      trackColor: Colors.grey.shade200,
                      trackBorderWidth: 0,
                      cornerStyle: CornerStyle.bothCurve,
                      gap: '8%',
                      innerRadius: '60%',
                      radius: '90%',
                      pointColorMapper: (d, _) => d.color,
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: true,
                        textStyle: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: BrandTokens.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: BrandTokens.primary, width: 2),
                  ),
                  child: const Icon(
                    Icons.work_outline,
                    color: BrandTokens.primary,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget candidateHistogram(List<_HistogramData> data) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white)
                .withValues(alpha: 0.9),
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
        color:
            (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white)
                .withValues(alpha: 0.9),
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
        color:
            (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white)
                .withValues(alpha: 0.9),
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
        color:
            (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white)
                .withValues(alpha: 0.9),
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
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade50,
                  Colors.purple.shade50,
                ],
              ),
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
              color: (themeProvider.isDarkMode
                      ? const Color(0xFF14131E)
                      : Colors.white)
                  .withValues(alpha: 0.9),
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
        color:
            (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white)
                .withValues(alpha: 0.9),
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
                    color: (themeProvider.isDarkMode
                            ? const Color(0xFF14131E)
                            : Colors.grey.shade50)
                        .withValues(alpha: 0.9),
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
class _DepartmentData {
  final String department;
  final int count;
  final Color color;
  _DepartmentData(this.department, this.count, this.color);
}

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
