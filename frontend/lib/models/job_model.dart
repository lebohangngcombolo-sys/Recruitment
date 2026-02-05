class Job {
  final int id;
  final String title;
  final String description;
  final String? jobSummary;
  final List<String> responsibilities;
  final String? companyDetails;
  final List<String> qualifications;
  final String category;
  final List<String> requiredSkills;
  final double minExperience;
  final List<String> knockoutRules;
  final Map<String, dynamic> weightings;
  final Map<String, dynamic> assessmentPack;
  final int createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime publishedOn;
  final int vacancy;
  final bool isActive;
  final DateTime? deletedAt;
  final int? applicationCount;

  const Job({
    required this.id,
    required this.title,
    required this.description,
    this.jobSummary,
    this.responsibilities = const [],
    this.companyDetails,
    this.qualifications = const [],
    this.category = '',
    this.requiredSkills = const [],
    this.minExperience = 0,
    this.knockoutRules = const [],
    this.weightings = const {'cv': 60, 'assessment': 40},
    this.assessmentPack = const {'questions': []},
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.publishedOn,
    this.vacancy = 1,
    this.isActive = true,
    this.deletedAt,
    this.applicationCount = 0,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      jobSummary: json['job_summary'] as String?,
      responsibilities: List<String>.from(json['responsibilities'] ?? []),
      companyDetails: json['company_details'] as String?,
      qualifications: List<String>.from(json['qualifications'] ?? []),
      category: json['category'] as String? ?? '',
      requiredSkills: List<String>.from(json['required_skills'] ?? []),
      minExperience: (json['min_experience'] as num?)?.toDouble() ?? 0.0,
      knockoutRules: List<String>.from(json['knockout_rules'] ?? []),
      weightings: Map<String, dynamic>.from(json['weightings'] ?? {}),
      assessmentPack: Map<String, dynamic>.from(json['assessment_pack'] ?? {}),
      createdBy: json['created_by'] as int,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      publishedOn: DateTime.parse(json['published_on']),
      vacancy: json['vacancy'] as int? ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'])
          : null,
      applicationCount: json['application_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'job_summary': jobSummary,
      'responsibilities': responsibilities,
      'company_details': companyDetails,
      'qualifications': qualifications,
      'category': category,
      'required_skills': requiredSkills,
      'min_experience': minExperience,
      'knockout_rules': knockoutRules,
      'weightings': weightings,
      'assessment_pack': assessmentPack,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'published_on': publishedOn.toIso8601String(),
      'vacancy': vacancy,
      'is_active': isActive,
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return toJson();
  }
}
