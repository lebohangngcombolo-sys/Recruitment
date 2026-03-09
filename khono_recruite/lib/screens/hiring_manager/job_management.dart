// ignore_for_file: dead_code, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/weighting_configuration_widget.dart';
import '../../widgets/knockout_rules_builder.dart';
import '../../services/admin_service.dart';
import '../../services/ai_service.dart';
import '../../services/test_pack_service.dart';
import '../../models/test_pack.dart';
import '../../widgets/save_test_pack_dialog.dart';
import '../../providers/theme_provider.dart';

class JobManagement extends StatefulWidget {
  final Function(int jobId)? onJobSelected;

  const JobManagement({super.key, this.onJobSelected});

  @override
  _JobManagementState createState() => _JobManagementState();
}

class _JobManagementState extends State<JobManagement> {
  final AdminService admin = AdminService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> jobs = [];
  bool loading = true;
  String _statusFilter = 'active'; // active, inactive, all
  String? _categoryFilter; // null = all
  final Set<int> _expandedJobIds = {};
  final Map<int, List<dynamic>> _applicationsByJob = {};
  final Set<int> _loadingApplications = {};
  static const List<String> _categoryOptions = [
    'Engineering',
    'Marketing',
    'Sales',
    'HR',
    'Finance',
    'Operations',
    'Customer Service',
    'Product',
    'Design',
    'Data Science',
  ];

  @override
  void initState() {
    super.initState();
    fetchJobs();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchJobs() async {
    setState(() => loading = true);
    try {
      final data = await admin.listJobsEnhanced(
        page: 1,
        perPage: 500,
        search: null,
        category: _categoryFilter,
        status: _statusFilter,
        sortBy: 'created_at',
        sortOrder: 'desc',
      );
      final list = data['jobs'];
      jobs = list != null ? List<Map<String, dynamic>>.from(list) : [];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error fetching jobs: $e",
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
          ),
        );
      }
      jobs = [];
    }
    if (mounted) setState(() => loading = false);
  }

  void _applySearch() => setState(() {});

  List<Map<String, dynamic>> _filteredJobs() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return jobs;
    final words =
        query.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (words.isEmpty) return jobs;
    return jobs.where((job) {
      final title = (job['title'] ?? '').toString().toLowerCase();
      final category = (job['category'] ?? '').toString().toLowerCase();
      final description = (job['description'] ?? '').toString().toLowerCase();
      final createdBy = job['created_by_user'] != null
          ? ((job['created_by_user']['name'] ??
                  job['created_by_user']['email'] ??
                  '') as String)
              .toLowerCase()
          : '';
      final searchable = '$title $category $description $createdBy';
      return words.every((word) => searchable.contains(word));
    }).toList();
  }

  Future<void> _fetchApplicationsForJob(int jobId) async {
    if (_applicationsByJob.containsKey(jobId)) return;
    setState(() => _loadingApplications.add(jobId));
    try {
      final list = await admin.getJobApplications(jobId, perPage: 100);
      if (mounted)
        setState(() {
          _applicationsByJob[jobId] = list;
          _loadingApplications.remove(jobId);
        });
    } catch (e) {
      if (mounted) setState(() => _loadingApplications.remove(jobId));
    }
  }

  void _toggleJobExpanded(int jobId) {
    setState(() {
      if (_expandedJobIds.contains(jobId)) {
        _expandedJobIds.remove(jobId);
      } else {
        _expandedJobIds.add(jobId);
        _fetchApplicationsForJob(jobId);
      }
    });
  }

  Widget _tableHeaderCell(
    String label, {
    required int flex,
    required ThemeProvider themeProvider,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildExpandableJobRow(
    Map<String, dynamic> job,
    ThemeProvider themeProvider,
  ) {
    final jobId = job['id'] as int;
    final isExpanded = _expandedJobIds.contains(jobId);
    final createdBy = job['created_by_user'] != null
        ? (job['created_by_user']['name'] ??
            job['created_by_user']['email'] ??
            'Unknown')
        : '—';
    final isActive = job['is_active'] == true;
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _toggleJobExpanded(jobId),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isExpanded && themeProvider.isDarkMode
                  ? Colors.grey.shade800.withValues(alpha: 0.5)
                  : isExpanded
                      ? Colors.grey.shade100
                      : null,
              border: Border(
                bottom: BorderSide(
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade800
                      : Colors.grey.shade300,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    job['title'] ?? '—',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    job['category'] ?? '—',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '${job['application_count'] ?? 0}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: textColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: isActive
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    createdBy,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.blueAccent,
                          size: 20,
                        ),
                        onPressed: () => openJobForm(job: job),
                        tooltip: 'Edit',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () async {
                          try {
                            await admin.deleteJob(jobId);
                            fetchJobs();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Error deleting job: $e",
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        tooltip: 'Delete',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      if (widget.onJobSelected != null)
                        IconButton(
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          onPressed: () => widget.onJobSelected!(jobId),
                          tooltip: 'Select Job',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: textColor,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          _buildExpandedApplicantsSection(jobId, job, themeProvider),
      ],
    );
  }

  Widget _buildExpandedApplicantsSection(
    int jobId,
    Map<String, dynamic> job,
    ThemeProvider themeProvider,
  ) {
    final applications = _applicationsByJob[jobId];
    final loading = _loadingApplications.contains(jobId);
    final textColor =
        themeProvider.isDarkMode ? Colors.white70 : Colors.black54;
    final borderColor =
        themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Colors.grey.shade900.withValues(alpha: 0.6)
            : Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Candidates & metrics',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          // Metrics summary
          Row(
            children: [
              _metricChip(
                'Total applications',
                '${job['application_count'] ?? 0}',
                themeProvider,
              ),
              const SizedBox(width: 12),
              _metricChip(
                'Job status',
                (job['is_active'] == true ? 'Active' : 'Inactive'),
                themeProvider,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Applicants',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (applications == null || applications.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No applicants yet.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: textColor,
                ),
              ),
            )
          else
            ...applications.asMap().entries.map<Widget>((entry) {
              final index = entry.key;
              final app = entry.value;
              final cand = app['candidate'] is Map
                  ? app['candidate'] as Map<String, dynamic>
                  : null;
              final name = cand?['full_name'] ?? 'Unknown';
              final email = cand?['email'] ?? '—';
              final status = app['status'] ?? '—';
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (index > 0)
                    Divider(
                      height: 1,
                      color: borderColor,
                      indent: 0,
                      endIndent: 0,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            name,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.person_outline, size: 16, color: textColor),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Text(
                            email,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$status',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: themeProvider.isDarkMode
                                  ? Colors.blue.shade200
                                  : Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value, ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: themeProvider.isDarkMode
              ? Colors.grey.shade700
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.black54,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void openJobForm({Map<String, dynamic>? job}) {
    showDialog(
      context: context,
      builder: (_) => JobFormDialog(job: job, onSaved: fetchJobs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return DefaultTextStyle(
      style: TextStyle(
        fontFamily: 'Poppins',
        color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
      ),
      child: Scaffold(
        // 🌆 Dynamic background implementation
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(themeProvider.backgroundImage),
              fit: BoxFit.cover,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Job Management",
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            CustomButton(
                              text: "Add Job",
                              onPressed: () => openJobForm(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(
                          color: themeProvider.isDarkMode
                              ? Colors.grey.shade800
                              : Colors.grey,
                        ),
                        const SizedBox(height: 16),

                        // Search bar
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _searchController,
                          builder: (_, value, __) {
                            final hasText = value.text.isNotEmpty;
                            final borderColor = themeProvider.isDarkMode
                                ? Colors.grey.shade700
                                : Colors.grey.shade400;
                            final inputBorder = OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            );
                            return Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Search jobs by title, description...',
                                      hintStyle: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: themeProvider.isDarkMode
                                            ? Colors.grey.shade500
                                            : Colors.grey.shade600,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        color: Colors.grey,
                                      ),
                                      suffixIcon: hasText
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.clear,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() {});
                                              },
                                            )
                                          : null,
                                      border: inputBorder,
                                      enabledBorder: inputBorder,
                                      focusedBorder: inputBorder,
                                      filled: true,
                                      fillColor: themeProvider.isDarkMode
                                          ? Colors.grey.shade900.withValues(
                                              alpha: 0.5,
                                            )
                                          : Colors.grey.shade50,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    onSubmitted: (_) => _applySearch(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton.filled(
                                  onPressed: _applySearch,
                                  icon: const Icon(Icons.search),
                                  tooltip: 'Search',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // Filters
                        Row(
                          children: [
                            Text(
                              'Category:',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: themeProvider.isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 8),
                            DropdownButton<String?>(
                              value: _categoryFilter,
                              hint: Text(
                                'All',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: themeProvider.isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.black54,
                                ),
                              ),
                              underline: const SizedBox(),
                              borderRadius: BorderRadius.circular(8),
                              dropdownColor: themeProvider.isDarkMode
                                  ? const Color(0xFF14131E)
                                  : Colors.white,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 14,
                              ),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    'All',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                ..._categoryOptions.map(
                                  (c) => DropdownMenuItem<String?>(
                                    value: c,
                                    child: Text(
                                      c,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: themeProvider.isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _categoryFilter = v;
                                  fetchJobs();
                                });
                              },
                            ),
                            const SizedBox(width: 24),
                            Text(
                              'Status:',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: themeProvider.isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: _statusFilter,
                              underline: const SizedBox(),
                              borderRadius: BorderRadius.circular(8),
                              dropdownColor: themeProvider.isDarkMode
                                  ? const Color(0xFF14131E)
                                  : Colors.white,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 14,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'active',
                                  child: Text(
                                    'Active',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'inactive',
                                  child: Text(
                                    'Inactive',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text(
                                    'All',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _statusFilter = v;
                                    fetchJobs();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Table with expandable rows (scrolls with the whole screen)
                        jobs.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 48,
                                ),
                                child: Center(
                                  child: Text(
                                    loading ? '' : "No jobs found",
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: themeProvider.isDarkMode
                                          ? Colors.grey.shade400
                                          : Colors.black54,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              )
                            : _filteredJobs().isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 48,
                                    ),
                                    child: Center(
                                      child: Text(
                                        "No jobs match your search",
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: themeProvider.isDarkMode
                                              ? Colors.grey.shade400
                                              : Colors.black54,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: (themeProvider.isDarkMode
                                              ? const Color(0xFF14131E)
                                              : Colors.white)
                                          .withValues(alpha: 0.95),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: themeProvider.isDarkMode
                                            ? Colors.grey.shade800
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Table header
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          color: themeProvider.isDarkMode
                                              ? Colors.grey.shade900
                                              : Colors.grey.shade200,
                                          child: Row(
                                            children: [
                                              _tableHeaderCell(
                                                'Title',
                                                flex: 3,
                                                themeProvider: themeProvider,
                                              ),
                                              _tableHeaderCell(
                                                'Category',
                                                flex: 1,
                                                themeProvider: themeProvider,
                                              ),
                                              _tableHeaderCell(
                                                'Applications',
                                                flex: 1,
                                                themeProvider: themeProvider,
                                              ),
                                              _tableHeaderCell(
                                                'Status',
                                                flex: 1,
                                                themeProvider: themeProvider,
                                              ),
                                              _tableHeaderCell(
                                                'Created by',
                                                flex: 2,
                                                themeProvider: themeProvider,
                                              ),
                                              SizedBox(
                                                width: 120,
                                                child: Text(
                                                  'Actions',
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color:
                                                        themeProvider.isDarkMode
                                                            ? Colors.white
                                                            : Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // All job rows in column so whole screen scrolls together
                                        ..._filteredJobs().map(
                                          (job) => _buildExpandableJobRow(
                                            job,
                                            themeProvider,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Job + Assessment Form Dialog ----------------
class JobFormDialog extends StatefulWidget {
  final Map<String, dynamic>? job;
  final VoidCallback onSaved;

  const JobFormDialog({super.key, this.job, required this.onSaved});

  @override
  _JobFormDialogState createState() => _JobFormDialogState();
}

class _JobFormDialogState extends State<JobFormDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late String title;
  late String description;
  String jobSummary = "";
  TextEditingController responsibilitiesController = TextEditingController();
  TextEditingController qualificationsController = TextEditingController();
  TextEditingController companyDetailsController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  String companyName = "";
  String jobLocation = "";
  String companyDetails = "";
  String category = "";
  final skillsController = TextEditingController();
  final minExpController = TextEditingController();
  final categoryController = TextEditingController();
  String salaryCurrency = "ZAR";
  String salaryPeriod = "monthly";
  final TextEditingController salaryMinController = TextEditingController();
  final TextEditingController salaryMaxController = TextEditingController();
  final TextEditingController applicationDeadlineController =
      TextEditingController();
  List<Map<String, dynamic>> questions = [];
  int? _testPackId;
  List<TestPack> _testPacks = [];
  bool _useTestPack = false;
  bool _loadingTestPacks = false;
  List<bool> _cherryPickSelected = [];
  Map<String, int> weightings = {
    "cv": 60,
    "assessment": 40,
    "interview": 0,
    "references": 0,
  };
  List<Map<String, dynamic>> knockoutRules = [];
  String employmentType = "full_time";
  String? weightingsError;
  late TabController _tabController;
  final AdminService admin = AdminService();
  final TestPackService _testPackService = TestPackService();

  // Category options for dropdown
  static const List<String> categoryOptions = [
    "Engineering",
    "Marketing",
    "Sales",
    "HR",
    "Finance",
    "Operations",
    "Customer Service",
    "Product",
    "Design",
    "Data Science",
  ];

  @override
  void initState() {
    super.initState();
    title = widget.job?['title'] ?? '';
    description = widget.job?['description'] ?? '';
    descriptionController.text = description;
    companyDetailsController.text = widget.job?['company_details'] ?? '';
    category = widget.job?['category'] ?? '';

    salaryCurrency = widget.job?['salary_currency'] ?? 'ZAR';
    salaryMinController.text = (widget.job?['salary_min'] ?? '').toString();
    salaryMaxController.text = (widget.job?['salary_max'] ?? '').toString();
    salaryPeriod = widget.job?['salary_period'] ?? 'monthly';
    final rawDeadline = widget.job?['application_deadline'];
    if (rawDeadline != null && rawDeadline.toString().trim().isNotEmpty) {
      final s = rawDeadline.toString();
      applicationDeadlineController.text =
          s.length >= 10 ? s.substring(0, 10) : s;
    }

    // Format existing responsibilities as bullet points
    final existingResponsibilities = widget.job?['responsibilities'] ?? [];
    responsibilitiesController.text =
        existingResponsibilities.map((r) => "• $r").join('\n');

    // Format existing qualifications as bullet points
    final existingQualifications = widget.job?['qualifications'] ?? [];
    qualificationsController.text =
        existingQualifications.map((q) => "• $q").join('\n');

    // Format existing skills as bullet points
    final existingSkills = widget.job?['required_skills'] ?? [];
    skillsController.text = existingSkills.map((s) => "• $s").join('\n');

    minExpController.text = (widget.job?['min_experience'] ?? 0).toString();
    jobSummary = widget.job?['job_summary'] ?? '';
    companyDetails = widget.job?['company_details'] ?? '';
    companyDetailsController.text = companyDetails;
    category = widget.job?['category'] ?? '';
    categoryController.text = category;

    if (widget.job != null &&
        widget.job!['assessment_pack'] != null &&
        widget.job!['assessment_pack']['questions'] != null) {
      questions = _normalizeQuestions(
        widget.job!['assessment_pack']['questions'],
      );
    }
    final tpId = widget.job?['test_pack_id'];
    if (tpId != null && tpId is int) {
      _testPackId = tpId;
      _useTestPack = true;
    }

    // Load weightings (CV %, Assessment %, etc.) and knockout rules when editing
    final rawWeightings = widget.job?['weightings'];
    if (rawWeightings is Map) {
      weightings = {
        "cv": (rawWeightings["cv"] is int)
            ? rawWeightings["cv"] as int
            : (rawWeightings["cv"] is num)
                ? (rawWeightings["cv"] as num).toInt()
                : 60,
        "assessment": (rawWeightings["assessment"] is int)
            ? rawWeightings["assessment"] as int
            : (rawWeightings["assessment"] is num)
                ? (rawWeightings["assessment"] as num).toInt()
                : 40,
        // This screen edits CV + Assessment only.
        "interview": 0,
        "references": 0,
      };
    }
    final rawRules = widget.job?['knockout_rules'];
    if (rawRules is List) {
      knockoutRules =
          rawRules.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    _tabController = TabController(length: 2, vsync: this);
    _loadTestPacks();
  }

  Future<void> _loadTestPacks() async {
    setState(() => _loadingTestPacks = true);
    try {
      final packs = await _testPackService.getTestPacks();
      if (mounted) setState(() => _testPacks = packs);
    } catch (_) {}
    if (mounted) setState(() => _loadingTestPacks = false);
  }

  Widget _buildCherryPickSection(dynamic themeProvider) {
    TestPack? selectedPack;
    for (final p in _testPacks) {
      if (p.id == _testPackId) {
        selectedPack = p;
        break;
      }
    }
    if (selectedPack == null || selectedPack.questions.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_cherryPickSelected.length != selectedPack.questions.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(
            () => _cherryPickSelected = List.filled(
              selectedPack!.questions.length,
              true,
            ),
          );
        }
      });
      return const SizedBox.shrink();
    }
    final packQuestions = selectedPack.questions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customize questions',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: themeProvider.isDarkMode
                ? Colors.grey.shade300
                : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Select which questions to use. "Use selected" copies them as custom questions.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: themeProvider.isDarkMode
                ? Colors.grey.shade400
                : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            border: Border.all(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade700
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: packQuestions.length,
            itemBuilder: (_, i) {
              final q = packQuestions[i];
              final text =
                  (q['question_text'] ?? q['question'] ?? '').toString();
              final short =
                  text.length > 60 ? '${text.substring(0, 60)}...' : text;
              return CheckboxListTile(
                value: _cherryPickSelected[i],
                onChanged: (v) =>
                    setState(() => _cherryPickSelected[i] = v ?? true),
                title: Text(
                  short,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: themeProvider.isDarkMode
                        ? Colors.white70
                        : Colors.black87,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _applyCherryPickedQuestions(selectedPack!),
          icon: const Icon(Icons.checklist, size: 18),
          label: const Text('Use selected'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _applyCherryPickedQuestions(TestPack pack) {
    final selected = <Map<String, dynamic>>[];
    for (var i = 0; i < pack.questions.length; i++) {
      if (i < _cherryPickSelected.length && _cherryPickSelected[i]) {
        final q = Map<String, dynamic>.from(pack.questions[i]);
        selected.add({
          'question': q['question_text'] ?? q['question'] ?? '',
          'options': (q['options'] is List)
              ? List<String>.from(
                  (q['options'] as List).map((e) => e.toString()),
                )
              : ['', '', '', ''],
          'answer': (q['correct_option'] ?? q['correct_answer'] ?? 0) is num
              ? ((q['correct_option'] ?? q['correct_answer'] ?? 0) as num)
                  .toInt()
              : 0,
          'weight':
              (q['weight'] ?? 1) is num ? (q['weight'] as num).toInt() : 1,
        });
      }
    }
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one question')),
      );
      return;
    }
    setState(() {
      questions = selected;
      _useTestPack = false;
      _testPackId = null;
      _cherryPickSelected = [];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Using ${selected.length} question(s) as custom assessment',
        ),
      ),
    );
  }

  // Show AI Question Generation Dialog
  Future<void> _showAIQuestionDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AIQuestionDialog(
        jobTitle: title,
        onQuestionsGenerated: (generatedQuestions) {
          setState(() {
            questions.addAll(generatedQuestions);
          });
        },
      ),
    );
  }

  Future<void> _saveAsTestPack() async {
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one question first')),
      );
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SaveTestPackDialog(
        initialQuestions: questions,
        initialName: title.trim().isEmpty ? null : '$title Assessment Pack',
      ),
    );
    if (result == null || !mounted) return;
    try {
      final pack = await _testPackService.createTestPack(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test pack "${pack.name}" created')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    companyDetailsController.dispose();
    responsibilitiesController.dispose();
    qualificationsController.dispose();
    skillsController.dispose();
    minExpController.dispose();
    salaryMinController.dispose();
    salaryMaxController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _normalizeQuestions(dynamic raw) {
    if (raw == null) return [];

    final List<dynamic> items;
    if (raw is List) {
      items = raw;
    } else {
      return [];
    }

    final normalized = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      final optsRaw = map['options'];
      final options = (optsRaw is List)
          ? optsRaw.map((e) => e?.toString() ?? '').toList()
          : <String>['', '', '', ''];
      while (options.length < 4) {
        options.add('');
      }

      normalized.add({
        'question': (map['question'] ?? '').toString(),
        'options': options.take(4).toList(),
        'answer': (map['answer'] ?? map['correct_answer'] ?? 0) is num
            ? ((map['answer'] ?? map['correct_answer'] ?? 0) as num).toInt()
            : 0,
        'weight':
            (map['weight'] ?? 1) is num ? (map['weight'] as num).toInt() : 1,
      });
    }
    return normalized;
  }

  void addQuestion() {
    setState(() {
      questions.add({
        "question": "",
        "options": ["", "", "", ""],
        "answer": 0,
        "weight": 1,
      });
    });
  }

  bool _generatingJobDetails = false;

  Future<void> _generateJobDetailsWithAI() async {
    final jobTitle = title.trim();
    if (jobTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a job title first'),
        ),
      );
      return;
    }

    setState(() => _generatingJobDetails = true);

    try {
      final result = await AIService.generateJobDetails(jobTitle);
      if (!mounted) return;

      final details = result['job_details'] ?? result;
      if (details is! Map<String, dynamic>) {
        throw Exception("Invalid response format from AI service");
      }

      // Apply the generated details to form fields
      setState(() {
        descriptionController.text = details['description'] ?? '';
        responsibilitiesController.text =
            (details['responsibilities'] as List?)?.join('\n') ?? '';
        qualificationsController.text =
            (details['qualifications'] as List?)?.join('\n') ?? '';
        categoryController.text = details['category'] ?? '';
        minExpController.text = details['min_experience']?.toString() ?? '';
        companyDetailsController.text = details['company_details'] ?? '';

        // Apply skills
        final skills = details['required_skills'] as List?;
        if (skills != null && skills.isNotEmpty) {
          skillsController.text = skills.join(', ');
        }

        // Apply salary if available
        final smin = details['salary_min'];
        if (smin != null) {
          salaryMinController.text = smin.toString();
        }
        final smax = details['salary_max'];
        if (smax != null) {
          salaryMaxController.text = smax.toString();
        }
        final ew = details['evaluation_weightings'] ?? details['weightings'];
        if (ew is Map) {
          weightings = {
            'cv': (ew['cv'] is num) ? (ew['cv'] as num).toInt() : 60,
            'assessment': (ew['assessment'] is num)
                ? (ew['assessment'] as num).toInt()
                : 40,
            'interview':
                (ew['interview'] is num) ? (ew['interview'] as num).toInt() : 0,
            'references': (ew['references'] is num)
                ? (ew['references'] as num).toInt()
                : 0,
          };
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Job details filled from AI. Review and edit as needed.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Generate failed: $e')));
    } finally {
      if (mounted) setState(() => _generatingJobDetails = false);
    }
  }

  Future<void> saveJob() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please fix the errors in the form (e.g. Job Title, Description).',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final responsibilities = responsibilitiesController.text
        .split("\n")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map(
          (e) => e.startsWith('• ') ? e.substring(2) : e,
        ) // Remove bullet point prefix
        .where((e) => e.isNotEmpty)
        .toList();

    final qualifications = qualificationsController.text
        .split("\n")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map(
          (e) => e.startsWith('• ') ? e.substring(2) : e,
        ) // Remove bullet point prefix
        .where((e) => e.isNotEmpty)
        .toList();

    final skills = skillsController.text
        .split("\n")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map(
          (e) => e.startsWith('• ') ? e.substring(2) : e,
        ) // Remove bullet point prefix
        .where((e) => e.isNotEmpty)
        .toList();

    final normalizedQuestions = _normalizeQuestions(questions);
    final totalWeight =
        (weightings["cv"] ?? 0) + (weightings["assessment"] ?? 0);
    if (totalWeight != 100) {
      setState(
        () => weightingsError =
            "Weightings must total 100% (current: $totalWeight%)",
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Adjust CV and Assessment percentages so they total 100%.",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final Map<String, int> adjustedWeightings = {
      "cv": weightings["cv"] ?? 0,
      "assessment": weightings["assessment"] ?? 0,
      "interview": 0,
      "references": 0,
    };

    final jobData = <String, dynamic>{
      'title': (title).trim().isEmpty ? 'Untitled Position' : title.trim(),
      'description': () {
        final fromController = descriptionController.text.trim();
        final fromState = description.trim();
        final value = fromController.isNotEmpty ? fromController : fromState;
        return value.isEmpty ? 'No description provided' : value;
      }(),
      'company': companyName.trim(),
      'location': jobLocation.trim(),
      'job_summary': jobSummary.trim(),
      'employment_type': employmentType,
      'responsibilities': responsibilities,
      'qualifications': qualifications,
      'company_details': companyDetails.trim(),
      'salary_min': double.tryParse(salaryMinController.text),
      'salary_max': double.tryParse(salaryMaxController.text),
      'salary_currency': salaryCurrency,
      'salary_period': salaryPeriod,
      'category': category.trim().isEmpty ? 'General' : category.trim(),
      'required_skills': skills,
      'min_experience': double.tryParse(minExpController.text) ?? 0,
      'weightings': adjustedWeightings,
      'knockout_rules': knockoutRules,
      'vacancy': 1,
      if (applicationDeadlineController.text.trim().isNotEmpty)
        'application_deadline': applicationDeadlineController.text.trim(),
      if (_useTestPack && _testPackId != null) 'test_pack_id': _testPackId,
      'assessment_pack': _useTestPack && _testPackId != null
          ? {'questions': []}
          : {
              'questions': normalizedQuestions.map((q) {
                return <String, dynamic>{
                  "question": q["question"] as String? ?? "",
                  "options": q["options"] as List<dynamic>? ?? [],
                  "correct_answer": q["answer"],
                  "weight": q["weight"] ?? 1,
                };
              }).toList(),
            },
    };

    try {
      if (widget.job == null) {
        await admin.createJob(jobData);
      } else {
        await admin.updateJob(widget.job!['id'] as int, jobData);
      }
      if (!mounted) return;
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving job: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 650,
        height: 800, // Increased height to accommodate expanded fields
        decoration: BoxDecoration(
          color: (themeProvider.isDarkMode
                  ? const Color(0xFF14131E)
                  : Colors.white)
              .withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: "Job Details"),
                  Tab(text: "Assessment"),
                ],
                labelColor: Colors.redAccent,
                unselectedLabelColor: themeProvider.isDarkMode
                    ? Colors.grey.shade400
                    : Colors.black54,
                indicatorColor: Colors.redAccent,
                indicatorWeight: 3,
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Job Details Tab
                    Container(
                      color: (themeProvider.isDarkMode
                              ? const Color(0xFF1A1A2E)
                              : Colors.white)
                          .withValues(alpha: 0.95),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.work,
                                    color: Colors.redAccent,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Basic Job Information",
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      label: "Job Title",
                                      initialValue: title,
                                      hintText: "Enter job title",
                                      onChanged: (v) => title = v,
                                      validator: (v) => v == null || v.isEmpty
                                          ? "Enter job title"
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filled(
                                    onPressed: _generatingJobDetails
                                        ? null
                                        : _generateJobDetailsWithAI,
                                    icon: _generatingJobDetails
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.redAccent,
                                            ),
                                          )
                                        : const Icon(Icons.auto_awesome),
                                    tooltip: _generatingJobDetails
                                        ? "Generating…"
                                        : "Generate job details from title (AI)",
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Card(
                                elevation: 4,
                                shadowColor: Colors.black26,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                color: (themeProvider.isDarkMode
                                        ? const Color(0xFF1A1A2E)
                                        : Colors.white)
                                    .withValues(alpha: 0.95),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.assignment,
                                            color: Colors.orangeAccent,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            "Job Requirements",
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: themeProvider.isDarkMode
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      CustomTextField(
                                        label: "Responsibilities",
                                        controller: responsibilitiesController,
                                        hintText:
                                            "Bullet points of key responsibilities",
                                        maxLines: 4,
                                        expands: false,
                                      ),
                                      const SizedBox(height: 16),
                                      CustomTextField(
                                        label: "Qualifications",
                                        controller: qualificationsController,
                                        hintText:
                                            "Bullet points of required qualifications",
                                        maxLines: 4,
                                        expands: false,
                                      ),
                                      const SizedBox(height: 16),
                                      CustomTextField(
                                        label: "Required Skills",
                                        controller: skillsController,
                                        hintText:
                                            "Bullet points of essential skills",
                                        maxLines: 3,
                                        expands: false,
                                      ),
                                      const SizedBox(height: 16),
                                      CustomTextField(
                                        label: "Minimum Experience (years)",
                                        controller: minExpController,
                                        inputType: TextInputType.number,
                                      ),
                                      const SizedBox(height: 16),
                                      CustomTextField(
                                        label:
                                            "Application deadline (YYYY-MM-DD)",
                                        controller:
                                            applicationDeadlineController,
                                        hintText: "e.g. 2025-12-31",
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Company Information Section
                              Card(
                                elevation: 4,
                                shadowColor: Colors.black26,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                color: (themeProvider.isDarkMode
                                        ? const Color(0xFF1A1A2E)
                                        : Colors.white)
                                    .withValues(alpha: 0.95),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.business,
                                            color: Colors.greenAccent,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            "Company Information",
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: themeProvider.isDarkMode
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      CustomTextField(
                                        label: "Description",
                                        controller: descriptionController,
                                        hintText: "Enter job description",
                                        maxLines: 5,
                                        expands: false,
                                        onChanged: (v) => description = v,
                                        validator: (v) => v == null || v.isEmpty
                                            ? "Enter description"
                                            : null,
                                      ),
                                      const SizedBox(height: 16),
                                      CustomTextField(
                                        label: "Company Details",
                                        controller: companyDetailsController,
                                        hintText: "About the company",
                                        maxLines: 4,
                                        expands: false,
                                        onChanged: (v) => companyDetails = v,
                                      ),
                                      const SizedBox(height: 20),
                                      DropdownButtonFormField<String>(
                                        value:
                                            category.isEmpty ? null : category,
                                        decoration: const InputDecoration(
                                          labelText: "Category",
                                        ),
                                        items: categoryOptions
                                            .map(
                                              (cat) => DropdownMenuItem(
                                                value: cat,
                                                child: Text(cat),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) => setState(
                                          () => category = value ?? '',
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          "Salary",
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
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: CustomTextField(
                                              label: "Salary Min",
                                              controller: salaryMinController,
                                              inputType: TextInputType.number,
                                              hintText: "e.g. 30000",
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: CustomTextField(
                                              label: "Salary Max",
                                              controller: salaryMaxController,
                                              inputType: TextInputType.number,
                                              hintText: "e.g. 45000",
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: CustomTextField(
                                              label: "Currency",
                                              initialValue: salaryCurrency,
                                              hintText: "ZAR, USD, EUR",
                                              onChanged: (v) {
                                                setState(() {
                                                  salaryCurrency =
                                                      v.isEmpty ? "ZAR" : v;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child:
                                                DropdownButtonFormField<String>(
                                              value: salaryPeriod,
                                              decoration: InputDecoration(
                                                labelText: "Period",
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    8,
                                                  ),
                                                ),
                                              ),
                                              items: const [
                                                DropdownMenuItem(
                                                  value: "monthly",
                                                  child: Text(
                                                    "Per month",
                                                    style: const TextStyle(
                                                      fontFamily: 'Poppins',
                                                    ),
                                                  ),
                                                ),
                                                DropdownMenuItem(
                                                  value: "yearly",
                                                  child: Text(
                                                    "Per year",
                                                    style: const TextStyle(
                                                      fontFamily: 'Poppins',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              onChanged: (value) {
                                                if (value != null) {
                                                  setState(
                                                    () => salaryPeriod = value,
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Assessment Configuration Section
                              Card(
                                elevation: 4,
                                shadowColor: Colors.black26,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                color: (themeProvider.isDarkMode
                                        ? const Color(0xFF1A1A2E)
                                        : Colors.white)
                                    .withValues(alpha: 0.95),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.assessment,
                                            color: Colors.blueAccent,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            "Assessment Configuration",
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: themeProvider.isDarkMode
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          "Evaluation weightings (must total 100%)",
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
                                      const SizedBox(height: 8),
                                      WeightingConfigurationWidget(
                                        weightings: weightings,
                                        errorText: weightingsError,
                                        onChanged: (updated) {
                                          setState(() {
                                            weightings = updated;
                                            final total = updated.values
                                                .fold<int>(0, (a, b) => a + b);
                                            weightingsError = total == 100
                                                ? null
                                                : "Weightings must total 100%";
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          "Knockout rules",
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
                                      const SizedBox(height: 8),
                                      KnockoutRulesBuilder(
                                        rules: knockoutRules,
                                        onChanged: (updated) {
                                          setState(
                                            () => knockoutRules = updated,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Use a test pack or create custom questions
                          Text(
                            "Assessment",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade300
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Radio<bool>(
                                value: true,
                                groupValue: _useTestPack,
                                onChanged: (v) =>
                                    setState(() => _useTestPack = true),
                                activeColor: Colors.redAccent,
                              ),
                              Text(
                                "Use a test pack",
                                style: const TextStyle(fontFamily: 'Poppins'),
                              ),
                              const SizedBox(width: 24),
                              Radio<bool>(
                                value: false,
                                groupValue: _useTestPack,
                                onChanged: (v) => setState(() {
                                  _useTestPack = false;
                                  _testPackId = null;
                                }),
                                activeColor: Colors.redAccent,
                              ),
                              Text(
                                "Create custom questions",
                                style: const TextStyle(fontFamily: 'Poppins'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_useTestPack) ...[
                            if (_loadingTestPacks)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.redAccent,
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: DropdownButtonFormField<int?>(
                                  value: _testPackId,
                                  decoration: InputDecoration(
                                    labelText: "Select test pack",
                                    border: const OutlineInputBorder(),
                                    labelStyle: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: themeProvider.isDarkMode
                                          ? Colors.grey.shade400
                                          : Colors.black87,
                                    ),
                                  ),
                                  dropdownColor: themeProvider.isDarkMode
                                      ? const Color(0xFF14131E)
                                      : Colors.white,
                                  items: [
                                    DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text(
                                        "None",
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                    ..._testPacks.map(
                                      (p) => DropdownMenuItem<int?>(
                                        value: p.id,
                                        child: Text(
                                          "${p.name} (${p.category}) – ${p.questionCount} questions",
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            color: themeProvider.isDarkMode
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    setState(() {
                                      _testPackId = v;
                                      _cherryPickSelected = [];
                                      if (v != null) {
                                        for (final p in _testPacks) {
                                          if (p.id == v) {
                                            _cherryPickSelected = List.filled(
                                              p.questions.length,
                                              true,
                                            );
                                            break;
                                          }
                                        }
                                      }
                                    });
                                  },
                                ),
                              ),
                            const SizedBox(height: 16),
                            if (_testPackId != null) ...[
                              _buildCherryPickSection(themeProvider),
                            ],
                            if (_testPackId != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  "Questions will be taken from the selected pack when candidates apply.",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: themeProvider.isDarkMode
                                        ? Colors.grey.shade400
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                          ],
                          if (!_useTestPack) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Assessment Questions",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: themeProvider.isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.green),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.psychology,
                                          color: Colors.green,
                                        ),
                                        onPressed: _showAIQuestionDialog,
                                        tooltip: "Generate AI Questions",
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.save_alt,
                                          color: Colors.blue,
                                        ),
                                        onPressed: _saveAsTestPack,
                                        tooltip: "Save as Test Pack",
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          Expanded(
                            child: ListView.builder(
                              itemCount: questions.length,
                              itemBuilder: (_, index) {
                                final q = questions[index];
                                return Card(
                                  color: (themeProvider.isDarkMode
                                          ? const Color(0xFF14131E)
                                          : Colors.white)
                                      .withValues(alpha: 0.9),
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Question Header
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.blue.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                "Question ${index + 1}",
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.orange
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Text(
                                                "Weight: ${q["weight"] ?? 1}",
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Question Field
                                        CustomTextField(
                                          label: "Question",
                                          initialValue: q["question"],
                                          hintText: "Enter your question here",
                                          maxLines: 3,
                                          expands: false,
                                          onChanged: (v) => q["question"] = v,
                                        ),
                                        const SizedBox(height: 16),

                                        // Options Section
                                        Text(
                                          "Answer Options",
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: themeProvider.isDarkMode
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...List.generate(4, (i) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: Row(
                                              children: [
                                                // Option Indicator
                                                Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: q["answer"] == i
                                                        ? Colors.green
                                                            .withValues(
                                                            alpha: 0.2,
                                                          )
                                                        : Colors.grey
                                                            .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      8,
                                                    ),
                                                    border: Border.all(
                                                      color: q["answer"] == i
                                                          ? Colors.green
                                                          : Colors.grey
                                                              .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                      width: q["answer"] == i
                                                          ? 2
                                                          : 1,
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      String.fromCharCode(
                                                        65 + i,
                                                      ), // A, B, C, D
                                                      style: TextStyle(
                                                        fontFamily: 'Poppins',
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: q["answer"] == i
                                                            ? Colors.green
                                                            : Colors
                                                                .grey.shade600,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),

                                                // Option Field
                                                Expanded(
                                                  child: CustomTextField(
                                                    label:
                                                        "Option ${String.fromCharCode(65 + i)}",
                                                    initialValue: q["options"]
                                                        [i],
                                                    hintText:
                                                        "Enter option ${String.fromCharCode(65 + i)}",
                                                    maxLines: 2,
                                                    expands: false,
                                                    onChanged: (v) =>
                                                        q["options"][i] = v,
                                                  ),
                                                ),

                                                // Correct Answer Indicator
                                                IconButton(
                                                  onPressed: () => setState(
                                                    () => q["answer"] = i,
                                                  ),
                                                  icon: Icon(
                                                    q["answer"] == i
                                                        ? Icons.check_circle
                                                        : Icons
                                                            .radio_button_unchecked,
                                                    color: q["answer"] == i
                                                        ? Colors.green
                                                        : Colors.grey.shade400,
                                                  ),
                                                  tooltip:
                                                      "Mark as correct answer",
                                                ),
                                              ],
                                            ),
                                          );
                                        }),

                                        const SizedBox(height: 16),

                                        // Weight Field
                                        Row(
                                          children: [
                                            Expanded(
                                              child: CustomTextField(
                                                label: "Question Weight",
                                                initialValue:
                                                    q["weight"].toString(),
                                                hintText: "Enter weight (1-10)",
                                                inputType: TextInputType.number,
                                                onChanged: (v) => q["weight"] =
                                                    double.tryParse(v) ?? 1,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.red.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.red.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                ),
                                              ),
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    questions.removeAt(index);
                                                  });
                                                },
                                                tooltip: "Delete Question",
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (!_useTestPack) ...[
                            const SizedBox(height: 12),
                            CustomButton(
                              text: "Add Question",
                              onPressed: addQuestion,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ), // End of TabBarView
              ),

              Container(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: themeProvider.isDarkMode
                              ? Colors.grey.shade400
                              : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CustomButton(text: "Save Job", onPressed: saveJob),
                  ],
                ),
              ), // Closing Container
            ], // Closing Column children
          ),
        ), // Form
      ),
    );
  }
}

// AI Question Generation Dialog
class AIQuestionDialog extends StatefulWidget {
  final String jobTitle;
  final Function(List<Map<String, dynamic>>) onQuestionsGenerated;

  const AIQuestionDialog({
    super.key,
    required this.jobTitle,
    required this.onQuestionsGenerated,
  });

  @override
  _AIQuestionDialogState createState() => _AIQuestionDialogState();
}

class _AIQuestionDialogState extends State<AIQuestionDialog> {
  final _formKey = GlobalKey<FormState>();
  String difficulty = 'Medium';
  int questionCount = 5;
  bool _isGenerating = false;

  final List<String> difficultyLevels = ['Easy', 'Medium', 'Hard'];
  final List<int> questionCounts = [3, 5, 8, 10];

  Future<void> _generateQuestions() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isGenerating = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating assessment questions with AI…'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final questions = await AIService.generateAssessmentQuestions(
        jobTitle: widget.jobTitle,
        difficulty: difficulty,
        questionCount: questionCount,
      );

      if (questions.isNotEmpty) {
        widget.onQuestionsGenerated(questions);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Generated $questionCount questions successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Fallback to manual question creation
        _showManualQuestionDialog();
      }
    } catch (e) {
      debugPrint('Error generating questions: $e');
      String errorMessage = 'AI generation failed';

      // Check for specific error types
      if (e.toString().contains('503') ||
          e.toString().contains('quota') ||
          e.toString().contains('credits')) {
        errorMessage =
            'AI services are currently unavailable due to quota limits. Please try again later or create questions manually.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage =
            'Network error occurred. Please check your connection and try again.';
      } else {
        errorMessage =
            'AI generation failed: $e. You can create questions manually.';
      }

      _showErrorDialog(errorMessage);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showManualQuestionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Questions Manually'),
        content: Text(
          'AI generation failed. Would you like to create questions manually?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showManualQuestionForm();
            },
            child: Text('Create Manually'),
          ),
        ],
      ),
    );
  }

  void _showManualQuestionForm() {
    // Implement manual question creation form
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manual Question Creation'),
        content: Text(
          'Manual question creation form would go here. For now, using fallback questions.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Create fallback questions
              final fallbackQuestions = _generateFallbackQuestions();
              widget.onQuestionsGenerated(fallbackQuestions);
              Navigator.pop(context);
              Navigator.pop(context); // Close the manual form dialog too
            },
            child: Text('Use Fallback Questions'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generateFallbackQuestions() {
    return List.generate(
      questionCount,
      (index) => {
        'id': 'fallback-$index',
        'question':
            'Describe your approach to ${widget.jobTitle} task #${index + 1}.',
        'type': 'text',
        'difficulty': difficulty.toLowerCase(),
        'points': 10,
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 450,
        height: 400,
        decoration: BoxDecoration(
          color: (themeProvider.isDarkMode
                  ? const Color(0xFF14131E)
                  : Colors.white)
              .withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.psychology, color: Colors.green, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Generate AI Questions",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Job Title Display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.work, size: 20, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Job: ${widget.jobTitle}",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Difficulty Level
                Text(
                  "Difficulty Level",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: difficulty,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: themeProvider.isDarkMode
                        ? Colors.grey.shade800
                        : Colors.grey.shade100,
                  ),
                  items: difficultyLevels.map((level) {
                    return DropdownMenuItem(
                      value: level,
                      child: Text(
                        level,
                        style: const TextStyle(fontFamily: 'Poppins'),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => difficulty = value!);
                  },
                ),
                const SizedBox(height: 20),

                // Number of Questions
                Text(
                  "Number of Questions",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: questionCount,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: themeProvider.isDarkMode
                        ? Colors.grey.shade800
                        : Colors.grey.shade100,
                  ),
                  items: questionCounts.map((count) {
                    return DropdownMenuItem(
                      value: count,
                      child: Text(
                        "$count questions",
                        style: const TextStyle(fontFamily: 'Poppins'),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => questionCount = value!);
                  },
                ),
                const Spacer(),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade400
                                : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isGenerating ? null : _generateQuestions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isGenerating
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Generating...",
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                "Generate Questions",
                                style: const TextStyle(fontFamily: 'Poppins'),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
