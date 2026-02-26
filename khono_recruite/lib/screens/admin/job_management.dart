import 'package:provider/provider.dart';
import 'package:flutter/material.dart' hide SearchBar, FilterChip; // hide both
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/knockout_rules_builder.dart';
import '../../widgets/weighting_configuration_widget.dart';
import '../../widgets/search_bar.dart'; // your custom SearchBar
import '../../widgets/filter_chip.dart'; // your custom FilterChip
import '../../services/admin_service.dart';
import '../../providers/theme_provider.dart';

class JobManagement extends StatefulWidget {
  final Function(int jobId)? onJobSelected;

  const JobManagement({super.key, this.onJobSelected});

  @override
  _JobManagementState createState() => _JobManagementState();
}

class _JobManagementState extends State<JobManagement> {
  final AdminService admin = AdminService();
  List<Map<String, dynamic>> jobs = [];
  bool loading = true;

  // New state variables for enhanced features
  String searchQuery = '';
  String selectedCategory = 'all';
  String selectedStatus = 'active';
  String sortBy = 'created_at';
  String sortOrder = 'desc';
  int currentPage = 1;
  int totalPages = 1;
  bool showInactiveJobs = false;

  // Filter options
  final List<String> statusFilters = ['active', 'inactive', 'all'];
  final List<String> sortOptions = [
    'created_at',
    'updated_at',
    'title',
    'category',
    'vacancy',
    'min_experience'
  ];

  final List<String> categories = [
    'all',
    'Engineering',
    'Marketing',
    'Sales',
    'HR',
    'Finance',
    'Operations'
  ];

  @override
  void initState() {
    super.initState();
    fetchJobs();
  }

  Future<void> fetchJobs() async {
    setState(() => loading = true);
    try {
      // Try enhanced method with filters
      Map<String, dynamic> response;
      try {
        response = await _fetchJobsEnhanced();
      } catch (e) {
        // Fallback to original method
        final data = await admin.listJobs();
        jobs = List<Map<String, dynamic>>.from(data);
        return;
      }

      jobs = List<Map<String, dynamic>>.from(response['jobs'] ?? []);
      totalPages = response['pagination']?['total_pages'] ?? 1;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching jobs: $e")),
      );
    }
    setState(() => loading = false);
  }

  Future<Map<String, dynamic>> _fetchJobsEnhanced() async {
    try {
      // Use the enhanced listJobs method which returns Map<String, dynamic>
      final response = await admin.listJobsEnhanced(
        page: currentPage,
        category: selectedCategory == 'all' ? null : selectedCategory,
        status: selectedStatus,
        sortBy: sortBy,
        sortOrder: sortOrder,
        search: searchQuery.isNotEmpty ? searchQuery : null,
      );

      return response;
    } catch (e) {
      // If enhanced method doesn't exist or fails, fallback to original
      final data = await admin.listJobs();
      return {
        'jobs': data,
        'pagination': {
          'page': 1,
          'per_page': 20,
          'total': data.length,
          'total_pages': 1,
          'has_next': false,
          'has_prev': false,
        }
      };
    }
  }

  void openJobForm({Map<String, dynamic>? job}) {
    showDialog(
      context: context,
      builder: (_) => JobFormDialog(job: job, onSaved: fetchJobs),
    );
  }

  // Enhanced job operations
  Future<void> toggleJobStatus(Map<String, dynamic> job) async {
    try {
      await admin.updateJobStatus(job['id'], !(job['is_active'] ?? true));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((job['is_active'] ?? true)
              ? "Job deactivated successfully"
              : "Job activated successfully"),
          backgroundColor: Colors.green,
        ),
      );
      fetchJobs();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating job status: $e")),
      );
    }
  }

  Future<void> restoreJob(Map<String, dynamic> job) async {
    try {
      await admin.restoreJob(job['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Job restored successfully"),
          backgroundColor: Colors.green,
        ),
      );
      fetchJobs();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error restoring job: $e")),
      );
    }
  }

  void showJobDetails(Map<String, dynamic> job) async {
    try {
      final detailedJob = await admin.getJobDetailed(job['id']);
      _showJobDetailsDialog(detailedJob);
    } catch (e) {
      // Fallback to basic details
      _showBasicJobDetails(job);
    }
  }

  void _showJobDetailsDialog(Map<String, dynamic> detailedJob) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).cardColor,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      detailedJob['title'] ?? 'Job Details',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Job Information
                _buildDetailSection("Description", detailedJob['description']),
                if (detailedJob['job_summary'] != null &&
                    detailedJob['job_summary'].isNotEmpty)
                  _buildDetailSection("Summary", detailedJob['job_summary']),

                // Requirements
                if (detailedJob['required_skills'] != null &&
                    detailedJob['required_skills'].isNotEmpty)
                  _buildListSection(
                      "Required Skills", detailedJob['required_skills']),

                if (detailedJob['responsibilities'] != null &&
                    detailedJob['responsibilities'].isNotEmpty)
                  _buildListSection(
                      "Responsibilities", detailedJob['responsibilities']),

                if (detailedJob['qualifications'] != null &&
                    detailedJob['qualifications'].isNotEmpty)
                  _buildListSection(
                      "Qualifications", detailedJob['qualifications']),

                // Job Stats
                const SizedBox(height: 20),
                const Text("Job Statistics",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildStatChip(
                        "Category", detailedJob['category'] ?? 'Not specified'),
                    _buildStatChip("Experience",
                        "${detailedJob['min_experience'] ?? 0} yrs"),
                    _buildStatChip(
                        "Vacancies", "${detailedJob['vacancy'] ?? 1}"),
                    _buildStatChip(
                        "Status",
                        (detailedJob['is_active'] ?? true)
                            ? 'Active'
                            : 'Inactive',
                        color: (detailedJob['is_active'] ?? true)
                            ? Colors.green
                            : Colors.red),
                  ],
                ),

                // Advanced stats if available
                if (detailedJob['statistics'] != null)
                  _buildAdvancedStatistics(detailedJob['statistics']),

                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                    const SizedBox(width: 12),
                    CustomButton(
                      text: "Edit Job",
                      onPressed: () {
                        Navigator.pop(context);
                        openJobForm(job: detailedJob);
                      },
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

  void _showJobApplicationsDialog(Map<String, dynamic> job, ThemeProvider themeProvider) async {
    final jobId = job['id'] as int?;
    if (jobId == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final applications = await admin.getJobApplications(jobId);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Applicants',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${job['title'] ?? 'Job'}${(job['company'] != null && (job['company'] as String).isNotEmpty) ? ' at ${job['company']}' : ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                if (applications.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No applications yet',
                      style: TextStyle(
                        color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: applications.length,
                      itemBuilder: (_, i) {
                        final app = applications[i] is Map ? applications[i] as Map<String, dynamic> : <String, dynamic>{};
                        final cand = app['candidate'] is Map ? app['candidate'] as Map<String, dynamic> : <String, dynamic>{};
                        final name = cand['full_name'] ?? 'Unknown';
                        final email = cand['email'] ?? '';
                        final phone = cand['phone'] ?? '';
                        final status = app['status'] ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: themeProvider.isDarkMode
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (email.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      email,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                if (phone.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      phone,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                if (status.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Chip(
                                      label: Text(status, style: const TextStyle(fontSize: 11)),
                                      backgroundColor: Colors.teal.withValues(alpha: 0.2),
                                      side: BorderSide(color: Colors.teal, width: 0.5),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load applicants: $e')),
      );
    }
  }

  void _showBasicJobDetails(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(job['title'] ?? 'Job Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(job['description'] ?? 'No description'),
              const SizedBox(height: 16),
              if (job['required_skills'] != null)
                Text("Skills: ${(job['required_skills'] as List).join(", ")}"),
              if (job['min_experience'] != null)
                Text("Experience: ${job['min_experience']} years"),
              if (job['category'] != null) Text("Category: ${job['category']}"),
              Text(
                "Status: ${(job['is_active'] ?? true) ? 'Active' : 'Inactive'}",
                style: TextStyle(
                  color: (job['is_active'] ?? true) ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, String? content) {
    if (content == null || content.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(content),
        ],
      ),
    );
  }

  Widget _buildListSection(String title, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...items
              .map((item) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 2),
                    child: Text("ΓÇó $item"),
                  ))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, {Color? color}) {
    return Chip(
      label: Text("$label: $value"),
      backgroundColor:
          color?.withValues(alpha: 0.1) ?? Colors.blue.withValues(alpha: 0.1),
      side: BorderSide(color: color ?? Colors.blue),
    );
  }

  Widget _buildAdvancedStatistics(Map<String, dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text("Advanced Statistics",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: stats.keys.length,
          itemBuilder: (context, index) {
            final key = stats.keys.elementAt(index);
            final value = stats[key];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    key.toString().replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value?.toString() ?? '0',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void showJobStatistics() async {
    try {
      final stats = await admin.getJobStatistics();
      _showStatisticsDialog(stats);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading statistics: $e")),
      );
    }
  }

  void _showStatisticsDialog(Map<String, dynamic> stats) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Job Statistics",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // Overall Statistics
                if (stats['overall'] != null)
                  _buildStatisticsSection("Overall", stats['overall']),

                // By Category
                if (stats['by_category'] != null &&
                    (stats['by_category'] as List).isNotEmpty)
                  _buildCategorySection(stats['by_category']),

                const SizedBox(height: 30),
                Align(
                  alignment: Alignment.centerRight,
                  child: CustomButton(
                    text: "Close",
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(String title, Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: data.keys.length,
          itemBuilder: (context, index) {
            final key = data.keys.elementAt(index);
            final value = data[key];
            final colors = [
              Colors.blue,
              Colors.green,
              Colors.orange,
              Colors.purple,
              Colors.red,
              Colors.teal
            ];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors[index % colors.length].withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors[index % colors.length]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    key.toString().replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors[index % colors.length],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value?.toString() ?? '0',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCategorySection(List<dynamic> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("By Category",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...categories.map((category) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(category['category'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                Text("${category['count'] ?? 0}",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job, ThemeProvider themeProvider) {
    final bool isActive = job['is_active'] ?? true;

    return Card(
      color: (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white)
          .withValues(alpha: 0.9),
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey,
          width: 0.3,
        ),
      ),
      child: InkWell(
        onTap: () => showJobDetails(job),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          job['title'] ?? 'Untitled Job',
                          style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (job['company'] != null && (job['company'] as String).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              job['company'] as String,
                              style: TextStyle(
                                color: themeProvider.isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.black54,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isActive ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: isActive ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (job['created_by_user'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Created by: ${job['created_by_user']['name'] ?? job['created_by_user']['email'] ?? 'Unknown'}",
                    style: TextStyle(
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade400
                          : Colors.black54,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 8),

              // Job info chips (company + employment type like candidate-facing listing)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (job['employment_type'] != null && (job['employment_type'] as String).isNotEmpty)
                    Chip(
                      label: Text(
                        (job['employment_type'] as String).replaceAll('_', ' '),
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      side: BorderSide(color: Colors.redAccent, width: 0.5),
                    ),
                  if (job['category'] != null && job['category'].isNotEmpty)
                    Chip(
                      label: Text(job['category']),
                      backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      side: BorderSide(color: Colors.blue, width: 0.5),
                    ),
                  if (job['min_experience'] != null)
                    Chip(
                      label: Text("${job['min_experience']} yrs exp"),
                      backgroundColor: Colors.orange.withValues(alpha: 0.1),
                      side: BorderSide(color: Colors.orange, width: 0.5),
                    ),
                  if (job['vacancy'] != null && job['vacancy'] > 1)
                    Chip(
                      label: Text("${job['vacancy']} vacancies"),
                      backgroundColor: Colors.purple.withValues(alpha: 0.1),
                      side: BorderSide(color: Colors.purple, width: 0.5),
                    ),
                  if (job['application_count'] != null &&
                      job['application_count'] > 0)
                    Chip(
                      label: Text("${job['application_count']} applications"),
                      backgroundColor: Colors.teal.withValues(alpha: 0.1),
                      side: BorderSide(color: Colors.teal, width: 0.5),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                job['description'] ?? 'No description',
                style: TextStyle(
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.black54,
                  fontSize: 14,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Skills preview
              if (job['required_skills'] != null &&
                  job['required_skills'].isNotEmpty)
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: (job['required_skills'] as List)
                      .take(3)
                      .map((skill) => Chip(
                            label: Text(skill.toString(),
                                style: const TextStyle(fontSize: 11)),
                            backgroundColor: themeProvider.isDarkMode
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                            side: BorderSide.none,
                          ))
                      .toList(),
                ),

              const SizedBox(height: 16),

              // Footer with actions and date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Created: ${_formatDate(job['created_at'])}",
                    style: TextStyle(
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.people, size: 20),
                        color: Colors.teal,
                        tooltip: "View Applicants",
                        onPressed: () => _showJobApplicationsDialog(job, themeProvider),
                      ),
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 20),
                        color: Colors.blue,
                        tooltip: "View Details",
                        onPressed: () => showJobDetails(job),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        color: Colors.blueAccent,
                        tooltip: "Edit",
                        onPressed: () => openJobForm(job: job),
                      ),
                      if (isActive)
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          color: Colors.redAccent,
                          tooltip: "Deactivate",
                          onPressed: () => toggleJobStatus(job),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.restore, size: 20),
                          color: Colors.orange,
                          tooltip: "Restore",
                          onPressed: () => restoreJob(job),
                        ),
                      if (widget.onJobSelected != null)
                        IconButton(
                          icon: const Icon(Icons.check_circle, size: 20),
                          color: Colors.green,
                          tooltip: "Select Job",
                          onPressed: () =>
                              widget.onJobSelected!(job['id'] as int),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildPagination() {
    if (totalPages <= 1) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black.withValues(alpha: 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1
                ? () {
                    setState(() => currentPage--);
                    fetchJobs();
                  }
                : null,
          ),
          ...List.generate(
            totalPages.clamp(1, 5),
            (index) {
              final pageNumber = index + 1;
              return TextButton(
                onPressed: () {
                  setState(() => currentPage = pageNumber);
                  fetchJobs();
                },
                style: TextButton.styleFrom(
                  foregroundColor: currentPage == pageNumber
                      ? Colors.redAccent
                      : Colors.grey,
                ),
                child: Text(pageNumber.toString()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < totalPages
                ? () {
                    setState(() => currentPage++);
                    fetchJobs();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
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
                  child: CircularProgressIndicator(color: Colors.redAccent))
              : Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Job Management",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              Row(
                                children: [
                                  CustomButton(
                                    text: "Statistics",
                                    onPressed: showJobStatistics,
                                    outlined: true,
                                  ),
                                  const SizedBox(width: 12),
                                  CustomButton(
                                    text: "Add Job",
                                    onPressed: () => openJobForm(),
                                    icon: Icons.add,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Search and Filters
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: themeProvider.isDarkMode
                                  ? Colors.black.withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                // Search Bar
                                SearchBar(
                                  hintText:
                                      "Search jobs by title, description, or skills...",
                                  onSearch: (query) {
                                    setState(() {
                                      searchQuery = query;
                                      currentPage = 1;
                                    });
                                    fetchJobs();
                                  },
                                  onClear: () {
                                    setState(() => searchQuery = '');
                                    fetchJobs();
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Filter Row
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      // Status Filter
                                      ...statusFilters.map((status) {
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: FilterChip(
                                            label: status,
                                            selected: selectedStatus == status,
                                            onSelected: (selected) {
                                              setState(() {
                                                selectedStatus = status;
                                                currentPage = 1;
                                              });
                                              fetchJobs();
                                            },
                                          ),
                                        );
                                      }).toList(),

                                      const SizedBox(width: 16),

                                      // Category Filter
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: themeProvider.isDarkMode
                                              ? Colors.grey.shade800
                                              : Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: selectedCategory,
                                            items: categories.map((category) {
                                              return DropdownMenuItem(
                                                value: category,
                                                child: Text(category),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              if (value != null) {
                                                setState(() {
                                                  selectedCategory = value;
                                                  currentPage = 1;
                                                });
                                                fetchJobs();
                                              }
                                            },
                                            style: TextStyle(
                                              color: themeProvider.isDarkMode
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                            dropdownColor:
                                                themeProvider.isDarkMode
                                                    ? Colors.grey.shade900
                                                    : Colors.white,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 16),

                                      // Sort Options
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: themeProvider.isDarkMode
                                              ? Colors.grey.shade800
                                              : Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: sortBy,
                                            items: sortOptions.map((option) {
                                              return DropdownMenuItem(
                                                value: option,
                                                child: Text(option.replaceAll(
                                                    '_', ' ')),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              if (value != null) {
                                                setState(() {
                                                  sortBy = value;
                                                  currentPage = 1;
                                                });
                                                fetchJobs();
                                              }
                                            },
                                            style: TextStyle(
                                              color: themeProvider.isDarkMode
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                            dropdownColor:
                                                themeProvider.isDarkMode
                                                    ? Colors.grey.shade900
                                                    : Colors.white,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      // Sort Order Toggle
                                      IconButton(
                                        icon: Icon(
                                          sortOrder == 'desc'
                                              ? Icons.arrow_downward
                                              : Icons.arrow_upward,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            sortOrder = sortOrder == 'desc'
                                                ? 'asc'
                                                : 'desc';
                                            currentPage = 1;
                                          });
                                          fetchJobs();
                                        },
                                        tooltip: 'Toggle sort order',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Job Count
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Showing ${jobs.length} jobs",
                            style: TextStyle(
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                          if (searchQuery.isNotEmpty ||
                              selectedCategory != 'all' ||
                              selectedStatus != 'active')
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  searchQuery = '';
                                  selectedCategory = 'all';
                                  selectedStatus = 'active';
                                  sortBy = 'created_at';
                                  sortOrder = 'desc';
                                  currentPage = 1;
                                });
                                fetchJobs();
                              },
                              child: const Text("Clear Filters"),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Jobs List
                    Expanded(
                      child: jobs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.work_outline,
                                    size: 64,
                                    color: themeProvider.isDarkMode
                                        ? Colors.grey.shade400
                                        : Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "No jobs found",
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: themeProvider.isDarkMode
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    searchQuery.isNotEmpty
                                        ? "Try adjusting your search"
                                        : "Create your first job posting",
                                    style: TextStyle(
                                      color: themeProvider.isDarkMode
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                  if (!searchQuery.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: CustomButton(
                                        text: "Add Job",
                                        onPressed: () => openJobForm(),
                                        small: true,
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: jobs.length,
                              itemBuilder: (_, index) {
                                final job = jobs[index];
                                return _buildJobCard(job, themeProvider);
                              },
                            ),
                    ),

                    // Pagination
                    _buildPagination(),
                  ],
                ),
        ),
      ),
    );
  }
}

// ---------------- Job + Assessment Form Dialog ----------------
// (Keep your existing JobFormDialog class exactly as it was)
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
  late String company;
  late String location;
  late String deadlineStr;
  String jobSummary = "";
  TextEditingController responsibilitiesController = TextEditingController();
  TextEditingController qualificationsController = TextEditingController();
  TextEditingController companyController = TextEditingController();
  TextEditingController locationController = TextEditingController();
  String companyName = "";
  String jobLocation = "";
  String companyDetails = "";
  String category = "";
  final skillsController = TextEditingController();
  final minExpController = TextEditingController();
  final salaryMinController = TextEditingController();
  final salaryMaxController = TextEditingController();
  String salaryCurrency = "ZAR";
  String salaryPeriod = "monthly";
  List<Map<String, dynamic>> questions = [];
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

  @override
  void initState() {
    super.initState();
    title = widget.job?['title'] ?? '';
    description = widget.job?['description'] ?? '';
    skillsController.text = (widget.job?['required_skills'] ?? []).join(", ");
    minExpController.text = (widget.job?['min_experience'] ?? 0).toString();
    jobSummary = widget.job?['job_summary'] ?? '';
    responsibilitiesController.text =
        (widget.job?['responsibilities'] ?? []).join(", ");
    qualificationsController.text =
        (widget.job?['qualifications'] ?? []).join(", ");
    companyController.text = widget.job?['company'] ?? '';
    locationController.text = widget.job?['location'] ?? '';
    companyName = widget.job?['company'] ?? '';
    jobLocation = widget.job?['location'] ?? '';
    companyDetails = widget.job?['company_details'] ?? '';
    salaryCurrency = widget.job?['salary_currency'] ?? 'ZAR';
    salaryMinController.text = (widget.job?['salary_min'] ?? '').toString();
    salaryMaxController.text = (widget.job?['salary_max'] ?? '').toString();
    salaryPeriod = widget.job?['salary_period'] ?? 'monthly';
    category = widget.job?['category'] ?? '';
    employmentType = widget.job?['employment_type'] ?? 'full_time';

    final jobWeightings = widget.job?['weightings'];
    if (jobWeightings is Map) {
      weightings = {
        "cv": (jobWeightings["cv"] ?? 60).toInt(),
        "assessment": (jobWeightings["assessment"] ?? 40).toInt(),
        "interview": (jobWeightings["interview"] ?? 0).toInt(),
        "references": (jobWeightings["references"] ?? 0).toInt(),
      };
    }

    knockoutRules = _normalizeKnockoutRules(widget.job?['knockout_rules']);

    if (widget.job != null &&
        widget.job!['assessment_pack'] != null &&
        widget.job!['assessment_pack']['questions'] != null) {
      questions =
          _normalizeQuestions(widget.job!['assessment_pack']['questions']);
    }

    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    responsibilitiesController.dispose();
    qualificationsController.dispose();
    companyController.dispose();
    locationController.dispose();
    skillsController.dispose();
    minExpController.dispose();
    salaryMinController.dispose();
    salaryMaxController.dispose();
    _tabController.dispose();
    super.dispose();
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

  List<Map<String, dynamic>> _normalizeKnockoutRules(dynamic raw) {
    if (raw is! List) return [];
    return raw.map<Map<String, dynamic>>((rule) {
      if (rule is Map<String, dynamic>) {
        return Map<String, dynamic>.from(rule);
      }
      return {
        "type": "skills",
        "field": "skills",
        "operator": "==",
        "value": rule.toString(),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _normalizeQuestions(dynamic raw) {
    if (raw is! List) return [];
    return raw.map<Map<String, dynamic>>((item) {
      final Map<String, dynamic> question =
          item is Map<String, dynamic> ? Map<String, dynamic>.from(item) : {};
      final rawOptions = question["options"];
      final List<dynamic> options =
          rawOptions is List ? List.from(rawOptions) : [];
      while (options.length < 4) {
        options.add("");
      }
      final normalizedOptions = options.take(4).map((opt) {
        return opt == null ? "" : opt.toString();
      }).toList();

      final rawAnswer = question["answer"] ?? question["correct_answer"];
      int answer = 0;
      if (rawAnswer is num) {
        answer = rawAnswer.toInt();
      } else if (rawAnswer is String) {
        answer = int.tryParse(rawAnswer) ?? 0;
      }
      if (answer < 0 || answer > 3) answer = 0;

      final rawWeight = question["weight"];
      double weight = 1;
      if (rawWeight is num) {
        weight = rawWeight.toDouble();
      } else if (rawWeight is String) {
        weight = double.tryParse(rawWeight) ?? 1;
      }
      if (weight <= 0) weight = 1;

      return {
        "question": question["question"]?.toString() ?? "",
        "options": normalizedOptions,
        "answer": answer,
        "weight": weight,
      };
    }).toList();
  }

  Future<void> saveJob() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final totalWeight = weightings.values.fold<int>(0, (sum, v) => sum + v);
    if (totalWeight != 100) {
      setState(() {
        weightingsError = "Weightings must total 100%";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Weightings must total 100%")),
      );
      return;
    } else {
      setState(() {
        weightingsError = null;
      });
    }

    final skills = skillsController.text
        .split(",")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final responsibilities = responsibilitiesController.text
        .split(",")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final qualifications = qualificationsController.text
        .split(",")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final normalizedQuestions = _normalizeQuestions(questions);
    final jobData = {
      'title': title,
      'description': description,
      'company': companyController.text,
      'location': locationController.text,
      'job_summary': jobSummary,
      'employment_type': employmentType,
      'responsibilities': responsibilities,
      'qualifications': qualifications,
      'company_details': companyDetails,
      'salary_min': double.tryParse(salaryMinController.text),
      'salary_max': double.tryParse(salaryMaxController.text),
      'salary_currency': salaryCurrency,
      'salary_period': salaryPeriod,
      'category': category,
      'required_skills': skills,
      'min_experience': double.tryParse(minExpController.text) ?? 0,
      'weightings': weightings,
      'knockout_rules': knockoutRules,
      'assessment_pack': {
        'questions': normalizedQuestions.map((q) {
          return {
            "question": q["question"],
            "options": q["options"],
            "correct_answer": q["answer"],
            "weight": q["weight"] ?? 1
          };
        }).toList()
      },
    };

    try {
      // Try enhanced method first
      try {
        if (widget.job == null) {
          await admin.createJobEnhanced(jobData);
        } else {
          await admin.updateJobEnhanced(widget.job!['id'] as int, jobData);
        }
      } catch (e) {
        // Fallback to original methods
        if (widget.job == null) {
          await admin.createJob(jobData);
        } else {
          await admin.updateJob(widget.job!['id'] as int, jobData);
        }
      }
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error saving job: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 650,
        height: 720,
        decoration: BoxDecoration(
          color: (themeProvider.isDarkMode
                  ? const Color(0xFF14131E)
                  : Colors.white)
              .withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
        ),
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
                  // Job Details Form
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            CustomTextField(
                              label: "Title",
                              initialValue: title,
                              hintText: "Enter job title",
                              onChanged: (v) => title = v,
                              validator: (v) =>
                                  v == null || v.isEmpty ? "Enter title" : null,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Description",
                              initialValue: description,
                              hintText: "Enter job description",
                              maxLines: 4,
                              onChanged: (v) => description = v,
                              validator: (v) => v == null || v.isEmpty
                                  ? "Enter description"
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Job Summary",
                              initialValue: jobSummary,
                              hintText: "Brief job summary",
                              maxLines: 3,
                              onChanged: (v) => jobSummary = v,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Responsibilities",
                              controller: responsibilitiesController,
                              hintText: "Comma separated list",
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Qualifications",
                              controller: qualificationsController,
                              hintText: "Comma separated list",
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Company",
                              controller: companyController,
                              hintText: "Company name",
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Location",
                              controller: locationController,
                              hintText: "City, Country or Remote",
                            ),
                            const SizedBox(height: 16),
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
                            CustomTextField(
                              label: "Salary Currency",
                              initialValue: salaryCurrency,
                              hintText: "ZAR, USD, EUR",
                              onChanged: (v) =>
                                  salaryCurrency = v.isEmpty ? "ZAR" : v,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: salaryPeriod,
                              decoration: const InputDecoration(
                                labelText: "Salary Period",
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: "monthly",
                                  child: Text("Per Month"),
                                ),
                                DropdownMenuItem(
                                  value: "yearly",
                                  child: Text("Per Year"),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => salaryPeriod = value);
                              },
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Company Details",
                              initialValue: companyDetails,
                              hintText: "About the company",
                              maxLines: 3,
                              onChanged: (v) => companyDetails = v,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Category",
                              initialValue: category,
                              hintText: "Engineering, Marketing...",
                              onChanged: (v) => category = v,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Required Skills",
                              controller: skillsController,
                              hintText: "Comma separated skills",
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Minimum Experience (years)",
                              controller: minExpController,
                              inputType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: employmentType,
                              decoration: const InputDecoration(
                                labelText: "Employment Type",
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: "full_time",
                                  child: Text("Full Time"),
                                ),
                                DropdownMenuItem(
                                  value: "part_time",
                                  child: Text("Part Time"),
                                ),
                                DropdownMenuItem(
                                  value: "contract",
                                  child: Text("Contract"),
                                ),
                                DropdownMenuItem(
                                  value: "internship",
                                  child: Text("Internship"),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  employmentType = value;
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Evaluation Weightings",
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(height: 8),
                            WeightingConfigurationWidget(
                              weightings: weightings,
                              errorText: weightingsError,
                              onChanged: (updated) {
                                setState(() {
                                  weightings = updated;
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Knockout Rules",
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(height: 8),
                            KnockoutRulesBuilder(
                              rules: knockoutRules,
                              onChanged: (updated) {
                                setState(() {
                                  knockoutRules = updated;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Assessment Tab
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
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
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        decoration: InputDecoration(
                                          labelText: "Question",
                                          labelStyle: TextStyle(
                                            color: themeProvider.isDarkMode
                                                ? Colors.grey.shade400
                                                : Colors.black87,
                                          ),
                                        ),
                                        initialValue: q["question"],
                                        onChanged: (v) => q["question"] = v,
                                        style: TextStyle(
                                          color: themeProvider.isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      ...List.generate(4, (i) {
                                        return TextFormField(
                                          decoration: InputDecoration(
                                            labelText: "Option ${i + 1}",
                                            labelStyle: TextStyle(
                                              color: themeProvider.isDarkMode
                                                  ? Colors.grey.shade400
                                                  : Colors.black87,
                                            ),
                                          ),
                                          initialValue: q["options"][i],
                                          onChanged: (v) => q["options"][i] = v,
                                          style: TextStyle(
                                            color: themeProvider.isDarkMode
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        );
                                      }),
                                      DropdownButton<int>(
                                        value: q["answer"],
                                        items: List.generate(
                                          4,
                                          (i) => DropdownMenuItem(
                                            value: i,
                                            child:
                                                Text("Correct: Option ${i + 1}",
                                                    style: TextStyle(
                                                      color: themeProvider
                                                              .isDarkMode
                                                          ? Colors.white
                                                          : Colors.black87,
                                                    )),
                                          ),
                                        ),
                                        onChanged: (v) =>
                                            setState(() => q["answer"] = v!),
                                      ),
                                      TextFormField(
                                        decoration: InputDecoration(
                                          labelText: "Weight",
                                          labelStyle: TextStyle(
                                            color: themeProvider.isDarkMode
                                                ? Colors.grey.shade400
                                                : Colors.black87,
                                          ),
                                        ),
                                        initialValue: q["weight"].toString(),
                                        keyboardType: TextInputType.number,
                                        onChanged: (v) => q["weight"] =
                                            double.tryParse(v) ?? 1,
                                        style: TextStyle(
                                          color: themeProvider.isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        CustomButton(
                            text: "Add Question", onPressed: addQuestion),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
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
            ),
          ],
        ),
      ),
    );
  }
}
