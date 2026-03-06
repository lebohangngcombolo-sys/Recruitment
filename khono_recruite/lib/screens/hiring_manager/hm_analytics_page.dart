import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../constants/app_colors.dart';
import '../../services/analytics_service.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import 'package:intl/intl.dart';
import '../../utils/app_config.dart';
import 'analytics_export_stub.dart' if (dart.library.html) 'analytics_export_web.dart' as analytics_export;

class HMAnalyticsPage extends StatefulWidget {
  const HMAnalyticsPage({super.key});

  @override
  State<HMAnalyticsPage> createState() => _HMAnalyticsPageState();
}

class _HMAnalyticsPageState extends State<HMAnalyticsPage> {
  bool _isLoading = true;
  bool _isExporting = false;
  String? _exportStatusMessage;
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

  // Shortlist & Recommendation section
  final AdminService _admin = AdminService();
  int? _shortlistJobId;
  List<Map<String, dynamic>> _shortlistJobs = [];
  List<Map<String, dynamic>> _shortlistCandidates = [];
  bool _shortlistLoading = false;
  bool _shortlistExporting = false;
  bool _shortlistExportingCsv = false;
  bool _shortlistJobsLoaded = false;

  // Same design system as CV review screen (light/dark)
  static const Color _kPrimary = Color(0xFFC10D00);
  static const Color _kDarkSurface = Color(0xFF2C3E50);
  static const double _kCardAndHeaderOpacity = 0.7; // dark mode
  static const double _kCardOpacityLight = 0.98; // light mode: thick, minimal see-through
  static const double _kTranslucentOpacity = 0.9;
  static const double _kCardRadius = 16;

  // Pro-level chart design system
  static const double _kChartCardPadding = 24;
  static const double _kChartTitleSize = 19;
  static const double _kChartSubtitleSize = 12;
  static const double _kChartBadgeRadius = 24;
  static const double _kChartAxisSize = 12;
  static const double _kChartDataLabelSize = 11;
  static const double _kChartBarRadius = 8;
  static const double _kChartLineWidth = 2.8;
  static const double _kChartAccentWidth = 4;
  static const double _kChartWellRadius = 14;
  static const double _kChartIconSize = 22;

  Widget _buildProChartHeader({
    required IconData icon,
    required String title,
    required String badgeLabel,
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _kPrimary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: _kChartIconSize, color: _kPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: _kChartTitleSize,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary(context),
                      letterSpacing: -0.4,
                      height: 1.25,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: _kChartSubtitleSize,
                        fontWeight: FontWeight.w400,
                        color: _textSecondary(context),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(_kChartBadgeRadius),
                border: Border.all(
                  color: _kPrimary.withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
              child: Text(
                badgeLabel,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Divider(
          height: 1,
          thickness: 1,
          color: _textSecondary(context).withValues(alpha: 0.2),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildChartWell(Widget chart) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : _kPrimary).withValues(alpha: isDark ? 0.03 : 0.04),
        borderRadius: BorderRadius.circular(_kChartWellRadius),
        border: Border.all(
          color: _textSecondary(context).withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: chart,
    );
  }

  Widget _buildThemedCard(Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = _textSecondary(context).withValues(alpha: 0.06);
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? _kDarkSurface.withValues(alpha: _kCardAndHeaderOpacity)
            : Colors.white.withValues(alpha: _kCardOpacityLight),
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kCardRadius),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _kChartAccentWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(_kCardRadius),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: _kChartAccentWidth),
              child: child,
            ),
          ],
        ),
      ),
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
    _loadShortlistJobs();
  }

  static const List<String> _shortlistRecommendationOptions = [
    'Proceed to Final Interview',
    'Hold',
    'Reject',
  ];

  Future<void> _loadShortlistJobs() async {
    if (_shortlistJobsLoaded) return;
    try {
      final data = await _admin.listJobsEnhanced(status: 'active', perPage: 200);
      final raw = (data['jobs'] as List<dynamic>?) ?? [];
      final jobs = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) {
        setState(() {
          _shortlistJobs = jobs;
          _shortlistJobsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _shortlistJobsLoaded = true);
    }
  }

  Future<void> _loadShortlistForJob(int? jobId) async {
    if (jobId == null) {
      setState(() {
        _shortlistJobId = null;
        _shortlistCandidates = [];
      });
      return;
    }
    setState(() {
      _shortlistJobId = jobId;
      _shortlistLoading = true;
    });
    try {
      final list = await _admin.shortlistCandidates(jobId);
      if (mounted) {
        setState(() {
          _shortlistCandidates = List<Map<String, dynamic>>.from(
              list.map((e) => Map<String, dynamic>.from(e as Map)));
          _shortlistLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _shortlistCandidates = [];
          _shortlistLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load shortlist: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> _setShortlistRecommendation(int applicationId, String value) async {
    try {
      await _admin.updateApplicationRecommendation(applicationId, value);
      if (!mounted) return;
      setState(() {
        final idx = _shortlistCandidates.indexWhere(
            (x) => (x['application_id'] ?? x['id']) == applicationId);
        if (idx >= 0) _shortlistCandidates[idx]['recommendation'] = value;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recommendation set to $value', style: GoogleFonts.poppins())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set recommendation: $e', style: GoogleFonts.poppins()), backgroundColor: Colors.redAccent),
        );
      }
    }
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
    return Stack(
      children: [
        Positioned.fill(
          child: DefaultTextStyle(
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
          ),
        ),
        if (_exportStatusMessage != null) _buildExportStatusOverlay(),
      ],
    );
  }

  Widget _buildExportStatusOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: isDark ? _kDarkSurface.withValues(alpha: 0.98) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 16, spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isExporting)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(_kPrimary),
                      ),
                    ),
                  ),
                Text(
                  _exportStatusMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary(context),
                  ),
                ),
              ],
            ),
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
            onPressed: _isExporting ? null : () => _export(),
            icon: _isExporting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(_isExporting ? 'Exporting...' : 'Export', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, constraints) {
          const crossAxisSpacing = 16.0;
          const mainAxisSpacing = 16.0;
          const childAspectRatio = 1.2;
          const childCount = 6;
          const minGridHeight = 400.0;

          final width = constraints.maxWidth.clamp(200.0, double.infinity);
          final cross = width > 900 ? 3 : (width > 600 ? 2 : 1);
          final cellWidth = (width - (cross - 1) * crossAxisSpacing) / cross;
          final cellHeight = (cellWidth / childAspectRatio).clamp(120.0, double.infinity);
          final rowCount = (childCount / cross).ceil();
          final gridHeight = (rowCount * cellHeight + (rowCount - 1) * mainAxisSpacing).clamp(minGridHeight, double.infinity);

          return SizedBox(
            height: gridHeight,
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cross,
              crossAxisSpacing: crossAxisSpacing,
              mainAxisSpacing: mainAxisSpacing,
              childAspectRatio: childAspectRatio,
              children: [
                _buildStylishHiringTrendChart(),
                _buildStylishSourcePerformanceChart(),
                _buildStylishAssessmentPassChart(),
                _buildStylishOffersByCategoryChart(),
                _buildStylishSkillsFrequencyChart(),
                _buildStylishExperienceDistributionChart(),
              ],
            ),
          );
        }),
        const SizedBox(height: 24),
        _buildDetailedReports(),
        const SizedBox(height: 32),
        _buildShortlistAndRecommendationSection(),
      ],
    );
  }

  Widget _buildShortlistAndRecommendationSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return _buildThemedCard(
      Padding(
        padding: const EdgeInsets.all(_kChartCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.people_alt_rounded, color: _kPrimary, size: _kChartIconSize),
                const SizedBox(width: 12),
                Text(
                  'Shortlist & Recommendation',
                  style: GoogleFonts.poppins(fontSize: _kChartTitleSize, fontWeight: FontWeight.bold, color: textColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<int?>(
                    value: _shortlistJobId,
                    decoration: InputDecoration(
                      labelText: 'Job / Requisition',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Select a job')),
                      ..._shortlistJobs.map((j) {
                        final id = j['id'] as int?;
                        final title = (j['title'] ?? j['job_title'] ?? 'Job #$id').toString();
                        return DropdownMenuItem<int?>(value: id, child: Text(title, overflow: TextOverflow.ellipsis));
                      }),
                    ],
                    onChanged: (v) {
                      setState(() => _shortlistJobId = v);
                      _loadShortlistForJob(v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _shortlistJobId == null || _shortlistLoading
                      ? null
                      : () => _loadShortlistForJob(_shortlistJobId),
                  icon: _shortlistLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_shortlistLoading ? 'Loading…' : 'Refresh', style: GoogleFonts.poppins()),
                  style: FilledButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_shortlistCandidates.isEmpty && !_shortlistLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    _shortlistJobId == null
                        ? 'Select a job to view ranked shortlist and set recommendations.'
                        : 'No shortlisted candidates for this job.',
                    style: GoogleFonts.poppins(color: _textSecondary(context), fontSize: 14),
                  ),
                ),
              )
            else if (_shortlistCandidates.isNotEmpty) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all((isDark ? Colors.grey.shade900 : Colors.grey.shade200).withValues(alpha: 0.8)),
                  columns: const [
                    DataColumn(label: Text('Rank')),
                    DataColumn(label: Text('Candidate')),
                    DataColumn(label: Text('CV')),
                    DataColumn(label: Text('Assessment')),
                    DataColumn(label: Text('Overall')),
                    DataColumn(label: Text('Recommendation')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: List.generate(_shortlistCandidates.length, (i) {
                    final c = _shortlistCandidates[i];
                    final appId = c['application_id'] ?? c['id'];
                    final rec = (c['recommendation'] ?? '').toString();
                    final cvScore = c['cv_score'];
                    final assessScore = c['assessment_score'];
                    final overallScore = c['overall_score'];
                    return DataRow(
                      cells: [
                        DataCell(Text('${i + 1}', style: GoogleFonts.poppins(fontSize: 12, color: textColor))),
                        DataCell(Text((c['full_name'] ?? c['name'] ?? '—').toString(), style: GoogleFonts.poppins(fontSize: 12, color: textColor), overflow: TextOverflow.ellipsis)),
                        DataCell(Text(_scoreStr(cvScore), style: GoogleFonts.poppins(fontSize: 12, color: textColor))),
                        DataCell(Text(_scoreStr(assessScore), style: GoogleFonts.poppins(fontSize: 12, color: textColor))),
                        DataCell(Text(_scoreStr(overallScore), style: GoogleFonts.poppins(fontSize: 12, color: textColor))),
                        DataCell(Text(rec.isEmpty ? '—' : rec, style: GoogleFonts.poppins(fontSize: 11, color: textColor), overflow: TextOverflow.ellipsis)),
                        DataCell(
                          appId != null
                              ? PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(Icons.more_vert, size: 20, color: textColor),
                                  onSelected: (value) => _setShortlistRecommendation(appId as int, value),
                                  itemBuilder: (context) => _shortlistRecommendationOptions
                                      .map((opt) => PopupMenuItem(value: opt, child: Text(opt, style: GoogleFonts.poppins(fontSize: 12))))
                                      .toList(),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _shortlistExportingCsv ? null : _exportShortlistCsv,
                    icon: _shortlistExportingCsv
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.table_chart_outlined, size: 20),
                    label: Text(_shortlistExportingCsv ? 'Exporting…' : 'Export shortlist CSV', style: GoogleFonts.poppins()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kPrimary,
                      side: const BorderSide(color: _kPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _shortlistExporting ? null : _exportShortlistPdf,
                    icon: _shortlistExporting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.picture_as_pdf_outlined, size: 20),
                    label: Text(_shortlistExporting ? 'Exporting…' : 'Export shortlist PDF', style: GoogleFonts.poppins()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kPrimary,
                      side: const BorderSide(color: _kPrimary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _scoreStr(dynamic v) {
    if (v == null) return '—';
    if (v is num) return v.toStringAsFixed(0);
    return v.toString();
  }

  static String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  Future<void> _exportShortlistCsv() async {
    if (_shortlistJobId == null || _shortlistCandidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Select a job and load shortlist first.', style: GoogleFonts.poppins())),
      );
      return;
    }
    setState(() => _shortlistExportingCsv = true);
    try {
      const header = 'Rank,Candidate,Email,CV Score,Assessment Score,Overall Score,Status,Recommendation';
      final rows = _shortlistCandidates.asMap().entries.map((e) {
        final i = e.key + 1;
        final c = e.value;
        final cv = c['cv_score'] != null ? (c['cv_score'] is num ? (c['cv_score'] as num).toString() : c['cv_score'].toString()) : '';
        final assess = c['assessment_score'] != null ? (c['assessment_score'] is num ? (c['assessment_score'] as num).toString() : c['assessment_score'].toString()) : '';
        final ov = c['overall_score'] != null ? (c['overall_score'] is num ? (c['overall_score'] as num).toString() : c['overall_score'].toString()) : '';
        return '$i,${_csvEscape((c['full_name'] ?? c['name'] ?? '').toString())},${_csvEscape((c['email'] ?? '').toString())},$cv,$assess,$ov,${_csvEscape((c['status'] ?? '').toString())},${_csvEscape((c['recommendation'] ?? '').toString())}';
      });
      final csv = '$header\n${rows.join('\n')}';
      final filename = 'shortlist_${_shortlistJobId}_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.csv';
      await analytics_export.downloadShortlistCsv(context, csv, filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shortlist CSV download started.', style: GoogleFonts.poppins())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e', style: GoogleFonts.poppins()), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _shortlistExportingCsv = false);
    }
  }

  Future<Uint8List?> _buildShortlistPdfForJob() async {
    if (_shortlistJobId == null || _shortlistCandidates.isEmpty) return null;
    final match = _shortlistJobs.where((j) => j['id'] == _shortlistJobId).toList();
    final jobTitle = match.isEmpty ? 'Job' : (match.first['title'] ?? match.first['job_title'] ?? 'Job').toString();
    Uint8List headerBytes;
    Uint8List footerBytes;
    try {
      headerBytes = (await rootBundle.load('assets/images/logo2.png')).buffer.asUint8List();
      footerBytes = (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load logo images: $e', style: GoogleFonts.poppins())),
        );
      }
      return null;
    }
    final headerImage = pw.MemoryImage(headerBytes);
    final footerImage = pw.MemoryImage(footerBytes);
    pw.ThemeData pdfTheme;
    try {
      final poppinsRegular = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
      final poppinsBold = await rootBundle.load('assets/fonts/Poppins-Bold.ttf');
      pdfTheme = pw.ThemeData.withFont(
        base: pw.Font.ttf(Uint8List.fromList(poppinsRegular.buffer.asUint8List()).buffer.asByteData()),
        bold: pw.Font.ttf(Uint8List.fromList(poppinsBold.buffer.asUint8List()).buffer.asByteData()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load fonts: $e', style: GoogleFonts.poppins())),
        );
      }
      return null;
    }
    final generatedOn = DateFormat('EEEE, d MMMM yyyy · HH:mm').format(DateTime.now());
    final doc = pw.Document(theme: pdfTheme);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Image(headerImage, width: 180, height: 56),
        ),
        footer: (pw.Context context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(footerImage, width: 140, height: 42),
              pw.Text('Page ${context.pageNumber + 1}', style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, text: 'Shortlist & Recommendation', textStyle: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Paragraph(text: 'Report generated for: Hiring Committee · $jobTitle', style: const pw.TextStyle(fontSize: 10)),
            pw.Paragraph(text: 'Generated on: $generatedOn', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              context: context,
              data: [
                ['Rank', 'Candidate', 'Email', 'CV', 'Assessment', 'Overall', 'Status', 'Recommendation'],
                ...List.generate(_shortlistCandidates.length, (i) {
                  final c = _shortlistCandidates[i];
                  final cv = _scoreStr(c['cv_score']);
                  final assess = _scoreStr(c['assessment_score']);
                  final ov = _scoreStr(c['overall_score']);
                  return [
                    '${i + 1}',
                    (c['full_name'] ?? c['name'] ?? '—').toString(),
                    (c['email'] ?? '—').toString(),
                    cv,
                    assess,
                    ov,
                    (c['status'] ?? '—').toString(),
                    (c['recommendation'] ?? '—').toString(),
                  ];
                }),
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),
          ];
        },
      ),
    );
    return doc.save();
  }

  Future<void> _exportShortlistPdf() async {
    if (_shortlistJobId == null || _shortlistCandidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Select a job and load shortlist first.', style: GoogleFonts.poppins())),
      );
      return;
    }
    setState(() => _shortlistExporting = true);
    try {
      final bytes = await _buildShortlistPdfForJob();
      if (bytes == null || !mounted) return;
      final filename = 'shortlist_${_shortlistJobId}_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.pdf';
      analytics_export.downloadShortlistPdf(context, bytes, filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shortlist PDF download started.', style: GoogleFonts.poppins())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e', style: GoogleFonts.poppins()), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _shortlistExporting = false);
    }
  }

  // ---------------- Stylish Charts ----------------

  Widget _buildStylishHiringTrendChart() {
    return _buildThemedCard(Padding(
      padding: const EdgeInsets.all(_kChartCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProChartHeader(
            icon: Icons.show_chart_rounded,
            title: 'Applications / Month',
            badgeLabel: '${_monthlyApps.length} months',
            subtitle: 'Monthly application volume',
          ),
          Expanded(
            child: _buildChartWell(SfCartesianChart(
              margin: EdgeInsets.zero,
              plotAreaBorderWidth: 0,
              primaryXAxis: CategoryAxis(
                majorGridLines: MajorGridLines(
                  width: 0.5,
                  color: _textSecondary(context).withValues(alpha: 0.12),
                  dashArray: const <double>[4, 4],
                ),
                axisLine: const AxisLine(width: 0),
                labelStyle: GoogleFonts.poppins(
                  color: _textSecondary(context),
                  fontSize: _kChartAxisSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              primaryYAxis: NumericAxis(
                majorGridLines: MajorGridLines(
                  width: 0.5,
                  color: _textSecondary(context).withValues(alpha: 0.12),
                  dashArray: const <double>[4, 4],
                ),
                axisLine: const AxisLine(width: 0),
                labelStyle: GoogleFonts.poppins(
                  color: _textSecondary(context),
                  fontSize: _kChartAxisSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              series: <CartesianSeries>[
                SplineSeries<Map<String, dynamic>, String>(
                  dataSource: _monthlyApps,
                  xValueMapper: (d, _) => d['month'] ?? '',
                  yValueMapper: (d, _) => (d['applications'] ?? 0) as num,
                  color: _kPrimary,
                  width: _kChartLineWidth,
                  markerSettings: const MarkerSettings(
                    isVisible: true,
                    color: _kPrimary,
                    borderWidth: 2.5,
                    borderColor: Colors.white,
                    height: 7,
                    width: 7,
                  ),
                  dataLabelSettings: DataLabelSettings(
                    isVisible: true,
                    textStyle: GoogleFonts.poppins(
                      fontSize: _kChartDataLabelSize,
                      color: _textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              ],
            )),
          ),
        ],
      ),
    ));
  }

  Widget _buildStylishSourcePerformanceChart() {
    final data = _appsPerReq.take(8).toList();
    return _buildThemedCard(Padding(
      padding: const EdgeInsets.all(_kChartCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProChartHeader(
            icon: Icons.work_outline_rounded,
            title: 'Top Requisitions',
            badgeLabel: '${data.length} roles',
            subtitle: 'By application count',
          ),
          Expanded(
            child: _buildChartWell(SfCartesianChart(
              margin: EdgeInsets.zero,
              plotAreaBorderWidth: 0,
              primaryXAxis: CategoryAxis(
                labelRotation: -45,
                majorGridLines: MajorGridLines(
                  width: 0.5,
                  color: _textSecondary(context).withValues(alpha: 0.12),
                  dashArray: const <double>[4, 4],
                ),
                axisLine: const AxisLine(width: 0),
                labelStyle: GoogleFonts.poppins(
                  color: _textSecondary(context),
                  fontSize: _kChartAxisSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              primaryYAxis: NumericAxis(
                majorGridLines: MajorGridLines(
                  width: 0.5,
                  color: _textSecondary(context).withValues(alpha: 0.12),
                  dashArray: const <double>[4, 4],
                ),
                axisLine: const AxisLine(width: 0),
                labelStyle: GoogleFonts.poppins(
                  color: _textSecondary(context),
                  fontSize: _kChartAxisSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              series: <CartesianSeries>[
                BarSeries<Map<String, dynamic>, String>(
                  dataSource: data,
                  xValueMapper: (d, _) =>
                      _truncateTitle((d['title'] ?? '').toString()),
                  yValueMapper: (d, _) => (d['applications'] ?? 0) as num,
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(_kChartBarRadius),
                  dataLabelSettings: DataLabelSettings(
                    isVisible: true,
                    textStyle: GoogleFonts.poppins(
                      fontSize: _kChartDataLabelSize,
                      color: _textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              ],
            )),
          ),
        ],
      ),
    ));
  }

  Widget _buildStylishAssessmentPassChart() {
    final data = _assessmentTrend;
    return _buildThemedCard(Padding(
      padding: const EdgeInsets.all(_kChartCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProChartHeader(
            icon: Icons.assignment_turned_in_rounded,
            title: 'Assessment Pass Rate',
            badgeLabel: 'Trend',
            subtitle: 'Over time',
          ),
          Expanded(
            child: _buildChartWell(SfCartesianChart(
              margin: EdgeInsets.zero,
              plotAreaBorderWidth: 0,
              primaryXAxis: CategoryAxis(
                majorGridLines: MajorGridLines(
                  width: 0.5,
                  color: _textSecondary(context).withValues(alpha: 0.12),
                  dashArray: const <double>[4, 4],
                ),
                axisLine: const AxisLine(width: 0),
                labelStyle: GoogleFonts.poppins(
                  color: _textSecondary(context),
                  fontSize: _kChartAxisSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              primaryYAxis: NumericAxis(
                numberFormat: NumberFormat.percentPattern(),
                majorGridLines: MajorGridLines(
                  width: 0.5,
                  color: _textSecondary(context).withValues(alpha: 0.12),
                  dashArray: const <double>[4, 4],
                ),
                axisLine: const AxisLine(width: 0),
                labelStyle: GoogleFonts.poppins(
                  color: _textSecondary(context),
                  fontSize: _kChartAxisSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              series: <CartesianSeries>[
                LineSeries<Map<String, dynamic>, String>(
                  dataSource: data,
                  xValueMapper: (d, _) => d['month'] ?? '',
                  yValueMapper: (d, _) =>
                      ((d['pass_rate_percent'] ?? 0) as num) / 100,
                  color: _kPrimary,
                  width: _kChartLineWidth,
                  markerSettings: const MarkerSettings(
                    isVisible: true,
                    color: _kPrimary,
                    borderWidth: 2.5,
                    borderColor: Colors.white,
                    height: 7,
                    width: 7,
                  ),
                  dataLabelSettings: DataLabelSettings(
                    isVisible: true,
                    labelAlignment: ChartDataLabelAlignment.auto,
                    textStyle: GoogleFonts.poppins(
                      fontSize: _kChartDataLabelSize,
                      color: _textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              ],
            )),
          ),
        ],
      ),
    ));
  }

  static const List<Color> _kChartPalette = [
    Color(0xFFC10D00), // _kPrimary
    Color(0xFFE53935),
    Color(0xFFD32F2F),
    Color(0xFFB71C1C),
    Color(0xFF8B0000),
  ];

  Widget _buildStylishOffersByCategoryChart() {
    final data = _offersByCategory;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strokeColor = isDark ? _kDarkSurface : Colors.white;
    return _buildThemedCard(Padding(
      padding: const EdgeInsets.all(_kChartCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProChartHeader(
            icon: Icons.category_rounded,
            title: 'Offers by Category',
            badgeLabel: '${data.length} categories',
            subtitle: 'Distribution of offers',
          ),
          Expanded(
            child: _buildChartWell(SfCircularChart(
              margin: EdgeInsets.zero,
              series: <CircularSeries>[
                DoughnutSeries<Map<String, dynamic>, String>(
                  dataSource: data,
                  xValueMapper: (d, _) => (d['category'] ?? '') as String,
                  yValueMapper: (d, _) => (d['offers'] ?? 0) as num,
                  pointColorMapper: (d, i) =>
                      _kChartPalette[i % _kChartPalette.length],
                  strokeColor: strokeColor,
                  strokeWidth: 1.5,
                  dataLabelSettings: DataLabelSettings(
                    isVisible: true,
                    textStyle: GoogleFonts.poppins(
                      fontSize: _kChartDataLabelSize,
                      color: _textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  innerRadius: '58%',
                  radius: '100%',
                )
              ],
            )),
          ),
        ],
      ),
    ));
  }

  Widget _buildStylishSkillsFrequencyChart() {
    final items = _skillsFreq.entries
        .map((e) => {'skill': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    final topSkills = items.take(8).toList();

    return _buildThemedCard(Padding(
      padding: const EdgeInsets.all(_kChartCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProChartHeader(
            icon: Icons.code_rounded,
            title: 'Top Skills',
            badgeLabel: '${topSkills.length} skills',
            subtitle: 'Most requested',
          ),
          Expanded(
            child: _buildChartWell(SfCartesianChart(
              margin: EdgeInsets.zero,
              plotAreaBorderWidth: 0,
              primaryXAxis: CategoryAxis(
                labelRotation: -45,
                majorGridLines: MajorGridLines(
                  width: 0.5,
                  color: _textSecondary(context).withValues(alpha: 0.12),
                  dashArray: const <double>[4, 4],
                ),
                axisLine: const AxisLine(width: 0),
                labelStyle: GoogleFonts.poppins(
                  color: _textSecondary(context),
                  fontSize: _kChartAxisSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              primaryYAxis: NumericAxis(
                majorGridLines: MajorGridLines(
                  width: 0.5,
                  color: _textSecondary(context).withValues(alpha: 0.12),
                  dashArray: const <double>[4, 4],
                ),
                axisLine: const AxisLine(width: 0),
                labelStyle: GoogleFonts.poppins(
                  color: _textSecondary(context),
                  fontSize: _kChartAxisSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              series: <CartesianSeries>[
                ColumnSeries<Map<String, dynamic>, String>(
                  dataSource: topSkills,
                  xValueMapper: (d, _) => d['skill'] as String,
                  yValueMapper: (d, _) => (d['count'] ?? 0) as num,
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(_kChartBarRadius),
                  dataLabelSettings: DataLabelSettings(
                    isVisible: true,
                    textStyle: GoogleFonts.poppins(
                      fontSize: _kChartDataLabelSize,
                      color: _textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              ],
            )),
          ),
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
      padding: const EdgeInsets.all(_kChartCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProChartHeader(
            icon: Icons.timeline_rounded,
            title: 'Experience Distribution',
            badgeLabel: '${items.length} ranges',
            subtitle: 'Years of experience',
          ),
          Expanded(
            child: _buildChartWell(SfCartesianChart(
              margin: EdgeInsets.zero,
              plotAreaBorderWidth: 0,
              primaryXAxis: CategoryAxis(
                majorGridLines: MajorGridLines(
                  width: 0.5,
                  color: _textSecondary(context).withValues(alpha: 0.12),
                  dashArray: const <double>[4, 4],
                ),
                axisLine: const AxisLine(width: 0),
                labelStyle: GoogleFonts.poppins(
                  color: _textSecondary(context),
                  fontSize: _kChartAxisSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              primaryYAxis: NumericAxis(
                majorGridLines: MajorGridLines(
                  width: 0.5,
                  color: _textSecondary(context).withValues(alpha: 0.12),
                  dashArray: const <double>[4, 4],
                ),
                axisLine: const AxisLine(width: 0),
                labelStyle: GoogleFonts.poppins(
                  color: _textSecondary(context),
                  fontSize: _kChartAxisSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              series: <CartesianSeries>[
                BarSeries<Map<String, dynamic>, String>(
                  dataSource: items,
                  xValueMapper: (d, _) => '${d['years']} yrs',
                  yValueMapper: (d, _) => (d['count'] ?? 0) as num,
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(_kChartBarRadius),
                  dataLabelSettings: DataLabelSettings(
                    isVisible: true,
                    textStyle: GoogleFonts.poppins(
                      fontSize: _kChartDataLabelSize,
                      color: _textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              ],
            )),
          ),
        ],
      ),
    ));
  }

  String _truncateTitle(String title) {
    if (title.length <= 15) return title;
    return '${title.substring(0, 12)}...';
  }

  Widget _buildDetailedReports() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildReportCard('Hiring Report'),
        const SizedBox(height: 12),
        _buildReportCard('Source Report'),
        const SizedBox(height: 12),
        _buildReportCard('Time to Fill Report'),
      ],
    );
  }

  Widget _buildReportCard(String title) {
    return _buildThemedCard(ListTile(
      title: Text(title, style: GoogleFonts.poppins(color: _textPrimary(context), fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward, color: _kPrimary),
      onTap: () => _viewDetailedReport(title),
    ));
  }

  Future<Uint8List?> _buildPdf({void Function(String)? onProgress}) async {
    if (mounted) onProgress?.call('Loading logos and images...');
    Uint8List headerBytes;
    Uint8List footerBytes;
    try {
      headerBytes = (await rootBundle.load('assets/images/logo2.png')).buffer.asUint8List();
      footerBytes = (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load logo images: $e', style: GoogleFonts.poppins())),
        );
      }
      return null;
    }
    final headerImage = pw.MemoryImage(headerBytes);
    final footerImage = pw.MemoryImage(footerBytes);

    if (mounted) onProgress?.call('Loading fonts...');
    // Load Poppins for PDF theme (use copy of ByteData; Font.ttf consumes the stream)
    pw.ThemeData pdfTheme;
    try {
      final poppinsRegular = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
      final poppinsBold = await rootBundle.load('assets/fonts/Poppins-Bold.ttf');
      pdfTheme = pw.ThemeData.withFont(
        base: pw.Font.ttf(Uint8List.fromList(poppinsRegular.buffer.asUint8List()).buffer.asByteData()),
        bold: pw.Font.ttf(Uint8List.fromList(poppinsBold.buffer.asUint8List()).buffer.asByteData()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load Poppins font: $e', style: GoogleFonts.poppins())),
        );
      }
      return null;
    }

    if (mounted) onProgress?.call('Fetching your profile...');
    String hmName = '—';
    String hmEmail = '—';
    String hmRole = 'Hiring Manager';
    try {
      final userData = await AuthService.getCurrentUser();
      if (userData['unauthorized'] != true && userData['error'] == null) {
        final user = userData['user'] ?? userData;
        final profile = user['profile'] is Map ? user['profile'] as Map<String, dynamic> : null;
        final nameFromProfile = profile?['full_name'] ?? profile?['name'];
        if (nameFromProfile != null && nameFromProfile.toString().trim().isNotEmpty) {
          hmName = nameFromProfile.toString().trim();
        } else if (profile != null) {
          final first = profile['first_name']?.toString() ?? '';
          final last = profile['last_name']?.toString() ?? '';
          final combined = '$first $last'.trim();
          if (combined.isNotEmpty) hmName = combined;
        }
        hmEmail = (user['email'] ?? profile?['email'] ?? hmEmail).toString();
        final roleRaw = (user['role'] ?? hmRole).toString();
        hmRole = roleRaw.replaceFirst('_', ' ').split(' ').map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.length > 1 ? s.substring(1).toLowerCase() : ''}').join(' ');
      }
    } catch (_) {}

    if (mounted) onProgress?.call('Building PDF document...');
    final generatedOn = DateFormat('EEEE, d MMMM yyyy · HH:mm').format(DateTime.now());

    final doc = pw.Document(theme: pdfTheme);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Image(headerImage, width: 180, height: 56),
        ),
        footer: (pw.Context context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(footerImage, width: 140, height: 42),
              pw.Text(
                'Page ${context.pageNumber + 1}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        build: (pw.Context context) {
          final sections = <pw.Widget>[
            pw.Header(level: 0, text: 'Analytics & Insights Report', textStyle: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Paragraph(text: 'Report generated for: $hmName ($hmEmail) · Role: $hmRole', style: const pw.TextStyle(fontSize: 10)),
            pw.Paragraph(text: 'Generated on: $generatedOn', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 12),
          ];
          if (_monthlyApps.isNotEmpty) {
            sections.addAll([
              pw.Header(level: 1, text: 'Monthly Applications', textStyle: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Table.fromTextArray(context: context, data: [
                ['Month', 'Applications'],
                ..._monthlyApps.map((r) => [(r['month'] ?? '').toString(), (r['applications'] ?? 0).toString()]),
              ], headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold), cellStyle: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
            ]);
          }
          if (_offersByCategory.isNotEmpty) {
            sections.addAll([
              pw.Header(level: 1, text: 'Offers by Category', textStyle: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Table.fromTextArray(context: context, data: [
                ['Category', 'Offers'],
                ..._offersByCategory.map((r) => [(r['category'] ?? '').toString(), (r['offers'] ?? 0).toString()]),
              ], headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold), cellStyle: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
            ]);
          }
          if (_appsPerReq.isNotEmpty) {
            sections.addAll([
              pw.Header(level: 1, text: 'Applications per Requisition', textStyle: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Table.fromTextArray(context: context, data: [
                ['Requisition', 'Applications'],
                ..._appsPerReq.map((r) => [(r['title'] ?? '').toString(), (r['applications'] ?? 0).toString()]),
              ], headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold), cellStyle: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
            ]);
          }
          if (_assessmentTrend.isNotEmpty) {
            sections.addAll([
              pw.Header(level: 1, text: 'Assessment Pass Rate Trend', textStyle: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Table.fromTextArray(context: context, data: [
                ['Month', 'Pass Rate %'],
                ..._assessmentTrend.map((r) => [(r['month'] ?? '').toString(), (r['pass_rate_percent'] ?? 0).toString()]),
              ], headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold), cellStyle: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
            ]);
          }
          if (_skillsFreq.isNotEmpty) {
            final sorted = _skillsFreq.entries.toList()..sort((a, b) => (b.value as num).compareTo(a.value as num));
            sections.addAll([
              pw.Header(level: 1, text: 'Skills Frequency', textStyle: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Table.fromTextArray(context: context, data: [
                ['Skill', 'Count'],
                ...sorted.map((e) => [e.key.toString(), e.value.toString()]),
              ], headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold), cellStyle: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
            ]);
          }
          if (_expDist.isNotEmpty) {
            final sorted = _expDist.entries.toList()
              ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
            sections.addAll([
              pw.Header(level: 1, text: 'Experience Distribution', textStyle: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Table.fromTextArray(context: context, data: [
                ['Years', 'Count'],
                ...sorted.map((e) => [e.key.toString(), e.value.toString()]),
              ], headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold), cellStyle: const pw.TextStyle(fontSize: 10)),
            ]);
          }
          if (sections.length <= 5) {
            sections.add(pw.Paragraph(text: 'No analytics data to display. Refresh the page and try again.'));
          }
          sections.add(pw.SizedBox(height: 16));
          sections.add(pw.Paragraph(
            text: 'This report contains analytics only. Export shortlist (PDF or CSV) from the Shortlist & Recommendation section on this page.',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ));
          return sections;
        },
      ),
    );
    return doc.save();
  }

  Future<void> _export() async {
    if (_monthlyApps.isEmpty && _offersByCategory.isEmpty && _skillsFreq.isEmpty &&
        _expDist.isEmpty && _appsPerReq.isEmpty && _assessmentTrend.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No data to export. Refresh analytics first.', style: GoogleFonts.poppins())),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _isExporting = true;
      _exportStatusMessage = 'Loading logos and images...';
    });
    try {
      final bytes = await _buildPdf(
        onProgress: (msg) {
          if (mounted) setState(() => _exportStatusMessage = msg);
        },
      );
      if (bytes == null || !mounted) {
        if (mounted) setState(() { _isExporting = false; _exportStatusMessage = null; });
        return;
      }
      final filename = 'analytics_export_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.pdf';
      analytics_export.downloadAnalyticsPdf(context, bytes, filename);
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _exportStatusMessage = 'Done! You can open the downloaded document.';
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _exportStatusMessage = null);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportStatusMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e', style: GoogleFonts.poppins())),
        );
      }
    } finally {
      if (mounted && _isExporting) setState(() { _isExporting = false; _exportStatusMessage = null; });
    }
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
