import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/application.dart';
import '../models/offer.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../utils/app_config.dart';
import 'package:http/http.dart' as http;

/// Unified state management provider for admin screens
class AdminStateProvider extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  // Loading states
  bool _isLoadingDashboard = false;
  bool _isLoadingJobs = false;
  bool _isLoadingApplications = false;
  bool _isLoadingCandidates = false;
  bool _isLoadingInterviews = false;
  bool _isLoadingOffers = false;
  bool _isLoadingAuditLogs = false;

  // Dashboard data
  Map<String, dynamic> _dashboardStats = {};
  List<String> _recentActivities = [];
  bool _powerBIConnected = false;
  bool _checkingPowerBI = true;

  // Jobs data
  List<Map<String, dynamic>> _jobs = [];
  Map<String, dynamic> _jobStatistics = {};
  int _jobsCurrentPage = 1;
  int _jobsTotalPages = 1;
  String _jobsSortBy = 'created_at';
  String _jobsSortOrder = 'desc';

  // Applications data
  List<Application> _applications = [];
  List<Application> _filteredApplications = [];
  int _applicationsCurrentPage = 1;
  int _applicationsTotalPages = 1;
  String _applicationsSearchQuery = '';
  String? _applicationsSelectedStatus;
  int? _applicationsSelectedJobId;

  // Candidates data
  List<Map<String, dynamic>> _candidates = [];
  Map<String, dynamic> _candidatesAnalytics = {};
  int _candidatesCurrentPage = 1;
  int _candidatesTotalPages = 1;

  // Interviews data
  List<Map<String, dynamic>> _interviews = [];
  Map<String, dynamic> _interviewStatistics = {};
  int _interviewsCurrentPage = 1;
  int _interviewsTotalPages = 1;
  String _interviewsSearchQuery = '';
  String? _interviewsSelectedStatus;
  String? _interviewsSelectedFilter;

  // Interviews getters
  List<Map<String, dynamic>> get interviews => _interviews;
  Map<String, dynamic> get interviewStatistics => _interviewStatistics;
  int get interviewsCurrentPage => _interviewsCurrentPage;
  int get interviewsTotalPages => _interviewsTotalPages;
  String get interviewsSearchQuery => _interviewsSearchQuery;
  String? get interviewsSelectedStatus => _interviewsSelectedStatus;
  String? get interviewsSelectedFilter => _interviewsSelectedFilter;

  // Interviews methods
  void setInterviews(List<Map<String, dynamic>> interviews) {
    _interviews = interviews;
    notifyListeners();
  }

  void addInterviews(List<Map<String, dynamic>> newInterviews) {
    _interviews.addAll(newInterviews);
    notifyListeners();
  }

  void setInterviewsPage(int page) {
    if (page >= 1 && page <= _interviewsTotalPages) {
      _interviewsCurrentPage = page;
      notifyListeners();
    }
  }

  void updateInterviewsSearchQuery(String query) {
    _interviewsSearchQuery = query;
    notifyListeners();
  }

  void setInterviewsSelectedStatus(String? status) {
    _interviewsSelectedStatus = status;
    notifyListeners();
  }

  void setInterviewsSelectedFilter(String? filter) {
    _interviewsSelectedFilter = filter;
    notifyListeners();
  }

  void clearInterviews() {
    _interviews.clear();
    _interviewsCurrentPage = 1;
    _interviewsTotalPages = 1;
    _interviewsSearchQuery = '';
    _interviewsSelectedStatus = null;
    _interviewsSelectedFilter = null;
    notifyListeners();
  }

  // Offers data
  List<Offer> _offers = [];
  Map<String, dynamic> _offerAnalytics = {};

  // Audit logs data
  List<Map<String, dynamic>> _auditLogs = [];
  int _auditLogsCurrentPage = 1;
  int _auditLogsTotalPages = 1;
  String? _auditLogsActionFilter;
  DateTime? _auditLogsStartDate;
  DateTime? _auditLogsEndDate;
  String? _auditLogsSearchQuery;

  // Error states
  String? _dashboardError;
  String? _jobsError;
  String? _applicationsError;
  String? _candidatesError;
  String? _interviewsError;
  String? _offersError;
  String? _auditLogsError;

  // Cache management
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Getters
  bool get isLoadingDashboard => _isLoadingDashboard;
  bool get isLoadingJobs => _isLoadingJobs;
  bool get isLoadingApplications => _isLoadingApplications;
  bool get isLoadingCandidates => _isLoadingCandidates;
  bool get isLoadingInterviews => _isLoadingInterviews;
  bool get isLoadingOffers => _isLoadingOffers;
  bool get isLoadingAuditLogs => _isLoadingAuditLogs;

  Map<String, dynamic> get dashboardStats => _dashboardStats;
  List<String> get recentActivities => _recentActivities;
  bool get powerBIConnected => _powerBIConnected;
  bool get checkingPowerBI => _checkingPowerBI;

  List<Map<String, dynamic>> get jobs => _jobs;
  Map<String, dynamic> get jobStatistics => _jobStatistics;
  int get jobsCurrentPage => _jobsCurrentPage;
  int get jobsTotalPages => _jobsTotalPages;

  List<Application> get applications => _applications;
  List<Application> get filteredApplications => _filteredApplications;
  int get applicationsCurrentPage => _applicationsCurrentPage;
  int get applicationsTotalPages => _applicationsTotalPages;

  List<Map<String, dynamic>> get candidates => _candidates;
  Map<String, dynamic> get candidatesAnalytics => _candidatesAnalytics;
  int get candidatesCurrentPage => _candidatesCurrentPage;
  int get candidatesTotalPages => _candidatesTotalPages;

  List<Offer> get offers => _offers;
  Map<String, dynamic> get offerAnalytics => _offerAnalytics;

  List<Map<String, dynamic>> get auditLogs => _auditLogs;
  int get auditLogsCurrentPage => _auditLogsCurrentPage;
  int get auditLogsTotalPages => _auditLogsTotalPages;

  String? get dashboardError => _dashboardError;
  String? get jobsError => _jobsError;
  String? get applicationsError => _applicationsError;
  String? get candidatesError => _candidatesError;
  String? get interviewsError => _interviewsError;
  String? get offersError => _offersError;
  String? get auditLogsError => _auditLogsError;

  // Dashboard methods
  Future<void> fetchDashboardStats() async {
    _setLoading(true, 'dashboard');
    _setError(null, 'dashboard');

    try {
      final cacheKey = 'dashboard_stats';
      final cachedData = _getCachedData(cacheKey);

      if (cachedData != null) {
        _dashboardStats = cachedData;
        notifyListeners();
        return;
      }

      final stats = await _adminService.getDashboardCounts();
      _dashboardStats = stats;
      _setCachedData(cacheKey, stats);

      // Fetch recent activities
      await fetchRecentActivities();

      // Check PowerBI status
      await checkPowerBIStatus();
    } catch (e) {
      _setError(e.toString(), 'dashboard');
    } finally {
      _setLoading(false, 'dashboard');
    }
  }

  Future<void> fetchRecentActivities() async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) return;

      final cacheKey = 'recent_activities';
      final cachedData = _getCachedData(cacheKey);

      if (cachedData != null) {
        _recentActivities = List<String>.from(cachedData);
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBase}/api/admin/recent-activities'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _recentActivities = List<String>.from(data["recent_activities"] ?? []);
        _setCachedData(cacheKey, _recentActivities);
      }
    } catch (e) {
      debugPrint('Error fetching recent activities: $e');
    }
  }

  Future<void> checkPowerBIStatus() async {
    _checkingPowerBI = true;
    notifyListeners();

    try {
      final token = await AuthService.getAccessToken();
      if (token == null) return;

      final cacheKey = 'powerbi_status';
      final cachedData = _getCachedData(cacheKey);

      if (cachedData != null) {
        _powerBIConnected = cachedData;
        _checkingPowerBI = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBase}/api/admin/powerbi/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _powerBIConnected = data["connected"] ?? false;
        _setCachedData(cacheKey, _powerBIConnected);
      } else {
        _powerBIConnected = false;
      }
    } catch (e) {
      _powerBIConnected = false;
    } finally {
      _checkingPowerBI = false;
      notifyListeners();
    }
  }

  // Jobs filter properties
  String _jobsStatusFilter = 'all';
  String _jobsCategoryFilter = 'all';

  String get jobsStatusFilter => _jobsStatusFilter;
  String get jobsCategoryFilter => _jobsCategoryFilter;
  String get jobsSortBy => _jobsSortBy;
  String get jobsSortOrder => _jobsSortOrder;

  // Jobs filter methods
  void setJobsStatusFilter(String status) {
    _jobsStatusFilter = status;
    notifyListeners();
  }

  void setJobsCategoryFilter(String category) {
    _jobsCategoryFilter = category;
    notifyListeners();
  }

  void setJobsSortBy(String sortBy) {
    _jobsSortBy = sortBy;
    notifyListeners();
  }

  void toggleJobsSortOrder() {
    _jobsSortOrder = _jobsSortOrder == 'desc' ? 'asc' : 'desc';
    notifyListeners();
  }

  void clearJobs() {
    _jobs.clear();
    _jobsCurrentPage = 1;
    _jobsTotalPages = 1;
    notifyListeners();
  }

  // Jobs methods
  Future<void> fetchJobs({bool refresh = false, int page = 1}) async {
    _setLoading(true, 'jobs');
    _setError(null, 'jobs');

    try {
      if (!refresh && page == 1) {
        final cacheKey = 'jobs_page_${_jobsCurrentPage}';
        final cachedData = _getCachedData(cacheKey);

        if (cachedData != null) {
          _jobs = cachedData;
          notifyListeners();
          return;
        }
      }

      final queryParams = {
        'page': page.toString(),
        'per_page': '20',
        if (_jobsStatusFilter != 'all') 'status': _jobsStatusFilter,
        if (_jobsCategoryFilter != 'all') 'category': _jobsCategoryFilter,
        'sort_by': _jobsSortBy,
        'sort_order': _jobsSortOrder,
      };

      final uri = Uri.parse('${AppConfig.apiBase}/api/admin/jobs')
          .replace(queryParameters: queryParams);

      final token = await AuthService.getAccessToken();
      if (token == null) return;

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newJobs = List<Map<String, dynamic>>.from(data['jobs'] ?? []);

        if (page == 1) {
          _jobs.clear();
        }
        _jobs.addAll(newJobs);

        _jobsCurrentPage = data['page'] ?? page;
        _jobsTotalPages = data['total_pages'] ?? 1;

        if (page == 1) {
          _setCachedData('jobs_page_1', _jobs);
        }
      }

      // Fetch job statistics
      await fetchJobStatistics();
    } catch (e) {
      _setError(e.toString(), 'jobs');
    } finally {
      _setLoading(false, 'jobs');
    }
  }

  Future<void> fetchJobStatistics() async {
    try {
      final cacheKey = 'job_statistics';
      final cachedData = _getCachedData(cacheKey);

      if (cachedData != null) {
        _jobStatistics = cachedData;
        notifyListeners();
        return;
      }

      final stats = await _adminService.getAllJobStatistics();
      _jobStatistics = stats;
      _setCachedData(cacheKey, stats);
    } catch (e) {
      debugPrint('Error fetching job statistics: $e');
    }
  }

  void updateJobsFilters({
    String? searchQuery,
    String? category,
    String? status,
    String? sortBy,
    String? sortOrder,
  }) {
    if (searchQuery != null) {
      // Search query handling - could be added if needed
    }
    if (category != null) _jobsCategoryFilter = category;
    if (status != null) _jobsStatusFilter = status;
    if (sortBy != null) _jobsSortBy = sortBy;
    if (sortOrder != null) _jobsSortOrder = sortOrder;
    notifyListeners();
  }

  void setJobsPage(int page) {
    if (page >= 1 && page <= _jobsTotalPages) {
      _jobsCurrentPage = page;
      fetchJobs();
    }
  }

  // Applications methods
  Future<void> fetchApplications({bool refresh = false}) async {
    _setLoading(true, 'applications');
    _setError(null, 'applications');

    try {
      if (!refresh) {
        final cacheKey = 'applications_page_$_applicationsCurrentPage';
        final cachedData = _getCachedData(cacheKey);

        if (cachedData != null) {
          _applications = (cachedData['applications'] as List)
              .map((json) => Application.fromJson(json))
              .toList();
          _applicationsTotalPages = cachedData['totalPages'] ?? 1;
          _applyApplicationsFilters();
          notifyListeners();
          return;
        }
      }

      final applications = await _adminService.getApplications();
      _applications =
          applications.map((json) => Application.fromJson(json)).toList();
      _applicationsTotalPages = 1;

      final cacheKey = 'applications_page_$_applicationsCurrentPage';
      _setCachedData(cacheKey, {
        'applications': applications,
        'totalPages': _applicationsTotalPages,
      });

      _applyApplicationsFilters();
    } catch (e) {
      _setError(e.toString(), 'applications');
    } finally {
      _setLoading(false, 'applications');
    }
  }

  void _applyApplicationsFilters() {
    _filteredApplications = _applications.where((app) {
      if (_applicationsSelectedStatus != null &&
          app.status != _applicationsSelectedStatus) {
        return false;
      }
      if (_applicationsSelectedJobId != null &&
          app.id != _applicationsSelectedJobId) {
        return false;
      }
      if (_applicationsSearchQuery.isNotEmpty) {
        final query = _applicationsSearchQuery.toLowerCase();
        return app.candidateName.toLowerCase().contains(query) ||
            app.jobTitle.toLowerCase().contains(query);
      }
      return true;
    }).toList();
  }

  void updateApplicationsFilters({
    String? searchQuery,
    String? status,
    int? jobId,
  }) {
    if (searchQuery != null) _applicationsSearchQuery = searchQuery;
    if (status != null) _applicationsSelectedStatus = status;
    if (jobId != null) _applicationsSelectedJobId = jobId;

    _applyApplicationsFilters();
    notifyListeners();
  }

  // Candidates methods
  Future<void> fetchCandidates({bool refresh = false}) async {
    _setLoading(true, 'candidates');
    _setError(null, 'candidates');

    try {
      if (!refresh) {
        final cacheKey = 'candidates_page_$_candidatesCurrentPage';
        final cachedData = _getCachedData(cacheKey);

        if (cachedData != null) {
          _candidates =
              List<Map<String, dynamic>>.from(cachedData['candidates']);
          _candidatesTotalPages = cachedData['totalPages'] ?? 1;
          notifyListeners();
          return;
        }
      }

      final candidates = await _adminService.listCandidates();
      _candidates = List<Map<String, dynamic>>.from(candidates);
      _candidatesTotalPages = 1;

      final cacheKey = 'candidates_page_$_candidatesCurrentPage';
      _setCachedData(cacheKey, {
        'candidates': _candidates,
        'totalPages': _candidatesTotalPages,
      });

      await fetchCandidatesAnalytics();
    } catch (e) {
      _setError(e.toString(), 'candidates');
    } finally {
      _setLoading(false, 'candidates');
    }
  }

  Future<void> fetchCandidatesAnalytics() async {
    try {
      final cacheKey = 'candidates_analytics';
      final cachedData = _getCachedData(cacheKey);

      if (cachedData != null) {
        _candidatesAnalytics = cachedData;
        notifyListeners();
        return;
      }

      final analytics = await _adminService.getCandidatesAnalytics();
      _candidatesAnalytics = analytics;
      _setCachedData(cacheKey, analytics);
    } catch (e) {
      debugPrint('Error fetching candidates analytics: $e');
    }
  }

  // Audit logs methods
  Future<void> fetchAuditLogs({bool refresh = false}) async {
    _setLoading(true, 'auditLogs');
    _setError(null, 'auditLogs');

    try {
      final token = await AuthService.getAccessToken();
      if (token == null) return;

      final queryParams = {
        "page": _auditLogsCurrentPage.toString(),
        "per_page": "20",
        if (_auditLogsActionFilter != null) "action": _auditLogsActionFilter!,
        if (_auditLogsStartDate != null)
          "start_date":
              "${_auditLogsStartDate!.year}-${_auditLogsStartDate!.month.toString().padLeft(2, '0')}-${_auditLogsStartDate!.day.toString().padLeft(2, '0')}",
        if (_auditLogsEndDate != null)
          "end_date":
              "${_auditLogsEndDate!.year}-${_auditLogsEndDate!.month.toString().padLeft(2, '0')}-${_auditLogsEndDate!.day.toString().padLeft(2, '0')}",
        if (_auditLogsSearchQuery != null) "q": _auditLogsSearchQuery!,
      };

      final uri = Uri.parse("${AppConfig.apiBase}/api/admin/audits")
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _auditLogs = List<Map<String, dynamic>>.from(data["results"] ?? []);
        _auditLogsCurrentPage = data["page"] ?? 1;
        _auditLogsTotalPages = data["total_pages"] ?? 1;
      }
    } catch (e) {
      _setError(e.toString(), 'auditLogs');
    } finally {
      _setLoading(false, 'auditLogs');
    }
  }

  void updateAuditLogsFilters({
    String? action,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) {
    if (action != null) _auditLogsActionFilter = action;
    if (startDate != null) _auditLogsStartDate = startDate;
    if (endDate != null) _auditLogsEndDate = endDate;
    if (searchQuery != null) _auditLogsSearchQuery = searchQuery;

    _auditLogsCurrentPage = 1;
    fetchAuditLogs();
  }

  void setAuditLogsPage(int page) {
    if (page >= 1 && page <= _auditLogsTotalPages) {
      _auditLogsCurrentPage = page;
      fetchAuditLogs();
    }
  }

  // Utility methods
  void _setLoading(bool loading, String screen) {
    switch (screen) {
      case 'dashboard':
        _isLoadingDashboard = loading;
        break;
      case 'jobs':
        _isLoadingJobs = loading;
        break;
      case 'applications':
        _isLoadingApplications = loading;
        break;
      case 'candidates':
        _isLoadingCandidates = loading;
        break;
      case 'interviews':
        _isLoadingInterviews = loading;
        break;
      case 'offers':
        _isLoadingOffers = loading;
        break;
      case 'auditLogs':
        _isLoadingAuditLogs = loading;
        break;
    }
    notifyListeners();
  }

  void _setError(String? error, String screen) {
    switch (screen) {
      case 'dashboard':
        _dashboardError = error;
        break;
      case 'jobs':
        _jobsError = error;
        break;
      case 'applications':
        _applicationsError = error;
        break;
      case 'candidates':
        _candidatesError = error;
        break;
      case 'interviews':
        _interviewsError = error;
        break;
      case 'offers':
        _offersError = error;
        break;
      case 'auditLogs':
        _auditLogsError = error;
        break;
    }
  }

  // Cache management
  T? _getCachedData<T>(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null ||
        DateTime.now().difference(timestamp) > _cacheExpiry) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
      return null;
    }
    return _cache[key] as T?;
  }

  void _setCachedData(String key, dynamic data) {
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
  }

  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  Future<void> refreshAllData() async {
    clearCache();
    await Future.wait([
      fetchDashboardStats(),
      fetchJobs(refresh: true),
      fetchApplications(refresh: true),
      fetchCandidates(refresh: true),
      fetchAuditLogs(refresh: true),
    ]);
  }

  @override
  void dispose() {
    clearCache();
    super.dispose();
  }
}
