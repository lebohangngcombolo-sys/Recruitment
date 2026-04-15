import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../utils/api_endpoints.dart';

class HiringManagerService {
  final String _apiBase = ApiEndpoints.hmBase;
  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getAccessToken();
    return {
      ...headers,
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> getCandidatesWithDetails({
    int page = 1,
    int perPage = 20,
    String? search,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('$_apiBase/candidates/with-details')
        .replace(queryParameters: queryParams);
    final authHeaders = await _getAuthHeaders();
    final res = await http.get(uri, headers: authHeaders);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return List<Map<String, dynamic>>.from(data['candidates'] ?? []);
    }
    throw Exception('Failed to fetch candidates with details: ${res.body}');
  }

  Future<Map<String, dynamic>> getUpcomingMeetings({
    int limit = 100,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = {
      'limit': limit.toString(),
    };
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;

    final uri = Uri.parse('$_apiBase/meetings/upcoming')
        .replace(queryParameters: queryParams);
    final authHeaders = await _getAuthHeaders();
    final res = await http.get(uri, headers: authHeaders);

    if (res.statusCode == 200) {
      return json.decode(res.body);
    }
    throw Exception('Failed to fetch upcoming meetings: ${res.body}');
  }

  Future<List<Map<String, dynamic>>> getInterviewsForCalendar({
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;

    final uri = Uri.parse('$_apiBase/interviews/calendar')
        .replace(queryParameters: queryParams);
    final authHeaders = await _getAuthHeaders();
    final res = await http.get(uri, headers: authHeaders);

    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(res.body));
    }
    throw Exception('Failed to fetch interviews for calendar: ${res.body}');
  }

  Future<Map<String, dynamic>> getDashboardCounts() async {
    final uri = Uri.parse('$_apiBase/dashboard-counts');
    final authHeaders = await _getAuthHeaders();
    final res = await http.get(uri, headers: authHeaders);

    if (res.statusCode == 200) {
      return json.decode(res.body);
    }
    throw Exception('Failed to fetch dashboard counts: ${res.body}');
  }

  Future<Map<String, dynamic>> downloadCandidateCV(int candidateId) async {
    final uri = Uri.parse(ApiEndpoints.getCandidateCvDownload(candidateId));
    final authHeaders = await _getAuthHeaders();
    final res = await http.get(uri, headers: authHeaders);

    if (res.statusCode == 200) {
      return json.decode(res.body);
    }
    throw Exception('Failed to download CV: ${res.body}');
  }

  Future<Map<String, dynamic>> getCVReviews({
    int page = 1,
    int perPage = 200,
    String? scope,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (scope != null) queryParams['scope'] = scope;

    final uri =
        Uri.parse(ApiEndpoints.cvReviews).replace(queryParameters: queryParams);
    final authHeaders = await _getAuthHeaders();
    final res = await http.get(uri, headers: authHeaders);

    if (res.statusCode == 200) {
      return json.decode(res.body);
    }
    throw Exception('Failed to fetch CV reviews: ${res.body}');
  }
}
