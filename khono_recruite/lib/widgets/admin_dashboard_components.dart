import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/theme_provider.dart';
import 'themed_surface_card.dart';

/// Dashboard statistics card component
class DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final String? subtitle;
  final VoidCallback? onTap;

  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.iconColor,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ThemedSurfaceCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (iconColor ?? const Color(0xFFC10D00))
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: iconColor ?? const Color(0xFFC10D00),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade500
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chart data model for dashboard charts
class ChartData {
  final String category;
  final double value;
  final Color? color;

  ChartData(this.category, this.value, {this.color});
}

/// Dashboard chart component
class DashboardChart extends StatelessWidget {
  final String title;
  final List<ChartData> data;
  final ChartType chartType;
  final String? subtitle;

  const DashboardChart({
    super.key,
    required this.title,
    required this.data,
    required this.chartType,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ThemedSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildChart(themeProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(ThemeProvider themeProvider) {
    switch (chartType) {
      case ChartType.bar:
        return SfCartesianChart(
          primaryXAxis: CategoryAxis(
            labelStyle: TextStyle(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
              fontSize: 10,
            ),
            majorGridLines: const MajorGridLines(width: 0),
          ),
          primaryYAxis: NumericAxis(
            labelStyle: TextStyle(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
              fontSize: 10,
            ),
            majorGridLines: MajorGridLines(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
            ),
          ),
          tooltipBehavior: TooltipBehavior(
            enable: true,
            format: 'point.x: point.y',
          ),
          series: <CartesianSeries<ChartData, String>>[
            ColumnSeries<ChartData, String>(
              dataSource: data,
              xValueMapper: (ChartData data, _) => data.category,
              yValueMapper: (ChartData data, _) => data.value,
              pointColorMapper: (ChartData data, _) =>
                  data.color ?? const Color(0xFFC10D00),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        );
      case ChartType.pie:
        return SfCircularChart(
          tooltipBehavior: TooltipBehavior(enable: true),
          legend: Legend(
            isVisible: true,
            position: LegendPosition.bottom,
            textStyle: TextStyle(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
              fontSize: 10,
            ),
          ),
          series: <CircularSeries<ChartData, String>>[
            PieSeries<ChartData, String>(
              dataSource: data,
              xValueMapper: (ChartData data, _) => data.category,
              yValueMapper: (ChartData data, _) => data.value,
              pointColorMapper: (ChartData data, _) => data.color,
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                labelPosition: ChartDataLabelPosition.outside,
                textStyle: TextStyle(fontSize: 10),
              ),
            ),
          ],
        );
      case ChartType.line:
        return SfCartesianChart(
          primaryXAxis: CategoryAxis(
            labelStyle: TextStyle(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
              fontSize: 10,
            ),
            majorGridLines: const MajorGridLines(width: 0),
          ),
          primaryYAxis: NumericAxis(
            labelStyle: TextStyle(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
              fontSize: 10,
            ),
            majorGridLines: MajorGridLines(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
            ),
          ),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <CartesianSeries<ChartData, String>>[
            LineSeries<ChartData, String>(
              dataSource: data,
              xValueMapper: (ChartData data, _) => data.category,
              yValueMapper: (ChartData data, _) => data.value,
              color: const Color(0xFFC10D00),
              markerSettings: const MarkerSettings(
                isVisible: true,
                color: Color(0xFFC10D00),
                height: 4,
                width: 4,
              ),
            ),
          ],
        );
    }
  }
}

enum ChartType { bar, pie, line }

/// Recent activities list component
class RecentActivitiesList extends StatelessWidget {
  final List<String> activities;
  final VoidCallback? onViewAll;

  const RecentActivitiesList({
    super.key,
    required this.activities,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ThemedSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activities',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: const Color(0xFFC10D00),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (activities.isEmpty)
            Text(
              'No recent activities',
              style: TextStyle(
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
                fontSize: 14,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC10D00),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        activities[index],
                        style: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

/// PowerBI status indicator component
class PowerBIStatusIndicator extends StatelessWidget {
  final bool isConnected;
  final bool isChecking;
  final VoidCallback? onRefresh;

  const PowerBIStatusIndicator({
    super.key,
    required this.isConnected,
    required this.isChecking,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ThemedSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isChecking
                  ? Colors.orange
                  : isConnected
                      ? Colors.green
                      : Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PowerBI Integration',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isChecking
                      ? 'Checking status...'
                      : isConnected
                          ? 'Connected'
                          : 'Disconnected',
                  style: TextStyle(
                    fontSize: 12,
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (onRefresh != null && !isChecking)
            IconButton(
              onPressed: onRefresh,
              icon: Icon(
                Icons.refresh,
                size: 16,
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),
        ],
      ),
    );
  }
}

// New dashboard components for the updated design

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? color;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final brandColor = color ?? const Color(0xFFC10D00);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 3.5,
            offset: const Offset(0, 3.5),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle ??
                    'Additional description information can be included.',
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 20,
                  color: brandColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UpcomingInterviewsCard extends StatelessWidget {
  final List<Map<String, dynamic>> interviews;
  final VoidCallback? onViewAll;

  const UpcomingInterviewsCard({
    super.key,
    required this.interviews,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 3.5,
            offset: const Offset(0, 3.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFC10D00),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.people,
                          size: 20, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upcoming Interviews',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Keep track of scheduled candidates.',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (interviews.isNotEmpty)
                _buildNotificationBadge(interviews.length.toString()),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          if (interviews.isEmpty)
            _buildEmptyState('No upcoming interviews', isDark)
          else
            ...interviews
                .take(4)
                .map((interview) => _buildInterviewItem(interview, isDark)),
          if (onViewAll != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onViewAll,
                child: Text(
                  'View All',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFC10D00),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInterviewItem(Map<String, dynamic> interview, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'Scheduled Interview: ${interview['job_title'] ?? 'Role'}\n${interview['candidate_name'] ?? 'Name Surname'} - ${interview['scheduled_time'] ?? 'TBD'}',
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFCF2030),
          height: 1.2,
        ),
      ),
    );
  }
}

class RecentUpdatesCard extends StatelessWidget {
  final List<String> updates;
  final VoidCallback? onViewAll;

  const RecentUpdatesCard({
    super.key,
    required this.updates,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 3.5,
            offset: const Offset(0, 3.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFC10D00),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications,
                          size: 20, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Updates',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Additional description can be included if required.',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (updates.isNotEmpty)
                _buildNotificationBadge(updates.length.toString()),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          if (updates.isEmpty)
            _buildEmptyState('No recent updates', isDark)
          else
            ...updates
                .take(4)
                .map((update) => _buildUpdateItem(update, isDark)),
          if (onViewAll != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onViewAll,
                child: Text(
                  'View All',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFC10D00),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpdateItem(String update, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.file_copy, size: 20, color: Color(0xFFE53935)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFE53935),
                    ),
                    children: [
                      const TextSpan(text: 'New Application: '),
                      TextSpan(
                        text: update,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Received from a candidate - Source Platform',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark
                        ? Colors.white.withOpacity(0.6)
                        : const Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildPillButton('VIEW', () {}),
        ],
      ),
    );
  }
}

Widget _buildNotificationBadge(String count) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFC10D00),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      '🔔 $count',
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    ),
  );
}

Widget _buildEmptyState(String message, bool isDark) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Text(
        message,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: isDark ? Colors.white38 : Colors.grey.shade400,
        ),
      ),
    ),
  );
}

Widget _buildPillButton(String text, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(40),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFC10D00),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC10D00).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
      ),
    ),
  );
}

class DepartmentData {
  final String name;
  final double percentage;
  final Color color;

  DepartmentData(this.name, this.percentage, this.color);
}

class JobsByDepartmentCard extends StatelessWidget {
  final List<DepartmentData> departments;
  final bool isLoading;

  const JobsByDepartmentCard({
    super.key,
    required this.departments,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 3.5,
            offset: const Offset(0, 3.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with circular icon and title
          Row(
            children: [
              // Circular white icon background
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pie_chart_outline,
                  color: const Color(0xFFC10D00),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Title
              Expanded(
                child: Text(
                  'Jobs by Department',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              // Distribution badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFC10D00),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${isLoading ? '...' : departments.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Divider
          Divider(
            color: isDark ? Colors.white12 : Colors.black12,
            height: 1,
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (departments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'No department data available',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isDark
                        ? Colors.white54
                        : const Color(0xFF090812).withOpacity(0.5),
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CustomPaint(
                    size: const Size(140, 140),
                    painter: DonutChartPainter(departments),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${departments.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF090812),
                            ),
                          ),
                          Text(
                            'Depts',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF090812).withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Key Guide:',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...departments.map((dept) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: dept.color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${(dept.percentage * 100).toInt()}% ${dept.name}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<DepartmentData> departments;

  DonutChartPainter(this.departments);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 10;
    final innerRadius = outerRadius * 0.6;

    double startAngle = -math.pi / 2;
    final total = departments.fold<double>(0.0, (sum, d) => sum + d.percentage);

    // Small gap between slices for visual separation
    final gap = 0.02; // radians (~1.1 degrees)

    for (final dept in departments) {
      final rawSweep =
          total > 0 ? (dept.percentage / total) * 2 * math.pi : 0.0;
      final sweepAngle = math.max(0.0, rawSweep - gap);

      final paint = Paint()
        ..color = dept.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerRadius - innerRadius
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(
            center: center, radius: (outerRadius + innerRadius) / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      // Advance start by sweep + gap so slices are separated
      startAngle += sweepAngle + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CVData {
  final String week;
  final int value;

  CVData(this.week, this.value);
}

class CVReviewTrendCard extends StatelessWidget {
  final List<CVData> weeklyData;

  const CVReviewTrendCard({super.key, required this.weeklyData});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 3.5,
            offset: const Offset(0, 3.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with circular icon, title/subtitle, and legend
          Row(
            children: [
              // Circular white icon background
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.trending_up,
                  color: const Color(0xFFC10D00),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CV Review Trend',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Additional description can be included if required.',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Legend
              Row(
                children: [
                  _buildLegendItem(
                      'Completed', const Color(0xFFC10D00), isDark),
                  const SizedBox(width: 12),
                  _buildLegendItem('Pending', const Color(0xFFFFD700), isDark),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Divider
          Divider(
            color: isDark ? Colors.white12 : Colors.black12,
            height: 1,
          ),
          const SizedBox(height: 16),
          // Chart
          SizedBox(
            height: 180,
            child: _buildTrendChart(weeklyData, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(List<CVData> data, bool isDark) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      );
    }

    final maxValue = data.map((d) => d.value).fold(0, (a, b) => a > b ? a : b);
    final yMax = math.max(maxValue * 1.2, 10.0);

    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 0,
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: GoogleFonts.poppins(
          fontSize: 10,
          color: isDark
              ? Colors.white70
              : const Color(0xFF090812).withOpacity(0.7),
        ),
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        maximum: yMax,
        interval: yMax / 4,
        majorGridLines: MajorGridLines(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 1,
        ),
        axisLine: const AxisLine(width: 0),
        labelStyle: GoogleFonts.poppins(
          fontSize: 9,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x: point.y',
        textStyle: GoogleFonts.poppins(fontSize: 10),
      ),
      series: [
        // Bar series for completed
        ColumnSeries<CVData, String>(
          dataSource: data,
          xValueMapper: (d, _) => d.week,
          yValueMapper: (d, _) => d.value,
          pointColorMapper: (_, __) => const Color(0xFFC10D00),
          width: 0.5,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.top,
            textStyle: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            margin: const EdgeInsets.only(top: 4),
          ),
          name: 'Completed',
        ),
        // Line series for pending (using a secondary value or calculated)
        LineSeries<CVData, String>(
          dataSource: data,
          xValueMapper: (d, _) => d.week,
          yValueMapper: (d, _) => (d.value * 0.6).toInt(), // Simulated pending
          color: const Color(0xFFFFD700),
          width: 2.5,
          markerSettings: const MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            color: Color(0xFFFFD700),
            width: 10,
            height: 10,
            borderColor: Color(0xFFFFD700),
            borderWidth: 2,
          ),
          name: 'Pending',
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: isDark
                ? Colors.white70
                : const Color(0xFF090812).withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class StatusData {
  final String name;
  final int value;
  final Color color;

  StatusData(this.name, this.value, this.color);
}

class InterviewStatusCard extends StatelessWidget {
  final List<StatusData> statuses;

  const InterviewStatusCard({super.key, required this.statuses});

  /// Get theme-aware color for status based on index
  Color _getStatusColor(int index, bool isDark) {
    final darkColors = [
      const Color(0xFFB0BEC5), // Scheduled - lighter grey
      const Color(0xFF64B5F6), // Pending - lighter blue
      const Color(0xFF81C784), // Completed - lighter green
      const Color(0xFFFFB74D), // Extra color - orange
      const Color(0xFFF06292), // Extra color - pink
    ];
    final lightColors = [
      const Color(0xFF81829B), // Scheduled - grey
      const Color(0xFF6095CC), // Pending - blue
      const Color(0xFF6CA510), // Completed - green
      const Color(0xFFFF8A65), // Extra color - orange
      const Color(0xFFEC407A), // Extra color - pink
    ];
    final colors = isDark ? darkColors : lightColors;
    return colors[index % colors.length];
  }

  Widget _buildStatusChart(
      List<StatusData> statuses, int maxValue, bool isDark) {
    if (statuses.isEmpty) {
      return Center(
        child: Text(
          'No interview data',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      );
    }

    final yMax = math.max(maxValue * 1.2, 10.0);

    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 0,
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: GoogleFonts.poppins(
          fontSize: 10,
          color: isDark
              ? Colors.white70
              : const Color(0xFF090812).withOpacity(0.7),
        ),
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        maximum: yMax,
        interval: yMax / 4,
        majorGridLines: MajorGridLines(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 1,
        ),
        axisLine: const AxisLine(width: 0),
        labelStyle: GoogleFonts.poppins(
          fontSize: 9,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x: point.y',
        textStyle: GoogleFonts.poppins(fontSize: 10),
      ),
      series: [
        ColumnSeries<StatusData, String>(
          dataSource: statuses,
          xValueMapper: (s, _) => s.name,
          yValueMapper: (s, _) => s.value,
          pointColorMapper: (s, index) => _getStatusColor(index, isDark),
          width: 0.45,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.top,
            textStyle: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            margin: const EdgeInsets.only(top: 4),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final maxValue = statuses.isNotEmpty
        ? statuses.map((s) => s.value).reduce((a, b) => a > b ? a : b)
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 3.5,
            offset: const Offset(0, 3.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with circular icon, title, and subtitle
          Row(
            children: [
              // Circular white icon background
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_note,
                  color: const Color(0xFFC10D00),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interview Status',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Additional description can be included if required.',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Divider
          Divider(
            color: isDark ? Colors.white12 : Colors.black12,
            height: 1,
          ),
          const SizedBox(height: 16),
          // Bar Chart
          SizedBox(
            height: 220,
            child: _buildStatusChart(statuses, maxValue, isDark),
          ),
        ],
      ),
    );
  }
}

class TeamCollaborationCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final VoidCallback? onViewAll;

  const TeamCollaborationCard({
    super.key,
    required this.items,
    this.isLoading = false,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 3.5,
            offset: const Offset(0, 3.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with circular icon, title/subtitle, and count badge
          Row(
            children: [
              // Circular white icon background
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_outline,
                  color: const Color(0xFFC10D00),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Team Collaboration',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Additional description can be included if required.',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Count badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFC10D00),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${isLoading ? '...' : items.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Divider
          Divider(
            color: isDark ? Colors.white12 : Colors.black12,
            height: 1,
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No recent team activity',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isDark
                        ? Colors.white54
                        : const Color(0xFF090812).withOpacity(0.5),
                  ),
                ),
              ),
            )
          else
            ...items.take(5).map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC10D00),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${item['name'] ?? 'Unknown'}: ',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF090812),
                                ),
                              ),
                              TextSpan(
                                text:
                                    '${item['action'] ?? item['description'] ?? 'No action'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w400,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF090812)
                                          .withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          if (!isLoading && items.isNotEmpty && onViewAll != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: _buildViewButton('View All', onViewAll),
            ),
          ],
        ],
      ),
    );
  }
}

class DashboardCalendarCard extends StatelessWidget {
  final DateTime focusedDay;
  final List<dynamic> appointments;

  const DashboardCalendarCard({
    super.key,
    required this.focusedDay,
    required this.appointments,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final List<String> weekDays = [
      'Sun',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat'
    ];
    final int year = focusedDay.year;
    final int month = focusedDay.month;
    final int daysInMonth = DateTime(year, month + 1, 0).day;
    final int firstDayOffset = DateTime(year, month, 1).weekday % 7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 3.5,
            offset: const Offset(0, 3.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with circular icon, title, and month
          Row(
            children: [
              // Circular white icon background
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_today_outlined,
                  color: const Color(0xFFC10D00),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Title
              Text(
                'Calendar',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              // Month/Year
              Text(
                DateFormat('MMMM yyyy').format(focusedDay),
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Divider
          Divider(
            color: isDark ? Colors.white12 : Colors.black12,
            height: 1,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays.map((day) {
              return Expanded(
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.2,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              int dayNumber = index - firstDayOffset + 1;
              if (dayNumber >= 1 && dayNumber <= daysInMonth) {
                bool hasAppointment = appointments.any((a) {
                  if (a is Appointment) {
                    return a.startTime.day == dayNumber &&
                        a.startTime.month == month &&
                        a.startTime.year == year;
                  }
                  return false;
                });

                return Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: hasAppointment
                        ? const Color(0xFFC10D00).withValues(alpha: 0.4)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      '$dayNumber',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                );
              } else {
                return Container();
              }
            },
          ),
        ],
      ),
    );
  }
}

// Helper Widgets
Widget _buildViewButton(String label, VoidCallback? onTap) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFC10D00),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    ),
  );
}
