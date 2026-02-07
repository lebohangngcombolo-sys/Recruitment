import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import 'cv_upload_page.dart';
import '../../widgets/application_flow_stepper.dart';
import 'package:go_router/go_router.dart';

class AssessmentPage extends StatefulWidget {
  final int applicationId;
  final Map<String, dynamic>? draftData; // <-- add this line
  const AssessmentPage(
      {super.key, required this.applicationId, this.draftData});

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  bool loading = true;
  List<dynamic> questions = [];
  Map<int, String> answers = {}; // index -> selected option
  bool submitting = false;

  String? token;

  // Enrollment-style Theme Colors
  final Color _primaryDark = Colors.transparent; // Background
  final Color _cardDark = Colors.black.withOpacity(0.55); // Card background
  final Color _accentRed = const Color(0xFFC10D00); // Main red
  final Color _textPrimary = Colors.white; // Main text
  final Color _boxFillColor = const Color(0xFFF2F2F2).withOpacity(0.2);

  @override
  void initState() {
    super.initState();
    loadTokenAndFetch();

    // ✅ Autofill from draft if available
    if (widget.draftData != null && widget.draftData!['assessment'] != null) {
      final savedAnswers =
          Map<String, dynamic>.from(widget.draftData!['assessment']);
      answers = savedAnswers
          .map((key, value) => MapEntry(int.parse(key), value.toString()));
    }
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
            "http://127.0.0.1:5000/api/candidate/applications/${widget.applicationId}/assessment"),
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
            "http://127.0.0.1:5000/api/candidate/applications/${widget.applicationId}/assessment"),
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

  // ✅ NEW: Save draft progress and redirect to dashboard
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
            "http://127.0.0.1:5000/api/candidate/apply/save_draft/${widget.applicationId}"),
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

        // ✅ Use GoRouter to navigate
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ApplicationFlowStepper(currentStep: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: _primaryDark,
        body: _buildBackground(
          Column(
            children: [
              const SizedBox(height: 16),
              _buildStepperHeader(),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: _accentRed),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: _primaryDark,
        body: _buildBackground(
          Column(
            children: [
              const SizedBox(height: 16),
              _buildStepperHeader(),
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

    return Scaffold(
      backgroundColor: _primaryDark,
      body: _buildBackground(
        Column(
          children: [
            const SizedBox(height: 16),
            _buildStepperHeader(),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView.builder(
                  itemCount:
                      questions.length + 2, // ✅ Added 1 more for Save & Exit
                  itemBuilder: (context, index) {
              if (index == questions.length) {
                // Submit button
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: submitting ? null : submitAssessment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentRed,
                        foregroundColor: _textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: submitting
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: _textPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              "Submit Assessment",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                                fontFamily: 'Poppins',
                              ),
                            ),
                    ),
                  ),
                );
              } else if (index == questions.length + 1) {
                // ✅ New Save & Exit button
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: saveDraftAndExit,
                      icon: Icon(Icons.save, color: _accentRed),
                      label: Text(
                        "Save & Exit",
                        style: TextStyle(
                          color: _accentRed,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _accentRed, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                  border: Border.all(color: _accentRed.withOpacity(0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
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
                        "Q${index + 1}: $questionText",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: List.generate(options.length, (i) {
                          final optionLabel = ["A", "B", "C", "D"][i];
                          final optionText = options[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: _boxFillColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _accentRed.withOpacity(0.4),
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
                              groupValue: answers[
                                  index], // already prefilled from draft
                              onChanged: (val) {
                                setState(() {
                                  answers[index] = val!;
                                });
                              },
                              activeColor: _accentRed,
                              tileColor: Colors.transparent,
                              selectedTileColor: _accentRed.withOpacity(0.1),
                            ),
                          );
                        }),
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
