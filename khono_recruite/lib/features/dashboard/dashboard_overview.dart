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
import '../../core/widgets/circle_icon.dart';
import '../../core/widgets/primary_button.dart';

class DashboardOverview extends StatelessWidget {
  final Map<String, dynamic> stats;
  final List<dynamic> recentActivities;
  final List<dynamic> upcomingInterviews;

  const DashboardOverview({
    super.key,
    required this.stats,
    this.recentActivities = const [],
    this.upcomingInterviews = const [],
  });

  @override
  Widget build(BuildContext context) {
    // Determine screen width to handle rudimentary responsiveness if needed, but keeping fixed layout as requested
    return Container(
      color: Colors.transparent, // Background texture goes under this
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ROW 1 (3 cards)
                  Row(
                    children: [
                      Flexible(
                        flex: 1,
                        child: MetricCard(
                          title: "Total Jobs",
                          value: (stats["jobs"] ?? 6).toString(),
                          icon: Icons.work_outline,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        flex: 1,
                        child: MetricCard(
                          title: "Candidates",
                          value: (stats["candidates"] ?? 15).toString(),
                          icon: Icons.people_outline,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        flex: 1,
                        child: MetricCard(
                          title: "Interviews",
                          value: (stats["interviews"] ?? 4).toString(),
                          icon: Icons.people_alt_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ROW 2 (2 cards)
                  Row(
                    children: [
                      Flexible(
                        flex: 1,
                        child: MetricCard(
                          title: "Applications",
                          value: (stats["applications"] ?? 7).toString(),
                          icon: Icons.description_outlined,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        flex: 1,
                        child: MetricCard(
                          title: "Offers",
                          value: (stats["offers"] ?? 0).toString(),
                          icon: Icons.check_circle_outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ROW 3
                  Row(
                    children: [
                      Expanded(
                        child: ListCard(
                          height: 266,
                          title: "Upcoming Interviews",
                          headerIcon: Icons.date_range,
                          items: upcomingInterviews.isEmpty
                              ? _getDummyInterviews()
                              : upcomingInterviews,
                          itemBuilder: _buildInterviewRow,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ListCard(
                          height: 266,
                          title: "Recent Updates",
                          headerIcon: Icons.update,
                          items: recentActivities.isEmpty
                              ? _getDummyUpdates()
                              : recentActivities,
                          itemBuilder: _buildUpdateRow,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ROW 4
                  Row(
                    children: const [
                      Expanded(
                        child: ChartCard(
                          height: 289,
                          title: "Jobs by Department",
                          icon: Icons.pie_chart_outline,
                          chart: JobsDonutChart(),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ChartCard(
                          height: 289,
                          title: "Candidates by Job Role",
                          icon: Icons.bar_chart,
                          chart: CandidatesBarChart(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ROW 5
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const ChartCard(
                              height: 289,
                              title: "Interview Status",
                              icon: Icons.insert_chart_outlined,
                              // In a real scenario, use another chart widget. Using bar chart as placeholder.
                              chart: CandidatesBarChart(),
                            ),
                            const SizedBox(height: 16),
                            const ChartCard(
                              height: 289,
                              title: "CV Review Trend",
                              icon: Icons.show_chart,
                              chart: ReviewTrendChart(),
                            ),
                            const SizedBox(height: 16),
                            ListCard(
                              height: 248,
                              title: "Team Collaboration",
                              headerIcon: Icons.group_work_outlined,
                              items: _getDummyTeamTasks(),
                              itemBuilder: _buildTaskRow,
                            ),
                            const SizedBox(height: 16),
                            ListCard(
                              height: 248,
                              title: "Recent Activities",
                              headerIcon: Icons.history,
                              items: _getDummyTeamTasks(),
                              itemBuilder: _buildTaskRow,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
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

  Widget _buildHeader() {
    return Row(
      children: [
        Flexible(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "Admin Dashboard ",
                  style: AppTextStyles.title,
                ),
                TextSpan(
                  text: "Hello, Admin User", // Can be dynamic
                  style: AppTextStyles.cardTitle
                      .copyWith(color: AppColors.textSecondary),
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
            const CircleIcon(icon: Icons.mail_outline, size: 36, iconSize: 20),
            const SizedBox(width: 12),
            const CircleIcon(
                icon: Icons.notifications_none, size: 36, iconSize: 20),
          ],
        )
      ],
    );
  }

  Widget _buildInterviewRow(dynamic item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const CircleIcon(
              icon: Icons.person,
              size: 32,
              iconSize: 18,
              backgroundColor: AppColors.card,
              iconColor: AppColors.white),
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
                              color: AppColors.white,
                              fontWeight: FontWeight.normal)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text("Jane Doe - March 30 2026 (10:30 AM)",
                    style: AppTextStyles.small
                        .copyWith(color: AppColors.textMuted),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const CircleIcon(
              icon: Icons.warning_amber_rounded,
              size: 32,
              iconSize: 18,
              backgroundColor: AppColors.card,
              iconColor: AppColors.orange),
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
                              color: AppColors.white,
                              fontWeight: FontWeight.normal)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text("Received from John Smith - Platform",
                    style: AppTextStyles.small
                        .copyWith(color: AppColors.textMuted),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title'] ?? 'Completed Candidate Screening',
                    style: AppTextStyles.small.copyWith(
                        color: AppColors.white, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(item['subtitle'] ?? 'System / Team Member',
                    style: AppTextStyles.small
                        .copyWith(color: AppColors.textMuted),
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
