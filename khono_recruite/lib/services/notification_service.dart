import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import 'auth_service.dart';

/// Response from GET /api/admin/notifications/<user_id>
class NotificationsResponse {
  final int userId;
  final int unreadCount;
  final List<Map<String, dynamic>> notifications;

  NotificationsResponse({
    required this.userId,
    required this.unreadCount,
    required this.notifications,
  });
}

/// Service for Admin/Hiring Manager notifications (list, mark read).
/// All API calls use the admin notifications endpoints.
class NotificationService {
  /// Fetches notifications for the current user. Uses AuthService.getUserId() and JWT.
  static Future<NotificationsResponse> getNotifications() async {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required');
    }
    final userId = await AuthService.getUserId();
    final res = await http.get(
      Uri.parse('${ApiEndpoints.getNotifications}/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 403) {
      throw Exception('You can only view your own notifications');
    }
    if (res.statusCode == 404) {
      throw Exception('User not found');
    }
    if (res.statusCode != 200) {
      final body = _tryDecode(res.body);
      final msg = body is Map
          ? (body['error'] ?? body['message'] ?? res.body)
          : res.body;
      throw Exception(msg.toString());
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['notifications'];
    final notifications = list is List
        ? list.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    final unreadCount =
        (body['unread_count'] is int) ? body['unread_count'] as int : 0;

    return NotificationsResponse(
      userId: (body['user_id'] is int) ? body['user_id'] as int : userId,
      unreadCount: unreadCount,
      notifications: notifications,
    );
  }

  /// Marks a single notification as read. User can only mark their own.
  static Future<void> markAsRead(int notificationId) async {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) return;

    final res = await http.patch(
      Uri.parse(ApiEndpoints.markNotificationRead(notificationId)),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 403 || res.statusCode == 404) {
      // Silently ignore; item may already be read or not owned
      return;
    }
    if (res.statusCode != 200) {
      // Don't throw; best-effort mark as read
      return;
    }
  }

  /// Marks all notifications as read for the current user.
  static Future<int> markAllAsRead() async {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required');
    }

    final res = await http.patch(
      Uri.parse('${ApiEndpoints.adminBase}/notifications/mark-all-read'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 403) {
      throw Exception('Forbidden: you can only mark your own notifications');
    }
    if (res.statusCode != 200) {
      final body = _tryDecode(res.body);
      final msg = body is Map
          ? (body['error'] ?? body['message'] ?? res.body)
          : res.body;
      throw Exception(msg.toString());
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['marked_count'] ?? 0;
  }

  /// Deletes all notifications for the current user.
  static Future<int> deleteAll() async {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required');
    }

    final res = await http.delete(
      Uri.parse('${ApiEndpoints.adminBase}/notifications/delete-all'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 403) {
      throw Exception('Forbidden: you can only delete your own notifications');
    }
    if (res.statusCode != 200) {
      final body = _tryDecode(res.body);
      final msg = body is Map
          ? (body['error'] ?? body['message'] ?? res.body)
          : res.body;
      throw Exception(msg.toString());
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['deleted_count'] ?? 0;
  }

  static dynamic _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }
}
