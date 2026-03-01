import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import '../../utils/api_endpoints.dart';
import 'cv_upload_page.dart';
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
  late AnimationController _redirectPulseController;
  late Animation<double> _redirectPulseAnimation;

  String? token;

  // Enrollment-style Theme Colors
  final Color _primaryDark = Colors.transparent; // Background
  final Color _cardDark =
      Colors.black.withValues(alpha: 0.55); // Card background
  final Color _accentRed = const Color(0xFFC10D00); // Main red
  final Color _textPrimary = Colors.white; // Main text
  final Color _boxFillColor = const Color(0xFFF2F2F2).withValues(alpha: 0.2);

  @override
  void initState() {
    super.initState();
    _redirectPulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);
    _redirectPulseAnimation = Tween<double>(begin: 0.82, end: 1.08).animate(
      CurvedAnimation(parent: _redirectPulseController, curve: Curves.easeInOut),
    );
    loadTokenAndFetch();

    // Γ£à Autofill from draft if available (backend may nest as assessment.assessment)
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
    _redirectPulseController.dispose();
    super.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "Assessment Submitted! Score: ${data['total_score']}%, Result: ${data['recommendation']}")));

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CVUploadScreen(applicationId: widget.applicationId),
          ),
        );
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

  // Γ£à NEW: Save draft progress and redirect to dashboard
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

        // Γ£à Use GoRouter to navigate
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
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: _cardDark,
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
                    color: Colors.black.withValues(alpha: 0.4),
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
                          color: Colors.white.withValues(alpha: 0.95),
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
              onPressed: () => setState(() => _showIntro = false),
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
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackground(BuildContext context, Widget child) {
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/dark.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
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
    if (loading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: _primaryDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Colors.white, size: 28),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _redirectPulseAnimation,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _accentRed.withValues(alpha: 0.6),
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _accentRed.withValues(alpha: 0.35),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: CircularProgressIndicator(
                                color: _accentRed,
                                strokeWidth: 3,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'Loading your assessment',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Hang tight ΓÇö we're setting everything up.",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: _primaryDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Colors.white, size: 28),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
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
        ),
      );
    }

    // Preparation / instructions screen before starting the assessment
    if (_showIntro) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: _primaryDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(color: Colors.white, size: 28),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
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
        body: _buildBackground(context, _buildAssessmentIntro()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _primaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Colors.white, size: 28),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
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
              SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _assessmentTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView.builder(
                  itemCount: questions.length + 1,
                  itemBuilder: (context, index) {
                    if (index == questions.length) {
                      // Submit button - same size/style as Start assessment
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: ElevatedButton(
                            onPressed: submitting ? null : submitAssessment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentRed,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: submitting
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    "Submit Assessment",
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    }

                    final q = questions[index];
                    final String questionText =
                        q['question'] ?? "Question not available";
                    final List options = q['options'] ?? [];

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _accentRed.withValues(alpha: 0.6),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Question ${index + 1}',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              questionText,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            RadioGroup<String>(
                              groupValue: answers[index],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  answers[index] = value;
                                });
                              },
                              child: Column(
                                children: List.generate(options.length, (i) {
                                  final optionLabel = ["A", "B", "C", "D"][i];
                                  final optionText = options[i];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: _boxFillColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _accentRed.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: RadioListTile<String>(
                                      title: Text(
                                        "$optionLabel. $optionText",
                                        style: TextStyle(
                                          color: _textPrimary,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      value: optionLabel,
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
