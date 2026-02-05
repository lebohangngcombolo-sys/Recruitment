import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io' if (dart.library.html) 'package:khono_recruite/io_stub.dart' show File;
import 'dart:typed_data';
import 'package:khono_recruite/profile_image_provider_io.dart'
    if (dart.library.html) 'package:khono_recruite/profile_image_provider_stub.dart'
    as profile_image_provider;

// Import your existing services
import '../../services/candidate_service.dart';
import '../../services/auth_service.dart';

/// New landing screen: hero, explore by category, job cards. Optional [token] for logged-in state.
/// Teammate will refine the real "candidate dashboard" (applications, profile, etc.) in candidate_dashboard.dart.
class LandingPage extends StatefulWidget {
  final String? token;
  const LandingPage({super.key, this.token});

  @override
  _LandingPageState createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  int _currentTab = 0;
  int _selectedCategoryIndex = 0; // 0 = All, 1..8 = category tabs
  // Aligned with Khonology's typical vacancies (development, architecture, cloud, data/digital)
  static const List<String> _categoryNames = [
    'All',
    'Development',
    'Architecture',
    'Cloud & DevOps',
    'Engineering',
    'Data & Digital',
    'Business & Consulting',
  ];

  /// Explore By Category uses only real API jobs (no mock data).
  static List<Map<String, dynamic>> get _categoryMockJobs => [];

  final Color primaryColor = Color(0xFF991A1A);
  final Color strokeColor = Color(0xFFC10D00); // Accent (e.g. backgrounds)
  final Color borderColor = Colors.white; // Borders for inputs, buttons, cards
  final Color fillColor =
      Color(0xFFf2f2f2).withOpacity(0.2); // Fill with 20% opacity

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
  final TextEditingController _categorySearchController = TextEditingController();
  String _categoryLocationFilter = 'All Locations';
  static const int _entriesPerPage = 4;
  int _categoryPageSize = _entriesPerPage;
  int _categoryCurrentPage = 0;
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
    if (_hasToken) fetchProfileImage();
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
    _categorySearchController.dispose();
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

  bool get _hasToken =>
      widget.token != null && widget.token!.trim().isNotEmpty;

  void _loadInitialData() {
    // Always fetch jobs for explore category (public API when not logged in)
    fetchAvailableJobs();
    if (!_hasToken) {
      _safeSetState(() {
        loadingApplications = false;
        loadingNotifications = false;
      });
      return;
    }
    fetchApplications();
    fetchNotifications();
    fetchCandidateProfile();
  }

  void _safeRefreshData() {
    fetchCandidateProfile();
  }

  // ---------- Fetch profile image ----------
  Future<void> fetchProfileImage() async {
    if (!_hasToken) return;
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
    if (_profileImage == null || !_hasToken) return;

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
      return profile_image_provider.getProfileImageProviderFromPath(_profileImage!.path);
    }

    if (_profileImageUrl.isNotEmpty) {
      return NetworkImage(_profileImageUrl);
    }

    return const AssetImage("assets/images/profile_placeholder.png");
  }

  // Fetch jobs for explore category: public API when not logged in, candidate API when logged in
  Future<void> fetchAvailableJobs() async {
    if (!mounted) return;

    _safeSetState(() => loadingJobs = true);
    try {
      final List<Map<String, dynamic>> jobs = _hasToken && widget.token != null
          ? await CandidateService.getAvailableJobs(widget.token!)
          : await CandidateService.getPublicJobs();
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
    if (!mounted || !_hasToken) return;

    _safeSetState(() => loadingApplications = true);
    try {
      final data = await CandidateService.getApplications(widget.token!);
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
    if (!mounted || !_hasToken) return;

    _safeSetState(() => loadingNotifications = true);
    try {
      final data = await CandidateService.getNotifications(widget.token!);
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
    if (!mounted || !_hasToken) return;

    try {
      final data = await CandidateService.getProfile(widget.token!);
      if (!mounted) return;

      _safeSetState(() => candidateProfile = data);
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
  }

  // Your existing filter methods (kept for possible dashboard/filter UI)
  // ignore: unused_element
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

  /// Jobs used for Explore By Category (real API data only).
  List<Map<String, dynamic>> get _jobsForCategorySection => availableJobs;

  List<Map<String, dynamic>> get _categoryFilteredJobs {
    final safeIndex = _selectedCategoryIndex;
    final index = safeIndex.clamp(0, _categoryNames.length - 1);
    final source = _jobsForCategorySection;
    if (index == 0) return source;
    final category = _categoryNames[index];
    // Match any word in the category (e.g. "Cloud & DevOps" -> cloud, devops)
    final terms = category.toLowerCase().split(RegExp(r'\s+|\s*&\s*')).where((s) => s.length > 1).toList();
    if (terms.isEmpty) return source;
    return source.where((job) {
      final role = (job['role']?.toString() ?? '').toLowerCase();
      final title = (job['title']?.toString() ?? '').toLowerCase();
      final text = '$role $title';
      return terms.any((term) => text.contains(term));
    }).toList();
  }

  /// Jobs in current category filtered by search + location (for table under category tab).
  List<Map<String, dynamic>> get _categoryListFilteredJobs {
    var list = _categoryFilteredJobs;
    final query = _categorySearchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((job) {
        final title = (job['title']?.toString() ?? '').toLowerCase();
        final role = (job['role']?.toString() ?? '').toLowerCase();
        final loc = (job['location']?.toString() ?? '').toLowerCase();
        return title.contains(query) ||
            role.contains(query) ||
            loc.contains(query);
      }).toList();
    }
    if (_categoryLocationFilter != 'All Locations') {
      list = list
          .where((job) =>
              (job['location']?.toString() ?? 'Remote') == _categoryLocationFilter)
          .toList();
    }
    return list;
  }

  int get _categoryListTotalCount => _categoryListFilteredJobs.length;

  /// Jobs to show for current page only (Previous/Next pagination).
  List<Map<String, dynamic>> get _categoryListPaginatedJobs {
    final list = _categoryListFilteredJobs;
    final start = _categoryCurrentPage * _categoryPageSize;
    if (start >= list.length) return [];
    final end = (start + _categoryPageSize).clamp(0, list.length);
    return list.sublist(start, end);
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

  /// Locations for category section chips (from API jobs).
  List<String> get _categorySectionLocations {
    final locations = _jobsForCategorySection
        .map((job) => job['location']?.toString() ?? 'Remote')
        .toSet()
        .toList();
    return ['All Locations', ...locations];
  }

  // Your existing chatbot methods
  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    if (!_hasToken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to use the chat')),
      );
      return;
    }

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
    if (!_hasToken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to analyze your CV')),
      );
      return;
    }

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
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                  color: primaryColor.withOpacity(0.5), width: 1),
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
    await AuthService.logout();
    if (mounted) context.go('/login');
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

  // Updated to handle real job data — dark theme to match the app
  Widget _buildJobItem(String title, String location, String type,
      String salary, Map<String, dynamic> job) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      color: Colors.white.withOpacity(0.06),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white12, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: primaryColor.withOpacity(0.2),
              backgroundImage: job['company_logo'] != null
                  ? NetworkImage(job['company_logo'])
                  : null,
              child: job['company_logo'] == null
                  ? Icon(Icons.business, color: strokeColor, size: 24)
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
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
                              size: 16, color: strokeColor),
                          SizedBox(width: 4),
                          Text(location,
                              style: GoogleFonts.poppins(
                                  color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 16, color: strokeColor),
                          SizedBox(width: 4),
                          Text(type,
                              style: GoogleFonts.poppins(
                                  color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attach_money,
                              size: 16, color: strokeColor),
                          SizedBox(width: 4),
                          Text(salary,
                              style: GoogleFonts.poppins(
                                  color: Colors.white70, fontSize: 14)),
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
                    IconButton(
                      icon: Icon(Icons.favorite_border,
                          color: strokeColor, size: 22),
                      onPressed: () => _saveJob(job),
                    ),
                    SizedBox(width: 4),
                    ElevatedButton(
                        onPressed: () => context.push('/job-details', extra: job),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Apply Now',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Date Line: ${job['deadline'] ?? '01 Jan, 2045'}',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.white54),
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

  // Updated search functionality (kept for possible search UI)
  // ignore: unused_element
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
                          border: Border.all(color: borderColor, width: 1),
                          color: fillColor,
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() {}),
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Keyword',
                            hintStyle: GoogleFonts.poppins(
                                color: Colors.white, fontSize: 16),
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
                          border: Border.all(color: borderColor, width: 1),
                          color: fillColor,
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            hintColor: Colors.white,
                            inputDecorationTheme: InputDecorationTheme(
                              hintStyle: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 16),
                            ),
                            textTheme: Theme.of(context).textTheme.copyWith(
                              bodyLarge: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 16),
                              bodyMedium: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 16),
                            ),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedJobFilter == 'All Jobs'
                                ? null
                                : _selectedJobFilter,
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontSize: 16),
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
                                  color: Colors.white, fontSize: 16),
                            ),
                            selectedItemBuilder: (context) => _jobTitles
                                .map((String s) => Text(s,
                                    style: GoogleFonts.poppins(
                                        color: Colors.white, fontSize: 16)))
                                .toList(),
                            items: _jobTitles
                                .map((category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(category,
                                          style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 16)),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _selectedJobFilter = value ?? 'All Jobs'),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: borderColor, width: 1),
                          color: fillColor,
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            hintColor: Colors.white,
                            inputDecorationTheme: InputDecorationTheme(
                              hintStyle: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 16),
                            ),
                            textTheme: Theme.of(context).textTheme.copyWith(
                              bodyLarge: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 16),
                              bodyMedium: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 16),
                            ),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedPlaceFilter == 'All Locations'
                                ? null
                                : _selectedPlaceFilter,
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontSize: 16),
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
                                  color: Colors.white, fontSize: 16),
                            ),
                            selectedItemBuilder: (context) => _locations
                                .map((String s) => Text(s,
                                    style: GoogleFonts.poppins(
                                        color: Colors.white, fontSize: 16)))
                                .toList(),
                            items: _locations
                                .map((location) => DropdownMenuItem(
                                      value: location,
                                      child: Text(location,
                                          style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 16)),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _selectedPlaceFilter = value ?? 'All Locations'),
                          ),
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
                  border: Border.all(color: borderColor, width: 1),
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
                          color: Colors.white, fontSize: 16)),
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
            color: Colors.black.withOpacity(0.8),
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
                  color: Colors.white.withOpacity(0.2),
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
                  color: Colors.white.withOpacity(0.1),
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
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                            ? Colors.white.withOpacity(0.2)
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
                            ? Colors.white.withOpacity(0.2)
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
                        ? Colors.white.withOpacity(0.2)
                        : Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.1)),
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
              color: Colors.white.withOpacity(0.7),
              backgroundColor: Colors.black.withOpacity(0.3),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.2)),
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
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
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
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.2)),
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
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.2)),
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
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2)),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.3)),
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
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.2)),
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
                  ElevatedButton(
                    onPressed: () => context.go('/register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: strokeColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: Colors.black.withOpacity(0.25),
                      padding: EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Get Started',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/find-talent'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: strokeColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: Colors.black.withOpacity(0.25),
                      padding: EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Find A Talent',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
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
            color: Colors.white.withOpacity(0.2),
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
                    automaticallyImplyLeading: false,
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
                        child: GestureDetector(
                          onTap: () => context.go('/'),
                          child: _buildNavItem('Home', isActive: _currentTab == 0),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: GestureDetector(
                          onTap: () => context.push('/about-us'),
                          child: _buildNavItem(
                            'About Us',
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: GestureDetector(
                          onTap: () => context.push('/contact'),
                          child: _buildNavItem(
                            'Contact',
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (_hasToken) ...[
                        IconButton(
                          icon: Icon(Icons.notifications_outlined,
                              color: Colors.white, size: 22),
                          onPressed: _showNotificationsDialog,
                        ),
                        GestureDetector(
                          onTap: () => _showLogoutConfirmation(context),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: primaryColor.withOpacity(0.3),
                            backgroundImage: _getProfileImageProvider() as ImageProvider?,
                            child: _profileImage == null && _profileImageUrl.isEmpty
                                ? Icon(Icons.person, color: Colors.white70, size: 20)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else ...[
                        ElevatedButton(
                          onPressed: () => context.go('/login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: strokeColor,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor: Colors.black.withOpacity(0.25),
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text('Login',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                      const SizedBox(width: 16),
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

                  // Explore By Category - tabs + vacancies (positioned where filters were)
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(),
                      padding: EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Explore By Category',
                            style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white24,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(_categoryNames.length, (int i) {
                                  final idx = i.clamp(0, _categoryNames.length - 1);
                                  final isSelected = _selectedCategoryIndex.clamp(0, _categoryNames.length - 1) == idx;
                                  return InkWell(
                                    onTap: () => _safeSetState(() {
                                      _selectedCategoryIndex = idx;
                                      _categoryCurrentPage = 0;
                                    }),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                      margin: EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: isSelected
                                                ? strokeColor
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        _categoryNames[idx],
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.white70,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                          // Search bar
                          TextField(
                            controller: _categorySearchController,
                            onChanged: (_) => _safeSetState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search by title, role, or location...',
                              hintStyle: GoogleFonts.poppins(
                                  color: Colors.white38, fontSize: 15),
                              prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: Colors.white54,
                                  size: 22),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.06),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.white12, width: 1),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                            ),
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontSize: 15),
                          ),
                          SizedBox(height: 16),
                          // Location chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _categorySectionLocations.map((loc) {
                                final isSelected = _categoryLocationFilter == loc;
                                return Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(loc,
                                        style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white70)),
                                    selected: isSelected,
                                    onSelected: (_) => _safeSetState(() {
                                      _categoryLocationFilter = loc;
                                      _categoryCurrentPage = 0;
                                    }),
                                    backgroundColor: Color(0xFF1e1212),
                                    selectedColor: primaryColor.withOpacity(0.6),
                                    checkmarkColor: Colors.white,
                                    side: BorderSide(
                                        color: isSelected
                                            ? strokeColor
                                            : Colors.white24,
                                        width: 1),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          SizedBox(height: 24),
                          // Job cards
                          _categoryListFilteredJobs.isEmpty
                              ? Container(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 48, horizontal: 24),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.work_off_rounded,
                                          size: 48, color: Colors.white24),
                                      SizedBox(height: 16),
                                      Text(
                                        'No positions match your filters',
                                        style: GoogleFonts.poppins(
                                            color: Colors.white70,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Try a different search or location, or check back later.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                            color: Colors.white54,
                                            fontSize: 14),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ..._categoryListPaginatedJobs.map((job) =>
                                        Padding(
                                          padding: EdgeInsets.only(bottom: 12),
                                          child: _buildJobItem(
                                            job['title'] ?? 'Position',
                                            job['location'] ?? 'Location',
                                            job['type'] ?? 'Type',
                                            job['salary'] ?? 'Salary',
                                            job,
                                          ),
                                        )),
                                    SizedBox(height: 16),
                                    // Pagination footer — solid background to match app
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF252525),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.white10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Showing ${_categoryListTotalCount == 0 ? 0 : (_categoryCurrentPage * _categoryPageSize) + 1} to ${(_categoryCurrentPage * _categoryPageSize + _categoryListPaginatedJobs.length).clamp(0, _categoryListTotalCount)} of $_categoryListTotalCount entries',
                                            style: GoogleFonts.poppins(
                                                color: Colors.white70,
                                                fontSize: 13),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextButton(
                                                onPressed:
                                                    _categoryCurrentPage > 0
                                                        ? () => _safeSetState(
                                                            () =>
                                                                _categoryCurrentPage--)
                                                        : null,
                                                child: Text('Previous',
                                                    style: GoogleFonts.poppins(
                                                        color:
                                                            _categoryCurrentPage >
                                                                    0
                                                                ? strokeColor
                                                                : Colors
                                                                    .white38)),
                                              ),
                                              SizedBox(width: 8),
                                              TextButton(
                                                onPressed: (_categoryCurrentPage +
                                                              1) *
                                                          _categoryPageSize <
                                                      _categoryListTotalCount
                                                    ? () => _safeSetState(
                                                        () =>
                                                            _categoryCurrentPage++)
                                                    : null,
                                                child: Text('Next',
                                                    style: GoogleFonts.poppins(
                                                        color: (_categoryCurrentPage +
                                                                    1) *
                                                                _categoryPageSize <
                                                            _categoryListTotalCount
                                                            ? strokeColor
                                                            : Colors
                                                                .white38)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
