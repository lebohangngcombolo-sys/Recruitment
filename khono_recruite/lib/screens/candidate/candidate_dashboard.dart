import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';

// Import your existing services
import 'job_details_page.dart';
import 'assessments_results_screen.dart';
import '../../screens/candidate/user_profile_page.dart';
import 'jobs_applied_page.dart';
import 'saved_application_screen.dart';
import '../../services/auth_service.dart';
import 'offers_screen.dart';

class CandidateDashboard extends StatefulWidget {
  final String token;
  const CandidateDashboard({super.key, required this.token});

  @override
  _CandidateDashboardState createState() => _CandidateDashboardState();
}

class _CandidateDashboardState extends State<CandidateDashboard>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  int _currentTab = 0;
  final List<String> _jobTypes = ['Featured', 'Full Time', 'Part Time'];
  final Color primaryColor = Color(0xFF991A1A);
  final Color strokeColor = Color(0xFFC10D00);
  final Color fillColor = Color(0xFFf2f2f2).withValues(alpha: 0.2);
  final String apiBase = "http://127.0.0.1:5000/api/candidate";

  List<Map<String, dynamic>> notifications = [];
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchNotifications();
    _startNotificationTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchNotifications();
    }
  }

  void _startNotificationTimer() {
    _notificationTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _fetchNotifications();
    });
  }

  Future<void> _fetchNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBase/notifications'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == 'true' && data['notifications'] != null) {
          _safeSetState(() {
            notifications =
                List<Map<String, dynamic>>.from(data['notifications']);
          });
        }
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return ListTile(
                        leading: Icon(
                          Icons.notifications,
                          color: primaryColor,
                        ),
                        title: Text(
                          notification['message'] ?? 'New notification',
                          style: GoogleFonts.poppins(),
                        ),
                        subtitle: Text(
                          _formatDate(notification['created_at']),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateString;
    }
  }

  void _safeSetState(VoidCallback callback) {
    if (mounted) {
      setState(callback);
    }
  }

  ImageProvider _getProfileImageProvider() {
    if (kIsWeb) {
      return const AssetImage('assets/images/default_profile.png');
    } else {
      try {
        final file = File('assets/images/profile.png');
        if (file.existsSync()) {
          return FileImage(file);
        }
      } catch (e) {
        print('Error loading profile image: $e');
      }
      return const AssetImage('assets/images/default_profile.png');
    }
  }

  Future<void> analyzeCV() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);

        final response = await http.post(
          Uri.parse('$apiBase/analyze-cv'),
          headers: {
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'image': base64Image}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _showAnalysisResult(data['analysis']);
        }
      }
    } catch (e) {
      _showErrorDialog('Error analyzing CV: $e');
    }
  }

  void _showAnalysisResult(String analysis) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CV Analysis Results',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      analysis,
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Error',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  message,
                  style: GoogleFonts.poppins(),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Logout',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Are you sure you want to logout?',
                  style: GoogleFonts.poppins(),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(color: Colors.black),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await AuthService.logout();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => LoginScreen()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Logout',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(String text, {bool isActive = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: color ?? (isActive ? Colors.white : Colors.white70),
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: strokeColor, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    job['title'] ?? 'Job Title',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: strokeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    job['type'] ?? 'Full Time',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              job['company'] ?? 'Company Name',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 8),
            Text(
              job['location'] ?? 'Location',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JobDetailsPage(
                            job: job,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'View Details',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Apply for job logic here
                      _showApplySuccess();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: strokeColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Apply Now',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobList() {
    final jobs = [
      {
        'id': '1',
        'title': 'Senior Flutter Developer',
        'company': 'Tech Company',
        'location': 'Johannesburg, South Africa',
        'type': 'Full Time',
        'description': 'Looking for experienced Flutter developer...'
      },
      {
        'id': '2',
        'title': 'UI/UX Designer',
        'company': 'Design Agency',
        'location': 'Cape Town, South Africa',
        'type': 'Full Time',
        'description': 'Creative designer needed for mobile apps...'
      },
      {
        'id': '3',
        'title': 'Backend Developer',
        'company': 'Startup',
        'location': 'Remote',
        'type': 'Part Time',
        'description': 'Python/Django developer position...'
      },
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: jobs.length,
      itemBuilder: (context, index) => _buildJobCard(jobs[index]),
    );
  }

  void _showApplySuccess() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 50,
                ),
                SizedBox(height: 20),
                Text(
                  'Application Submitted!',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Your application has been successfully submitted.',
                  style: GoogleFonts.poppins(),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpportunitiesHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20),
          Text(
            'Hello, Candidate!',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Explore your opportunities and applications today',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOpportunitiesCards() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Expanded(
            child: _buildOpportunityCard(
              title: 'Available Jobs',
              count: '',
              gradient: LinearGradient(
                colors: [
                  Color(0xFF991A1A).withValues(alpha: 0.8),
                  Color(0xFFC10D00).withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                // Navigate to available jobs or stay on current tab
                _safeSetState(() => _currentTab = 0);
              },
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: _buildOpportunityCard(
              title: 'Job Applications',
              count: '',
              gradient: LinearGradient(
                colors: [
                  Color(0xFF2A5298).withValues(alpha: 0.8),
                  Color(0xFF1E3C72).withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JobsAppliedPage(token: widget.token),
                  ),
                );
              },
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: _buildOpportunityCard(
              title: 'Saved Jobs',
              count: '',
              gradient: LinearGradient(
                colors: [
                  Color(0xFF11998e).withValues(alpha: 0.8),
                  Color(0xFF38ef7d).withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SavedApplicationsScreen(token: widget.token),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunityCard({
    required String title,
    required String count,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern or icon
            Positioned(
              right: 16,
              top: 16,
              child: Icon(
                Icons.work_outline,
                color: Colors.white.withValues(alpha: 0.3),
                size: 40,
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    count,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow indicator
            Positioned(
              bottom: 16,
              right: 16,
              child: Icon(
                Icons.arrow_forward,
                color: Colors.white.withValues(alpha: 0.7),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Fixed background that fills the entire screen
            Positioned.fill(
              child: Image.asset(
                'assets/images/dark.png',
                fit: BoxFit.cover,
              ),
            ),

            // Main content with transparent background
            Positioned.fill(
              child: CustomScrollView(
                slivers: [
                  // App Bar - Updated with real data
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 2,
                    title: Image.asset(
                      'assets/icons/khono.png',
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                    actions: [
                      _buildNavItem('Home', isActive: _currentTab == 0),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    AssessmentResultsPage(token: widget.token)),
                          );
                        },
                        child: _buildNavItem(
                          'Assessments Results',
                          color: Colors.white,
                        ),
                      ),
                      PopupMenuButton<String>(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: Text(
                              'Saved Applications',
                              style: GoogleFonts.poppins(color: Colors.black),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SavedApplicationsScreen(
                                      token: widget.token),
                                ),
                              );
                            },
                          ),
                          PopupMenuItem(
                            child: Text(
                              'Applied jobs',
                              style: GoogleFonts.poppins(color: Colors.black),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      JobsAppliedPage(token: widget.token),
                                ),
                              );
                            },
                          ),
                          PopupMenuItem(
                            child: Text(
                              'Offers',
                              style: GoogleFonts.poppins(color: Colors.black),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CandidateOffersScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(
                                'Application',
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showLogoutConfirmation(context),
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.white,
                        ),
                        label: Text('Log Out',
                            style: GoogleFonts.poppins(color: Colors.white)),
                      ),
                      // Notifications Bell Icon
                      Stack(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.notifications,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              if (notifications.isNotEmpty) {
                                _showNotificationsDialog();
                              }
                            },
                          ),
                          if (notifications.isNotEmpty)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Material(
                                color: Colors.red,
                                shape: CircleBorder(),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: Center(
                                    child: Text(
                                      notifications.length.toString(),
                                      style: GoogleFonts.poppins(
                                          color: Colors.white, fontSize: 10),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(width: 8),
                      // Profile Placeholder Icon
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    ProfilePage(token: widget.token)),
                          );
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _getProfileImageProvider(),
                        ),
                      ),
                      SizedBox(width: 16),
                    ],
                  ),

                  // Opportunities Section
                  SliverToBoxAdapter(
                    child: _buildOpportunitiesHeader(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildOpportunitiesCards(),
                  ),

                  // Jobs Section - KEPT AS IS
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Text(
                            'Job Listing',
                            style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          SizedBox(height: 32),
                          DefaultTabController(
                            length: 3,
                            child: Column(
                              children: [
                                TabBar(
                                  labelStyle: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                  unselectedLabelStyle:
                                      GoogleFonts.poppins(color: Colors.white),
                                  labelColor: Colors.white,
                                  unselectedLabelColor: Colors.white,
                                  indicatorColor: primaryColor,
                                  onTap: (index) =>
                                      _safeSetState(() => _currentTab = index),
                                  tabs: _jobTypes
                                      .map((type) => Tab(
                                          child: Text(type,
                                              style: GoogleFonts.poppins(
                                                  color: Colors.white))))
                                      .toList(),
                                ),
                                SizedBox(height: 32),
                                SizedBox(
                                  height: 600,
                                  child: TabBarView(
                                    children: _jobTypes
                                        .map((type) => _buildJobList())
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer - KEPT AS IS
                  SliverToBoxAdapter(
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 60, vertical: 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset('assets/images/logo3.png',
                                    width: 220,
                                    height: 120,
                                    fit: BoxFit.contain),
                                const SizedBox(width: 20),
                                Text(
                                  "© 2025 Khonology. All rights reserved.",
                                  style: GoogleFonts.poppins(
                                      color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
