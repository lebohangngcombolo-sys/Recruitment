import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart';

/// Dialog for submitting interview feedback
class FeedbackDialog extends StatefulWidget {
  final int interviewId;
  final double? overallRating;
  final String? recommendation;

  const FeedbackDialog({
    super.key,
    required this.interviewId,
    this.overallRating,
    this.recommendation,
  });

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final AdminService _adminService = AdminService();
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _ratingController = TextEditingController();

  bool _isSubmitting = false;
  String _selectedRecommendation = 'consider';
  List<String> _selectedStrengths = [];
  List<String> _selectedAreasForImprovement = [];

  @override
  void initState() {
    super.initState();
    _selectedRecommendation = widget.recommendation ?? 'consider';
    if (widget.overallRating != null) {
      _ratingController.text = widget.overallRating.toString();
    }
  }

  final List<String> _recommendations = [
    'strong_hire',
    'hire',
    'consider',
    'not_suitable',
  ];

  final List<String> _strengths = [
    'Technical Skills',
    'Communication',
    'Problem Solving',
    'Teamwork',
    'Leadership',
    'Adaptability',
    'Time Management',
    'Attention to Detail',
  ];

  final List<String> _areasForImprovement = [
    'Technical Knowledge',
    'Communication Skills',
    'Problem Solving',
    'Team Collaboration',
    'Leadership Skills',
    'Time Management',
    'Attention to Detail',
    'Industry Knowledge',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  String _getRecommendationLabel(String value) {
    switch (value) {
      case 'strong_hire':
        return 'Strong Hire';
      case 'hire':
        return 'Hire';
      case 'consider':
        return 'Consider';
      case 'not_suitable':
        return 'Not Suitable';
      default:
        return value;
    }
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await _adminService.submitInterviewFeedback(
        interviewId: widget.interviewId,
        overallRating: int.tryParse(_ratingController.text) ?? 0,
        recommendation: _selectedRecommendation,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade800
                    : const Color(0xFFF8F9FA),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.rate_review,
                    color: const Color(0xFFC10D00),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Interview Feedback',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating
                      _buildSection(
                        title: 'Overall Rating',
                        child: TextFormField(
                          controller: _ratingController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Rating (0-10)',
                            hintText: 'Enter rating from 0 to 10',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: themeProvider.isDarkMode
                                ? Colors.grey.shade800
                                : Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a rating';
                            }
                            final rating = double.tryParse(value);
                            if (rating == null || rating < 0 || rating > 10) {
                              return 'Rating must be between 0 and 10';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Recommendation
                      _buildSection(
                        title: 'Recommendation',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _recommendations.map((recommendation) {
                            return RadioListTile<String>(
                              title:
                                  Text(_getRecommendationLabel(recommendation)),
                              value: recommendation,
                              groupValue: _selectedRecommendation,
                              onChanged: (value) {
                                setState(
                                    () => _selectedRecommendation = value!);
                              },
                              activeColor: const Color(0xFFC10D00),
                              contentPadding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Strengths
                      _buildSection(
                        title: 'Strengths',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _strengths.map((strength) {
                            final isSelected =
                                _selectedStrengths.contains(strength);
                            return FilterChip(
                              label: Text(strength),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedStrengths.add(strength);
                                  } else {
                                    _selectedStrengths.remove(strength);
                                  }
                                });
                              },
                              backgroundColor: themeProvider.isDarkMode
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                              selectedColor:
                                  const Color(0xFFC10D00).withOpacity(0.2),
                              checkmarkColor: const Color(0xFFC10D00),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Areas for Improvement
                      _buildSection(
                        title: 'Areas for Improvement',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _areasForImprovement.map((area) {
                            final isSelected =
                                _selectedAreasForImprovement.contains(area);
                            return FilterChip(
                              label: Text(area),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedAreasForImprovement.add(area);
                                  } else {
                                    _selectedAreasForImprovement.remove(area);
                                  }
                                });
                              },
                              backgroundColor: themeProvider.isDarkMode
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                              selectedColor: Colors.orange.withOpacity(0.2),
                              checkmarkColor: Colors.orange,
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Notes
                      _buildSection(
                        title: 'Additional Notes',
                        child: TextFormField(
                          controller: _notesController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Notes',
                            hintText:
                                'Enter any additional feedback or comments...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: themeProvider.isDarkMode
                                ? Colors.grey.shade800
                                : Colors.white,
                          ),
                          validator: (value) {
                            if (value != null && value.length > 1000) {
                              return 'Notes must be less than 1000 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade900
                    : Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC10D00),
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Submit Feedback'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
