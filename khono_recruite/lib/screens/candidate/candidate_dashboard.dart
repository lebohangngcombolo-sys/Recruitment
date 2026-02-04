import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

// Import your existing services
import '../../services/candidate_service.dart';
import 'job_details_page.dart';
import 'assessments_results_screen.dart';
import '../../screens/candidate/user_profile_page.dart';
import 'jobs_applied_page.dart';
import 'saved_application_screen.dart';
import '../../services/auth_service.dart';
import '../../screens/auth/login_screen.dart';
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
  final Color strokeColor = Color(0xFFC10D00); // New stroke color
  final Color fillColor =
      Color(0xFFf2f2f2).withValues(alpha: 0.2); // Fill with 20% opacity

  // Your existing data states
  List<Map<String, dynamic>> availableJobs = [];
  bool loadingJobs = true;
  List<dynamic> applications = [];
  bool loadingApplications = true;
  List<Map<String, dynamic>> notifications = [];
  bool loadingNotifications = true;
  Map<String, dynamic>? candidateProfile;

  // Your existing filter states
  String _selectedJobFilter = 'All Jobs';
  String _selectedRoleFilter = 'All Roles';
  String _selectedPlaceFilter = 'All Locations';
  String _selectedJobTypeFilter = 'All Types';
  final TextEditingController _searchController = TextEditingController();

  // Your existing chatbot state
  bool chatbotOpen = false;
  bool cvParserMode = false;
  final TextEditingController messageController = TextEditingController();
  final TextEditingController jobDescController = TextEditingController();
  final TextEditingController cvController = TextEditingController();
  final List<Map<String, String>> messages = [];
  Map<String, dynamic>? cvAnalysisResult;
  bool _isLoading = false;

  // Your existing state management
  bool _isDisposed = false;
  final PageController _pageController = PageController();

  XFile? _profileImage;
  Uint8List? _profileImageBytes;
  String _profileImageUrl = "";
  final String apiBase = "http://127.0.0.1:5000/api/candidate";

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    fetchProfileImage();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    messageController.dispose();
    jobDescController.dispose();
    cvController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _safeRefreshData();
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    fetchAvailableJobs();
    fetchApplications();
    fetchNotifications();
    fetchCandidateProfile();
  }

  void _safeRefreshData() {
    fetchCandidateProfile();
  }

  // ---------- Fetch profile image ----------
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

  // ---------- Upload profile picture ----------
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
          const SnackBar(content: Text("Profile picture updated")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: ${response.statusCode}")),
        );
      }
    } catch (e) {
      debugPrint("Profile image upload error: $e");
    }
  }

  // ---------- Get correct image provider ----------
  ImageProvider<Object> _getProfileImageProvider() {
    if (_profileImage != null) {
      if (kIsWeb) return MemoryImage(_profileImageBytes!);
      return FileImage(File(_profileImage!.path));
    }

    if (_profileImageUrl.isNotEmpty) {
      return NetworkImage(_profileImageUrl);
    }

    return const AssetImage("assets/images/profile_placeholder.png");
  }

  // Your existing API methods
  Future<void> fetchAvailableJobs() async {
    if (!mounted) return;

    _safeSetState(() => loadingJobs = true);
    try {
      final jobs = await CandidateService.getAvailableJobs(widget.token);
      if (!mounted) return;

      _safeSetState(() {
        availableJobs = List<Map<String, dynamic>>.from(jobs);
      });
    } catch (e) {
      debugPrint("Error fetching jobs: $e");
      if (!mounted) return;
      _safeSetState(() => loadingJobs = false);
    } finally {
      if (mounted) {
        _safeSetState(() => loadingJobs = false);
      }
    }
  }

  Future<void> fetchApplications() async {
    if (!mounted) return;

    _safeSetState(() => loadingApplications = true);
    try {
      final data = await CandidateService.getApplications(widget.token);
      if (!mounted) return;

      _safeSetState(() {
        applications = data;
      });
    } catch (e) {
      debugPrint("Error fetching applications: $e");
      if (!mounted) return;
      _safeSetState(() => loadingApplications = false);
    } finally {
      if (mounted) {
        _safeSetState(() => loadingApplications = false);
      }
    }
  }

  Future<void> fetchNotifications() async {
    if (!mounted) return;

    _safeSetState(() => loadingNotifications = true);
    try {
      final data = await CandidateService.getNotifications(widget.token);
      if (!mounted) return;

      _safeSetState(() {
        notifications = data;
      });
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
      if (!mounted) return;
      _safeSetState(() => loadingNotifications = false);
    } finally {
      if (mounted) {
        _safeSetState(() => loadingNotifications = false);
      }
    }
  }

  Future<void> fetchCandidateProfile() async {
    if (!mounted) return;

    try {
      final data = await CandidateService.getProfile(widget.token);
      if (!mounted) return;

      _safeSetState(() => candidateProfile = data);
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
  }

  // Your existing filter methods
  List<Map<String, dynamic>> get _filteredJobs {
    var filtered = availableJobs;

    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((job) {
        final title = job['title']?.toString().toLowerCase() ?? '';
        final company = job['company']?.toString().toLowerCase() ?? '';
        final searchTerm = _searchController.text.toLowerCase();
        return title.contains(searchTerm) || company.contains(searchTerm);
      }).toList();
    }

    if (_selectedJobFilter != 'All Jobs') {
      filtered =
          filtered.where((job) => job['title'] == _selectedJobFilter).toList();
    }

    if (_selectedRoleFilter != 'All Roles') {
      filtered =
          filtered.where((job) => job['role'] == _selectedRoleFilter).toList();
    }

    if (_selectedPlaceFilter != 'All Locations') {
      filtered = filtered
          .where((job) => job['location'] == _selectedPlaceFilter)
          .toList();
    }

    if (_selectedJobTypeFilter != 'All Types') {
      filtered = filtered
          .where((job) => job['type'] == _selectedJobTypeFilter)
          .toList();
    }

    return filtered;
  }

  List<String> get _jobTitles {
    final titles = availableJobs
        .map((job) => job['title']?.toString() ?? 'Unknown')
        .toSet()
        .toList();
    return ['All Jobs', ...titles];
  }

  List<String> get _locations {
    final locations = availableJobs
        .map((job) => job['location']?.toString() ?? 'Remote')
        .toSet()
        .toList();
    return ['All Locations', ...locations];
  }

  // Your existing chatbot methods
  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    _safeSetState(() {
      messages.add({"type": "chat", "text": "You: $text"});
      messageController.clear();
    });

    try {
      final response = await http.post(
        Uri.parse("http://127.0.0.1:5000/api/ai/chat"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
        body: jsonEncode({"message": text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data["reply"] ?? "No reply from AI";

        if (mounted) {
          _safeSetState(() {
            messages.add({"type": "chat", "text": "AI: $reply"});
          });
        }
      } else {
        if (mounted) {
          _safeSetState(() {
            messages.add({
              "type": "chat",
              "text":
                  "AI: Failed to get response (status ${response.statusCode})"
            });
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _safeSetState(() {
          messages.add({"type": "chat", "text": "AI: Error - $e"});
        });
      }
    }
  }

  Future<void> analyzeCV() async {
    final jobDesc = jobDescController.text.trim();
    final cvText = cvController.text.trim();
    if (jobDesc.isEmpty || cvText.isEmpty) return;

    _safeSetState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse("http://127.0.0.1:5000/api/ai/parse_cv"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
        body: jsonEncode({
          "job_description": jobDesc,
          "cv_text": cvText,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          _safeSetState(() => cvAnalysisResult = data);
        }
      } else {
        debugPrint("Failed to analyze CV: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error analyzing CV: $e");
    } finally {
      if (mounted) {
        _safeSetState(() => _isLoading = false);
      }
    }
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: Colors.white.withValues(alpha: 0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                  color: primaryColor.withValues(alpha: 0.5), width: 1),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout, color: primaryColor, size: 32),
                  const SizedBox(height: 15),
                  Text("Logout",
                      style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Text("Are you sure you want to logout?",
                      style: GoogleFonts.poppins(color: Colors.black54)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text("Cancel",
                              style:
                                  GoogleFonts.poppins(color: Colors.black54)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, Color(0xFFEF5350)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _performLogout(context);
                          },
                          child: Text("Logout",
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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

  // Updated UI methods with your logic
  Widget _buildNavItem(
    String title, {
    bool isActive = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: color ?? (isActive ? Colors.white : Colors.white70),
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // Updated to use real job data
  Widget _buildJobList() {
    final jobsToShow = _currentTab == 0
        ? _filteredJobs.take(5).toList() // Featured - show first 5
        : _filteredJobs;

    return ListView(
      children: [
        ...jobsToShow
            .map((job) => _buildJobItem(
                  job['title'] ?? 'Position',
                  job['location'] ?? 'Location',
                  job['type'] ?? 'Type',
                  job['salary'] ?? 'Salary',
                  job, // Pass the full job object
                ))
            .toList(),
        SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: ElevatedButton(
              onPressed: () {
                _safeSetState(() => _currentTab = 1);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: strokeColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Text('Browse More Jobs',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }

  // Updated to handle real job data
  Widget _buildJobItem(String title, String location, String type,
      String salary, Map<String, dynamic> job) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: primaryColor.withValues(alpha: 0.1),
              backgroundImage: job['company_logo'] != null
                  ? NetworkImage(job['company_logo'])
                  : null,
              child: job['company_logo'] == null
                  ? Icon(Icons.business, color: primaryColor, size: 24)
                  : null,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on,
                              size: 16, color: primaryColor),
                          SizedBox(width: 4),
                          Text(location, style: GoogleFonts.poppins()),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 16, color: primaryColor),
                          SizedBox(width: 4),
                          Text(type, style: GoogleFonts.poppins()),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attach_money,
                              size: 16, color: primaryColor),
                          SizedBox(width: 4),
                          Text(salary, style: GoogleFonts.poppins()),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.favorite_border, color: primaryColor),
                        onPressed: () {
                          _saveJob(job);
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => JobDetailsPage(job: job)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: Text('Apply Now', style: GoogleFonts.poppins()),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Date Line: ${job['deadline'] ?? '01 Jan, 2045'}',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _saveJob(Map<String, dynamic> job) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Job saved to favorites', style: GoogleFonts.poppins()),
        backgroundColor: primaryColor,
      ),
    );
  }

  // Updated search functionality
  Widget _buildSearchSection() {
    return Container(
      decoration: BoxDecoration(),
      padding: EdgeInsets.all(35),
      child: Container(
        constraints: BoxConstraints(maxWidth: 1200),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: strokeColor, width: 1),
                          color: fillColor,
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() {}),
                          style: GoogleFonts.poppins(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Keyword',
                            hintStyle: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                            filled: false,
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: strokeColor, width: 1),
                          color: fillColor,
                        ),
                        child: DropdownButtonFormField(
                          style: GoogleFonts.poppins(color: Colors.white),
                          dropdownColor: Colors.black,
                          icon:
                              Icon(Icons.arrow_drop_down, color: Colors.white),
                          iconEnabledColor: Colors.white,
                          iconDisabledColor: Colors.white,
                          iconSize: 24,
                          decoration: InputDecoration(
                            filled: false,
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            hintText: 'All Jobs',
                            hintStyle: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          items: _jobTitles
                              .map((category) => DropdownMenuItem(
                                    value: category,
                                    child: Text(category,
                                        style: GoogleFonts.poppins(
                                            color: Colors.white)),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedJobFilter = value!),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: strokeColor, width: 1),
                          color: fillColor,
                        ),
                        child: DropdownButtonFormField(
                          style: GoogleFonts.poppins(color: Colors.white),
                          dropdownColor: Colors.black,
                          icon:
                              Icon(Icons.arrow_drop_down, color: Colors.white),
                          iconEnabledColor: Colors.white,
                          iconDisabledColor: Colors.white,
                          iconSize: 24,
                          decoration: InputDecoration(
                            filled: false,
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            hintText: 'All Locations',
                            hintStyle: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          items: _locations
                              .map((location) => DropdownMenuItem(
                                    value: location,
                                    child: Text(location,
                                        style: GoogleFonts.poppins(
                                            color: Colors.white)),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedPlaceFilter = value!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: strokeColor, width: 1),
                  color: fillColor,
                ),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text('Search',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLuxuryChatbotPanel() {
    return Container(
      width: 380,
      height: 500,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(76)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  'assets/icons/Chatbot_Red.png',
                  width: 20,
                  height: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Career AI Assistant",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () => _safeSetState(() => chatbotOpen = false),
                  icon: Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton(
                      onPressed: () =>
                          _safeSetState(() => cvParserMode = false),
                      style: TextButton.styleFrom(
                        backgroundColor: !cvParserMode
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        "Career Chat",
                        style: GoogleFonts.poppins(
                          color: !cvParserMode ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton(
                      onPressed: () => _safeSetState(() => cvParserMode = true),
                      style: TextButton.styleFrom(
                        backgroundColor: cvParserMode
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        "CV Analysis",
                        style: GoogleFonts.poppins(
                          color: cvParserMode ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: cvParserMode
                ? _buildLuxuryCVParserTab()
                : _buildLuxuryChatMessages(),
          ),
        ],
      ),
    );
  }

  Widget _buildLuxuryChatMessages() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Container(
                  decoration: BoxDecoration(
                    color: msg['text']!.startsWith('You:')
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      msg['text'] ?? "",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_isLoading)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
            ),
            child: LinearProgressIndicator(
              color: Colors.white.withValues(alpha: 0.7),
              backgroundColor: Colors.black.withValues(alpha: 0.3),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: TextField(
                  controller: messageController,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "Ask about career advice...",
                    hintStyle: GoogleFonts.poppins(
                        color: Colors.white54, fontSize: 12),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: IconButton(
                onPressed: sendMessage,
                icon: Icon(Icons.send, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLuxuryCVParserTab() {
    PlatformFile? uploadedResume;
    bool _isParsing = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Job Description",
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: TextField(
                  controller: jobDescController,
                  maxLines: 3,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "Paste position requirements here...",
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Professional CV",
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: TextField(
                  controller: cvController,
                  maxLines: 4,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "Paste your professional CV here...",
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: TextButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
                        );
                        if (result != null && result.files.isNotEmpty) {
                          setState(() => uploadedResume = result.files.first);
                        }
                      },
                      icon: const Icon(Icons.upload_file,
                          size: 14, color: Colors.white),
                      label: Text(
                        "Upload Resume",
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.white),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (uploadedResume != null)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          uploadedResume!.name,
                          style: GoogleFonts.poppins(
                              color: Colors.white54, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: TextButton(
                  onPressed: _isParsing
                      ? null
                      : () async {
                          final jobDesc = jobDescController.text.trim();
                          final cvText = cvController.text.trim();
                          if (jobDesc.isEmpty || cvText.isEmpty) return;
                          setState(() => _isParsing = true);
                          await analyzeCV();
                          setState(() => _isParsing = false);
                        },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  child: _isParsing
                      ? SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          "Analyze CV Compatibility",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              if (cvAnalysisResult != null)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      jsonEncode(cvAnalysisResult),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.notifications, color: primaryColor),
                    SizedBox(width: 8),
                    Text('Notifications',
                        style: GoogleFonts.poppins(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    return Container(
                      decoration: BoxDecoration(),
                      child: ListTile(
                        leading: Icon(Icons.notifications, color: primaryColor),
                        title: Text(notif['title'] ?? 'Notification',
                            style: GoogleFonts.poppins()),
                        subtitle: Text(notif['message'] ?? '',
                            style: GoogleFonts.poppins()),
                      ),
                    );
                  },
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Close', style: GoogleFonts.poppins()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselItem(String title, String description) {
    return Container(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 800),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(description,
                  style:
                      GoogleFonts.poppins(color: Colors.white, fontSize: 18)),
              SizedBox(height: 32),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: strokeColor, width: 1),
                      color: fillColor,
                    ),
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text('Search A Job',
                          style: GoogleFonts.poppins(color: Colors.white)),
                    ),
                  ),
                  SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: strokeColor, width: 1),
                      color: fillColor,
                    ),
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text('Find A Talent',
                          style: GoogleFonts.poppins(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String title, String vacancies) {
    return Card(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: strokeColor, width: 1),
      ),
      child: InkWell(
        onTap: () {},
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: fillColor,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.white),
              SizedBox(height: 16),
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              SizedBox(height: 8),
              Text(vacancies,
                  style: GoogleFonts.poppins(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.check, color: primaryColor),
          SizedBox(width: 8),
          Text(text, style: GoogleFonts.poppins(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildTestimonialItem() {
    return Container(
      width: 300,
      margin: EdgeInsets.all(8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: strokeColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.format_quote, size: 32, color: Colors.white),
          SizedBox(height: 16),
          Expanded(
            child: Text(
              'This platform has completely transformed the way I prepare for interviews. The feedback is clear, practical, and actually helps me improve. Highly recommended!',
              style: GoogleFonts.poppins(
                  fontStyle: FontStyle.italic, color: Colors.white),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: strokeColor,
                child: Icon(Icons.person, color: Colors.white),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Client Name',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Profession',
                      style: GoogleFonts.poppins(color: Colors.white70)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _socialIcon(String assetPath, String url) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: InkWell(
        onTap: () async {
          final Uri uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(assetPath,
                width: 24, height: 24, fit: BoxFit.contain),
          ),
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
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child:
                            _buildNavItem('Home', isActive: _currentTab == 0),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => AssessmentResultsPage(
                                      token: widget.token)),
                            );
                          },
                          child: _buildNavItem(
                            'Assessments Results',
                            color: Colors.white,
                          ),
                        ),
                      ),

                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: PopupMenuButton<String>(
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
                                  style:
                                      GoogleFonts.poppins(color: Colors.white),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: TextButton.icon(
                          onPressed: () => _showLogoutConfirmation(context),
                          icon: const Icon(
                            Icons.logout,
                            color: Colors.white,
                          ),
                          label: Text('Log Out',
                              style: GoogleFonts.poppins(color: Colors.white)),
                        ),
                      ),

                      // Notifications Bell Icon
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Stack(
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
                                child: Container(
                                  padding: EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: BoxConstraints(
                                      minWidth: 16, minHeight: 16),
                                  child: Text(
                                    notifications.length.toString(),
                                    style: GoogleFonts.poppins(
                                        color: Colors.white, fontSize: 10),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      // Profile Placeholder Icon
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: GestureDetector(
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
                      ),
                      SizedBox(width: 16),
                    ],
                  ),

                  // Carousel Section
                  SliverToBoxAdapter(
                    child: Container(
                      height: 500,
                      decoration: BoxDecoration(),
                      child: PageView(
                        children: [
                          _buildCarouselItem(
                            'Find the Perfect Job You Deserve',
                            'Discover opportunities tailored to your skills and ambitions. We help you connect with roles that offer growth, purpose, and long-term success.',
                          ),
                          _buildCarouselItem(
                            'Find the Best Startup Role That Fits You',
                            'Join innovative teams where your ideas matter. Explore startup positions that match your strengths and give you the freedom to make a real impact.',
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Search Section
                  SliverToBoxAdapter(
                    child: _buildSearchSection(),
                  ),

                  // Categories Section
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(),
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Text(
                            'Explore By Category',
                            style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          SizedBox(height: 32),
                          GridView.count(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            crossAxisCount: 4,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            children: [
                              _buildCategoryItem(Icons.mark_email_read,
                                  'Marketing', '123 Vacancy'),
                              _buildCategoryItem(Icons.headset_mic,
                                  'Customer Service', '123 Vacancy'),
                              _buildCategoryItem(Icons.people, 'Human Resource',
                                  '123 Vacancy'),
                              _buildCategoryItem(Icons.assignment,
                                  'Project Management', '123 Vacancy'),
                              _buildCategoryItem(Icons.trending_up,
                                  'Business Development', '123 Vacancy'),
                              _buildCategoryItem(Icons.handshake,
                                  'Sales & Communication', '123 Vacancy'),
                              _buildCategoryItem(Icons.school,
                                  'Teaching & Education', '123 Vacancy'),
                              _buildCategoryItem(Icons.design_services,
                                  'Design & Creative', '123 Vacancy'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // About Section
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(),
                      padding: EdgeInsets.all(32),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: GridView.count(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                children: [
                                  Image.asset('assets/images/collaggge.jpg',
                                      fit: BoxFit.cover),
                                  Image.asset('assets/images/Mosa.jpg',
                                      fit: BoxFit.cover),
                                  Image.asset('assets/images/office.jpg',
                                      fit: BoxFit.cover),
                                  Image.asset('assets/images/thato.png',
                                      fit: BoxFit.cover),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'We Help To Get The Best Job And Find A Talent',
                                      style: GoogleFonts.poppins(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'We connect ambitious professionals with opportunities that match their skills, goals, and passion. '
                                      'Whether you\'re building your dream career or searching for exceptional talent, our smart matching '
                                      'system and expert guidance make the journey faster, easier, and more impactful.',
                                      style: GoogleFonts.poppins(
                                          fontSize: 16, color: Colors.white),
                                    ),
                                    SizedBox(height: 16),
                                    _buildFeatureItem(
                                        'Smart AI-powered job matching to save you time'),
                                    _buildFeatureItem(
                                        'Verified talent profiles for confident hiring decisions'),
                                    _buildFeatureItem(
                                        'Personalized guidance to help you stand out and grow'),
                                    SizedBox(height: 16),
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: ElevatedButton(
                                        onPressed: () {},
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: strokeColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                        child: Text('Read More',
                                            style: GoogleFonts.poppins(
                                                color: Colors.white)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Jobs Section
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(),
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
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: DefaultTabController(
                              length: 3,
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: TabBar(
                                      labelStyle: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                      unselectedLabelStyle: GoogleFonts.poppins(
                                          color: Colors.white),
                                      labelColor: Colors.white,
                                      unselectedLabelColor: Colors.white,
                                      indicatorColor: primaryColor,
                                      onTap: (index) => _safeSetState(
                                          () => _currentTab = index),
                                      tabs: _jobTypes
                                          .map((type) => Tab(
                                              child: Text(type,
                                                  style: GoogleFonts.poppins(
                                                      color: Colors.white))))
                                          .toList(),
                                    ),
                                  ),
                                  SizedBox(height: 32),
                                  Container(
                                    height: 600,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: TabBarView(
                                      children: _jobTypes
                                          .map((type) => _buildJobList())
                                          .toList(),
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

                  // Testimonials Section
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(),
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Text(
                            'Our Clients Say!!!',
                            style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          SizedBox(height: 32),
                          Container(
                            height: 220,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _buildTestimonialItem(),
                                _buildTestimonialItem(),
                                _buildTestimonialItem(),
                                _buildTestimonialItem(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 60, vertical: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset('assets/images/logo3.png',
                              width: 220, height: 120, fit: BoxFit.contain),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _socialIcon('assets/icons/Instagram1.png',
                                    'https://www.instagram.com/yourprofile'),
                                _socialIcon('assets/icons/x1.png',
                                    'https://x.com/yourprofile'),
                                _socialIcon('assets/icons/Linkedin1.png',
                                    'https://www.linkedin.com/in/yourprofile'),
                                _socialIcon('assets/icons/facebook1.png',
                                    'https://www.facebook.com/yourprofile'),
                                _socialIcon('assets/icons/YouTube1.png',
                                    'https://www.youtube.com/yourchannel'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "© 2025 Khonology. All rights reserved.",
                            style: GoogleFonts.poppins(
                                color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ===== LUXURY CHATBOT PANEL =====
            if (chatbotOpen)
              Positioned(
                right: 20,
                bottom: 80,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildLuxuryChatbotPanel(),
                ),
              ),
          ],
        ),

        // Floating Chatbot Icon
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
          ),
          child: FloatingActionButton(
            onPressed: () => _safeSetState(() => chatbotOpen = !chatbotOpen),
            backgroundColor: primaryColor,
            child: Image.asset(
              'assets/icons/Chatbot_Red.png',
              width: 30,
              height: 30,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
