import 'dart:convert' as convert;
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import 'auth_service.dart';

class _SafeJson {
  const _SafeJson();

  dynamic decode(String body) {
    try {
      return convert.jsonDecode(body);
    } catch (_) {
      final trimmed = body.trimLeft();
      if (trimmed.startsWith('[')) {
        return [];
      }
      return {};
    }
  }

  String encode(Object? value) => convert.jsonEncode(value);
}

const json = _SafeJson();
dynamic jsonDecode(String body) => json.decode(body);
String jsonEncode(Object? value) => convert.jsonEncode(value);

class AdminService {
  final Map<String, String> headers = {'Content-Type': 'application/json'};

  // ---------- JOBS ----------
  // ========== ENHANCED JOB METHODS (ADD THESE) ==========

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getAccessToken();
    return {
      ...headers,
      'Authorization': 'Bearer $token',
    };
  }

  // Enhanced listJobs with filtering
  // In AdminService class
  Future<Map<String, dynamic>> listJobsEnhanced({
    int page = 1,
    int perPage = 20,
    String? category,
    String status = 'active',
    String sortBy = 'created_at',
    String sortOrder = 'desc',
    String? search,
  }) async {
    final authHeaders = await _getAuthHeaders();

    final queryParams = {
      'page': page.toString(),
      'per_page': perPage.toString(),
      'status': status,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    };

    if (category != null) queryParams['category'] = category;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri =
        Uri.parse(ApiEndpoints.adminJobs).replace(queryParameters: queryParams);

    final res = await http.get(uri, headers: authHeaders);

    if (res.statusCode == 200) {
      return json.decode(res.body); // This should return Map<String, dynamic>
    } else {
      final error = json.decode(res.body);
      throw Exception('Failed to load jobs: ${error['error'] ?? res.body}');
    }
  }

  // Get job with detailed statistics
  Future<Map<String, dynamic>> getJobDetailed(int jobId) async {
    final authHeaders = await _getAuthHeaders();
    final res = await http.get(
      Uri.parse('${ApiEndpoints.adminJobs}/$jobId/detailed'),
      headers: authHeaders,
    );

    if (res.statusCode == 200) {
      return json.decode(res.body);
    } else {
      final error = json.decode(res.body);
      throw Exception(
          'Failed to get job details: ${error['error'] ?? res.body}');
    }
  }

  // Restore soft-deleted job
  Future<void> restoreJob(int jobId) async {
    final authHeaders = await _getAuthHeaders();
    final res = await http.post(
      Uri.parse('${ApiEndpoints.adminJobs}/$jobId/restore'),
      headers: authHeaders,
    );

    if (res.statusCode != 200) {
      final error = json.decode(res.body);
      throw Exception('Failed to restore job: ${error['error'] ?? res.body}');
    }
  }

  // Get job activity logs
  Future<List<dynamic>> getJobActivity(int jobId,
      {int page = 1, int perPage = 50}) async {
    final authHeaders = await _getAuthHeaders();

    final queryParams = {
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    final uri = Uri.parse('${ApiEndpoints.adminJobs}/$jobId/activity')
        .replace(queryParameters: queryParams);

    final res = await http.get(uri, headers: authHeaders);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return data['activities'] ?? [];
    } else {
      final error = json.decode(res.body);
      throw Exception(
          'Failed to get job activity: ${error['error'] ?? res.body}');
    }
  }

  // Get job applications
  Future<List<dynamic>> getJobApplications(
    int jobId, {
    int page = 1,
    int perPage = 20,
    String? status,
  }) async {
    final authHeaders = await _getAuthHeaders();

    final queryParams = {
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    if (status != null) queryParams['status'] = status;

    final uri = Uri.parse('${ApiEndpoints.adminJobs}/$jobId/applications')
        .replace(queryParameters: queryParams);

    final res = await http.get(uri, headers: authHeaders);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return data['applications'] ?? [];
    } else {
      final error = json.decode(res.body);
      throw Exception(
          'Failed to get job applications: ${error['error'] ?? res.body}');
    }
  }

  // Get job statistics
  Future<Map<String, dynamic>> getJobStatistics() async {
    final authHeaders = await _getAuthHeaders();
    final res = await http.get(
      Uri.parse('${ApiEndpoints.adminJobs}/stats'),
      headers: authHeaders,
    );

    if (res.statusCode == 200) {
      return json.decode(res.body);
    } else {
      final error = json.decode(res.body);
      throw Exception(
          'Failed to get job statistics: ${error['error'] ?? res.body}');
    }
  }

  // Update job status (activate/deactivate)
  Future<void> updateJobStatus(int jobId, bool isActive) async {
    final authHeaders = await _getAuthHeaders();
    final data = {'is_active': isActive};

    final res = await http.put(
      Uri.parse('${ApiEndpoints.adminJobs}/$jobId'),
      headers: authHeaders,
      body: json.encode(data),
    );

    if (res.statusCode != 200) {
      final error = json.decode(res.body);
      throw Exception(
          'Failed to update job status: ${error['error'] ?? res.body}');
    }
  }

  // Create job with full data (enhanced version)
  Future<Map<String, dynamic>> createJobEnhanced(
      Map<String, dynamic> data) async {
    final authHeaders = await _getAuthHeaders();
    final res = await http.post(
      Uri.parse(ApiEndpoints.adminJobs),
      headers: authHeaders,
      body: json.encode(data),
    );

    if (res.statusCode == 201) {
      return json.decode(res.body);
    } else {
      Map<String, dynamic> body = {};
      try {
        if (res.body.isNotEmpty) body = json.decode(res.body);
      } catch (_) {}
      final error = body['error'] ?? 'Failed to create job';
      final details = body['details'];
      final msg = details != null
          ? '$error: ${details is Map ? details.entries.map((e) => '${e.key}: ${e.value}').join('; ') : details}'
          : error.toString();
      throw Exception(msg);
    }
  }

  // Update job with full data (enhanced version)
  Future<Map<String, dynamic>> updateJobEnhanced(
      int jobId, Map<String, dynamic> data) async {
    final authHeaders = await _getAuthHeaders();
    final res = await http.put(
      Uri.parse('${ApiEndpoints.adminJobs}/$jobId'),
      headers: authHeaders,
      body: json.encode(data),
    );

    if (res.statusCode == 200) {
      return json.decode(res.body);
    } else {
      final error = json.decode(res.body);
      throw Exception('Failed to update job: ${error['error'] ?? res.body}');
    }
  }

  Future<List<dynamic>> listJobs() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.adminJobs),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data is List) {
        return data;
      }
      if (data is Map<String, dynamic>) {
        return List<dynamic>.from(data['jobs'] ?? []);
      }
      return [];
    }
    throw Exception('Failed to load jobs: ${res.body}');
  }

  Future<Map<String, dynamic>> createJob(Map<String, dynamic> data) async {
    final token = await AuthService.getAccessToken();
    final res = await http.post(
      Uri.parse(ApiEndpoints.adminJobs),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );
    if (res.statusCode == 201) return json.decode(res.body);
    Map<String, dynamic> body = {};
    try {
      if (res.body.isNotEmpty) body = json.decode(res.body);
    } catch (_) {}
    final error = body['error'] ?? 'Failed to create job';
    final details = body['details'];
    final msg = details != null
        ? '$error: ${details is Map ? details.entries.map((e) => '${e.key}: ${e.value}').join('; ') : details}'
        : (body['message'] ?? error).toString();
    throw Exception(msg);
  }

  Future<Map<String, dynamic>> updateJob(
      int jobId, Map<String, dynamic> data) async {
    final token = await AuthService.getAccessToken();
    final res = await http.put(
      Uri.parse('${ApiEndpoints.adminJobs}/$jobId'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );
    if (res.statusCode == 200) return json.decode(res.body);
    throw Exception('Failed to update job: ${res.body}');
  }

  Future<void> deleteJob(int jobId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.delete(
      Uri.parse('${ApiEndpoints.adminJobs}/$jobId'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200)
      throw Exception('Failed to delete job: ${res.body}');
  }

  // ---------- CANDIDATES ----------
  Future<List<dynamic>> listCandidates() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse('${ApiEndpoints.adminBase}/candidates'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) return json.decode(res.body);
    throw Exception('Failed to fetch candidates: ${res.body}');
  }

  Future<Map<String, dynamic>> getApplication(int applicationId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse('${ApiEndpoints.adminBase}/applications/$applicationId'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) return json.decode(res.body);
    throw Exception('Failed to fetch application: ${res.body}');
  }

  /// All applications for a candidate with job details (title, company, employment_type).
  Future<List<Map<String, dynamic>>> getCandidateApplications(int candidateId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.getCandidateApplicationsByCandidateId(candidateId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return List<Map<String, dynamic>>.from(data['applications'] ?? []);
    }
    throw Exception('Failed to fetch candidate applications: ${res.body}');
  }

  Future<List<Map<String, dynamic>>> getApplications() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse('${ApiEndpoints.adminBase}/applications'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch applications: ${res.body}');
  }

  Future<List<dynamic>> shortlistCandidates(int jobId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse('${ApiEndpoints.adminJobs}/$jobId/shortlist'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) return json.decode(res.body);
    throw Exception('Failed to fetch shortlisted candidates: ${res.body}');
  }

  Future<List<Map<String, dynamic>>> getAllApplications() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse('${ApiEndpoints.adminBase}/applications/all'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch applications: ${res.body}');
  }

  // ---------- INTERVIEWS ----------
  Future<Map<String, dynamic>> scheduleInterview(
      Map<String, dynamic> data) async {
    final token = await AuthService.getAccessToken();
    final res = await http.post(
      Uri.parse('${ApiEndpoints.adminJobs}/interviews'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );
    if (res.statusCode == 201) return json.decode(res.body);
    throw Exception('Failed to schedule interview: ${res.body}');
  }

  Future<List<Map<String, dynamic>>> getAllInterviews() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse("${ApiEndpoints.adminBase}/interviews"),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    } else {
      throw Exception("Failed to fetch interviews: ${res.body}");
    }
  }

  Future<void> cancelInterview(int interviewId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.delete(
      Uri.parse("${ApiEndpoints.adminBase}/interviews/$interviewId"),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200)
      throw Exception("Failed to cancel interview: ${res.body}");
  }

  // ---------- CANDIDATE INTERVIEWS ----------
  /// Get all interviews for a specific candidate
  Future<List<Map<String, dynamic>>> getCandidateInterviews(
      int candidateId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(
          "${ApiEndpoints.adminBase}/interviews?candidate_id=$candidateId"),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(res.body));
    } else {
      throw Exception("Failed to fetch candidate interviews: ${res.body}");
    }
  }

  Future<Map<String, dynamic>> getDashboardCounts() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse("${ApiEndpoints.adminBase}/dashboard-counts"),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    } else {
      throw Exception("Failed to fetch dashboard counts: ${res.body}");
    }
  }

  /// Schedule a new interview for a candidate
  Future<Map<String, dynamic>> scheduleInterviewForCandidate({
    required int candidateId,
    required int applicationId,
    required DateTime scheduledTime,
  }) async {
    final token = await AuthService.getAccessToken();
    final data = {
      "candidate_id": candidateId,
      "application_id": applicationId,
      "scheduled_time": scheduledTime.toIso8601String(),
    };
    final res = await http.post(
      Uri.parse("${ApiEndpoints.adminJobs}/interviews"),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );
    if (res.statusCode == 201) return json.decode(res.body);
    throw Exception("Failed to schedule interview: ${res.body}");
  }

  // ---------- NOTIFICATIONS ----------
  Future<List<Map<String, dynamic>>> getNotifications(int userId) async {
    // Get the saved access token
    final token = await AuthService.getAccessToken();
    if (token == null) {
      throw Exception('User not authenticated');
    }

    // Define headers
    final Map<String, String> requestHeaders = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    // Make GET request
    final res = await http.get(
      Uri.parse("${ApiEndpoints.adminBase}/notifications/$userId"),
      headers: requestHeaders,
    );

    if (res.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(res.body);

      // Extract the list from 'notifications' key
      final List<dynamic> notificationsList = data['notifications'] ?? [];

      return notificationsList
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      throw Exception('Failed to fetch notifications: ${res.body}');
    }
  }

  // ---------- CV REVIEWS ----------
  Future<List<Map<String, dynamic>>> listCVReviews() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse('${ApiEndpoints.adminBase}/cv-reviews'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(res.body));
    }
    throw Exception('Failed to fetch CV reviews: ${res.body}');
  }

// ---------- ASSESSMENTS ----------
  Future<Map<String, dynamic>> updateAssessment(
      int jobId, Map<String, dynamic> data) async {
    final token = await AuthService.getAccessToken();
    final res = await http.put(
      Uri.parse('${ApiEndpoints.adminJobs}/$jobId/assessment'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(data),
    );

    if (res.statusCode == 200) return json.decode(res.body);
    throw Exception('Failed to update assessment: ${res.body}');
  }

  // ---------- ANALYTICS ----------
  Future<Map<String, dynamic>> getDashboardStats() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse('${ApiEndpoints.adminBase}/analytics/dashboard'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) return json.decode(res.body);
    throw Exception('Failed to load dashboard stats: ${res.body}');
  }

  Future<Map<String, dynamic>> getUsersGrowth({int days = 30}) async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse('${ApiEndpoints.adminBase}/analytics/users-growth?days=$days'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) return json.decode(res.body);
    throw Exception('Failed to load users growth data: ${res.body}');
  }

  Future<Map<String, dynamic>> getApplicationsAnalysis() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse('${ApiEndpoints.adminBase}/analytics/applications-analysis'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) return json.decode(res.body);
    throw Exception('Failed to load applications analysis: ${res.body}');
  }

  Future<Map<String, dynamic>> getInterviewsAnalysis() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse('${ApiEndpoints.adminBase}/analytics/interviews-analysis'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) return json.decode(res.body);
    throw Exception('Failed to load interviews analysis: ${res.body}');
  }

  Future<Map<String, dynamic>> getAssessmentsAnalysis() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse('${ApiEndpoints.adminBase}/analytics/assessments-analysis'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) return json.decode(res.body);
    throw Exception('Failed to load assessments analysis: ${res.body}');
  }

  // ---------- SHARED NOTES ----------
  Future<Map<String, dynamic>> createNote(Map<String, dynamic> data) async {
    final token = await AuthService.getAccessToken();
    final res = await http.post(
      Uri.parse(ApiEndpoints.createNote),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );
    if (res.statusCode == 201) return json.decode(res.body);
    throw Exception('Failed to create note: ${res.body}');
  }

  Future<Map<String, dynamic>> getNotes({
    int page = 1,
    int perPage = 20,
    String? search,
    int? authorId,
  }) async {
    final token = await AuthService.getAccessToken();

    // Build query parameters
    final params = {
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (authorId != null) 'author_id': authorId.toString(),
    };

    final uri =
        Uri.parse(ApiEndpoints.getNotes).replace(queryParameters: params);
    final res = await http.get(
      uri,
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) return json.decode(res.body);
    throw Exception('Failed to fetch notes: ${res.body}');
  }

  Future<Map<String, dynamic>> getNoteById(int noteId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse('${ApiEndpoints.getNoteById}/$noteId'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) return json.decode(res.body);
    throw Exception('Failed to fetch note: ${res.body}');
  }

  Future<Map<String, dynamic>> updateNote(
      int noteId, Map<String, dynamic> data) async {
    final token = await AuthService.getAccessToken();
    final res = await http.put(
      Uri.parse('${ApiEndpoints.updateNote}/$noteId'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );
    if (res.statusCode == 200) return json.decode(res.body);
    throw Exception('Failed to update note: ${res.body}');
  }

  Future<void> deleteNote(int noteId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.delete(
      Uri.parse('${ApiEndpoints.deleteNote}/$noteId'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to delete note: ${res.body}');
    }
  }

// Note: The shareNote endpoint was removed as sharing is handled via participants in the backend
// If you need sharing functionality, you'll need to update the backend or handle it differently

// ---------- MEETINGS ----------
  Future<Map<String, dynamic>> createMeeting(Map<String, dynamic> data) async {
    final token = await AuthService.getAccessToken();
    final res = await http.post(
      Uri.parse(ApiEndpoints.createMeeting),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );

    if (res.statusCode == 201) {
      return json.decode(res.body);
    } else {
      // Try to parse error message from response
      try {
        final errorBody = json.decode(res.body);
        throw Exception(
            errorBody['error'] ?? 'Failed to create meeting: ${res.body}');
      } catch (e) {
        throw Exception('Failed to create meeting: ${res.body}');
      }
    }
  }

  Future<Map<String, dynamic>> getMeetings({
    int page = 1,
    int perPage = 20,
    String? status,
    String? search,
  }) async {
    final token = await AuthService.getAccessToken();

    final params = {
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final uri =
        Uri.parse(ApiEndpoints.getMeetings).replace(queryParameters: params);
    final res = await http.get(
      uri,
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final body = json.decode(res.body);
      return {
        "meetings": body["meetings"] ?? [],
        "total": body["total"] ?? 0,
        "pages": body["pages"] ?? 0,
        "current_page": body["current_page"] ?? page,
        "per_page": body["per_page"] ?? perPage,
      };
    } else {
      throw Exception('Failed to fetch meetings: ${res.body}');
    }
  }

  Future<Map<String, dynamic>> getMeetingById(int meetingId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse('${ApiEndpoints.getMeetingById}/$meetingId'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> updateMeeting(
      int meetingId, Map<String, dynamic> data) async {
    final token = await AuthService.getAccessToken();
    final res = await http.put(
      Uri.parse('${ApiEndpoints.updateMeeting}/$meetingId'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );
    return _handleResponse(res);
  }

  Future<void> cancelMeeting(int meetingId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.post(
      Uri.parse('${ApiEndpoints.cancelMeeting}/$meetingId'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to cancel meeting: ${res.body}');
    }
  }

  Future<void> deleteMeeting(int meetingId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.delete(
      Uri.parse('${ApiEndpoints.deleteMeeting}/$meetingId'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to delete meeting: ${res.body}');
    }
  }

  Future<Map<String, dynamic>> getUpcomingMeetings({int limit = 5}) async {
    final token = await AuthService.getAccessToken();
    final uri = Uri.parse(ApiEndpoints.getUpcomingMeetings).replace(
      queryParameters: {'limit': limit.toString()},
    );
    final res = await http.get(
      uri,
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );
    final body = _handleResponse(res);
    return {"meetings": body["data"] ?? []};
  }

// ---------- PRIVATE HELPER ----------
  Map<String, dynamic> _handleResponse(http.Response res,
      {int expectedStatusCode = 200}) {
    try {
      final decoded = json.decode(res.body);
      if (res.statusCode == expectedStatusCode) {
        if (decoded is Map<String, dynamic>) return decoded;
        return {"data": decoded};
      } else {
        throw Exception('Request failed: ${res.body}');
      }
    } catch (e) {
      throw Exception('Invalid JSON response: ${res.body}');
    }
  }

// Note: inviteToMeeting was removed as participants are now handled in create/update meeting
// If you need separate invite functionality, you'll need to add it to the backend
// ---------- CHAT THREADS ----------
  Future<List<dynamic>> getChatThreads({
    String? entityType,
    String? entityId,
  }) async {
    final token = await AuthService.getAccessToken();

    // Build query parameters
    final params = <String, String>{};
    if (entityType != null) params['entity_type'] = entityType;
    if (entityId != null) params['entity_id'] = entityId;

    final uri =
        Uri.parse(ApiEndpoints.getChatThreads).replace(queryParameters: params);

    final res = await http.get(
      uri,
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return data['threads'] ?? [];
    }
    throw Exception('Failed to fetch chat threads: ${res.body}');
  }

  Future<Map<String, dynamic>> createChatThread({
    required String title,
    required List<int> participantIds,
    String entityType = 'general',
    String? entityId,
  }) async {
    final token = await AuthService.getAccessToken();

    final res = await http.post(
      Uri.parse(ApiEndpoints.createChatThread),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode({
        'title': title,
        'participant_ids': participantIds,
        'entity_type': entityType,
        'entity_id': entityId,
      }),
    );

    if (res.statusCode == 201) {
      final data = json.decode(res.body);
      if (data is Map<String, dynamic>) {
        return data['thread'] ?? data;
      }
      return {};
    }
    throw Exception('Failed to create chat thread: ${res.body}');
  }

  Future<Map<String, dynamic>> getChatThread(int threadId) async {
    final token = await AuthService.getAccessToken();

    final res = await http.get(
      Uri.parse(ApiEndpoints.getChatThread(threadId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    return _handleResponse(res);
  }

  // ---------- CHAT MESSAGES ----------
  Future<List<dynamic>> getChatMessages({
    required int threadId,
    int limit = 50,
    String? before,
  }) async {
    final token = await AuthService.getAccessToken();

    final params = <String, String>{'limit': limit.toString()};
    if (before != null) params['before'] = before;

    final uri = Uri.parse(ApiEndpoints.getChatMessages(threadId))
        .replace(queryParameters: params);

    final res = await http.get(
      uri,
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return data['messages'] ?? [];
    }
    throw Exception('Failed to fetch chat messages: ${res.body}');
  }

  Future<Map<String, dynamic>> sendMessage({
    required int threadId,
    required String content,
    String messageType = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    final token = await AuthService.getAccessToken();

    final res = await http.post(
      Uri.parse(ApiEndpoints.sendChatMessage(threadId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode({
        'content': content,
        'message_type': messageType,
        'metadata': metadata ?? {},
      }),
    );

    if (res.statusCode == 201) {
      return json.decode(res.body);
    }
    throw Exception('Failed to send message: ${res.body}');
  }

  Future<void> markMessagesAsRead({
    required int threadId,
    List<int>? messageIds,
  }) async {
    final token = await AuthService.getAccessToken();

    final res = await http.post(
      Uri.parse(ApiEndpoints.markMessagesAsRead(threadId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode({
        'message_ids': messageIds ?? [],
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to mark messages as read: ${res.body}');
    }
  }

  // ---------- CHAT SEARCH ----------
  Future<List<dynamic>> searchMessages({
    required String query,
    int? threadId,
    int limit = 20,
  }) async {
    final token = await AuthService.getAccessToken();

    final params = <String, String>{
      'q': query,
      'limit': limit.toString(),
    };
    if (threadId != null) params['thread_id'] = threadId.toString();

    final uri = Uri.parse(ApiEndpoints.searchChatMessages)
        .replace(queryParameters: params);

    final res = await http.get(
      uri,
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return data['messages'] ?? [];
    }
    throw Exception('Failed to search messages: ${res.body}');
  }

  // ---------- PRESENCE ----------
  Future<Map<String, dynamic>> updatePresence({
    required String status, // 'online', 'away', 'offline'
    String? socketId,
  }) async {
    final token = await AuthService.getAccessToken();

    final res = await http.post(
      Uri.parse(ApiEndpoints.updatePresence),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode({
        'status': status,
        'socket_id': socketId,
      }),
    );

    return _handleResponse(res);
  }

  // ---------- ENTITY CHATS ----------
  Future<Map<String, dynamic>> getEntityChat({
    required String entityType, // 'candidate' or 'requisition'
    required String entityId,
  }) async {
    final token = await AuthService.getAccessToken();

    final res = await http.get(
      Uri.parse(ApiEndpoints.getEntityChat(entityType, entityId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    return _handleResponse(res);
  }

  // Convenience methods for specific entity types
  Future<Map<String, dynamic>> getCandidateChat(int candidateId) async {
    return getEntityChat(
        entityType: 'candidate', entityId: candidateId.toString());
  }

  Future<Map<String, dynamic>> getRequisitionChat(int requisitionId) async {
    return getEntityChat(
        entityType: 'requisition', entityId: requisitionId.toString());
  }

  Future<List<dynamic>> getUsers() async {
    final token = await AuthService.getAccessToken();

    final res = await http.get(
      Uri.parse(ApiEndpoints.getUsers),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data is List) {
        return data;
      }
      if (data is Map<String, dynamic>) {
        return data['users'] ?? [];
      }
      return [];
    }

    throw Exception("Failed to load users: ${res.body}");
  }

  // =====================================================
// 📅 INTERVIEW CALENDAR (GOOGLE CALENDAR)
// =====================================================

  /// GET – Sync and compare upcoming interviews with Google Calendar
  Future<Map<String, dynamic>> syncInterviewCalendar() async {
    final token = await AuthService.getAccessToken();

    final res = await http.get(
      Uri.parse(ApiEndpoints.syncInterviewCalendar),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to sync interview calendar: ${res.body}');
  }

  /// POST – Sync a single interview to Google Calendar
  Future<Map<String, dynamic>> syncSingleInterviewCalendar(
      int interviewId) async {
    final token = await AuthService.getAccessToken();

    final res = await http.post(
      Uri.parse(ApiEndpoints.syncSingleInterviewCalendar(interviewId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to sync interview $interviewId: ${res.body}');
  }

  /// POST – Bulk sync multiple interviews
  Future<Map<String, dynamic>> bulkSyncInterviewCalendar(
      List<int> interviewIds) async {
    final token = await AuthService.getAccessToken();

    final res = await http.post(
      Uri.parse(ApiEndpoints.bulkSyncInterviewCalendar),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode({
        "interview_ids": interviewIds,
      }),
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to bulk sync interviews: ${res.body}');
  }

  /// GET – Retrieve Google Calendar status for a single interview
  Future<Map<String, dynamic>> getInterviewCalendarStatus(
      int interviewId) async {
    final token = await AuthService.getAccessToken();

    final res = await http.get(
      Uri.parse(ApiEndpoints.getInterviewCalendarStatus(interviewId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch calendar status: ${res.body}');
  }

  // ==================== INTERVIEW LIFECYCLE ENHANCEMENTS ====================

  // ---------- INTERVIEW STATUS UPDATES ----------
  /// Update interview status (completed, no_show, cancelled_by_candidate, etc.)
  Future<Map<String, dynamic>> updateInterviewStatus({
    required int interviewId,
    required String status,
    String? notes,
    String? noShowReason,
    String? cancellationReason,
  }) async {
    final token = await AuthService.getAccessToken();

    final data = {
      'status': status,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (noShowReason != null && noShowReason.isNotEmpty)
        'no_show_reason': noShowReason,
      if (cancellationReason != null && cancellationReason.isNotEmpty)
        'cancellation_reason': cancellationReason,
    };

    final res = await http.patch(
      Uri.parse(ApiEndpoints.updateInterviewStatus(interviewId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to update interview status: ${res.body}');
  }

  /// Reschedule an interview
  Future<Map<String, dynamic>> rescheduleInterview({
    required int interviewId,
    required DateTime newTime,
    String? newMeetingLink,
  }) async {
    final token = await AuthService.getAccessToken();

    final data = {
      'scheduled_time': newTime.toIso8601String(),
      if (newMeetingLink != null) 'meeting_link': newMeetingLink,
    };

    final res = await http.put(
      Uri.parse(ApiEndpoints.rescheduleInterview(interviewId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to reschedule interview: ${res.body}');
  }

  // ---------- INTERVIEW FEEDBACK ----------
  /// Submit interview feedback
  Future<Map<String, dynamic>> submitInterviewFeedback({
    required int interviewId,
    required int overallRating,
    required String recommendation,
    int? technicalSkills,
    int? communication,
    int? cultureFit,
    int? problemSolving,
    int? experienceRelevance,
    String? strengths,
    String? weaknesses,
    String? additionalNotes,
    String? privateNotes,
  }) async {
    final token = await AuthService.getAccessToken();

    final Map<String, dynamic> data = {
      'overall_rating': overallRating,
      'recommendation': recommendation,
      if (technicalSkills != null) 'technical_skills': technicalSkills,
      if (communication != null) 'communication': communication,
      if (cultureFit != null) 'culture_fit': cultureFit,
      if (problemSolving != null) 'problem_solving': problemSolving,
      if (experienceRelevance != null)
        'experience_relevance': experienceRelevance,
      if (strengths != null && strengths.isNotEmpty) 'strengths': strengths,
      if (weaknesses != null && weaknesses.isNotEmpty) 'weaknesses': weaknesses,
      if (additionalNotes != null && additionalNotes.isNotEmpty)
        'additional_notes': additionalNotes,
      if (privateNotes != null && privateNotes.isNotEmpty)
        'private_notes': privateNotes,
    };

    final res = await http.post(
      Uri.parse(ApiEndpoints.submitInterviewFeedback(interviewId)),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (res.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(res.body));
    }

    throw Exception('Failed to submit feedback: ${res.body}');
  }

  /// Get all feedback for an interview
  Future<List<Map<String, dynamic>>> getInterviewFeedback(
      int interviewId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.getInterviewFeedback(interviewId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = Map<String, dynamic>.from(json.decode(res.body));
      return List<Map<String, dynamic>>.from(data['feedback'] ?? []);
    }

    throw Exception('Failed to fetch interview feedback: ${res.body}');
  }

  /// Request feedback from interviewer
  Future<Map<String, dynamic>> requestFeedback(int interviewId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.post(
      Uri.parse(ApiEndpoints.requestFeedback(interviewId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to request feedback: ${res.body}');
  }

  /// Get feedback summary for an interview
  Future<Map<String, dynamic>> getFeedbackSummary(int interviewId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.getFeedbackSummary(interviewId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch feedback summary: ${res.body}');
  }

  // ---------- INTERVIEW REMINDERS ----------
  /// Schedule automated reminders for interviews
  Future<Map<String, dynamic>> scheduleInterviewReminders({
    int? interviewId,
    List<int>? interviewIds,
  }) async {
    final token = await AuthService.getAccessToken();

    final data = {
      if (interviewId != null) 'interview_id': interviewId,
      if (interviewIds != null && interviewIds.isNotEmpty)
        'interview_ids': interviewIds,
    };

    final res = await http.post(
      Uri.parse(ApiEndpoints.scheduleInterviewReminders),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to schedule reminders: ${res.body}');
  }

  /// Get all reminders for an interview
  Future<List<Map<String, dynamic>>> getInterviewReminders(
      int interviewId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.getInterviewReminders(interviewId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = Map<String, dynamic>.from(json.decode(res.body));
      return List<Map<String, dynamic>>.from(data['reminders'] ?? []);
    }

    throw Exception('Failed to fetch interview reminders: ${res.body}');
  }

  /// Send immediate reminder (ad-hoc)
  Future<Map<String, dynamic>> sendImmediateReminder(int interviewId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.post(
      Uri.parse(ApiEndpoints.sendImmediateReminder(interviewId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to send immediate reminder: ${res.body}');
  }

  /// Cancel a scheduled reminder
  Future<void> cancelInterviewReminder(int reminderId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.delete(
      Uri.parse(ApiEndpoints.cancelInterviewReminder(reminderId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to cancel reminder: ${res.body}');
    }
  }

  // ---------- INTERVIEW ANALYTICS ----------
  /// Get interview statistics and metrics
  Future<Map<String, dynamic>> getInterviewAnalytics() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.getInterviewAnalytics),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch interview analytics: ${res.body}');
  }

  /// Get no-show statistics
  Future<Map<String, dynamic>> getNoShowAnalytics() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.getNoShowAnalytics),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch no-show analytics: ${res.body}');
  }

  /// Get feedback completion rates
  Future<Map<String, dynamic>> getFeedbackAnalytics() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.getFeedbackAnalytics),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch feedback analytics: ${res.body}');
  }

  /// Get interviewer performance metrics
  Future<Map<String, dynamic>> getInterviewerAnalytics() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.getInterviewerAnalytics),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch interviewer analytics: ${res.body}');
  }

  // ---------- INTERVIEW NOTES ----------
  /// Add notes to an interview
  Future<Map<String, dynamic>> addInterviewNotes({
    required int interviewId,
    required String notes,
  }) async {
    final token = await AuthService.getAccessToken();

    final data = {'notes': notes};

    final res = await http.post(
      Uri.parse(ApiEndpoints.addInterviewNotes(interviewId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );

    if (res.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to add interview notes: ${res.body}');
  }

  /// Get all notes for an interview
  Future<List<Map<String, dynamic>>> getInterviewNotes(int interviewId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.getInterviewNotes(interviewId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch interview notes: ${res.body}');
  }

  /// Update interview notes
  Future<Map<String, dynamic>> updateInterviewNotes({
    required int noteId,
    required String notes,
  }) async {
    final token = await AuthService.getAccessToken();

    final data = {'notes': notes};

    final res = await http.put(
      Uri.parse(ApiEndpoints.updateInterviewNotes(noteId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to update interview notes: ${res.body}');
  }

  /// Delete interview notes
  Future<void> deleteInterviewNotes(int noteId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.delete(
      Uri.parse(ApiEndpoints.deleteInterviewNotes(noteId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to delete interview notes: ${res.body}');
    }
  }

  // ---------- INTERVIEW WORKFLOW ----------
  /// Move interview to next stage
  Future<Map<String, dynamic>> moveInterviewToNextStage(int interviewId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.post(
      Uri.parse(ApiEndpoints.moveInterviewToNextStage(interviewId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to move interview to next stage: ${res.body}');
  }

  /// Move interview to previous stage
  Future<Map<String, dynamic>> moveInterviewToPreviousStage(
      int interviewId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.post(
      Uri.parse(ApiEndpoints.moveInterviewToPreviousStage(interviewId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to move interview to previous stage: ${res.body}');
  }

  /// Get interview workflow stages
  Future<List<Map<String, dynamic>>> getInterviewWorkflowStages() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.getInterviewWorkflowStages),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch workflow stages: ${res.body}');
  }

  // ---------- BULK INTERVIEW OPERATIONS ----------
  /// Bulk update interview statuses
  Future<Map<String, dynamic>> bulkUpdateInterviewStatus({
    required List<int> interviewIds,
    required String status,
    String? notes,
  }) async {
    final token = await AuthService.getAccessToken();

    final data = {
      'interview_ids': interviewIds,
      'status': status,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    final res = await http.post(
      Uri.parse(ApiEndpoints.bulkUpdateInterviewStatus),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to bulk update interview status: ${res.body}');
  }

  /// Bulk schedule reminders
  Future<Map<String, dynamic>> bulkScheduleReminders(
      List<int> interviewIds) async {
    final token = await AuthService.getAccessToken();

    final data = {'interview_ids': interviewIds};

    final res = await http.post(
      Uri.parse(ApiEndpoints.bulkScheduleReminders),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to bulk schedule reminders: ${res.body}');
  }

  /// Bulk request feedback
  Future<Map<String, dynamic>> bulkRequestFeedback(
      List<int> interviewIds) async {
    final token = await AuthService.getAccessToken();

    final data = {'interview_ids': interviewIds};

    final res = await http.post(
      Uri.parse(ApiEndpoints.bulkRequestFeedback),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to bulk request feedback: ${res.body}');
  }

  // ---------- INTERVIEW TEMPLATES ----------
  /// Get all interview templates
  Future<List<Map<String, dynamic>>> getInterviewTemplates() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.getInterviewTemplates),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch interview templates: ${res.body}');
  }

  /// Get specific interview template
  Future<Map<String, dynamic>> getInterviewTemplate(int templateId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.getInterviewTemplate(templateId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch interview template: ${res.body}');
  }

  /// Create new interview template
  Future<Map<String, dynamic>> createInterviewTemplate(
      Map<String, dynamic> data) async {
    final token = await AuthService.getAccessToken();
    final res = await http.post(
      Uri.parse(ApiEndpoints.createInterviewTemplate),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );

    if (res.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to create interview template: ${res.body}');
  }

  /// Update interview template
  Future<Map<String, dynamic>> updateInterviewTemplate({
    required int templateId,
    required Map<String, dynamic> data,
  }) async {
    final token = await AuthService.getAccessToken();
    final res = await http.put(
      Uri.parse(ApiEndpoints.updateInterviewTemplate(templateId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to update interview template: ${res.body}');
  }

  /// Delete interview template
  Future<void> deleteInterviewTemplate(int templateId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.delete(
      Uri.parse(ApiEndpoints.deleteInterviewTemplate(templateId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to delete interview template: ${res.body}');
    }
  }

  // ---------- CANDIDATE AVAILABILITY ----------
  /// Get candidate availability
  Future<Map<String, dynamic>> getCandidateAvailability(int candidateId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.getCandidateAvailability(candidateId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch candidate availability: ${res.body}');
  }

  /// Set candidate availability
  Future<Map<String, dynamic>> setCandidateAvailability({
    required int candidateId,
    required Map<String, dynamic> availabilityData,
  }) async {
    final token = await AuthService.getAccessToken();
    final res = await http.post(
      Uri.parse(ApiEndpoints.setCandidateAvailability(candidateId)),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(availabilityData),
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to set candidate availability: ${res.body}');
  }

  /// Check interview scheduling conflicts
  Future<Map<String, dynamic>> checkSchedulingConflicts({
    required DateTime startTime,
    required DateTime endTime,
    List<int>? interviewerIds,
    int? candidateId,
  }) async {
    final token = await AuthService.getAccessToken();

    final data = {
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      if (interviewerIds != null && interviewerIds.isNotEmpty)
        'interviewer_ids': interviewerIds,
      if (candidateId != null) 'candidate_id': candidateId,
    };

    final res = await http.post(
      Uri.parse(ApiEndpoints.checkSchedulingConflicts),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: json.encode(data),
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to check scheduling conflicts: ${res.body}');
  }

  // ---------- INTERVIEW DASHBOARD ----------
  /// Get today's interviews
  Future<List<Map<String, dynamic>>> getTodaysInterviews() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.getTodaysInterviews),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch today\'s interviews: ${res.body}');
  }

  /// Get upcoming interviews
  Future<List<Map<String, dynamic>>> getUpcomingInterviews() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.getUpcomingInterviews),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch upcoming interviews: ${res.body}');
  }

  /// Get past interviews
  Future<List<Map<String, dynamic>>> getPastInterviews() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.getPastInterviews),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch past interviews: ${res.body}');
  }

  /// Get interviews requiring action
  Future<List<Map<String, dynamic>>> getInterviewsRequiringAction() async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiEndpoints.getInterviewsRequiringAction),
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch interviews requiring action: ${res.body}');
  }

  // ========== ADD THE NEW METHOD HERE ==========
  /// Get candidates ready for job offers (optimized database query)
  Future<Map<String, dynamic>> getCandidatesReadyForOffer({
    int minInterviews = 2,
    double minRating = 3.5,
    int limit = 50,
    String stage = 'interview_completed',
  }) async {
    final token = await AuthService.getAccessToken();

    final params = <String, String>{
      'min_interviews': minInterviews.toString(),
      'min_rating': minRating.toString(),
      'limit': limit.toString(),
      'stage': stage,
    };

    final uri = Uri.parse(ApiEndpoints.getCandidatesReadyForOffer)
        .replace(queryParameters: params);

    final res = await http.get(
      uri,
      headers: {...headers, 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    }

    throw Exception('Failed to fetch candidates ready for offers: ${res.body}');
  }
}
