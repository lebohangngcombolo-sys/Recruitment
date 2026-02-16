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

  // --- Chart Data ---
  List<_ChartData> candidatePipelineData = [];
  List<_ChartData> timeToFillData = [];
  List<_ChartData> genderData = [];
  List<_ChartData> ethnicityData = [];
  List<_ChartData> sourcePerformanceData = [];
  bool loadingChartData = true;

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

  @override
  void initState() {
    super.initState();
    fetchStats();
    fetchAudits(page: 1);
    fetchProfileImage();
    fetchChartData();

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
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _sidebarAnimController.dispose();
    auditSearchController.dispose();
    super.dispose();
  }

  // ---------- Chart Data Methods ----------
  Future<void> fetchChartData() async {
    setState(() => loadingChartData = true);
    try {
      // TODO: Implement actual API calls for chart data
      // For now, keeping empty to remove mock data

      setState(() {
        loadingChartData = false;
      });
    } catch (e) {
      setState(() => loadingChartData = false);
      debugPrint("Error fetching chart data: $e");
    }
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

  // ---------- Dashboard Stats ----------
  Future<void> fetchStats() async {
    setState(() => loadingStats = true);
    try {
      final counts = await admin.getDashboardCounts();
      final role = await AuthService.getRole();

      List<String> activities = [];
      if (role == "admin") {
        final token = await AuthService.getAccessToken();
        final res = await http.get(
          Uri.parse("http://127.0.0.1:5000/api/admin/recent-activities"),
          headers: {"Authorization": "Bearer $token"},
        );
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          activities = List<String>.from(data["recent_activities"] ?? []);
        }
      }

      setState(() {
        jobsCount = counts["jobs"] ?? 0;
        candidatesCount = counts["candidates"] ?? 0;
        interviewsCount = counts["interviews"] ?? 0;
        cvReviewsCount = counts["cv_reviews"] ?? 0;
        auditsCount = counts["audits"] ?? 0;
        recentActivities = activities;
        loadingStats = false;
      });
    } catch (e) {
      setState(() => loadingStats = false);
      debugPrint("Error fetching dashboard stats: $e");
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
                                    context.push(
                                      '/hiring-manager-pipeline?token=${Uri.encodeComponent(widget.token)}',
                                    );
                                  },
                                  icon: Image.asset(
                                    'assets/icons/data-analytics.png',
                                    width: 24,
                                    height: 24,
                                  ),
                                  tooltip: "Analytics Dashboard",
                                ),
                                const SizedBox(width: 8),

                                // ---------- Power BI Status Icon ----------
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: powerBIConnected
                                        ? Colors.green
                                        : Colors.red,
                                    boxShadow: [
                                      BoxShadow(
                                        color: powerBIConnected
                                            ? Colors.green
                                                .withValues(alpha: 0.6)
                                            : Colors.red.withValues(alpha: 0.6),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: checkingPowerBI
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.bar_chart,
                                            color: Colors.white, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                    // ---------- Team Collaboration Icon ----------
                                    IconButton(
                                      onPressed: () => setState(() =>
                                          currentScreen = "team_collaboration"),
                                      icon: Image.asset(
                                        'assets/icons/teamC.png',
                                        width: 34,
                                        height: 34,
                                      ),
                                      tooltip: "Team Collaboration",
                                    ),
                                    const SizedBox(width: 8),

                                TextButton.icon(
                                  onPressed: () {
                                    context.push('/hiring-manager-offers');
                                  },
                                  icon: Image.asset(
                                    'assets/icons/add.png',
                                    width: 30,
                                    height: 30,
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
                                  onPressed: () => setState(
                                      () => currentScreen = "notifications"),
                                  icon: Image.asset(
                                    'assets/icons/notification.png',
                                    width: 45,
                                    height: 45,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () {
                                    context
                                        .push('/profile?token=${widget.token}');
                                  },
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage: _getProfileImageProvider(),
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
        "title": "Jobs",
        "count": jobsCount,
        "color": const Color.fromARGB(255, 193, 13, 0),
        "icon": "assets/icons/jobs.png" // or .svg if using SVG
      },
      {
        "title": "Candidates",
        "count": candidatesCount,
        "color": const Color.fromARGB(255, 193, 13, 0),
        "icon": "assets/icons/candidates.png"
      },
      {
        "title": "Interviews",
        "count": interviewsCount,
        "color": const Color.fromARGB(255, 193, 13, 0),
        "icon": "assets/icons/interview.png"
      },
      {
        "title": "CV Reviews",
        "count": cvReviewsCount,
        "color": const Color.fromARGB(255, 193, 13, 0),
        "icon": "assets/icons/review.png"
      },
      {
        "title": "Audits",
        "count": auditsCount,
        "color": const Color.fromARGB(255, 193, 13, 0),
        "icon": "assets/icons/audit.png"
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
            const SizedBox(height: 6),
            Text("Welcome Back, Admin",
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
                        item["icon"] as String),
                  );
                },
              ),
            ),
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

                  // Row 3
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
          const SizedBox(height: 12),
          Container(
            height: 110,
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
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.blueAccent,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('MMMM yyyy').format(DateTime.now()),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
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

  Widget kpiCard(String title, int count, Color color, String iconPath) {
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
        ],
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    final ImagePicker picker = ImagePicker();
    await picker.pickImage(source: ImageSource.gallery);
    // TODO: Handle the selected image
  }

  Future<void> fetchPowerBIStatus() async {
    // TODO: Implement PowerBI status fetching
  }
}

class _ChartData {
  final String label;
  final int value;
  _ChartData(this.label, this.value);
}
