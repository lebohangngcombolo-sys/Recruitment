import 'dart:core';

/// Comprehensive profile validation service
/// Implements validation logic identified in the detailed analysis
class ProfileValidator {
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.trim().length > 100) {
      return 'Name must be less than 100 characters';
    }
    // Simple validation - check each character
    for (int i = 0; i < value.trim().length; i++) {
      final char = value.trim()[i];
      final isLetter = (char.codeUnitAt(0) >= 65 && char.codeUnitAt(0) <= 90) ||
          (char.codeUnitAt(0) >= 97 && char.codeUnitAt(0) <= 122);
      final isValidChar =
          isLetter || char == ' ' || char == '-' || char == '\'' || char == '.';
      if (!isValidChar) {
        return 'Name can only contain letters, spaces, hyphens, and apostrophes';
      }
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final cleanPhone = value.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    if (!RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(value)) {
      return 'Invalid phone number format';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
      return 'Invalid email format';
    }
    return null;
  }

  static String? validateTitle(String? value) {
    if (value != null && value.trim().isNotEmpty) {
      if (value.trim().length > 100) {
        return 'Title must be less than 100 characters';
      }
      if (!RegExp(r'^[a-zA-Z\s\-\.\,]+$').hasMatch(value.trim())) {
        return 'Title contains invalid characters';
      }
    }
    return null;
  }

  static String? validateBio(String? value) {
    if (value != null && value.trim().isNotEmpty) {
      if (value.trim().length > 500) {
        return 'Bio must be less than 500 characters';
      }
    }
    return null;
  }

  static String? validateLinkedIn(String? value) {
    if (value != null && value.trim().isNotEmpty) {
      final urlPattern = RegExp(
        r'^(https?:\/\/)?(www\.)?linkedin\.com\/in\/[a-zA-Z0-9\-_\/]+$',
        caseSensitive: false,
      );
      if (!urlPattern.hasMatch(value.trim())) {
        return 'Invalid LinkedIn URL format';
      }
    }
    return null;
  }

  static String? validateGitHub(String? value) {
    if (value != null && value.trim().isNotEmpty) {
      final urlPattern = RegExp(
        r'^(https?:\/\/)?(www\.)?github\.com\/[a-zA-Z0-9\-_]+$',
        caseSensitive: false,
      );
      if (!urlPattern.hasMatch(value.trim())) {
        return 'Invalid GitHub URL format';
      }
    }
    return null;
  }

  static String? validatePortfolio(String? value) {
    if (value != null && value.trim().isNotEmpty) {
      final urlPattern = RegExp(
        r'^(https?:\/\/)?(www\.)?[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}(\/.*)?$',
        caseSensitive: false,
      );
      if (!urlPattern.hasMatch(value.trim())) {
        return 'Invalid portfolio URL format';
      }
    }
    return null;
  }

  static Map<String, String?> validateCompleteProfile(
      Map<String, dynamic> profileData) {
    final errors = <String, String?>{};

    // Personal information validation
    errors['full_name'] = validateName(profileData['full_name']);
    errors['phone'] = validatePhone(profileData['phone']);
    errors['email'] = validateEmail(profileData['email']);
    errors['title'] = validateTitle(profileData['title']);
    errors['bio'] = validateBio(profileData['bio']);

    // Social media validation
    errors['linkedin'] = validateLinkedIn(profileData['linkedin']);
    errors['github'] = validateGitHub(profileData['github']);
    errors['portfolio'] = validatePortfolio(profileData['portfolio']);

    // Remove null values (no errors)
    errors.removeWhere((key, value) => value == null);

    return errors;
  }

  static int calculateProfileCompletion(Map<String, dynamic> profileData) {
    int completedFields = 0;
    int totalFields = 10;

    // Essential fields (weighted more)
    if (profileData['full_name']?.toString().trim().isNotEmpty == true)
      completedFields++;
    if (profileData['phone']?.toString().trim().isNotEmpty == true)
      completedFields++;
    if (profileData['email']?.toString().trim().isNotEmpty == true)
      completedFields++;

    // Professional fields
    if (profileData['title']?.toString().trim().isNotEmpty == true)
      completedFields++;
    if (profileData['bio']?.toString().trim().isNotEmpty == true)
      completedFields++;

    // Social profiles
    if (profileData['linkedin']?.toString().trim().isNotEmpty == true)
      completedFields++;
    if (profileData['github']?.toString().trim().isNotEmpty == true)
      completedFields++;
    if (profileData['portfolio']?.toString().trim().isNotEmpty == true)
      completedFields++;

    // Structured data
    if ((profileData['skills'] as List?)?.isNotEmpty == true) completedFields++;
    if ((profileData['education'] as List?)?.isNotEmpty == true)
      completedFields++;

    return ((completedFields / totalFields) * 100).round();
  }
}

/// Advanced skill vs reference detection
/// Implements the intelligent text analysis from the detailed analysis
class SkillReferenceDetector {
  static bool _looksLikeReference(String s) {
    if (s.isEmpty) return true;
    final t = s.trim();
    final lower = t.toLowerCase();

    // Email detection
    if (t.contains('@') && (t.contains('.') || lower.contains('email')))
      return true;

    // Phone number detection (multiple formats)
    if (RegExp(r'\+[\d\s]{10,}').hasMatch(t) ||
        RegExp(r'\d{10,}').hasMatch(t.replaceAll(' ', ''))) return true;

    // Reference keywords
    if (lower.contains('reference') ||
        lower.contains('facilitator') ||
        lower.contains('senior coach')) return true;

    // Website detection
    if (lower.contains('.co.za') ||
        lower.contains('.com') ||
        lower.contains('.co.uk') ||
        lower.contains('.io')) return true;

    // "Name - Organization" pattern
    if (t.contains(' - ') && t.split(' - ').length >= 2) return true;

    // Long text likely a reference
    if (t.length > 70) return true;

    return false;
  }

  static bool _looksLikeSkill(String s) {
    if (s.isEmpty) return false;
    final t = s.trim();

    if (t.length > 50) return false;
    if (t.contains('@') || t.contains(' - ')) return false;
    if (RegExp(r'\+[\d\s]+').hasMatch(t)) return false;
    if (t.toLowerCase().contains('reference') ||
        t.toLowerCase().contains('.co.za') ||
        t.toLowerCase().contains('.com') ||
        t.toLowerCase().contains('.io')) return false;

    return true;
  }

  static Map<String, List<String>> categorizeSkillsAndReferences(
      List<String> items) {
    final skills = <String>[];
    final references = <String>[];

    for (String item in items) {
      if (_looksLikeSkill(item)) {
        skills.add(item);
      } else if (_looksLikeReference(item)) {
        references.add(item);
      } else {
        // Default to skill if unsure
        skills.add(item);
      }
    }

    return {
      'skills': skills,
      'references': references,
    };
  }
}

/// Education parsing service
/// Implements the multi-format education parsing from the analysis
class EducationParser {
  static const List<String> _institutionKeywords = [
    'academy',
    'university',
    'universities',
    'college',
    'school',
    'institute',
    'campus',
    'polytechnic',
    'varsity',
    'faculty',
    'department of ',
    'high school',
    'secondary school',
  ];

  static const List<String> _programmeKeywords = [
    'java',
    'matric',
    'bsc',
    'bsc.',
    'ba',
    'ba.',
    'bcom',
    'beng',
    'btech',
    'mbchb',
    'llb',
    'certificate',
    'diploma',
    'degree',
    'aws',
    'python',
    'javascript',
    'cloud practitioner',
    'national diploma',
    'higher certificate',
    'nqf',
    'honours',
    'masters',
    'phd',
    'mba',
  ];

  static bool _looksLikeInstitutionName(String text) {
    if (text.isEmpty) return false;
    final lower = text.trim().toLowerCase();

    return _institutionKeywords.any((k) => lower.contains(k));
  }

  static List<String>? _splitInstitutionAndProgramme(String text) {
    final t = text.trim();
    if (t.isEmpty || !_looksLikeInstitutionName(t)) return null;

    // Find programme keywords
    for (String keyword in _programmeKeywords) {
      final idx = t.toLowerCase().indexOf(keyword);
      if (idx != -1) {
        final institution = t.substring(0, idx).trim();
        final programme = t.substring(idx).trim();
        if (institution.isNotEmpty && programme.isNotEmpty) {
          return [institution, programme];
        }
      }
    }

    return null;
  }

  static List<Map<String, String>> parseEducationString(String raw) {
    String text = raw.trim();
    if (text.isEmpty) return [];

    final list = <Map<String, String>>[];

    // Format 1: Institution - Degree - Year
    final dashPattern = RegExp(r'(.+?)\s*-\s*(.+?)\s*-\s*(\d{4})');
    final dashMatch = dashPattern.firstMatch(text);
    if (dashMatch != null) {
      list.add({
        'institution': dashMatch.group(1)!.trim(),
        'degree': dashMatch.group(2)!.trim(),
        'graduation_year': dashMatch.group(3)!.trim(),
      });
      return list;
    }

    // Format 2: Institution, Degree, Year
    final commaPattern = RegExp(r'(.+?),\s*(.+?),\s*(\d{4})');
    final commaMatch = commaPattern.firstMatch(text);
    if (commaMatch != null) {
      list.add({
        'institution': commaMatch.group(1)!.trim(),
        'degree': commaMatch.group(2)!.trim(),
        'graduation_year': commaMatch.group(3)!.trim(),
      });
      return list;
    }

    // Format 3: Degree (Year) at Institution
    final atPattern = RegExp(r'(.+?)\s*\((\d{4})\)\s*at\s*(.+)');
    final atMatch = atPattern.firstMatch(text);
    if (atMatch != null) {
      list.add({
        'degree': atMatch.group(1)!.trim(),
        'graduation_year': atMatch.group(2)!.trim(),
        'institution': atMatch.group(3)!.trim(),
      });
      return list;
    }

    // Try to split institution and programme
    final splitResult = _splitInstitutionAndProgramme(text);
    if (splitResult != null) {
      list.add({
        'institution': splitResult[0],
        'degree': splitResult[1],
        'graduation_year': '',
      });
      return list;
    }

    // Fallback: treat entire string as degree
    list.add({
      'degree': text,
      'institution': '',
      'graduation_year': '',
    });

    return list;
  }

  static List<Map<String, String>> parseMultiLineEducation(String raw) {
    String text = raw.trim();
    if (text.isEmpty) return [];

    // Normalize literal \n to real newlines
    text = text.replaceAll(r'\n', '\n').replaceAll('\\n', '\n');

    if (text.contains('\n')) {
      final list = <Map<String, String>>[];
      for (final line in text.split('\n')) {
        final t = line.trim();
        if (t.isEmpty) continue;
        list.addAll(parseEducationString(t));
      }
      return list;
    }

    return parseEducationString(text);
  }
}

/// Profile analytics service
/// Implements user interaction tracking from the analysis
class ProfileAnalytics {
  static void trackProfileEdit(String field, String action) {
    // Implementation would integrate with analytics service
    print('Profile edit tracked: $field - $action');
    // AnalyticsService.track('profile_edit', {
    //   'field': field,
    //   'action': action,
    //   'timestamp': DateTime.now().toIso8601String(),
    // });
  }

  static void trackSectionCompletion(String section, int timeSpent) {
    print('Section completed: $section - ${timeSpent}s');
    // AnalyticsService.track('profile_section_completed', {
    //   'section': section,
    //   'time_spent_seconds': timeSpent,
    //   'completion_percentage': _getCompletionPercentage(),
    // });
  }

  static void trackDocumentUpload(String documentType, int fileSize) {
    print('Document uploaded: $documentType - ${fileSize} bytes');
    // AnalyticsService.track('document_upload', {
    //   'document_type': documentType,
    //   'file_size_bytes': fileSize,
    //   'upload_success': true,
    // });
  }

  static void trackProfileCompletion(Map<String, dynamic> profileData) {
    final completionPercentage = _calculateProfileCompletion(profileData);
    final completedSections = _getCompletedSections(profileData);
    final totalSections = _getTotalSections();

    print('Profile completion: $completionPercentage%');
    print('Completed sections: ${completedSections.length}/$totalSections');

    // AnalyticsService.track('profile_completion', {
    //   'completion_percentage': completionPercentage,
    //   'completed_sections': completedSections,
    //   'total_sections': totalSections,
    // });
  }

  static int _calculateProfileCompletion(Map<String, dynamic> profileData) {
    return ProfileValidator.calculateProfileCompletion(profileData);
  }

  static List<String> _getCompletedSections(Map<String, dynamic> profileData) {
    final completedSections = <String>[];

    // Check personal information section
    if (profileData['full_name']?.toString().trim().isNotEmpty == true &&
        profileData['phone']?.toString().trim().isNotEmpty == true &&
        profileData['email']?.toString().trim().isNotEmpty == true) {
      completedSections.add('personal');
    }

    // Check professional section
    if (profileData['title']?.toString().trim().isNotEmpty == true ||
        profileData['bio']?.toString().trim().isNotEmpty == true) {
      completedSections.add('professional');
    }

    // Check social profiles section
    if (profileData['linkedin']?.toString().trim().isNotEmpty == true ||
        profileData['github']?.toString().trim().isNotEmpty == true ||
        profileData['portfolio']?.toString().trim().isNotEmpty == true) {
      completedSections.add('social');
    }

    // Check education section
    if ((profileData['education'] as List?)?.isNotEmpty == true) {
      completedSections.add('education');
    }

    // Check skills section
    if ((profileData['skills'] as List?)?.isNotEmpty == true) {
      completedSections.add('skills');
    }

    // Check work experience section
    if ((profileData['work_experience'] as List?)?.isNotEmpty == true) {
      completedSections.add('experience');
    }

    return completedSections;
  }

  static int _getTotalSections() {
    return 6; // personal, professional, social, education, skills, experience
  }
}
