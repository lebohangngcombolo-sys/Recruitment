import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/admin_service.dart';
import '../../providers/theme_provider.dart';
import '../../constants/brand_tokens.dart';
import '../../widgets/state_widgets.dart';

class AdminPipelinePage extends StatefulWidget {
  final bool embedded;

  const AdminPipelinePage({
    super.key,
    this.embedded = false,
  });

  @override
  State<AdminPipelinePage> createState() => _AdminPipelinePageState();
}

class _AdminPipelinePageState extends State<AdminPipelinePage> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _pipelineStages = [];

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
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      final pipelineData = await _adminService.loadPipelineData();

      setState(() {
        _pipelineStages = pipelineData['stages'] ?? [];
        _totalApplications = pipelineData['total_applications'] ?? 0;
        _activeJobs = pipelineData['active_jobs'] ?? 0;
        _offersSent = pipelineData['offers_sent'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading pipeline data: $e'),
            backgroundColor: BrandTokens.primary,
          ),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await _loadInitialData();
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final page = Column(
      children: [
        _buildHeader(),
        _buildFilterBar(),
        const SizedBox(height: 8),

        // Loading Indicator
        if (_isLoading && !_isRefreshing) const LinearLoadingIndicator(),

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
                _buildTeamView(),
                _buildSettingsView(),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return page;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              themeProvider.backgroundImage,
              fit: BoxFit.cover,
            ),
          ),
          page,
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:
            themeProvider.isDarkMode ? BrandTokens.darkSurface : Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                  if (!widget.embedded) ...[
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: BrandTokens.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: BrandTokens.primary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Pipeline',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage recruitment workflow',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: themeProvider.isDarkMode
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Stats row
              Row(
                children: [
                  _buildStatCard('Applications', _totalApplications.toString(),
                      Icons.people_outline),
                  const SizedBox(width: 12),
                  _buildStatCard('Active Jobs', _activeJobs.toString(),
                      Icons.work_outline),
                  const SizedBox(width: 12),
                  _buildStatCard(
                      'Offers Sent', _offersSent.toString(), Icons.send),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: BrandTokens.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        border: Border.all(color: BrandTokens.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: BrandTokens.primary, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: BrandTokens.primary,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: themeProvider.isDarkMode
                      ? Colors.white70
                      : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? BrandTokens.darkSurface
                    : Colors.white,
                borderRadius: BorderRadius.circular(BrandTokens.searchRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search applications...',
                  prefixIcon: Icon(Icons.search, color: BrandTokens.primary),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(BrandTokens.searchRadius),
                    borderSide: BorderSide(
                        color: BrandTokens.primary.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(BrandTokens.searchRadius),
                    borderSide:
                        BorderSide(color: BrandTokens.primary, width: 2),
                  ),
                  fillColor: themeProvider.isDarkMode
                      ? BrandTokens.darkSurface
                      : Colors.white,
                  filled: true,
                  hintStyle: GoogleFonts.inter(
                      color: themeProvider.isDarkMode
                          ? Colors.white70
                          : Colors.black54),
                ),
                onChanged: (value) {
                  // Implement search functionality
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: BrandTokens.primary,
              borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                icon: Icon(Icons.filter_list, color: Colors.white, size: 20),
                dropdownColor: themeProvider.isDarkMode
                    ? BrandTokens.darkSurface
                    : Colors.white,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(value: 'applied', child: Text('Applied')),
                  DropdownMenuItem(
                      value: 'screening', child: Text('Screening')),
                  DropdownMenuItem(
                      value: 'assessment', child: Text('Assessment')),
                  DropdownMenuItem(
                      value: 'interview', child: Text('Interview')),
                  DropdownMenuItem(value: 'offer', child: Text('Offer')),
                  DropdownMenuItem(value: 'hired', child: Text('Hired')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (value) {
                  setState(() => _selectedFilter = value!);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pipeline Stages
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
                  _buildPipelineStage(
                      'Hired', Icons.check_circle, 0, BrandTokens.primary),
                ],
              ),
            ),
          const SizedBox(height: 32),

          // Recent Applications
          Text(
            'Recent Applications',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Total: $_totalApplications',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineStage(
      String title, IconData icon, int count, Color color) {
    final isActive = _selectedView == title.toLowerCase();

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: isActive
            ? BrandTokens.primary.withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _selectedView = title.toLowerCase());
          },
          borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: isActive ? BrandTokens.primary : Colors.grey.shade500,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color:
                        isActive ? BrandTokens.primary : Colors.grey.shade600,
                  ),
                ),
                if (count > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: BrandTokens.primary,
                      borderRadius:
                          BorderRadius.circular(BrandTokens.badgeRadius),
                    ),
                    child: Text(
                      count.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
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
        return BrandTokens.primary;
      default:
        return Colors.grey;
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
        return Icons.help_outline;
    }
  }

  Widget _buildRequisitionsView() {
    return Center(
      child: Text(
        'Requisitions management coming soon',
        style: GoogleFonts.poppins(fontSize: 16),
      ),
    );
  }

  Widget _buildCalendarView() {
    return Center(
      child: Text(
        'Calendar view coming soon',
        style: GoogleFonts.poppins(fontSize: 16),
      ),
    );
  }

  Widget _buildAnalyticsView() {
    return Center(
      child: Text(
        'Analytics view coming soon',
        style: GoogleFonts.poppins(fontSize: 16),
      ),
    );
  }

  Widget _buildTeamView() {
    return Center(
      child: Text(
        'Team collaboration coming soon',
        style: GoogleFonts.poppins(fontSize: 16),
      ),
    );
  }

  Widget _buildSettingsView() {
    return Center(
      child: Text(
        'Settings coming soon',
        style: GoogleFonts.poppins(fontSize: 16),
      ),
    );
  }
}
