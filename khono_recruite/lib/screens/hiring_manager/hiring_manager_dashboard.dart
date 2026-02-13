// ignore_for_file: unused_element

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import 'candidate_management_screen.dart';
import 'cv_reviews_screen.dart';
import 'notifications_screen.dart';
import 'job_management.dart';
import 'interviews_list_screen.dart';
import 'hm_analytics_page.dart';
import 'hm_team_collaboration_page.dart';
import 'offer_list_screen.dart';
import 'pipeline_page.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../auth/login_screen.dart';

// Simple meeting data source class

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
  int offeredApplications = 0;
  int acceptedOffers = 0;
  int newApplicationsWeek = 0;
  int newInterviewsWeek = 0;

  Map<String, dynamic> applicationStatusBreakdown = {};

  int? selectedJobId;

  // Calendar state
  DateTime focusedDay = DateTime.now();
  DateTime selectedDay = DateTime.now();

  final AdminService admin = AdminService();

  List<String> recentActivities = [];

  // Display name for the logged-in user (shared with Team Collaboration semantics)
  String userName = "Hiring Manager";

  bool sidebarCollapsed = false;
  late final AnimationController _sidebarAnimController;
  late final Animation<double> _sidebarWidthAnimation;

  // --- Candidate Data ---
  List<Map<String, dynamic>> candidates = [];
  List<Map<String, dynamic>> recentCandidates = [];
  Map<String, dynamic> candidateDemographics = {};
  bool loadingCandidates = true;
  int candidatePage = 1;
  int candidatePerPage = 20;
  String? candidateSearchQuery;
  String? candidateStatusFilter;

  // --- Chart Data ---
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
  bool loadingChartData = true;

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

  // ---------- Profile image state ----------
  XFile? _profileImage;
  Uint8List? _profileImageBytes;
  String _profileImageUrl = "";
  final String apiBase = "http://127.0.0.1:5000/api/candidate";
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    fetchStats();
    fetchCandidates();
    fetchChartData();
    fetchAudits(page: 1);
    fetchProfileImage();
    _loadUserName();

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

  void _searchCandidates(String query) {
    setState(() {
      candidateSearchQuery = query.isEmpty ? null : query;
    });
    fetchCandidates(refresh: true);
  }

  void _filterCandidatesByStatus(String? status) {
    setState(() {
      candidateStatusFilter = status;
    });
    fetchCandidates(refresh: true);
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
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

  Future<void> _pickProfileImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        _profileImageBytes = await pickedFile.readAsBytes();
      }
      setState(() => _profileImage = pickedFile);
      await uploadProfileImage();
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
          Uri.parse("http://127.0.0.1:5000/api/admin/audits/recent"),
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
        offeredApplications = data['offered_applications'] ?? 0;
        acceptedOffers = data['accepted_offers'] ?? 0;
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
        Uri.parse(
            "http://127.0.0.1:5000/api/analytics/applications-per-requisition"),
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
        Uri.parse("http://127.0.0.1:5000/api/analytics/time-per-stage"),
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
          Uri.parse(
              "http://127.0.0.1:5000/api/analytics/candidate/gender-distribution"),
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
            Uri.parse(
                "http://127.0.0.1:5000/api/analytics/conversion/application-to-interview"),
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
          Uri.parse(
              "http://127.0.0.1:5000/api/analytics/conversion/application-to-interview"),
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
          Uri.parse(
              "http://127.0.0.1:5000/api/analytics/candidate/ethnicity-distribution"),
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
            Uri.parse("http://127.0.0.1:5000/api/analytics/dropoff"),
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
          Uri.parse("http://127.0.0.1:5000/api/analytics/dropoff"),
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
        Uri.parse("http://127.0.0.1:5000/api/analytics/applications/monthly"),
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
        // Skills frequency data
        final skillsRes = await http.get(
          Uri.parse(
              "http://127.0.0.1:5000/api/analytics/candidate/skills-frequency"),
          headers: headers,
        );
        if (skillsRes.statusCode == 200) {
          final data = json.decode(skillsRes.body) as List;
          skillsData = data
              .take(10)
              .map((item) => _ChartData(
                    item['skill'] ?? 'Unknown',
                    item['frequency'] ?? 0,
                  ))
              .toList();
        }
      } catch (e) {
        debugPrint("Error fetching skills data: $e");
      }

      try {
        // Experience distribution data
        final experienceRes = await http.get(
          Uri.parse(
              "http://127.0.0.1:5000/api/analytics/candidate/experience-distribution"),
          headers: headers,
        );
        if (experienceRes.statusCode == 200) {
          final data = json.decode(experienceRes.body) as List;
          experienceData = data
              .map((item) => _ChartData(
                    item['experience_level'] ?? 'Unknown',
                    item['count'] ?? 0,
                  ))
              .toList();
        }
      } catch (e) {
        debugPrint("Error fetching experience data: $e");
      }

      try {
        // CV screening drop trends
        final cvDropRes = await http.get(
          Uri.parse("http://127.0.0.1:5000/api/analytics/cv-screening-drop"),
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
          Uri.parse(
              "http://127.0.0.1:5000/api/analytics/assessments/pass-rate"),
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
      final uri = Uri.http("127.0.0.1:5000", "/api/admin/audits", queryParams);
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

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Logout", style: TextStyle(fontFamily: 'Poppins')),
          content: const Text("Are you sure you want to logout?",
              style: TextStyle(fontFamily: 'Poppins')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  const Text("Cancel", style: TextStyle(fontFamily: 'Poppins')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performLogout(context);
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
    Navigator.of(context).pop();
    await AuthService.logout();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    });
  }

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
                          ? const Color.fromARGB(171, 20, 19, 30)
                          : const Color.fromARGB(156, 255, 255, 255),
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
                        const Divider(height: 1, color: Colors.grey),
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              _sidebarEntry(
                                  Icons.home_outlined, 'Home', 'dashboard'),
                              _sidebarEntry(Icons.work_outline, 'Jobs', 'jobs'),
                              _sidebarEntry(Icons.people_alt_outlined,
                                  'Candidates', 'candidates'),
                              _sidebarEntry(
                                  Icons.event_note, 'Interviews', 'interviews'),
                              _sidebarEntry(Icons.assignment_outlined,
                                  'CV Reviews', 'cv_reviews'),
                              _sidebarEntry(Icons.analytics_outlined,
                                  'Analytics', 'analytics'),
                              _sidebarEntry(Icons.group_outlined,
                                  'Team Collaboration', 'team_collaboration'),
                              _sidebarEntry(Icons.notifications_active_outlined,
                                  'Notifications', 'notifications'),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.grey),
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
                                        context.push(
                                            '/profile?token=${widget.token}');
                                      },
                                      onLongPress: _pickProfileImage,
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
                                        userName,
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
                                      context.push(
                                          '/profile?token=${widget.token}');
                                    },
                                    onLongPress: _pickProfileImage,
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.grey.shade200,
                                      backgroundImage:
                                          _getProfileImageProvider(),
                                      child: null,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),
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
                child: Column(
                  children: [
                    Container(
                      height: 72,
                      color: themeProvider.isDarkMode
                          ? const Color(0xFF14131E).withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            // Search Bar - Replaced the welcome text
                            Expanded(
                              child: Container(
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
                                  decoration: InputDecoration(
                                    hintText: "Search across platform...",
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
                                  onSubmitted: (query) {
                                    final q = query.toLowerCase();
                                    setState(() {
                                      if (q.contains('job')) {
                                        currentScreen = "jobs";
                                      } else if (q.contains('candidate')) {
                                        currentScreen = "candidates";
                                      } else if (q.contains('interview')) {
                                        currentScreen = "interviews";
                                      } else if (q.contains('pipeline')) {
                                        // For now, treat pipeline as analytics view
                                        currentScreen = "analytics";
                                      } else if (q.contains('analytics') ||
                                          q.contains('report')) {
                                        currentScreen = "analytics";
                                      } else if (q.contains('notification')) {
                                        currentScreen = "notifications";
                                      } else if (q.contains('home') ||
                                          q.contains('dashboard')) {
                                        currentScreen = "dashboard";
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                "No results found for '$query'"),
                                          ),
                                        );
                                      }
                                    });
                                  },
                                  cursorColor: Colors.redAccent,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: themeProvider.isDarkMode
                                        ? Colors.white
                                        : Colors.black.withValues(alpha: 0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            Flexible(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ---------- Theme Toggle Switch ----------
                                    Row(
                                      children: [
                                        Icon(
                                          themeProvider.isDarkMode
                                              ? Icons.dark_mode
                                              : Icons.light_mode,
                                          color: themeProvider.isDarkMode
                                              ? Colors.amber
                                              : Colors.grey.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Switch(
                                          value: themeProvider.isDarkMode,
                                          onChanged: (value) {
                                            themeProvider.toggleTheme();
                                          },
                                          activeThumbColor: Colors.redAccent,
                                          inactiveTrackColor:
                                              Colors.grey.shade400,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),

                                    // ---------- Analytics Icon ----------
                                    IconButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  RecruitmentPipelinePage(
                                                      token: widget.token)),
                                        );
                                      },
                                      icon: Image.asset(
                                        // Changed from Icon to Image.asset
                                        'assets/icons/data-analytics.png',
                                        width: 24,
                                        height: 24,
                                        color: const Color.fromARGB(
                                            255, 193, 13, 0),
                                      ),
                                      tooltip: "Analytics Dashboard",
                                    ),
                                    const SizedBox(width: 8),

                                    // ---------- Team Collaboration Icon ----------
                                    IconButton(
                                      onPressed: () => setState(() =>
                                          currentScreen = "team_collaboration"),
                                      icon: Image.asset(
                                        // Changed from Icon to Image.asset
                                        'assets/icons/teamC.png',
                                        width: 34,
                                        height: 34,
                                        color: const Color.fromARGB(
                                            255, 193, 13, 0),
                                      ),
                                      tooltip: "Team Collaboration",
                                    ),
                                    const SizedBox(width: 8),

                                    TextButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  AdminOfferListScreen()),
                                        );
                                      },
                                      icon: Image.asset(
                                        'assets/icons/add.png',
                                        width: 30,
                                        height: 30,
                                        color: const Color.fromARGB(
                                            255, 193, 13, 0),
                                      ),
                                      label: Text(
                                        "Create",
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: themeProvider.isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      onPressed: () => setState(() =>
                                          currentScreen = "notifications"),
                                      icon: Image.asset(
                                        // Changed from Icon to Image.asset
                                        'assets/icons/notification.png',
                                        width: 45,
                                        height: 45,
                                        color: const Color.fromARGB(
                                            255, 193, 13, 0),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () {
                                        context.push(
                                            '/profile?token=${widget.token}');
                                      },
                                      onLongPress: _pickProfileImage,
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.grey.shade200,
                                        backgroundImage:
                                            _getProfileImageProvider(),
                                        child: null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
        child: const Icon(Icons.refresh),
        onPressed: fetchStats,
        tooltip: "Refresh stats",
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

  Widget _sidebarEntry(IconData icon, String label, String screenKey) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final selected = currentScreen == screenKey;
    return InkWell(
      onTap: () => setState(() => currentScreen = screenKey),
      child: Container(
        color: selected
            ? const Color.fromRGBO(151, 18, 8, 1).withValues(alpha: 0.06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon,
                color: selected
                    ? const Color.fromRGBO(151, 18, 8, 1)
                    : themeProvider.isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade800),
            const SizedBox(width: 12),
            if (!sidebarCollapsed)
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: selected
                        ? Colors.redAccent
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
      case "analytics":
        return HMAnalyticsPage();
      case "team_collaboration":
        return HMTeamCollaborationPage();
      case "notifications":
        return NotificationsScreen();
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
        "icon": "assets/icons/jobs.png"
      },
      {
        "title": "Candidates",
        "count": candidatesCount,
        "subtitle": "${candidatesWithCV} with CV",
        "color": const Color.fromARGB(255, 193, 13, 0),
        "icon": "assets/icons/candidates.png"
      },
      {
        "title": "Interviews",
        "count": interviewsCount,
        "subtitle": "$upcomingInterviews upcoming",
        "color": const Color.fromARGB(255, 193, 13, 0),
        "icon": "assets/icons/interview.png"
      },
      {
        "title": "Applications",
        "count": cvReviewsCount,
        "subtitle": "$newApplicationsWeek this week",
        "color": const Color.fromARGB(255, 193, 13, 0),
        "icon": "assets/icons/review.png"
      },
      {
        "title": "Offers",
        "count": offeredApplications,
        "subtitle": "$acceptedOffers accepted",
        "color": const Color.fromARGB(255, 193, 13, 0),
        "icon":
            "assets/icons/add.png" // Using existing icon instead of missing offer.png
      },
      {
        "title": "Assessments",
        "count": candidatesWithAssessments,
        "subtitle": "Completed",
        "color": const Color.fromARGB(255, 193, 13, 0),
        "icon":
            "assets/icons/audit.png" // Using existing icon instead of missing assessment.png
      },
    ];

    // Data will be fetched from API
    final List<_ChartData> candidatePipeline = candidatePipelineData;

    // Data will be fetched from API
    final List<_ChartData> timeToFill = timeToFillData;

    // Data will be fetched from API
    final List<_ChartData> genderMetrics = genderData;
    final List<_ChartData> ethnicityMetrics = ethnicityData;

    // Data will be fetched from API
    final List<_ChartData> sourceMetrics = sourcePerformanceData;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text("Welcome Back, $userName",
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : const Color.fromARGB(225, 20, 19, 30))),
            const SizedBox(height: 6),

            // KPI Cards
            // Instead of SizedBox with fixed height, use:
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 160,
                maxHeight: 180,
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (_, index) {
                  final item = stats[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: (themeProvider.isDarkMode
                              ? const Color(0xFF14131E)
                              : Colors.white)
                          .withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (item["color"] as Color).withValues(alpha: 0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: kpiCard(
                      item["title"].toString(),
                      item["count"] as int,
                      item["color"] as Color,
                      item["icon"] as String,
                      item["subtitle"] as String?,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Enhanced Candidates Section
            _buildCandidatesSection(themeProvider),
            const SizedBox(height: 24),

            // Candidate Demographics Section
            _buildCandidateDemographicsSection(themeProvider),
            const SizedBox(height: 24),

            LayoutBuilder(builder: (context, constraints) {
              int crossAxisCount = constraints.maxWidth > 900 ? 2 : 1;
              return Column(
                children: [
                  // Row 1
                  if (crossAxisCount == 2)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: stylishBarChartCard(
                                "Candidate Pipeline",
                                candidatePipeline,
                                const Color.fromARGB(255, 193, 13, 0))),
                        const SizedBox(width: 16),
                        Expanded(
                            child: stylishLineChartCard(
                                "Time to Fill Trend",
                                timeToFill,
                                const Color.fromARGB(255, 193, 13, 0))),
                      ],
                    )
                  else
                    Column(
                      children: [
                        stylishBarChartCard(
                            "Candidate Pipeline",
                            candidatePipeline,
                            const Color.fromARGB(255, 193, 13, 0)),
                        const SizedBox(height: 16),
                        stylishLineChartCard("Time to Fill Trend", timeToFill,
                            const Color.fromARGB(255, 193, 13, 0)),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Row 2
                  if (crossAxisCount == 2)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: stylishDualDonutCard("Diversity Metrics",
                                genderMetrics, ethnicityMetrics)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: stylishBarChartCard(
                                "Source Performance",
                                sourceMetrics,
                                const Color.fromARGB(255, 193, 13, 0))),
                      ],
                    )
                  else
                    Column(
                      children: [
                        stylishDualDonutCard("Diversity Metrics", genderMetrics,
                            ethnicityMetrics),
                        const SizedBox(height: 16),
                        stylishBarChartCard("Source Performance", sourceMetrics,
                            const Color.fromARGB(255, 193, 13, 0)),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Row 3 - Additional Analytics
                  if (crossAxisCount == 2)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: skillsData.isNotEmpty
                                ? stylishBarChartCard("Top Skills", skillsData,
                                    const Color.fromARGB(255, 193, 13, 0))
                                : stylishBarChartCard("Top Skills", [],
                                    const Color.fromARGB(255, 193, 13, 0))),
                        const SizedBox(width: 16),
                        Expanded(
                            child: experienceData.isNotEmpty
                                ? stylishBarChartCard(
                                    "Experience Distribution",
                                    experienceData,
                                    const Color.fromARGB(255, 193, 13, 0))
                                : stylishBarChartCard("Experience Distribution",
                                    [], const Color.fromARGB(255, 193, 13, 0))),
                      ],
                    )
                  else
                    Column(
                      children: [
                        skillsData.isNotEmpty
                            ? stylishBarChartCard("Top Skills", skillsData,
                                const Color.fromARGB(255, 193, 13, 0))
                            : stylishBarChartCard("Top Skills", [],
                                const Color.fromARGB(255, 193, 13, 0)),
                        const SizedBox(height: 16),
                        experienceData.isNotEmpty
                            ? stylishBarChartCard(
                                "Experience Distribution",
                                experienceData,
                                const Color.fromARGB(255, 193, 13, 0))
                            : stylishBarChartCard("Experience Distribution", [],
                                const Color.fromARGB(255, 193, 13, 0)),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Row 4
                  if (crossAxisCount == 2)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: cvScreeningData.isNotEmpty
                                ? stylishLineChartCard(
                                    "CV Screening Trends",
                                    cvScreeningData,
                                    const Color.fromARGB(255, 193, 13, 0))
                                : stylishLineChartCard("CV Screening Trends",
                                    [], const Color.fromARGB(255, 193, 13, 0))),
                        const SizedBox(width: 16),
                        Expanded(
                            child: assessmentData.isNotEmpty
                                ? stylishLineChartCard(
                                    "Assessment Pass Rates",
                                    assessmentData,
                                    const Color.fromARGB(255, 193, 13, 0))
                                : stylishLineChartCard("Assessment Pass Rates",
                                    [], const Color.fromARGB(255, 193, 13, 0))),
                      ],
                    )
                  else
                    Column(
                      children: [
                        cvScreeningData.isNotEmpty
                            ? stylishLineChartCard(
                                "CV Screening Trends",
                                cvScreeningData,
                                const Color.fromARGB(255, 193, 13, 0))
                            : stylishLineChartCard("CV Screening Trends", [],
                                const Color.fromARGB(255, 193, 13, 0)),
                        const SizedBox(height: 16),
                        assessmentData.isNotEmpty
                            ? stylishLineChartCard(
                                "Assessment Pass Rates",
                                assessmentData,
                                const Color.fromARGB(255, 193, 13, 0))
                            : stylishLineChartCard("Assessment Pass Rates", [],
                                const Color.fromARGB(255, 193, 13, 0)),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Row 5 - Original Row 3
                  if (crossAxisCount == 2)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: stylishTeamCollaborationCard(
                                "Team Collaboration", [])),
                        const SizedBox(width: 16),
                        Expanded(child: modernCalendarCard()),
                      ],
                    )
                  else
                    Column(
                      children: [
                        stylishTeamCollaborationCard("Team Collaboration", []),
                        const SizedBox(height: 16),
                        modernCalendarCard(),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Activities card (always full width)
                  stylishActivitiesCard(recentActivities),
                ],
              );
            }),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget teamCollaborationWidget() {
    return stylishTeamCollaborationCard("Team Collaboration", []);
  }

  // ---------------- Stylish Chart Cards ----------------
  Widget stylishBarChartCard(String title, List<_ChartData> data, Color color) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white)
                .withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: themeProvider.isDarkMode
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.red.shade900.withValues(alpha: 0.2),
                  Colors.red.shade800.withValues(alpha: 0.1),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.red.shade50,
                  Colors.red.shade100.withValues(alpha: 0.3),
                ],
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black87)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text("${data.length} stages",
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Flexible(
            child: loadingChartData
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading data...',
                          style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.white70
                                : Colors.grey.shade600,
                            fontFamily: 'Poppins',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : data.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bar_chart_outlined,
                              size: 48,
                              color: themeProvider.isDarkMode
                                  ? Colors.white24
                                  : Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No data available',
                              style: TextStyle(
                                color: themeProvider.isDarkMode
                                    ? Colors.white54
                                    : Colors.grey.shade500,
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Data will appear here once available',
                              style: TextStyle(
                                color: themeProvider.isDarkMode
                                    ? Colors.white38
                                    : Colors.grey.shade400,
                                fontFamily: 'Poppins',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SfCartesianChart(
                        margin: EdgeInsets.zero,
                        plotAreaBorderWidth: 0,
                        primaryXAxis: CategoryAxis(
                          majorGridLines: const MajorGridLines(width: 0),
                          axisLine: const AxisLine(width: 0),
                          labelStyle: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        primaryYAxis: NumericAxis(
                          majorGridLines: const MajorGridLines(width: 0),
                          axisLine: const AxisLine(width: 0),
                          labelStyle: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        series: <ColumnSeries<_ChartData, String>>[
                          ColumnSeries<_ChartData, String>(
                            dataSource: data,
                            xValueMapper: (d, _) => d.label,
                            yValueMapper: (d, _) => d.value,
                            color: color,
                            width: 0.6,
                            borderRadius: BorderRadius.circular(4),
                            dataLabelSettings: DataLabelSettings(
                              isVisible: true,
                              textStyle: TextStyle(
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                                fontFamily: 'Poppins',
                                fontSize: 10,
                              ),
                            ),
                          )
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget stylishLineChartCard(
      String title, List<_ChartData> data, Color color) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white)
                .withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: themeProvider.isDarkMode
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade900.withValues(alpha: 0.2),
                  Colors.purple.shade800.withValues(alpha: 0.1),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black87)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_down, color: color, size: 12),
                    const SizedBox(width: 4),
                    Text("Improving",
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Flexible(
            child: loadingChartData
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading data...',
                          style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.white70
                                : Colors.grey.shade600,
                            fontFamily: 'Poppins',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : data.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.show_chart,
                              size: 48,
                              color: themeProvider.isDarkMode
                                  ? Colors.white24
                                  : Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No data available',
                              style: TextStyle(
                                color: themeProvider.isDarkMode
                                    ? Colors.white54
                                    : Colors.grey.shade500,
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Trend data will appear here once available',
                              style: TextStyle(
                                color: themeProvider.isDarkMode
                                    ? Colors.white38
                                    : Colors.grey.shade400,
                                fontFamily: 'Poppins',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SfCartesianChart(
                        margin: EdgeInsets.zero,
                        plotAreaBorderWidth: 0,
                        primaryXAxis: CategoryAxis(
                          majorGridLines: const MajorGridLines(width: 0),
                          axisLine: const AxisLine(width: 0),
                          labelStyle: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        primaryYAxis: NumericAxis(
                          majorGridLines: const MajorGridLines(width: 0),
                          axisLine: const AxisLine(width: 0),
                          labelStyle: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        series: <SplineSeries<_ChartData, String>>[
                          SplineSeries<_ChartData, String>(
                            dataSource: data,
                            xValueMapper: (d, _) => d.label,
                            yValueMapper: (d, _) => d.value,
                            color: color,
                            width: 3,
                            markerSettings:
                                const MarkerSettings(isVisible: true),
                            dataLabelSettings: DataLabelSettings(
                              isVisible: true,
                              textStyle: TextStyle(
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                                fontFamily: 'Poppins',
                                fontSize: 10,
                              ),
                            ),
                          )
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget stylishDualDonutCard(
      String title, List<_ChartData> data1, List<_ChartData> data2) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white)
                .withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: themeProvider.isDarkMode
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.purple.shade900.withValues(alpha: 0.2),
                  Colors.indigo.shade800.withValues(alpha: 0.1),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.purple.shade50,
                  Colors.indigo.shade50,
                ],
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: themeProvider.isDarkMode
                      ? Colors.white
                      : Colors.black87)),
          const SizedBox(height: 6),
          Flexible(
            child: loadingChartData
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.purple),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading diversity data...',
                          style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.white70
                                : Colors.grey.shade600,
                            fontFamily: 'Poppins',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : data1.isEmpty && data2.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.donut_large_outlined,
                              size: 48,
                              color: themeProvider.isDarkMode
                                  ? Colors.white24
                                  : Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No diversity data available',
                              style: TextStyle(
                                color: themeProvider.isDarkMode
                                    ? Colors.white54
                                    : Colors.grey.shade500,
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Diversity metrics will appear here once available',
                              style: TextStyle(
                                color: themeProvider.isDarkMode
                                    ? Colors.white38
                                    : Colors.grey.shade400,
                                fontFamily: 'Poppins',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: SfCircularChart(
                              margin: EdgeInsets.zero,
                              title: ChartTitle(
                                  text: "Gender",
                                  textStyle: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 12)),
                              legend: Legend(
                                  isVisible: true,
                                  textStyle: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 10)),
                              series: <DoughnutSeries<_ChartData, String>>[
                                DoughnutSeries<_ChartData, String>(
                                  dataSource: data1.isEmpty
                                      ? [_ChartData("No Data", 1)]
                                      : data1,
                                  xValueMapper: (d, _) => d.label,
                                  yValueMapper: (d, _) => d.value,
                                  innerRadius: '70%',
                                  dataLabelSettings: DataLabelSettings(
                                    isVisible: true,
                                    textStyle: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10,
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                          Expanded(
                            child: SfCircularChart(
                              margin: EdgeInsets.zero,
                              title: ChartTitle(
                                  text: "Ethnicity",
                                  textStyle: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 12)),
                              legend: Legend(
                                  isVisible: true,
                                  textStyle: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 10)),
                              series: <DoughnutSeries<_ChartData, String>>[
                                DoughnutSeries<_ChartData, String>(
                                  dataSource: data2.isEmpty
                                      ? [_ChartData("No Data", 1)]
                                      : data2,
                                  xValueMapper: (d, _) => d.label,
                                  yValueMapper: (d, _) => d.value,
                                  innerRadius: '70%',
                                  dataLabelSettings: DataLabelSettings(
                                    isVisible: true,
                                    textStyle: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10,
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget stylishTeamCollaborationCard(String title, List<String> messages) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white)
                .withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: themeProvider.isDarkMode
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade900.withValues(alpha: 0.2),
                  Colors.teal.shade800.withValues(alpha: 0.1),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade50,
                  Colors.teal.shade50,
                ],
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black87)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text("${messages.length} updates",
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          messages[index],
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade300
                                : Colors.grey.shade800,
                            fontSize: 12,
                          ),
                        ),
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

  Widget stylishActivitiesCard(List<String> activities) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white)
                .withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: themeProvider.isDarkMode
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.orange.shade900.withValues(alpha: 0.2),
                  Colors.amber.shade800.withValues(alpha: 0.1),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.orange.shade50,
                  Colors.amber.shade50,
                ],
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Recent Activities",
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text("${activities.length} items",
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: activities.isEmpty
                ? Center(
                    child: Text("No recent activities",
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600)),
                  )
                : ListView.builder(
                    itemCount: activities.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: themeProvider.isDarkMode
                              ? Colors.black.withValues(alpha: 0.3)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                activities[index],
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: themeProvider.isDarkMode
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade800,
                                  fontSize: 12,
                                ),
                              ),
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

  Widget modernCalendarCard() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      height: 220,
      padding: const EdgeInsets.all(12),
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
                    "Calendar",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
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
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              height: 400,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Interview Calendar",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('Calendar functionality coming soon'),
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

  Widget kpiCard(String title, int count, Color color, String iconPath,
      [String? subtitle]) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
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
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
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
          const SizedBox(height: 6),
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

  // ---------------- Enhanced Candidates Section ----------------
  Widget _buildCandidatesSection(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with Search and Filter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Candidates Overview",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: themeProvider.isDarkMode
                    ? Colors.white
                    : const Color.fromARGB(225, 20, 19, 30),
              ),
            ),
            Row(
              children: [
                // Status Filter Dropdown
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (themeProvider.isDarkMode
                            ? const Color(0xFF14131E)
                            : Colors.white)
                        .withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: candidateStatusFilter,
                      hint: const Text("All Status",
                          style: TextStyle(fontSize: 12)),
                      items: [
                        'all',
                        'applied',
                        'reviewed',
                        'interviewed',
                        'offered',
                        'rejected'
                      ]
                          .map((status) => DropdownMenuItem(
                                value: status == 'all' ? null : status,
                                child: Text(
                                    status[0].toUpperCase() +
                                        status.substring(1),
                                    style: const TextStyle(fontSize: 12)),
                              ))
                          .toList(),
                      onChanged: (value) => _filterCandidatesByStatus(value),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Search Bar
                Container(
                  width: 200,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (themeProvider.isDarkMode
                            ? const Color(0xFF14131E)
                            : Colors.white)
                        .withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: "Search candidates...",
                      hintStyle: TextStyle(fontSize: 12),
                      prefixIcon: Icon(Icons.search, size: 16),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 12),
                    onChanged: _searchCandidates,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Candidates Grid
        if (loadingCandidates)
          Container(
            height: 300,
            child: const Center(
                child: CircularProgressIndicator(color: Colors.redAccent)),
          )
        else if (candidates.isEmpty)
          Container(
            height: 200,
            child: Center(
              child: Text(
                "No candidates found",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 3.0, // Increased from 2.8 to give more height
            ),
            itemCount: candidates.take(8).length, // Show first 8 candidates
            itemBuilder: (context, index) {
              final candidate = candidates[index];
              return _buildCandidateCard(candidate, themeProvider);
            },
          ),

        const SizedBox(height: 16),

        // View All Candidates Button
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => currentScreen = "candidates"),
            icon: const Icon(Icons.people_outline, size: 16),
            label: const Text("View All Candidates",
                style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: const Color.fromARGB(255, 193, 13, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCandidateCard(
      Map<String, dynamic> candidate, ThemeProvider themeProvider) {
    final stats = candidate['statistics'] as Map<String, dynamic>? ?? {};
    final fullName = candidate['full_name']?.toString() ?? 'Unknown';
    final location = candidate['location']?.toString() ?? '';
    final title = candidate['title']?.toString() ?? '';
    final profilePicture = candidate['profile_picture']?.toString();
    final latestStatus = stats['latest_application_status']?.toString();
    final totalApplications = stats['total_applications'] ?? 0;
    final avgScore = (stats['average_cv_score'] ?? 0.0).toDouble();

    Color statusColor = Colors.grey;
    switch (latestStatus) {
      case 'applied':
        statusColor = Colors.blue;
        break;
      case 'reviewed':
        statusColor = Colors.orange;
        break;
      case 'interviewed':
        statusColor = Colors.purple;
        break;
      case 'offered':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color:
            (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white)
                .withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8), // Reduced from 12
        child: Row(
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 16, // Reduced from 20
              backgroundColor: Colors.grey.shade200,
              backgroundImage: profilePicture?.isNotEmpty == true
                  ? NetworkImage(profilePicture!)
                  : null,
              child: profilePicture?.isEmpty != false
                  ? Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 12, // Reduced from 14
                        fontWeight: FontWeight.bold,
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.grey.shade700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8), // Reduced from 12

            // Candidate Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, // Added to prevent overflow
                children: [
                  Text(
                    fullName,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11, // Reduced from 12
                      fontWeight: FontWeight.bold,
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1, // Added to prevent overflow
                  ),
                  if (title.isNotEmpty) ...[
                    const SizedBox(height: 1), // Reduced from 2
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9, // Reduced from 10
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1, // Added to prevent overflow
                    ),
                  ],
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 1), // Reduced from 2
                    Text(
                      location,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9, // Reduced from 10
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1, // Added to prevent overflow
                    ),
                  ],
                ],
              ),
            ),

            // Status and Score
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Added to prevent overflow
              children: [
                if (latestStatus != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1), // Reduced padding
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8), // Reduced from 10
                    ),
                    child: Text(
                      latestStatus.length > 8
                          ? '${latestStatus.substring(0, 8)}.'
                          : latestStatus[0].toUpperCase() +
                              latestStatus.substring(1),
                      style: TextStyle(
                        fontSize: 8, // Reduced from 9
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                if (avgScore > 0) ...[
                  const SizedBox(height: 2), // Reduced from 4
                  Text(
                    "${avgScore.toStringAsFixed(0)}", // Removed decimal for space
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9, // Reduced from 10
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
                if (totalApplications > 0)
                  Text(
                    "$totalApplications", // Shortened text
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 8, // Reduced from 9
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade500
                          : Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Candidate Demographics Section ----------------
  Widget _buildCandidateDemographicsSection(ThemeProvider themeProvider) {
    if (candidateDemographics.isEmpty) {
      return const SizedBox.shrink();
    }

    final genderDistribution =
        candidateDemographics['gender_distribution'] as Map<String, dynamic>? ??
            {};
    final locationDistribution = candidateDemographics['location_distribution']
            as Map<String, dynamic>? ??
        {};
    final topSkills =
        candidateDemographics['top_skills'] as Map<String, dynamic>? ?? {};
    final educationDistribution =
        candidateDemographics['education_distribution']
                as Map<String, dynamic>? ??
            {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Candidate Demographics & Insights",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: themeProvider.isDarkMode
                ? Colors.white
                : const Color.fromARGB(225, 20, 19, 30),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = constraints.maxWidth > 1200
                ? 4
                : constraints.maxWidth > 800
                    ? 2
                    : 1;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12, // Reduced from 16
              mainAxisSpacing: 12, // Reduced from 16
              childAspectRatio: crossAxisCount == 4
                  ? 1.4
                  : 1.2, // Adjust aspect ratio based on column count
              children: [
                // Gender Distribution
                _buildDemographicCard(
                  "Gender Distribution",
                  genderDistribution,
                  Icons.pie_chart,
                  themeProvider,
                ),

                // Top Locations
                _buildDemographicCard(
                  "Top Locations",
                  Map<String, dynamic>.fromEntries(
                      locationDistribution.entries.take(5)),
                  Icons.location_on,
                  themeProvider,
                ),

                // Top Skills
                _buildDemographicCard(
                  "Top Skills",
                  Map<String, dynamic>.fromEntries(topSkills.entries.take(5)),
                  Icons.psychology,
                  themeProvider,
                ),

                // Education Levels
                _buildDemographicCard(
                  "Education Levels",
                  educationDistribution,
                  Icons.school,
                  themeProvider,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDemographicCard(
    String title,
    Map<String, dynamic> data,
    IconData icon,
    ThemeProvider themeProvider,
  ) {
    if (data.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: (themeProvider.isDarkMode
                  ? const Color(0xFF14131E)
                  : Colors.white)
              .withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade300
                      : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "No data available",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade500
                      : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort data by value (descending)
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    final total =
        sortedEntries.fold<int>(0, (sum, entry) => sum + (entry.value as int));

    return Container(
      decoration: BoxDecoration(
        color:
            (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white)
                .withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12), // Reduced from 16
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 16,
                    color: const Color.fromARGB(
                        255, 193, 13, 0)), // Reduced from 18
                const SizedBox(width: 6), // Reduced from 8
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12, // Reduced from 14
                      fontWeight: FontWeight.bold,
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8), // Reduced from 12

            // Display top items
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Added to prevent overflow
                children:
                    sortedEntries.take(4).toList().asMap().entries.map((entry) {
                  // Reduced from 5 to 4 items
                  final index = entry.key;
                  final item = entry.value;
                  final label = item.key.toString();
                  final value = item.value as int;
                  final percentage = total > 0 ? (value / total * 100) : 0.0;

                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: index < 3 ? 6 : 0), // Reduced spacing
                    child: Row(
                      children: [
                        // Colored indicator
                        Container(
                          width: 6, // Reduced from 8
                          height: 6, // Reduced from 8
                          decoration: BoxDecoration(
                            color: _getChartColor(index),
                            borderRadius:
                                BorderRadius.circular(3), // Reduced from 4
                          ),
                        ),
                        const SizedBox(width: 6), // Reduced from 8

                        // Label
                        Expanded(
                          child: Text(
                            label.length > 12 // Reduced from 15
                                ? '${label.substring(0, 12)}...'
                                : label,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10, // Reduced from 11
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Value and percentage
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize:
                              MainAxisSize.min, // Added to prevent overflow
                          children: [
                            Text(
                              value.toString(),
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10, // Reduced from 11
                                fontWeight: FontWeight.w600,
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            Text(
                              "${percentage.toStringAsFixed(0)}%", // Removed decimal
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 8, // Reduced from 9
                                color: themeProvider.isDarkMode
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getChartColor(int index) {
    final colors = [
      const Color.fromARGB(255, 193, 13, 0), // Red/Accent
      const Color(0xFF4CAF50), // Green
      const Color(0xFF2196F3), // Blue
      const Color(0xFFFF9800), // Orange
      const Color(0xFF9C27B0), // Purple
    ];
    return colors[index % colors.length];
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
