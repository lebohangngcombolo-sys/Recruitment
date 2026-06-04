import 'package:flutter/material.dart';
import '../../../models/hm_models.dart';
import '../../../constants/app_colors.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import 'interview_schedule_dialog.dart';

class CandidateProfileDialog extends StatefulWidget {
  final CandidateData candidate;

  const CandidateProfileDialog({
    super.key,
    required this.candidate,
  });

  @override
  State<CandidateProfileDialog> createState() => _CandidateProfileDialogState();
}

class _CandidateProfileDialogState extends State<CandidateProfileDialog> {
  final AdminService _admin = AdminService();
  Map<String, dynamic>? _drilldown;
  bool _loadingDrilldown = false;
  String? _drilldownError;

  @override
  void initState() {
    super.initState();
    if (widget.candidate.applicationId != null) {
      _loadDrilldown();
    }
  }

  Future<void> _loadDrilldown() async {
    final appId = widget.candidate.applicationId;
    if (appId == null) return;
    setState(() {
      _loadingDrilldown = true;
      _drilldownError = null;
    });
    try {
      final data = await _admin.getApplication(appId);
      if (mounted) {
        setState(() {
          _drilldown = data;
          _loadingDrilldown = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _drilldownError = e.toString();
          _loadingDrilldown = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.primaryRed.withValues(alpha: 0.1),
                        child: Text(
                          candidate.name.isNotEmpty
                              ? candidate.name[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              candidate.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              candidate.position,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textGrey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              candidate.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textGrey.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Match Score
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.psychology, color: AppColors.primaryRed),
                        const SizedBox(width: 12),
                        Text(
                          'Match Score: ${(candidate.matchScore * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Skills
                  if (candidate.skills.isNotEmpty) ...[
                    const Text(
                      'Skills',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: candidate.skills.map((skill) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            skill,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryRed,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Status and Applied Date
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(candidate.status)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                candidate.status,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getStatusColor(candidate.status),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Applied Date',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${candidate.appliedDate.day}/${candidate.appliedDate.month}/${candidate.appliedDate.year}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Drilldown: CV match breakdown, assessment results, reviewer notes
                  if (candidate.applicationId != null) ...[
                    if (_loadingDrilldown)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                            child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    else if (_drilldownError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Could not load details: $_drilldownError',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      )
                    else if (_drilldown != null) ...[
                      _DrilldownSection(
                        title: 'CV match breakdown',
                        icon: Icons.badge_outlined,
                        child: _buildCvBreakdown(_drilldown!),
                      ),
                      const SizedBox(height: 12),
                      _DrilldownSection(
                        title: 'Assessment results',
                        icon: Icons.quiz_outlined,
                        child: _buildAssessmentBreakdown(_drilldown!),
                      ),
                      const SizedBox(height: 12),
                      _DrilldownSection(
                        title: 'Reviewer notes',
                        icon: Icons.notes_outlined,
                        child: _buildReviewerNotes(_drilldown!),
                      ),
                    ],
                  ],

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.person, size: 16),
                          label: const Text('View Full Profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final token = await AuthService.getAccessToken();
                            if (token == null || token.isEmpty) return;
                            final result = await showDialog<dynamic>(
                              context: context,
                              builder: (ctx) => InterviewScheduleDialog(
                                token: token,
                                candidateId: widget.candidate.id,
                                applicationId: widget.candidate.applicationId,
                              ),
                            );
                            if (!mounted) return;
                            if (result is Map<String, dynamic>) {
                              try {
                                await _admin.scheduleInterview(result);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Interview scheduled successfully.'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  Navigator.of(context).pop();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to schedule: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: const Text('Schedule Interview'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            foregroundColor: AppColors.primaryWhite,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCvBreakdown(Map<String, dynamic> data) {
    final app = data['application'] as Map<String, dynamic>? ?? {};
    final parser = app['cv_parser_result'] is Map
        ? Map<String, dynamic>.from(app['cv_parser_result'] as Map)
        : <String, dynamic>{};
    final missingSkills = List<String>.from(parser['missing_skills'] ?? []);
    final suggestions = List<String>.from(parser['suggestions'] ?? []);
    final matchScore = parser['match_score'];
    final recommendation = parser['recommendation'];
    final cvScore = app['cv_score'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cvScore != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'CV score: $cvScore%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        if (matchScore != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Match vs role: $matchScore%',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textGrey,
              ),
            ),
          ),
        if (missingSkills.isNotEmpty) ...[
          const Text('Missing skills', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: missingSkills
                .take(10)
                .map((s) => Chip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.orange.withValues(alpha: 0.2),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
        if (suggestions.isNotEmpty) ...[
          const Text('Suggestions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...suggestions.take(3).map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  s.toString(),
                  style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                ),
              )),
          const SizedBox(height: 8),
        ],
        if (recommendation != null && recommendation.toString().trim().isNotEmpty)
          Text(
            'Gaps / recommendation: $recommendation',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppColors.textGrey,
            ),
          ),
        if (missingSkills.isEmpty &&
            suggestions.isEmpty &&
            (recommendation == null || recommendation.toString().trim().isEmpty) &&
            matchScore == null &&
            cvScore == null)
          Text(
            'No CV breakdown available.',
            style: TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
      ],
    );
  }

  Widget _buildAssessmentBreakdown(Map<String, dynamic> data) {
    final app = data['application'] as Map<String, dynamic>? ?? {};
    final assessment = data['assessment'] as Map<String, dynamic>? ?? {};
    final assessmentScore = app['assessment_score'];
    final overallScore = app['overall_score'];
    final breakdown = app['scoring_breakdown'] is Map
        ? Map<String, dynamic>.from(app['scoring_breakdown'] as Map)
        : <String, dynamic>{};
    final percentageScore = assessment['percentage_score'] ?? assessment['total_score'];
    final scores = assessment['scores'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (assessmentScore != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Assessment score: $assessmentScore%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        if (overallScore != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Overall score: $overallScore%',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
          ),
        if (percentageScore != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Test score: $percentageScore%',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
          ),
        if (breakdown.isNotEmpty) ...[
          const Text('Breakdown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...breakdown.entries.take(5).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${e.key}: ${e.value}',
                  style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                ),
              )),
        ],
        if (scores is Map && scores.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Text('Scores', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...scores.entries.take(5).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${e.key}: ${e.value}',
                  style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                ),
              )),
        ],
        if (assessmentScore == null &&
            overallScore == null &&
            percentageScore == null &&
            breakdown.isEmpty &&
            (scores is! Map || scores.isEmpty))
          Text(
            'No assessment results yet.',
            style: TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
      ],
    );
  }

  Widget _buildReviewerNotes(Map<String, dynamic> data) {
    final notes = List<Map<String, dynamic>>.from(
        (data['reviewer_notes'] is List)
            ? (data['reviewer_notes'] as List)
                .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
            : []);

    if (notes.isEmpty) {
      return Text(
        'No reviewer notes yet.',
        style: TextStyle(fontSize: 12, color: AppColors.textGrey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: notes.map((n) {
        final name = n['interviewer_name'] ?? 'Reviewer';
        final rating = n['overall_rating'];
        final additional = n['additional_notes']?.toString() ?? '';
        final private = n['private_notes']?.toString() ?? '';
        final submitted = n['submitted_at']?.toString() ?? '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (rating != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Rating: $rating/5',
                        style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                      ),
                    ],
                    if (submitted.isNotEmpty) ...[
                      const Spacer(),
                      Text(
                        submitted.length > 10 ? submitted.substring(0, 10) : submitted,
                        style: TextStyle(fontSize: 10, color: AppColors.textGrey),
                      ),
                    ],
                  ],
                ),
                if (additional.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    additional,
                    style: TextStyle(fontSize: 11, color: AppColors.textDark),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (private.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '(Private) $private',
                    style: TextStyle(fontSize: 10, color: AppColors.textGrey, fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hired':
        return Colors.green;
      case 'interview':
        return Colors.blue;
      case 'screening':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return AppColors.textGrey;
    }
  }
}

class _DrilldownSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DrilldownSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryRed),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
