import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';

class AIService {
  static late GenerativeModel _generativeModel;

  static void initialize() {
    _generativeModel =
        FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');
  }

  static Future<Map<String, dynamic>> generateJobDetails(
      String jobTitle) async {
    const maxRetries = 3;
    const baseDelay = Duration(seconds: 2);

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
          throw Exception('Empty response from AI');
        }

        // Try to parse JSON response
        try {
          // Extract JSON from response if it contains extra text
          final jsonStart = responseText.indexOf('{');
          final jsonEnd = responseText.lastIndexOf('}') + 1;

          if (jsonStart == -1 || jsonEnd == 0) {
            throw Exception('No JSON found in response');
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
          // Last attempt failed, throw the exception
          throw Exception(
              'Failed to generate job details after $maxRetries attempts. Last error: $e');
        }

        if (isQuotaError) {
          // Exponential backoff for quota errors
          final delaySeconds = baseDelay.inSeconds * (attempt * attempt);
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        } else {
          // For non-quota errors, don't retry
          throw Exception('Failed to generate job details: $e');
        }
      }
    }

    throw Exception('Unexpected error in generateJobDetails');
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
