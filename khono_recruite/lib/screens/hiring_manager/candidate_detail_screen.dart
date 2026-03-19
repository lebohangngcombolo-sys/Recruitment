// ignore_for_file: unused_local_variable, unused_import
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
  int _selectedTab = 0;

  static const List<String> _recommendationOptions = [
    'Proceed to Final Interview',
    'Hold',
    'Reject',
  ];

  static const List<String> _tabLabels = [
    'Overview',
    'CV & Skills',
    'Assessment',
    'Interviews',
    'Timeline',
  ];

  static const List<IconData> _tabIcons = [
    Icons.person_outline,
    Icons.description_outlined,
    Icons.assignment_turned_in_outlined,
    Icons.event_note_outlined,
    Icons.timeline_outlined,
  ];

  @override
  void initState() {
    super.initState();
    fetchAllData();
  }

  @override
  void dispose() {
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
        "assessment_score":
            assessment['percentage_score'] ?? assessment['score'] ?? 'N/A',
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
          SnackBar(
              content: Text('Failed to set recommendation: $e'),
              backgroundColor: Colors.redAccent),
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
        Uri.parse(
            '${ApiEndpoints.adminBase}/applications/$applicationId/download-cv'),
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
                          style: const TextStyle(
                            color: Colors.black87,
                            fontFamily: 'Poppins',
                          )),
                    )
                  : _buildModernLayout(themeProvider),
        ),
      ),
    );
  }

  Widget _buildModernLayout(ThemeProvider themeProvider) {
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    final bgColor =
        themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white;
    final accentColor =
        themeProvider.isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700;

    return Column(
      children: [
        // Compact Header Card
        _buildHeaderCard(themeProvider),

        // Modern Tab Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: themeProvider.isDarkMode
                  ? Colors.white24
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: List.generate(_tabLabels.length, (index) {
              final isSelected = _selectedTab == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = index),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _tabIcons[index],
                          size: 16,
                          color: isSelected
                              ? accentColor
                              : textColor.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _tabLabels[index],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? accentColor
                                  : textColor.withValues(alpha: 0.7),
                              fontFamily: 'Poppins',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // Tab Content
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildTabContent(themeProvider),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(ThemeProvider themeProvider) {
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    final bgColor =
        themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              themeProvider.isDarkMode ? Colors.white24 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  themeProvider.isDarkMode
                      ? Colors.blue.shade700
                      : Colors.blue.shade500,
                  themeProvider.isDarkMode
                      ? Colors.purple.shade700
                      : Colors.purple.shade500,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _getInitials(candidateData!['full_name']),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidateData!['full_name'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.email_outlined,
                        size: 14, color: textColor.withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Text(
                      candidateData!['email'] ?? '—',
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor.withValues(alpha: 0.7),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.phone_outlined,
                        size: 14, color: textColor.withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Text(
                      candidateData!['phone'] ?? '—',
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor.withValues(alpha: 0.7),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        _getStatusColor(candidateData!['status'], themeProvider)
                            .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (candidateData!['status'] ?? 'Unknown')
                        .toString()
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _getStatusColor(
                          candidateData!['status'], themeProvider),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Actions
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () {},
                color: textColor.withValues(alpha: 0.6),
              ),
              IconButton(
                icon: const Icon(Icons.download_outlined, size: 20),
                onPressed: () => downloadCV(
                  widget.applicationId,
                  context,
                  candidateData!['full_name'] ?? "candidate",
                ),
                color:
                    themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Color _getStatusColor(String? status, ThemeProvider themeProvider) {
    if (status == null)
      return themeProvider.isDarkMode ? Colors.grey : Colors.grey.shade600;
    switch (status.toLowerCase()) {
      case 'hired':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'interview':
        return Colors.blue;
      case 'offer':
        return Colors.orange;
      default:
        return themeProvider.isDarkMode
            ? Colors.grey.shade400
            : Colors.grey.shade700;
    }
  }

  Widget _buildTabContent(ThemeProvider themeProvider) {
    switch (_selectedTab) {
      case 0:
        return _buildOverviewTab(themeProvider);
      case 1:
        return _buildCVSkillsTab(themeProvider);
      case 2:
        return _buildAssessmentTab(themeProvider);
      case 3:
        return _buildInterviewsTab(themeProvider);
      case 4:
        return _buildTimelineTab(themeProvider);
      default:
        return _buildOverviewTab(themeProvider);
    }
  }

  Widget _buildOverviewTab(ThemeProvider themeProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Quick Stats Row
          Row(
            children: [
              _buildStatCard(
                  'CV Score',
                  candidateData!['cv_score']?.toString() ?? '—',
                  Icons.description_outlined,
                  themeProvider),
              const SizedBox(width: 12),
              _buildStatCard(
                  'Assessment',
                  candidateData!['assessment_score']?.toString() ?? '—',
                  Icons.assignment_turned_in_outlined,
                  themeProvider),
              const SizedBox(width: 12),
              _buildStatCard(
                  'Overall',
                  candidateData!['overall_score']?.toString() ?? '—',
                  Icons.trending_up_outlined,
                  themeProvider),
            ],
          ),
          const SizedBox(height: 16),
          // Recommendation Section
          _buildRecommendationCard(themeProvider),
          const SizedBox(height: 16),
          // CV Match & Knockout
          if (candidateData!['cv_parser_result'] != null)
            _buildCVMatchCard(themeProvider),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, ThemeProvider themeProvider) {
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    final bgColor =
        themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: themeProvider.isDarkMode
                ? Colors.white24
                : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: textColor.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
                fontFamily: 'Poppins',
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: textColor.withValues(alpha: 0.6),
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(ThemeProvider themeProvider) {
    final rec = (candidateData!['recommendation'] ?? '').toString();
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    final bgColor =
        themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              themeProvider.isDarkMode ? Colors.white24 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.how_to_vote_outlined,
                  size: 20, color: textColor.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text(
                'Application Recommendation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  fontFamily: 'Poppins',
                ),
              ),
              const Spacer(),
              if (rec.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRecColor(rec, themeProvider)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    rec,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getRecColor(rec, themeProvider),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recommendationOptions.map((opt) {
              final isSelected = rec == opt;
              return ActionChip(
                label: Text(opt,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : textColor,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontFamily: 'Poppins',
                    )),
                backgroundColor: isSelected
                    ? _getRecColor(opt, themeProvider)
                    : (themeProvider.isDarkMode
                        ? Colors.grey.shade800
                        : Colors.grey.shade100),
                side: BorderSide.none,
                onPressed: () => _setRecommendation(opt),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getRecColor(String rec, ThemeProvider themeProvider) {
    final lower = rec.toLowerCase();
    if (lower.contains('proceed') || lower.contains('final'))
      return Colors.green;
    if (lower.contains('hold')) return Colors.orange;
    if (lower.contains('reject')) return Colors.red;
    return themeProvider.isDarkMode
        ? Colors.grey.shade400
        : Colors.grey.shade700;
  }

  Widget _buildCVMatchCard(ThemeProvider themeProvider) {
    final cvResult = candidateData!['cv_parser_result'];
    if (cvResult == null || cvResult is! Map) return const SizedBox.shrink();

    final map = Map<String, dynamic>.from(cvResult);
    final missing = map['missing_skills'] is List
        ? (map['missing_skills'] as List).cast<String>()
        : <String>[];
    final matchScore = map['match_score'];
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    final bgColor =
        themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              themeProvider.isDarkMode ? Colors.white24 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined,
                  size: 20, color: textColor.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text(
                'CV Match Analysis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  fontFamily: 'Poppins',
                ),
              ),
              const Spacer(),
              if (matchScore != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (matchScore >= 70
                            ? Colors.green
                            : matchScore >= 50
                                ? Colors.orange
                                : Colors.red)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$matchScore% Match',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: matchScore >= 70
                          ? Colors.green
                          : matchScore >= 50
                              ? Colors.orange
                              : Colors.red,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
            ],
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Missing Skills (${missing.length})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor.withValues(alpha: 0.7),
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: missing
                  .take(8)
                  .map((skill) => Chip(
                        label: Text(skill,
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'Poppins',
                            )),
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                        side: BorderSide(
                            color: Colors.red.withValues(alpha: 0.3)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCVSkillsTab(ThemeProvider themeProvider) {
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    final bgColor =
        themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Education
          _buildInfoSection(
              'Education',
              Icons.school_outlined,
              candidateData!['education']?.toString() ?? 'Not provided',
              themeProvider),
          const SizedBox(height: 12),
          // Skills
          _buildInfoSection('Skills', Icons.code_outlined,
              _formatList(candidateData!['skills']), themeProvider),
          const SizedBox(height: 12),
          // Work Experience
          _buildInfoSection(
              'Work Experience',
              Icons.work_outline,
              candidateData!['work_experience']?.toString() ?? 'Not provided',
              themeProvider),
          const SizedBox(height: 12),
          // CV Parser Result
          if (candidateData!['cv_parser_result'] != null)
            _buildCVMatchCard(themeProvider),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, IconData icon, String content,
      ThemeProvider themeProvider) {
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    final bgColor =
        themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              themeProvider.isDarkMode ? Colors.white24 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: textColor.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: textColor.withValues(alpha: 0.8),
              height: 1.5,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentTab(ThemeProvider themeProvider) {
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    final bgColor =
        themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white;
    final assessment = candidateData!['assessment'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Assessment Scores
          Row(
            children: [
              _buildStatCard(
                  'Score',
                  candidateData!['assessment_score']?.toString() ?? '—',
                  Icons.assignment_turned_in_outlined,
                  themeProvider),
              const SizedBox(width: 12),
              _buildStatCard(
                  'Recommendation',
                  candidateData!['assessment_recommendation']?.toString() ??
                      '—',
                  Icons.thumbs_up_down_outlined,
                  themeProvider),
            ],
          ),
          const SizedBox(height: 16),
          // Assessment Details
          if (assessment is Map && assessment.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgColor.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: themeProvider.isDarkMode
                      ? Colors.white24
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assessment Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...assessment.entries
                      .map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  e.key.toString(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textColor.withValues(alpha: 0.7),
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                Text(
                                  e.value?.toString() ?? '—',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInterviewsTab(ThemeProvider themeProvider) {
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    final bgColor =
        themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Schedule Interview Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScheduleInterviewPage(
                      candidateId: widget.candidateId,
                    ),
                  ),
                ).then((_) => fetchAllData());
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Schedule New Interview'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Interview List
          if (interviews.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: bgColor.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_note_outlined,
                        size: 48, color: textColor.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'No interviews scheduled',
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.6),
                          fontFamily: 'Poppins'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...interviews.map((i) {
              final scheduled = DateTime.parse(i['scheduled_time']);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: bgColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: themeProvider.isDarkMode
                        ? Colors.white24
                        : Colors.grey.shade200,
                  ),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.event, color: Colors.blue.shade700),
                  ),
                  title: Text(
                    DateFormat.yMd().add_jm().format(scheduled),
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        fontFamily: 'Poppins'),
                  ),
                  subtitle: Text(
                    'Interviewer: ${i['hiring_manager_name'] ?? 'N/A'}',
                    style: TextStyle(
                        color: textColor.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontFamily: 'Poppins'),
                  ),
                  trailing: TextButton.icon(
                    onPressed: () => cancelInterview(i['id'] as int),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimelineTab(ThemeProvider themeProvider) {
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    final bgColor =
        themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (timeline.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: bgColor.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.timeline_outlined,
                        size: 48, color: textColor.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'No timeline events recorded',
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.6),
                          fontFamily: 'Poppins'),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgColor.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: themeProvider.isDarkMode
                      ? Colors.white24
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stage Timeline',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...timeline.take(15).map((e) {
                    final ts = e['timestamp']?.toString();
                    final actor = e['actor_name'] ?? 'System';
                    final oldS = e['old_status'] ?? '';
                    final newS = e['new_status'] ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 4, right: 12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ts != null && ts.length >= 16
                                      ? ts.substring(0, 16).replaceAll('T', ' ')
                                      : ts ?? '—',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textColor.withValues(alpha: 0.5),
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$actor: ${oldS.isNotEmpty ? '$oldS → ' : ''}$newS',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textColor,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  if (timeline.length > 15)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '... and ${timeline.length - 15} more events',
                        style: TextStyle(
                          fontSize: 13,
                          color: textColor.withValues(alpha: 0.7),
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ignore: unused_element
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
                color: themeProvider.isDarkMode
                    ? Colors.white70
                    : Colors.black54)),
      );
    }
    final map = Map<String, dynamic>.from(cvResult);
    final missing = map['missing_skills'] is List
        ? (map['missing_skills'] as List).cast<String>()
        : <String>[];
    final suggestions = map['suggestions'] is List
        ? (map['suggestions'] as List).cast<String>()
        : <String>[];
    final matchScore = map['match_score'];
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    return _buildFlatTile(
      themeProvider: themeProvider,
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("CV match breakdown",
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          if (matchScore != null)
            _dashboardInfo("Match score", matchScore.toString(), themeProvider),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text("Missing skills",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor)),
            ...missing.take(10).map((s) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text("• $s",
                    style: TextStyle(fontSize: 12, color: textColor)))),
            if (missing.length > 10)
              Text("... and ${missing.length - 10} more",
                  style: TextStyle(fontSize: 11, color: textColor)),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text("Suggestions",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor)),
            ...suggestions.take(5).map((s) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text("• $s",
                    style: TextStyle(fontSize: 12, color: textColor)))),
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
          Text("Application recommendation",
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 6),
          if (rec.isNotEmpty) _dashboardInfo("Current", rec, themeProvider),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _recommendationOptions
                .map((opt) => ActionChip(
                      label: Text(opt, style: const TextStyle(fontSize: 11)),
                      onPressed: () => _setRecommendation(opt),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildKnockoutTile(ThemeProvider themeProvider) {
    final violations = candidateData!['knockout_rule_violations'];
    final list =
        violations is List ? List<dynamic>.from(violations) : <dynamic>[];
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    if (list.isEmpty) {
      return _buildFlatTile(
        themeProvider: themeProvider,
        icon: Icons.rule_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Knockout / holds",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
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
          Text("Knockout / holds",
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 6),
          ...list.map((v) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                    "• ${v is Map ? (v['reason'] ?? v['rule'] ?? v.toString()) : v}",
                    style: TextStyle(fontSize: 13, color: textColor)),
              )),
        ],
      ),
    );
  }

  Widget _buildScoringBreakdownTile(ThemeProvider themeProvider) {
    final breakdown = candidateData!['scoring_breakdown'];
    final overall = candidateData!['overall_score'];
    final weightings = job != null && job!['weightings'] is Map
        ? Map<String, dynamic>.from(job!['weightings'] as Map)
        : <String, dynamic>{"cv": 60, "assessment": 40};
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    final cvPct = weightings['cv'] ?? 60;
    final assessPct = weightings['assessment'] ?? 40;
    return _buildFlatTile(
      themeProvider: themeProvider,
      icon: Icons.pie_chart_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Scoring breakdown",
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 6),
          _dashboardInfo(
              "Weights", "CV $cvPct% · Assessment $assessPct%", themeProvider),
          if (breakdown is Map) ...[
            if (breakdown['cv'] != null)
              _dashboardInfo(
                  "CV score", breakdown['cv'].toString(), themeProvider),
            if (breakdown['assessment'] != null)
              _dashboardInfo("Assessment score",
                  breakdown['assessment'].toString(), themeProvider),
          ],
          if (overall != null)
            _dashboardInfo(
                "Overall",
                overall is num
                    ? (overall).toStringAsFixed(1)
                    : overall.toString(),
                themeProvider),
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
          Text("Stage timeline",
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          if (timeline.isEmpty)
            Text("No status changes recorded",
                style: TextStyle(fontSize: 14, color: textColor))
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
          if (timeline.length > 10)
            Text("... and ${timeline.length - 10} more",
                style: TextStyle(fontSize: 11, color: textColor)),
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
