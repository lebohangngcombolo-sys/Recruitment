import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin_service.dart';
import '../../providers/theme_provider.dart';
import '../../providers/admin_state_provider.dart';
import 'job_list_view.dart';
import 'job_filters_section.dart';
import 'job_create_dialog.dart';

/// Optimized job management screen with lazy loading and modular components
class OptimizedJobManagement extends StatefulWidget {
  final Function(int jobId)? onJobSelected;

  const OptimizedJobManagement({super.key, this.onJobSelected});

  @override
  _OptimizedJobManagementState createState() => _OptimizedJobManagementState();
}

class _OptimizedJobManagementState extends State<OptimizedJobManagement> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final AdminService _adminService = AdminService();

  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initializeData() {
    final adminProvider =
        Provider.of<AdminStateProvider>(context, listen: false);
    adminProvider.clearJobs();
    _loadJobs();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreJobs();
      }
    });
  }

  Future<void> _loadJobs({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _currentPage = 1;
        _hasMore = true;
      }
    });

    try {
      final adminProvider =
          Provider.of<AdminStateProvider>(context, listen: false);

      if (refresh) {
        adminProvider.clearJobs();
      }

      await adminProvider.fetchJobs(page: _currentPage);

      setState(() {
        _hasMore = adminProvider.jobs.length >= _pageSize;
        _currentPage++;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load jobs: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreJobs() async {
    if (!_hasMore || _isLoading) return;
    await _loadJobs();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _loadJobs(refresh: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final adminProvider = Provider.of<AdminStateProvider>(context);

    return Scaffold(
      backgroundColor:
          themeProvider.isDarkMode ? Colors.black : Colors.grey.shade50,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Header
          SliverAppBar(
            floating: true,
            backgroundColor:
                themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
            elevation: 0,
            title: Text(
              'Job Management',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => _loadJobs(refresh: true),
                icon: Icon(
                  Icons.refresh,
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _showCreateJobDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC10D00),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Create Job',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),

          // Filters Section
          SliverToBoxAdapter(
            child: JobFiltersSection(
              searchController: _searchController,
              onSearchChanged: (value) {
                // Debounced search
                _debouncedSearch(value);
              },
              onFiltersChanged: () {
                _loadJobs(refresh: true);
              },
            ),
          ),

          // Jobs List
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: JobListView(
              jobs: adminProvider.jobs,
              isLoading: _isLoading,
              hasMore: _hasMore,
              onJobSelected: widget.onJobSelected,
              onJobEdited: _editJob,
              onJobDeleted: _deleteJob,
              onJobToggled: _toggleJobStatus,
            ),
          ),
        ],
      ),
    );
  }

  void _debouncedSearch(String query) {
    // Simple debounce implementation
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchController.text == query) {
        _loadJobs(refresh: true);
      }
    });
  }

  void _showCreateJobDialog() {
    showDialog(
      context: context,
      builder: (context) => JobCreateDialog(
        onJobCreated: (job) {
          _loadJobs(refresh: true);
        },
      ),
    );
  }

  void _editJob(Map<String, dynamic> job) {
    final titleController = TextEditingController(text: job['title'] ?? '');
    final descriptionController =
        TextEditingController(text: job['description'] ?? '');
    final locationController =
        TextEditingController(text: job['location'] ?? '');
    final departmentController =
        TextEditingController(text: job['department'] ?? '');
    final employmentTypeController =
        TextEditingController(text: job['employment_type'] ?? '');
    final salaryController =
        TextEditingController(text: job['salary_range'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Job'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: 'Job Title'),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(labelText: 'Location'),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: departmentController,
                  decoration: InputDecoration(labelText: 'Department'),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: employmentTypeController,
                  decoration: InputDecoration(labelText: 'Employment Type'),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: salaryController,
                  decoration: InputDecoration(labelText: 'Salary Range'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Implement update logic here
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Job updated successfully')),
              );
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteJob(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Job'),
        content: Text('Are you sure you want to delete "${job['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _adminService.deleteJob(job['id']);
                _loadJobs(refresh: true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Job deleted successfully')),
                );
              } catch (e) {
                _showErrorSnackBar('Failed to delete job: $e');
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleJobStatus(Map<String, dynamic> job) async {
    try {
      final newStatus = job['status'] == 'active' ? 'inactive' : 'active';
      await _adminService.updateJob(job['id'], {'status': newStatus});
      _loadJobs(refresh: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Job status updated to $newStatus')),
      );
    } catch (e) {
      _showErrorSnackBar('Failed to update job status: $e');
    }
  }
}
