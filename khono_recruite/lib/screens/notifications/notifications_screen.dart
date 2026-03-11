import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/notification_service.dart';
import '../../providers/theme_provider.dart';

/// Shared notifications screen for Admin and Hiring Manager.
/// Notifications live in a separate file; API is via [NotificationService].
///
/// Optional [onNotificationTap] is called when the user taps a notification
/// (after marking it as read). Parent can use it to e.g. switch to interviews tab
/// or navigate to the relevant screen. [notification] includes id, message, type, interview_id, etc.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.onNotificationTap,
  });

  /// Called when user taps a notification (after marking as read). Pass the notification map.
  final void Function(Map<String, dynamic> notification)? onNotificationTap;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _loading = true;
  String? _errorMessage;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await NotificationService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = response.notifications;
        _unreadCount = response.unreadCount;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// Derive display title from backend type when title is missing.
  static String _titleFor(Map<String, dynamic> n) {
    final title = n['title']?.toString().trim();
    if (title != null && title.isNotEmpty) return title;
    switch (n['type']?.toString() ?? '') {
      case 'new_application':
        return 'New application';
      case 'new_candidate':
        return 'New candidate registered';
      case 'interview':
        return 'Interview update';
      case 'feedback_reminder':
        return 'Feedback reminder';
      case 'feedback_received':
        return 'Feedback received';
      case 'reminder':
        return 'Upcoming interview';
      case 'reminder_urgent':
        return 'Interview in 1 hour';
      case 'warning':
        return 'No-show';
      case 'status_update':
        return 'Status update';
      case 'info':
        return 'Update';
      default:
        return 'Notification';
    }
  }

  static String _typeFor(Map<String, dynamic> notification) =>
      (notification['type']?.toString() ?? 'info').trim().toLowerCase();

  static const List<String> _filters = <String>[
    'all',
    'unread',
    'applications',
    'candidates',
    'interviews',
  ];

  String _filterLabel(String filter) {
    switch (filter) {
      case 'unread':
        return 'Unread';
      case 'applications':
        return 'Applications';
      case 'candidates':
        return 'Candidates';
      case 'interviews':
        return 'Interviews';
      default:
        return 'All';
    }
  }

  IconData _iconFor(Map<String, dynamic> notification) {
    switch (_typeFor(notification)) {
      case 'new_application':
        return Icons.work_outline_rounded;
      case 'new_candidate':
        return Icons.person_add_alt_1_rounded;
      case 'interview':
        return Icons.event_available_rounded;
      case 'feedback_reminder':
        return Icons.rate_review_outlined;
      case 'feedback_received':
        return Icons.feedback_outlined;
      case 'reminder':
        return Icons.schedule_rounded;
      case 'reminder_urgent':
        return Icons.alarm_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'status_update':
        return Icons.sync_alt_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _accentColor(
      Map<String, dynamic> notification, ThemeProvider themeProvider) {
    switch (_typeFor(notification)) {
      case 'new_application':
        return themeProvider.isDarkMode
            ? Colors.lightBlueAccent
            : Colors.blue.shade700;
      case 'new_candidate':
        return themeProvider.isDarkMode
            ? Colors.tealAccent.shade200
            : Colors.teal.shade700;
      case 'interview':
      case 'reminder':
      case 'reminder_urgent':
        return themeProvider.isDarkMode
            ? Colors.orangeAccent.shade200
            : Colors.deepOrange.shade600;
      case 'warning':
        return themeProvider.isDarkMode
            ? Colors.amberAccent.shade200
            : Colors.orange.shade700;
      case 'feedback_reminder':
      case 'feedback_received':
        return themeProvider.isDarkMode
            ? Colors.purpleAccent.shade100
            : Colors.purple.shade600;
      default:
        return themeProvider.isDarkMode ? Colors.redAccent : Colors.blue.shade600;
    }
  }

  bool _matchesFilter(Map<String, dynamic> notification) {
    if (_selectedFilter == 'all') return true;
    if (_selectedFilter == 'unread') return notification['is_read'] != true;

    final type = _typeFor(notification);
    switch (_selectedFilter) {
      case 'applications':
        return type == 'new_application' || type == 'status_update';
      case 'candidates':
        return type == 'new_candidate';
      case 'interviews':
        return type == 'interview' ||
            type == 'feedback_reminder' ||
            type == 'feedback_received' ||
            type == 'reminder' ||
            type == 'reminder_urgent' ||
            type == 'warning';
      default:
        return true;
    }
  }

  List<Map<String, dynamic>> get _visibleNotifications =>
      _notifications.where(_matchesFilter).toList();

  String _formatCreatedAt(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _onTapNotification(Map<String, dynamic> n) async {
    final id = n['id'];
    if (id != null && (n['is_read'] != true)) {
      await NotificationService.markAsRead(id is int ? id : int.tryParse(id.toString()) ?? 0);
      if (mounted) {
        setState(() {
          final idx = _notifications.indexWhere((e) => e['id'] == id);
          if (idx >= 0) _notifications[idx] = {..._notifications[idx], 'is_read': true};
          if (_unreadCount > 0) _unreadCount--;
        });
      }
    }
    widget.onNotificationTap?.call(n);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final visibleNotifications = _visibleNotifications;
    final baseTheme = Theme.of(context);

    return Theme(
      data: baseTheme.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(baseTheme.textTheme),
        primaryTextTheme:
            GoogleFonts.poppinsTextTheme(baseTheme.primaryTextTheme),
        chipTheme: baseTheme.chipTheme.copyWith(
          labelStyle: GoogleFonts.poppins(fontSize: 12),
          secondaryLabelStyle: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(themeProvider.backgroundImage),
              fit: BoxFit.cover,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Notifications',
                    style: GoogleFonts.poppins(
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _unreadCount > 0
                        ? '$_unreadCount unread updates'
                        : 'Everything is up to date',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: themeProvider.isDarkMode
                          ? Colors.white70
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
              backgroundColor: (themeProvider.isDarkMode
                      ? const Color(0xFF14131E)
                      : Colors.white)
                  .withOpacity(0.9),
              elevation: 1,
              iconTheme: IconThemeData(
                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            body: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: themeProvider.isDarkMode
                          ? Colors.redAccent
                          : Colors.blue,
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: themeProvider.isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: _fetch,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _notifications.isEmpty
                        ? Center(
                            child: Text(
                              'No notifications',
                              style: GoogleFonts.poppins(
                                color: themeProvider.isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetch,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: visibleNotifications.isEmpty
                                  ? 2
                                  : visibleNotifications.length + 1,
                              itemBuilder: (_, index) {
                                if (index == 0) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        margin:
                                            const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: (themeProvider.isDarkMode
                                                  ? const Color(0xFF14131E)
                                                  : Colors.grey[100]!)
                                              .withOpacity(0.9),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: themeProvider.isDarkMode
                                                ? Colors.grey.shade800
                                                : Colors.grey[300]!,
                                          ),
                                        ),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: _filters
                                              .map(
                                                (filter) => ChoiceChip(
                                                  label: Text(
                                                    _filterLabel(filter),
                                                  ),
                                                  selected:
                                                      _selectedFilter == filter,
                                                  onSelected: (_) {
                                                    setState(() {
                                                      _selectedFilter = filter;
                                                    });
                                                  },
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                      if (visibleNotifications.isEmpty)
                                        Container(
                                          width: double.infinity,
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            color: (themeProvider.isDarkMode
                                                    ? const Color(0xFF14131E)
                                                    : Colors.grey[100]!)
                                                .withOpacity(0.9),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: themeProvider.isDarkMode
                                                  ? Colors.grey.shade800
                                                  : Colors.grey[300]!,
                                            ),
                                          ),
                                          child: Text(
                                            'No notifications match the ${_filterLabel(_selectedFilter).toLowerCase()} filter.',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(
                                              color: themeProvider.isDarkMode
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                }

                                if (visibleNotifications.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                final n = visibleNotifications[index - 1];
                                final isUnread = n['is_read'] != true;
                                final createdAt = n['created_at'] != null
                                    ? DateTime.tryParse(
                                        n['created_at'].toString(),
                                      )
                                    : null;
                                final accent = _accentColor(n, themeProvider);

                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: Duration(
                                    milliseconds: 500 + (index * 100),
                                  ),
                                  builder: (context, opacity, child) {
                                    return Opacity(
                                      opacity: opacity,
                                      child: Transform.translate(
                                        offset: Offset(0, (1 - opacity) * 20),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _onTapNotification(n),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: (themeProvider.isDarkMode
                                                  ? const Color(0xFF14131E)
                                                  : Colors.grey[100]!)
                                              .withOpacity(0.9),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isUnread
                                                ? accent.withOpacity(0.35)
                                                : (themeProvider.isDarkMode
                                                    ? Colors.grey.shade800
                                                    : Colors.grey[300]!),
                                          ),
                                          gradient: isUnread
                                              ? LinearGradient(
                                                  colors: [
                                                    accent.withOpacity(0.12),
                                                    Colors.transparent,
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : null,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 6,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              margin: const EdgeInsets.only(
                                                right: 12,
                                                top: 2,
                                              ),
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: accent.withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                _iconFor(n),
                                                color: accent,
                                                size: 22,
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _titleFor(n),
                                                    style: GoogleFonts.poppins(
                                                      color: themeProvider
                                                              .isDarkMode
                                                          ? Colors.white
                                                          : Colors.black,
                                                      fontWeight: isUnread
                                                          ? FontWeight.bold
                                                          : FontWeight.w600,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    crossAxisAlignment:
                                                        WrapCrossAlignment
                                                            .center,
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 4,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: accent
                                                              .withOpacity(
                                                                  0.12),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      999),
                                                        ),
                                                        child: Text(
                                                          _filterLabel(
                                                            _typeFor(n) ==
                                                                    'new_application'
                                                                ? 'applications'
                                                                : _typeFor(n) ==
                                                                        'new_candidate'
                                                                    ? 'candidates'
                                                                    : _typeFor(n) ==
                                                                                'interview' ||
                                                                            _typeFor(n) ==
                                                                                'feedback_reminder' ||
                                                                            _typeFor(n) ==
                                                                                'feedback_received' ||
                                                                            _typeFor(n) ==
                                                                                'reminder' ||
                                                                            _typeFor(n) ==
                                                                                'reminder_urgent' ||
                                                                            _typeFor(n) ==
                                                                                'warning'
                                                                        ? 'interviews'
                                                                        : 'all',
                                                          ),
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: accent,
                                                          ),
                                                        ),
                                                      ),
                                                      if (isUnread)
                                                        Container(
                                                          width: 8,
                                                          height: 8,
                                                          decoration:
                                                              const BoxDecoration(
                                                            color: Colors
                                                                .redAccent,
                                                            shape: BoxShape
                                                                .circle,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Text(
                                                    n['message']?.toString() ??
                                                        '',
                                                    style: GoogleFonts.poppins(
                                                      color: themeProvider
                                                              .isDarkMode
                                                          ? Colors.grey.shade400
                                                          : Colors.black87,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  if (createdAt != null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                        top: 10,
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        children: [
                                                          Text(
                                                            _formatCreatedAt(
                                                              createdAt,
                                                            ),
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontSize: 12,
                                                              color: themeProvider
                                                                      .isDarkMode
                                                                  ? Colors.grey
                                                                      .shade500
                                                                  : Colors.grey,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ),
      ),
    );
  }
}
