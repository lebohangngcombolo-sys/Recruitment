class CVAnalyserUploadResponse {
  final String analysisId;
  final String resumeId;
  final String status;

  CVAnalyserUploadResponse({
    required this.analysisId,
    required this.resumeId,
    required this.status,
  });

  factory CVAnalyserUploadResponse.fromJson(Map<String, dynamic> json) {
    return CVAnalyserUploadResponse(
      analysisId: json['analysis_id']?.toString() ?? '',
      resumeId: json['resume_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
    );
  }
}

class CVAnalyserStatusResponse {
  final String analysisId;
  final String status;
  final dynamic summary;
  final num? matchScore;
  final List<String> missingSkills;
  final String? finishedAt;
  final List<dynamic> warnings;

  CVAnalyserStatusResponse({
    required this.analysisId,
    required this.status,
    required this.summary,
    required this.matchScore,
    required this.missingSkills,
    required this.finishedAt,
    required this.warnings,
  });

  factory CVAnalyserStatusResponse.fromJson(Map<String, dynamic> json) {
    return CVAnalyserStatusResponse(
      analysisId: json['analysis_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      summary: json['summary'],
      matchScore: json['match_score'] is num ? json['match_score'] as num : null,
      missingSkills: List<String>.from(json['missing_skills'] ?? const []),
      finishedAt: json['finished_at']?.toString(),
      warnings: List<dynamic>.from(json['warnings'] ?? const []),
    );
  }
}

class CVAnalyserResult {
  final String analysisId;
  final String resumeId;
  final double overallScore;
  final ComponentScores componentScores;
  final Evidence evidence;
  final List<Suggestion> suggestions;
  final Map<String, dynamic>? rawPayload;

  CVAnalyserResult({
    required this.analysisId,
    required this.resumeId,
    required this.overallScore,
    required this.componentScores,
    required this.evidence,
    required this.suggestions,
    required this.rawPayload,
  });

  factory CVAnalyserResult.fromJson(Map<String, dynamic> json) {
    return CVAnalyserResult(
      analysisId: json['analysis_id']?.toString() ?? '',
      resumeId: json['resume_id']?.toString() ?? '',
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0.0,
      componentScores: ComponentScores.fromJson(
          Map<String, dynamic>.from(json['component_scores'] ?? const {})),
      evidence: Evidence.fromJson(
          Map<String, dynamic>.from(json['evidence'] ?? const {})),
      suggestions: (json['suggestions'] as List? ?? const [])
          .map((s) => Suggestion.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      rawPayload: json['raw_payload'] is Map
          ? Map<String, dynamic>.from(json['raw_payload'] as Map)
          : null,
    );
  }
}

class ComponentScores {
  final double skills;
  final double experience;
  final double education;
  final double format;

  ComponentScores({
    required this.skills,
    required this.experience,
    required this.education,
    required this.format,
  });

  factory ComponentScores.fromJson(Map<String, dynamic> json) {
    return ComponentScores(
      skills: (json['skills'] as num?)?.toDouble() ?? 0.0,
      experience: (json['experience'] as num?)?.toDouble() ?? 0.0,
      education: (json['education'] as num?)?.toDouble() ?? 0.0,
      format: (json['format'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Evidence {
  final List<MatchedSkill> matchedSkills;
  final List<String> missingSkills;
  final List<TimelineItem> timeline;

  Evidence({
    required this.matchedSkills,
    required this.missingSkills,
    required this.timeline,
  });

  factory Evidence.fromJson(Map<String, dynamic> json) {
    return Evidence(
      matchedSkills: (json['matched_skills'] as List? ?? const [])
          .map((s) => MatchedSkill.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      missingSkills: List<String>.from(json['missing_skills'] ?? const []),
      timeline: (json['timeline'] as List? ?? const [])
          .map((t) => TimelineItem.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList(),
    );
  }
}

class MatchedSkill {
  final String skill;
  final String? snippet;
  final double? score;

  MatchedSkill({
    required this.skill,
    required this.snippet,
    required this.score,
  });

  factory MatchedSkill.fromJson(Map<String, dynamic> json) {
    return MatchedSkill(
      skill: json['skill']?.toString() ?? '',
      snippet: json['snippet']?.toString(),
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}

class TimelineItem {
  final String? company;
  final String? title;
  final String? from;
  final String? to;

  TimelineItem({
    required this.company,
    required this.title,
    required this.from,
    required this.to,
  });

  factory TimelineItem.fromJson(Map<String, dynamic> json) {
    return TimelineItem(
      company: json['company']?.toString(),
      title: json['title']?.toString(),
      from: (json['from_'] ?? json['from'])?.toString(),
      to: json['to_']?.toString() ?? json['to']?.toString(),
    );
  }
}

class Suggestion {
  final String id;
  final String text;
  final String priority;

  Suggestion({
    required this.id,
    required this.text,
    required this.priority,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'medium',
    );
  }
}
