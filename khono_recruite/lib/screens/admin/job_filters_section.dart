import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/admin_state_provider.dart';
import '../../widgets/themed_surface_card.dart';
import 'package:flutter/material.dart' as material show FilterChip;

/// Job filters section component
class JobFiltersSection extends StatelessWidget {
  final TextEditingController searchController;
  final Function(String) onSearchChanged;
  final VoidCallback onFiltersChanged;

  const JobFiltersSection({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFiltersChanged,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final adminProvider = Provider.of<AdminStateProvider>(context);

    return Container(
      margin: const EdgeInsets.all(16),
      child: ThemedSurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search jobs by title, category, or description...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: onSearchChanged,
            ),

            const SizedBox(height: 16),

            // Filter options
            _buildFilterOptions(themeProvider, adminProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOptions(
      ThemeProvider themeProvider, AdminStateProvider adminProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status filter
        _buildFilterSection(
          title: 'Status',
          chips: [
            material.FilterChip(
              label: Text('All'),
              selected: adminProvider.jobsStatusFilter == 'all',
              onSelected: (selected) {
                if (selected) {
                  adminProvider.setJobsStatusFilter('all');
                  onFiltersChanged();
                }
              },
            ),
            material.FilterChip(
              label: Text('Active'),
              selected: adminProvider.jobsStatusFilter == 'active',
              onSelected: (selected) {
                if (selected) {
                  adminProvider.setJobsStatusFilter('active');
                  onFiltersChanged();
                }
              },
            ),
            material.FilterChip(
              label: Text('Inactive'),
              selected: adminProvider.jobsStatusFilter == 'inactive',
              onSelected: (selected) {
                if (selected) {
                  adminProvider.setJobsStatusFilter('inactive');
                  onFiltersChanged();
                }
              },
            ),
          ],
          themeProvider: themeProvider,
        ),

        const SizedBox(height: 16),

        // Category filter
        _buildFilterSection(
          title: 'Category',
          chips: [
            material.FilterChip(
              label: Text('All'),
              selected: adminProvider.jobsCategoryFilter == 'all',
              onSelected: (selected) {
                if (selected) {
                  adminProvider.setJobsCategoryFilter('all');
                  onFiltersChanged();
                }
              },
            ),
            material.FilterChip(
              label: Text('Engineering'),
              selected: adminProvider.jobsCategoryFilter == 'Engineering',
              onSelected: (selected) {
                if (selected) {
                  adminProvider.setJobsCategoryFilter('Engineering');
                  onFiltersChanged();
                }
              },
            ),
            material.FilterChip(
              label: Text('Marketing'),
              selected: adminProvider.jobsCategoryFilter == 'Marketing',
              onSelected: (selected) {
                if (selected) {
                  adminProvider.setJobsCategoryFilter('Marketing');
                  onFiltersChanged();
                }
              },
            ),
            material.FilterChip(
              label: Text('Sales'),
              selected: adminProvider.jobsCategoryFilter == 'Sales',
              onSelected: (selected) {
                if (selected) {
                  adminProvider.setJobsCategoryFilter('Sales');
                  onFiltersChanged();
                }
              },
            ),
            material.FilterChip(
              label: Text('HR'),
              selected: adminProvider.jobsCategoryFilter == 'HR',
              onSelected: (selected) {
                if (selected) {
                  adminProvider.setJobsCategoryFilter('HR');
                  onFiltersChanged();
                }
              },
            ),
            material.FilterChip(
              label: Text('Finance'),
              selected: adminProvider.jobsCategoryFilter == 'Finance',
              onSelected: (selected) {
                if (selected) {
                  adminProvider.setJobsCategoryFilter('Finance');
                  onFiltersChanged();
                }
              },
            ),
            material.FilterChip(
              label: Text('Operations'),
              selected: adminProvider.jobsCategoryFilter == 'Operations',
              onSelected: (selected) {
                if (selected) {
                  adminProvider.setJobsCategoryFilter('Operations');
                  onFiltersChanged();
                }
              },
            ),
          ],
          themeProvider: themeProvider,
        ),

        const SizedBox(height: 16),

        // Sort options
        _buildFilterSection(
          title: 'Sort By',
          chips: [
            material.FilterChip(
              label: Text('Created Date'),
              selected: adminProvider.jobsSortBy == 'created_at',
              onSelected: (selected) {
                if (selected) {
                  adminProvider.setJobsSortBy('created_at');
                  onFiltersChanged();
                }
              },
            ),
            material.FilterChip(
              label: Text('Title'),
              selected: adminProvider.jobsSortBy == 'title',
              onSelected: (selected) {
                if (selected) {
                  adminProvider.setJobsSortBy('title');
                  onFiltersChanged();
                }
              },
            ),
            material.FilterChip(
              label: Text('Applications'),
              selected: adminProvider.jobsSortBy == 'applications_count',
              onSelected: (selected) {
                if (selected) {
                  adminProvider.setJobsSortBy('applications_count');
                  onFiltersChanged();
                }
              },
            ),
          ],
          themeProvider: themeProvider,
        ),

        const SizedBox(height: 8),

        // Sort order toggle
        Row(
          children: [
            Text(
              'Sort Order:',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade300
                    : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 8),
            material.FilterChip(
              label: Text(adminProvider.jobsSortOrder == 'desc'
                  ? 'Newest First'
                  : 'Oldest First'),
              selected: true,
              onSelected: (selected) {
                adminProvider.toggleJobsSortOrder();
                onFiltersChanged();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterSection({
    required String title,
    required List<Widget> chips,
    required ThemeProvider themeProvider,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: themeProvider.isDarkMode
                ? Colors.grey.shade300
                : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips,
        ),
      ],
    );
  }
}
