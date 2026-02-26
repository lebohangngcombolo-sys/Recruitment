import 'package:flutter/material.dart';
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

    return Scaffold(
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
            title: Text(
              'Notifications',
              style: TextStyle(
                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
              ),
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
                              style: TextStyle(
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
                            style: TextStyle(
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
                            itemCount: _notifications.length,
                            itemBuilder: (_, index) {
                              final n = _notifications[index];
                              final isUnread = n['is_read'] != true;
                              final createdAt = n['created_at'] != null
                                  ? DateTime.tryParse(n['created_at'].toString())
                                  : null;

                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: Duration(
                                    milliseconds: 500 + (index * 100)),
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
                                          vertical: 8),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: (themeProvider.isDarkMode
                                                ? const Color(0xFF14131E)
                                                : Colors.grey[100]!)
                                            .withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: themeProvider.isDarkMode
                                              ? Colors.grey.shade800
                                              : Colors.grey[300]!),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (isUnread)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  right: 10, top: 6),
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Colors.redAccent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _titleFor(n),
                                                  style: TextStyle(
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
                                                Text(
                                                  n['message']?.toString() ?? '',
                                                  style: TextStyle(
                                                    color: themeProvider
                                                            .isDarkMode
                                                        ? Colors.grey.shade400
                                                        : Colors.black87,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                if (createdAt != null)
                                                  Align(
                                                    alignment:
                                                        Alignment.bottomRight,
                                                    child: Padding(
                                                      padding: const EdgeInsets.only(
                                                          top: 8),
                                                      child: Text(
                                                        '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} '
                                                        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: themeProvider
                                                                  .isDarkMode
                                                              ? Colors.grey
                                                                  .shade500
                                                              : Colors.grey,
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
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                );
  }
}
