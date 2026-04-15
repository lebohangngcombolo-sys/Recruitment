import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../utils/api_endpoints.dart';
import '../../providers/theme_provider.dart';
import 'package:go_router/go_router.dart';

class AssessmentPage extends StatefulWidget {
  final int applicationId;
  final Map<String, dynamic>? draftData; // <-- add this line
  const AssessmentPage(
      {super.key, required this.applicationId, this.draftData});

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  bool _showIntro = true;
  List<dynamic> questions = [];
  String _assessmentTitle = 'Assessment';
  Map<int, String> answers = {}; // index -> selected option
  bool submitting = false;
  int _currentQuestionIndex = 0; // one question per screen, navigate with Prev/Next
  late AnimationController _redirectPulseController;

  // Countdown timer: duration from intro "About X minutes" (questions.length * 1.5).ceil()
  int _countdownRemainingSeconds = 0;
  Timer? _countdownTimer;

  String? token;
  bool _isDarkMode = true;

  // Enrollment-style Theme Colors
  final Color _accentRed = const Color(0xFFC10D00); // Main red
  Color get _primaryBg => Colors.transparent;
  Color get _cardBg => _isDarkMode
      ? Colors.black.withValues(alpha: 0.55)
      : Colors.white.withValues(alpha: 0.95);
  Color get _textPrimary => _isDarkMode ? Colors.white : const Color(0xFF090812);
  Color get _textSecondary => _isDarkMode
      ? Colors.white.withValues(alpha: 0.88)
      : const Color(0xFF3C3B46);
  Color get _boxFillColor => _isDarkMode
      ? const Color(0xFFF2F2F2).withValues(alpha: 0.2)
      : const Color(0xFFF5F5F8);
  Color get _overlayColor => _isDarkMode
      ? Colors.black.withValues(alpha: 0.4)
      : Colors.white.withValues(alpha: 0.72);
  Color get _outlineEnabled =>
      _isDarkMode ? Colors.white54 : const Color(0xFFAAA9B5);
  Color get _outlineDisabled =>
      _isDarkMode ? Colors.white24 : const Color(0xFFD9D9E0);
  Color get _mutedIcon =>
      _isDarkMode ? Colors.white54 : const Color(0xFF7E7D89);
  Color get _pagerIdleBg => _isDarkMode
      ? Colors.white.withValues(alpha: 0.15)
      : const Color(0xFFE7E7EC);
  Color get _cardShadow => _isDarkMode
      ? Colors.black.withValues(alpha: 0.35)
      : Colors.black.withValues(alpha: 0.08);

  @override
  void initState() {
    super.initState();
    _redirectPulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);
    loadTokenAndFetch();

    // Autofill from draft if available (backend may nest as assessment.assessment)
    if (widget.draftData != null) {
      final assessmentData = widget.draftData!['assessment'];
      final answersMap = assessmentData is Map
          ? (assessmentData['assessment'] ?? assessmentData) as Map<String, dynamic>?
          : null;
      if (answersMap != null) {
        for (final e in answersMap.entries) {
          final k = int.tryParse(e.key.toString());
          if (k != null && k >= 0) answers[k] = e.value.toString();
        }
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _redirectPulseController.dispose();
    super.dispose();
  }

  int get _countdownDurationSeconds {
    final minutes = (questions.length * 1.5).ceil();
    return (minutes > 0 ? minutes : 1) * 60;
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownRemainingSeconds = _countdownDurationSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _countdownRemainingSeconds--;
        if (_countdownRemainingSeconds <= 0) {
          _countdownRemainingSeconds = 0;
          t.cancel();
          _countdownTimer = null;
        }
      });
    });
  }

  String _formatCountdown(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')} : ${minutes.toString().padLeft(2, '0')} : ${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> loadTokenAndFetch() async {
    final t = await AuthService.getAccessToken();
    if (!mounted) return;
    setState(() => token = t);
    await fetchAssessment();
  }

  dynamic _safeJsonDecode(String body) {
    try {
      return json.decode(body);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheAssessmentResult(Map<String, dynamic> submissionData) async {
    try {
      const cacheKey = 'candidate_assessment_results_cache';
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      final decoded = raw == null || raw.isEmpty ? [] : json.decode(raw);
      final List<dynamic> items = decoded is List ? List<dynamic>.from(decoded) : [];

      final row = <String, dynamic>{
        'application_id': widget.applicationId,
        'job_title': _assessmentTitle,
        'status': 'assessment_submitted',
        'assessment_score': submissionData['assessment_score'],
        'overall_score': submissionData['overall_score'],
        'score_ready': submissionData['score_ready'] == true,
        'cv_analysis_status': submissionData['cv_analysis_status'],
        'scoring_breakdown': submissionData['score_ready'] == true
            ? (submissionData['scoring_breakdown'] ?? const <String, dynamic>{})
            : const <String, dynamic>{},
        'created_at': DateTime.now().toIso8601String(),
        'assessment_result': <String, dynamic>{
          'percentage_score': submissionData['assessment_score'],
          'recommendation': submissionData['recommendation'],
          'assessed_at': DateTime.now().toIso8601String(),
        },
      };

      final idx = items.indexWhere((e) {
        if (e is! Map) return false;
        final rawId = e['application_id'];
        final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
        return id == widget.applicationId;
      });
      if (idx >= 0) {
        final merged = Map<String, dynamic>.from(items[idx] as Map);
        merged.addAll(row);
        items[idx] = merged;
      } else {
        items.insert(0, row);
      }
      await prefs.setString(cacheKey, json.encode(items));
    } catch (_) {
      // Cache is best-effort only.
    }
  }

  Future<void> fetchAssessment() async {
    if (token == null) return;

    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse(
            "${ApiEndpoints.candidateBase}/applications/${widget.applicationId}/assessment"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
      );

      if (res.statusCode == 200) {
        final data = _safeJsonDecode(res.body);
        if (data is! Map) {
          throw Exception("Invalid assessment response");
        }
        if (!mounted) return;
        setState(() {
          questions = (data['assessment_pack']?['questions'] as List? ?? [])
              .take(11)
              .toList();
          final pack = data['assessment_pack'];
          final packName = pack is Map ? pack['name'] : null;
          _assessmentTitle = (packName ?? data['job_title'] ?? 'Assessment').toString();
        });
      } else {
        throw Exception("Failed to load assessment: ${res.body}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (!mounted) return;
      _redirectPulseController.stop();
      setState(() => loading = false);
    }
  }

  Future<void> submitAssessment() async {
    if (token == null) return;

    setState(() => submitting = true);
    try {
      final payload = {
        "answers": answers.map((key, value) => MapEntry(key.toString(), value)),
      };

      final res = await http.post(
        Uri.parse(
            "${ApiEndpoints.candidateBase}/applications/${widget.applicationId}/assessment"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: json.encode(payload),
      );

      if (res.statusCode == 201) {
        final data = _safeJsonDecode(res.body);
        if (data is! Map) {
          throw Exception("Invalid submission response");
        }
        if (!mounted) return;
        await _cacheAssessmentResult(Map<String, dynamic>.from(data));

        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              title: Center(
                child: Text(
                  'Assessment submitted',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              content: Text(
                'Your assessment has been submitted successfully.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                color: _textPrimary,
                    ),
                  ),
                ),
              ],
            );
          },
        );
        if (!mounted) return;
        _countdownTimer?.cancel();
        // Assessment page is frequently opened via Navigator.push.
        // Returning through Navigator ensures we always leave this page after submit.
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop({
            'application_id': widget.applicationId,
            'status': 'assessment_submitted',
            'job_title': _assessmentTitle,
            ...Map<String, dynamic>.from(data),
          });
          return;
        }
        final safeToken = token ?? '';
        final target = safeToken.isNotEmpty
            ? '/candidate-dashboard?token=${Uri.encodeComponent(safeToken)}'
            : '/candidate-dashboard';
        GoRouter.of(context).go(target);
        return;
      } else {
        throw Exception("Failed to submit: ${res.body}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (!mounted) return;
      setState(() => submitting = false);
    }
  }

  // Save draft progress and redirect to dashboard
  Future<void> saveDraftAndExit() async {
    if (token == null) return;

    try {
      // Wrap assessment answers under 'assessment' key
      final payload = {
        "draft_data": {
          "assessment":
              answers.map((key, value) => MapEntry(key.toString(), value))
        },
        "last_saved_screen": "assessment"
      };

      final res = await http.post(
        Uri.parse(
            "${ApiEndpoints.candidateBase}/applications/${widget.applicationId}/draft"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: json.encode(payload),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Progress saved successfully.")),
        );

        // Use GoRouter to navigate
        await Future.delayed(const Duration(milliseconds: 700));
        if (context.mounted) {
          GoRouter.of(context).go('/candidate-dashboard');
        }
      } else {
        throw Exception("Failed to save draft: ${res.body}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving draft: $e")),
      );
    }
  }

  Widget _buildAssessmentIntro() {
    final estimatedMinutes = (questions.length * 1.5).ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 2),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accentRed.withValues(alpha: 0.2),
                border: Border.all(color: _accentRed, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _accentRed.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(Icons.help_outline, size: 36, color: _accentRed),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Assessment',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'This assessment helps us understand your fit for the role. Take your time and answer honestly.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.4,
              color: _textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _accentRed.withValues(alpha: 0.9), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _accentRed.withValues(alpha: 0.2),
                    blurRadius: 28,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: _cardShadow,
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _accentRed.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.info_outline, color: _accentRed, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'What to expect',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: _accentRed.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _introCardItem(Icons.schedule, 'Duration', 'About $estimatedMinutes minutes'),
                            const SizedBox(height: 10),
                                _introCardItem(Icons.gps_fixed, 'Focus', "Based on the job you're applying for"),
                            const SizedBox(height: 10),
                            _introCardItem(Icons.save_alt, 'Progress', 'Your answers are saved automatically'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _introCardItem(Icons.help_outline, 'Questions', 'Multiple-choice (one best answer)'),
                            const SizedBox(height: 10),
                            _introCardItem(Icons.replay, 'Review', 'You can review answers before submitting'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: () {
                setState(() => _showIntro = false);
                _startCountdown();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentRed,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Start assessment',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _introCardItem(IconData icon, String label, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _accentRed, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackground(BuildContext context, Widget child, String backgroundImage) {
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(backgroundImage),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            color: _overlayColor,
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: child,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    _isDarkMode = themeProvider.isDarkMode;
    final backgroundImage = themeProvider.backgroundImage;

    if (loading) {
      final jobText = _assessmentTitle.trim();
      final redirectMessage = (jobText.isNotEmpty && jobText != 'Assessment')
          ? 'You are now being redirected to your assessment for ${jobText.toLowerCase()}'
          : 'You are now being redirected to your assessment';
      return Scaffold(
        backgroundColor: _isDarkMode ? const Color(0xFF121212) : Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo3.png',
                    height: 64,
                    width: 64,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.work_outline,
                      size: 64,
                      color: _accentRed,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Khonology',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _accentRed,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Preparing your application',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: _isDarkMode ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    redirectMessage,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: _textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  AnimatedBuilder(
                    animation: _redirectPulseController,
                    builder: (context, _) {
                      final t = _redirectPulseController.value;
                      const segmentCount = 8;
                      final filledSegments =
                          (t * segmentCount).floor().clamp(0, segmentCount);
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(segmentCount, (i) {
                          final filled = i < filledSegments;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 28,
                            height: 8,
                            decoration: BoxDecoration(
                              color: filled
                                  ? const Color(0xFF2E7D32)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: _primaryBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: _textPrimary, size: 28),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _textPrimary, size: 26),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          title: null,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Image.asset(
                  'assets/icons/khono.png',
                  height: 32,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
        body: _buildBackground(
          context,
          Column(
            children: [
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: Text(
                    "No assessment available",
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ],
          ),
          backgroundImage,
        ),
      );
    }

    // Preparation / instructions screen before starting the assessment
    if (_showIntro) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: _primaryBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: _textPrimary, size: 28),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _textPrimary, size: 26),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          title: null,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Image.asset(
                  'assets/icons/khono.png',
                  height: 32,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
        body: _buildBackground(context, _buildAssessmentIntro(), backgroundImage),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: _textPrimary, size: 28),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _textPrimary, size: 26),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Image.asset(
                'assets/icons/khono.png',
                height: 32,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
      body: _buildBackground(
        context,
        Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Position: $_assessmentTitle',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  _buildTimerAndProgress(context),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Expanded(child: _buildCurrentQuestionCard()),
                    const SizedBox(height: 16),
                    _buildQuestionFooter(context),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
        backgroundImage,
      ),
    );
  }

  Widget _buildTimerAndProgress(BuildContext context) {
    final current = _currentQuestionIndex + 1;
    final total = questions.length;
    final progress = _countdownDurationSeconds > 0
        ? 1.0 - (_countdownRemainingSeconds / _countdownDurationSeconds)
        : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, color: _textSecondary, size: 20),
            const SizedBox(width: 6),
            Text(
              'Question $current of $total',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: _isDarkMode
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFFE0DFE7),
                color: _accentRed,
                strokeWidth: 4,
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    _formatCountdown(_countdownRemainingSeconds),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentQuestionCard() {
    if (questions.isEmpty || _currentQuestionIndex >= questions.length) {
      return const SizedBox();
    }
    final q = questions[_currentQuestionIndex];
    final String questionText = q['question'] ?? 'Question not available';
    final List options = q['options'] ?? [];

    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accentRed.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: _cardShadow,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Question ${_currentQuestionIndex + 1}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              questionText,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ...List.generate(options.length, (i) {
              final optionLabel = ['A', 'B', 'C', 'D'][i];
              final optionText = i < options.length ? options[i].toString() : '';
              final isSelected = answers[_currentQuestionIndex] == optionLabel;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => setState(() => answers[_currentQuestionIndex] = optionLabel),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _boxFillColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? _accentRed : _accentRed.withValues(alpha: 0.4),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected ? _accentRed : _mutedIcon,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$optionLabel. $optionText',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionFooter(BuildContext context) {
    final total = questions.length;
    final canPrev = _currentQuestionIndex > 0;
    final canNext = _currentQuestionIndex < total - 1;

    final centerGroup = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: canPrev
              ? () => setState(() => _currentQuestionIndex = (_currentQuestionIndex - 1).clamp(0, total - 1))
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: _textPrimary,
            side: BorderSide(color: canPrev ? _outlineEnabled : _outlineDisabled),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text('Prev', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(total, (i) {
              final isCurrent = i == _currentQuestionIndex;
              final hasAnswer = answers.containsKey(i);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Material(
                  color: isCurrent
                      ? _accentRed
                      : (hasAnswer
                          ? _accentRed.withValues(alpha: 0.5)
                          : _pagerIdleBg),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => setState(() => _currentQuestionIndex = i),
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isCurrent ? Colors.white : _textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: canNext
              ? () => setState(() => _currentQuestionIndex = (_currentQuestionIndex + 1).clamp(0, total - 1))
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: _textPrimary,
            side: BorderSide(color: canNext ? _outlineEnabled : _outlineDisabled),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text('Next', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Center(child: centerGroup)),
        ElevatedButton(
          onPressed: submitting ? null : submitAssessment,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentRed,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Submit',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }
}
