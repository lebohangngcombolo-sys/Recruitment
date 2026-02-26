import 'dart:convert';
import 'package:http/http.dart' as http;

import '../utils/api_endpoints.dart';
import 'auth_service.dart';

class AIService {
  static Future<Map<String, dynamic>> generateJobDetails(
      String jobTitle) async {
    // Try backend first (uses server-side API keys; no keys in client)
    try {
      final token = await AuthService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        final response = await http.post(
          Uri.parse(ApiEndpoints.generateJobDetails),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'job_title': jobTitle.trim()}),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            return _ensureAllFieldsFilled(data, jobTitle);
          }
        }
      }
    } catch (e) {
      print("Backend generateJobDetails failed: $e");
    }

    // Return fallback data if backend fails
    return _getFallbackJobDetails(jobTitle);
  }

  static int _determineMinExperience(String jobTitle) {
    final title = jobTitle.toLowerCase();

    if (title.contains('senior') ||
        title.contains('lead') ||
        title.contains('principal')) {
      return 5;
    } else if (title.contains('manager') || title.contains('director')) {
      return 7;
    } else if (title.contains('junior') ||
        title.contains('entry') ||
        title.contains('trainee')) {
      return 0;
    } else if (title.contains('intern') || title.contains('internship')) {
      return 0;
    } else {
      return 2; // Default for mid-level positions
    }
  }

  static Map<String, dynamic> _ensureAllFieldsFilled(
      Map<String, dynamic> jobDetails, String jobTitle) {
    print("Original jobDetails: $jobDetails");

    // Ensure description is filled
    if (jobDetails['description'] == null ||
        jobDetails['description'].toString().trim().isEmpty) {
      print("Description is empty, generating default");
      jobDetails['description'] = _generateDefaultDescription(jobTitle);
    } else {
      print("Description found: ${jobDetails['description']}");
    }

    // Ensure responsibilities is filled
    if (jobDetails['responsibilities'] == null ||
        (jobDetails['responsibilities'] as List?)?.isEmpty == true) {
      print("Responsibilities is empty, generating default");
      jobDetails['responsibilities'] =
          _generateDefaultResponsibilities(jobTitle);
    }

    // Ensure qualifications is filled
    if (jobDetails['qualifications'] == null ||
        (jobDetails['qualifications'] as List?)?.isEmpty == true) {
      print("Qualifications is empty, generating default");
      jobDetails['qualifications'] = _generateDefaultQualifications(jobTitle);
    }

    // Ensure category is filled
    if (jobDetails['category'] == null ||
        jobDetails['category'].toString().trim().isEmpty) {
      print("Category is empty, determining category");
      jobDetails['category'] = _determineCategory(jobTitle);
    } else {
      print("Category found: ${jobDetails['category']}");
    }

    // Ensure required_skills is filled
    if (jobDetails['required_skills'] == null ||
        (jobDetails['required_skills'] as List?)?.isEmpty == true) {
      print("Required skills is empty, generating default");
      jobDetails['required_skills'] = _generateDefaultSkills(jobTitle);
    }

    // Ensure min_experience is filled
    if (jobDetails['min_experience'] == null ||
        jobDetails['min_experience'].toString().trim().isEmpty) {
      print("Min experience is empty, determining");
      jobDetails['min_experience'] =
          _determineMinExperience(jobTitle).toString();
    }

    // Company details is optional - only fill if completely empty
    if (jobDetails['company_details'] == null ||
        jobDetails['company_details'].toString().trim().isEmpty) {
      jobDetails['company_details'] = ''; // Leave empty as requested
    }

    print("Final jobDetails: $jobDetails");
    return jobDetails;
  }

  static String _generateDefaultDescription(String jobTitle) {
    return "We are seeking a talented $jobTitle to join our dynamic team. This role offers an exciting opportunity to contribute to innovative projects and grow professionally in a collaborative environment. The ideal candidate will bring fresh perspectives and help drive our mission forward while developing their skills and expertise.";
  }

  static List<String> _generateDefaultResponsibilities(String jobTitle) {
    final baseResponsibilities = [
      'Perform core responsibilities related to $jobTitle',
      'Collaborate with cross-functional teams to achieve project goals',
      'Contribute to planning and execution of key initiatives',
      'Maintain high-quality standards in all deliverables and outputs',
      'Continuously improve processes and methodologies'
    ];

    if (jobTitle.toLowerCase().contains('manager')) {
      baseResponsibilities.insert(
          0, 'Lead and mentor team members to achieve excellence');
      baseResponsibilities.insert(
          1, 'Develop and implement strategic plans and objectives');
    } else if (jobTitle.toLowerCase().contains('developer') ||
        jobTitle.toLowerCase().contains('engineer')) {
      baseResponsibilities.insert(
          0, 'Design, develop, and maintain high-quality software solutions');
      baseResponsibilities.insert(
          1, 'Participate in code reviews and technical discussions');
    } else if (jobTitle.toLowerCase().contains('design')) {
      baseResponsibilities.insert(
          0, 'Create innovative and user-centered design solutions');
      baseResponsibilities.insert(
          1, 'Develop and maintain design systems and guidelines');
    }

    return baseResponsibilities;
  }

  static List<String> _generateDefaultQualifications(String jobTitle) {
    final baseQualifications = [
      'Relevant experience in $jobTitle or similar roles',
      'Strong problem-solving and analytical thinking skills',
      'Excellent communication and collaboration abilities',
      'Ability to adapt to changing priorities and requirements',
      'Commitment to continuous learning and professional growth'
    ];

    if (jobTitle.toLowerCase().contains('manager')) {
      baseQualifications.insert(
          0, 'Proven leadership experience with track record of success');
      baseQualifications.insert(
          1, 'Strong strategic planning and decision-making skills');
    } else if (jobTitle.toLowerCase().contains('developer') ||
        jobTitle.toLowerCase().contains('engineer')) {
      baseQualifications.insert(
          0, 'Proficiency in relevant programming languages and technologies');
      baseQualifications.insert(
          1, 'Strong understanding of software development best practices');
    } else if (jobTitle.toLowerCase().contains('design')) {
      baseQualifications.insert(
          0, 'Strong portfolio demonstrating design expertise and creativity');
      baseQualifications.insert(1, 'Proficiency in design tools and software');
    }

    return baseQualifications;
  }

  static String _determineCategory(String jobTitle) {
    final title = jobTitle.toLowerCase();

    if (title.contains('manager') ||
        title.contains('director') ||
        title.contains('lead')) {
      return 'Management';
    } else if (title.contains('developer') ||
        title.contains('engineer') ||
        title.contains('programmer')) {
      return 'Engineering';
    } else if (title.contains('design') ||
        title.contains('designer') ||
        title.contains('creative')) {
      return 'Design';
    } else if (title.contains('market') ||
        title.contains('marketing') ||
        title.contains('brand')) {
      return 'Marketing';
    } else if (title.contains('sales') ||
        title.contains('business development')) {
      return 'Sales';
    } else if (title.contains('hr') ||
        title.contains('human resources') ||
        title.contains('recruit')) {
      return 'HR';
    } else if (title.contains('finance') ||
        title.contains('account') ||
        title.contains('financial')) {
      return 'Finance';
    } else if (title.contains('data') ||
        title.contains('analyst') ||
        title.contains('analytics')) {
      return 'Data Science';
    } else if (title.contains('product') || title.contains('product manager')) {
      return 'Product';
    } else if (title.contains('customer') ||
        title.contains('support') ||
        title.contains('service')) {
      return 'Customer Service';
    } else if (title.contains('operation') || title.contains('operational')) {
      return 'Operations';
    } else {
      return 'Engineering'; // Default fallback
    }
  }

  static List<String> _generateDefaultSkills(String jobTitle) {
    final baseSkills = [
      'Communication',
      'Teamwork',
      'Problem Solving',
      'Time Management'
    ];

    final title = jobTitle.toLowerCase();
    if (title.contains('manager') || title.contains('director')) {
      baseSkills.addAll([
        'Leadership',
        'Project Management',
        'Strategic Planning',
        'Decision Making'
      ]);
    } else if (title.contains('developer') || title.contains('engineer')) {
      baseSkills.addAll([
        'Programming',
        'Debugging',
        'System Design',
        'Technical Documentation'
      ]);
    } else if (title.contains('design')) {
      baseSkills.addAll(
          ['UI/UX Design', 'Creativity', 'Design Tools', 'User Research']);
    } else if (title.contains('market')) {
      baseSkills.addAll(
          ['Digital Marketing', 'Content Creation', 'Analytics', 'SEO/SEM']);
    } else if (title.contains('sales')) {
      baseSkills.addAll(
          ['Negotiation', 'Customer Relations', 'Sales Strategy', 'CRM']);
    } else if (title.contains('data') || title.contains('analyst')) {
      baseSkills
          .addAll(['Data Analysis', 'Statistics', 'SQL', 'Visualization']);
    } else {
      baseSkills.addAll([
        'Microsoft Office',
        'Research',
        'Critical Thinking',
        'Adaptability'
      ]);
    }

    return baseSkills;
  }

  static Future<List<Map<String, dynamic>>> generateAssessmentQuestions({
    required String jobTitle,
    required String difficulty,
    required int questionCount,
  }) async {
    // Try backend first (uses server-side API keys)
    try {
      final token = await AuthService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        final response = await http.post(
          Uri.parse(ApiEndpoints.generateQuestions),
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
          final questions = data['questions'];
          if (questions is List) {
            return List<Map<String, dynamic>>.from(questions.map(
                (e) => e is Map<String, dynamic> ? e : <String, dynamic>{}));
          }
        }
      }
    } catch (e) {
      print("Backend generateQuestions failed: $e");
    }

    return _getFallbackAssessmentQuestions(jobTitle, difficulty, questionCount);
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

  static Map<String, dynamic> _getFallbackJobDetails(String jobTitle) {
    // Smart fallback based on job title
    String category = 'Engineering';
    List<String> skills = ['Communication', 'Teamwork', 'Problem Solving'];
    int minExp = 2;

    if (jobTitle.toLowerCase().contains('manager')) {
      category = 'Management';
      skills.addAll(['Leadership', 'Project Management', 'Strategic Planning']);
      minExp = 5;
    } else if (jobTitle.toLowerCase().contains('developer') ||
        jobTitle.toLowerCase().contains('engineer')) {
      category = 'Engineering';
      skills.addAll(['Programming', 'Debugging', 'System Design']);
      minExp = 3;
    } else if (jobTitle.toLowerCase().contains('design')) {
      category = 'Design';
      skills.addAll(['UI/UX', 'Creativity', 'Design Tools']);
      minExp = 2;
    } else if (jobTitle.toLowerCase().contains('market')) {
      category = 'Marketing';
      skills.addAll(['Digital Marketing', 'Analytics', 'Content Creation']);
      minExp = 3;
    } else if (jobTitle.toLowerCase().contains('sales')) {
      category = 'Sales';
      skills.addAll(['Negotiation', 'Customer Relations', 'Sales Strategy']);
      minExp = 2;
    }

    return {
      'description':
          'We are looking for a talented $jobTitle to join our dynamic team. This role offers an exciting opportunity to contribute to innovative projects and grow professionally in a collaborative environment.',
      'responsibilities': [
        'Perform core responsibilities related to $jobTitle',
        'Collaborate with cross-functional teams',
        'Contribute to project planning and execution',
        'Maintain high-quality standards in all deliverables',
        'Continuously improve processes and methodologies'
      ],
      'qualifications': [
        'Relevant experience in $jobTitle or similar roles',
        'Strong problem-solving and analytical skills',
        'Excellent communication and teamwork abilities',
        'Ability to adapt to changing priorities',
        'Commitment to continuous learning and growth'
      ],
      'company_details':
          'Our company is a forward-thinking organization that values innovation, collaboration, and employee growth. We offer a supportive environment where talented individuals can thrive and make meaningful contributions.',
      'category': category,
      'required_skills': skills,
      'min_experience': minExp.toString(),
    };
  }
}
