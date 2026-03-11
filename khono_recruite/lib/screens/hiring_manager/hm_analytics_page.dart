import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../constants/app_colors.dart';
import '../../services/analytics_service.dart';
import 'package:intl/intl.dart';
import '../../utils/app_config.dart';

class HMAnalyticsPage extends StatefulWidget {
  const HMAnalyticsPage({super.key});

  @override
  State<HMAnalyticsPage> createState() => _HMAnalyticsPageState();
}

class _HMAnalyticsPageState extends State<HMAnalyticsPage> {
  bool _isLoading = true;
  String _selectedTimeRange = 'Last 6 Months';
  final AnalyticsService _service =
      AnalyticsService(baseUrl: AppConfig.apiBase);

  // Data holders
  List<Map<String, dynamic>> _monthlyApps = [];
  List<Map<String, dynamic>> _offersByCategory = [];
  Map<String, dynamic> _skillsFreq = {};
  Map<String, dynamic> _expDist = {};
  List<Map<String, dynamic>> _appsPerReq = [];
  List<Map<String, dynamic>> _assessmentTrend = [];

  String? _error;

  // Same design system as CV review screen (light/dark)
  static const Color _kPrimary = Color(0xFFC10D00);
  static const Color _kDarkSurface = Color(0xFF2C3E50);
  static const double _kCardAndHeaderOpacity = 0.7; // dark mode
  static const double _kCardOpacityLight = 0.98; // light mode: thick, minimal see-through
  static const double _kTranslucentOpacity = 0.9;
  static const double _kCardRadius = 16;

  Widget _buildThemedCard(Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? _kDarkSurface.withValues(alpha: _kCardAndHeaderOpacity)
            : Colors.white.withValues(alpha: _kCardOpacityLight),
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Color _textPrimary(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? Colors.white
          : AppColors.textDark;

  Color _textSecondary(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? Colors.white70
          : AppColors.textGrey;

  @override
  void initState() {
    super.initState();
    _loadAllAnalytics();
  }

  Future<void> _loadAllAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _service.monthlyApplications(),
        _service.offersByCategory(),
        _service.skillsFrequency(),
        _service.experienceDistribution(),
        _service.applicationsPerRequisition(),
        _service.assessmentPassRate(),
      ]);

      _monthlyApps = List<Map<String, dynamic>>.from(
          (results[0] as List).map((e) => Map<String, dynamic>.from(e)));
      _offersByCategory = List<Map<String, dynamic>>.from(
          (results[1] as List).map((e) => Map<String, dynamic>.from(e)));
      _skillsFreq = Map<String, dynamic>.from(results[2] as Map);
      _expDist = Map<String, dynamic>.from(results[3] as Map);
      _appsPerReq = List<Map<String, dynamic>>.from(
          (results[4] as List).map((e) => Map<String, dynamic>.from(e)));
      _assessmentTrend = List<Map<String, dynamic>>.from(
          (results[5] as List).map((e) => Map<String, dynamic>.from(e)));
    } catch (e, st) {
      _error = e.toString();
      debugPrint('Analytics load error: $e\n$st');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: GoogleFonts.poppins(fontSize: 14, color: _textPrimary(context)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
            const SizedBox(height: 16),
            _buildTimeRangeSelector(),
            const SizedBox(height: 16),
            _isLoading
                ? SizedBox(
                    height: 400,
                    child: _buildLoadingState(),
                  )
                : _error != null
                    ? SizedBox(
                        height: 200,
                        child: _buildError(),
                      )
                    : _buildAnalyticsContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Analytics & Insights',
            style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _textPrimary(context))),
        Row(children: [
          ElevatedButton.icon(
            onPressed: () => _exportCsv(),
            icon: const Icon(Icons.download),
            label: Text('Export CSV', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _loadAllAnalytics,
            icon: const Icon(Icons.refresh),
            label: Text('Refresh', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          ),
        ]),
      ],
    );
  }

  Widget _buildTimeRangeSelector() {
    return Row(children: [
      Text('Time Range:',
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textPrimary(context))),
      const SizedBox(width: 12),
      DropdownButton<String>(
        value: _selectedTimeRange,
        style: GoogleFonts.poppins(color: _textPrimary(context), fontSize: 14),
        dropdownColor: Theme.of(context).brightness == Brightness.dark
            ? _kDarkSurface.withValues(alpha: _kTranslucentOpacity)
            : Colors.white,
        items: ['Last Month', 'Last 3 Months', 'Last 6 Months', 'Last Year']
            .map((range) => DropdownMenuItem(
                value: range,
                child: Text(range,
                    style: GoogleFonts.poppins(
                        color: _textPrimary(context)))))
            .toList(),
        onChanged: (value) {
          setState(() => _selectedTimeRange = value!);
          _loadAllAnalytics();
        },
      ),
    ]);
  }

  Widget _buildLoadingState() {
    return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          const CircularProgressIndicator(
              valueColor: const AlwaysStoppedAnimation<Color>(_kPrimary)),
          const SizedBox(height: 16),
          Text('Loading analytics...',
              style: GoogleFonts.poppins(color: _textSecondary(context), fontSize: 16)),
        ]));
  }

  Widget _buildError() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Failed to load analytics: $_error',
          style: GoogleFonts.poppins(color: Colors.red)),
      const SizedBox(height: 12),
      ElevatedButton(
          onPressed: _loadAllAnalytics,
          child: Text('Retry', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)))
    ]));
  }

  Widget _buildAnalyticsContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, constraints) {
            final cross = constraints.maxWidth > 900
                ? 3
                : (constraints.maxWidth > 600 ? 2 : 1);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cross,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildStylishHiringTrendChart(),
                _buildStylishSourcePerformanceChart(),
                _buildStylishAssessmentPassChart(),
                _buildStylishOffersByCategoryChart(),
                _buildStylishSkillsFrequencyChart(),
                _buildStylishExperienceDistributionChart(),
              ],
            );
          }),
          const SizedBox(height: 24),
          _buildDetailedReports(),
        ],
      ),
    );
  }

  // ---------------- Stylish Charts ----------------

  Widget _buildStylishHiringTrendChart() {
    return _buildThemedCard(Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Applications / Month',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary(context))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${_monthlyApps.length} months',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _kPrimary)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SfCartesianChart(
                margin: EdgeInsets.zero,
                plotAreaBorderWidth: 0,
                primaryXAxis: CategoryAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                  axisLine: const AxisLine(width: 0),
                  labelStyle:
                      GoogleFonts.poppins(color: _textSecondary(context), fontSize: 10),
                ),
                primaryYAxis: NumericAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                  axisLine: const AxisLine(width: 0),
                  labelStyle:
                      GoogleFonts.poppins(color: _textSecondary(context), fontSize: 10),
                ),
                series: <CartesianSeries>[
                  SplineSeries<Map<String, dynamic>, String>(
                    dataSource: _monthlyApps,
                    xValueMapper: (d, _) => d['month'] ?? '',
                    yValueMapper: (d, _) => (d['applications'] ?? 0) as num,
                    color: _kPrimary,
                    width: 3,
                    markerSettings: const MarkerSettings(
                      isVisible: true,
                      color: _kPrimary,
                      borderWidth: 2,
                      borderColor: Colors.white,
                    ),
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      textStyle:
                          GoogleFonts.poppins(fontSize: 10, color: _textPrimary(context)),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ));
  }

  Widget _buildStylishSourcePerformanceChart() {
    final data = _appsPerReq.take(8).toList(); // Limit for better display
    return _buildThemedCard(Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Top Requisitions',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary(context))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${data.length} roles',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SfCartesianChart(
                margin: EdgeInsets.zero,
                plotAreaBorderWidth: 0,
                primaryXAxis: CategoryAxis(
                  labelRotation: -45,
                  majorGridLines: const MajorGridLines(width: 0),
                  axisLine: const AxisLine(width: 0),
                  labelStyle:
                      GoogleFonts.poppins(color: _textSecondary(context), fontSize: 9),
                ),
                primaryYAxis: NumericAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                  axisLine: const AxisLine(width: 0),
                  labelStyle:
                      GoogleFonts.poppins(color: _textSecondary(context), fontSize: 10),
                ),
                series: <CartesianSeries>[
                  BarSeries<Map<String, dynamic>, String>(
                    dataSource: data,
                    xValueMapper: (d, _) =>
                        _truncateTitle((d['title'] ?? '').toString()),
                    yValueMapper: (d, _) => (d['applications'] ?? 0) as num,
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      textStyle:
                          GoogleFonts.poppins(fontSize: 9, color: _textPrimary(context)),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ));
  }

  Widget _buildStylishAssessmentPassChart() {
    final data = _assessmentTrend;
    return _buildThemedCard(Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Assessment Pass Rate',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary(context))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Trend',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SfCartesianChart(
                margin: EdgeInsets.zero,
                plotAreaBorderWidth: 0,
                primaryXAxis: CategoryAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                  axisLine: const AxisLine(width: 0),
                  labelStyle:
                      GoogleFonts.poppins(color: _textSecondary(context), fontSize: 10),
                ),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.percentPattern(),
                  majorGridLines: const MajorGridLines(width: 0),
                  axisLine: const AxisLine(width: 0),
                  labelStyle:
                      GoogleFonts.poppins(color: _textSecondary(context), fontSize: 10),
                ),
                series: <CartesianSeries>[
                  LineSeries<Map<String, dynamic>, String>(
                    dataSource: data,
                    xValueMapper: (d, _) => d['month'] ?? '',
                    yValueMapper: (d, _) =>
                        ((d['pass_rate_percent'] ?? 0) as num) / 100,
                    color: Colors.purple,
                    width: 3,
                    markerSettings: const MarkerSettings(
                      isVisible: true,
                      color: Colors.purple,
                      borderWidth: 2,
                      borderColor: Colors.white,
                    ),
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      labelAlignment: ChartDataLabelAlignment.auto,
                      textStyle: GoogleFonts.poppins(
                          fontSize: 10, color: _textPrimary(context)),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ));
  }

  Widget _buildStylishOffersByCategoryChart() {
    final data = _offersByCategory;
    return _buildThemedCard(Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Offers by Category',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary(context))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${data.length} categories',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SfCircularChart(
                margin: EdgeInsets.zero,
                series: <CircularSeries>[
                  DoughnutSeries<Map<String, dynamic>, String>(
                    dataSource: data,
                    xValueMapper: (d, _) => (d['category'] ?? '') as String,
                    yValueMapper: (d, _) => (d['offers'] ?? 0) as num,
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      textStyle:
                          GoogleFonts.poppins(fontSize: 10, color: _textPrimary(context)),
                    ),
                    innerRadius: '60%',
                    radius: '100%',
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStylishSkillsFrequencyChart() {
    final items = _skillsFreq.entries
        .map((e) => {'skill': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    final topSkills = items.take(8).toList();

    return _buildThemedCard(Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Top Skills',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary(context))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${topSkills.length} skills',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SfCartesianChart(
                margin: EdgeInsets.zero,
                plotAreaBorderWidth: 0,
                primaryXAxis: CategoryAxis(
                  labelRotation: -45,
                  majorGridLines: const MajorGridLines(width: 0),
                  axisLine: const AxisLine(width: 0),
                  labelStyle:
                      GoogleFonts.poppins(color: _textSecondary(context), fontSize: 9),
                ),
                primaryYAxis: NumericAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                  axisLine: const AxisLine(width: 0),
                  labelStyle:
                      GoogleFonts.poppins(color: _textSecondary(context), fontSize: 10),
                ),
                series: <CartesianSeries>[
                  ColumnSeries<Map<String, dynamic>, String>(
                    dataSource: topSkills,
                    xValueMapper: (d, _) => d['skill'] as String,
                    yValueMapper: (d, _) => (d['count'] ?? 0) as num,
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      textStyle:
                          GoogleFonts.poppins(fontSize: 9, color: _textPrimary(context)),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ));
  }

  Widget _buildStylishExperienceDistributionChart() {
    final items = _expDist.entries
        .map((e) => {'years': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => int.parse(a['years'].toString())
          .compareTo(int.parse(b['years'].toString())));

    return _buildThemedCard(Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Experience Distribution',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary(context))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${items.length} ranges',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SfCartesianChart(
                margin: EdgeInsets.zero,
                plotAreaBorderWidth: 0,
                primaryXAxis: CategoryAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                  axisLine: const AxisLine(width: 0),
                  labelStyle:
                      GoogleFonts.poppins(color: _textSecondary(context), fontSize: 10),
                ),
                primaryYAxis: NumericAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                  axisLine: const AxisLine(width: 0),
                  labelStyle:
                      GoogleFonts.poppins(color: _textSecondary(context), fontSize: 10),
                ),
                series: <CartesianSeries>[
                  BarSeries<Map<String, dynamic>, String>(
                    dataSource: items,
                    xValueMapper: (d, _) => '${d['years']} yrs',
                    yValueMapper: (d, _) => (d['count'] ?? 0) as num,
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(4),
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      textStyle:
                          GoogleFonts.poppins(fontSize: 10, color: _textPrimary(context)),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ));
  }

  String _truncateTitle(String title) {
    if (title.length <= 15) return title;
    return '${title.substring(0, 12)}...';
  }

  Widget _buildDetailedReports() {
    return Column(children: [
      _buildReportCard('Hiring Report'),
      const SizedBox(height: 12),
      _buildReportCard('Source Report'),
      const SizedBox(height: 12),
      _buildReportCard('Time to Fill Report'),
    ]);
  }

  Widget _buildReportCard(String title) {
    return _buildThemedCard(ListTile(
      title: Text(title, style: GoogleFonts.poppins(color: _textPrimary(context), fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward, color: _kPrimary),
      onTap: () => _viewDetailedReport(title),
    ));
  }

  void _exportCsv() {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export CSV not implemented.', style: GoogleFonts.poppins())));
  }

  void _viewDetailedReport(String title) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('$title Report', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              content: Text(
                  'Detailed report view - implement navigation to full report page.',
                  style: GoogleFonts.poppins()),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)))
              ],
            ));
  }
}
