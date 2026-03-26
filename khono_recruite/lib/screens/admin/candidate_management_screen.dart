import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../services/admin_service.dart';
import 'candidate_detail_screen.dart';
import '../../providers/theme_provider.dart';
import '../../constants/app_colors.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/themed_surface_card.dart';

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
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchShortlist();
  }

  Future<void> fetchShortlist() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final data = await admin.shortlistCandidates(widget.jobId);
      final List<Map<String, dynamic>> fetched =
          List<Map<String, dynamic>>.from(data);

      fetched.sort((a, b) {
        final aScore = a['overall_score'] ?? 0;
        final bScore = b['overall_score'] ?? 0;
        return bScore.compareTo(aScore);
      });

      setState(() => candidates = fetched);
    } catch (e) {
      debugPrint("Error fetching shortlist: $e");
      setState(() => errorMessage = "Failed to load candidates: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => loading = false);
    }
  }

  void openCandidateDetails(Map<String, dynamic> candidate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CandidateDetailScreen(
          candidateId: candidate['candidate_id'],
          applicationId: candidate['application_id'],
        ),
      ),
    );
  }

  // Helper method to safely get initials
  String getInitials(String? fullName) {
    if (fullName == null || fullName.isEmpty) return "?";

    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) return "?";

    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    } else {
      return '${parts[0].substring(0, 1)}${parts[parts.length - 1].substring(0, 1)}'
          .toUpperCase();
    }
  }

  // Helper to get status icon and color
  (IconData, Color) _getStatusData(String? status) {
    switch (status) {
      case "hired":
        return (Icons.work_outline, Colors.green);
      case "rejected":
        return (Icons.cancel_outlined, Colors.red);
      case "interview":
        return (Icons.calendar_today_outlined, Colors.blue);
      default:
        return (Icons.pending_actions_outlined, Colors.orange);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryRed = const Color.fromRGBO(151, 18, 8, 1);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          "Shortlisted Candidates",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: (isDark ? const Color(0xFF14131E) : Colors.white)
            .withValues(alpha: 0.95),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
        actions: [
          IconButton(
            onPressed: fetchShortlist,
            icon: Icon(Icons.refresh_rounded, size: 24),
            tooltip: "Refresh",
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(themeProvider.backgroundImage),
            fit: BoxFit.cover,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modern Header Card

            // Stats Overview
            if (!loading && candidates.isNotEmpty)
              ThemedSurfaceCard(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      Icons.people_outline_rounded,
                      candidates.length.toString(),
                      "Total Candidates",
                      isDark,
                    ),
                    _buildStatItem(
                      Icons.emoji_events_outlined,
                      candidates.isNotEmpty
                          ? candidates[0]['overall_score']
                                  ?.toStringAsFixed(1) ??
                              "0.0"
                          : "0.0",
                      "Top Score",
                      isDark,
                    ),
                    _buildStatItem(
                      Icons.analytics_outlined,
                      candidates.length > 1
                          ? candidates[1]['overall_score']
                                  ?.toStringAsFixed(1) ??
                              "0.0"
                          : "0.0",
                      "Runner-up",
                      isDark,
                    ),
                  ],
                ),
              ),

            // Main Content Section
            Expanded(
              child: ThemedSurfaceCard(
                padding: const EdgeInsets.all(20),
                child: loading
                    ? const ThemedLoadingState(
                        message: 'Loading Candidates...',
                      )
                    : errorMessage != null
                        ? ThemedErrorState(
                            title: 'Unable to load candidates',
                            subtitle: errorMessage,
                            icon: Icons.error_outline_rounded,
                            onRetry: fetchShortlist,
                          )
                        : candidates.isEmpty
                            ? const ThemedEmptyState(
                                title: 'No Candidates Found',
                                subtitle:
                                    'No shortlisted candidates available for this position',
                                icon: Icons.people_alt_outlined,
                              )
                            : _buildCandidateList(isDark, primaryRed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon, String value, String label, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryRed.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryRed, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildCandidateList(bool isDark, Color primaryRed) {
    return RefreshIndicator(
      onRefresh: fetchShortlist,
      color: primaryRed,
      backgroundColor: isDark ? Color(0xFF14131E) : Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.all(0),
        itemCount: candidates.length,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final candidate = candidates[index];
          final overallScore = candidate['overall_score']?.toDouble() ?? 0.0;
          final (statusIcon, statusColor) = _getStatusData(candidate['status']);

          return _buildCandidateCard(
            candidate,
            overallScore,
            statusIcon,
            statusColor,
            isDark,
            primaryRed,
            index + 1, // Rank
          );
        },
      ),
    );
  }

  Widget _buildCandidateCard(
    Map<String, dynamic> candidate,
    double overallScore,
    IconData statusIcon,
    Color statusColor,
    bool isDark,
    Color primaryRed,
    int rank,
  ) {
    return MouseRegion(
      cursor: kIsWeb ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: () => openCandidateDetails(candidate),
        child: ThemedSurfaceCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Rank Badge
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rank <= 3
                      ? primaryRed.withValues(alpha: 0.9)
                      : Colors.grey.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  rank.toString(),
                  style: TextStyle(
                    color: rank <= 3
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Avatar
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryRed.withValues(alpha: 0.2),
                      primaryRed.withValues(alpha: 0.3),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  getInitials(candidate['full_name']),
                  style: TextStyle(
                    color: primaryRed,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Candidate Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            candidate['full_name'] ?? 'Unnamed Candidate',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade400,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildScoreItem(
                          Icons.description_outlined,
                          "CV: ${candidate['cv_score'] ?? 'N/A'}",
                          isDark,
                        ),
                        const SizedBox(width: 12),
                        _buildScoreItem(
                          Icons.quiz_outlined,
                          "Test: ${candidate['assessment_score'] ?? 'N/A'}",
                          isDark,
                        ),
                        const SizedBox(width: 12),
                        _buildScoreItem(
                          Icons.star_rate_rounded,
                          "Overall: ${overallScore.toStringAsFixed(1)}",
                          isDark,
                          isHighlighted: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      candidate['status']?.toString().toUpperCase() ??
                          "PENDING",
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreItem(IconData icon, String text, bool isDark,
      {bool isHighlighted = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: isHighlighted
              ? AppColors.primaryRed
              : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isHighlighted
                ? AppColors.primaryRed
                : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
