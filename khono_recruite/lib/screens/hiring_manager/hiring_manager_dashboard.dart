import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import 'candidate_management_screen.dart';
import 'cv_reviews_screen.dart';
import '../notifications/notifications_screen.dart';
import 'job_management.dart';
import '../admin/interviews_list_screen.dart';
import 'offer_list_screen.dart';
import 'review_queue_screen.dart';
import 'hm_analytics_page.dart';
import 'hm_team_collaboration_page.dart';
import 'hiring_manager_profile_screen.dart';
import 'hiring_manager_settings_screen.dart';
import 'pipeline_page.dart';
import 'meeting_screen.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/api_endpoints.dart';
import '../../utils/app_config.dart';
import '../../services/notification_service.dart';
// ignore: unused_import - json.decode used in fetchAudits, fetchPipelineActivity, fetchChartData
import 'dart:convert';

/// Normalizes shorthand paths (`images/…`, `icons/…`) to full pubspec keys.
String _hmNormalizeAssetPath(String path) {
  final p = path.trim();
  if (p.startsWith('assets/')) return p;
  if (p.startsWith('images/')) return 'assets/$p';
  if (p.startsWith('icons/')) return 'assets/$p';
  return p;
}

/// On Flutter web, [Image.asset] sometimes requests `assets/assets/…` and returns 404.
/// We load via [Image.network] using the **host root**, not [Uri.base.path] (e.g. `/login`),
/// otherwise the server returns HTML (`<!DOCTYPE…`) and decoding fails with [ImageCodecException].
Widget _hmDashboardAssetImage(
  String assetPath, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  final path = _hmNormalizeAssetPath(assetPath);
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

class _DashboardCalendarDataSource extends CalendarDataSource {
  _DashboardCalendarDataSource(List<Appointment> source) {
    appointments = source;
  }
}

class HMMainDashboard extends StatefulWidget {
  final String token;
  const HMMainDashboard({super.key, required this.token});

  @override
  _HMMainDashboardState createState() => _HMMainDashboardState();
}

class _HMMainDashboardState extends State<HMMainDashboard>
    with SingleTickerProviderStateMixin {
  static const Color _palettePrimary = Color(0xFFCF2030);
  static const Color _paletteWhite = Color(0xFFFFFFFF);
  static const Color _paletteInk = Color(0xFF090812);
  static const Color _paletteCharcoal = Color(0xFF3D3F40);
  static const Color _paletteSteel = Color(0xFF727576);
  static const Color _paletteSilver = Color(0xFFB0B6BB);
  static const Color _paletteCanvas = Color(0xFFF8F6F3);
  static const Color _palettePeriwinkle = Color(0xFF81829B);
  static const Color _palettePurple = Color(0xFF5C389D);
  static const Color _paletteBlue = Color(0xFF6095CC);
  static const Color _paletteOrange = Color(0xFFEA990C);
  static const Color _paletteYellow = Color(0xFFE7BE2D);
  static const Color _paletteGreen = Color(0xFF6CA510);
  static const List<Color> _paletteAccents = [
    _palettePeriwinkle,
    _palettePurple,
    _paletteBlue,
    _paletteOrange,
    _paletteYellow,
    _paletteGreen,
  ];

  /// Dark mode: #3D3F40 ([_paletteCharcoal]) at 60% so the background image shows through.
  static Color _darkWidgetSurface() => _paletteCharcoal.withValues(alpha: 0.6);

  /// Dashboard body copy: pure white in dark mode, pure black in light mode.
  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _pureBlack = Color(0xFF000000);

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
  int candidatesWithAssessments = 0;
  int completedInterviews = 0;
  int scheduledInterviews = 0;
  int upcomingInterviews = 0;
  int newApplicationsWeek = 0;
  int newInterviewsWeek = 0;

  // Candidate-related variables
  bool loadingCandidates = true;
  int candidatePage = 1;

  /// Larger page so Candidate Overview can list everyone returned for the HM scope.
  int candidatePerPage = 200;
  List<Map<String, dynamic>> candidates = [];
  String? candidateSearchQuery;

  // Chart data variables
  bool loadingChartData = true;
  List<_ChartData> candidatePipelineData = [];
  List<_ChartData> timeToFillData = [];
  List<_ChartData> genderData = [];
  List<_ChartData> ethnicityData = [];
  List<_ChartData> sourcePerformanceData = [];
  List<_ChartData> skillsData = [];
  List<_ChartData> experienceData = [];
  List<_ChartData> cvScreeningData = [];
  List<_ChartData> assessmentData = [];
  List<_ChartData> auditTrendData = [];

  // Additional data
  Map<String, dynamic> candidateDemographics = {};
  List<Map<String, dynamic>> recentCandidates = [];

  Map<String, dynamic> applicationStatusBreakdown = {};

  int? selectedJobId;

  // Calendar state
  DateTime focusedDay = DateTime.now();
  DateTime selectedDay = DateTime.now();

  // Navigation helpers for calendar
  void _previousMonth() {
    setState(() {
      focusedDay = DateTime(focusedDay.year, focusedDay.month - 1, 1);
    });
    _loadCalendarData();
  }

  void _nextMonth() {
    setState(() {
      focusedDay = DateTime(focusedDay.year, focusedDay.month + 1, 1);
    });
    _loadCalendarData();
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  final AdminService admin = AdminService();

  List<String> recentActivities = [];

  // Display name for the logged-in user (shared with Team Collaboration semantics)
  String userName = "Hiring Manager";

  /// Use role-based name when stored name is null, empty, or a placeholder (e.g. "Deployed Hiring Manager").
  String _effectiveWelcomeName(String? name) {
    if (name == null || name.trim().isEmpty) return 'Hiring Manager';
    if (name.toLowerCase().contains('deployed')) return 'Hiring Manager';
    return name.trim();
  }

  bool sidebarCollapsed = false;
  bool candidateMenuExpanded = false;
  late final AnimationController _sidebarAnimController;
  late final Animation<double> _sidebarWidthAnimation;

  // --- Team Collaboration mock data (previously audits) ---
  List<String> teamMessages = [
    "John: Completed the candidate screening.",
    "Mary: Scheduled interviews for next week.",
    "Alex: Uploaded new CVs to review.",
    "Lisa: Updated job descriptions.",
  ];

  // --- Audits ---
  List<Map<String, dynamic>> audits = [];
  int auditPage = 1;
  int auditPerPage = 20;
  String? auditActionFilter;
  DateTime? auditStartDate;
  DateTime? auditEndDate;
  String? auditSearchQuery;
  bool loadingAudits = true;

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

  // Pipeline activity (who advanced/declined and when) - for HM and admin
  List<Map<String, dynamic>> pipelineActivity = [];
  bool loadingPipelineActivity = false;

  // Notifications for dashboard widget (status changes + upcoming interviews)
  List<Map<String, dynamic>> dashboardNotifications = [];
  bool loadingNotifications = false;
  int unreadNotificationCount = 0;

  String get apiBase => AppConfig.apiBase + "/api/candidate";

  // Calendar appointments (interviews + meetings)
  List<Appointment> _calendarAppointments = [];
  bool _calendarLoading = false;

  @override
  void initState() {
    super.initState();
    userName = AuthService.getCachedDisplayName() ?? "Hiring Manager";
    fetchStats();
    fetchCandidates();
    fetchChartData();
    fetchAudits(page: 1);
    fetchPipelineActivity();
    fetchDashboardNotifications();
    _fetchUnreadNotificationCount();
    _loadUserName();
    _loadCalendarData();

    _sidebarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _sidebarWidthAnimation = Tween<double>(begin: 260, end: 72).animate(
      CurvedAnimation(parent: _sidebarAnimController, curve: Curves.easeInOut),
    );
  }

  // --- Candidate Data Fetching ---
  Future<void> fetchCandidates({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        loadingCandidates = true;
        candidatePage = 1;
        candidates.clear();
      });
    }

    try {
      final list = await admin.getCandidatesWithDetails(
        page: candidatePage,
        perPage: candidatePerPage,
        search: candidateSearchQuery,
      );

      setState(() {
        if (refresh || candidatePage == 1) {
          candidates = List<Map<String, dynamic>>.from(list);
        } else {
          candidates.addAll(List<Map<String, dynamic>>.from(list));
        }
        loadingCandidates = false;
      });
    } catch (e) {
      setState(() {
        loadingCandidates = false;
      });
      _showErrorSnackBar('Failed to fetch candidates: $e');
    }
  }

  @override
  void dispose() {
    _sidebarAnimController.dispose();
    auditSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    try {
      final info = await AuthService.getUserInfo();
      if (info == null) return;

      // Try a few common keys defensively
      final profile = info['profile'] ?? {};
      final candidate = info['candidate'] ?? {};

      final name = info['full_name'] ??
          info['name'] ??
          profile['full_name'] ??
          profile['name'] ??
          candidate['full_name'] ??
          candidate['name'];

      if (name is String && name.trim().isNotEmpty) {
        setState(() {
          userName = name.trim();
        });
      }
    } catch (e) {
      debugPrint('Failed to load user name: $e');
    }
  }

  Future<void> _loadCalendarData() async {
    if (_calendarLoading) return;
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
            startDate: startStr, endDate: endStr);
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
        appointments.add(Appointment(
          startTime: startTime,
          endTime: endTime,
          subject: map['title'] as String? ?? 'Meeting',
          color: Colors.blue,
        ));
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
        appointments.add(Appointment(
          startTime: startTime,
          endTime: endTime,
          subject:
              'Interview: $jobTitle${candidateName.isNotEmpty ? ' – $candidateName' : ''}',
          color: Colors.deepOrange,
        ));
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

  // ---------- Error Handling ----------
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // ---------- Dashboard Stats ----------
  Future<void> fetchStats() async {
    setState(() => loadingStats = true);
    try {
      final data = await admin.getDashboardCounts();
      final role = await AuthService.getRole();

      List<String> activities = [];
      if (role == "admin") {
        final token = await AuthService.getAccessToken();
        final res = await http.get(
          Uri.parse(AppConfig.apiBase + "/api/admin/audits/recent"),
          headers: {"Authorization": "Bearer $token"},
        );
        if (res.statusCode == 200) {
          final audits = json.decode(res.body) as List;
          activities =
              audits.map((a) => a['action']?.toString() ?? '').take(5).toList();
        }
      }

      setState(() {
        jobsCount = data['jobs'] ?? 0;
        candidatesCount = data['candidates'] ?? 0;
        interviewsCount = data['interviews'] ?? 0;
        cvReviewsCount = data['cv_reviews'] ?? 0;
        auditsCount = data['audits'] ?? 0;

        // Enhanced metrics
        activeJobs = data['active_jobs'] ?? 0;
        candidatesWithCV = data['candidates_with_cv'] ?? 0;
        candidatesWithAssessments = data['candidates_with_assessments'] ?? 0;
        completedInterviews = data['completed_interviews'] ?? 0;
        scheduledInterviews = data['scheduled_interviews'] ?? 0;
        upcomingInterviews = data['upcoming_interviews'] ?? 0;
        newApplicationsWeek = data['recent_activity']['new_applications'] ?? 0;
        newInterviewsWeek = data['recent_activity']['new_interviews'] ?? 0;

        applicationStatusBreakdown = data['application_status_breakdown'] ?? {};

        // Enhanced candidate demographics
        candidateDemographics = data['candidate_demographics'] ?? {};
        recentCandidates =
            List<Map<String, dynamic>>.from(data['recent_candidates'] ?? []);

        recentActivities = activities;
        loadingStats = false;
      });
    } catch (e) {
      setState(() {
        loadingStats = false;
      });
      _showErrorSnackBar('Failed to fetch dashboard stats: $e');
    }
  }

  Future<void> fetchChartData() async {
    setState(() => loadingChartData = true);
    try {
      final token = await AuthService.getAccessToken();
      final headers = {"Authorization": "Bearer $token"};

      // Fetch candidate pipeline data (applications per requisition)
      final pipelineRes = await http.get(
        Uri.parse(ApiEndpoints.getApplicationsPerRequisition),
        headers: headers,
      );
      if (pipelineRes.statusCode == 200) {
        final data = json.decode(pipelineRes.body) as List;
        candidatePipelineData = data
            .map((item) => _ChartData(
                  item['title'] ?? 'Unknown',
                  item['applications'] ?? 0,
                ))
            .toList();
      }

      // Fetch time to fill data (time per stage)
      final timeRes = await http.get(
        Uri.parse(ApiEndpoints.getTimePerStage),
        headers: headers,
      );
      if (timeRes.statusCode == 200) {
        final data = json.decode(timeRes.body) as List;
        // Calculate average time to interview
        final validTimes = data
            .where((item) => item['time_to_interview_days'] != null)
            .toList();
        if (validTimes.isNotEmpty) {
          final avgTime = validTimes
                  .map((item) => item['time_to_interview_days'] as int)
                  .reduce((a, b) => a + b) /
              validTimes.length;
          timeToFillData = [
            _ChartData("Avg Time to Interview", avgTime.round())
          ];
        }
      }

      // Fetch gender diversity data if available
      try {
        final genderRes = await http.get(
          Uri.parse(ApiEndpoints.getGenderDistribution),
          headers: headers,
        );
        if (genderRes.statusCode == 200) {
          final data = json.decode(genderRes.body) as List;
          genderData = data
              .map((item) => _ChartData(
                    item['gender'] ?? 'Unknown',
                    item['count'] ?? 0,
                  ))
              .toList();
        } else {
          // Fallback to conversion rate if gender endpoint not available
          final conversionRes = await http.get(
            Uri.parse(ApiEndpoints.getApplicationToInterviewConversion),
            headers: headers,
          );
          if (conversionRes.statusCode == 200) {
            final data = json.decode(conversionRes.body);
            genderData = [
              _ChartData("Interview Rate",
                  (data['conversion_rate_percent'] ?? 0).toInt()),
            ];
          }
        }
      } catch (e) {
        // Use fallback data
        final conversionRes = await http.get(
          Uri.parse(ApiEndpoints.getApplicationToInterviewConversion),
          headers: headers,
        );
        if (conversionRes.statusCode == 200) {
          final data = json.decode(conversionRes.body);
          genderData = [
            _ChartData("Interview Rate",
                (data['conversion_rate_percent'] ?? 0).toInt()),
          ];
        }
      }

      // Fetch ethnicity diversity data if available
      try {
        final ethnicityRes = await http.get(
          Uri.parse(ApiEndpoints.getEthnicityDistribution),
          headers: headers,
        );
        if (ethnicityRes.statusCode == 200) {
          final data = json.decode(ethnicityRes.body) as List;
          ethnicityData = data
              .map((item) => _ChartData(
                    item['ethnicity'] ?? 'Unknown',
                    item['count'] ?? 0,
                  ))
              .toList();
        } else {
          // Fallback to dropoff data
          final dropoffRes = await http.get(
            Uri.parse(ApiEndpoints.getStageDropoff),
            headers: headers,
          );
          if (dropoffRes.statusCode == 200) {
            final data = json.decode(dropoffRes.body);
            ethnicityData = [
              _ChartData("Total Applications", data['total_applications'] ?? 0),
              _ChartData("Interviewed", data['interviewed'] ?? 0),
              _ChartData("Offered", data['offered'] ?? 0),
            ];
          }
        }
      } catch (e) {
        // Use fallback data
        final dropoffRes = await http.get(
          Uri.parse(ApiEndpoints.getStageDropoff),
          headers: headers,
        );
        if (dropoffRes.statusCode == 200) {
          final data = json.decode(dropoffRes.body);
          ethnicityData = [
            _ChartData("Total Applications", data['total_applications'] ?? 0),
            _ChartData("Interviewed", data['interviewed'] ?? 0),
            _ChartData("Offered", data['offered'] ?? 0),
          ];
        }
      }

      // Fetch source performance data (applications per month)
      final monthlyRes = await http.get(
        Uri.parse(ApiEndpoints.getMonthlyApplications),
        headers: headers,
      );
      if (monthlyRes.statusCode == 200) {
        final data = json.decode(monthlyRes.body) as List;
        sourcePerformanceData = data
            .take(6)
            .map((item) => _ChartData(
                  item['month'] ?? 'Unknown',
                  item['applications'] ?? 0,
                ))
            .toList();
      }

      // Fetch additional analytics data for comprehensive dashboard
      try {
        // Skills frequency data (API returns Map<String, int>: skill name -> count)
        final skillsRes = await http.get(
          Uri.parse(ApiEndpoints.getSkillsFrequency),
          headers: headers,
        );
        if (skillsRes.statusCode == 200) {
          final raw = json.decode(skillsRes.body);
          if (raw is Map<String, dynamic>) {
            skillsData = raw.entries
                .take(10)
                .map((e) => _ChartData(
                      e.key,
                      (e.value is num) ? (e.value as num).toInt() : 0,
                    ))
                .toList();
          } else if (raw is List) {
            skillsData = raw
                .take(10)
                .map((item) => _ChartData(
                      item['skill']?.toString() ?? 'Unknown',
                      (item['frequency'] is num)
                          ? (item['frequency'] as num).toInt()
                          : 0,
                    ))
                .toList();
          }
        }
      } catch (e) {
        debugPrint("Error fetching skills data: $e");
      }

      try {
        // Experience distribution (API returns Map: years/key -> count)
        final experienceRes = await http.get(
          Uri.parse(ApiEndpoints.getExperienceDistribution),
          headers: headers,
        );
        if (experienceRes.statusCode == 200) {
          final raw = json.decode(experienceRes.body);
          if (raw is Map<String, dynamic>) {
            experienceData = raw.entries
                .map((e) => _ChartData(
                      '${e.key} yrs',
                      (e.value is num) ? (e.value as num).toInt() : 0,
                    ))
                .toList();
          } else if (raw is Map) {
            experienceData = raw.entries
                .map((e) => _ChartData(
                      '${e.key} yrs',
                      (e.value is num) ? (e.value as num).toInt() : 0,
                    ))
                .toList();
          } else if (raw is List) {
            experienceData = raw
                .map((item) => _ChartData(
                      item['experience_level']?.toString() ?? 'Unknown',
                      (item['count'] is num)
                          ? (item['count'] as num).toInt()
                          : 0,
                    ))
                .toList();
          }
        }
      } catch (e) {
        debugPrint("Error fetching experience data: $e");
      }

      try {
        // CV screening drop trends
        final cvDropRes = await http.get(
          Uri.parse(ApiEndpoints.getCVScreeningDrop),
          headers: headers,
        );
        if (cvDropRes.statusCode == 200) {
          final data = json.decode(cvDropRes.body) as List;
          cvScreeningData = data
              .map((item) => _ChartData(
                    item['date'] ?? 'Unknown',
                    item['drop_count'] ?? 0,
                  ))
              .toList();
        }
      } catch (e) {
        debugPrint("Error fetching CV screening data: $e");
      }

      try {
        // Assessment pass rates
        final assessmentRes = await http.get(
          Uri.parse(ApiEndpoints.getAssessmentPassRate),
          headers: headers,
        );
        if (assessmentRes.statusCode == 200) {
          final data = json.decode(assessmentRes.body) as List;
          assessmentData = data
              .map((item) => _ChartData(
                    item['date'] ?? 'Unknown',
                    item['pass_rate'] ?? 0,
                  ))
              .toList();
        }
      } catch (e) {
        debugPrint("Error fetching assessment data: $e");
      }
    } catch (e) {
      debugPrint("Error fetching chart data: $e");
    } finally {
      setState(() => loadingChartData = false);
    }
  }

  Future<void> fetchAudits({int page = 1}) async {
    setState(() => loadingAudits = true);
    try {
      final role = await AuthService.getRole();
      if (role != "admin") {
        setState(() => loadingAudits = false);
        return;
      }

      final token = await AuthService.getAccessToken();
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
      final uri = Uri.parse(AppConfig.apiBase + "/api/admin/audits")
          .replace(queryParameters: queryParams);
      final res =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
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
      } else {
        setState(() => loadingAudits = false);
      }
    } catch (e) {
      setState(() => loadingAudits = false);
    }
  }

  Future<void> fetchPipelineActivity() async {
    setState(() => loadingPipelineActivity = true);
    try {
      final token = await AuthService.getAccessToken();
      final uri = Uri.parse(ApiEndpoints.pipelineActivity);
      final res =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final results = data["results"];
        setState(() {
          pipelineActivity = results is List
              ? List<Map<String, dynamic>>.from(
                  results.map((e) => Map<String, dynamic>.from(e as Map)))
              : [];
          loadingPipelineActivity = false;
        });
      } else {
        setState(() => loadingPipelineActivity = false);
      }
    } catch (e) {
      setState(() => loadingPipelineActivity = false);
    }
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
    // Do not pop here: confirmation dialog already closed by onPressed. Popping again would remove the last route (dashboard) and break go_router.
    await AuthService.logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      // ≡ƒîå Dynamic background implementation
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
                          ? _paletteCharcoal
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
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: sidebarCollapsed
                                        ? _hmDashboardAssetImage(
                                            'images/icon.png',
                                            height: 40,
                                            fit: BoxFit.contain,
                                          )
                                        : _hmDashboardAssetImage(
                                            'images/logo2.png',
                                            height: 40,
                                            fit: BoxFit.contain,
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
                                    color: themeProvider.isDarkMode
                                        ? Colors.grey.shade400
                                        : Colors.black,
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
                                  'images/Home_Remote_Work_Red_Badge_White.png',
                                  'Home',
                                  'dashboard'),
                              _sidebarEntry(
                                  Icons.person_outline, 'Profile', 'profile'),
                              _sidebarEntry(
                                  'assets/images/Approval_Red_Badge_White.png',
                                  'Jobs',
                                  'jobs'),
                              _candidateSidebarGroup(),
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
                              _sidebarEntryWithBadge(
                                  'images/Notification_Red_White.png',
                                  'Notifications',
                                  'notifications',
                                  badgeCount: unreadNotificationCount),
                              _sidebarEntry(
                                  'images/innovation_brainstorm_red_badge_white.png',
                                  'Settings',
                                  'settings'),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12.0, horizontal: 8),
                          child: Column(
                            children: [
                              if (!sidebarCollapsed)
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _showLogoutConfirmation(context),
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
                                )
                              else
                                IconButton(
                                  onPressed: () =>
                                      _showLogoutConfirmation(context),
                                  icon: Icon(
                                    Icons.logout,
                                    color: themeProvider.isDarkMode
                                        ? Colors.grey.shade400
                                        : Colors.black,
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
                child: getCurrentScreen(),
              ),
            ],
          ),
        ),
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

  bool _isCandidateMenuScreen(String screenKey) {
    return screenKey == 'candidates' ||
        screenKey == 'pipeline' ||
        screenKey == 'offers' ||
        screenKey == 'review_queue' ||
        screenKey == 'meetings';
  }

  Widget _buildSidebarIcon(
    dynamic icon,
    bool selected,
    Color iconColor,
    ThemeProvider themeProvider,
  ) {
    if (icon is IconData) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? Colors.white
              : themeProvider.isDarkMode
                  ? Colors.grey.shade700
                  : Colors.grey.shade200,
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected
              ? const Color(0xFFC10D00)
              : themeProvider.isDarkMode
                  ? Colors.white
                  : Colors.black,
        ),
      );
    }

    return _hmDashboardAssetImage(
      icon as String,
      width: 32,
      height: 32,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.error, color: iconColor, size: 32);
      },
    );
  }

  Widget _candidateSidebarGroup() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final selected = _isCandidateMenuScreen(currentScreen);
    final iconColor = selected
        ? const Color.fromRGBO(151, 18, 8, 1)
        : themeProvider.isDarkMode
            ? Colors.grey.shade400
            : Colors.black;

    return Column(
      children: [
        Container(
          color: selected ? const Color(0xFFC10D00) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => currentScreen = 'candidates'),
                  child: Row(
                    children: [
                      _buildSidebarIcon(
                        'assets/images/HR_Team_Management_White_Badge_Red.png',
                        selected,
                        iconColor,
                        themeProvider,
                      ),
                      if (!sidebarCollapsed) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Candidates',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: selected
                                  ? Colors.white
                                  : themeProvider.isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.black,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!sidebarCollapsed)
                InkWell(
                  onTap: () {
                    setState(() {
                      candidateMenuExpanded = !candidateMenuExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      candidateMenuExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: selected ? Colors.white : iconColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!sidebarCollapsed && candidateMenuExpanded) ...[
          _sidebarChildEntry(Icons.account_tree, 'Pipeline', 'pipeline'),
          _sidebarChildEntry(Icons.request_quote, 'Offers', 'offers'),
          _sidebarChildEntry(
            Icons.pending_actions,
            'Review queue',
            'review_queue',
          ),
          _sidebarChildEntry(Icons.video_call, 'Meetings', 'meetings'),
        ],
      ],
    );
  }

  Widget _sidebarChildEntry(dynamic icon, String label, String screenKey) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final selected = currentScreen == screenKey;
    final iconColor = selected
        ? const Color.fromRGBO(151, 18, 8, 1)
        : themeProvider.isDarkMode
            ? Colors.grey.shade400
            : Colors.black;

    return InkWell(
      onTap: () {
        setState(() {
          candidateMenuExpanded = true;
          currentScreen = screenKey;
        });
      },
      child: Container(
        color: selected
            ? const Color(0xFFC10D00).withValues(alpha: 0.12)
            : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(28, 10, 12, 10),
        child: Row(
          children: [
            Icon(icon as IconData, size: 18, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: selected
                      ? const Color(0xFFC10D00)
                      : themeProvider.isDarkMode
                          ? Colors.grey.shade400
                          : Colors.black,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarEntry(dynamic icon, String label, String screenKey,
      {VoidCallback? onTapOverride}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final selected = currentScreen == screenKey;
    final iconColor = selected
        ? const Color.fromRGBO(151, 18, 8, 1)
        : themeProvider.isDarkMode
            ? Colors.grey.shade400
            : Colors.black;
    return InkWell(
      onTap: onTapOverride ?? () => setState(() => currentScreen = screenKey),
      child: Container(
        color: selected ? const Color(0xFFC10D00) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            _buildSidebarIcon(icon, selected, iconColor, themeProvider),
            const SizedBox(width: 12),
            if (!sidebarCollapsed)
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: selected
                        ? Colors.white
                        : themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.black,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarEntryWithBadge(dynamic icon, String label, String screenKey,
      {int badgeCount = 0, VoidCallback? onTapOverride}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final selected = currentScreen == screenKey;
    final iconColor = selected
        ? const Color.fromRGBO(151, 18, 8, 1)
        : themeProvider.isDarkMode
            ? Colors.grey.shade400
            : Colors.black;
    return InkWell(
      onTap: onTapOverride ??
          () => setState(() {
                currentScreen = screenKey;
                // Clear badge when navigating to notifications
                if (screenKey == 'notifications') {
                  setState(() => unreadNotificationCount = 0);
                }
              }),
      child: Container(
        color: selected ? const Color(0xFFC10D00) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Stack(
          children: [
            Row(
              children: [
                _buildSidebarIcon(icon, selected, iconColor, themeProvider),
                const SizedBox(width: 12),
                if (!sidebarCollapsed)
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: selected
                            ? Colors.white
                            : themeProvider.isDarkMode
                                ? Colors.grey.shade400
                                : Colors.black,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                if (!sidebarCollapsed && badgeCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (sidebarCollapsed && badgeCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchUnreadNotificationCount() async {
    try {
      final response = await NotificationService.getNotifications();
      if (!mounted) return;
      setState(() {
        unreadNotificationCount = response.unreadCount;
      });
    } catch (e) {
      debugPrint('Failed to fetch unread notification count: $e');
    }
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
          onOpenTeamCollaboration: () =>
              setState(() => currentScreen = 'team_collaboration'),
          onOpenNotifications: () => setState(() {
            currentScreen = 'notifications';
            unreadNotificationCount = 0;
          }),
        );
      case "candidates":
        return CandidateManagementScreen(jobId: selectedJobId ?? 0);
      case "interviews":
        return const InterviewListScreen();
      case "cv_reviews":
        return CVReviewsScreen();
      case "pipeline":
        return RecruitmentPipelinePage(token: widget.token);
      case "offers":
        return AdminOfferListScreen(token: widget.token);
      case "review_queue":
        return const HiringManagerReviewQueueScreen();
      case "analytics":
        return HMAnalyticsPage();
      case "team_collaboration":
        return HMTeamCollaborationPage();
      case "meetings":
        return const HMMeetingsPage();
      case "notifications":
        return NotificationsScreen(onNotificationTap: _handleNotificationTap);
      case "settings":
        return HiringManagerSettingsScreen(
          token: widget.token,
          onBack: () => setState(() => currentScreen = 'dashboard'),
        );
      case "profile":
        return HiringManagerProfileScreen(
          token: widget.token,
          onBack: () => setState(() => currentScreen = 'dashboard'),
        );
      default:
        return dashboardOverview();
    }
  }

  // ---------------- Dashboard widgets ----------------

  /// Header actions (message, notifications): no background pill — asset only, larger tap target.
  Widget _hmDashboardHeaderIconButton({
    required String assetPath,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: _hmDashboardAssetImage(
              assetPath,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.image_not_supported_outlined,
                size: 32,
                color: _paletteSteel,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget dashboardOverview() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    if (loadingStats) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.redAccent));
    }

    final kpis = [
      {
        "title": "Total Jobs",
        "count": jobsCount,
        "subtitle": "Open requisitions currently managed by your team.",
        "color": _palettePrimary,
        "icon": 'assets/images/Task_Management_White_Badge_Red.png',
      },
      {
        "title": "Candidates",
        "count": candidatesCount,
        "subtitle": "Candidates active in your hiring pipeline.",
        "color": _palettePrimary,
        "icon": 'assets/images/Search_Seek_White_Badge_Red.png',
      },
      {
        "title": "Interviews",
        "count": interviewsCount,
        "subtitle": "Scheduled and completed interviews this cycle.",
        "color": _palettePrimary,
        "icon": 'images/Team.png',
      },
      {
        "title": "Applications",
        "count": cvReviewsCount,
        "subtitle": "Applications received across your requisitions.",
        "color": _palettePrimary,
        "icon": 'images/Send_Paper_Plane_White_Badge_Red.png',
      },
      {
        "title": "Offers",
        "count": 0,
        "subtitle": "Offers prepared or sent to shortlisted candidates.",
        "color": _palettePrimary,
        "icon": 'images/Project_Direction_Acceleration_Badge_Red.png',
      },
      {
        "title": "Assessments",
        "count": candidatesWithAssessments,
        "subtitle": "Candidates with completed assessment submissions.",
        "color": _palettePrimary,
        "icon": 'images/Document_Upload.png',
      },
    ];

    final overviewCandidates = List<Map<String, dynamic>>.from(candidates);
    final activities = pipelineActivity.take(6).toList();
    final sourceData = sourcePerformanceData.isNotEmpty
        ? sourcePerformanceData
        : <_ChartData>[
            _ChartData("LinkedIn", 40),
            _ChartData("Referral", 25),
            _ChartData("Job Boards", 20),
            _ChartData("Career Site", 10),
          ];

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Hiring Manager Dashboard',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? _pureWhite : _pureBlack,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Hello, ${_effectiveWelcomeName(userName)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? _pureWhite : _pureBlack,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Team collaboration',
                    child: _hmDashboardHeaderIconButton(
                      assetPath: 'assets/images/message.png',
                      onTap: () =>
                          setState(() => currentScreen = 'team_collaboration'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Notifications',
                    child: _hmDashboardHeaderIconButton(
                      assetPath: 'assets/images/blue_bell.png',
                      onTap: () => setState(() {
                        currentScreen = 'notifications';
                        unreadNotificationCount = 0;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildScreenshotKpiGrid(kpis, isDark),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildCandidateOverviewCard(overviewCandidates, isDark),
                        const SizedBox(height: 10),
                        _buildCandidatePipelineCard(isDark),
                        const SizedBox(height: 10),
                        _buildDiversityMetricsCard(isDark),
                        const SizedBox(height: 10),
                        _buildTeamCollaborationCard(isDark),
                        const SizedBox(height: 10),
                        _buildRecentActivitiesCard(activities, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        _buildDemographicsInsightsCard(isDark),
                        const SizedBox(height: 10),
                        _buildTimeToFillCard(isDark),
                        const SizedBox(height: 10),
                        _buildSourcePerformanceCard(sourceData, isDark),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildCalendarPanelCard(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreenshotKpiGrid(
      List<Map<String, dynamic>> items, bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 3.25,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildScreenshotKpiTile(items[i], isDark),
    );
  }

  Widget _buildScreenshotKpiTile(Map<String, dynamic> item, bool isDark) {
    final Color accent = item['color'] as Color;
    final isCandidatesWidget = item['title'] == "Candidates";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? _darkWidgetSurface()
            : _paletteCanvas.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item['title'] as String,
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        color: isDark ? _pureWhite : _pureBlack)),
                Text(
                  item['subtitle'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 7.5,
                      color: isDark ? _pureWhite : _pureBlack),
                ),
                const SizedBox(height: 2),
                Text('${item['count']}',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? _pureWhite : _pureBlack)),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            child: isCandidatesWidget
                ? _hmDashboardAssetImage(
                    'assets/images/HR_Team_Management_White_Badge_Red.png',
                    width: 48,
                    height: 48,
                  )
                : (item['icon'] is IconData)
                    ? Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: accent, shape: BoxShape.circle),
                        child: Icon(item['icon'] as IconData,
                            color: _paletteWhite, size: 14),
                      )
                    : _hmDashboardAssetImage(
                        item['icon'] as String,
                        width: 48,
                        height: 48,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(String title, bool isDark,
      {Widget? trailing,
      required Widget child,
      String? subtitle,
      String? titleLeadingAsset,
      Color? titleColor}) {
    final cardColor =
        isDark ? _darkWidgetSurface() : _paletteCanvas.withValues(alpha: 0.95);
    final headerStripColor =
        isDark ? _darkWidgetSurface() : const Color(0xFFECECEC);
    final headerBorderColor =
        isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300;
    final useRichHeader = titleLeadingAsset != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (useRichHeader) ...[
            Container(
              decoration: BoxDecoration(
                color: headerStripColor,
                border: Border(
                  bottom: BorderSide(color: headerBorderColor, width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _hmDashboardAssetImage(
                    titleLeadingAsset,
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.search,
                      color: _palettePrimary,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: titleColor ??
                                (isDark ? _pureWhite : _pureBlack),
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w400,
                              fontSize: 11,
                              height: 1.2,
                              color: isDark ? _pureWhite : _pureBlack,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: child,
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: titleColor ??
                                    (isDark ? _pureWhite : _pureBlack))),
                      ),
                      if (trailing != null) trailing,
                    ],
                  ),
                  const SizedBox(height: 8),
                  child,
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCandidateOverviewCard(
      List<Map<String, dynamic>> candidatesData, bool isDark) {
    return _buildDashboardCard(
      'Candidate Overview',
      isDark,
      subtitle:
          'Recent candidates in your pipeline with shortcuts to list and stages.',
      titleLeadingAsset: 'assets/images/SearchRed.png',
      trailing: TextButton(
        onPressed: () => setState(() => currentScreen = "candidates"),
        child: const Text('VIEW', style: TextStyle(fontSize: 10)),
      ),
      child: Column(
        children: candidatesData.isEmpty
            ? [
                Text('No candidate data available',
                    style: TextStyle(color: isDark ? _pureWhite : _pureBlack)),
              ]
            : candidatesData.map((c) {
                final name = _candidateDisplayName(c);
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? _paletteWhite.withValues(alpha: 0.08)
                        : _paletteCanvas,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _hmDashboardAssetImage(
                        _candidateOverviewRowAvatar,
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person,
                          size: 22,
                          color: _palettePrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? _pureWhite : _pureBlack)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => currentScreen = "pipeline"),
                        child: const Text('VIA', style: TextStyle(fontSize: 9)),
                      ),
                    ],
                  ),
                );
              }).toList(),
      ),
    );
  }

  String _candidateDisplayName(Map<String, dynamic> candidateRow) {
    final first = (candidateRow['first_name'] ?? '').toString().trim();
    final last = (candidateRow['last_name'] ?? '').toString().trim();
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;

    final profile = candidateRow['profile'];
    if (profile is Map<String, dynamic>) {
      final pFirst = (profile['first_name'] ?? '').toString().trim();
      final pLast = (profile['last_name'] ?? '').toString().trim();
      final pCombined = '$pFirst $pLast'.trim();
      if (pCombined.isNotEmpty) return pCombined;
      final pFull =
          (profile['full_name'] ?? profile['name'] ?? '').toString().trim();
      if (pFull.isNotEmpty) return pFull;
    }

    final full = (candidateRow['full_name'] ?? candidateRow['name'] ?? '')
        .toString()
        .trim();
    if (full.isNotEmpty) return full;

    return 'Unnamed Candidate';
  }

  Widget _buildDemographicsInsightsCard(bool isDark) {
    final gender = _mapEntries(candidateDemographics['gender_distribution']);
    final locations = _mapEntries(candidateDemographics['top_locations']);
    final education = _mapEntries(candidateDemographics['education_levels']);
    final List<_ChartData> skills =
        skillsData.isNotEmpty ? List<_ChartData>.from(skillsData.take(3)) : [];
    return _buildDashboardCard(
      'Candidate Demographics & Insights',
      isDark,
      subtitle:
          'Skills, gender, locations, and education for candidates in your pool.',
      titleLeadingAsset:
          'assets/images/Innovation_Brainstorm_White_Badge_Red.png',
      child: Column(
        children: [
          Row(
            children: [
              _metricSectionTitle(
                label: 'Gender Distribution:',
                icon: 'assets/images/red_Management_Red_Badge_White.png',
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _metricSectionTitle(
                label: 'Top Skills:',
                icon: 'assets/images/bagde_red.png',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _smallPairList('', gender, isDark)),
              const SizedBox(width: 12),
              Expanded(child: _smallChartDataList('', skills, isDark)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _metricSectionTitle(
                label: 'Top Locations:',
                icon: 'assets/images/Location_Pin_Point_Red_Badge_White.png',
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _metricSectionTitle(
                label: 'Education Levels:',
                icon: 'assets/images/bagde_red.png',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _smallPairList('', locations, isDark)),
              const SizedBox(width: 12),
              Expanded(child: _smallPairList('', education, isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricSectionTitle({
    required String label,
    required dynamic icon, // Changed to dynamic
    required bool isDark,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon is IconData)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _palettePrimary.withValues(alpha: 0.95),
                  ),
                  child: Icon(icon, size: 14, color: _paletteWhite),
                )
              else
                _hmDashboardAssetImage(
                  icon as String,
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _palettePrimary.withValues(alpha: 0.95),
                    ),
                    child: const Icon(Icons.image_not_supported_outlined,
                        size: 14, color: _paletteWhite),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? _pureWhite : _pureBlack,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            color: isDark
                ? _paletteSilver.withValues(alpha: 0.25)
                : _paletteSteel.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, int>> _mapEntries(dynamic raw) {
    if (raw is! Map) return [const MapEntry('N/A', 0)];
    return raw.entries
        .map((e) => MapEntry(e.key.toString(), (e.value as num?)?.toInt() ?? 0))
        .toList();
  }

  Widget _smallPairList(
      String title, List<MapEntry<String, int>> data, bool isDark) {
    final rows =
        data.isEmpty ? [const MapEntry('N/A', 0)] : data.take(3).toList();
    final total = rows.fold<int>(0, (p, e) => p + e.value).clamp(1, 999999);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(title,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? _pureWhite : _pureBlack)),
        if (title.isNotEmpty) const SizedBox(height: 3),
        ...rows.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(e.key,
                        style: TextStyle(
                            fontSize: 9,
                            color: isDark ? _pureWhite : _pureBlack)),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _paletteWhite,
                      shape: BoxShape.circle,
                    ),
                    child: Text('${e.value}',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _paletteInk)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 36),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _paletteSteel.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${((e.value / total) * 100).round()}%',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: _paletteWhite,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _smallChartDataList(String title, List<_ChartData> data, bool isDark) {
    final rows = data.isEmpty ? [_ChartData('N/A', 0)] : data;
    final total = rows.fold<int>(0, (p, e) => p + e.value).clamp(1, 999999);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(title,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? _pureWhite : _pureBlack)),
        if (title.isNotEmpty) const SizedBox(height: 3),
        ...rows.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(e.label,
                        style: TextStyle(
                            fontSize: 9,
                            color: isDark ? _pureWhite : _pureBlack)),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _paletteWhite,
                      shape: BoxShape.circle,
                    ),
                    child: Text('${e.value}',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _paletteInk)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 36),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _paletteSteel.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${((e.value / total) * 100).round()}%',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: _paletteWhite,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildCandidatePipelineCard(bool isDark) {
    final data = candidatePipelineData.isEmpty
        ? [
            _ChartData('Applied', 0),
            _ChartData('Screened', 0),
            _ChartData('Interviewed', 0),
            _ChartData('Offers', 0),
            _ChartData('Hired', 0),
          ]
        : candidatePipelineData;
    final maxVal =
        data.map((e) => e.value).fold<int>(1, (a, b) => a > b ? a : b);
    return _buildDashboardCard(
      'Candidate Pipeline',
      isDark,
      subtitle: 'Headcount at each hiring stage from applied through hired.',
      titleLeadingAsset:
          'assets/images/Process_Flows_Automation_White_Badge_Red.png',
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: data.map((e) {
            final h = ((e.value / maxVal) * 95).clamp(8, 95).toDouble();
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${e.value}',
                        style: TextStyle(
                            fontSize: 8,
                            color: isDark ? _pureWhite : _pureBlack)),
                    const SizedBox(height: 3),
                    Container(
                        height: h,
                        decoration: BoxDecoration(
                            color: _palettePrimary,
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 4),
                    Text(e.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 8,
                            color: isDark ? _pureWhite : _pureBlack)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTimeToFillCard(bool isDark) {
    final data = timeToFillData.isEmpty
        ? [
            _ChartData('Oct 25', 30),
            _ChartData('Nov 25', 28),
            _ChartData('Dec 25', 35),
            _ChartData('Jan 26', 31),
            _ChartData('Feb 26', 27),
            _ChartData('Mar 26', 23),
          ]
        : timeToFillData;
    final maxVal =
        data.map((e) => e.value).fold<int>(1, (a, b) => a > b ? a : b);
    return _buildDashboardCard(
      'Time-to-Fill Trend',
      isDark,
      subtitle: 'Typical days to fill roles over the last several months.',
      titleLeadingAsset:
          'assets/images/Time_Allocation_Approval_White_Badge_Red.png',
      child: SizedBox(
        height: 150,
        child: CustomPaint(
          painter: _LineChartPainter(data, maxVal, isDark),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _buildDiversityMetricsCard(bool isDark) {
    return _buildDashboardCard(
      'Diversity Metrics',
      isDark,
      subtitle: 'Share of candidates by gender and ethnicity for reporting.',
      titleLeadingAsset: 'assets/images/Sprints.png',
      child: Row(
        children: [
          Expanded(
              child: _simpleDonutLegend('Gender:', genderData, isDark,
                  iconPath:
                      'assets/images/red_Management_Red_Badge_White.png')),
          const SizedBox(width: 8),
          Expanded(
              child: _simpleDonutLegend('Ethnicity:', ethnicityData, isDark)),
        ],
      ),
    );
  }

  Widget _simpleDonutLegend(String title, List<_ChartData> data, bool isDark,
      {String? iconPath}) {
    final values =
        data.isEmpty ? [_ChartData('Unknown', 100)] : data.take(4).toList();
    final total = values.fold<int>(0, (p, e) => p + e.value).clamp(1, 999999);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? _pureWhite : _pureBlack)),
            ),
            if (iconPath != null) ...[
              const SizedBox(width: 4),
              _hmDashboardAssetImage(
                iconPath,
                height: 12,
                width: 12,
                errorBuilder: (_, __, ___) =>
                    const SizedBox(width: 12, height: 12),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ...values.asMap().entries.map((entry) {
          final idx = entry.key;
          final e = entry.value;
          final pct = ((e.value / total) * 100).round();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _paletteAccents[idx % _paletteAccents.length]
                        .withValues(
                            alpha: (0.55 + (pct / 100)).clamp(0.55, 1.0)),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(e.label,
                      style: TextStyle(
                          fontSize: 8,
                          color: isDark ? _pureWhite : _pureBlack)),
                ),
                Text('$pct%',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: isDark ? _pureWhite : _pureBlack)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSourcePerformanceCard(List<_ChartData> data, bool isDark) {
    final maxVal =
        data.map((e) => e.value).fold<int>(1, (a, b) => a > b ? a : b);
    return _buildDashboardCard(
      'Source Performance',
      isDark,
      subtitle: 'Which sourcing channels are driving the most applications.',
      titleLeadingAsset: 'assets/images/Goal_Target_White_Badge_Red.png',
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: data.asMap().entries.map((entry) {
            final idx = entry.key;
            final e = entry.value;
            final h = ((e.value / maxVal) * 95).clamp(10, 95).toDouble();
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${e.value}',
                        style: TextStyle(
                            fontSize: 8,
                            color: isDark ? _pureWhite : _pureBlack)),
                    const SizedBox(height: 3),
                    Container(
                      height: h,
                      decoration: BoxDecoration(
                        color: _paletteAccents[idx % _paletteAccents.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(e.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 8,
                            color: isDark ? _pureWhite : _pureBlack)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTeamCollaborationCard(bool isDark) {
    return _buildDashboardCard(
      'Team Collaboration',
      isDark,
      subtitle: 'Quick team notes; use the bell to jump to full notifications.',
      titleLeadingAsset:
          'assets/images/Networking_Collaboration_White_Badge__Red.png',
      trailing: InkWell(
        onTap: () => setState(() {
          currentScreen = 'notifications';
          unreadNotificationCount = 0;
        }),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _paletteWhite,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(5),
                child: Icon(
                  Icons.notifications_outlined,
                  size: 16,
                  color: _paletteInk,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$unreadNotificationCount',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? _pureWhite : _pureBlack,
                ),
              ),
            ],
          ),
        ),
      ),
      child: Column(
        children: teamMessages.take(5).map((m) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _palettePrimary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child:
                      const Icon(Icons.check, size: 10, color: _paletteWhite),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    m,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 9, color: isDark ? _pureWhite : _pureBlack),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentActivitiesCard(
      List<Map<String, dynamic>> items, bool isDark) {
    final list = items.isEmpty
        ? [
            {"action": "No recent activities", "details": ""}
          ]
        : items;
    return _buildDashboardCard(
      'Recent Activities',
      isDark,
      subtitle: 'Latest hiring and account actions logged for your workspace.',
      titleLeadingAsset: 'assets/images/bell_red.png',
      child: Column(
        children: list.map((a) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _palettePrimary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child:
                      const Icon(Icons.check, size: 10, color: _paletteWhite),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${a['action'] ?? 'Update'} ${a['details'] ?? ''}'.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 9, color: isDark ? _pureWhite : _pureBlack),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static const String _calendarHeaderIconAsset =
      'assets/images/Date_Picker_White_Badge_Red.png';
  static const String _candidateOverviewRowAvatar =
      'assets/images/red_user_profile.png';

  Widget _buildCalendarPanelCard(bool isDark) {
    return _buildDashboardCard(
      'Calendar',
      isDark,
      subtitle:
          'Interviews and meetings by day—tap a date for details or long-press to add.',
      titleLeadingAsset: _calendarHeaderIconAsset,
      titleColor: isDark ? _pureWhite : _palettePrimary,
      trailing: Tooltip(
        message: 'View calendar analytics',
        child: TextButton(
          onPressed: () => _showCalendarAnalytics(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: isDark ? _pureWhite : _palettePrimary,
          ),
          child: const Text(
            'VIEW',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ),
      ),
      child: _hmEmbeddedMonthCalendar(),
    );
  }

  /// Month grid only: no duplicate header, no Syncfusion title bar, no daily summary strip.
  Widget _hmEmbeddedMonthCalendar() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return SizedBox(
      height: 400,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? _darkWidgetSurface()
              : _paletteWhite.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _paletteCharcoal.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: _calendarLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: isDark ? _palettePrimary : null,
                ),
              )
            : Column(
                children: [
                  // Custom header with Material Icons (replaces broken Syncfusion icons)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.chevron_left,
                          color: isDark ? _pureWhite : _paletteInk,
                        ),
                        onPressed: _previousMonth,
                        tooltip: 'Previous month',
                      ),
                      Text(
                        '${_monthName(focusedDay.month)} ${focusedDay.year}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? _pureWhite : _paletteInk,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.chevron_right,
                          color: isDark ? _pureWhite : _paletteInk,
                        ),
                        onPressed: _nextMonth,
                        tooltip: 'Next month',
                      ),
                    ],
                  ),
                  Expanded(
                    child: SfCalendar(
                      view: CalendarView.month,
                      headerHeight:
                          0, // Hide Syncfusion header with broken icons
                      backgroundColor: isDark ? Colors.transparent : null,
                      cellBorderColor:
                          isDark ? _paletteWhite.withValues(alpha: 0.12) : null,
                      viewHeaderStyle: ViewHeaderStyle(
                        backgroundColor: isDark ? Colors.transparent : null,
                        dayTextStyle: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? _pureWhite : _pureBlack,
                        ),
                      ),
                      todayTextStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? _pureWhite : _palettePrimary,
                      ),
                      dataSource:
                          _DashboardCalendarDataSource(_calendarAppointments),
                      onViewChanged: (ViewChangedDetails details) {
                        final visibleDates = details.visibleDates;
                        if (visibleDates.isNotEmpty &&
                            (focusedDay.year != visibleDates.first.year ||
                                focusedDay.month != visibleDates.first.month)) {
                          final nextFocusedDay = visibleDates.first;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            setState(() {
                              focusedDay = nextFocusedDay;
                            });
                            _loadCalendarData();
                          });
                        }
                      },
                      onTap: (CalendarTapDetails details) {
                        if (details.targetElement ==
                            CalendarElement.calendarCell) {
                          _showDayEventsDialog(details.date!);
                        }
                      },
                      onLongPress: (CalendarLongPressDetails details) {
                        if (details.targetElement ==
                            CalendarElement.calendarCell) {
                          _showQuickEventCreationMenu(details.date!);
                        }
                      },
                      monthViewSettings: MonthViewSettings(
                        appointmentDisplayMode:
                            MonthAppointmentDisplayMode.appointment,
                        showAgenda: false,
                        monthCellStyle: MonthCellStyle(
                          backgroundColor: isDark ? Colors.transparent : null,
                          todayBackgroundColor: isDark
                              ? _palettePrimary.withValues(alpha: 0.22)
                              : null,
                          leadingDatesBackgroundColor:
                              isDark ? Colors.transparent : null,
                          trailingDatesBackgroundColor:
                              isDark ? Colors.transparent : null,
                          textStyle: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: isDark ? _pureWhite : _pureBlack,
                          ),
                          leadingDatesTextStyle: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: isDark
                                ? _pureWhite.withValues(alpha: 0.55)
                                : _pureBlack.withValues(alpha: 0.45),
                          ),
                          trailingDatesTextStyle: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: isDark
                                ? _pureWhite.withValues(alpha: 0.55)
                                : _pureBlack.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      todayHighlightColor: _palettePrimary,
                      selectionDecoration: BoxDecoration(
                        color: isDark
                            ? _palettePrimary.withValues(alpha: 0.28)
                            : _palettePeriwinkle.withValues(alpha: 0.25),
                        border: Border.all(color: _palettePrimary, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _refreshDashboardData() async {
    await Future.wait([
      fetchStats(),
      fetchCandidates(refresh: true),
      fetchChartData(),
      fetchPipelineActivity(),
      fetchDashboardNotifications(),
      _loadCalendarData(),
    ]);
  }

  // New method for showing day events in a dialog
  void _showDayEventsDialog(DateTime selectedDate) {
    final dayEvents = _calendarAppointments.where((appointment) {
      return appointment.startTime.year == selectedDate.year &&
          appointment.startTime.month == selectedDate.month &&
          appointment.startTime.day == selectedDate.day;
    }).toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            DateFormat('EEEE, MMMM d, y').format(selectedDate),
            style: const TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width *
                0.4, // Constrain width to 40% of screen width
            child: dayEvents.isEmpty
                ? const Text("No events scheduled for this day.",
                    style: TextStyle(fontFamily: 'Poppins'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: dayEvents.length,
                    itemBuilder: (context, index) {
                      final event = dayEvents[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Icon(
                            event.color == Colors.deepOrange
                                ? Icons.video_call
                                : Icons.event,
                            color: event.color,
                          ),
                          title: Text(event.subject,
                              style: const TextStyle(fontFamily: 'Poppins')),
                          subtitle: Text(
                            '${DateFormat.jm().format(event.startTime)} - ${DateFormat.jm().format(event.endTime)}',
                            style: const TextStyle(
                                fontFamily: 'Poppins', fontSize: 12),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'reschedule') {
                                // Implement reschedule logic
                              } else if (value == 'cancel') {
                                // Implement cancel logic
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              const PopupMenuItem<String>(
                                value: 'reschedule',
                                child: Text('Reschedule'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'cancel',
                                child: Text('Cancel'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
            ElevatedButton(
              onPressed: () => _showQuickEventCreationMenu(selectedDate),
              child: const Text("Add Event"),
            ),
          ],
        );
      },
    );
  }

  // New method for quick event creation menu
  void _showQuickEventCreationMenu(DateTime selectedDate) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Create Event on ${DateFormat('MMM d, y').format(selectedDate)}",
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _eventTypeButton("Interview", Icons.video_call,
                      Colors.deepOrange, selectedDate),
                  _eventTypeButton(
                      "Meeting", Icons.event, _paletteBlue, selectedDate),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _eventTypeButton(
      String type, IconData icon, Color color, DateTime date) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.of(context).pop();
        if (type == "Interview") {
          // Navigate to interview creation screen
          setState(() => currentScreen = "interviews");
        } else if (type == "Meeting") {
          // Navigate to meeting creation screen
          setState(() => currentScreen = "meetings");
        }
      },
      icon: Icon(icon, color: Colors.white),
      label: Text(type, style: const TextStyle(fontFamily: 'Poppins')),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // New method for calendar analytics
  void _showCalendarAnalytics() {
    // Implement analytics dialog showing metrics
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Calendar Analytics",
              style: TextStyle(fontFamily: 'Poppins')),
          content: const SizedBox(
            width: double.maxFinite,
            child: Text(
                "Analytics implementation pending - integrate with server API for metrics."),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }
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

class _LineChartPainter extends CustomPainter {
  final List<_ChartData> points;
  final int maxValue;
  final bool isDark;

  _LineChartPainter(this.points, this.maxValue, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final linePaint = Paint()
      ..color = const Color(0xFFCF2030)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()
      ..color = const Color(0xFFCF2030)
      ..style = PaintingStyle.fill;
    final gridPaint = Paint()
      ..color = (isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000))
          .withValues(alpha: 0.35)
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x =
          (points.length == 1) ? 0.0 : (i / (points.length - 1)) * size.width;
      final y =
          size.height - ((points[i].value / maxValue) * (size.height - 8));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.isDark != isDark;
  }
}

class _ChartData {
  final String label;
  final int value;
  _ChartData(this.label, this.value);
}
