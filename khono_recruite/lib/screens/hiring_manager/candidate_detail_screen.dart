// ignore_for_file: unused_import
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../services/admin_service.dart';
import '../../widgets/custom_button.dart';
import 'interview_schedule_page.dart';
import 'package:http/http.dart' as http;
import '../../utils/api_endpoints.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class CandidateDetailScreen extends StatefulWidget {
  final int candidateId;
  final int applicationId;

  const CandidateDetailScreen({
    super.key,
    required this.candidateId,
    required this.applicationId,
  });

  @override
  _CandidateDetailScreenState createState() => _CandidateDetailScreenState();
}

class _CandidateDetailScreenState extends State<CandidateDetailScreen>
    with SingleTickerProviderStateMixin {
  final AdminService admin = AdminService();
  final storage = const FlutterSecureStorage();

  Map<String, dynamic>? candidateData;
  Map<String, dynamic>? application;
  Map<String, dynamic>? job;
  List<Map<String, dynamic>> timeline = [];
  List<Map<String, dynamic>> interviews = [];
  bool loading = true;
  String? errorMessage;
  String currentScreen = "candidates";

  static const List<String> _recommendationOptions = [
    'Proceed to Final Interview',
    'Hold',
    'Reject',
  ];

  late final AnimationController _hoverController;
  late final Animation<double> _hoverAnimation;

  @override
  void initState() {
    super.initState();
    fetchAllData();

    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
    _hoverAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  String _formatList(dynamic v) {
    if (v == null) return '—';
    if (v is List) return v.isEmpty ? '—' : v.join(', ');
    return v.toString();
  }

  Future<void> fetchAllData() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final data = await admin.getApplication(widget.applicationId);
      final app = data['application'] as Map<String, dynamic>? ?? {};
      final cand = data['candidate'] as Map<String, dynamic>? ?? {};
      final assessment = data['assessment'] as Map<String, dynamic>? ?? {};
      final jobPayload = data['job'] as Map<String, dynamic>?;

      application = app;
      job = jobPayload;

      candidateData = {
        "full_name": cand['full_name'] ?? app['full_name'] ?? 'Unnamed',
        "email": cand['email'] ?? '',
        "phone": cand['phone'] ?? '',
        "cv_score": app['cv_score'] ?? 0,
        "cv_file": app['resume_url'] ?? app['cv_url'] ?? '',
        "education": _formatList(cand['education']),
        "skills": _formatList(cand['skills']),
        "work_experience": _formatList(cand['work_experience']),
        "assessment_score": assessment['percentage_score'] ?? assessment['score'] ?? 'N/A',
        "assessment_recommendation": assessment['recommendation'] ?? 'N/A',
        "status": app['status'] ?? 'Pending',
        "candidate_id": app['candidate_id'] ?? widget.candidateId,
        "recommendation": app['recommendation'],
        "cv_parser_result": app['cv_parser_result'],
        "knockout_rule_violations": app['knockout_rule_violations'],
        "scoring_breakdown": app['scoring_breakdown'],
        "overall_score": app['overall_score'],
      };

      final interviewData =
          await admin.getCandidateInterviews(widget.candidateId);
      interviews = List<Map<String, dynamic>>.from(interviewData);

      try {
        final tl = await admin.getApplicationTimeline(widget.applicationId);
        if (mounted) timeline = tl;
      } catch (_) {
        if (mounted) timeline = [];
      }
    } catch (e) {
      print("Error fetching candidate details: $e");
      errorMessage = "Failed to load data: $e";
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _setRecommendation(String value) async {
    try {
      await admin.updateApplicationRecommendation(widget.applicationId, value);
      if (!mounted) return;
      setState(() {
        candidateData = Map<String, dynamic>.from(candidateData!);
        candidateData!['recommendation'] = value;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recommendation set to $value')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set recommendation: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> downloadCV(
      int applicationId, BuildContext context, String candidateName) async {
    try {
      // 🔥 FIX: Always read token inside the function
      final jwtToken = await storage.read(key: "access_token");

      if (jwtToken == null || jwtToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No token found. Please log in again.")),
        );
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiEndpoints.adminBase}/applications/$applicationId/download-cv'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        print("Backend error: ${response.statusCode} ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to get CV URL from backend")),
        );
        return;
      }

      final data = jsonDecode(response.body);
      final cvUrl = data['cv_url'];
      final fullName = data['candidate_name'] ?? candidateName;

      if (cvUrl == null || cvUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("CV URL is invalid")),
        );
        return;
      }

      if (kIsWeb) {
        final uri = Uri.parse(cvUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Download started")),
        );
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final savePath = "${dir.path}/cv_$fullName.pdf";

        await Dio().download(cvUrl, savePath);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("CV downloaded successfully")),
        );

        await OpenFile.open(savePath);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error downloading CV: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      // 🌆 Dynamic background implementation
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(themeProvider.backgroundImage),
            fit: BoxFit.cover,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          drawer: buildSidebar(themeProvider),
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(candidateData?['full_name'] ?? "Candidate Details"),
            backgroundColor: Colors.black87.withValues(alpha: 0.8),
            elevation: 0,
          ),
          body: loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.black87))
              : errorMessage != null
                  ? Center(
                      child: Text(errorMessage!,
                          style: const TextStyle(color: Colors.black87)),
                    )
                  : _buildTilesGrid(themeProvider),
        ),
      ),
    );
  }

  Widget _buildTilesGrid(ThemeProvider themeProvider) {
    final List<Widget> tiles = [
      _buildFlatTile(
        themeProvider: themeProvider,
        icon: Icons.person_outline,
        topRightIcon: Icons.edit_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dashboardText(candidateData!['full_name'], 20, FontWeight.bold,
                themeProvider),
            const SizedBox(height: 6),
            _dashboardInfo("Email", candidateData!['email'], themeProvider),
            _dashboardInfo("Phone", candidateData!['phone'], themeProvider),
            _dashboardInfo("Status", candidateData!['status'], themeProvider,
                bold: true,
                color: candidateData!['status'] == "hired"
                    ? Colors.green
                    : themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87),
          ],
        ),
      ),
      _buildFlatTile(
        themeProvider: themeProvider,
        icon: Icons.insert_drive_file_outlined,
        topRightIcon: Icons.download_outlined,
        onTopRightTap: () {
          downloadCV(
            widget.applicationId,
            context,
            candidateData!['full_name'] ?? "candidate",
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dashboardInfo("CV Score", candidateData!['cv_score'].toString(),
                themeProvider),
            const SizedBox(height: 8),
            Text("Click top-right icon to download CV",
                style: TextStyle(
                    color: themeProvider.isDarkMode
                        ? Colors.white70
                        : Colors.black54,
                    fontSize: 12)),
          ],
        ),
      ),
      _buildFlatTile(
        themeProvider: themeProvider,
        icon: Icons.school_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dashboardInfo(
                "Education", candidateData!['education'], themeProvider),
            _dashboardInfo("Skills", candidateData!['skills'], themeProvider),
            _dashboardInfo("Work Experience", candidateData!['work_experience'],
                themeProvider),
          ],
        ),
      ),
      _buildFlatTile(
        themeProvider: themeProvider,
        icon: Icons.assignment_turned_in_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dashboardInfo("Assessment Score",
                candidateData!['assessment_score'].toString(), themeProvider),
            _dashboardInfo("Assessment Recommendation",
                candidateData!['assessment_recommendation'], themeProvider),
          ],
        ),
      ),
      _buildCvMatchBreakdownTile(themeProvider),
      _buildApplicationRecommendationTile(themeProvider),
      _buildKnockoutTile(themeProvider),
      _buildScoringBreakdownTile(themeProvider),
      _buildTimelineTile(themeProvider),
      _buildFlatTile(
        themeProvider: themeProvider,
        icon: Icons.event_note_outlined,
        topRightIcon: Icons.add,
        onTopRightTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScheduleInterviewPage(
                candidateId: widget.candidateId,
              ),
            ),
          ).then((_) => fetchAllData());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Scheduled Interviews",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87)),
            const SizedBox(height: 8),
            ...interviews.map((i) {
              final scheduled = DateTime.parse(i['scheduled_time']);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _buildHoverWrapper(
                  child: Card(
                    color: themeProvider.isDarkMode
                        ? const Color(0xFF14131E)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                    shadowColor: Colors.black26,
                    child: ListTile(
                      title: Text(
                        DateFormat.yMd().add_jm().format(scheduled),
                        style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black87),
                      ),
                      subtitle: Text(
                          "Interviewer: ${i['hiring_manager_name'] ?? 'N/A'}",
                          style: TextStyle(
                              color: themeProvider.isDarkMode
                                  ? Colors.white70
                                  : Colors.black87)),
                      trailing: CustomButton(
                        text: "Cancel",
                        color: Colors.black87,
                        onPressed: () => cancelInterview(i['id'] as int),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = 1;
          if (constraints.maxWidth > 1200)
            crossAxisCount = 3;
          else if (constraints.maxWidth > 800) crossAxisCount = 2;

          return GridView.count(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            children: tiles,
          );
        },
      ),
    );
  }

  Widget _buildCvMatchBreakdownTile(ThemeProvider themeProvider) {
    final cvResult = candidateData!['cv_parser_result'];
    if (cvResult == null || cvResult is! Map) {
      return _buildFlatTile(
        themeProvider: themeProvider,
        icon: Icons.fact_check_outlined,
        child: Text("CV match breakdown not available",
            style: TextStyle(
                fontSize: 14,
                color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54)),
      );
    }
    final map = Map<String, dynamic>.from(cvResult);
    final missing = map['missing_skills'] is List ? (map['missing_skills'] as List).cast<String>() : <String>[];
    final suggestions = map['suggestions'] is List ? (map['suggestions'] as List).cast<String>() : <String>[];
    final matchScore = map['match_score'];
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    return _buildFlatTile(
      themeProvider: themeProvider,
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("CV match breakdown", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          if (matchScore != null) _dashboardInfo("Match score", matchScore.toString(), themeProvider),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text("Missing skills", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
            ...missing.take(10).map((s) => Padding(padding: const EdgeInsets.only(left: 8), child: Text("• $s", style: TextStyle(fontSize: 12, color: textColor)))),
            if (missing.length > 10) Text("... and ${missing.length - 10} more", style: TextStyle(fontSize: 11, color: textColor)),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text("Suggestions", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
            ...suggestions.take(5).map((s) => Padding(padding: const EdgeInsets.only(left: 8), child: Text("• $s", style: TextStyle(fontSize: 12, color: textColor)))),
          ],
        ],
      ),
    );
  }

  Widget _buildApplicationRecommendationTile(ThemeProvider themeProvider) {
    final rec = (candidateData!['recommendation'] ?? '').toString();
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    return _buildFlatTile(
      themeProvider: themeProvider,
      icon: Icons.how_to_vote_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Application recommendation", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 6),
          if (rec.isNotEmpty) _dashboardInfo("Current", rec, themeProvider),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _recommendationOptions.map((opt) => ActionChip(
              label: Text(opt, style: const TextStyle(fontSize: 11)),
              onPressed: () => _setRecommendation(opt),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildKnockoutTile(ThemeProvider themeProvider) {
    final violations = candidateData!['knockout_rule_violations'];
    final list = violations is List ? List<dynamic>.from(violations) : <dynamic>[];
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    if (list.isEmpty) {
      return _buildFlatTile(
        themeProvider: themeProvider,
        icon: Icons.rule_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Knockout / holds", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 4),
            Text("None", style: TextStyle(fontSize: 14, color: textColor)),
          ],
        ),
      );
    }
    return _buildFlatTile(
      themeProvider: themeProvider,
      icon: Icons.rule_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Knockout / holds", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 6),
          ...list.map((v) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text("• ${v is Map ? (v['reason'] ?? v['rule'] ?? v.toString()) : v}", style: TextStyle(fontSize: 13, color: textColor)),
          )),
        ],
      ),
    );
  }

  Widget _buildScoringBreakdownTile(ThemeProvider themeProvider) {
    final breakdown = candidateData!['scoring_breakdown'];
    final overall = candidateData!['overall_score'];
    final weightings = job != null && job!['weightings'] is Map ? Map<String, dynamic>.from(job!['weightings'] as Map) : <String, dynamic>{"cv": 60, "assessment": 40};
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    final cvPct = weightings['cv'] ?? 60;
    final assessPct = weightings['assessment'] ?? 40;
    return _buildFlatTile(
      themeProvider: themeProvider,
      icon: Icons.pie_chart_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Scoring breakdown", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 6),
          _dashboardInfo("Weights", "CV $cvPct% · Assessment $assessPct%", themeProvider),
          if (breakdown is Map) ...[
            if (breakdown['cv'] != null) _dashboardInfo("CV score", breakdown['cv'].toString(), themeProvider),
            if (breakdown['assessment'] != null) _dashboardInfo("Assessment score", breakdown['assessment'].toString(), themeProvider),
          ],
          if (overall != null) _dashboardInfo("Overall", overall is num ? (overall).toStringAsFixed(1) : overall.toString(), themeProvider),
        ],
      ),
    );
  }

  Widget _buildTimelineTile(ThemeProvider themeProvider) {
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    return _buildFlatTile(
      themeProvider: themeProvider,
      icon: Icons.timeline_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Stage timeline", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          if (timeline.isEmpty)
            Text("No status changes recorded", style: TextStyle(fontSize: 14, color: textColor))
          else
            ...timeline.take(10).map((e) {
              final ts = e['timestamp']?.toString();
              final actor = e['actor_name'] ?? 'Unknown';
              final oldS = e['old_status'] ?? '';
              final newS = e['new_status'] ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "${ts != null && ts.length >= 16 ? ts.substring(0, 16).replaceAll('T', ' ') : ts} · $actor: $oldS → $newS",
                  style: TextStyle(fontSize: 12, color: textColor),
                ),
              );
            }),
          if (timeline.length > 10) Text("... and ${timeline.length - 10} more", style: TextStyle(fontSize: 11, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildFlatTile({
    required ThemeProvider themeProvider,
    required Widget child,
    IconData? icon,
    IconData? topRightIcon,
    VoidCallback? onTopRightTap,
  }) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (themeProvider.isDarkMode
                    ? const Color(0xFF14131E)
                    : Colors.white)
                .withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: themeProvider.isDarkMode ? Colors.white24 : Colors.white,
                width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 4),
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null)
                Row(
                  children: [
                    Icon(icon,
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                        size: 28),
                    const SizedBox(width: 8),
                    Expanded(child: child),
                  ],
                )
              else
                child,
            ],
          ),
        ),
        if (topRightIcon != null)
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: onTopRightTap,
              child: Icon(topRightIcon,
                  color:
                      themeProvider.isDarkMode ? Colors.white : Colors.black87,
                  size: 24),
            ),
          ),
      ],
    );
  }

  Widget _dashboardText(String text, double size, FontWeight weight,
      ThemeProvider themeProvider) {
    return Text(text,
        style: TextStyle(
            fontSize: size,
            fontWeight: weight,
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            shadows: [
              Shadow(
                  color:
                      themeProvider.isDarkMode ? Colors.black : Colors.black26,
                  blurRadius: 4,
                  offset: const Offset(2, 2))
            ]));
  }

  Widget _dashboardInfo(String label, String value, ThemeProvider themeProvider,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text("$label: $value",
          style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ??
                  (themeProvider.isDarkMode ? Colors.white : Colors.black87))),
    );
  }

  Widget _buildHoverWrapper({required Widget child}) {
    return MouseRegion(
      onEnter: (_) => kIsWeb ? _hoverController.forward() : null,
      onExit: (_) => kIsWeb ? _hoverController.reverse() : null,
      child: AnimatedBuilder(
        animation: _hoverAnimation,
        builder: (context, _) {
          final scale = _hoverAnimation.value;
          return Transform.scale(scale: scale, child: child);
        },
      ),
    );
  }

  Widget buildSidebar(ThemeProvider themeProvider) {
    return Drawer(
      backgroundColor:
          (themeProvider.isDarkMode ? const Color(0xFF1F2840) : Colors.white)
              .withValues(alpha: 0.9),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              child: Text(
                "Admin Panel",
                style: TextStyle(
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
            ),
            drawerItem("Dashboard", "dashboard", Icons.dashboard_outlined,
                themeProvider),
            drawerItem("Jobs", "jobs", Icons.work_outline, themeProvider),
            drawerItem("Candidates", "candidates", Icons.people_alt_outlined,
                themeProvider),
            drawerItem(
                "Interviews", "interviews", Icons.event_note, themeProvider),
            drawerItem("CV Reviews", "cv_reviews", Icons.assignment_outlined,
                themeProvider),
            drawerItem("Audits", "audits", Icons.history, themeProvider),
            drawerItem("Role Access", "roles", Icons.security, themeProvider),
            drawerItem("Notifications", "notifications",
                Icons.notifications_active_outlined, themeProvider),
          ],
        ),
      ),
    );
  }

  Widget drawerItem(
      String title, String screen, IconData icon, ThemeProvider themeProvider) {
    final bool selected = currentScreen == screen;
    return ListTile(
      leading: Icon(icon,
          color: themeProvider.isDarkMode ? Colors.white : Colors.black87),
      title: Text(title,
          style: TextStyle(
              color: selected
                  ? (themeProvider.isDarkMode ? Colors.white : Colors.black87)
                  : (themeProvider.isDarkMode
                      ? Colors.white70
                      : Colors.black54),
              fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      onTap: () {
        setState(() => currentScreen = screen);
        Navigator.pop(context);
      },
    );
  }

  Future<void> cancelInterview(int interviewId) async {
    try {
      await admin.cancelInterview(interviewId);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Interview cancelled")));

      final interviewData =
          await admin.getCandidateInterviews(widget.candidateId);
      setState(
          () => interviews = List<Map<String, dynamic>>.from(interviewData));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error cancelling interview: $e")));
    }
  }
}
