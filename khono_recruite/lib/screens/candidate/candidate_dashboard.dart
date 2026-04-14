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
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import 'job_details_page.dart';
import 'assessment_page.dart';
import 'redirect_to_assessment_page.dart';
import '../../services/candidate_service.dart';
import '../../services/unified_api_service.dart';
import 'assessments_results_screen.dart';
import '../../screens/candidate/user_profile_page.dart';
import '../../services/auth_service.dart';
import '../../utils/app_config.dart';

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
  final List<String> _jobTypes = [
    'Featured',
    'Full Time',
    'Part Time',
    'Remote',
  ];
  static const int _jobListPageSize = 8;
  int _jobListCurrentPage = 0;
  final Color primaryColor = Color(0xFF991A1A);
  final Color strokeColor = Color(0xFFC10D00);
  final Color fillColor = Color(0xFFf2f2f2).withValues(alpha: 0.2);
  final String apiBase = "${AppConfig.apiBase}/api/candidate";
  final GlobalKey _jobsSectionKey = GlobalKey();
  final ScrollController _mainScrollController = ScrollController();
  /// Sidebar width; keep in sync with `_buildSideMenu`.
  static const double _sideMenuWidth = 210;
  /// Theme + chatbot: same hit target; theme uses [_cornerActionGlyph] inside the circle.
  static const double _cornerActionSize = 44;
  static const double _cornerActionGlyph = 26;
  static const double _cornerActionGap = 10;
  String _activeSidebarItem = 'dashboard';

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
    _loadStoredUserNameIfNeeded();
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

  Future<void> _loadStoredUserNameIfNeeded() async {
    if (_userName != null && _userName!.isNotEmpty) return;
    final user = await AuthService.getUserInfo();
    if (user == null) return;

    final fullName = user['full_name']?.toString().trim();
    final first = user['first_name']?.toString().trim() ?? '';
    final last = user['last_name']?.toString().trim() ?? '';
    final combined = '$first $last'.trim();
    final resolved = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : (combined.isNotEmpty ? combined : null);

    if (resolved != null && mounted) {
      AuthService.setCachedDisplayName(resolved);
      await AuthService.persistDisplayName(resolved);
      _safeSetState(() => _userName = resolved);
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
        _safeSetState(
          () => _userName =
              (persisted != null && persisted.isNotEmpty) ? persisted : null,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['error']?.toString() ??
                  'Session expired. Please log in again.',
            ),
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
      final data = response['data'] is Map ? response['data'] as Map : null;
      final candidateProfile = response['candidate_profile'] ??
          (data is Map ? data['candidate_profile'] : null);
      final user = response['user'] ??
          (data is Map ? data['user'] : null) ??
          response;
      final profile = user['profile'] is Map ? user['profile'] as Map : null;

      String? displayName;
      final rootFullName = user['full_name']?.toString().trim();
      if (rootFullName != null && rootFullName.isNotEmpty) {
        displayName = rootFullName;
      }
      if (candidateProfile != null &&
          candidateProfile['full_name']?.toString().trim().isNotEmpty == true) {
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
      if ((displayName == null || displayName.isEmpty)) {
        final first = user['first_name']?.toString() ?? '';
        final last = user['last_name']?.toString() ?? '';
        final combined = '$first $last'.trim();
        if (combined.isNotEmpty) displayName = combined;
      }

      if (displayName != null && displayName.isNotEmpty) {
        AuthService.setCachedDisplayName(displayName);
        await AuthService.persistDisplayName(displayName);
      }
      if (mounted)
        _safeSetState(
          () => _userName = (displayName != null && displayName.isNotEmpty)
              ? displayName
              : null,
        );
    } catch (_) {
      if (mounted) {
        final persisted = await AuthService.getPersistedDisplayName();
        _safeSetState(
          () => _userName =
              (persisted != null && persisted.isNotEmpty) ? persisted : null,
        );
      }
    }
  }

  static const _jobsFetchTimeout = Duration(seconds: 8);

  Future<void> _fetchJobs() async {
    _safeSetState(() => _loadingJobs = true);
    try {
      // Use the widget token directly instead of relying on storage
      final token = widget.token.trim().isNotEmpty
          ? widget.token
          : await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('No authentication token available');
      }

      final list = await UnifiedApiService.getJobsWithToken(token).timeout(
        _jobsFetchTimeout,
        onTimeout: () => <Map<String, dynamic>>[],
      );
      if (mounted)
        _safeSetState(() {
          _jobs = list;
          _loadingJobs = false;
        });
    } catch (_) {
      if (mounted)
        _safeSetState(() {
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

  /// All application records (irrespective of status) so we can reliably hide already-applied jobs
  /// from Recommended Jobs even when backend status values vary.
  List<Map<String, dynamic>> _allApplications = [];
  int _interviewsScheduledCount = 0;
  bool _dashboardCountsLoaded = false;
  static const String _kCachedInProgressApps =
      'candidate_in_progress_applications';

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
          if (maps.isNotEmpty)
            _safeSetState(() => _inProgressApplications = maps);
        }
      }
    } catch (_) {}
    // Do NOT set _dashboardCountsLoaded here — only _fetchDashboardCounts does, so Continue section stays empty until API returns
  }

  Future<void> _saveCachedInProgressApplications(
    List<Map<String, dynamic>> list,
  ) async {
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
        CandidateService.getInterviews(widget.token),
      ]);
      if (mounted) {
        final apps = List<dynamic>.from(results[0] as Iterable<dynamic>);
        final allAppsMaps = apps
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final submittedOrCompletedList =
            apps.where(_isSubmittedOrCompletedApplication).toList();
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
        final firstInProgress =
            inProgressMaps.isNotEmpty ? inProgressMaps.first : null;
        _CandidateDashboardState._cachedInProgressApps = inProgressMaps;
        final interviewData = results[2] is Map<String, dynamic>
            ? results[2] as Map<String, dynamic>
            : <String, dynamic>{};
        final scheduledCount = interviewData['scheduled_count'] is int
            ? interviewData['scheduled_count'] as int
            : (int.tryParse(
                  interviewData['scheduled_count']?.toString() ?? '',
                ) ??
                0);
        _safeSetState(() {
          _applicationsCount = submittedOrCompletedMaps.length;
          _savedCount = (results[1] as List).length;
          _inProgressApplication = firstInProgress;
          _inProgressApplications = inProgressMaps;
          _completedApplications = completedMaps;
          _appliedOnlyApplications = appliedOnlyMaps;
          _allApplications = allAppsMaps;
          _interviewsScheduledCount = scheduledCount;
          _dashboardCountsLoaded = true;
        });
        _saveCachedInProgressApplications(inProgressMaps);
        // If pending apply job is for a job we've already applied/completed, clear it so it doesn't show in Continue.
        final pending = await AuthService.getPendingApplyJob();
        if (pending != null && pending['id'] != null) {
          final pid = pending['id'] is int
              ? pending['id'] as int
              : int.tryParse(pending['id'].toString());
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
      if (mounted)
        _safeSetState(() {
          _applicationsCount = 0;
          _savedCount = 0;
          _inProgressApplication = null;
          _inProgressApplications = [];
          _completedApplications = [];
          _appliedOnlyApplications = [];
          _allApplications = [];
          _interviewsScheduledCount = 0;
          _dashboardCountsLoaded = true;
        });
    }
  }

  int? _toIntId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  bool _idsEqual(dynamic a, dynamic b) {
    final ia = _toIntId(a);
    final ib = _toIntId(b);
    if (ia == null || ib == null) return false;
    return ia == ib;
  }

  /// In-progress application for this job, if any (so we can show Continue instead of Apply Now). Only draft/in_progress.
  Map<String, dynamic>? _inProgressForJob(Map<String, dynamic> job) {
    final jobId = job['id'];
    if (jobId == null) return null;
    for (final app in _inProgressApplications) {
      if (_idsEqual(app['job_id'], jobId)) return app;
    }
    return null;
  }

  /// Form submitted (status applied) for this job — show "Applied" on job card, not Continue.
  Map<String, dynamic>? _appliedOnlyForJob(Map<String, dynamic> job) {
    final jobId = job['id'];
    if (jobId == null) return null;
    for (final app in _appliedOnlyApplications) {
      if (_idsEqual(app['job_id'], jobId)) return app;
    }
    return null;
  }

  /// Completed application for this job (assessment submitted), so we show "View results" instead of "Apply Now".
  Map<String, dynamic>? _completedApplicationForJob(Map<String, dynamic> job) {
    final jobId = job['id'];
    if (jobId == null) return null;
    for (final app in _completedApplications) {
      if (_idsEqual(app['job_id'], jobId)) return app;
    }
    return null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTimer?.cancel();
    _mainScrollController.dispose();
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
      // Use the widget token directly instead of relying on storage
      final token = widget.token.trim().isNotEmpty
          ? widget.token
          : await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('No authentication token available');
      }

      final notificationList =
          await UnifiedApiService.getNotificationsWithToken(token);
      if (mounted) {
        _safeSetState(() {
          notifications = notificationList;
        });
      }
    } catch (e) {
      if (kIsWeb && e.toString().contains('Failed to fetch')) {
        // Likely CORS or server unreachable; avoid noisy log
        return;
      }
      print('Error fetching notifications: $e');
    }
  }

  /// Treat missing [is_read] as unread (older API responses).
  bool _isNotificationUnread(Map<String, dynamic> n) {
    final r = n['is_read'];
    if (r == null) return true;
    if (r is bool) return !r;
    if (r is int) return r == 0;
    final s = r.toString().toLowerCase();
    return s != 'true' && s != '1';
  }

  int _unreadNotificationCount() =>
      notifications.where(_isNotificationUnread).length;

  int _compareCreatedAtDesc(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return db.compareTo(da);
  }

  Future<void> _markNotificationSeen(Map<String, dynamic> n) async {
    if (!_isNotificationUnread(n)) return;
    final rawId = n['id'];
    if (rawId == null) return;
    final id = int.tryParse(rawId.toString());
    if (id == null) return;
    try {
      await UnifiedApiService.markNotificationRead(id);
      if (!mounted) return;
      _safeSetState(() {
        final i = notifications.indexWhere(
          (e) => e['id'].toString() == rawId.toString(),
        );
        if (i >= 0) {
          notifications[i] = {...notifications[i], 'is_read': true};
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not update notification: $e',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ),
        );
      }
    }
  }

  void _showNotificationsDialog() {
    const double panelWidth = 360;
    const double maxPanelHeight = 480;
    bool showUnreadTab = true;
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        alignment: Alignment.topRight,
        insetPadding: EdgeInsets.only(top: 72, right: 12, left: 24, bottom: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: panelWidth,
            maxHeight: maxPanelHeight,
          ),
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
                        icon: Icon(
                          Icons.arrow_back,
                          size: 22,
                          color: Colors.black87,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
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
                        icon: Icon(
                          Icons.close,
                          size: 22,
                          color: Colors.black87,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxPanelHeight - 80),
                  child: notifications.isEmpty
                      ? Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 32,
                            horizontal: 20,
                          ),
                          child: Text(
                            'No notifications yet. Updates from hiring managers will appear here.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        )
                      : StatefulBuilder(
                          builder: (context, setDialogState) {
                            final unread = notifications
                                .where(_isNotificationUnread)
                                .toList()
                              ..sort(_compareCreatedAtDesc);
                            final read = notifications
                                .where((n) => !_isNotificationUnread(n))
                                .toList()
                              ..sort(_compareCreatedAtDesc);

                            Widget emptyHint(String text) {
                              return Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 20,
                                ),
                                child: Text(
                                  text,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.black45,
                                  ),
                                ),
                              );
                            }

                            Widget tile(Map<String, dynamic> notification,
                                {required bool unreadStyle}) {
                              final messageText =
                                  _getNotificationMessage(notification);
                              final dateText = _formatDate(
                                notification['created_at']?.toString(),
                              );
                              return Material(
                                color: unreadStyle
                                    ? primaryColor.withValues(alpha: 0.06)
                                    : Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    await _markNotificationSeen(notification);
                                    setDialogState(() {
                                      if (showUnreadTab && unread.length == 1) {
                                        showUnreadTab = false;
                                      }
                                    });
                                  },
                                  child: Container(
                                    decoration: unreadStyle
                                        ? BoxDecoration(
                                            border: Border(
                                              left: BorderSide(
                                                color: strokeColor,
                                                width: 3,
                                              ),
                                            ),
                                          )
                                        : null,
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                      leading: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Icon(
                                            Icons.notifications_outlined,
                                            color: primaryColor,
                                            size: 22,
                                          ),
                                          if (unreadStyle)
                                            Positioned(
                                              right: -2,
                                              top: -2,
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: strokeColor,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      title: Text(
                                        messageText,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.black87,
                                          fontWeight: unreadStyle
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Text(
                                          dateText,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            Widget tabButton({
                              required String label,
                              required int count,
                              required bool active,
                              required VoidCallback onTap,
                            }) {
                              return Expanded(
                                child: GestureDetector(
                                  onTap: onTap,
                                  child: AnimatedContainer(
                                    duration: Duration(milliseconds: 180),
                                    padding: EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? primaryColor.withValues(alpha: 0.09)
                                          : Colors.transparent,
                                      border: Border(
                                        bottom: BorderSide(
                                          color: active
                                              ? strokeColor
                                              : Colors.black12,
                                          width: active ? 2 : 1,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          label,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: active
                                                ? strokeColor
                                                : Colors.black54,
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: active
                                                ? strokeColor
                                                : Colors.black12,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '$count',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: active
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            final activeList = showUnreadTab ? unread : read;

                            return Column(
                              children: [
                                Row(
                                  children: [
                                    tabButton(
                                      label: 'Unread',
                                      count: unread.length,
                                      active: showUnreadTab,
                                      onTap: () => setDialogState(
                                          () => showUnreadTab = true),
                                    ),
                                    tabButton(
                                      label: 'Read',
                                      count: read.length,
                                      active: !showUnreadTab,
                                      onTap: () => setDialogState(
                                          () => showUnreadTab = false),
                                    ),
                                  ],
                                ),
                                Expanded(
                                  child: activeList.isEmpty
                                      ? emptyHint(
                                          showUnreadTab
                                              ? "You're all caught up — no new alerts."
                                              : 'Opened notifications appear here.',
                                        )
                                      : ListView(
                                          padding: EdgeInsets.only(bottom: 12),
                                          children: activeList
                                              .map(
                                                (n) => tile(
                                                  n,
                                                  unreadStyle: showUnreadTab,
                                                ),
                                              )
                                              .toList(),
                                        ),
                                ),
                              ],
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

  /// Build a clear, never-blank message. For interview-related alerts, direct user to the Interview screen.
  String _getNotificationMessage(Map<String, dynamic> notification) {
    final type = (notification['type']?.toString() ?? '').toLowerCase();
    if (type == 'interview') {
      return 'You have an alert. Check your Interview tab for details.';
    }
    final message = notification['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;
    final title = notification['title']?.toString().trim();
    if (title != null && title.isNotEmpty) return title;
    final body = notification['body']?.toString().trim();
    if (body != null && body.isNotEmpty) return body;
    final content = notification['content']?.toString().trim();
    if (content != null && content.isNotEmpty) return content;
    return 'You have an alert. Check your Interview tab for details.';
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
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

  String get _greetingName {
    final name = _userName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Name Surname';
  }

  static const Color _figmaLightText = Color(0xFF090812);

  Color _cdOnSurface(bool dark) =>
      dark ? Colors.white : _figmaLightText;
  Color _cdOnSurfaceMuted(bool dark) => dark
      ? Colors.white70
      : _figmaLightText.withValues(alpha: 0.76);
  Color _cdPanelBg(bool dark) => dark
      ? Colors.white.withValues(alpha: 0.14)
      : Colors.white.withValues(alpha: 0.72);
  Color _cdPanelBorder(bool dark) => dark
      ? Colors.white10
      : Colors.black.withValues(alpha: 0.1);
  Color _cdHairline(bool dark) =>
      dark ? Colors.white24 : Colors.black26;
  Color _cdSidebarFill(bool dark) =>
      dark ? const Color(0xFF2A2A2A) : const Color(0xFFE6E6E8);
  Color _cdSidebarEdge(bool dark) => dark
      ? Colors.white12
      : Colors.black.withValues(alpha: 0.08);
  Color _cdIconHalo(bool dark) => dark
      ? Colors.white.withValues(alpha: 0.14)
      : Colors.black.withValues(alpha: 0.08);
  Color _cdSideItemLabel(bool dark, bool isActive) {
    if (isActive) return Colors.white;
    return dark
        ? Colors.white.withValues(alpha: 0.85)
        : _figmaLightText.withValues(alpha: 0.9);
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
                    child: Text(analysis, style: GoogleFonts.poppins()),
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
                Text(message, style: GoogleFonts.poppins()),
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
  // ignore: unused_element
  Widget _buildNavLink(
    String label, {
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color:
                isActive ? Colors.white : Colors.white.withValues(alpha: 0.85),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSideMenuItem({
    required String label,
    required String iconAsset,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 6),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFC10D00) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _cdIconHalo(isDark),
                shape: BoxShape.circle,
              ),
              child: _buildCircleAssetIcon(iconAsset, fallbackSize: 13),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: _cdSideItemLabel(isDark, isActive),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomMenuItem({
    required String label,
    required String iconAsset,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _cdIconHalo(isDark),
                shape: BoxShape.circle,
              ),
              child: _buildCircleAssetIcon(iconAsset, fallbackSize: 13),
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: _cdOnSurface(isDark),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideMenuHeader({required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Image.asset(
            'assets/icons/khono.png',
            height: 34.97,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: 8),
        SizedBox(
          width: 192.14,
          child: Column(
            children: [
              Text(
                'Welcome to',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: _cdOnSurfaceMuted(isDark),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Automated Recruitment Workflow',
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: _cdOnSurface(isDark),
                    fontSize: 11.2,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        SizedBox(
          width: 192.14,
          child: Container(height: 1, color: _cdHairline(isDark)),
        ),
      ],
    );
  }

  Widget _buildSideMenu({required bool isDark}) {
    return Container(
      width: _sideMenuWidth,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.fromLTRB(10, 14, 10, 8),
      decoration: BoxDecoration(
        color: _cdSidebarFill(isDark),
        border: Border(right: BorderSide(color: _cdSidebarEdge(isDark))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSideMenuHeader(isDark: isDark),
          SizedBox(height: 10),
          _buildSideMenuItem(
            label: 'Dashboard',
            iconAsset: 'assets/icons/Dashboard2.png',
            isActive: _activeSidebarItem == 'dashboard',
            isDark: isDark,
            onTap: _scrollToDashboardTop,
          ),
          _buildSideMenuItem(
            label: 'Applications',
            iconAsset: 'assets/icons/Applications_blue.png',
            isActive: _activeSidebarItem == 'applications',
            isDark: isDark,
            onTap: () {
              _safeSetState(() => _activeSidebarItem = 'applications');
              final initialApplications = _allApplications
                  .where((app) {
                    final status =
                        app['status']?.toString().toLowerCase().trim();
                    if (status == null || status.isEmpty) return false;
                    return status == 'applied' ||
                        status == 'assessment_submitted' ||
                        status == 'disqualified' ||
                        status.contains('offer');
                  })
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
              context.push(
                '/jobs-applied?token=${Uri.encodeComponent(widget.token)}',
                extra: initialApplications,
              );
            },
          ),
          _buildSideMenuItem(
            label: 'Assessments',
            iconAsset: 'assets/icons/Assessments.png',
            isActive: _activeSidebarItem == 'assessments',
            isDark: isDark,
            onTap: () {
              _safeSetState(() => _activeSidebarItem = 'assessments');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AssessmentResultsPage(token: widget.token),
                ),
              );
            },
          ),
          Spacer(),
          _buildBottomMenuItem(
            label: 'Account Profile',
            iconAsset: 'assets/icons/Profile2.png',
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfilePage(token: widget.token)),
              );
            },
          ),
          _buildBottomMenuItem(
            label: 'Logout',
            iconAsset: 'assets/icons/Logout.png',
            isDark: isDark,
            onTap: () => _showLogoutConfirmation(context),
          ),
        ],
      ),
    );
  }

  void _scrollToDashboardTop() {
    _safeSetState(() => _activeSidebarItem = 'dashboard');
    if (!_mainScrollController.hasClients) return;
    _mainScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  // ignore: unused_element
  Widget _buildJobCard(Map<String, dynamic> job) {
    return _buildJobTableRow(job);
  }

  Widget _buildJobTableHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
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
    final company = (job['company']?.toString().trim().isNotEmpty == true)
        ? (job['company'] ?? '')
        : '—';
    final location = (job['location']?.toString().trim().isNotEmpty == true)
        ? (job['location'] ?? '')
        : '—';
    final jobType = _formatJobType(
      job['type'] ?? job['employment_type'] ?? 'Full Time',
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.015),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
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
                    MaterialPageRoute(builder: (_) => JobDetailsPage(job: job)),
                  );
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Color(0xFF3A3A3A),
                  side: BorderSide(color: Colors.white38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text('Apply Now', style: GoogleFonts.poppins(color: Colors.white)),
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
    final jobId = job['id'];
    if (jobId == null) return false;
    final jid = _toIntId(jobId);
    if (jid == null) return false;
    for (final app in _allApplications) {
      final appJobId = app['job_id'] ??
          app['requisition_id'] ??
          app['jobId'] ??
          app['requisitionId'];
      if (_idsEqual(appJobId, jid)) return true;
    }
    return false;
  }

  List<Map<String, dynamic>> _getFilteredJobs(int typeIndex) {
    final typeFilter = _jobTypes[typeIndex];
    final byType = typeFilter == 'Featured'
        ? _jobs
        : _jobs.where((j) {
            final t = (j['type'] ?? j['employment_type'] ?? '')
                .toString()
                .toLowerCase();
            final loc = (j['location'] ?? '').toString().toLowerCase();
            if (typeFilter == 'Full Time')
              return t.contains('full') || t == 'full_time';
            if (typeFilter == 'Part Time')
              return t.contains('part') || t == 'part_time';
            if (typeFilter == 'Remote')
              return loc.contains('remote') || t.contains('remote');
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
  int _getFilteredJobsTotalCount(int typeIndex) =>
      _getFilteredJobs(typeIndex).length;

  // ignore: unused_element
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
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 32, left: 24, right: 24),
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
            // Glassmorphic container so it blends with the dark background.
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildJobTableHeader(),
                  ...paginatedJobs.map((job) {
                    final j = Map<String, dynamic>.from(job);
                    if (!j.containsKey('type') &&
                        j.containsKey('employment_type')) {
                      j['type'] = j['employment_type'];
                    }
                    return _buildJobTableRow(j);
                  }),
                ],
              ),
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
    final token = widget.token.isNotEmpty
        ? widget.token
        : await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      _showSignInToApplyDialog(job);
      return;
    }
    if (job['id'] == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid job.')));
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
              style: GoogleFonts.poppins(
                color: strokeColor,
                fontWeight: FontWeight.w600,
              ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Log in',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunitiesCards({required bool isDark}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildOpportunityCard(
              isDark: isDark,
              title: 'Applications',
              count: _applicationsCount != null ? '$_applicationsCount' : '—',
              iconAsset: 'assets/icons/Applications.png',
              onTap: () {
                final initialApplications = _allApplications
                    .where((app) {
                      final status = app['status']?.toString().toLowerCase().trim();
                      if (status == null || status.isEmpty) return false;
                      return status == 'applied' ||
                          status == 'assessment_submitted' ||
                          status == 'disqualified' ||
                          status.contains('offer');
                    })
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();
                context.push(
                  '/jobs-applied?token=${Uri.encodeComponent(widget.token)}',
                  extra: initialApplications,
                );
              },
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: _buildOpportunityCard(
              isDark: isDark,
              title: 'Interviews Scheduled',
              count: '$_interviewsScheduledCount',
              iconAsset: 'assets/icons/InterviewsScheduled.png',
              onTap: () {
                context.push(
                  '/my-interviews?token=${Uri.encodeComponent(widget.token)}',
                );
              },
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: _buildOpportunityCard(
              isDark: isDark,
              title: 'Saved Jobs',
              count: _savedCount != null ? '$_savedCount' : '—',
              iconAsset: 'assets/icons/SavedJobs.png',
              onTap: () {
                context.push(
                  '/saved-jobs?token=${Uri.encodeComponent(widget.token)}',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid job.')));
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
      if (res.statusCode == 201 &&
          data is Map &&
          data['application_id'] != null) {
        if (!mounted) return;
        await AuthService.clearPendingApplyJob();
        if (!mounted) return;
        _safeSetState(() => _pendingApplyJob = null);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RedirectToAssessmentPage(
              applicationId: data['application_id'] as int,
              jobTitle: job['title']?.toString(),
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
            const SnackBar(
              content: Text(
                'This application is already in your list. Refreshing.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                err.isNotEmpty ? err : 'Could not start application',
              ),
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data is Map
                  ? (data['error']?.toString() ?? 'Could not start application')
                  : 'Could not start application',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    if (diff.inDays > 0)
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    if (diff.inHours > 0)
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inMinutes > 0)
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
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
        final id =
            pendingId is int ? pendingId : int.tryParse(pendingId.toString());
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

  Widget _buildContinueYourApplicationSection({required bool isDark}) {
    final items = _getDeduplicatedContinueItems();
    final visible = items.take(2).toList();
    final continueCount = visible.length;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: _cdPanelBg(isDark),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _cdPanelBorder(isDark)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: Colors.white,
                  child: _buildCircleAssetIcon(
                    'assets/icons/ContinueApplication.png',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continue Application',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: _cdOnSurface(isDark),
                          height: 1.0,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Additional description can be included if required.',
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          color: _cdOnSurfaceMuted(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.white,
                  child: _buildCircleAssetIcon('assets/icons/Notifications.png'),
                ),
                SizedBox(width: 8),
                Text(
                  '$continueCount',
                  style: GoogleFonts.poppins(
                    color: _cdOnSurface(isDark),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Container(height: 1, color: _cdHairline(isDark)),
            SizedBox(height: 8),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _dashboardCountsLoaded
                        ? 'No applications in progress.'
                        : 'Loading your applications...',
                    style: GoogleFonts.poppins(
                      color: _cdOnSurfaceMuted(isDark),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ...visible.map(
              (item) {
                final status = _continueStatusForItem(item);
                final step = _stepFromItem(item);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 11,
                        height: 11,
                        color: _cdOnSurfaceMuted(isDark),
                      ),
                      SizedBox(width: 10),
                      SizedBox(
                        width: 300,
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: (item['job_title'] ?? item['job']?['title'] ?? 'Job')
                                    .toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _cdOnSurface(isDark),
                                ),
                              ),
                              TextSpan(
                                text: ' - Full Time',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: _cdOnSurfaceMuted(isDark),
                                ),
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: _buildStepDots(currentStep: step, isDark: isDark),
                        ),
                      ),
                      _buildStatusChip(status.$1, status.$2),
                      SizedBox(width: 8),
                      _buildMiniViewButton(),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedJobsSection({required bool isDark}) {
    final jobs = _getFilteredJobs(_currentTab).take(6).toList();
    final jobsCount = jobs.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        // Keep row actions clear of the bottom-right FAB stack (same width as one control).
        24 + _cornerActionSize + 20,
        0,
      ),
      child: Container(
        key: _jobsSectionKey,
        padding: EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: _cdPanelBg(isDark),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _cdPanelBorder(isDark)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: Colors.white,
                  child: _buildCircleAssetIcon('assets/icons/RecommendedJobs.png'),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended Jobs',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: _cdOnSurface(isDark),
                          height: 1.0,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Additional description can be included if required.',
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          color: _cdOnSurfaceMuted(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.white,
                  child: _buildCircleAssetIcon('assets/icons/Notifications.png'),
                ),
                SizedBox(width: 8),
                Text(
                  '$jobsCount',
                  style: GoogleFonts.poppins(
                    color: _cdOnSurface(isDark),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Container(height: 1, color: _cdHairline(isDark)),
            SizedBox(height: 8),
            if (jobs.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No jobs found.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _cdOnSurfaceMuted(isDark),
                  ),
                ),
              ),
            ...jobs.map(
              (job) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      color: _cdOnSurfaceMuted(isDark),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: (job['title'] ?? 'Job Name / Title').toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _cdOnSurface(isDark),
                              ),
                            ),
                            TextSpan(
                              text: ' - Full Time - Introductory Job Description & Requirement Detail for further insight prior to viewing more.',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: _cdOnSurfaceMuted(isDark),
                              ),
                            ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 10),
                    _buildMiniViewButton(),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _handleApplyNow(job),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: strokeColor,
                        foregroundColor: Colors.white,
                        minimumSize: Size(82, 28),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'APPLY NOW',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleAssetIcon(
    String assetPath, {
    double scale = 1.35,
    double fallbackSize = 14,
    Color fallbackColor = Colors.white,
  }) {
    return ClipOval(
      child: Transform.scale(
        // Crop transparent icon margins so the glyph fills the circle.
        scale: scale,
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Icon(
            Icons.image_outlined,
            size: fallbackSize,
            color: fallbackColor,
          ),
        ),
      ),
    );
  }

  (String, Color) _continueStatusForItem(Map<String, dynamic> item) {
    final type = item['type']?.toString().toLowerCase();
    if (type == 'pending') {
      return ('Pending Response', const Color(0xFFE2A321));
    }
    final status = item['status']?.toString().toLowerCase() ?? '';
    if (status.contains('interview') || status.contains('shortlist')) {
      return ('Interview Scheduled', const Color(0xFF3A89D6));
    }
    final progress = _stepFromItem(item);
    if (progress >= 4) {
      return ('Interview Scheduled', const Color(0xFF3A89D6));
    }
    return ('Pending Response', const Color(0xFFE2A321));
  }

  int _stepFromItem(Map<String, dynamic> item) {
    final type = item['type']?.toString().toLowerCase();
    if (type == 'pending') return 1;
    final draftData = item['draft_data'] is Map
        ? Map<String, dynamic>.from(item['draft_data'] as Map)
        : null;
    final lastSaved = item['last_saved_screen']?.toString();
    final percent = _progressPercent(draftData, lastSaved);
    final step = (percent / 20).ceil().clamp(1, 5);
    return step;
  }

  Widget _buildStepDots({required int currentStep, required bool isDark}) {
    return Row(
      children: List.generate(5, (i) {
        final active = (i + 1) <= currentStep;
        return Padding(
          padding: EdgeInsets.only(right: i == 4 ? 0 : 6),
          child: CircleAvatar(
            radius: 12,
            backgroundColor: active
                ? strokeColor
                : (isDark ? Colors.white : Colors.grey.shade300),
            child: Text(
              '${i + 1}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : Colors.black87,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMiniViewButton() {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF727576),
        foregroundColor: Colors.white,
        minimumSize: Size(50, 24),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        'VIEW',
        style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Estimate progress 0–100 from draft_data / last_saved_screen.
  int _progressPercent(
    Map<String, dynamic>? draftData,
    String? lastSavedScreen,
  ) {
    if (draftData == null || draftData.isEmpty)
      return lastSavedScreen != null ? 25 : 0;
    final screen = (lastSavedScreen ?? '').toString().toLowerCase();
    if (screen.contains('assessment')) {
      final assessment =
          draftData['assessment'] ?? draftData['assessment.assessment'];
      if (assessment is Map && assessment.isNotEmpty) return 75;
      return 50;
    }
    if (screen.isNotEmpty && screen != 'job_details') return 50;
    return 25;
  }

  // ignore: unused_element
  Widget _buildIncompleteApplicationCard(
    Map<String, dynamic> item, {
    bool compact = false,
  }) {
    final type = item['type'] as String?;
    String title;
    String statusLine;
    int progressPercent;
    VoidCallback? onContinue;

    if (type == 'pending') {
      final job = item['job'] as Map<String, dynamic>? ?? {};
      title = job['title']?.toString() ?? 'Job';
      statusLine = 'Not started';
      progressPercent = 8;
      onContinue = _continueWithApplication;
    } else {
      title = item['job_title']?.toString() ?? 'Application';
      final savedAt = item['saved_at']?.toString();
      final draftData = item['draft_data'] is Map
          ? Map<String, dynamic>.from(item['draft_data'] as Map)
          : null;
      final lastSaved = item['last_saved_screen']?.toString();
      progressPercent = _progressPercent(draftData, lastSaved);
      if (progressPercent == 0) progressPercent = 25;
      final timeAgo =
          savedAt != null && savedAt.isNotEmpty ? _timeAgo(savedAt) : null;
      if (timeAgo != null && timeAgo.isNotEmpty) {
        statusLine = 'In progress';
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
                  if (mounted)
                    _safeSetState(() => _navigatingToAssessment = false);
                  _fetchDashboardCounts();
                });
              });
            };
    }

    return Padding(
      padding: compact ? EdgeInsets.zero : EdgeInsets.only(bottom: 16),
      child: Container(
        height: compact ? double.infinity : null,
        padding: EdgeInsets.all(compact ? 18 : 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2126).withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24, width: 0.8),
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
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.0,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressPercent / 100,
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(strokeColor),
              ),
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.green.shade400,
                  ),
                ),
                Expanded(
                  child: Text(
                    statusLine,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: strokeColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 26, vertical: 12),
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
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
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
    required bool isDark,
    required String title,
    required String count,
    required String iconAsset,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 126,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: _cdPanelBg(isDark),
          border: Border.all(color: _cdPanelBorder(isDark)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Content
            Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      color: _cdOnSurface(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Additional description information can be included.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: _cdOnSurfaceMuted(isDark),
                      height: 1.0,
                    ),
                  ),
                  Spacer(),
                  Text(
                    count,
                    style: GoogleFonts.poppins(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: _cdOnSurface(isDark),
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              bottom: 10,
              right: 10,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: _buildCircleAssetIcon(
                  iconAsset,
                  fallbackColor: const Color(0xFFC10D00),
                  fallbackSize: 16,
                ),
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
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

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
            // Theme-aware background (same asset pipeline as hiring manager)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(themeProvider.backgroundImage),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: Row(
                children: [
                  _buildSideMenu(isDark: isDark),
                  Expanded(
                    child: CustomScrollView(
                      controller: _mainScrollController,
                      slivers: [
                        SliverAppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          automaticallyImplyLeading: false,
                          titleSpacing: 18,
                          title: Row(
                            children: [
                              Text(
                                'Candidate Dashboard',
                                style: GoogleFonts.poppins(
                                  color: _cdOnSurface(isDark),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                              ),
                              SizedBox(width: 18),
                              Expanded(
                                child: Text(
                                  'Hello, $_greetingName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: _cdOnSurface(isDark),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () => _showNotificationsDialog(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.white,
                                      child: _buildCircleAssetIcon(
                                        'assets/icons/Notifications.png',
                                      ),
                                    ),
                                  ),
                                ),
                                if (_unreadNotificationCount() > 0)
                                  Positioned(
                                    right: 2,
                                    top: 6,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: strokeColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        _unreadNotificationCount() > 99
                                            ? '99+'
                                            : _unreadNotificationCount().toString(),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(width: 24),
                          ],
                        ),

                        SliverToBoxAdapter(child: SizedBox(height: 6)),
                        SliverToBoxAdapter(
                          child: _buildOpportunitiesCards(isDark: isDark),
                        ),

                        // Continue Your Application section (always visible immediately after login)
                        SliverToBoxAdapter(
                          child: _buildContinueYourApplicationSection(
                            isDark: isDark,
                          ),
                        ),

                        // Recommended jobs in single rectangle layout
                        SliverToBoxAdapter(
                          child: _buildRecommendedJobsSection(isDark: isDark),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 24,
                              top: 8,
                              bottom: 14,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _cdPanelBg(isDark),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: _cdHairline(isDark)),
                                ),
                                child: Text(
                                  'Ver 2026.03.AI_STT',
                                  style: GoogleFonts.poppins(
                                    color: _cdOnSurfaceMuted(isDark),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
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
            Positioned(
              right: 12,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Tooltip(
                        message: 'Chat assistant',
                        child: Material(
                          color: Colors.transparent,
                          elevation: 0,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {},
                            splashColor: Colors.white24,
                            child: SizedBox(
                              width: _cornerActionSize,
                              height: _cornerActionSize,
                              child: Image.asset(
                                'assets/icons/chatbot.png',
                                width: _cornerActionSize,
                                height: _cornerActionSize,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: _cornerActionGap),
                      Tooltip(
                        message: themeProvider.isDarkMode
                            ? 'Switch to light mode'
                            : 'Switch to dark mode',
                        child: Material(
                          color: Colors.redAccent,
                          elevation: 2,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: themeProvider.toggleTheme,
                            child: SizedBox(
                              width: _cornerActionSize,
                              height: _cornerActionSize,
                              child: Icon(
                                themeProvider.isDarkMode
                                    ? Icons.light_mode
                                    : Icons.dark_mode,
                                color: Colors.white,
                                size: _cornerActionGlyph,
                              ),
                            ),
                          ),
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
    );
  }
}
