import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';

class AIService {
  static const String _baseUrl = 'http://localhost:5000/api/ai';

  static void initialize() {
    // AI Service initialized - uses backend API calls
    print("AI Service initialized with backend API calls");
  }

  static Future<Map<String, dynamic>> generateJobDetails(String jobTitle) async {
    try {
      final authProvider = AuthProvider();
      final token = await authProvider.getToken();

      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/generate_job_details'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'job_title': jobTitle,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['job_details'] as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied - admin or hiring manager role required');
      } else {
        throw Exception('Failed to generate job details: ${response.body}');
      }
    } catch (e) {
      print('Error generating job details: $e');
      // Return fallback data
      return _getFallbackJobDetails(jobTitle);
    }
  }

  static Future<List<Map<String, dynamic>>> generateAssessmentQuestions({
    required String jobTitle,
    required String difficulty,
    required int questionCount,
  }) async {
    try {
      final authProvider = AuthProvider();
      final token = await authProvider.getToken();

      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/generate_questions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'job_title': jobTitle,
          'difficulty': difficulty,
          'question_count': questionCount,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['questions'] ?? []);
      } else {
        throw Exception('Failed to generate questions: ${response.body}');
      }
    } catch (e) {
      print('Error generating questions: $e');
      // Return fallback questions
      return _getFallbackAssessmentQuestions(jobTitle, difficulty, questionCount);
    }
  }

  static Map<String, dynamic> _getFallbackJobDetails(String jobTitle) {
    return {
      'description':
          'We are seeking a talented $jobTitle to join our dynamic team. This role offers an exciting opportunity to contribute to innovative projects and grow professionally in a collaborative environment.',
      'responsibilities': [
        'Perform core responsibilities related to $jobTitle',
        'Collaborate with cross-functional teams',
        'Contribute to project planning and execution',
        'Maintain high-quality standards in all deliverables',
        'Continuously improve processes and methodologies'
      ],
      'qualifications': [
        'Relevant experience in $jobTitle or similar roles',
        'Strong problem-solving and analytical thinking skills',
        'Excellent communication and collaboration abilities',
        'Ability to adapt to changing priorities and requirements',
        'Commitment to continuous learning and professional growth'
      ],
      'company_details':
          'Our company is a forward-thinking organization that values innovation, collaboration, and employee growth. We offer a supportive environment where talented individuals can thrive and make meaningful contributions.',
      'category': 'Engineering',
      'required_skills': ['Communication', 'Teamwork', 'Problem Solving', 'Time Management'],
      'min_experience': '2',
      'salary_min': '25000',
      'salary_max': '40000',
      'salary_currency': 'ZAR',
      'salary_period': 'monthly',
      'evaluation_weightings': {
        'cv': 60,
        'assessment': 30,
        'interview': 10,
        'references': 0,
      }
    };
  }

  static List<Map<String, dynamic>> _getFallbackAssessmentQuestions(
      String jobTitle, String difficulty, int questionCount) {
    final List<Map<String, dynamic>> baseQuestions = [
      {
        "question":
            "What is your primary experience level with ${jobTitle.toLowerCase()} responsibilities?",
        "options": ["Beginner", "Intermediate", "Advanced", "Expert"],
        "answer": 2,
        "weight": 1
      },
      {
        "question":
            "How would you handle a challenging situation in this role?",
        "options": [
          "Seek help immediately",
          "Try to solve it myself",
          "Research and consult",
          "Delegate to others"
        ],
        "answer": 2,
        "weight": 1
      },
      {
        "question":
            "What motivates you most in a ${jobTitle.toLowerCase()} position?",
        "options": [
          "Salary",
          "Learning opportunities",
          "Team collaboration",
          "Autonomy"
        ],
        "answer": 1,
        "weight": 1
      },
    ];

    return baseQuestions.take(questionCount).toList();
  }
}
