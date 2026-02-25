/// Model for a reusable assessment (test) pack linked to requisitions.
class TestPack {
  final int id;
  final String name;
  final String category;
  final String description;
  final List<Map<String, dynamic>> questions;
  final int questionCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  TestPack({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.questions,
    required this.questionCount,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory TestPack.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'];
    final questionsList = rawQuestions is List
        ? rawQuestions
            .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
            .toList()
        : <Map<String, dynamic>>[];
    return TestPack(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'technical',
      description: json['description'] as String? ?? '',
      questions: questionsList,
      questionCount: (json['question_count'] as num?)?.toInt() ?? questionsList.length,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'description': description,
        'questions': questions,
        'question_count': questionCount,
      };
}
