import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import 'auth_service.dart';

/// Unified API service with role-based endpoint selection
/// This prevents authorization errors by ensuring users access correct endpoints based on their role
class UnifiedApiService {
  // Get current user role for endpoint selection
  static Future<String> _getCurrentUserRole() async {
    try {
      // First try to get from user info
      final userInfo = await AuthService.getUserInfo();
      String? role = userInfo?['role']?.toString();
      
      // If not in user info, try stored role
      if (role == null || role.isEmpty) {
        role = await AuthService.getRole();
      }
      
      return role?.isNotEmpty == true ? role! : 'candidate';
    } catch (e) {
      // Default to candidate if role cannot be determined
      return 'candidate';
    }
  }

  // Role-based endpoint selection for jobs
  static Future<String> getJobsEndpoint() async {
    final role = await _getCurrentUserRole();
    switch (role) {
      case 'admin':
      case 'hiring_manager':
        return ApiEndpoints.adminJobs;
      case 'candidate':
        return ApiEndpoints.getAvailableJobs;
      default:
        throw Exception('Invalid user role: $role');
    }
  }

  // Role-based endpoint selection for applications
  static Future<String> getApplicationsEndpoint() async {
    final role = await _getCurrentUserRole();
    switch (role) {
      case 'admin':
      case 'hiring_manager':
        return ApiEndpoints.getCandidateApplications;
      case 'candidate':
        return ApiEndpoints.getApplications;
      default:
        throw Exception('Invalid user role: $role');
    }
  }

  // Role-based endpoint selection for notifications
  static Future<String> getNotificationsEndpoint() async {
    final role = await _getCurrentUserRole();
    switch (role) {
      case 'admin':
      case 'hiring_manager':
        return ApiEndpoints.getNotifications;
      case 'candidate':
        return ApiEndpoints.getCandidateNotifications;
      default:
        throw Exception('Invalid user role: $role');
    }
  }

  // Role-based endpoint selection for dashboard counts
  static Future<String> getDashboardCountsEndpoint() async {
    final role = await _getCurrentUserRole();
    switch (role) {
      case 'admin':
      case 'hiring_manager':
        return ApiEndpoints.getDashboardCounts;
      case 'candidate':
        throw Exception('Dashboard counts not available for candidates');
      default:
        throw Exception('Invalid user role: $role');
    }
  }

  // Unified method to get jobs with proper error handling
  static Future<List<Map<String, dynamic>>> getJobs() async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('User not authenticated');
      }

      final endpoint = await getJobsEndpoint();
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
        if (data is Map<String, dynamic>) {
          final jobs = data['jobs'] ?? data['data'] ?? data['results'];
          if (jobs is List) {
            return jobs
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
          }
        }
        return [];
      } else if (response.statusCode == 401) {
        // Try token refresh
        final newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          return getJobs(); // Retry with new token
        }
        throw Exception('Session expired. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('You do not have permission to access jobs.');
      } else {
        throw Exception('Failed to fetch jobs: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching jobs: $e');
    }
  }

  // Unified method to get jobs with explicit token
  static Future<List<Map<String, dynamic>>> getJobsWithToken(String token) async {
    try {
      if (token.isEmpty) {
        throw Exception('User not authenticated');
      }

      final endpoint = await getJobsEndpoint();
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
        if (data is Map<String, dynamic>) {
          final jobs = data['jobs'] ?? data['data'] ?? data['results'];
          if (jobs is List) {
            return jobs
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
          }
        }
        return [];
      } else if (response.statusCode == 401) {
        // Try token refresh
        final newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          return getJobsWithToken(newToken); // Retry with new token
        }
        throw Exception('Session expired. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('You do not have permission to access jobs.');
      } else {
        throw Exception('Failed to fetch jobs: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching jobs: $e');
    }
  }

  // Unified method to get applications with proper error handling
  static Future<List<dynamic>> getApplications() async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('User not authenticated');
      }

      final endpoint = await getApplicationsEndpoint();
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<dynamic>.from(data);
        }
        if (data is Map<String, dynamic>) {
          final applications =
              data['applications'] ?? data['data'] ?? data['results'];
          if (applications is List) {
            return List<dynamic>.from(applications);
          }
        }
        return [];
      } else if (response.statusCode == 401) {
        // Try token refresh
        final newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          return getApplications(); // Retry with new token
        }
        throw Exception('Session expired. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('You do not have permission to access applications.');
      } else {
        throw Exception('Failed to fetch applications: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching applications: $e');
    }
  }

  // Unified method to get notifications with proper error handling
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('User not authenticated');
      }

      final endpoint = await getNotificationsEndpoint();
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
        if (data is Map<String, dynamic>) {
          final notifications =
              data['notifications'] ?? data['data'] ?? data['results'];
          if (notifications is List) {
            return notifications
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
          }
        }
        return [];
      } else if (response.statusCode == 401) {
        // Try token refresh
        final newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          return getNotifications(); // Retry with new token
        }
        throw Exception('Session expired. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('You do not have permission to access notifications.');
      } else {
        throw Exception(
            'Failed to fetch notifications: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching notifications: $e');
    }
  }

  // Unified method to get notifications with explicit token
  static Future<List<Map<String, dynamic>>> getNotificationsWithToken(String token) async {
    try {
      if (token.isEmpty) {
        throw Exception('User not authenticated');
      }

      final endpoint = await getNotificationsEndpoint();
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
        if (data is Map<String, dynamic>) {
          final notifications =
              data['notifications'] ?? data['data'] ?? data['results'];
          if (notifications is List) {
            return notifications
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
          }
        }
        return [];
      } else {
        throw Exception('Failed to fetch notifications: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching notifications: $e');
    }
  }

  /// Mark one notification as read (candidate vs admin/HM endpoint).
  static Future<void> markNotificationRead(int notificationId) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('User not authenticated');
      }
      final role = await _getCurrentUserRole();
      final url = role == 'candidate'
          ? ApiEndpoints.markCandidateNotificationRead(notificationId)
          : ApiEndpoints.markNotificationRead(notificationId);

      Future<http.Response> send() async {
        return http.patch(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }

      var response = await send();
      if (response.statusCode == 200) return;

      if (response.statusCode == 401) {
        final newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          response = await http.patch(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $newToken',
            },
          );
          if (response.statusCode == 200) return;
        }
        throw Exception('Session expired. Please log in again.');
      }
      throw Exception(
        'Failed to mark notification read: ${response.statusCode}',
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error marking notification read: $e');
    }
  }

  // Unified method to get dashboard counts with proper error handling
  static Future<Map<String, dynamic>> getDashboardCounts() async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('User not authenticated');
      }

      final endpoint = await getDashboardCountsEndpoint();
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        }
        return {};
      } else if (response.statusCode == 401) {
        // Try token refresh
        final newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          return getDashboardCounts(); // Retry with new token
        }
        throw Exception('Session expired. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception(
            'You do not have permission to access dashboard counts.');
      } else {
        throw Exception(
            'Failed to fetch dashboard counts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching dashboard counts: $e');
    }
  }

  // Generic authorized request method with token refresh
  static Future<http.Response> makeAuthorizedRequest(
    String method,
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('User not authenticated');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        ...?additionalHeaders,
      };

      late http.Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(Uri.parse(url), headers: headers);
          break;
        case 'POST':
          response = await http.post(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          response = await http.put(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(Uri.parse(url), headers: headers);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      // Handle 401 with token refresh
      if (response.statusCode == 401) {
        final newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          // Retry with new token
          return makeAuthorizedRequest(method, url,
              body: body, additionalHeaders: additionalHeaders);
        }
        throw Exception('Session expired. Please log in again.');
      }

      return response;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Request failed: $e');
    }
  }
}
