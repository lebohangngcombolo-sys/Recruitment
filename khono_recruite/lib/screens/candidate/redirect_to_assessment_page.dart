import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../utils/api_endpoints.dart';
import 'assessment_page.dart';

/// Adzuna-style intermediate screen shown after "Apply now" before opening the assessment.
/// Shows branding, a short message, a segmented progress bar, and a fallback "continue here" link.
/// If [applicationId] is null but [job] is provided, the apply API is called on this page so the previous screen can navigate here immediately.
class RedirectToAssessmentPage extends StatefulWidget {
  final int? applicationId;
  final Map<String, dynamic>? draftData;
  final String? jobTitle;
  /// When set, apply is performed on this page (so the button can navigate here instantly).
  final Map<String, dynamic>? job;
  /// Optional apply payload (full_name, phone, portfolio, cover_letter) when applying from job details.
  final Map<String, dynamic>? applyPayload;

  const RedirectToAssessmentPage({
    super.key,
    this.applicationId,
    this.draftData,
    this.jobTitle,
    this.job,
    this.applyPayload,
  });

  @override
  State<RedirectToAssessmentPage> createState() =>
      _RedirectToAssessmentPageState();
}

class _RedirectToAssessmentPageState extends State<RedirectToAssessmentPage>
    with SingleTickerProviderStateMixin {
  static const int _redirectSeconds = 5;
  static const int _segmentCount = 8;

  Timer? _timer;
  late AnimationController _progressController;

  int? _applicationId;
  bool _applyFailed = false;
  String? _applyError;
  Future<void>? _applyFuture;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _redirectSeconds),
    );

    if (widget.applicationId != null && widget.applicationId! > 0) {
      _applicationId = widget.applicationId;
      _progressController.forward();
      _timer = Timer(const Duration(seconds: _redirectSeconds), _goToAssessment);
    } else if (widget.job != null) {
      // Show redirect UI and progress bar immediately; run apply in background.
      _progressController.forward();
      _timer = Timer(const Duration(seconds: _redirectSeconds), _goToAssessment);
      _applyFuture = _runApplyInBackground();
    }
  }

  Future<void> _runApplyInBackground() async {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty || !mounted) {
      setState(() {
        _applyFailed = true;
        _applyError = 'Session expired. Please sign in again.';
      });
      return;
    }
    final jobId = widget.job!['id'];
    if (jobId == null) {
      setState(() {
        _applyFailed = true;
        _applyError = 'Invalid job.';
      });
      return;
    }
    final payload = widget.applyPayload ?? {};
    try {
      final res = await http.post(
        Uri.parse('${ApiEndpoints.candidateBase}/apply/$jobId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'full_name': payload['full_name'] ?? '',
          'phone': payload['phone'] ?? '',
          'portfolio': payload['portfolio'] ?? '',
          'cover_letter': payload['cover_letter'] ?? '',
        }),
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (res.statusCode == 201 || res.statusCode == 200) {
        final appIdRaw = data['application_id'];
        final appId = appIdRaw is int ? appIdRaw : int.tryParse(appIdRaw?.toString() ?? '');
        if (appId != null && appId > 0) {
          if (mounted) setState(() => _applicationId = appId);
          await AuthService.clearPendingApplyJob();
        } else {
          setState(() {
            _applyFailed = true;
            _applyError = data['message']?.toString() ?? 'Apply failed.';
          });
        }
      } else {
        setState(() {
          _applyFailed = true;
          _applyError = data is Map ? (data['error']?.toString() ?? 'Apply failed') : 'Apply failed';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _applyFailed = true;
        _applyError = 'Error: $e';
      });
    }
  }

  Future<void> _goToAssessment() async {
    _timer?.cancel();
    if (!mounted) return;
    int? appId = _applicationId ?? widget.applicationId;
    if (appId == null || appId <= 0) {
      if (_applyFuture != null) {
        await _applyFuture!.timeout(const Duration(seconds: 5), onTimeout: () {});
        if (!mounted) return;
        appId = _applicationId;
      }
    }
    if (appId == null || appId <= 0) {
      if (_applyFailed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_applyError ?? 'Apply failed')),
        );
      }
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AssessmentPage(
          applicationId: appId!,
          draftData: widget.draftData,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobTitle = widget.jobTitle;
    final message = jobTitle != null && jobTitle.isNotEmpty
        ? 'You are now being redirected to your assessment for $jobTitle'
        : 'You are now being redirected to your assessment';

    if (_applyFailed) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
                const SizedBox(height: 16),
                Text(
                  _applyError ?? 'Something went wrong',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Go back', style: GoogleFonts.poppins(color: const Color(0xFF1976D2))),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              Image.asset(
                'assets/images/logo3.png',
                height: 64,
                width: 64,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.work_outline,
                  size: 64,
                  color: const Color(0xFFC10D00),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Khonology',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFC10D00),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Preparing your application',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 48),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              AnimatedBuilder(
                animation: _progressController,
                builder: (context, _) {
                  final t = _progressController.value;
                  final filledSegments = (t * _segmentCount).floor().clamp(0, _segmentCount);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_segmentCount, (i) {
                      final filled = i < filledSegments;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 28,
                        height: 8,
                        decoration: BoxDecoration(
                          color: filled ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  );
                },
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: GestureDetector(
                  onTap: () => _goToAssessment(),
                  child: Text.rich(
                    TextSpan(
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                      children: [
                        const TextSpan(
                            text: 'If you are not redirected within $_redirectSeconds seconds, '),
                        TextSpan(
                          text: 'continue here',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1976D2),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
