import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/themed_surface_card.dart';

/// Job list view component with lazy loading
class JobListView extends StatelessWidget {
  final List<Map<String, dynamic>> jobs;
  final bool isLoading;
  final bool hasMore;
  final Function(int jobId)? onJobSelected;
  final Function(Map<String, dynamic> job)? onJobEdited;
  final Function(Map<String, dynamic> job)? onJobDeleted;
  final Function(Map<String, dynamic> job)? onJobToggled;

  const JobListView({
    super.key,
    required this.jobs,
    required this.isLoading,
    required this.hasMore,
    this.onJobSelected,
    this.onJobEdited,
    this.onJobDeleted,
    this.onJobToggled,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (jobs.isEmpty && !isLoading) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.work_outline,
                size: 64,
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade600
                    : Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No Jobs Found',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color:
                      themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create your first job to get started.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
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
          // Add loading indicator at the end
          if (index == jobs.length) {
            if (isLoading) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            } else if (!hasMore && jobs.isNotEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No more jobs to load',
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              );
            }
            return null;
          }

          final job = jobs[index];
          return JobCard(
            job: job,
            onTap: () => onJobSelected?.call(job['id']),
            onEdit: () => onJobEdited?.call(job),
            onDelete: () => onJobDeleted?.call(job),
            onToggleStatus: () => onJobToggled?.call(job),
          );
        },
        childCount: jobs.length + (isLoading || hasMore ? 1 : 0),
      ),
    );
  }
}

/// Individual job card component
class JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleStatus;

  const JobCard({
    super.key,
    required this.job,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isActive = job['status'] == 'active';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ThemedSurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['title'] ?? 'Untitled Job',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job['category'] ?? 'Uncategorized',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: themeProvider.isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            onEdit?.call();
                            break;
                          case 'toggle':
                            onToggleStatus?.call();
                            break;
                          case 'delete':
                            onDelete?.call();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16),
                              const SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(
                                isActive ? Icons.pause : Icons.play_arrow,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(isActive ? 'Deactivate' : 'Activate'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: Colors.red),
                              const SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Job details
            _buildJobDetails(themeProvider),

            const SizedBox(height: 12),

            // Footer with stats and actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildJobStats(themeProvider),
                ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: const Color(0xFFC10D00),
                    side: const BorderSide(color: Color(0xFFC10D00)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'View Details',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobDetails(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (job['description'] != null &&
            job['description'].toString().isNotEmpty) ...[
          Text(
            job['description'].toString().length > 100
                ? '${job['description'].toString().substring(0, 100)}...'
                : job['description'].toString(),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade300
                  : Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Requirements and other details
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (job['min_experience'] != null)
              _buildDetailChip(
                '${job['min_experience']}+ years',
                Icons.work_outline,
                themeProvider,
              ),
            if (job['vacancy'] != null)
              _buildDetailChip(
                '${job['vacancy']} vacancies',
                Icons.people_outline,
                themeProvider,
              ),
            if (job['location'] != null)
              _buildDetailChip(
                job['location'],
                Icons.location_on_outlined,
                themeProvider,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailChip(
      String label, IconData icon, ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Colors.grey.shade800
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: themeProvider.isDarkMode
                ? Colors.grey.shade400
                : Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade300
                  : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobStats(ThemeProvider themeProvider) {
    return Row(
      children: [
        _buildStatItem(
          'Applications',
          '${job['applications_count'] ?? 0}',
          Icons.description_outlined,
          themeProvider,
        ),
        const SizedBox(width: 16),
        _buildStatItem(
          'Views',
          '${job['views_count'] ?? 0}',
          Icons.visibility_outlined,
          themeProvider,
        ),
      ],
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            color: themeProvider.isDarkMode
                ? Colors.grey.shade400
                : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
