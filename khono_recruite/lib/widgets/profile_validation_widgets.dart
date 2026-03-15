import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/profile_validator.dart';

/// Profile validation widget that shows real-time validation feedback
class ProfileValidationWidget extends StatefulWidget {
  final Map<String, dynamic> profileData;
  final Function(Map<String, dynamic>) onDataChanged;
  final Function(bool) onValidationChanged;

  const ProfileValidationWidget({
    Key? key,
    required this.profileData,
    required this.onDataChanged,
    required this.onValidationChanged,
  }) : super(key: key);

  @override
  _ProfileValidationWidgetState createState() =>
      _ProfileValidationWidgetState();
}

class _ProfileValidationWidgetState extends State<ProfileValidationWidget> {
  Map<String, String?> _validationErrors = {};
  int _completionPercentage = 0;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _validateProfile();
  }

  @override
  void didUpdateWidget(ProfileValidationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileData != widget.profileData) {
      _validateProfile();
    }
  }

  void _validateProfile() {
    setState(() {
      _validationErrors =
          ProfileValidator.validateCompleteProfile(widget.profileData);
      _completionPercentage =
          ProfileValidator.calculateProfileCompletion(widget.profileData);
      _isValid = _validationErrors.isEmpty;
    });

    widget.onValidationChanged(_isValid);

    // Track profile completion analytics
    ProfileAnalytics.trackProfileCompletion(widget.profileData);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCompletionIndicator(),
        if (!_isValid) _buildValidationErrors(),
        _buildFormFields(),
      ],
    );
  }

  Widget _buildCompletionIndicator() {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile Completion',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[900],
                ),
              ),
              Text(
                '$_completionPercentage%',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _completionPercentage >= 80
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: _completionPercentage / 100,
            backgroundColor: Colors.blue[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              _completionPercentage >= 80 ? Colors.green : Colors.orange,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _getCompletionMessage(),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  String _getCompletionMessage() {
    if (_completionPercentage >= 80) {
      return 'Excellent! Your profile is nearly complete.';
    } else if (_completionPercentage >= 60) {
      return 'Good progress! Add a few more details to complete your profile.';
    } else if (_completionPercentage >= 40) {
      return 'Getting started! Add your essential information to improve visibility.';
    } else {
      return 'Complete your profile to increase your chances of being noticed.';
    }
  }

  Widget _buildValidationErrors() {
    if (_validationErrors.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[600], size: 20),
              SizedBox(width: 8),
              Text(
                'Please fix the following errors:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ..._validationErrors.entries
              .map((entry) => Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.circle, size: 6, color: Colors.red[600]),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.value!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildTextField(
          'Full Name',
          'full_name',
          'Enter your full name',
          Icons.person,
        ),
        _buildTextField(
          'Phone',
          'phone',
          '+27810256782',
          Icons.phone,
          keyboardType: TextInputType.phone,
        ),
        _buildTextField(
          'Email',
          'email',
          'your.email@example.com',
          Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        _buildTextField(
          'Professional Title',
          'title',
          'Senior Software Engineer',
          Icons.work,
        ),
        _buildTextField(
          'Bio',
          'bio',
          'Tell us about yourself...',
          Icons.info_outline,
          maxLines: 3,
        ),
        _buildTextField(
          'LinkedIn',
          'linkedin',
          'https://linkedin.com/in/yourprofile',
          Icons.link,
          keyboardType: TextInputType.url,
        ),
        _buildTextField(
          'GitHub',
          'github',
          'https://github.com/yourusername',
          Icons.code,
          keyboardType: TextInputType.url,
        ),
        _buildTextField(
          'Portfolio',
          'portfolio',
          'https://yourportfolio.com',
          Icons.web,
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    String key,
    String hintText,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final controller = TextEditingController(
      text: widget.profileData[key]?.toString() ?? '',
    );

    final hasError = _validationErrors.containsKey(key);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Icon(icon, color: hasError ? Colors.red : Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: hasError ? Colors.red : Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: hasError ? Colors.red : Colors.blue),
          ),
          errorText: hasError ? _validationErrors[key] : null,
          errorStyle: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.red,
          ),
          labelStyle: GoogleFonts.inter(
            color: hasError ? Colors.red : Colors.grey[600],
          ),
        ),
        style: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.black87,
        ),
        onChanged: (value) {
          final updatedData = Map<String, dynamic>.from(widget.profileData);
          updatedData[key] = value;
          widget.onDataChanged(updatedData);
        },
      ),
    );
  }
}

/// Skills and references categorization widget
class SkillsCategorizationWidget extends StatefulWidget {
  final List<String> items;
  final Function(List<String>, List<String>) onCategorized;

  const SkillsCategorizationWidget({
    Key? key,
    required this.items,
    required this.onCategorized,
  }) : super(key: key);

  @override
  _SkillsCategorizationWidgetState createState() =>
      _SkillsCategorizationWidgetState();
}

class _SkillsCategorizationWidgetState
    extends State<SkillsCategorizationWidget> {
  List<String> _skills = [];
  List<String> _references = [];

  @override
  void initState() {
    super.initState();
    _categorizeItems();
  }

  @override
  void didUpdateWidget(SkillsCategorizationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _categorizeItems();
    }
  }

  void _categorizeItems() {
    final result =
        SkillReferenceDetector.categorizeSkillsAndReferences(widget.items);
    setState(() {
      _skills = result['skills'] ?? [];
      _references = result['references'] ?? [];
    });
    widget.onCategorized(_skills, _references);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Skills & References',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          if (_skills.isNotEmpty) ...[
            _buildSection('Skills', _skills, Colors.blue),
            SizedBox(height: 16),
          ],
          if (_references.isNotEmpty) ...[
            _buildSection('References', _references, Colors.green),
          ],
          if (_skills.isEmpty && _references.isEmpty)
            Text(
              'No items to categorize',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              title == 'Skills' ? Icons.psychology : Icons.people,
              size: 16,
              color: color,
            ),
            SizedBox(width: 8),
            Text(
              '$title (${items.length})',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: items
              .map((item) => Chip(
                    label: Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: color.withOpacity(0.7),
                      ),
                    ),
                    backgroundColor: color.withOpacity(0.1),
                    side: BorderSide(color: color.withOpacity(0.2)),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

/// Education parsing widget
class EducationParsingWidget extends StatefulWidget {
  final String educationText;
  final Function(List<Map<String, String>>) onParsed;

  const EducationParsingWidget({
    Key? key,
    required this.educationText,
    required this.onParsed,
  }) : super(key: key);

  @override
  _EducationParsingWidgetState createState() => _EducationParsingWidgetState();
}

class _EducationParsingWidgetState extends State<EducationParsingWidget> {
  List<Map<String, String>> _parsedEducation = [];

  @override
  void initState() {
    super.initState();
    _parseEducation();
  }

  @override
  void didUpdateWidget(EducationParsingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.educationText != widget.educationText) {
      _parseEducation();
    }
  }

  void _parseEducation() {
    final parsed =
        EducationParser.parseMultiLineEducation(widget.educationText);
    setState(() {
      _parsedEducation = parsed;
    });
    widget.onParsed(_parsedEducation);
  }

  @override
  Widget build(BuildContext context) {
    if (_parsedEducation.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: Colors.green[600], size: 20),
              SizedBox(width: 8),
              Text(
                'Parsed Education (${_parsedEducation.length})',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ..._parsedEducation
              .map((education) => Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[100]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (education['degree']?.isNotEmpty == true) ...[
                          Text(
                            education['degree']!,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                        ],
                        if (education['institution']?.isNotEmpty == true) ...[
                          Text(
                            education['institution']!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 4),
                        ],
                        if (education['graduation_year']?.isNotEmpty == true)
                          Text(
                            'Class of ${education['graduation_year']}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.green[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }
}
