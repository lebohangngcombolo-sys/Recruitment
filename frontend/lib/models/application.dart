class Application {
  final int id;
  final String candidateName;
  final String jobTitle;
  final String status;
  final DateTime? appliedDate; // nullable
  final int? cvScore;
  final int? assessmentScore;
  final double? overallScore;
  final String? recommendation;

  // Additional fields that were referenced in the dialog
  final int candidateId;
  final String candidateEmail;
  final String? candidatePhone;
  final String? resumeUrl;
  final String? coverLetter;
  final int? yearsOfExperience;
  final List<String>? skills;
  final List<dynamic>? education;
  final List<dynamic>? workExperience;

  // Interview feedback statistics
  final double? technicalScore;
  final double? communicationScore;
  final double? cultureFitScore;
  final double? problemSolvingScore;
  final double? experienceScore;
  final int? feedbackCount;
  final Map<String, dynamic>? recommendationsBreakdown;
  final bool? readyForOffer;
  final String? decision;
  final double? recommendationScore;
  final List<String>? nextSteps;
  final Map<String, dynamic>? interviewStats;
  final DateTime? appliedAt; // ADDED: This was missing

  Application({
    required this.id,
    required this.candidateName,
    required this.jobTitle,
    required this.status,
    this.appliedDate,
    this.cvScore,
    this.assessmentScore,
    this.overallScore,
    this.recommendation,

    // Required fields
    required this.candidateId,
    required this.candidateEmail,

    // Optional fields
    this.candidatePhone,
    this.resumeUrl,
    this.coverLetter,
    this.yearsOfExperience,
    this.skills,
    this.education,
    this.workExperience,
    this.technicalScore,
    this.communicationScore,
    this.cultureFitScore,
    this.problemSolvingScore,
    this.experienceScore,
    this.feedbackCount,
    this.recommendationsBreakdown,
    this.readyForOffer,
    this.decision,
    this.recommendationScore,
    this.nextSteps,
    this.interviewStats,
    this.appliedAt, // ADDED: This was missing
  });

  factory Application.fromJson(Map<String, dynamic> json) {
    // Handle both application data and candidate data from new endpoint
    final rawId = json['application_id'] ?? json['id'] ?? json['candidate_id'];

    if (rawId == null) {
      throw Exception('ID missing in response');
    }

    // Parse interview statistics if available
    final stats = json['statistics'] ?? {};
    final recommendations = stats['recommendations'] ?? {};

    // Handle applied date - try multiple possible fields
    DateTime? parseAppliedDate() {
      final dates = [
        json['applied_date'],
        json['applied_at'],
        json['created_at'],
        json['submitted_at'],
      ];

      for (final date in dates) {
        if (date != null) {
          final parsed = DateTime.tryParse(date.toString());
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    return Application(
      id: rawId is int ? rawId : int.parse(rawId.toString()),
      candidateName: json['candidate_name'] ?? json['full_name'] ?? 'Unnamed',
      jobTitle:
          json['job_title'] ?? json['position_applied'] ?? 'Unknown Position',
      status: json['status'] ?? json['current_stage'] ?? 'unknown',
      appliedDate: parseAppliedDate(),
      appliedAt: parseAppliedDate(), // Use the same date

      // Scores
      cvScore: json['cv_score'],
      assessmentScore: json['assessment_score'],
      overallScore: _parseDouble(
          json['overall_score'] ?? stats['average_overall_rating']),
      recommendation: json['recommendation'] ?? json['decision'],

      // Candidate details
      candidateId: json['candidate_id'] ?? json['id'] ?? 0,
      candidateEmail: json['email'] ?? json['candidate_email'] ?? '',
      candidatePhone: json['phone'] ?? json['candidate_phone'],
      resumeUrl: json['resume_url'],
      coverLetter: json['cover_letter'],
      yearsOfExperience: json['years_of_experience'],
      skills: json['skills'] != null ? List<String>.from(json['skills']) : null,
      education: json['education'],
      workExperience: json['work_experience'],

      // Interview feedback scores
      technicalScore: _parseDouble(stats['average_technical']),
      communicationScore: _parseDouble(stats['average_communication']),
      cultureFitScore: _parseDouble(stats['average_culture_fit']),
      problemSolvingScore: _parseDouble(stats['average_problem_solving']),
      experienceScore: _parseDouble(stats['average_experience']),
      feedbackCount: stats['feedback_count'],

      // Recommendations breakdown
      recommendationsBreakdown: recommendations is Map<String, dynamic>
          ? Map<String, dynamic>.from(recommendations)
          : null,

      // Offer readiness
      readyForOffer: json['ready_for_offer'],
      decision: json['decision'],
      recommendationScore: _parseDouble(json['recommendation_score']),
      nextSteps: json['next_steps'] != null
          ? List<String>.from(json['next_steps'])
          : null,

      // Full statistics
      interviewStats: stats is Map<String, dynamic>
          ? Map<String, dynamic>.from(stats)
          : null,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // Helper method to calculate a summary score
  double get calculatedScore {
    if (overallScore != null) return overallScore!;

    // Calculate from individual scores if available
    final scores = [
      technicalScore,
      communicationScore,
      cultureFitScore,
      problemSolvingScore,
      experienceScore,
    ].where((score) => score != null).cast<double>();

    if (scores.isNotEmpty) {
      return scores.reduce((a, b) => a + b) / scores.length;
    }

    return 0.0;
  }

  // Helper method to get strongest recommendation
  String? get strongestRecommendation {
    if (recommendationsBreakdown == null) return recommendation;

    final recs = Map<String, dynamic>.from(recommendationsBreakdown!);
    recs.removeWhere(
        (key, value) => value == null || (value is num && value <= 0));

    if (recs.isEmpty) return recommendation;

    final maxKey = recs.keys.reduce((a, b) => recs[a]! > recs[b]! ? a : b);
    return maxKey.replaceAll('_', ' ').toUpperCase();
  }

  // Helper method to get recommendation count
  int get recommendationCount {
    if (recommendationsBreakdown == null) return 0;

    return recommendationsBreakdown!.values
        .where((value) => value is int && value > 0)
        .fold(0, (sum, value) => sum + (value as int));
  }

  // Helper method to check if candidate is highly recommended
  bool get isHighlyRecommended {
    if (readyForOffer == true) return true;
    if (recommendationScore != null && recommendationScore! >= 80) return true;
    if (decision?.toLowerCase().contains('strong') == true) return true;
    return false;
  }

  // Convert to map for JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'candidate_name': candidateName,
      'job_title': jobTitle,
      'status': status,
      'applied_date': appliedDate?.toIso8601String(),
      'applied_at': appliedAt?.toIso8601String(),
      'cv_score': cvScore,
      'assessment_score': assessmentScore,
      'overall_score': overallScore,
      'recommendation': recommendation,
      'candidate_id': candidateId,
      'candidate_email': candidateEmail,
      'candidate_phone': candidatePhone,
      'resume_url': resumeUrl,
      'cover_letter': coverLetter,
      'years_of_experience': yearsOfExperience,
      'skills': skills,
      'education': education,
      'work_experience': workExperience,
      'technical_score': technicalScore,
      'communication_score': communicationScore,
      'culture_fit_score': cultureFitScore,
      'problem_solving_score': problemSolvingScore,
      'experience_score': experienceScore,
      'feedback_count': feedbackCount,
      'recommendations_breakdown': recommendationsBreakdown,
      'ready_for_offer': readyForOffer,
      'decision': decision,
      'recommendation_score': recommendationScore,
      'next_steps': nextSteps,
      'interview_stats': interviewStats,
    };
  }

  // Copy with method for immutability
  Application copyWith({
    int? id,
    String? candidateName,
    String? jobTitle,
    String? status,
    DateTime? appliedDate,
    DateTime? appliedAt,
    int? cvScore,
    int? assessmentScore,
    double? overallScore,
    String? recommendation,
    int? candidateId,
    String? candidateEmail,
    String? candidatePhone,
    String? resumeUrl,
    String? coverLetter,
    int? yearsOfExperience,
    List<String>? skills,
    List<dynamic>? education,
    List<dynamic>? workExperience,
    double? technicalScore,
    double? communicationScore,
    double? cultureFitScore,
    double? problemSolvingScore,
    double? experienceScore,
    int? feedbackCount,
    Map<String, dynamic>? recommendationsBreakdown,
    bool? readyForOffer,
    String? decision,
    double? recommendationScore,
    List<String>? nextSteps,
    Map<String, dynamic>? interviewStats,
  }) {
    return Application(
      id: id ?? this.id,
      candidateName: candidateName ?? this.candidateName,
      jobTitle: jobTitle ?? this.jobTitle,
      status: status ?? this.status,
      appliedDate: appliedDate ?? this.appliedDate,
      cvScore: cvScore ?? this.cvScore,
      assessmentScore: assessmentScore ?? this.assessmentScore,
      overallScore: overallScore ?? this.overallScore,
      recommendation: recommendation ?? this.recommendation,
      candidateId: candidateId ?? this.candidateId,
      candidateEmail: candidateEmail ?? this.candidateEmail,
      candidatePhone: candidatePhone ?? this.candidatePhone,
      resumeUrl: resumeUrl ?? this.resumeUrl,
      coverLetter: coverLetter ?? this.coverLetter,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      skills: skills ?? this.skills,
      education: education ?? this.education,
      workExperience: workExperience ?? this.workExperience,
      technicalScore: technicalScore ?? this.technicalScore,
      communicationScore: communicationScore ?? this.communicationScore,
      cultureFitScore: cultureFitScore ?? this.cultureFitScore,
      problemSolvingScore: problemSolvingScore ?? this.problemSolvingScore,
      experienceScore: experienceScore ?? this.experienceScore,
      feedbackCount: feedbackCount ?? this.feedbackCount,
      recommendationsBreakdown:
          recommendationsBreakdown ?? this.recommendationsBreakdown,
      readyForOffer: readyForOffer ?? this.readyForOffer,
      decision: decision ?? this.decision,
      recommendationScore: recommendationScore ?? this.recommendationScore,
      nextSteps: nextSteps ?? this.nextSteps,
      interviewStats: interviewStats ?? this.interviewStats,
      appliedAt: appliedAt ?? this.appliedAt,
    );
  }

  @override
  String toString() {
    return 'Application{id: $id, candidate: $candidateName, position: $jobTitle, score: ${calculatedScore.toStringAsFixed(1)}, ready: $readyForOffer}';
  }
}
