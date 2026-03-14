import 'package:flutter/foundation.dart';
import '../services/admin_service.dart';

/// State management provider specifically for interview-related operations
class InterviewStateProvider extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  // Loading states
  bool _isLoadingInterviews = false;
  bool _isLoadingInterviewDetails = false;
  bool _isSubmittingFeedback = false;

  // Interviews data
  List<Map<String, dynamic>> _interviews = [];
  Map<String, dynamic> _interviewStatistics = {};
  Map<String, dynamic> _selectedInterviewDetails = {};
  List<Map<String, dynamic>> _interviewFeedback = [];
  int _interviewsCurrentPage = 1;
  int _interviewsTotalPages = 1;

  // Interviews filter properties
  String _interviewsSearchQuery = '';
  String? _interviewsSelectedStatus;
  String? _interviewsSelectedFilter;

  // Getters
  bool get isLoadingInterviews => _isLoadingInterviews;
  bool get isLoadingInterviewDetails => _isLoadingInterviewDetails;
  bool get isSubmittingFeedback => _isSubmittingFeedback;
  List<Map<String, dynamic>> get interviews => _interviews;
  Map<String, dynamic> get interviewStatistics => _interviewStatistics;
  Map<String, dynamic> get selectedInterviewDetails =>
      _selectedInterviewDetails;
  List<Map<String, dynamic>> get interviewFeedback => _interviewFeedback;
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

  void setSelectedInterviewDetails(Map<String, dynamic> details) {
    _selectedInterviewDetails = details;
    notifyListeners();
  }

  void setInterviewFeedback(List<Map<String, dynamic>> feedback) {
    _interviewFeedback = feedback;
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

  // API Methods
  Future<void> fetchInterviews({
    int page = 1,
    int perPage = 20,
    String? filter,
    String? status,
    String? search,
    bool refresh = false,
  }) async {
    if (refresh) {
      _interviewsCurrentPage = 1;
      _interviews.clear();
    }

    _isLoadingInterviews = true;
    notifyListeners();

    try {
      // For now, we'll use a placeholder implementation
      // This would need to be implemented in AdminService
      final List<Map<String, dynamic>> mockInterviews = [];

      _interviews = mockInterviews;
      _interviewsTotalPages = 1;
      _interviewsCurrentPage = page;

      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching interviews: $e');
      rethrow;
    } finally {
      _isLoadingInterviews = false;
      notifyListeners();
    }
  }

  Future<void> fetchInterviewDetails(int interviewId) async {
    _isLoadingInterviewDetails = true;
    notifyListeners();

    try {
      // Placeholder implementation
      final Map<String, dynamic> mockDetails = {};
      _selectedInterviewDetails = mockDetails;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching interview details: $e');
      rethrow;
    } finally {
      _isLoadingInterviewDetails = false;
      notifyListeners();
    }
  }

  Future<void> updateInterviewStatus(int interviewId, String status,
      {String? notes}) async {
    try {
      await _adminService.updateInterviewStatus(
        interviewId: interviewId,
        status: status,
      );

      // Update local state
      final index =
          _interviews.indexWhere((interview) => interview['id'] == interviewId);
      if (index != -1) {
        _interviews[index]['status'] = status;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating interview status: $e');
      rethrow;
    }
  }

  Future<void> cancelInterview(int interviewId) async {
    try {
      await _adminService.cancelInterview(interviewId);

      // Update local state
      final index =
          _interviews.indexWhere((interview) => interview['id'] == interviewId);
      if (index != -1) {
        _interviews[index]['status'] = 'cancelled';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error cancelling interview: $e');
      rethrow;
    }
  }

  Future<void> submitFeedback({
    required int interviewId,
    required int overallRating,
    required String recommendation,
  }) async {
    _isSubmittingFeedback = true;
    notifyListeners();

    try {
      await _adminService.submitInterviewFeedback(
        interviewId: interviewId,
        overallRating: overallRating,
        recommendation: recommendation,
      );

      // Update local state
      final index =
          _interviews.indexWhere((interview) => interview['id'] == interviewId);
      if (index != -1) {
        _interviews[index]['feedback_submitted'] = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
      rethrow;
    } finally {
      _isSubmittingFeedback = false;
      notifyListeners();
    }
  }

  Future<void> fetchInterviewFeedback(int interviewId) async {
    try {
      final feedback = await _adminService.getInterviewFeedback(interviewId);
      _interviewFeedback = feedback;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching interview feedback: $e');
      // Set empty feedback on error
      _interviewFeedback = <Map<String, dynamic>>[];
      notifyListeners();
    }
  }

  Future<void> refreshInterviews() async {
    await fetchInterviews(
      page: _interviewsCurrentPage,
      filter: _interviewsSelectedFilter,
      status: _interviewsSelectedStatus,
      search: _interviewsSearchQuery.isEmpty ? null : _interviewsSearchQuery,
      refresh: true,
    );
  }
}
