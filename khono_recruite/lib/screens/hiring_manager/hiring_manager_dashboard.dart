import 'dart:async';
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
  int candidatePerPage = 20;
  List<Map<String, dynamic>> candidates = [];
  String? candidateSearchQuery;
  String? candidateStatusFilter;

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
      final data = await admin.getCandidatesWithDetails(
        page: candidatePage,
        perPage: candidatePerPage,
        search: candidateSearchQuery,
        status: candidateStatusFilter,
      );

      setState(() {
        if (refresh || candidatePage == 1) {
          candidates = List<Map<String, dynamic>>.from(data['candidates']);
        } else {
          candidates
              .addAll(List<Map<String, dynamic>>.from(data['candidates']));
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
                          ? const Color(0xFF1F2840)
                          : const Color(0xFFFFFFFF),
                      border: Border(
                        right:
                            BorderSide(color: Colors.grey.shade200, width: 1),
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
                                        ? Image.asset(
                                            'assets/images/icon.png',
                                            height: 40,
                                            fit: BoxFit.contain,
                                          )
                                        : Image.asset(
                                            'assets/images/logo2.png',
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
                                  'assets/images/Goal_Target_White_Badge_Red_Badge_White.png',
                                  'CV Reviews',
                                  'cv_reviews'),
                              _sidebarEntry('assets/icons/data-analytics.png',
                                  'Analytics', 'analytics'),
                              _sidebarEntry('assets/icons/teamC.png',
                                  'Team Collaboration', 'team_collaboration'),
                              _sidebarEntryWithBadge(
                                  'assets/images/Notification_Red_White.png',
                                  'Notifications',
                                  'notifications',
                                  badgeCount: unreadNotificationCount),
                              _sidebarEntry(
                                  'assets/images/innovation_brainstorm_red_badge_white.png',
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
                                        ? const Color(0xFF2D2D2D)
                                        : Colors.white,
                                    foregroundColor: Colors.redAccent,
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
                  : Colors.grey.shade600,
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected ? const Color(0xFFC10D00) : Colors.white,
        ),
      );
    }

    return Image.asset(
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
            : Colors.grey.shade800;

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
                        'assets/images/candidates.png',
                        selected,
                        iconColor,
                        themeProvider,
                      ),
                      const SizedBox(width: 12),
                      if (!sidebarCollapsed)
                        Expanded(
                          child: Text(
                            'Candidates',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: selected
                                  ? Colors.white
                                  : themeProvider.isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade800,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
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
            : Colors.grey.shade800;

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
                          : Colors.grey.shade800,
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
            : Colors.grey.shade800;
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
                            : Colors.grey.shade800,
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
            : Colors.grey.shade800;
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
                                : Colors.grey.shade800,
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
  Widget dashboardOverview() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (loadingStats) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.redAccent));
    }

    final stats = [
      {
        "title": "Total Jobs",
        "count": jobsCount,
        "subtitle": "$activeJobs active",
        "color": const Color.fromARGB(255, 193, 13, 0),
      },
      {
        "title": "Candidates",
        "count": candidatesCount,
        "subtitle": "${candidatesWithCV} with CV",
        "color": const Color.fromARGB(255, 193, 13, 0),
      },
      {
        "title": "Interviews",
        "count": interviewsCount,
        "subtitle": "$upcomingInterviews upcoming",
        "color": const Color.fromARGB(255, 193, 13, 0),
      },
      {
        "title": "Applications",
        "count": cvReviewsCount,
        "subtitle": "$newApplicationsWeek this week",
        "color": const Color.fromARGB(255, 193, 13, 0),
      },
      {
        "title": "Assessments",
        "count": candidatesWithAssessments,
        "subtitle": "Completed",
        "color": const Color.fromARGB(255, 193, 13, 0),
      },
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Welcome back, ${_effectiveWelcomeName(userName)}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: themeProvider.isDarkMode
                    ? Colors.white
                    : const Color(0xFF14131E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Your key metrics and calendar at a glance.",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.35,
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            _buildHmSimpleKpiStrip(stats, themeProvider),
            const SizedBox(height: 28),

            modernCalendarCard(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }


  Widget modernCalendarCard() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.all(20),
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
                  Colors.indigo.shade900.withValues(alpha: 0.2),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade50,
                  Colors.purple.shade50,
                  Colors.indigo.shade50,
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
                    "Calendar",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.1),
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
                            color: Colors.blueAccent,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.analytics_outlined,
                        color: Colors.blueAccent),
                    onPressed: () => _showCalendarAnalytics(),
                    tooltip: "View calendar analytics",
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 400,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _calendarLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SfCalendar(
                      view: CalendarView.month,
                      dataSource:
                          _DashboardCalendarDataSource(_calendarAppointments),
                      onViewChanged: (ViewChangedDetails details) {
                        final visibleDates = details.visibleDates;
                        if (visibleDates.isNotEmpty &&
                            (focusedDay.year != visibleDates.first.year ||
                                focusedDay.month != visibleDates.first.month)) {
                          setState(() {
                            focusedDay = visibleDates.first;
                          });
                          _loadCalendarData();
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
                          textStyle: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      todayHighlightColor: Colors.blueAccent,
                      selectionDecoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.2),
                        border: Border.all(color: Colors.blueAccent, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
            ),
          ),
          _buildDailyEventSummary(themeProvider),
        ],
      ),
    );
  }

  /// Minimal text-first KPI row for the HM dashboard home.
  Widget _buildHmSimpleKpiStrip(
    List<Map<String, dynamic>> stats,
    ThemeProvider themeProvider,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w >= 1100) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _simpleHmKpiTile(stats[i], themeProvider),
                ),
              ],
            ],
          );
        }
        final int cols;
        double aspect;
        if (w >= 720) {
          cols = 3;
          aspect = 1.55;
        } else if (w >= 400) {
          cols = 2;
          aspect = 1.35;
        } else {
          cols = 1;
          aspect = 2.1;
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: aspect,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) =>
              _simpleHmKpiTile(stats[index], themeProvider),
        );
      },
    );
  }

  Widget _simpleHmKpiTile(
    Map<String, dynamic> item,
    ThemeProvider themeProvider,
  ) {
    final title = item['title'] as String;
    final count = item['count'] as int;
    final subtitle = item['subtitle'] as String?;
    final color = item['color'] as Color;
    final isDark = themeProvider.isDarkMode;
    final surface = isDark ? const Color(0xFF1C1A26) : const Color(0xFFFAFAFA);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: isDark ? 0.92 : 1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.22 : 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.85,
              color: color.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            count.toString(),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              height: 1,
              color: isDark ? Colors.white : const Color(0xFF14131E),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
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
                      "Meeting", Icons.event, Colors.blue, selectedDate),
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

  // New method for daily event summary
  Widget _buildDailyEventSummary(ThemeProvider themeProvider) {
    final todayEvents = _calendarAppointments.where((appointment) {
      final now = DateTime.now();
      return appointment.startTime.year == now.year &&
          appointment.startTime.month == now.month &&
          appointment.startTime.day == now.day;
    }).toList();

    return ExpansionTile(
      title: Text(
        "Today's Events (${todayEvents.length})",
        style:
            const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
      ),
      children: todayEvents.isEmpty
          ? [
              const ListTile(
                  title: Text("No events today",
                      style: TextStyle(fontFamily: 'Poppins')))
            ]
          : todayEvents
              .map((event) => ListTile(
                    leading: Icon(
                      event.color == Colors.deepOrange
                          ? Icons.video_call
                          : Icons.event,
                      color: event.color,
                    ),
                    title: Text(event.subject,
                        style: const TextStyle(fontFamily: 'Poppins')),
                    subtitle: Text(
                      DateFormat.jm().format(event.startTime),
                      style:
                          const TextStyle(fontFamily: 'Poppins', fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showEventActions(event),
                    ),
                  ))
              .toList(),
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

  // New method for event actions
  void _showEventActions(Appointment event) {
    // Implement quick actions menu
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

class _ChartData {
  final String label;
  final int value;
  _ChartData(this.label, this.value);
}
