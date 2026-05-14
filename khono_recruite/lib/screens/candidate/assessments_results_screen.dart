import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/api_endpoints.dart';
import '../../services/auth_service.dart';
import '../../services/candidate_service.dart';

class AssessmentResultsPage extends StatefulWidget {
  final int? applicationId;
  final String token;
  const AssessmentResultsPage(
      {super.key, this.applicationId, required this.token});

  @override
  State<AssessmentResultsPage> createState() => _AssessmentResultsPageState();
}

class _AssessmentResultsPageState extends State<AssessmentResultsPage> {
  bool loading = false;
  List<dynamic> applications = [];
  late String token;
  String? _errorMessage;
  String _selectedFilter = 'All';
  int _currentPage = 0;
  static const int _rowsPerPage = 6;
  static const String _resultsCacheKey = 'candidate_assessment_results_cache';

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

  int get _totalPages => _filteredApplications.isEmpty
      ? 1
      : ((_filteredApplications.length + _rowsPerPage - 1) ~/ _rowsPerPage);

  List<dynamic> get _pagedApplications {
    if (_filteredApplications.isEmpty) return const [];
    final page = _currentPage.clamp(0, _totalPages - 1);
    final start = page * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, _filteredApplications.length);
    return _filteredApplications.sublist(start, end);
  }

  double _safeDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _resultStatus(dynamic app) {
    final assessmentScore = _safeDouble(app['assessment_score']);
    final finalScore = _safeDouble(
      app['scoring_breakdown']?['overall'] ?? app['final_score'],
    );
    final effective = finalScore > 0 ? finalScore : assessmentScore;
    return effective >= 60 ? 'Passed' : 'Failed';
  }

  bool _matchesFilter(dynamic app) {
    if (_selectedFilter == 'All') return true;
    return _resultStatus(app) == _selectedFilter;
  }

  DateTime _parseAppDate(dynamic app) {
    final candidates = [
      app['applied_on'],
      app['application_date'],
      app['created_at'],
      app['updated_at'],
      app['date_applied'],
    ];
    for (final raw in candidates) {
      if (raw == null) continue;
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _numericApplicationId(dynamic app) {
    final raw = app['application_id'] ?? app['id'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  List<dynamic> get _filteredApplications {
    final list = applications.where(_matchesFilter).toList();
    list.sort((a, b) {
      final dateCmp = _parseAppDate(b).compareTo(_parseAppDate(a));
      if (dateCmp != 0) return dateCmp;
      return _numericApplicationId(b).compareTo(_numericApplicationId(a));
    });
    return list;
  }

  Widget _filterTab(String label) {
    final selected = _selectedFilter == label;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          _selectedFilter = label;
          _currentPage = 0;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _accentRed.withValues(alpha: 0.18) : _surfaceOverlay,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _accentRed.withValues(alpha: 0.45) : _surfaceOverlay,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color tone;
    IconData icon;
    Color contentColor;
    double fillAlpha;
    switch (status) {
      case 'Passed':
        tone = _accentGreen;
        icon = Icons.check_circle_outline;
        contentColor = Colors.white;
        fillAlpha = 0.88;
        break;
      case 'Failed':
        tone = _accentRed;
        icon = Icons.cancel_outlined;
        contentColor = Colors.white;
        fillAlpha = 0.88;
        break;
      default:
        tone = _accentRed;
        icon = Icons.cancel_outlined;
        contentColor = Colors.white;
        fillAlpha = 0.88;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: fillAlpha),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.withValues(alpha: 0.95)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: contentColor),
          const SizedBox(width: 6),
          Text(
            status,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: contentColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showResultDetails(dynamic app) {
    final appId = _numericApplicationId(app);
    if (appId <= 0) return;

    String normalizeLetter(dynamic raw) {
      if (raw == null) return '';
      final s = raw.toString().trim().toUpperCase();
      if (RegExp(r'^[ABCD]$').hasMatch(s)) return s;
      final idx = int.tryParse(s);
      if (idx != null && idx >= 0 && idx <= 3) {
        return ['A', 'B', 'C', 'D'][idx];
      }
      return '';
    }

    List<String> extractOptions(dynamic q) {
      final options = q['options'];
      if (options is List) {
        return options.map((e) => e?.toString() ?? '').toList();
      }
      return [
        q['option_a']?.toString() ?? '',
        q['option_b']?.toString() ?? '',
        q['option_c']?.toString() ?? '',
        q['option_d']?.toString() ?? '',
      ].where((e) => e.trim().isNotEmpty).toList();
    }

    String questionText(dynamic q) =>
        q['question']?.toString() ??
        q['text']?.toString() ??
        q['prompt']?.toString() ??
        'Question';

    String correctLetter(dynamic q) {
      final direct = normalizeLetter(q['correct_answer']);
      if (direct.isNotEmpty) return direct;
      final optionIdx = q['correct_option'];
      final idx = optionIdx is num
          ? optionIdx.toInt()
          : int.tryParse(optionIdx?.toString() ?? '');
      if (idx != null && idx >= 0 && idx <= 3) {
        return ['A', 'B', 'C', 'D'][idx];
      }
      return '';
    }

    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1B1B22),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980, maxHeight: 700),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<Map<String, dynamic>>(
              future: CandidateService.getAssessment(appId, token),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError ||
                    !snap.hasData ||
                    (snap.data?['error'] != null)) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app['job_title']?.toString() ?? 'Assessment Review',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Could not load question-level review for this assessment.',
                        style: GoogleFonts.inter(color: Colors.white70),
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  );
                }

                final data = snap.data!;
                final submitted = (data['submitted_result'] as Map?) ?? {};
                final answers = (submitted['answers'] as Map?) ?? {};
                final pack = (data['assessment_pack'] as Map?) ?? {};
                final questions = (pack['questions'] as List?) ?? const [];
                final hasAnyAnswers = answers.isNotEmpty;
                final hasQuestions = questions.isNotEmpty;

                int totalReviewed = 0;
                int correctCount = 0;
                for (var i = 0; i < questions.length; i++) {
                  final q = questions[i];
                  final selected = normalizeLetter(answers[i.toString()]);
                  final correct = correctLetter(q);
                  if (selected.isEmpty || correct.isEmpty) continue;
                  totalReviewed++;
                  if (selected == correct) correctCount++;
                }
                final accuracy = totalReviewed == 0
                    ? 0
                    : ((correctCount / totalReviewed) * 100).round();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app['job_title']?.toString() ?? 'Assessment Review',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Selected answer vs correct answer',
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                    ),
                    if (hasQuestions && hasAnyAnswers)
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            'Correct: $correctCount/$totalReviewed   Accuracy: $accuracy%',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: !hasQuestions
                          ? Center(
                              child: Text(
                                'No questions found for this assessment yet.',
                                style: GoogleFonts.inter(color: Colors.white70),
                              ),
                            )
                          : !hasAnyAnswers
                              ? Center(
                                  child: Text(
                                    'No submitted answers available for review.',
                                    style: GoogleFonts.inter(color: Colors.white70),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: questions.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (_, i) {
                                    final q = questions[i];
                                    final qId = i.toString();
                                    final selected = normalizeLetter(answers[qId]);
                                    final correct = correctLetter(q);
                                    final opts = extractOptions(q);
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.12),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Q${i + 1}. ${questionText(q)}',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          if (opts.isEmpty)
                                            Text(
                                              'No options available for this question.',
                                              style: GoogleFonts.inter(color: Colors.white70),
                                            ),
                                          ...List.generate(opts.length, (idx) {
                                            final letter = idx < 26
                                                ? String.fromCharCode(
                                                    'A'.codeUnitAt(0) + idx,
                                                  )
                                                : '#';
                                            final isSelected = selected == letter;
                                            final isCorrect = correct == letter;
                                            Color bg = Colors.white.withValues(alpha: 0.02);
                                            Color border =
                                                Colors.white.withValues(alpha: 0.15);
                                            if (isCorrect) {
                                              bg = Colors.green.withValues(alpha: 0.20);
                                              border = Colors.green.withValues(alpha: 0.65);
                                            } else if (isSelected && !isCorrect) {
                                              bg = Colors.red.withValues(alpha: 0.20);
                                              border = Colors.red.withValues(alpha: 0.65);
                                            }
                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 9,
                                              ),
                                              decoration: BoxDecoration(
                                                color: bg,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: border),
                                              ),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    width: 22,
                                                    child: Text(
                                                      '$letter.',
                                                      style: GoogleFonts.inter(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      opts[idx],
                                                      style:
                                                          GoogleFonts.inter(color: Colors.white),
                                                    ),
                                                  ),
                                                  if (isCorrect)
                                                    const Icon(
                                                      Icons.check_circle,
                                                      color: Colors.greenAccent,
                                                      size: 18,
                                                    )
                                                  else if (isSelected)
                                                    const Icon(
                                                      Icons.cancel,
                                                      color: Colors.redAccent,
                                                      size: 18,
                                                    ),
                                                ],
                                              ),
                                            );
                                          }),
                                          if (correct.isEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                'Correct answer metadata is missing for this question.',
                                                style:
                                                    GoogleFonts.inter(color: Colors.orangeAccent),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color tone,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _surfaceOverlay),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: tone),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    token = widget.token;
    _loadCachedResults();
    _fetchResults();
  }

  Future<void> _loadCachedResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_resultsCacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = json.decode(raw);
      if (decoded is! List) return;
      var data = List<dynamic>.from(decoded);
      if (widget.applicationId != null) {
        final filtered = data.where((a) {
          final rawId = a['application_id'];
          final id =
              rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
          return id == widget.applicationId;
        }).toList();
        if (filtered.isNotEmpty) {
          data = filtered;
        } else {
          // Fallback to non-empty results list instead of hard empty UI.
          data = data
              .where((a) => (a['assessment_score'] ?? 0).toDouble() > 0)
              .toList();
        }
      }
      if (!mounted) return;
      setState(() {
        applications = data;
      });
    } catch (_) {
      // Cache is optional; ignore parse/read errors.
    }
  }

  Future<void> _fetchResults() async {
    if (!mounted) return;
    setState(() {
      // Do not block first paint with a full-screen loader.
      // Show loader only when refreshing existing visible data.
      loading = applications.isNotEmpty;
      _errorMessage = null;
    });
    try {
      // Prefer a fresh persisted token if available.
      final latestToken = await AuthService.getAccessToken();
      if (latestToken != null && latestToken.isNotEmpty) {
        token = latestToken;
      }
      final res = await http.get(
        Uri.parse(ApiEndpoints.getApplications),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      );

      if (res.statusCode == 200) {
        final allData = List<dynamic>.from(json.decode(res.body));
        List<dynamic> data = allData;
        if (widget.applicationId != null) {
          final filtered = allData.where((a) {
            final raw = a['application_id'];
            final id = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
            return id == widget.applicationId;
          }).toList();
          // If that specific record is unavailable/stale, show available results.
          data = filtered.isNotEmpty
              ? filtered
              : allData
                  .where((a) => (a['assessment_score'] ?? 0).toDouble() > 0)
                  .toList();
        }
        if (!mounted) return;
        setState(() {
          applications = data;
          _currentPage = 0;
        });
        final prefs = await SharedPreferences.getInstance();
        // Cache the full payload, not filtered subset.
        await prefs.setString(_resultsCacheKey, json.encode(allData));
      } else {
        throw Exception('Failed to load results (${res.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = applications.isEmpty ? e.toString() : null;
      });
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
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
                      _accentGreen.withValues(alpha: 0.05)
                    ]
                  : [
                      _accentRed.withValues(alpha: 0.1),
                      _accentRed.withValues(alpha: 0.05)
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

  Widget applicationCard(BuildContext context, dynamic app) {
    final assessmentScore = (app['assessment_score'] ?? 0).toDouble();
    final status = app['status'] ?? "Applied";
    final scoreReady = app['score_ready'] == true;
    final cvAnalysisStatus = (app['cv_analysis_status'] ?? '').toString();
    final passFail = assessmentScore >= 60 ? "Pass" : "Fail";
    final missingSkills =
        List<String>.from(app['cv_parser_result']?['missing_skills'] ?? []);
    final suggestions =
        List<String>.from(app['cv_parser_result']?['suggestions'] ?? []);
    final breakdown = app['scoring_breakdown'] ?? {};
    final cvFromApp = (app['cv_score'] ?? 0).toDouble();
    final cvFromBreakdown = (breakdown['cv'] ?? cvFromApp).toDouble();
    final cvDisplay =
        cvFromBreakdown == 0 && cvFromApp > 0 ? cvFromApp : cvFromBreakdown;
    final cvDisplayText =
        cvDisplay % 1 == 0 ? cvDisplay.toInt().toString() : cvDisplay.toString();
    final violations =
        List<dynamic>.from(app['knockout_rule_violations'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceOverlay),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                          fontSize: 20,
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _kpiCard(
                    label: 'Assessment Score',
                    value: '${assessmentScore.toStringAsFixed(0)}%',
                    icon: Icons.assessment_outlined,
                    tone: _accentRed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _kpiCard(
                    label: 'CV Score',
                    value: scoreReady ? cvDisplayText : 'Pending',
                    icon: Icons.description_outlined,
                    tone: scoreReady ? _accentGreen : Colors.orange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _kpiCard(
                    label: 'Final Weighted',
                    value: scoreReady
                        ? '${(breakdown['overall'] ?? 0)}'
                        : 'Pending',
                    icon: Icons.pie_chart_outline,
                    tone: _accentBlue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (!scoreReady) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _accentRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accentRed.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top, color: _accentRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cvAnalysisStatus == 'not_started'
                            ? "Final score will appear after you upload your CV and analysis completes."
                            : "Final weighted score will appear once CV analysis completes.",
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (scoreReady) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accentGreen.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: _accentGreen, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "CV scoring is complete—visit your CV results page to review the analysis.",
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final safeToken = Uri.encodeComponent(token);
                        context.go('/jobs-applied?token=$safeToken');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: _accentGreen,
                      ),
                      child: const Text("View CV Results"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

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
                      "CV: $cvDisplayText | "
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

  Widget _buildBackground(Widget child) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/dark.png"),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        color: Colors.black.withValues(alpha: 0.35),
        child: child,
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
                        child: const Icon(Icons.arrow_back,
                            size: 24, color: Colors.white),
                      ),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          context.go('/candidate-dashboard');
                        }
                      },
                      tooltip: 'Back',
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
                  ],
                ),
              ),
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
                    : _errorMessage != null
                        ? Center(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                              decoration: BoxDecoration(
                                color: _cardDark,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _surfaceOverlay),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.wifi_off_rounded,
                                      color: _accentRed, size: 42),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Could not load assessment results',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _errorMessage ?? '',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: _textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchResults,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _accentRed,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text("Try again"),
                                  ),
                                ],
                              ),
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
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            children: [
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _filterTab('All'),
                                  _filterTab('Passed'),
                                  _filterTab('Failed'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LayoutBuilder(
                                builder: (context, constraints) => Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: _cardDark,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _surfaceOverlay),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minWidth: constraints.maxWidth,
                                        ),
                                        child: DataTable(
                                        headingRowHeight: 44,
                                        dataRowMinHeight: 52,
                                        dataRowMaxHeight: 58,
                                        horizontalMargin: 12,
                                        columnSpacing: 16,
                                        headingTextStyle: GoogleFonts.inter(
                                          color: _textSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        columns: const [
                                          DataColumn(label: Text('Job Role')),
                                          DataColumn(label: Text('Assessment')),
                                          DataColumn(label: Text('CV')),
                                          DataColumn(label: Text('Final')),
                                          DataColumn(label: Text('Status')),
                                          DataColumn(label: Text('Action')),
                                        ],
                                        rows: _pagedApplications.map((app) {
                                          final assessment = _safeDouble(app['assessment_score']);
                                          final cv = _safeDouble(app['cv_score']);
                                          final finalWeighted = _safeDouble(
                                            app['scoring_breakdown']?['overall'] ??
                                                app['final_score'],
                                          );
                                          final status = _resultStatus(app);
                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Text(
                                                  app['job_title']?.toString() ?? 'Unknown Job',
                                                  style: GoogleFonts.inter(
                                                    color: _textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  assessment > 0
                                                      ? '${assessment.toStringAsFixed(0)}%'
                                                      : 'Pending',
                                                  style: GoogleFonts.inter(color: _textPrimary),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  cv > 0 ? '${cv.toStringAsFixed(0)}%' : 'Pending',
                                                  style: GoogleFonts.inter(color: _textPrimary),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  finalWeighted > 0
                                                      ? '${finalWeighted.toStringAsFixed(0)}%'
                                                      : 'Pending',
                                                  style: GoogleFonts.inter(color: _textPrimary),
                                                ),
                                              ),
                                              DataCell(_statusChip(status)),
                                              DataCell(
                                                TextButton.icon(
                                                  onPressed: () => _showResultDetails(app),
                                                  icon: const Icon(Icons.visibility_outlined, size: 16),
                                                  label: const Text('View Results'),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Colors.white,
                                                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_filteredApplications.isEmpty) ...[
                                const SizedBox(height: 14),
                                Center(
                                  child: Text(
                                    'No results in this filter.',
                                    style: GoogleFonts.inter(color: _textSecondary),
                                  ),
                                ),
                              ],
                              if (_filteredApplications.length > _rowsPerPage) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _cardDark,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _surfaceOverlay),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Page ${_currentPage + 1} of $_totalPages',
                                        style: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
                                      ),
                                      const Spacer(),
                                      OutlinedButton(
                                        onPressed: _currentPage > 0
                                            ? () => setState(() => _currentPage--)
                                            : null,
                                        child: const Text('Previous'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: _currentPage < _totalPages - 1
                                            ? () => setState(() => _currentPage++)
                                            : null,
                                        child: const Text('Next'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
