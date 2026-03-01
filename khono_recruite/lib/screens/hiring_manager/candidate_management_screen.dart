import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin_service.dart';
import '../../widgets/custom_button.dart';
import 'candidate_detail_screen.dart';
import '../../providers/theme_provider.dart';

class CandidateManagementScreen extends StatefulWidget {
  final int jobId;

  const CandidateManagementScreen({super.key, required this.jobId});

  @override
  _CandidateManagementScreenState createState() =>
      _CandidateManagementScreenState();
}

class _CandidateManagementScreenState extends State<CandidateManagementScreen> {
  final AdminService admin = AdminService();
  List<Map<String, dynamic>> candidates = [];
  bool loading = true;
  String? statusMessage;

  @override
  void initState() {
    super.initState();
    fetchShortlist();
  }

  Future<void> fetchShortlist() async {
    setState(() {
      loading = true;
      statusMessage = null;
    });

    if (widget.jobId <= 0) {
      final message = "Select a job to view its applicants.";
      if (!mounted) return;
      setState(() {
        candidates = [];
        statusMessage = message;
        loading = false;
      });
      return;
    }

    try {
      final rawApplications = await admin.getJobApplications(
        widget.jobId,
        page: 1,
        perPage: 100,
      );
      final fetched = (rawApplications).map<Map<String, dynamic>>((dynamic app) {
        final map = Map<String, dynamic>.from(app as Map);
        final candidateData = (map['candidate'] is Map)
            ? Map<String, dynamic>.from(map['candidate'] as Map)
            : {};
        return {
          'application_id': map['application_id'] ?? map['id'],
          'candidate_id': candidateData['id'] ?? map['candidate_id'],
          'full_name': candidateData['full_name'] ??
              candidateData['name'] ??
              map['full_name'],
          'email': candidateData['email'],
          'phone': candidateData['phone'],
          'status': map['status'],
          'cv_score': map['cv_score'] ?? map['overall_score'] ?? 0,
          'assessment_score': map['assessment_score'] ?? 0,
          'overall_score': map['overall_score'] ??
              (map['scoring_breakdown']?['overall'] ?? 0),
          'job_title': map['job_title'],
          'cv_parser_result': map['cv_parser_result'] ?? {},
          'candidate': candidateData,
        };
      }).toList();

      fetched.sort((a, b) {
        final aScore = (a['overall_score'] ?? 0).toDouble();
        final bScore = (b['overall_score'] ?? 0).toDouble();
        return bScore.compareTo(aScore);
      });

      if (!mounted) return;
      setState(() {
        candidates = fetched;
        statusMessage =
            fetched.isEmpty ? "No candidates have applied to this job yet." : null;
      });
    } catch (e) {
      debugPrint("Error fetching candidates: $e");
      if (!mounted) return;
      setState(() {
        candidates = [];
        statusMessage = "Failed to load candidates: $e";
      });
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  void openCandidateDetails(Map<String, dynamic> candidate) {
    final candidateId = candidate['candidate_id'] ?? candidate['id'];
    final applicationId = candidate['application_id'];

    if (candidateId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CandidateDetailScreen(
            candidateId: candidateId,
            applicationId: applicationId,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Candidate ID not found"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // Helper method to safely get initials
  String getInitials(String? fullName) {
    if (fullName == null || fullName.isEmpty) return "?";

    // Split by spaces and take first character of each word
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) return "?";

    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    } else {
      // Return first character of first and last name
      return '${parts[0].substring(0, 1)}${parts[parts.length - 1].substring(0, 1)}'
          .toUpperCase();
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
          body: SafeArea(
            child: Column(
              children: [
                // Sticky header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  color: (themeProvider.isDarkMode
                          ? const Color(0xFF14131E)
                          : Colors.white)
                      .withValues(alpha: 0.9),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "All Candidates",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black87),
                      ),
                      CustomButton(
                        text: "Refresh",
                        onPressed: fetchShortlist,
                      ),
                    ],
                  ),
                ),
                Divider(
                    height: 1,
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade800
                        : Colors.grey),

                // Loading / Status / Candidate List
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Colors.redAccent),
                        )
                      : statusMessage != null
                          ? Center(
                              child: Text(
                                statusMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: themeProvider.isDarkMode
                                        ? Colors.grey.shade300
                                        : Colors.black54,
                                    fontSize: 16),
                              ),
                            )
                          : candidates.isEmpty
                              ? Center(
                                  child: Text(
                                    "No candidates found",
                                    style: TextStyle(
                                        color: themeProvider.isDarkMode
                                            ? Colors.grey.shade400
                                            : Colors.black54,
                                        fontSize: 16),
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: fetchShortlist,
                                  color: Colors.redAccent,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: candidates.length,
                                    itemBuilder: (_, index) {
                                      final c = candidates[index];
                                      final overallScore =
                                          (c['overall_score']?.toDouble() ?? 0.0);
                                      final cvScore =
                                          (c['cv_score'] ?? 0).toDouble();
                                      final assessmentScore =
                                          (c['assessment_score'] ?? 0).toDouble();

                                      return GestureDetector(
                                        onTap: () => openCandidateDetails(c),
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: (themeProvider.isDarkMode
                                                    ? const Color(0xFF14131E)
                                                    : Colors.white)
                                                .withValues(alpha: 0.9),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: themeProvider.isDarkMode
                                                    ? Colors.grey.shade800
                                                    : Colors.grey.shade200),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.03),
                                                blurRadius: 6,
                                                offset: const Offset(0, 3),
                                              )
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 26,
                                                backgroundColor:
                                                    Colors.red.shade50,
                                                child: Text(
                                                  getInitials(c['full_name'] ??
                                                      c['name'] ??
                                                      'Unknown'),
                                                  style: const TextStyle(
                                                      color: Colors.redAccent,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      c['full_name'] ??
                                                          'Unnamed Candidate',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 16,
                                                          color: themeProvider
                                                                  .isDarkMode
                                                              ? Colors.white
                                                              : Colors.black87),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      "CV: ${cvScore.toStringAsFixed(0)} | "
                                                      "Assessment: ${assessmentScore.toStringAsFixed(0)} | "
                                                      "Overall: ${overallScore.toStringAsFixed(1)}",
                                                      style: TextStyle(
                                                          fontSize: 14,
                                                          color: themeProvider
                                                                  .isDarkMode
                                                              ? Colors
                                                                  .grey.shade400
                                                              : Colors.black87),
                                                    ),
                                                    if (c['email'] != null)
                                                      Text(
                                                        c['email'],
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: themeProvider
                                                                    .isDarkMode
                                                                ? Colors.grey
                                                                    .shade500
                                                                : Colors.grey
                                                                    .shade600),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 6,
                                                        horizontal: 12),
                                                decoration: BoxDecoration(
                                                  color: c['status'] == "hired"
                                                      ? Colors.green.shade50
                                                      : c['status'] ==
                                                              "rejected"
                                                          ? Colors.red.shade50
                                                          : Colors
                                                              .orange.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  (c['status'] ?? "Pending")
                                                      .toString()
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    color:
                                                        c['status'] == "hired"
                                                            ? Colors.green
                                                            : c['status'] ==
                                                                    "rejected"
                                                                ? Colors.red
                                                                : Colors.orange,
                                                    fontWeight: FontWeight.bold,
                                                  ),
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
        ),
      ),
    );
  }
}
