import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/admin_dashboard_components.dart';

/// Dashboard statistics section component
class DashboardStatsSection extends StatelessWidget {
  final bool isLoading;
  final Map<String, dynamic> stats;
  final VoidCallback onRefresh;

  const DashboardStatsSection({
    super.key,
    required this.isLoading,
    required this.stats,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final crossAxisCount = _getCrossAxisCount(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Overview',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            if (!isLoading)
              IconButton(
                onPressed: onRefresh,
                icon: Icon(
                  Icons.refresh,
                  size: 20,
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (isLoading)
          const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (stats.isEmpty)
          SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Statistics Available',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unable to load dashboard statistics. Please try again.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _buildStatsGrid(themeProvider, crossAxisCount),
      ],
    );
  }

  Widget _buildStatsGrid(ThemeProvider themeProvider, int crossAxisCount) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        DashboardStatCard(
          title: 'Total Jobs',
          value: (stats['jobs'] ?? 0).toString(),
          icon: Icons.work_outline,
          subtitle: _getJobsSubtitle(),
          onTap: () {
            // Navigate to job management
          },
        ),
        DashboardStatCard(
          title: 'Candidates',
          value: (stats['candidates'] ?? 0).toString(),
          icon: Icons.people_outline,
          subtitle: _getCandidatesSubtitle(),
          onTap: () {
            // Navigate to candidate management
          },
        ),
        DashboardStatCard(
          title: 'Interviews',
          value: (stats['interviews'] ?? 0).toString(),
          icon: Icons.calendar_today_outlined,
          subtitle: _getInterviewsSubtitle(),
          onTap: () {
            // Navigate to interview management
          },
        ),
        DashboardStatCard(
          title: 'Applications',
          value: (stats['applications'] ?? 0).toString(),
          icon: Icons.description_outlined,
          subtitle: _getApplicationsSubtitle(),
          onTap: () {
            // Navigate to application management
          },
        ),
        DashboardStatCard(
          title: 'CV Reviews',
          value: (stats['cv_reviews'] ?? 0).toString(),
          icon: Icons.rate_review_outlined,
          subtitle: _getCVReviewsSubtitle(),
          onTap: () {
            // Navigate to CV reviews
          },
        ),
        DashboardStatCard(
          title: 'Offers',
          value: (stats['offers'] ?? 0).toString(),
          icon: Icons.card_giftcard_outlined,
          subtitle: _getOffersSubtitle(),
          onTap: () {
            // Navigate to offer management
          },
        ),
      ],
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    // Responsive grid based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 3;
    if (screenWidth > 800) return 2;
    return 1;
  }

  String _getJobsSubtitle() {
    final activeJobs = stats['active_jobs'] ?? 0;
    return '$activeJobs active';
  }

  String _getCandidatesSubtitle() {
    final newCandidates = stats['new_candidates_today'] ?? 0;
    return '$newCandidates new today';
  }

  String _getInterviewsSubtitle() {
    final todayInterviews = stats['interviews_today'] ?? 0;
    return '$todayInterviews today';
  }

  String _getApplicationsSubtitle() {
    final pendingApplications = stats['pending_applications'] ?? 0;
    return '$pendingApplications pending';
  }

  String _getCVReviewsSubtitle() {
    final pendingReviews = stats['pending_cv_reviews'] ?? 0;
    return '$pendingReviews pending';
  }

  String _getOffersSubtitle() {
    final pendingOffers = stats['pending_offers'] ?? 0;
    return '$pendingOffers pending';
  }
}
