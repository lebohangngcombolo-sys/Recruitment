import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_ai/firebase_ai.dart';

class AIService {
  static late GenerativeModel _generativeModel;
  static const String _openRouterApiKey =
      "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";
  static const String _openRouterModel = "openai/gpt-4o-mini";
  static const String _deepseekApiKey = "sk-e2731f1bc9f44e8dba5cfae851a21fd9";

  static void initialize() {
    _generativeModel =
        FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');
  }

  static Future<Map<String, dynamic>> generateJobDetails(
      String jobTitle) async {
    const maxRetries = 2; // Reduced retries since we have multiple models
    const baseDelay = Duration(seconds: 1);

    // Try Gemini first
    try {
      final result = await _tryGemini(jobTitle, maxRetries, baseDelay);
      return _ensureAllFieldsFilled(result, jobTitle);
    } catch (e) {
      print("Gemini failed: $e");
    }

    // Fallback to OpenRouter
    try {
      final result = await _tryOpenRouter(jobTitle, maxRetries, baseDelay);
      return _ensureAllFieldsFilled(result, jobTitle);
    } catch (e) {
      print("OpenRouter failed: $e");
    }

    // Fallback to DeepSeek
    try {
      final result = await _tryDeepSeek(jobTitle, maxRetries, baseDelay);
      return _ensureAllFieldsFilled(result, jobTitle);
    } catch (e) {
      print("DeepSeek failed: $e");
    }

    // If all models fail, return fallback data
    return _getFallbackJobDetails(jobTitle);
  }

  static Map<String, dynamic> _ensureAllFieldsFilled(
      Map<String, dynamic> jobDetails, String jobTitle) {
    // Ensure description is filled
    if (jobDetails['description'] == null ||
        jobDetails['description'].toString().trim().isEmpty) {
      jobDetails['description'] = _generateDefaultDescription(jobTitle);
    }

    // Ensure responsibilities is filled
    if (jobDetails['responsibilities'] == null ||
        (jobDetails['responsibilities'] as List?)?.isEmpty == true) {
      jobDetails['responsibilities'] =
          _generateDefaultResponsibilities(jobTitle);
    }

    // Ensure qualifications is filled
    if (jobDetails['qualifications'] == null ||
        (jobDetails['qualifications'] as List?)?.isEmpty == true) {
      jobDetails['qualifications'] = _generateDefaultQualifications(jobTitle);
    }

    // Ensure category is filled
    if (jobDetails['category'] == null ||
        jobDetails['category'].toString().trim().isEmpty) {
      jobDetails['category'] = _determineCategory(jobTitle);
    }

    // Ensure required_skills is filled
    if (jobDetails['required_skills'] == null ||
        (jobDetails['required_skills'] as List?)?.isEmpty == true) {
      jobDetails['required_skills'] = _generateDefaultSkills(jobTitle);
    }

    // Ensure min_experience is filled
    if (jobDetails['min_experience'] == null ||
        jobDetails['min_experience'].toString().trim().isEmpty) {
      jobDetails['min_experience'] =
          _determineMinExperience(jobTitle).toString();
    }

    // Company details is optional - only fill if completely empty
    if (jobDetails['company_details'] == null ||
        jobDetails['company_details'].toString().trim().isEmpty) {
      jobDetails['company_details'] = ''; // Leave empty as requested
    }

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

  static Future<Map<String, dynamic>> _tryGemini(
      String jobTitle, int maxRetries, Duration baseDelay) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final prompt = '''
        Based on the job title "$jobTitle", generate comprehensive job details in JSON format with the following structure:
        {
          "description": "Detailed job description (2-3 paragraphs) that clearly explains the role, its purpose, and what the candidate will be doing day-to-day",
          "responsibilities": ["List of 5-7 specific, actionable key responsibilities as bullet points"],
          "qualifications": ["List of 5-7 required qualifications including education, experience, and specific skills"],
          "company_details": "Professional company overview (2-3 sentences) that describes the company culture, mission, and what makes it an attractive workplace",
          "category": "One of: Engineering, Marketing, Sales, HR, Finance, Operations, Customer Service, Product, Design, Data Science",
          "required_skills": ["List of 5-8 technical/professional skills that are essential for this role"],
          "min_experience": "Minimum years of experience as a number (0-15+)"
        }
        
        Guidelines:
        - Make the description compelling and detailed
        - Responsibilities should be specific and measurable
        - Qualifications should be realistic but selective
        - Company details should be professional and appealing
        - Choose the most appropriate category
        - Skills should be current and relevant
        - Experience should match the seniority level of the role
        
        Make sure the response is valid JSON and all fields are filled appropriately for the job title.
      ''';

        final response =
            await _generativeModel.generateContent([Content.text(prompt)]);
        final responseText = response.text?.trim();

        if (responseText == null || responseText.isEmpty) {
          throw Exception('Empty response from Gemini');
        }

        // Try to parse JSON response
        try {
          final jsonStart = responseText.indexOf('{');
          final jsonEnd = responseText.lastIndexOf('}') + 1;

          if (jsonStart == -1 || jsonEnd == 0) {
            throw Exception('No JSON found in Gemini response');
          }

          final jsonStr = responseText.substring(jsonStart, jsonEnd);
          final Map<String, dynamic> jobDetails = await _parseJson(jsonStr);

          return jobDetails;
        } catch (e) {
          // Fallback to manual parsing if JSON parsing fails
          return _parseManually(responseText);
        }
      } catch (e) {
        // Check if it's a quota/rate limit error
        final errorMessage = e.toString().toLowerCase();
        final isQuotaError = errorMessage.contains('quota') ||
            errorMessage.contains('rate limit') ||
            errorMessage.contains('too many requests') ||
            errorMessage.contains('resource exhausted');

        if (attempt == maxRetries) {
          throw Exception(
              'Gemini failed after $maxRetries attempts. Last error: $e');
        }

        if (isQuotaError) {
          // Exponential backoff for quota errors
          final delaySeconds = baseDelay.inSeconds * (attempt * attempt);
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        } else {
          // For non-quota errors, don't retry
          throw Exception('Gemini failed: $e');
        }
      }
    }

    throw Exception('Gemini: Unexpected error');
  }

  static Future<Map<String, dynamic>> _tryOpenRouter(
      String jobTitle, int maxRetries, Duration baseDelay) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final prompt = '''
        Based on the job title "$jobTitle", generate comprehensive job details in JSON format with the following structure:
        {
          "description": "Detailed job description (2-3 paragraphs) that clearly explains the role, its purpose, and what the candidate will be doing day-to-day",
          "responsibilities": ["List of 5-7 specific, actionable key responsibilities as bullet points"],
          "qualifications": ["List of 5-7 required qualifications including education, experience, and specific skills"],
          "company_details": "Professional company overview (2-3 sentences) that describes the company culture, mission, and what makes it an attractive workplace",
          "category": "One of: Engineering, Marketing, Sales, HR, Finance, Operations, Customer Service, Product, Design, Data Science",
          "required_skills": ["List of 5-8 technical/professional skills that are essential for this role"],
          "min_experience": "Minimum years of experience as a number (0-15+)"
        }
        
        Guidelines:
        - Make the description compelling and detailed
        - Responsibilities should be specific and measurable
        - Qualifications should be realistic but selective
        - Company details should be professional and appealing
        - Choose the most appropriate category
        - Skills should be current and relevant
        - Experience should match the seniority level of the role
        
        Make sure the response is valid JSON and all fields are filled appropriately for the job title.
      ''';

        final response = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $_openRouterApiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _openRouterModel,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
            'temperature': 0.7,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final responseText = data['choices'][0]['message']['content']?.trim();

          if (responseText == null || responseText.isEmpty) {
            throw Exception('Empty response from OpenRouter');
          }

          // Try to parse JSON response
          try {
            final jsonStart = responseText.indexOf('{');
            final jsonEnd = responseText.lastIndexOf('}') + 1;

            if (jsonStart == -1 || jsonEnd == 0) {
              throw Exception('No JSON found in OpenRouter response');
            }

            final jsonStr = responseText.substring(jsonStart, jsonEnd);
            final Map<String, dynamic> jobDetails = await _parseJson(jsonStr);

            return jobDetails;
          } catch (e) {
            // Fallback to manual parsing if JSON parsing fails
            return _parseManually(responseText);
          }
        } else {
          throw Exception('OpenRouter API error: ${response.statusCode}');
        }
      } catch (e) {
        if (attempt == maxRetries) {
          throw Exception(
              'OpenRouter failed after $maxRetries attempts. Last error: $e');
        }

        // Brief delay before retry
        await Future.delayed(baseDelay);
      }
    }

    throw Exception('OpenRouter: Unexpected error');
  }

  static Future<Map<String, dynamic>> _tryDeepSeek(
      String jobTitle, int maxRetries, Duration baseDelay) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final prompt = '''
        Based on the job title "$jobTitle", generate comprehensive job details in JSON format with the following structure:
        {
          "description": "Detailed job description (2-3 paragraphs) that clearly explains the role, its purpose, and what the candidate will be doing day-to-day",
          "responsibilities": ["List of 5-7 specific, actionable key responsibilities as bullet points"],
          "qualifications": ["List of 5-7 required qualifications including education, experience, and specific skills"],
          "company_details": "Professional company overview (2-3 sentences) that describes the company culture, mission, and what makes it an attractive workplace",
          "category": "One of: Engineering, Marketing, Sales, HR, Finance, Operations, Customer Service, Product, Design, Data Science",
          "required_skills": ["List of 5-8 technical/professional skills that are essential for this role"],
          "min_experience": "Minimum years of experience as a number (0-15+)"
        }
        
        Guidelines:
        - Make the description compelling and detailed
        - Responsibilities should be specific and measurable
        - Qualifications should be realistic but selective
        - Company details should be professional and appealing
        - Choose the most appropriate category
        - Skills should be current and relevant
        - Experience should match the seniority level of the role
        
        Make sure the response is valid JSON and all fields are filled appropriately for the job title.
      ''';

        final response = await http.post(
          Uri.parse('https://api.deepseek.com/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $_deepseekApiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'deepseek-chat',
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
            'temperature': 0.7,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final responseText = data['choices'][0]['message']['content']?.trim();

          if (responseText == null || responseText.isEmpty) {
            throw Exception('Empty response from DeepSeek');
          }

          // Try to parse JSON response
          try {
            final jsonStart = responseText.indexOf('{');
            final jsonEnd = responseText.lastIndexOf('}') + 1;

            if (jsonStart == -1 || jsonEnd == 0) {
              throw Exception('No JSON found in DeepSeek response');
            }

            final jsonStr = responseText.substring(jsonStart, jsonEnd);
            final Map<String, dynamic> jobDetails = await _parseJson(jsonStr);

            return jobDetails;
          } catch (e) {
            // Fallback to manual parsing if JSON parsing fails
            return _parseManually(responseText);
          }
        } else {
          throw Exception('DeepSeek API error: ${response.statusCode}');
        }
      } catch (e) {
        if (attempt == maxRetries) {
          throw Exception(
              'DeepSeek failed after $maxRetries attempts. Last error: $e');
        }

        // Brief delay before retry
        await Future.delayed(baseDelay);
      }
    }

    throw Exception('DeepSeek: Unexpected error');
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

  static Future<Map<String, dynamic>> _parseJson(String jsonStr) async {
    return jsonDecode(jsonStr);
  }

  static Map<String, dynamic> _parseManually(String response) {
    // Fallback parsing method - extract information manually
    final lines = response.split('\n');
    final result = <String, dynamic>{};

    // Default values
    result['description'] =
        'Job description will be generated based on the title.';
    result['responsibilities'] = [
      'Responsibility 1',
      'Responsibility 2',
      'Responsibility 3'
    ];
    result['qualifications'] = [
      'Qualification 1',
      'Qualification 2',
      'Qualification 3'
    ];
    result['company_details'] =
        'We are a dynamic company committed to innovation and excellence. Our team thrives on collaboration and continuous growth.';
    result['category'] = 'Engineering';
    result['required_skills'] = ['Skill 1', 'Skill 2', 'Skill 3'];
    result['min_experience'] = '2';

    // Try to extract some information from the response
    for (final line in lines) {
      if (line.toLowerCase().contains('description')) {
        result['description'] = line.trim();
      } else if (line.toLowerCase().contains('responsibilit')) {
        result['responsibilities'] = [line.trim()];
      } else if (line.toLowerCase().contains('qualification')) {
        result['qualifications'] = [line.trim()];
      } else if (line.toLowerCase().contains('company')) {
        result['company_details'] = line.trim();
      }
    }

    return result;
  }
}
