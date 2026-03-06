import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

// Import your existing services
import 'job_details_page.dart';
import 'assessment_page.dart';
import 'redirect_to_assessment_page.dart';
import '../../services/candidate_service.dart';
import 'assessments_results_screen.dart';
import '../../screens/candidate/user_profile_page.dart';
import 'saved_application_screen.dart';
import '../../services/auth_service.dart';

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

  // ignore: unused_field
  int _currentTab = 0;
  final List<String> _jobTypes = ['Featured', 'Full Time', 'Part Time', 'Remote'];
  static const int _jobListPageSize = 8;
  int _jobListCurrentPage = 0;
  final Color primaryColor = Color(0xFF991A1A);
  final Color strokeColor = Color(0xFFC10D00);
  final Color fillColor = Color(0xFFf2f2f2).withValues(alpha: 0.2);
  final String apiBase = "http://127.0.0.1:5000/api/candidate";
  final GlobalKey _jobsSectionKey = GlobalKey();

  List<Map<String, dynamic>> notifications = [];
  Timer? _notificationTimer;
  String? _userName;
  List<Map<String, dynamic>> _jobs = [];
  bool _loadingJobs = true;
  bool _navigatingToAssessment = false;
  int? _applicationsCount;
  int? _savedCount; // saved drafts count
  Map<String, dynamic>? _pendingApplyJob;
  // ignore: unused_field
  bool _continuingApplication = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Persist token so Jobs Applied and other routes can use AuthService.getAccessToken()
    if (widget.token.trim().isNotEmpty) {
      AuthService.saveToken(widget.token);
    }
    // Use cached name so greeting shows correct name from first paint (set by login/MFA before navigate)
    _userName = AuthService.getCachedDisplayName();
    _loadPersistedNameIfNeeded();
    // Don't restore from cache on init — show Continue section only after API returns, so no stale "Not started" cards appear
    _fetchDashboardCounts();
    _fetchUserProfile();
    _fetchNotifications();
    _fetchJobs();
    _loadPendingApplyJob();
    _startNotificationTimer();
  }

  /// If in-memory name is null, load from persisted storage (survives token expiry until re-login).
  Future<void> _loadPersistedNameIfNeeded() async {
    if (_userName != null && _userName!.isNotEmpty) return;
    final persisted = await AuthService.getPersistedDisplayName();
    if (persisted != null && persisted.isNotEmpty && mounted) {
      _safeSetState(() => _userName = persisted);
    }
  }

  Future<void> _loadPendingApplyJob() async {
    final job = await AuthService.getPendingApplyJob();
    if (mounted) _safeSetState(() => _pendingApplyJob = job);
  }

  Future<void> _fetchUserProfile() async {
    try {
      final response = await AuthService.getCurrentUser(token: widget.token);
      if (response['unauthorized'] == true && mounted) {
        // Token expired and refresh failed; keep showing persisted name if any, and prompt re-login
        final persisted = await AuthService.getPersistedDisplayName();
        _safeSetState(() => _userName = (persisted != null && persisted.isNotEmpty) ? persisted : null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error']?.toString() ?? 'Session expired. Please log in again.'),
            backgroundColor: Colors.red.shade700,
            action: SnackBarAction(
              label: 'Log in',
              textColor: Colors.white,
              onPressed: () => context.go('/login'),
            ),
          ),
        );
        return;
      }
      // Use the name they used when they registered (candidate_profile or user profile only, not email)
      final candidateProfile = response['candidate_profile'];
      final user = response['user'] ?? response;
      final profile = user['profile'] is Map ? user['profile'] as Map : null;

      String? displayName;
      if (candidateProfile != null && candidateProfile['full_name']?.toString().trim().isNotEmpty == true) {
        displayName = candidateProfile['full_name'].toString().trim();
      }
      if (displayName == null || displayName.isEmpty) {
        final fullName = profile?['full_name']?.toString().trim();
        if (fullName != null && fullName.isNotEmpty) {
          displayName = fullName;
        }
      }
      if ((displayName == null || displayName.isEmpty) && profile != null) {
        final first = profile['first_name']?.toString() ?? '';
        final last = profile['last_name']?.toString() ?? '';
        final combined = '$first $last'.trim();
        if (combined.isNotEmpty) displayName = combined;
      }

      if (mounted) _safeSetState(() => _userName = (displayName != null && displayName.isNotEmpty) ? displayName : null);
    } catch (_) {
      if (mounted) {
        final persisted = await AuthService.getPersistedDisplayName();
        _safeSetState(() => _userName = (persisted != null && persisted.isNotEmpty) ? persisted : null);
      }
    }
  }

  static const _jobsFetchTimeout = Duration(seconds: 8);

  Future<void> _fetchJobs() async {
    _safeSetState(() => _loadingJobs = true);
    try {
      final list = await CandidateService.getAvailableJobs(widget.token)
          .timeout(_jobsFetchTimeout, onTimeout: () => <Map<String, dynamic>>[]);
      if (mounted) _safeSetState(() {
        _jobs = list;
        _loadingJobs = false;
      });
    } catch (_) {
      if (mounted) _safeSetState(() {
        _jobs = [];
        _loadingJobs = false;
      });
    }
  }

  /// Applications count: form submitted or assessment completed (what user sees in "My applications").
  static bool _isSubmittedOrCompletedApplication(dynamic app) {
    final status = app is Map ? app['status']?.toString() : null;
    return status == 'applied' ||
        status == 'assessment_submitted' ||
        status == 'disqualified';
  }

  /// Completed assessment only (for backward compatibility if needed).
  static bool _isCompletedApplication(dynamic app) {
    final status = app is Map ? app['status']?.toString() : null;
    return status == 'assessment_submitted' || status == 'disqualified';
  }

  /// Only draft or in_progress: not yet in "My applications". Once form is submitted (applied) or completed, show only in My applications, not in Continue.
  static bool _isInProgressApplication(dynamic app) {
    final status = app is Map ? app['status']?.toString() : null;
    return status == 'in_progress' || status == 'draft';
  }

  static bool _isAppliedOnlyApplication(dynamic app) {
    final status = app is Map ? app['status']?.toString() : null;
    return status == 'applied';
  }

  // ignore: unused_field
  Map<String, dynamic>? _inProgressApplication;
  List<Map<String, dynamic>> _inProgressApplications = [];
  List<Map<String, dynamic>> _completedApplications = [];
  /// Form submitted but assessment not done (status 'applied') — show "Applied" on job cards, not in Continue section.
  List<Map<String, dynamic>> _appliedOnlyApplications = [];
  int _interviewsScheduledCount = 0;
  bool _dashboardCountsLoaded = false;
  static const String _kCachedInProgressApps = 'candidate_in_progress_applications';
  /// In-memory cache so "Continue Your Application" shows on first paint after login (same session).
  // ignore: unused_field
  static List<Map<String, dynamic>>? _cachedInProgressApps;

  // ignore: unused_element
  Future<void> _loadCachedInProgressApplications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kCachedInProgressApps);
      if (mounted && json != null && json.isNotEmpty) {
        final list = jsonDecode(json) as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          final maps = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (maps.isNotEmpty) _safeSetState(() => _inProgressApplications = maps);
        }
      }
    } catch (_) {}
    // Do NOT set _dashboardCountsLoaded here — only _fetchDashboardCounts does, so Continue section stays empty until API returns
  }

  Future<void> _saveCachedInProgressApplications(List<Map<String, dynamic>> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCachedInProgressApps, jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _fetchDashboardCounts() async {
    try {
      final results = await Future.wait([
        CandidateService.getApplications(widget.token),
        CandidateService.getDrafts(widget.token),
      ]);
      if (mounted) {
        final apps = List<dynamic>.from(results[0]);
        final submittedOrCompletedList = apps.where(_isSubmittedOrCompletedApplication).toList();
        final submittedOrCompletedMaps = submittedOrCompletedList
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final completedList = apps.where(_isCompletedApplication).toList();
        final completedMaps = completedList
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final inProgressList = apps.where(_isInProgressApplication).toList();
        final inProgressMaps = inProgressList
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final appliedOnlyList = apps.where(_isAppliedOnlyApplication).toList();
        final appliedOnlyMaps = appliedOnlyList
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final firstInProgress = inProgressMaps.isNotEmpty ? inProgressMaps.first : null;
        _CandidateDashboardState._cachedInProgressApps = inProgressMaps;
        _safeSetState(() {
          _applicationsCount = submittedOrCompletedMaps.length;
          _savedCount = results[1].length;
          _inProgressApplication = firstInProgress;
          _inProgressApplications = inProgressMaps;
          _completedApplications = completedMaps;
          _appliedOnlyApplications = appliedOnlyMaps;
          _interviewsScheduledCount = 0; // TODO: fetch from candidate interviews API
          _dashboardCountsLoaded = true;
        });
        _saveCachedInProgressApplications(inProgressMaps);
        // If pending apply job is for a job we've already applied/completed, clear it so it doesn't show in Continue.
        final pending = await AuthService.getPendingApplyJob();
        if (pending != null && pending['id'] != null) {
          final pid = pending['id'] is int ? pending['id'] as int : int.tryParse(pending['id'].toString());
          if (pid != null) {
            final alreadyHas = submittedOrCompletedMaps.any((a) {
              final jid = a['job_id'];
              final id = jid is int ? jid : int.tryParse(jid?.toString() ?? '');
              return id == pid;
            });
            if (alreadyHas) {
              await AuthService.clearPendingApplyJob();
              if (mounted) _safeSetState(() => _pendingApplyJob = null);
            }
          }
        }
      }
    } catch (_) {
      if (mounted) _safeSetState(() {
        _applicationsCount = 0;
        _savedCount = 0;
        _inProgressApplication = null;
        _inProgressApplications = [];
        _completedApplications = [];
        _appliedOnlyApplications = [];
        _interviewsScheduledCount = 0;
        _dashboardCountsLoaded = true;
      });
    }
  }

  /// In-progress application for this job, if any (so we can show Continue instead of Apply Now). Only draft/in_progress.
  Map<String, dynamic>? _inProgressForJob(Map<String, dynamic> job) {
    final jobId = job['id'];
    if (jobId == null) return null;
    for (final app in _inProgressApplications) {
      if (app['job_id'] == jobId) return app;
    }
    return null;
  }

  /// Form submitted (status applied) for this job — show "Applied" on job card, not Continue.
  Map<String, dynamic>? _appliedOnlyForJob(Map<String, dynamic> job) {
    final jobId = job['id'];
    if (jobId == null) return null;
    for (final app in _appliedOnlyApplications) {
      if (app['job_id'] == jobId) return app;
    }
    return null;
  }

  /// Completed application for this job (assessment submitted), so we show "View results" instead of "Apply Now".
  Map<String, dynamic>? _completedApplicationForJob(Map<String, dynamic> job) {
    final jobId = job['id'];
    if (jobId == null) return null;
    for (final app in _completedApplications) {
      if (app['job_id'] == jobId) return app;
    }
    return null;
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
    if (widget.token.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('$apiBase/notifications'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          _safeSetState(() {
            notifications = decoded
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          });
        } else if (decoded is Map<String, dynamic>) {
          final ok = decoded['success'];
          final isSuccess = ok == true || ok == 'true';
          final list = decoded['notifications'];
          if (isSuccess && list is List) {
            _safeSetState(() {
              notifications = list
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
            });
          }
        }
      }
      // 401: ignore (token expired or not logged in); avoid spamming console
    } catch (e) {
      if (kIsWeb && e.toString().contains('Failed to fetch')) {
        // Likely CORS or server unreachable; avoid noisy log
        return;
      }
      print('Error fetching notifications: $e');
    }
  }

  void _showNotificationsDialog() {
    const double panelWidth = 360;
    const double maxPanelHeight = 420;
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        alignment: Alignment.topRight,
        insetPadding: EdgeInsets.only(top: 72, right: 12, left: 24, bottom: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: panelWidth, maxHeight: maxPanelHeight),
          child: Container(
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(8, 10, 4, 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.arrow_back, size: 22, color: Colors.black87),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Notifications',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, size: 22, color: Colors.black87),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ],
                  ),
                ),
                  Divider(height: 1),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxPanelHeight - 80),
                      child: notifications.isEmpty
                          ? Padding(
                              padding: EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                              child: Text(
                                'No notifications yet. Updates from hiring managers will appear here.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.symmetric(vertical: 4),
                              itemCount: notifications.length,
                              itemBuilder: (context, index) {
                                final notification = notifications[index];
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  leading: Icon(
                                    Icons.notifications_outlined,
                                    color: primaryColor,
                                    size: 22,
                                  ),
                                  title: Text(
                                    notification['message'] ?? 'New notification',
                                    style: GoogleFonts.poppins(fontSize: 14),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Text(
                                      _formatDate(notification['created_at']),
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
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

  // ignore: unused_element
  ImageProvider _getProfileImageProvider() {
    // Use the same default profile icon on all platforms (assets/icons/profile.png).
    return const AssetImage('assets/icons/profile.png');
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
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            constraints: BoxConstraints(maxWidth: 320),
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
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Are you sure you want to logout?',
                  style: GoogleFonts.poppins(color: Colors.black87),
                ),
                SizedBox(height: 16),
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
                        if (!context.mounted) return;
                        context.go('/login');
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

  // ignore: unused_element
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

  /// Primary nav link with optional tap and subtle active state (dashboard theme).
  Widget _buildNavLink(String label, {bool isActive = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.85),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _scrollToJobsSection() {
    final ctx = _jobsSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: Duration(milliseconds: 400), alignment: 0.1);
    }
  }

  // ignore: unused_element
  Widget _buildJobCard(Map<String, dynamic> job) {
    return _buildJobTableRow(job);
  }

  Widget _buildJobTableHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: _tableHeaderCell('Job Position')),
          Expanded(flex: 2, child: _tableHeaderCell('Company')),
          Expanded(flex: 1, child: _tableHeaderCell('Location')),
          SizedBox(width: 160),
        ],
      ),
    );
  }

  Widget _tableHeaderCell(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white70,
      ),
    );
  }

  Widget _buildJobTableRow(Map<String, dynamic> job) {
    final company = (job['company']?.toString().trim().isNotEmpty == true) ? (job['company'] ?? '') : '—';
    final location = (job['location']?.toString().trim().isNotEmpty == true) ? (job['location'] ?? '') : '—';
    final jobType = _formatJobType(job['type'] ?? job['employment_type'] ?? 'Full Time');
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              job['title'] ?? 'Job Title',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  company,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  jobType,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              location,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JobDetailsPage(job: job),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Color(0xFF3A3A3A),
                  side: BorderSide(color: Colors.white38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: Text(
                  'View Details',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
                ),
              ),
              SizedBox(width: 10),
              _buildApplyOrContinueButton(job),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApplyOrContinueButton(Map<String, dynamic> job) {
    final inProgress = _inProgressForJob(job);
    if (inProgress != null) {
      final appId = inProgress['application_id'];
      final draftData = inProgress['draft_data'] is Map
          ? Map<String, dynamic>.from(inProgress['draft_data'] as Map)
          : null;
      return ElevatedButton(
        onPressed: appId == null
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssessmentPage(
                      applicationId: appId as int,
                      draftData: draftData,
                    ),
                  ),
                ).then((_) => _fetchDashboardCounts());
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: strokeColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'Continue',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      );
    }
    // Assessment submitted: show "View results"
    final completed = _completedApplicationForJob(job);
    if (completed != null) {
      final appId = completed['application_id'] as int?;
      return ElevatedButton(
        onPressed: appId == null
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssessmentResultsPage(
                      token: widget.token,
                      applicationId: appId,
                    ),
                  ),
                );
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'View results',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      );
    }
    // Form submitted (applied) but assessment not done: show "Applied" (disabled), they see it in My applications
    final appliedOnly = _appliedOnlyForJob(job);
    if (appliedOnly != null) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade700,
          disabledBackgroundColor: Colors.grey.shade700,
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'Applied',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
      );
    }
    return ElevatedButton(
      onPressed: () => _handleApplyNow(job),
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
    );
  }

  static String _formatJobType(dynamic value) {
    final t = (value ?? '').toString().trim().toLowerCase();
    if (t.isEmpty) return 'Full Time';
    if (t.contains('full') || t == 'full_time') return 'Full Time';
    if (t.contains('part') || t == 'part_time') return 'Part Time';
    if (t.contains('remote')) return 'Remote';
    return value.toString();
  }

  /// True if the candidate has any application for this job (in progress, completed, or applied); such jobs are hidden from Recommended Jobs.
  bool _hasAnyApplicationForJob(Map<String, dynamic> job) {
    return _inProgressForJob(job) != null ||
        _completedApplicationForJob(job) != null ||
        _appliedOnlyForJob(job) != null;
  }

  List<Map<String, dynamic>> _getFilteredJobs(int typeIndex) {
    final typeFilter = _jobTypes[typeIndex];
    final byType = typeFilter == 'Featured'
        ? _jobs
        : _jobs.where((j) {
            final t = (j['type'] ?? j['employment_type'] ?? '').toString().toLowerCase();
            final loc = (j['location'] ?? '').toString().toLowerCase();
            if (typeFilter == 'Full Time') return t.contains('full') || t == 'full_time';
            if (typeFilter == 'Part Time') return t.contains('part') || t == 'part_time';
            if (typeFilter == 'Remote') return loc.contains('remote') || t.contains('remote');
            return true;
          }).toList();
    return byType.where((j) => !_hasAnyApplicationForJob(j)).toList();
  }

  List<Map<String, dynamic>> _getPaginatedJobs(int typeIndex) {
    final list = _getFilteredJobs(typeIndex);
    final start = _jobListCurrentPage * _jobListPageSize;
    if (start >= list.length) return [];
    final end = (start + _jobListPageSize).clamp(0, list.length);
    return list.sublist(start, end);
  }

  // ignore: unused_element
  int _getFilteredJobsTotalCount(int typeIndex) => _getFilteredJobs(typeIndex).length;

  Widget _buildJobList(int typeIndex) {
    final jobs = _getFilteredJobs(typeIndex);
    if (_loadingJobs) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CircularProgressIndicator(color: strokeColor),
        ),
      );
    }
    if (jobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No jobs found.',
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
          ),
        ),
      );
    }
    final paginatedJobs = _getPaginatedJobs(typeIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildJobTableHeader(),
                ...paginatedJobs.map((job) {
                  final j = Map<String, dynamic>.from(job);
                  if (!j.containsKey('type') && j.containsKey('employment_type')) {
                    j['type'] = j['employment_type'];
                  }
                  return _buildJobTableRow(j);
                }),
              ],
            ),
          ),
        ),
        SizedBox(height: 28),
        Center(
          child: TextButton.icon(
            onPressed: () {
              _safeSetState(() => _jobListCurrentPage = 0);
              _fetchJobs();
              _fetchDashboardCounts();
            },
            icon: Icon(Icons.refresh, size: 18, color: Colors.white70),
            label: Text(
              'Browse All Jobs',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Color(0xFF3A3A3A),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleApplyNow(Map<String, dynamic> job) async {
    final token = widget.token.isNotEmpty ? widget.token : await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      _showSignInToApplyDialog(job);
      return;
    }
    if (job['id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid job.')),
      );
      return;
    }
    // Navigate to redirect page immediately; it will call apply API then show countdown.
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RedirectToAssessmentPage(
          job: job,
          jobTitle: job['title']?.toString(),
        ),
      ),
    );
  }

  void _showSignInToApplyDialog(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign in to apply',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        content: Text(
          'Log in if you have an account, or create an account to apply for this job.',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService.setPendingApplyJob(job);
              if (!context.mounted) return;
              context.push('/register');
            },
            child: Text(
              'Create account',
              style: GoogleFonts.poppins(color: strokeColor, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService.setPendingApplyJob(job);
              if (!context.mounted) return;
              context.push('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: strokeColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Log in',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunitiesHeader() {
    final incompleteCount = _getDeduplicatedContinueItems().length;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20),
          Text(
            'Welcome back, ${_userName ?? 'Candidate'}!',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            incompleteCount > 0
                ? 'You have $incompleteCount application${incompleteCount == 1 ? '' : 's'} in progress.'
                : (_applicationsCount != null && _applicationsCount! > 0)
                    ? 'You have $_applicationsCount submitted application${_applicationsCount == 1 ? '' : 's'}.'
                    : 'Explore your opportunities and applications today',
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
              title: 'My applications',
              count: _applicationsCount != null ? '$_applicationsCount' : '—',
              gradient: LinearGradient(
                colors: [
                  Color(0xFF991A1A).withValues(alpha: 0.8),
                  Color(0xFFC10D00).withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                context.push('/jobs-applied?token=${Uri.encodeComponent(widget.token)}');
              },
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: _buildOpportunityCard(
              title: 'Interviews Scheduled',
              count: '$_interviewsScheduledCount',
              gradient: LinearGradient(
                colors: [
                  Color(0xFF2A5298).withValues(alpha: 0.8),
                  Color(0xFF1E3C72).withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                context.push('/jobs-applied?token=${Uri.encodeComponent(widget.token)}');
              },
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: _buildOpportunityCard(
              title: 'Saved Jobs',
              count: _savedCount != null ? '$_savedCount' : '—',
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

  Future<void> _continueWithApplication() async {
    final job = _pendingApplyJob;
    if (job == null) return;
    final jobId = job['id'];
    if (jobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid job.')),
      );
      return;
    }
    _safeSetState(() => _continuingApplication = true);
    try {
      final res = await http.post(
        Uri.parse('$apiBase/apply/$jobId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'full_name': '',
          'phone': '',
          'portfolio': '',
          'cover_letter': '',
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 201 && data is Map && data['application_id'] != null) {
        if (!mounted) return;
        await AuthService.clearPendingApplyJob();
        if (!mounted) return;
        _safeSetState(() => _pendingApplyJob = null);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AssessmentPage(
              applicationId: data['application_id'] as int,
            ),
          ),
        );
      } else if (res.statusCode == 400 && data is Map) {
        final err = data['error']?.toString() ?? '';
        if (!mounted) return;
        if (err.toLowerCase().contains('already applied')) {
          await AuthService.clearPendingApplyJob();
          if (mounted) _safeSetState(() => _pendingApplyJob = null);
          _fetchDashboardCounts();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This application is already in your list. Refreshing.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err.isNotEmpty ? err : 'Could not start application')),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data is Map ? (data['error']?.toString() ?? 'Could not start application') : 'Could not start application',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) _safeSetState(() => _continuingApplication = false);
    }
  }

  static String _timeAgo(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    final d = DateTime.tryParse(isoDate);
    if (d == null) return '';
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays > 0) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    if (diff.inHours > 0) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    return 'Just now';
  }

  /// Builds the deduplicated list of "Continue Your Application" items. Same job never appears twice. Skip pending job if user already has any application for it (in progress, applied, or completed) so completed jobs don't show as "Not started" in Continue.
  /// Returns empty until dashboard counts have loaded from API so no stale/pending cards appear on first paint.
  List<Map<String, dynamic>> _getDeduplicatedContinueItems() {
    if (!_dashboardCountsLoaded) return [];
    final items = <Map<String, dynamic>>[];
    final seenJobIds = <int>{};

    // Jobs the user has already applied to or completed must not appear in Continue (including as pending "Not started").
    void addJobId(dynamic jobId) {
      if (jobId == null) return;
      final id = jobId is int ? jobId : int.tryParse(jobId.toString());
      if (id != null) seenJobIds.add(id);
    }
    for (final app in _completedApplications) {
      addJobId(app['job_id']);
    }
    for (final app in _appliedOnlyApplications) {
      addJobId(app['job_id']);
    }

    for (final app in _inProgressApplications) {
      final jobId = app['job_id'];
      if (jobId != null) {
        final id = jobId is int ? jobId : int.tryParse(jobId.toString());
        if (id != null && seenJobIds.contains(id)) continue;
        if (id != null) seenJobIds.add(id);
      }
      items.add({
        'type': 'in_progress',
        'job': null,
        'application_id': app['application_id'],
        'job_title': app['job_title'],
        'company': app['company'],
        'location': app['location'],
        'draft_data': app['draft_data'],
        'saved_at': app['saved_at'],
        'last_saved_screen': app['last_saved_screen'],
      });
    }

    if (_pendingApplyJob != null) {
      final pendingId = _pendingApplyJob!['id'];
      if (pendingId != null) {
        final id = pendingId is int ? pendingId : int.tryParse(pendingId.toString());
        if (id != null && !seenJobIds.contains(id)) {
          seenJobIds.add(id);
          items.add({
            'type': 'pending',
            'job': _pendingApplyJob!,
            'application_id': null,
            'draft_data': null,
            'saved_at': null,
            'last_saved_screen': null,
          });
        }
      } else {
        items.add({
          'type': 'pending',
          'job': _pendingApplyJob!,
          'application_id': null,
          'draft_data': null,
          'saved_at': null,
          'last_saved_screen': null,
        });
      }
    }
    return items;
  }

  Widget _buildContinueYourApplicationSection() {
    final items = _getDeduplicatedContinueItems();
    // Section always visible; when no items yet show brief loading or empty state (no spinner)
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Continue Your Application',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            Text(
              _dashboardCountsLoaded
                  ? 'No applications in progress. Browse jobs below.'
                  : 'Loading your applications...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Continue Your Application',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 228,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(right: 32),
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(width: 16),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 380,
                  child: _buildIncompleteApplicationCard(items[index], compact: true),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Estimate progress 0–100 from draft_data / last_saved_screen.
  int _progressPercent(Map<String, dynamic>? draftData, String? lastSavedScreen) {
    if (draftData == null || draftData.isEmpty) return lastSavedScreen != null ? 25 : 0;
    final screen = (lastSavedScreen ?? '').toString().toLowerCase();
    if (screen.contains('assessment')) {
      final assessment = draftData['assessment'] ?? draftData['assessment.assessment'];
      if (assessment is Map && assessment.isNotEmpty) return 75;
      return 50;
    }
    if (screen.isNotEmpty && screen != 'job_details') return 50;
    return 25;
  }

  Widget _buildIncompleteApplicationCard(Map<String, dynamic> item, {bool compact = false}) {
    final type = item['type'] as String?;
    String title;
    String? company;
    String? location;
    String statusLine;
    int progressPercent;
    bool showProgressBar;
    VoidCallback? onContinue;

    if (type == 'pending') {
      final job = item['job'] as Map<String, dynamic>? ?? {};
      title = job['title']?.toString() ?? 'Job';
      company = job['company']?.toString().trim();
      location = job['location']?.toString().trim();
      statusLine = 'Not started';
      progressPercent = 0;
      showProgressBar = false;
      onContinue = _continueWithApplication;
    } else {
      title = item['job_title']?.toString() ?? 'Application';
      company = item['company']?.toString().trim();
      location = item['location']?.toString().trim();
      final savedAt = item['saved_at']?.toString();
      final draftData = item['draft_data'] is Map
          ? Map<String, dynamic>.from(item['draft_data'] as Map)
          : null;
      final lastSaved = item['last_saved_screen']?.toString();
      progressPercent = _progressPercent(draftData, lastSaved);
      if (progressPercent == 0) progressPercent = 25;
      showProgressBar = true;
      final timeAgo = savedAt != null && savedAt.isNotEmpty ? _timeAgo(savedAt) : null;
      if (timeAgo != null && timeAgo.isNotEmpty) {
        statusLine = '$progressPercent% complete - last updated $timeAgo';
      } else {
        statusLine = 'In progress';
      }
      final appId = item['application_id'] as int?;
      onContinue = appId == null
          ? null
          : () {
              _safeSetState(() => _navigatingToAssessment = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssessmentPage(
                      applicationId: appId,
                      draftData: draftData,
                    ),
                  ),
                ).then((_) {
                  if (mounted) _safeSetState(() => _navigatingToAssessment = false);
                  _fetchDashboardCounts();
                });
              });
            };
    }

    return Padding(
      padding: compact ? EdgeInsets.zero : EdgeInsets.only(bottom: 16),
      child: Container(
        height: compact ? double.infinity : null,
        padding: EdgeInsets.all(compact ? 14 : 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (company != null && company.isNotEmpty) ...[
              SizedBox(height: 4),
              Text(
                company,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (location != null && location.isNotEmpty) ...[
              SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: Colors.white54),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ] else if (compact) ...[
              // Reserve space when no location so progress bar and status align with other cards
              SizedBox(height: 6),
              SizedBox(height: 20),
            ],
            SizedBox(height: 10),
            if (showProgressBar) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressPercent / 100,
                  minHeight: 6,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(strokeColor),
                ),
              ),
              SizedBox(height: 6),
            ],
            Row(
              children: [
                if (showProgressBar && progressPercent >= 25)
                  Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.check_circle, size: 14, color: Colors.green.shade400),
                  ),
                Expanded(
                  child: Text(
                    statusLine,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (compact) Spacer(),
            SizedBox(height: compact ? 0 : 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: strokeColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Continue',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
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
            // Loading overlay when navigating to assessment (instant feedback)
            if (_navigatingToAssessment)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: strokeColor),
                        SizedBox(height: 16),
                        Text(
                          'Opening assessment...',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                  // App Bar - logo (title), nav tabs + utility (actions)
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    title: Image.asset(
                      'assets/icons/khono.png',
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                    titleSpacing: 24,
                    actions: [
                      _buildNavLink('Dashboard', isActive: true),
                      SizedBox(width: 28),
                      _buildNavLink('Browse Jobs', onTap: _scrollToJobsSection),
                      SizedBox(width: 28),
                      _buildNavLink('Applications', onTap: () {
                        context.push('/jobs-applied?token=${Uri.encodeComponent(widget.token)}');
                      }),
                      SizedBox(width: 28),
                      _buildNavLink('Assessments', onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AssessmentResultsPage(token: widget.token),
                          ),
                        );
                      }),
                      SizedBox(width: 40),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
                            onPressed: () => _showNotificationsDialog(),
                          ),
                          if (notifications.isNotEmpty)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: strokeColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  notifications.length > 99 ? '99+' : notifications.length.toString(),
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 10),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(width: 8),
                      PopupMenuButton<String>(
                        offset: Offset(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        color: Color(0xFF2C2C2C),
                        onSelected: (value) {
                          if (value == 'profile') {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => ProfilePage(token: widget.token),
                            ));
                          } else if (value == 'logout') {
                            _showLogoutConfirmation(context);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'profile',
                            child: Row(
                              children: [
                                Icon(Icons.person_outline, color: Colors.white70, size: 20),
                                SizedBox(width: 12),
                                Text('My Profile', style: GoogleFonts.poppins(color: Colors.white)),
                              ],
                            ),
                          ),
                          PopupMenuDivider(color: Colors.white24),
                          PopupMenuItem(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout, color: Colors.white70, size: 20),
                                SizedBox(width: 12),
                                Text('Log Out', style: GoogleFonts.poppins(color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: primaryColor,
                            child: Icon(Icons.person, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                      SizedBox(width: 24),
                    ],
                  ),

                  // Opportunities Section
                  SliverToBoxAdapter(
                    child: _buildOpportunitiesHeader(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildOpportunitiesCards(),
                  ),

                  // Continue Your Application section (always visible immediately after login)
                  SliverToBoxAdapter(
                    child: _buildContinueYourApplicationSection(),
                  ),

                  // Jobs Section (scroll target for "Browse Jobs")
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        key: _jobsSectionKey,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recommended Jobs',
                            style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          SizedBox(height: 24),
                          DefaultTabController(
                            length: _jobTypes.length,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TabBar(
                                  isScrollable: true,
                                  tabAlignment: TabAlignment.start,
                                  labelStyle: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15),
                                  unselectedLabelStyle:
                                      GoogleFonts.poppins(
                                          color: Colors.white70,
                                          fontSize: 15),
                                  labelColor: Colors.white,
                                  unselectedLabelColor: Colors.white70,
                                  indicatorColor: primaryColor,
                                  indicatorWeight: 3,
                                  onTap: (index) => _safeSetState(() {
                                        _currentTab = index;
                                        _jobListCurrentPage = 0;
                                      }),
                                  tabs: _jobTypes
                                      .map((type) => Tab(
                                          child: Text(type,
                                              style: GoogleFonts.poppins(
                                                  color: Colors.white))))
                                      .toList(),
                                ),
                                Container(
                                  height: 1,
                                  margin: EdgeInsets.only(top: 0),
                                  color: Colors.white24,
                                ),
                                SizedBox(height: 24),
                                SizedBox(
                                  height: 860,
                                  child: TabBarView(
                                    children: _jobTypes
                                        .asMap()
                                        .entries
                                        .map((e) => _buildJobList(e.key))
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
                                  "┬⌐ 2025 Khonology. All rights reserved.",
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
