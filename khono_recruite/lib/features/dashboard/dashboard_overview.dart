import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'widgets/metric_card.dart';
import 'widgets/list_card.dart';
import 'widgets/chart_card.dart';
import 'widgets/calendar_widget.dart';
import 'widgets/chart_cards/bar_chart_widget.dart';
import 'widgets/chart_cards/donut_chart_widget.dart';
import 'widgets/chart_cards/line_chart_widget.dart';
import '../../core/widgets/primary_button.dart';

class DashboardOverview extends StatelessWidget {
  final Map<String, dynamic> stats;
  final List<dynamic> recentActivities;
  final List<dynamic> upcomingInterviews;
  final bool isDarkMode;

  const DashboardOverview({
    super.key,
    required this.stats,
    this.recentActivities = const [],
    this.upcomingInterviews = const [],
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent, // Background texture goes under this
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeader(isDarkMode),
          const SizedBox(height: 0),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ROW 1 (3 cards)
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          title: "Total Jobs",
                          subtitle: "Active job postings currently live",
                          value: (stats["jobs"] ?? 6).toString(),
                          imageAsset: 'assets/icons/Dashboard/total_jobs.png',
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MetricCard(
                          title: "Candidates",
                          subtitle: "Candidates registered in system",
                          value: (stats["candidates"] ?? 15).toString(),
                          imageAsset:
                              'assets/icons/Dashboard/dash-candidates.png',
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MetricCard(
                          title: "Interviews",
                          subtitle: "Scheduled interviews this week",
                          value: (stats["interviews"] ?? 4).toString(),
                          imageAsset:
                              'assets/icons/Dashboard/dash_interviews.png',
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ROW 2 (2 cards)
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          title: "Applications",
                          subtitle: "Pending applications to review",
                          value: (stats["applications"] ?? 7).toString(),
                          imageAsset: 'assets/icons/Dashboard/applications.png',
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MetricCard(
                          title: "Offers",
                          subtitle: "Pending offer letters to send",
                          value: (stats["offers"] ?? 0).toString(),
                          imageAsset: 'assets/icons/Dashboard/offers.png',
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ROW 3
                  Row(
                    children: [
                      Expanded(
                        child: ListCard(
                          height: 266,
                          title: "Upcoming Interviews",
                          headerImageAsset:
                              'assets/icons/Dashboard/calender.png',
                          items: upcomingInterviews.isEmpty
                              ? _getDummyInterviews()
                              : upcomingInterviews,
                          itemBuilder: (item) => _buildInterviewRow(item),
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ListCard(
                          height: 266,
                          title: "Recent Updates",
                          headerImageAsset:
                              'assets/icons/Dashboard/updates.png',
                          items: recentActivities.isEmpty
                              ? _getDummyUpdates()
                              : recentActivities,
                          itemBuilder: (item) => _buildUpdateRow(item),
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ROW 4
                  Row(
                    children: [
                      Expanded(
                        child: ChartCard(
                          height: 289,
                          title: "Jobs by Department",
                          imageAsset: 'assets/icons/Dashboard/total_jobs.png',
                          chart: JobsDonutChart(),
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChartCard(
                          height: 289,
                          title: "Candidates by Job Role",
                          imageAsset:
                              'assets/icons/Dashboard/candidates_byjobrole.png',
                          chart: CandidatesBarChart(),
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ROW 5
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            ChartCard(
                              height: 289,
                              title: "Interview Status",
                              imageAsset:
                                  'assets/icons/Dashboard/interviews.png',
                              // In a real scenario, use another chart widget. Using bar chart as placeholder.
                              chart: CandidatesBarChart(),
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 8),
                            ChartCard(
                              height: 289,
                              title: "CV Review Trend",
                              imageAsset:
                                  'assets/icons/Dashboard/reviews_trend.png',
                              chart: ReviewTrendChart(),
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 8),
                            ListCard(
                              height: 248,
                              title: "Team Collaboration",
                              headerImageAsset:
                                  'assets/icons/Dashboard/dash_teamcollaborations.png',
                              items: _getDummyTeamTasks(),
                              itemBuilder: _buildTaskRow,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 8),
                            ListCard(
                              height: 248,
                              title: "Recent Activities",
                              headerImageAsset:
                                  'assets/icons/Dashboard/recent_activities.png',
                              items: _getDummyTeamTasks(),
                              itemBuilder: _buildTaskRow,
                              isDarkMode: isDarkMode,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: CalendarCard()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Row(
      children: [
        Flexible(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "Admin Dashboard ",
                  style: AppTextStyles.title.copyWith(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                TextSpan(
                  text: "Hello, Admin User", // Can be dynamic
                  style: AppTextStyles.cardTitle.copyWith(
                    color: isDarkMode
                        ? Colors.white70
                        : Colors.black.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Image.asset('assets/icons/messeges.png',
                width: 64, height: 64, fit: BoxFit.contain),
            const SizedBox(width: 12),
            Image.asset('assets/icons/Notifications.png',
                width: 64, height: 64, fit: BoxFit.contain),
          ],
        )
      ],
    );
  }

  Widget _buildInterviewRow(dynamic item) {
    final isDarkMode =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Image.asset(
            'assets/icons/Dashboard/candidate.png',
            width: 18,
            height: 18,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    text: "Scheduled Interview: ",
                    style: AppTextStyles.small.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                          text: "Quality Assurance Analyst",
                          style: AppTextStyles.small.copyWith(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.normal)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text("Jane Doe - March 30 2026 (10:30 AM)",
                    style: AppTextStyles.small.copyWith(
                        color: isDarkMode
                            ? Colors.white70
                            : Colors.black.withValues(alpha: 0.6)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 10),
          PrimaryButton(text: "VIEW", onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildUpdateRow(dynamic item) {
    final isDarkMode =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Image.asset(
            'assets/icons/Dashboard/new_application.png',
            width: 18,
            height: 18,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    text: "New Application: ",
                    style: AppTextStyles.small.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                          text: "Software Engineer",
                          style: AppTextStyles.small.copyWith(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.normal)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text("Received from John Smith - Platform",
                    style: AppTextStyles.small.copyWith(
                        color: isDarkMode
                            ? Colors.white70
                            : Colors.black.withValues(alpha: 0.6)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 10),
          PrimaryButton(text: "VIEW", onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildTaskRow(dynamic item) {
    final isDarkMode =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Image.asset(
            'assets/icons/Dashboard/name_surname.png',
            width: 18,
            height: 18,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title'] ?? 'Completed Candidate Screening',
                    style: AppTextStyles.small.copyWith(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(item['subtitle'] ?? 'System / Team Member',
                    style: AppTextStyles.small.copyWith(
                        color: isDarkMode
                            ? Colors.white70
                            : Colors.black.withValues(alpha: 0.6)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _getDummyInterviews() {
    return [1, 2, 3, 4];
  }

  List<dynamic> _getDummyUpdates() {
    return [1, 2, 3, 4];
  }

  List<dynamic> _getDummyTeamTasks() {
    return [
      {'title': 'Completed candidate screening.', 'subtitle': 'Jane Smith'},
      {'title': 'Scheduled interview for next week.', 'subtitle': 'System'},
      {'title': 'Uploaded new CVs to review.', 'subtitle': 'John Doe'},
      {'title': 'Updated job descriptions.', 'subtitle': 'Alice Walker'},
      {'title': 'Finalized offer letters.', 'subtitle': 'Bob Builder'},
    ];
  }
}
