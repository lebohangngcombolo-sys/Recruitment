import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/application_flow_stepper.dart';

class AssessmentResultsPage extends StatefulWidget {
  final int? applicationId;
  final String token;
  const AssessmentResultsPage(
      {super.key, this.applicationId, required this.token});

  @override
  State<AssessmentResultsPage> createState() => _AssessmentResultsPageState();
}

class _AssessmentResultsPageState extends State<AssessmentResultsPage> {
  bool loading = true;
  List<dynamic> applications = [];
  late String token;

  // Enrollment-style Theme
  final Color _primaryDark = Colors.transparent; // Background
  final Color _cardDark = Colors.black.withOpacity(0.55); // Card background
  final Color _accentRed = const Color(0xFFC10D00); // Main red
  final Color _accentBlue = const Color(0xFFC10D00); // Light red
  final Color _accentGreen = Color(0xFF43A047); // Success
  final Color _textPrimary = Colors.white; // Main text
  final Color _textSecondary = Colors.grey.shade300; // Secondary text
  final Color _surfaceOverlay =
      Colors.white.withOpacity(0.08); // subtle overlay

  @override
  void initState() {
    super.initState();
    token = widget.token;
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse('http://127.0.0.1:5000/api/candidate/applications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      );

      if (res.statusCode == 200) {
        List<dynamic> data = json.decode(res.body);
        if (widget.applicationId != null) {
          data = data
              .where((a) => a['application_id'] == widget.applicationId)
              .toList();
        }
        setState(() => applications = data);
      } else {
        throw Exception('Failed to load results');
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _buildBackground(Widget child) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/dark.png"),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(
          color: Colors.black.withOpacity(0.4),
        ),
        child,
      ],
    );
  }

  Widget _buildStepperHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ApplicationFlowStepper(currentStep: 3),
    );
  }

  Widget scoreDonutChart(double score, Color color, String title) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _surfaceOverlay),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            width: 140,
            child: SfCircularChart(
              annotations: <CircularChartAnnotation>[
                CircularChartAnnotation(
                  widget: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${score.toInt()}%',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      Text(
                        'Score',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              ],
              series: <CircularSeries>[
                DoughnutSeries<_ChartData, String>(
                  dataSource: [
                    _ChartData('Score', score),
                    _ChartData('Remaining', 100 - score)
                  ],
                  xValueMapper: (_ChartData data, _) => data.label,
                  yValueMapper: (_ChartData data, _) => data.value,
                  pointColorMapper: (_ChartData data, _) =>
                      data.label == 'Score'
                          ? color
                          : _textSecondary.withValues(alpha: 0.1),
                  radius: '100%',
                  innerRadius: '75%',
                  dataLabelSettings: const DataLabelSettings(isVisible: false),
                  cornerStyle: CornerStyle.bothCurve,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget chipsList(List<String> items,
      {Color color = Colors.red, String title = "", IconData? icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceOverlay),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items
                .map((item) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.15),
                            color.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 6, color: color),
                          const SizedBox(width: 6),
                          Text(
                            item,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, String passFail) {
    Color statusColor = _accentBlue;
    if (status.toLowerCase() == 'approved') statusColor = _accentGreen;
    if (status.toLowerCase() == 'rejected') statusColor = _accentRed;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                statusColor.withValues(alpha: 0.1),
                statusColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.2)),
          ),
          child: Text(
            status,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: passFail == "Pass"
                  ? [
                      _accentGreen.withValues(alpha: 0.1),
                      _accentGreen.withValues(alpha: 0.05),
                    ]
                  : [
                      _accentRed.withValues(alpha: 0.1),
                      _accentRed.withValues(alpha: 0.05),
                    ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: passFail == "Pass"
                  ? _accentGreen.withValues(alpha: 0.2)
                  : _accentRed.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                passFail == "Pass" ? Icons.check_circle : Icons.cancel,
                size: 14,
                color: passFail == "Pass" ? _accentGreen : _accentRed,
              ),
              const SizedBox(width: 4),
              Text(
                passFail,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: passFail == "Pass" ? _accentGreen : _accentRed,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatViolation(dynamic violation) {
    if (violation is Map) {
      final type = violation['type'] ?? 'rule';
      final field = violation['field'] ?? 'field';
      final operator = violation['operator'] ?? '==';
      final value = violation['value'] ?? '';
      return "$type: $field $operator $value";
    }
    return violation?.toString() ?? '';
  }

  Widget applicationCard(dynamic app) {
    final assessmentScore = (app['assessment_score'] ?? 0).toDouble();
    final status = app['status'] ?? "Applied";
    final passFail = assessmentScore >= 60 ? "Pass" : "Fail";
    final missingSkills =
        List<String>.from(app['cv_parser_result']?['missing_skills'] ?? []);
    final suggestions =
        List<String>.from(app['cv_parser_result']?['suggestions'] ?? []);
    final breakdown = app['scoring_breakdown'] ?? {};
    final violations =
        List<dynamic>.from(app['knockout_rule_violations'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _surfaceOverlay),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app['job_title'] ?? "Unknown Job",
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.business_center,
                              color: _textSecondary, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            app['company'] ?? "Company",
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: _textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(status, passFail),
              ],
            ),
            const SizedBox(height: 28),

            // Assessment Score
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _surfaceOverlay),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.assessment_outlined,
                          color: _accentRed, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Assessment Score",
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: scoreDonutChart(
                        assessmentScore, _accentRed, "Assessment Score"),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: assessmentScore >= 60
                          ? _accentGreen.withValues(alpha: 0.1)
                          : _accentRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: assessmentScore >= 60
                            ? _accentGreen.withValues(alpha: 0.2)
                            : _accentRed.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          assessmentScore >= 60
                              ? Icons.emoji_events
                              : Icons.lightbulb_outline,
                          color:
                              assessmentScore >= 60 ? _accentGreen : _accentRed,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          assessmentScore >= 60
                              ? "Great job! You passed the assessment"
                              : "Keep practicing to improve your score",
                          style: GoogleFonts.inter(
                            color: assessmentScore >= 60
                                ? _accentGreen
                                : _accentRed,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (breakdown.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _surfaceOverlay),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics_outlined,
                            color: _accentRed, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Scoring Breakdown",
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "CV: ${breakdown['cv'] ?? 0} | "
                      "Assessment: ${breakdown['assessment'] ?? 0} | "
                      "Interview: ${breakdown['interview'] ?? 0} | "
                      "References: ${breakdown['references'] ?? 0}",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Total Weighted Score: ${breakdown['overall'] ?? 0}",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _accentRed,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (violations.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _accentRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accentRed.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.block, color: _accentRed, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "Disqualified by Knockout Rules",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _accentRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...violations.map((v) => Text(
                          "- ${_formatViolation(v)}",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: _accentRed,
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Skills & Suggestions
            if (missingSkills.isNotEmpty || suggestions.isNotEmpty) ...[
              if (missingSkills.isNotEmpty) ...[
                chipsList(
                  missingSkills,
                  color: _accentRed,
                  title: "Skills to Improve",
                  icon: Icons.upgrade_outlined,
                ),
                const SizedBox(height: 16),
              ],
              if (suggestions.isNotEmpty) ...[
                chipsList(
                  suggestions,
                  color: _accentRed,
                  title: "Recommendations",
                  icon: Icons.lightbulb_outline,
                ),
                const SizedBox(height: 16),
              ],
            ],

            // Application Date
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accentRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accentRed.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined,
                      color: _accentRed, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Applied on: ${app['applied_on'] ?? 'Unknown date'}",
                      style: GoogleFonts.inter(
                        color: _accentRed,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryDark,
      body: _buildBackground(
        SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: _cardDark,
                  border: Border(
                    bottom: BorderSide(color: _surfaceOverlay, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _surfaceOverlay,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18, color: Colors.white),
                      ),
                      onPressed: () {
                        context.go('/candidate-dashboard');
                      },
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Assessment Results",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _surfaceOverlay,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${applications.length} Results",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildStepperHeader(),
              const SizedBox(height: 12),

              // Content
              Expanded(
                child: loading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(_accentRed),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Loading Assessment Results...",
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Please wait while we fetch your results",
                              style: GoogleFonts.inter(
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : applications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: _cardDark,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _surfaceOverlay),
                                  ),
                                  child: Icon(
                                    Icons.assessment_outlined,
                                    size: 60,
                                    color: _textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  "No Assessment Results",
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Your assessment results will appear here\nonce you complete your assessments",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: _textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _fetchResults,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _accentRed,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    "Refresh",
                                    style: GoogleFonts.inter(
                                      color: _textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              // Welcome Card
                              Container(
                                padding: const EdgeInsets.all(24),
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: _cardDark,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _surfaceOverlay),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _accentRed.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(Icons.insights_rounded,
                                              color: _accentRed, size: 24),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            "Performance Overview",
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: _textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "Track your assessment performance and identify areas for improvement to enhance your skills.",
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: _textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Applications List
                              ...applications
                                  .map((app) => applicationCard(app))
                                  .toList(),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartData {
  final String label;
  final double value;
  _ChartData(this.label, this.value);
}
