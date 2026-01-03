import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../utils/api_endpoints.dart';

class RecruitmentService {
  final String token;

  RecruitmentService(this.token);

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  // ==================== PIPELINE STATISTICS ====================
  Future<Map<String, dynamic>> getPipelineStats() async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.getPipelineStats),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to load pipeline stats: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching pipeline stats: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getPipelineQuickStats() async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.getPipelineQuickStats),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to load quick stats: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching quick stats: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPipelineStages() async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.getPipelineStagesCount),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['stages'] ?? []);
      }
      throw Exception('Failed to load pipeline stages: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching pipeline stages: $e');
      rethrow;
    }
  }

  // ==================== APPLICATIONS ====================
  Future<Map<String, dynamic>> getFilteredApplications({
    String? status,
    int? jobId,
    String? search,
    String? sortBy = 'created_at',
    String? sortOrder = 'desc',
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      String url = ApiEndpoints.getFilteredApplications;
      final params = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      if (status != null && status != 'all') params['status'] = status;
      if (jobId != null) params['job_id'] = jobId.toString();
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (sortBy != null) params['sort_by'] = sortBy;
      if (sortOrder != null) params['sort_order'] = sortOrder;

      final uri = Uri.parse(url).replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to load applications: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching applications: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getApplications({
    String? status,
    int? requisitionId,
  }) async {
    try {
      // Use the filtered endpoint for backward compatibility
      final result = await getFilteredApplications(
        status: status,
        jobId: requisitionId,
        perPage: 1000, // Large number to get all
      );

      return List<Map<String, dynamic>>.from(result['applications'] ?? []);
    } catch (e) {
      debugPrint('Error fetching applications: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getApplication(int id) async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.getApplicationById(id)),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to load application: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching application: $e');
      rethrow;
    }
  }

  Future<bool> updateApplicationStatus(int applicationId, String status) async {
    try {
      final response = await http.patch(
        Uri.parse(ApiEndpoints.updateApplicationStatus(applicationId)),
        headers: _headers,
        body: jsonEncode({'status': status}),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating application status: $e');
      return false;
    }
  }

  // ==================== REQUISITIONS/JOBS ====================
  Future<List<Map<String, dynamic>>> getRequisitions() async {
    try {
      // Use the new jobs with stats endpoint
      return await getJobsWithStats();
    } catch (e) {
      debugPrint('Error fetching requisitions: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getJobsWithStats() async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.getJobsWithStats),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['jobs'] ?? []);
      }
      throw Exception('Failed to load jobs: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching jobs: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getRequisition(int id) async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.getJobById(id)),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to load requisition: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching requisition: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createRequisition(
      Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.createJob),
        headers: _headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to create requisition: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error creating requisition: $e');
      rethrow;
    }
  }

  // ==================== INTERVIEWS ====================
  Future<List<Map<String, dynamic>>> getInterviews({
    String? status,
    String? timeframe,
  }) async {
    try {
      if (timeframe != null) {
        return await getInterviewsByTimeframe(timeframe);
      }

      // Default to upcoming interviews
      return await getInterviewsByTimeframe('upcoming');
    } catch (e) {
      debugPrint('Error fetching interviews: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getInterviewsByTimeframe(
      String timeframe) async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.getInterviewsByTimeframe(timeframe)),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['interviews'] ?? []);
      }
      throw Exception('Failed to load interviews: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching interviews: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTodaysInterviews() async {
    return await getInterviewsByTimeframe('today');
  }

  Future<List<Map<String, dynamic>>> getUpcomingInterviews() async {
    return await getInterviewsByTimeframe('upcoming');
  }

  Future<List<Map<String, dynamic>>> getPastInterviews() async {
    return await getInterviewsByTimeframe('past');
  }

  Future<Map<String, dynamic>> scheduleInterview(
      Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.scheduleInterview),
        headers: _headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to schedule interview: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error scheduling interview: $e');
      rethrow;
    }
  }

  // ==================== OFFERS ====================
  Future<List<Map<String, dynamic>>> getOffers({String? status}) async {
    try {
      String url;
      if (status != null) {
        url = ApiEndpoints.getOffersByStatus(status);
      } else {
        url = ApiEndpoints.getAllOffers;
      }

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      throw Exception('Failed to load offers: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching offers: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createOffer(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.draftOffer),
        headers: _headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to create offer: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error creating offer: $e');
      rethrow;
    }
  }

  // ==================== CANDIDATES READY FOR OFFER ====================
  Future<List<Map<String, dynamic>>> getCandidatesReadyForOffer() async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.getCandidatesReadyForOffer),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['candidates'] ?? []);
      }
      throw Exception('Failed to load candidates: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching candidates ready for offer: $e');
      rethrow;
    }
  }

  // ==================== ANALYTICS ====================
  Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final [dashboardAnalytics, offerAnalytics] = await Future.wait([
        getDashboardAnalytics(),
        getOfferAnalytics(),
      ]);

      return {
        'dashboard': dashboardAnalytics,
        'offers': offerAnalytics,
      };
    } catch (e) {
      debugPrint('Error fetching analytics: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDashboardAnalytics() async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.getDashboardAnalytics),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception(
          'Failed to load dashboard analytics: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching dashboard analytics: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getOfferAnalytics() async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.getOfferAnalytics),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to load offer analytics: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching offer analytics: $e');
      rethrow;
    }
  }

  // ==================== SEARCH ====================
  Future<Map<String, dynamic>> searchAll(String query) async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.searchAll(query)),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to search: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error searching: $e');
      rethrow;
    }
  }

  // ==================== DASHBOARD DATA LOADING ====================
  Future<Map<String, dynamic>> loadPipelineData({
    String? filter,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final [
        stats,
        quickStats,
        stages,
        applications,
        interviews,
        offers,
        readyCandidates
      ] = await Future.wait([
        getPipelineStats(),
        getPipelineQuickStats(),
        getPipelineStages(),
        getFilteredApplications(
          status: filter,
          page: page,
          perPage: perPage,
        ),
        getTodaysInterviews(),
        getOffers(),
        getCandidatesReadyForOffer(),
      ]);

      return {
        'stats': stats,
        'quickStats': quickStats,
        'stages': stages,
        'applications': applications,
        'interviews': interviews,
        'offers': offers,
        'readyCandidates': readyCandidates,
      };
    } catch (e) {
      debugPrint('Error loading pipeline data: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> loadRequisitionsData() async {
    try {
      final results = await Future.wait([
        getJobsWithStats(),
        getFilteredApplications(perPage: 10),
        getUpcomingInterviews(),
        getOffers(),
      ]);

      final jobs = results[0];
      final applicationsResponse = results[1] as Map<String, dynamic>;
      final interviews = results[2];
      final offers = results[3];

      return {
        'jobs': jobs,
        'applications': applicationsResponse['applications'] ?? [],
        'interviews': interviews,
        'offers': offers,
      };
    } catch (e) {
      debugPrint('Error loading requisitions data: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> loadCalendarData() async {
    try {
      final [todayInterviews, upcomingInterviews, pastInterviews, offers] =
          await Future.wait([
        getTodaysInterviews(),
        getUpcomingInterviews(),
        getPastInterviews(),
        getOffers(),
      ]);

      return {
        'todayInterviews': todayInterviews,
        'upcomingInterviews': upcomingInterviews,
        'pastInterviews': pastInterviews,
        'offers': offers,
      };
    } catch (e) {
      debugPrint('Error loading calendar data: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> loadAnalyticsData() async {
    try {
      final [dashboardAnalytics, offerAnalytics, quickStats, applications] =
          await Future.wait([
        getDashboardAnalytics(),
        getOfferAnalytics(),
        getPipelineQuickStats(),
        getFilteredApplications(perPage: 10),
      ]);

      return {
        'dashboardAnalytics': dashboardAnalytics,
        'offerAnalytics': offerAnalytics,
        'quickStats': quickStats,
        'topApplications': applications['applications'] ?? [],
      };
    } catch (e) {
      debugPrint('Error loading analytics data: $e');
      rethrow;
    }
  }

  // ==================== REFRESH DATA ====================
  Future<Map<String, dynamic>> refreshAllData() async {
    try {
      final results = await Future.wait([
        getPipelineStats(),
        getFilteredApplications(perPage: 20),
        getTodaysInterviews(),
        getOffers(),
        getJobsWithStats(),
        getCandidatesReadyForOffer(),
      ]);

      final stats = results[0];
      final applicationsResponse = results[1] as Map<String, dynamic>;
      final interviews = results[2];
      final offers = results[3];
      final jobs = results[4];
      final readyCandidates = results[5];

      return {
        'stats': stats,
        'applications': applicationsResponse['applications'] ?? [],
        'interviews': interviews,
        'offers': offers,
        'jobs': jobs,
        'readyCandidates': readyCandidates,
      };
    } catch (e) {
      debugPrint('Error refreshing data: $e');
      rethrow;
    }
  }

  // ==================== QUICK ACTIONS ====================
  Future<List<Map<String, dynamic>>> getShortlistedCandidates(int jobId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.shortlistCandidates(jobId)),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      throw Exception(
          'Failed to load shortlisted candidates: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching shortlisted candidates: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllCandidates() async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.viewCandidates),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      throw Exception('Failed to load candidates: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching candidates: $e');
      rethrow;
    }
  }

  // ==================== CV/APPLICATION MANAGEMENT ====================
  Future<Map<String, dynamic>> downloadApplicationCV(int applicationId) async {
    try {
      final response = await http.get(
        Uri.parse(
            "${ApiEndpoints.adminBase}/applications/$applicationId/download-cv"),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to download CV: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error downloading CV: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCVReviews() async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.cvReviews),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      throw Exception('Failed to load CV reviews: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching CV reviews: $e');
      rethrow;
    }
  }

  // ==================== ERROR HANDLING HELPERS ====================
  String getErrorMessage(dynamic error) {
    if (error is http.Response) {
      try {
        final errorBody = jsonDecode(error.body);
        return errorBody['error'] ??
            errorBody['message'] ??
            'An error occurred';
      } catch (_) {
        return 'HTTP ${error.statusCode}: ${error.reasonPhrase}';
      }
    }
    return error.toString();
  }

  bool isConnectionError(dynamic error) {
    return error is http.ClientException ||
        (error is http.Response && error.statusCode >= 500);
  }
}
