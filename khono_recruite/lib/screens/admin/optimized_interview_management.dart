import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../providers/theme_provider.dart';
import '../../providers/admin_state_provider.dart';
import '../../utils/api_endpoints.dart';
import '../../utils/global_error_handler.dart';
import 'interview_detail_dialog.dart';

/// Optimized interview management screen with proper state management
class OptimizedInterviewManagement extends StatefulWidget {
  const OptimizedInterviewManagement({super.key});

  @override
  State<OptimizedInterviewManagement> createState() =>
      _OptimizedInterviewManagementState();
}

class _OptimizedInterviewManagementState
    extends State<OptimizedInterviewManagement>
    with AutomaticKeepAliveClientMixin {
  final AdminService _adminService = AdminService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  String _selectedFilter = 'all';
  String _selectedStatus = 'all';
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _loadInterviews(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadInterviews();
      }
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _loadInterviews(refresh: true);
    });
  }

  Future<void> _loadInterviews({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }

    if (!_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final adminProvider =
          Provider.of<AdminStateProvider>(context, listen: false);

      final queryParams = {
        'page': _currentPage.toString(),
        'per_page': '20',
        'filter': _selectedFilter,
        'status': _selectedStatus,
        'search': _searchController.text.trim(),
      };

      final uri = Uri.parse('${ApiEndpoints.adminBase}/interviews/all')
          .replace(queryParameters: queryParams);

      final response = await AuthService.authorizedGet(uri.toString());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newInterviews = List<Map<String, dynamic>>.from(
          data['interviews'] ?? [],
        );

        if (refresh) {
          adminProvider.setInterviews(newInterviews);
        } else {
          adminProvider.addInterviews(newInterviews);
        }

        _hasMore = newInterviews.length == 20;
        _currentPage++;
      } else {
        context.showError(
          Exception('Failed to load interviews'),
          context: 'Loading interviews',
          onRetry: () => _loadInterviews(refresh: refresh),
        );
      }
    } catch (e) {
      context.showError(
        e,
        context: 'Loading interviews',
        onRetry: () => _loadInterviews(refresh: refresh),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateInterviewStatus(int interviewId, String status) async {
    try {
      await _adminService.updateInterviewStatus(
        interviewId: interviewId,
        status: status,
      );

      context.showSuccess('Interview status updated');
      _loadInterviews(refresh: true);
    } catch (e) {
      context.showError(
        e,
        context: 'Updating interview status',
        onRetry: () => _updateInterviewStatus(interviewId, status),
      );
    }
  }

  Future<void> _cancelInterview(int interviewId) async {
    try {
      await _adminService.cancelInterview(interviewId);
      context.showSuccess('Interview cancelled');
      _loadInterviews(refresh: true);
    } catch (e) {
      context.showError(
        e,
        context: 'Cancelling interview',
        onRetry: () => _cancelInterview(interviewId),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor:
          themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Header
          SliverAppBar(
            title: Text(
              'Interview Management',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
            floating: true,
            elevation: 0,
            backgroundColor:
                themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.white,
            actions: [
              IconButton(
                onPressed: () => _loadInterviews(refresh: true),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),

          // Search and Filters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search interviews...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: themeProvider.isDarkMode
                          ? Colors.grey.shade800
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filter Chips
                  _buildFilterChips(themeProvider),
                ],
              ),
            ),
          ),

          // Interview List
          Consumer<AdminStateProvider>(
            builder: (context, provider, child) {
              final interviews = provider.interviews;

              if (interviews.isEmpty && !_isLoading) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 64,
                          color: themeProvider.isDarkMode
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Interviews Found',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == interviews.length) {
                      return _isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : const SizedBox.shrink();
                    }

                    final interview = interviews[index];
                    return InterviewCard(
                      interview: interview,
                      onStatusUpdate: _updateInterviewStatus,
                      onCancel: _cancelInterview,
                      onTap: () => _showInterviewDetails(interview),
                    );
                  },
                  childCount: interviews.length + (_isLoading ? 1 : 0),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ThemeProvider themeProvider) {
    final filters = [
      {'value': 'all', 'label': 'All'},
      {'value': 'today', 'label': 'Today'},
      {'value': 'upcoming', 'label': 'Upcoming'},
      {'value': 'past', 'label': 'Past'},
      {'value': 'action_required', 'label': 'Action Required'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter['label']!),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedFilter = filter['value']!);
                  _loadInterviews(refresh: true);
                }
              },
              backgroundColor: themeProvider.isDarkMode
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
              selectedColor: const Color(0xFFC10D00).withOpacity(0.2),
              checkmarkColor: const Color(0xFFC10D00),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showInterviewDetails(Map<String, dynamic> interview) {
    showDialog(
      context: context,
      builder: (context) => InterviewDetailDialog(
        interview: interview,
        onStatusUpdate: _updateInterviewStatus,
        onCancel: _cancelInterview,
      ),
    );
  }
}

/// Individual interview card widget
class InterviewCard extends StatelessWidget {
  final Map<String, dynamic> interview;
  final Function(int, String) onStatusUpdate;
  final Function(int) onCancel;
  final VoidCallback onTap;

  const InterviewCard({
    super.key,
    required this.interview,
    required this.onStatusUpdate,
    required this.onCancel,
    required this.onTap,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'rescheduled':
        return Colors.orange;
      case 'feedback_pending':
        return Colors.amber;
      case 'no_show':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'Not scheduled';

    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, yyyy - hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final status = interview['status'] ?? 'scheduled';
    final candidate = interview['candidate'] ?? {};

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      candidate['full_name'] ?? 'Unknown Candidate',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(status).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Interview details
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatDateTime(interview['scheduled_time']),
                      style: TextStyle(
                        fontSize: 14,
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),

              if (interview['interview_type'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.category,
                      size: 16,
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      interview['interview_type'],
                      style: TextStyle(
                        fontSize: 14,
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (status == 'scheduled')
                    TextButton(
                      onPressed: () =>
                          onStatusUpdate(interview['id'], 'completed'),
                      child: const Text('Mark Complete'),
                    ),
                  if (status == 'scheduled' || status == 'rescheduled')
                    TextButton(
                      onPressed: () => onCancel(interview['id']),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Cancel'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
