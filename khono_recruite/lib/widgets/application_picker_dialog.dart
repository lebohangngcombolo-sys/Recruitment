import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/application.dart';
import '../services/admin_service.dart';

class ApplicationPickerDialog extends StatefulWidget {
  const ApplicationPickerDialog({super.key});

  @override
  State<ApplicationPickerDialog> createState() =>
      _ApplicationPickerDialogState();
}

class _ApplicationPickerDialogState extends State<ApplicationPickerDialog> {
  final AdminService _adminService = AdminService();
  bool _loading = true;
  List<Map<String, dynamic>> _candidates = [];

  // Filter states
  double _minRating = 3.5;
  int _minInterviews = 2;
  int _limit = 50;

  @override
  void initState() {
    super.initState();
    _loadCandidatesReadyForOffer();
  }

  /// Load candidates ready for offers using the optimized endpoint
  Future<void> _loadCandidatesReadyForOffer() async {
    try {
      final data = await _adminService.getCandidatesReadyForOffer(
        minInterviews: _minInterviews,
        minRating: _minRating,
        limit: _limit,
      );

      if (data['success'] == true) {
        final rawCandidates =
            List<Map<String, dynamic>>.from(data['candidates'] ?? []);

        // DEBUG: Print first candidate to see structure
        if (rawCandidates.isNotEmpty && kDebugMode) {
          debugPrint('First candidate raw data: ${rawCandidates[0]}');
        }

        // Map backend field names (camelCase) to frontend expected names (snake_case)
        final mappedCandidates = rawCandidates.map((candidate) {
          return {
            'candidate_id': candidate['candidateId'],
            'candidate_name': candidate['candidateName'],
            'email': candidate['email'],
            'ready_for_offer':
                candidate['readyForOffer'] ?? false, // ← FIXED FIELD NAME
            'decision': candidate['decision'],
            'statistics': {
              'average_overall_rating':
                  candidate['statistics']?['averageOverallRating'] ?? 0.0,
              'average_technical':
                  candidate['statistics']?['averageTechnical'] ?? 0.0,
              'average_communication':
                  candidate['statistics']?['averageCommunication'] ?? 0.0,
              'average_culture_fit':
                  candidate['statistics']?['averageCultureFit'] ?? 0.0,
              'average_problem_solving':
                  candidate['statistics']?['averageProblemSolving'] ?? 0.0,
              'average_experience':
                  candidate['statistics']?['averageExperience'] ?? 0.0,
              'feedback_count': candidate['statistics']?['feedbackCount'] ?? 0,
              'recommendations': {
                'strong_hire': candidate['statistics']?['strongHireCount'] ?? 0,
                'hire': candidate['statistics']?['hireCount'] ?? 0,
                'no_hire': candidate['statistics']?['noHireCount'] ?? 0,
                'strong_no_hire':
                    candidate['statistics']?['strongNoHireCount'] ?? 0,
              }
            },
            'recommendation_score': candidate['recommendationScore'] ?? 0.0,
            'next_steps': candidate['nextSteps'] ?? [],
          };
        }).toList();

        setState(() {
          _candidates = mappedCandidates;
          _loading = false;
        });

        // DEBUG: Print counts
        if (kDebugMode) {
          final readyCount =
              _candidates.where((c) => c['ready_for_offer'] == true).length;
          debugPrint('Total candidates: ${_candidates.length}');
          debugPrint('Ready candidates: $readyCount');
          debugPrint('Review candidates: ${_candidates.length - readyCount}');
        }
      } else {
        throw Exception(data['error'] ?? 'Failed to load candidates');
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load candidates: $e')),
      );
    }
  }

  /// When user selects a candidate for offer
  Future<void> _onCandidateTap(Map<String, dynamic> candidate) async {
    try {
      final application = Application(
        id: candidate['candidate_id'] ?? 0,
        candidateName: candidate['candidate_name'] ?? 'Unknown',
        jobTitle: 'Unknown Position', // No position info
        candidateId: candidate['candidate_id'] ?? 0,
        status: 'recommended_for_offer',
        appliedAt: DateTime.now(),
        candidateEmail: candidate['email'] ?? '',
        candidatePhone: '',
        resumeUrl: '',
        coverLetter: '',
        yearsOfExperience: 0,
        skills: [],
        education: [],
        workExperience: [],
        overallScore:
            candidate['statistics']['average_overall_rating']?.toDouble() ??
                0.0,
        technicalScore:
            candidate['statistics']['average_technical']?.toDouble() ?? 0.0,
        communicationScore:
            candidate['statistics']['average_communication']?.toDouble() ?? 0.0,
        cultureFitScore:
            candidate['statistics']['average_culture_fit']?.toDouble() ?? 0.0,
      );

      Navigator.pop(context, application);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select candidate: $e')),
      );
    }
  }

  /// Refresh with new filters
  void _refreshWithFilters() {
    setState(() => _loading = true);
    _loadCandidatesReadyForOffer();
  }

  /// Show filter dialog
  Future<void> _showFilterDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => FilterDialog(
        initialMinRating: _minRating,
        initialMinInterviews: _minInterviews,
        initialLimit: _limit,
      ),
    );

    if (result != null) {
      setState(() {
        _minRating = result['min_rating'] ?? _minRating;
        _minInterviews = result['min_interviews'] ?? _minInterviews;
        _limit = result['limit'] ?? _limit;
      });
      _refreshWithFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Select Candidate for Offer'),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter candidates',
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    // DEBUG: Show raw data for troubleshooting
    final debugInfo = _buildDebugInfo();

    if (_candidates.isEmpty) {
      return Column(
        children: [
          if (debugInfo != null) debugInfo,
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No candidates ready for offers',
                  style: TextStyle(color: Colors.grey),
                ),
                Text(
                  'Try adjusting your filters',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final readyCandidates =
        _candidates.where((c) => c['ready_for_offer'] == true).toList();
    final reviewCandidates =
        _candidates.where((c) => c['ready_for_offer'] != true).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (debugInfo != null) debugInfo,
        _buildSummaryBar(readyCandidates.length, reviewCandidates.length),
        const SizedBox(height: 8),
        if (readyCandidates.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              '✅ Ready for Offers',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
          _buildCandidateList(readyCandidates, isRecommended: true),
        ],
        if (reviewCandidates.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              '⚠️ Needs Review',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
          _buildCandidateList(reviewCandidates, isRecommended: false),
        ],
      ],
    );
  }

  /// Debug widget to show candidate data structure
  Widget? _buildDebugInfo() {
    // Only show in debug mode
    const bool isDebug = true; // Set to false in production

    if (!isDebug || _candidates.isEmpty) return null;

    return Card(
      color: Colors.amber[50],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report, size: 16),
                const SizedBox(width: 4),
                const Text(
                  'DEBUG INFO',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  '${_candidates.length} candidates',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_candidates.isNotEmpty) ...[
              Text(
                'First candidate keys: ${_candidates[0].keys.join(", ")}',
                style: const TextStyle(fontSize: 10),
              ),
              const SizedBox(height: 4),
              Text(
                'ready_for_offer: ${_candidates[0]['ready_for_offer']} (${_candidates[0]['ready_for_offer'].runtimeType})',
                style: const TextStyle(fontSize: 10),
              ),
              const SizedBox(height: 4),
              Text(
                'decision: ${_candidates[0]['decision']}',
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar(int readyCount, int reviewCount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Ready', readyCount, Colors.green),
          _buildStatItem('Review', reviewCount, Colors.orange),
          _buildStatItem('Total', _candidates.length, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildCandidateList(List<Map<String, dynamic>> candidates,
      {required bool isRecommended}) {
    return SizedBox(
      height: candidates.length <= 3 ? candidates.length * 80.0 : 240.0,
      child: ListView.builder(
        itemCount: candidates.length,
        itemBuilder: (context, index) {
          final candidate = candidates[index];
          return _buildCandidateCard(candidate, isRecommended);
        },
      ),
    );
  }

  Widget _buildCandidateCard(
      Map<String, dynamic> candidate, bool isRecommended) {
    final stats = candidate['statistics'];
    final decision = candidate['decision'] ?? 'UNKNOWN';
    final recommendationScore = candidate['recommendation_score'] ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      color: isRecommended ? Colors.green[50] : Colors.orange[50],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isRecommended ? Colors.green : Colors.orange,
          child: Text(
            candidate['candidate_name']?.substring(0, 1).toUpperCase() ?? '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                candidate['candidate_name'] ?? 'Unknown',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isRecommended ? Colors.green[800] : Colors.orange[800],
                ),
              ),
            ),
            Chip(
              label: Text(decision),
              backgroundColor:
                  isRecommended ? Colors.green[100] : Colors.orange[100],
              labelStyle: TextStyle(
                color: isRecommended ? Colors.green[800] : Colors.orange[800],
                fontSize: 10,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildRatingBadge(
                    '⭐ ${stats['average_overall_rating']?.toStringAsFixed(1) ?? 'N/A'}'),
                const SizedBox(width: 4),
                _buildRatingBadge(
                    '📊 ${stats['feedback_count'] ?? 0} interviews'),
                const SizedBox(width: 4),
                _buildRatingBadge(
                    '💬 ${stats['recommendations']['strong_hire'] ?? 0} strong'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Score: ${recommendationScore.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        trailing: Icon(
          isRecommended ? Icons.check_circle : Icons.info_outline,
          color: isRecommended ? Colors.green : Colors.orange,
        ),
        onTap: () => _onCandidateTap(candidate),
      ),
    );
  }

  Widget _buildRatingBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10),
      ),
    );
  }
}

/// Filter Dialog for adjusting criteria
class FilterDialog extends StatefulWidget {
  final double initialMinRating;
  final int initialMinInterviews;
  final int initialLimit;

  const FilterDialog({
    super.key,
    required this.initialMinRating,
    required this.initialMinInterviews,
    required this.initialLimit,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late double _minRating;
  late int _minInterviews;
  late int _limit;

  @override
  void initState() {
    super.initState();
    _minRating = widget.initialMinRating;
    _minInterviews = widget.initialMinInterviews;
    _limit = widget.initialLimit;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Candidates'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Minimum Rating: ${_minRating.toStringAsFixed(1)}'),
                subtitle: Slider(
                  value: _minRating,
                  min: 1.0,
                  max: 5.0,
                  divisions: 8,
                  label: _minRating.toStringAsFixed(1),
                  onChanged: (value) => setState(() => _minRating = value),
                ),
              ),
              ListTile(
                title: Text('Minimum Interviews: $_minInterviews'),
                subtitle: Slider(
                  value: _minInterviews.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '$_minInterviews',
                  onChanged: (value) =>
                      setState(() => _minInterviews = value.toInt()),
                ),
              ),
              ListTile(
                title: Text('Max Results: $_limit'),
                subtitle: Slider(
                  value: _limit.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 9,
                  label: '$_limit',
                  onChanged: (value) => setState(() => _limit = value.toInt()),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'min_rating': _minRating,
              'min_interviews': _minInterviews,
              'limit': _limit,
            });
          },
          child: const Text('Apply Filters'),
        ),
      ],
    );
  }
}
