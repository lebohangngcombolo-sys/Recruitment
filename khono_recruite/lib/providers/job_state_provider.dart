import 'package:flutter/foundation.dart';
import '../services/admin_service.dart';

/// State management provider specifically for job-related operations
class JobStateProvider extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  // Loading states
  bool _isLoadingJobs = false;
  bool _isLoadingJobDetails = false;

  // Jobs data
  List<Map<String, dynamic>> _jobs = [];
  Map<String, dynamic> _jobStatistics = {};
  Map<String, dynamic> _selectedJobDetails = {};
  int _jobsCurrentPage = 1;
  int _jobsTotalPages = 1;
  String _jobsSortBy = 'created_at';
  String _jobsSortOrder = 'desc';

  // Jobs filter properties
  String _jobsStatusFilter = 'all';
  String _jobsCategoryFilter = 'all';
  String _jobsSearchQuery = '';

  // Getters
  bool get isLoadingJobs => _isLoadingJobs;
  bool get isLoadingJobDetails => _isLoadingJobDetails;
  List<Map<String, dynamic>> get jobs => _jobs;
  Map<String, dynamic> get jobStatistics => _jobStatistics;
  Map<String, dynamic> get selectedJobDetails => _selectedJobDetails;
  int get jobsCurrentPage => _jobsCurrentPage;
  int get jobsTotalPages => _jobsTotalPages;
  String get jobsSortBy => _jobsSortBy;
  String get jobsSortOrder => _jobsSortOrder;
  String get jobsStatusFilter => _jobsStatusFilter;
  String get jobsCategoryFilter => _jobsCategoryFilter;
  String get jobsSearchQuery => _jobsSearchQuery;

  // Jobs methods
  void setJobs(List<Map<String, dynamic>> jobs) {
    _jobs = jobs;
    notifyListeners();
  }

  void addJobs(List<Map<String, dynamic>> newJobs) {
    _jobs.addAll(newJobs);
    notifyListeners();
  }

  void setSelectedJobDetails(Map<String, dynamic> details) {
    _selectedJobDetails = details;
    notifyListeners();
  }

  void setJobsPage(int page) {
    if (page >= 1 && page <= _jobsTotalPages) {
      _jobsCurrentPage = page;
      notifyListeners();
    }
  }

  void setJobsSortBy(String sortBy) {
    _jobsSortBy = sortBy;
    notifyListeners();
  }

  void toggleJobsSortOrder() {
    _jobsSortOrder = _jobsSortOrder == 'desc' ? 'asc' : 'desc';
    notifyListeners();
  }

  void setJobsStatusFilter(String status) {
    _jobsStatusFilter = status;
    notifyListeners();
  }

  void setJobsCategoryFilter(String category) {
    _jobsCategoryFilter = category;
    notifyListeners();
  }

  void setJobsSearchQuery(String query) {
    _jobsSearchQuery = query;
    notifyListeners();
  }

  void clearJobs() {
    _jobs.clear();
    _jobsCurrentPage = 1;
    _jobsTotalPages = 1;
    _jobsSearchQuery = '';
    _jobsStatusFilter = 'all';
    _jobsCategoryFilter = 'all';
    notifyListeners();
  }

  // API Methods
  Future<void> fetchJobs({
    int page = 1,
    int perPage = 20,
    String? category,
    String status = 'active',
    String sortBy = 'created_at',
    String sortOrder = 'desc',
    String? search,
    bool refresh = false,
  }) async {
    if (refresh) {
      _jobsCurrentPage = 1;
      _jobs.clear();
    }

    _isLoadingJobs = true;
    notifyListeners();

    try {
      final response = await _adminService.listJobsEnhanced(
        page: page,
        perPage: perPage,
        category: category,
        status: status,
        sortBy: sortBy,
        sortOrder: sortOrder,
        search: search,
      );

      _jobs = List<Map<String, dynamic>>.from(response['jobs'] ?? []);
      _jobsTotalPages = response['pagination']?['total_pages'] ?? 1;
      _jobsCurrentPage = page;

      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching jobs: $e');
      rethrow;
    } finally {
      _isLoadingJobs = false;
      notifyListeners();
    }
  }

  Future<void> fetchJobDetails(int jobId) async {
    _isLoadingJobDetails = true;
    notifyListeners();

    try {
      final details = await _adminService.getJobDetailed(jobId);
      _selectedJobDetails = details;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching job details: $e');
      rethrow;
    } finally {
      _isLoadingJobDetails = false;
      notifyListeners();
    }
  }

  Future<void> createJob(Map<String, dynamic> jobData) async {
    try {
      final job = await _adminService.createJob(jobData);
      _jobs.insert(0, job);
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating job: $e');
      rethrow;
    }
  }

  Future<void> updateJob(int jobId, Map<String, dynamic> jobData) async {
    try {
      final updatedJob = await _adminService.updateJob(jobId, jobData);
      final index = _jobs.indexWhere((job) => job['id'] == jobId);
      if (index != -1) {
        _jobs[index] = updatedJob;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating job: $e');
      rethrow;
    }
  }

  Future<void> deleteJob(int jobId) async {
    try {
      await _adminService.deleteJob(jobId);
      _jobs.removeWhere((job) => job['id'] == jobId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting job: $e');
      rethrow;
    }
  }

  Future<void> refreshJobs() async {
    await fetchJobs(
      page: _jobsCurrentPage,
      category: _jobsCategoryFilter == 'all' ? null : _jobsCategoryFilter,
      status: _jobsStatusFilter,
      sortBy: _jobsSortBy,
      sortOrder: _jobsSortOrder,
      search: _jobsSearchQuery.isEmpty ? null : _jobsSearchQuery,
      refresh: true,
    );
  }
}
