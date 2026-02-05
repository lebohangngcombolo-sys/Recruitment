import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/recruitment_service.dart';

class RecruitmentPipelinePage extends StatefulWidget {
  final String token;
  const RecruitmentPipelinePage({super.key, required this.token});

  @override
  _RecruitmentPipelinePageState createState() =>
      _RecruitmentPipelinePageState();
}

class _RecruitmentPipelinePageState extends State<RecruitmentPipelinePage> {
  late RecruitmentService _recruitmentService;
  List<Map<String, dynamic>> _requisitions = [];
  List<Map<String, dynamic>> _applications = [];
  List<Map<String, dynamic>> _interviews = [];
  List<Map<String, dynamic>> _offers = [];
  Map<String, dynamic> _quickStats = {};
  List<Map<String, dynamic>> _pipelineStages = [];
  Map<String, dynamic> _analytics = {};

  bool _isLoading = true;
  bool _isRefreshing = false;
  String _selectedFilter = 'all';
  String _selectedView = 'pipeline';
  int _activeTab = 0;

  int _totalApplications = 0;
  int _activeJobs = 0;
  int _offersSent = 0;

  @override
  void initState() {
    super.initState();
    _recruitmentService = RecruitmentService(widget.token);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      final pipelineData = await _recruitmentService.loadPipelineData(
        filter: _selectedFilter == 'all' ? null : _selectedFilter,
      );

      final requisitionsData = await _recruitmentService.loadRequisitionsData();
      final analyticsData = await _recruitmentService.loadAnalyticsData();

      setState(() {
        _quickStats = pipelineData['quickStats'] ?? {};
        _pipelineStages =
            List<Map<String, dynamic>>.from(pipelineData['stages'] ?? []);
        _applications = List<Map<String, dynamic>>.from(
            pipelineData['applications']?['applications'] ?? []);
        _totalApplications =
            pipelineData['applications']?['total'] ?? _applications.length;
        _interviews =
            List<Map<String, dynamic>>.from(pipelineData['interviews'] ?? []);
        _offers = List<Map<String, dynamic>>.from(pipelineData['offers'] ?? []);

        _requisitions =
            List<Map<String, dynamic>>.from(requisitionsData['jobs'] ?? []);
        _activeJobs =
            _requisitions.where((r) => r['status'] == 'active').length;
        _offersSent = _offers.length;

        _analytics = analyticsData;

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      _showErrorSnackbar('Failed to load data. Please try again.');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    try {
      setState(() => _isRefreshing = true);

      final refreshedData = await _recruitmentService.refreshAllData();

      setState(() {
        _applications = List<Map<String, dynamic>>.from(
            refreshedData['applications'] ?? []);
        _interviews =
            List<Map<String, dynamic>>.from(refreshedData['interviews'] ?? []);
        _offers =
            List<Map<String, dynamic>>.from(refreshedData['offers'] ?? []);
        _requisitions =
            List<Map<String, dynamic>>.from(refreshedData['jobs'] ?? []);

        _activeJobs =
            _requisitions.where((r) => r['status'] == 'active').length;
        _offersSent = _offers.length;
        _totalApplications = _applications.length;

        _isRefreshing = false;
      });

      _showSuccessSnackbar('Data refreshed successfully');
    } catch (e) {
      debugPrint('Error refreshing data: $e');
      _showErrorSnackbar('Failed to refresh data');
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadTabData(int tabIndex) async {
    try {
      setState(() => _isLoading = true);

      switch (tabIndex) {
        case 0: // Pipeline
          final pipelineData = await _recruitmentService.loadPipelineData(
            filter: _selectedFilter == 'all' ? null : _selectedFilter,
          );
          setState(() {
            _quickStats = pipelineData['quickStats'] ?? {};
            _pipelineStages =
                List<Map<String, dynamic>>.from(pipelineData['stages'] ?? []);
            _applications = List<Map<String, dynamic>>.from(
                pipelineData['applications']?['applications'] ?? []);
            _interviews = List<Map<String, dynamic>>.from(
                pipelineData['interviews'] ?? []);
            _offers =
                List<Map<String, dynamic>>.from(pipelineData['offers'] ?? []);
          });
          break;

        case 1: // Requisitions
          final requisitionsData =
              await _recruitmentService.loadRequisitionsData();
          setState(() {
            _requisitions =
                List<Map<String, dynamic>>.from(requisitionsData['jobs'] ?? []);
            _activeJobs =
                _requisitions.where((r) => r['status'] == 'active').length;
          });
          break;

        case 2: // Calendar
          final calendarData = await _recruitmentService.loadCalendarData();
          setState(() {
            _interviews = List<Map<String, dynamic>>.from(
                calendarData['todayInterviews'] ?? []);
            // Note: You might want to load upcoming and past interviews separately
          });
          break;

        case 3: // Analytics
          final analyticsData = await _recruitmentService.loadAnalyticsData();
          setState(() {
            _analytics = analyticsData;
          });
          break;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading tab data: $e');
      _showErrorSnackbar('Failed to load data');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateApplicationStatus(
      int applicationId, String status) async {
    try {
      final success = await _recruitmentService.updateApplicationStatus(
          applicationId, status);
      if (success) {
        _showSuccessSnackbar('Status updated successfully');
        // Refresh the applications list
        final index =
            _applications.indexWhere((app) => app['id'] == applicationId);
        if (index != -1) {
          setState(() {
            _applications[index]['status'] = status;
          });
        }
      } else {
        _showErrorSnackbar('Failed to update status');
      }
    } catch (e) {
      debugPrint('Error updating application status: $e');
      _showErrorSnackbar('Failed to update status');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredApplications() {
    if (_selectedFilter == 'all') return _applications;
    return _applications
        .where((app) => app['status'] == _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              "assets/images/dark.png",
              fit: BoxFit.cover,
            ),
          ),

          // Foreground Content
          Column(
            children: [
              _buildHeader(),
              _buildFilterBar(),
              const SizedBox(height: 8),

              // Loading Indicator
              if (_isLoading && !_isRefreshing) const LinearProgressIndicator(),

              // Main Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  child: IndexedStack(
                    index: _activeTab,
                    children: [
                      _buildPipelineView(),
                      _buildRequisitionsView(),
                      _buildCalendarView(),
                      _buildAnalyticsView(),
                      _buildTeamView(), // Placeholder for Team tab
                      _buildSettingsView(), // Placeholder for Settings tab
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).round()),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button and title section
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recruitment Pipeline',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage candidates and track hiring progress',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  _buildStatCard(
                    'Active Jobs',
                    '$_activeJobs',
                    const Color.fromARGB(255, 135, 20, 20),
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Total Candidates',
                    '$_totalApplications',
                    Colors.blueAccent,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Offers Sent',
                    '$_offersSent',
                    Colors.green,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Navigation Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildNavTab('Pipeline', 0),
                _buildNavTab('Requisitions', 1),
                _buildNavTab('Calendar', 2),
                _buildNavTab('Analytics', 3),
                _buildNavTab('Team', 4),
                _buildNavTab('Settings', 5),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab(String title, int index) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _activeTab = index);
        _loadTabData(index);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color.fromARGB(255, 135, 20, 20)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color.fromARGB(255, 135, 20, 20)
                : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          // View Toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildViewButton('Pipeline', Icons.view_column_outlined),
                _buildViewButton('List', Icons.view_list_outlined),
                _buildViewButton('Board', Icons.view_agenda_outlined),
              ],
            ),
          ),
          const Spacer(),

          // Search
          Container(
            width: 300,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search candidates, jobs...',
                      hintStyle: GoogleFonts.inter(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                    style: GoogleFonts.inter(fontSize: 14),
                    onChanged: (query) {
                      // Implement search functionality
                      if (query.isEmpty) {
                        _loadTabData(_activeTab);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Filters
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _selectedFilter = value);
              _loadTabData(_activeTab);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Candidates')),
              const PopupMenuItem(value: 'screening', child: Text('Screening')),
              const PopupMenuItem(value: 'interview', child: Text('Interview')),
              const PopupMenuItem(
                  value: 'assessment', child: Text('Assessment')),
              const PopupMenuItem(value: 'offer', child: Text('Offer Stage')),
              const PopupMenuItem(value: 'hired', child: Text('Hired')),
              const PopupMenuItem(value: 'rejected', child: Text('Rejected')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_alt_outlined,
                      color: Colors.grey.shade600, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _selectedFilter == 'all' ? 'All Status' : _selectedFilter,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down,
                      color: Colors.grey.shade600, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Add New Button
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to create requisition page
              // Navigator.push(...);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 135, 20, 20),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              'New Requisition',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewButton(String title, IconData icon) {
    final isActive = _selectedView == title.toLowerCase();
    return GestureDetector(
      onTap: () => setState(() => _selectedView = title.toLowerCase()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.05).round()),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive
                  ? const Color.fromARGB(255, 135, 20, 20)
                  : Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? const Color.fromARGB(255, 135, 20, 20)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredApplications = _getFilteredApplications();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pipeline Stages from API
          if (_pipelineStages.isNotEmpty)
            SizedBox(
              height: 220,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _pipelineStages.map((stage) {
                  final stageName = stage['stage_name'] ?? '';
                  final count = stage['count'] ?? 0;
                  final color = _getStageColor(stageName);
                  final icon = _getStageIcon(stageName);

                  return _buildPipelineStage(stageName, icon, count, color);
                }).toList(),
              ),
            )
          else
            SizedBox(
              height: 220,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildPipelineStage(
                      'Screening', Icons.filter_list, 0, Colors.blue),
                  _buildPipelineStage(
                      'Assessment', Icons.assessment, 0, Colors.orange),
                  _buildPipelineStage(
                      'Interview', Icons.video_call, 0, Colors.purple),
                  _buildPipelineStage(
                      'Offer', Icons.work_outline, 0, Colors.green),
                  _buildPipelineStage('Hired', Icons.check_circle, 0,
                      const Color.fromARGB(255, 135, 20, 20)),
                ],
              ),
            ),
          const SizedBox(height: 32),

          // Recent Applications
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Applications',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              Text(
                'Total: $_totalApplications',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (filteredApplications.isEmpty)
            _buildEmptyState('No applications found'),
          if (_selectedView == 'pipeline')
            _buildApplicationsGrid(filteredApplications)
          else if (_selectedView == 'list')
            _buildApplicationsList(filteredApplications)
          else
            _buildApplicationsBoard(filteredApplications),
        ],
      ),
    );
  }

  Widget _buildPipelineStage(
      String title, IconData icon, int count, Color color) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            _capitalize(title),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$count candidates',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: count / (_totalApplications > 0 ? _totalApplications : 1),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsGrid(List<Map<String, dynamic>> applications) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: applications.length,
      itemBuilder: (context, index) {
        final app = applications[index];
        return _buildApplicationCard(app);
      },
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> app) {
    final status = app['status'] ?? 'screening';
    final statusColor = _getStatusColor(status);
    final recommendation = app['recommendation'] ?? 'moderate';
    final recommendationColor = _getRecommendationColor(recommendation);
    final candidateName = app['candidate_name'] ??
        app['candidate']?['name'] ??
        'Unknown Candidate';
    final jobTitle =
        app['requisition_title'] ?? app['job']?['title'] ?? 'Unknown Position';
    final cvScore = app['cv_score'] ?? app['score'] ?? 0;
    final assessmentScore = app['assessment_score'] ?? 0;
    final appliedDate = app['applied_date'] ??
        app['created_at'] ??
        DateTime.now().toIso8601String();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha((255 * 0.1).round()),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _capitalize(status),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: recommendationColor.withAlpha((255 * 0.1).round()),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _capitalize(recommendation),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: recommendationColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              candidateName,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              jobTitle,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildScoreIndicator('CV', cvScore),
                const SizedBox(width: 12),
                _buildScoreIndicator('Assessment', assessmentScore),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM dd').format(DateTime.parse(appliedDate)),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) =>
                      _updateApplicationStatus(app['id'], value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'screening', child: Text('Move to Screening')),
                    const PopupMenuItem(
                        value: 'assessment', child: Text('Move to Assessment')),
                    const PopupMenuItem(
                        value: 'interview', child: Text('Move to Interview')),
                    const PopupMenuItem(
                        value: 'offer', child: Text('Move to Offer')),
                    const PopupMenuItem(
                        value: 'hired', child: Text('Mark as Hired')),
                    const PopupMenuItem(
                        value: 'rejected', child: Text('Reject')),
                  ],
                  child: Icon(Icons.more_vert,
                      color: Colors.grey.shade500, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationsList(List<Map<String, dynamic>> applications) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: applications.map((app) {
          return _buildApplicationListItem(app);
        }).toList(),
      ),
    );
  }

  Widget _buildApplicationListItem(Map<String, dynamic> app) {
    final status = app['status'] ?? 'screening';
    final statusColor = _getStatusColor(status);
    final candidateName = app['candidate_name'] ??
        app['candidate']?['name'] ??
        'Unknown Candidate';
    final jobTitle =
        app['requisition_title'] ?? app['job']?['title'] ?? 'Unknown Position';
    final overallScore = app['overall_score'] ?? app['score'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      const Color.fromARGB(255, 135, 20, 20).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    candidateName.substring(0, 2).toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color.fromARGB(255, 135, 20, 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidateName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      jobTitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _capitalize(status),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '$overallScore%',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 16),
              PopupMenuButton<String>(
                onSelected: (value) =>
                    _updateApplicationStatus(app['id'], value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'screening', child: Text('Move to Screening')),
                  const PopupMenuItem(
                      value: 'assessment', child: Text('Move to Assessment')),
                  const PopupMenuItem(
                      value: 'interview', child: Text('Move to Interview')),
                  const PopupMenuItem(
                      value: 'offer', child: Text('Move to Offer')),
                  const PopupMenuItem(
                      value: 'hired', child: Text('Mark as Hired')),
                  const PopupMenuItem(value: 'rejected', child: Text('Reject')),
                ],
                child: Icon(Icons.more_vert, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.grey.shade200, height: 1),
        ],
      ),
    );
  }

  Widget _buildApplicationsBoard(List<Map<String, dynamic>> applications) {
    final columns = ['screening', 'assessment', 'interview', 'offer', 'hired'];

    return SizedBox(
      height: 600,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: columns.length,
        itemBuilder: (context, columnIndex) {
          final columnName = columns[columnIndex];
          final columnApps =
              applications.where((app) => app['status'] == columnName).toList();

          return Container(
            width: 320,
            margin: EdgeInsets.only(
                right: columnIndex < columns.length - 1 ? 16 : 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _capitalize(columnName),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 135, 20, 20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${columnApps.length}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.add,
                          color: const Color.fromARGB(255, 135, 20, 20),
                          size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: columnApps.length,
                    itemBuilder: (context, index) {
                      final app = columnApps[index];
                      return _buildBoardCard(app);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBoardCard(Map<String, dynamic> app) {
    final candidateName = app['candidate_name'] ??
        app['candidate']?['name'] ??
        'Unknown Candidate';
    final jobTitle =
        app['requisition_title'] ?? app['job']?['title'] ?? 'Unknown Position';
    final overallScore = app['overall_score'] ?? app['score'] ?? 0;
    final nextInterview =
        app['next_interview'] ?? app['interview_scheduled_at'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  candidateName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.drag_handle, color: Colors.grey.shade400, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            jobTitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      const Color.fromARGB(255, 135, 20, 20).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$overallScore%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color.fromARGB(255, 135, 20, 20),
                  ),
                ),
              ),
              const Spacer(),
              if (nextInterview != null)
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM dd')
                          .format(DateTime.parse(nextInterview)),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequisitionsView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Stats
          Row(
            children: [
              Expanded(
                child: _buildRequisitionStatCard(
                  'Open Positions',
                  '${_requisitions.where((r) => r['status'] == 'active').length}',
                  const Color.fromARGB(255, 135, 20, 20),
                  Icons.work_outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildRequisitionStatCard(
                  'Total Applicants',
                  '$_totalApplications',
                  Colors.blueAccent,
                  Icons.people_outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildRequisitionStatCard(
                  'Applications Today',
                  '${_quickStats['applications_today'] ?? 0}',
                  Colors.green,
                  Icons.timeline_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildRequisitionStatCard(
                  'Interview Rate',
                  '${_quickStats['interview_rate'] ?? '0%'}',
                  Colors.purple,
                  Icons.video_call_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Active Requisitions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Requisitions',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              Text(
                'Total: ${_requisitions.length}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_requisitions.isEmpty) _buildEmptyState('No requisitions found'),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
            ),
            itemCount: _requisitions.length,
            itemBuilder: (context, index) {
              final req = _requisitions[index];
              return _buildRequisitionCard(req);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequisitionStatCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequisitionCard(Map<String, dynamic> req) {
    final isActive = req['status'] == 'active';
    final title = req['title'] ?? 'Untitled Position';
    final category = req['category'] ?? req['department'] ?? 'General';
    final applicationsCount =
        req['applications_count'] ?? req['application_count'] ?? 0;
    final vacancy = req['vacancy'] ?? req['positions'] ?? 1;
    final progress = req['progress'] ??
        ((applicationsCount / (vacancy * 10)) * 100).clamp(0, 100).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color.fromARGB(255, 135, 20, 20)
                            .withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Closed',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? const Color.fromARGB(255, 135, 20, 20)
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.more_vert,
                      color: Colors.grey.shade500, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              category,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                  const Color.fromARGB(255, 135, 20, 20)),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.people_outline,
                        size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      '$applicationsCount applicants',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.work_outline,
                        size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      '$vacancy vacancy',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((255 * 0.05).round()),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon:
                          Icon(Icons.chevron_left, color: Colors.grey.shade600),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(DateTime.now()),
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.chevron_right,
                          color: Colors.grey.shade600),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildCalendarViewButton('Day'),
                    _buildCalendarViewButton('Week'),
                    _buildCalendarViewButton('Month', isActive: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Today's Interviews
          Text(
            "Today's Interviews",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),

          if (_interviews.isEmpty)
            _buildEmptyState('No interviews scheduled for today'),

          ..._interviews.map((interview) => _buildInterviewCard(interview)),

          const SizedBox(height: 32),

          // Pending Offers
          Text(
            'Pending Offers',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),

          if (_offers.isEmpty) _buildEmptyState('No pending offers'),

          ..._offers
              .where((offer) =>
                  offer['status'] == 'pending' || offer['status'] == 'sent')
              .map((offer) => _buildOfferCard(offer)),
        ],
      ),
    );
  }

  Widget _buildCalendarViewButton(String text, {bool isActive = false}) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? const Color.fromARGB(255, 135, 20, 20)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? const Color.fromARGB(255, 135, 20, 20)
              : Colors.grey.shade300,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isActive ? Colors.white : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildInterviewCard(Map<String, dynamic> interview) {
    final candidateName = interview['candidate_name'] ??
        interview['candidate']?['name'] ??
        'Unknown Candidate';
    final interviewType =
        interview['interview_type'] ?? interview['type'] ?? 'Interview';
    final scheduledTime = DateTime.parse(interview['scheduled_time'] ??
        interview['interview_date'] ??
        DateTime.now().toIso8601String());
    final interviewer = interview['interviewer'] ??
        interview['interviewer_name'] ??
        'Unknown Interviewer';
    final meetingLink = interview['meeting_link'] ?? interview['meeting_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 135, 20, 20).withAlpha((255 * 0.1).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('EEE').format(scheduledTime),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color.fromARGB(255, 135, 20, 20),
                  ),
                ),
                Text(
                  scheduledTime.day.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color.fromARGB(255, 135, 20, 20),
                  ),
                ),
                Text(
                  DateFormat('MMM').format(scheduledTime),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color:
                        const Color.fromARGB(255, 135, 20, 20).withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidateName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$interviewType Interview',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('h:mm a').format(scheduledTime),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.person_outline,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      interviewer,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (meetingLink != null && meetingLink.isNotEmpty)
            IconButton(
              onPressed: () {
                // Launch meeting link
              },
              icon: Icon(Icons.video_call,
                  color: const Color.fromARGB(255, 135, 20, 20), size: 24),
            ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final candidateName = offer['candidate_name'] ??
        offer['candidate']?['name'] ??
        'Unknown Candidate';
    final position =
        offer['position'] ?? offer['job_title'] ?? 'Unknown Position';
    final baseSalary = offer['base_salary'] ?? offer['salary'] ?? 'Negotiable';
    final contractType = offer['contract_type'] ?? 'Full-time';
    final status = offer['status'] ?? 'pending';
    final statusColor = status == 'accepted'
        ? Colors.green
        : status == 'rejected'
            ? Colors.red
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.work_outline, color: Colors.green, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidateName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  position,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.attach_money,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      baseSalary,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.business, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      contractType,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _capitalize(status),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final dashboardAnalytics = _analytics['dashboardAnalytics'] ?? {};
    final offerAnalytics = _analytics['offerAnalytics'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Analytics Overview
          Text(
            'Hiring Analytics',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Track recruitment performance and metrics',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),

          // Analytics Cards
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  'Time to Hire',
                  '${dashboardAnalytics['avg_time_to_hire'] ?? '28'} days',
                  Icons.timeline_outlined,
                  Colors.blue,
                  '↓ ${dashboardAnalytics['time_to_hire_change'] ?? '12'}% from last month',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard(
                  'Offer Acceptance',
                  '${offerAnalytics['acceptance_rate'] ?? '78'}%',
                  Icons.check_circle_outline,
                  Colors.green,
                  '↑ ${offerAnalytics['acceptance_change'] ?? '15'}% from last quarter',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard(
                  'Interview to Offer',
                  '${dashboardAnalytics['interview_to_offer_rate'] ?? '25'}%',
                  Icons.video_call_outlined,
                  Colors.purple,
                  '↓ ${dashboardAnalytics['interview_to_offer_change'] ?? '5'}% from last month',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Charts Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((255 * 0.05).round()),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Applications Trend',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 200,
                        child: _buildDummyChart(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((255 * 0.05).round()),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top Performers',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ..._applications
                          .where((app) =>
                              (app['overall_score'] ?? app['score'] ?? 0) >= 80)
                          .take(5)
                          .map((app) => _buildTopPerformerCard(app)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(
      String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: subtitle.contains('↑') ? Colors.green : Colors.redAccent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDummyChart() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          'Chart visualization would go here',
          style: GoogleFonts.inter(
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildTopPerformerCard(Map<String, dynamic> app) {
    final candidateName = app['candidate_name'] ??
        app['candidate']?['name'] ??
        'Unknown Candidate';
    final jobTitle =
        app['requisition_title'] ?? app['job']?['title'] ?? 'Unknown Position';
    final overallScore = app['overall_score'] ?? app['score'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 135, 20, 20).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                candidateName.substring(0, 2).toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color.fromARGB(255, 135, 20, 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidateName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Text(
                  jobTitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$overallScore%',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamView() {
    return const Center(
      child: Text('Team View - Coming Soon'),
    );
  }

  Widget _buildSettingsView() {
    return const Center(
      child: Text('Settings View - Coming Soon'),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreIndicator(String label, dynamic score) {
    final numScore = score is int
        ? score
        : score is double
            ? score.toInt()
            : 0;
    final color = numScore >= 80
        ? Colors.green
        : numScore >= 60
            ? Colors.orange
            : const Color.fromARGB(255, 135, 20, 20);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 60,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: numScore / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$numScore%',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper methods
  Color _getStatusColor(String status) {
    switch (status) {
      case 'screening':
        return Colors.blue;
      case 'assessment':
        return Colors.orange;
      case 'interview':
        return Colors.purple;
      case 'offer':
        return Colors.green;
      case 'hired':
        return const Color.fromARGB(255, 135, 20, 20);
      case 'rejected':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Color _getStageColor(String stageName) {
    switch (stageName.toLowerCase()) {
      case 'screening':
        return Colors.blue;
      case 'assessment':
        return Colors.orange;
      case 'interview':
        return Colors.purple;
      case 'offer':
        return Colors.green;
      case 'hired':
        return const Color.fromARGB(255, 135, 20, 20);
      default:
        return Colors.blue;
    }
  }

  IconData _getStageIcon(String stageName) {
    switch (stageName.toLowerCase()) {
      case 'screening':
        return Icons.filter_list;
      case 'assessment':
        return Icons.assessment;
      case 'interview':
        return Icons.video_call;
      case 'offer':
        return Icons.work_outline;
      case 'hired':
        return Icons.check_circle;
      default:
        return Icons.filter_list;
    }
  }

  Color _getRecommendationColor(String recommendation) {
    switch (recommendation.toLowerCase()) {
      case 'strong':
      case 'hire':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'reject':
        return const Color.fromARGB(255, 135, 20, 20);
      default:
        return Colors.grey;
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
