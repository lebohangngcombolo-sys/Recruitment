import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin_service.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/themed_dialog.dart';

/// Job creation dialog component
class JobCreateDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onJobCreated;

  const JobCreateDialog({
    super.key,
    required this.onJobCreated,
  });

  @override
  _JobCreateDialogState createState() => _JobCreateDialogState();
}

class _JobCreateDialogState extends State<JobCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final AdminService _adminService = AdminService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _requirementsController = TextEditingController();
  final TextEditingController _vacancyController =
      TextEditingController(text: '1');
  final TextEditingController _minExperienceController =
      TextEditingController(text: '0');
  final TextEditingController _maxExperienceController =
      TextEditingController(text: '10');
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String _selectedCategory = 'Engineering';
  String _selectedType = 'Full-time';
  String _selectedLevel = 'Mid-level';
  bool _isRemote = false;
  bool _isActive = true;

  bool _isLoading = false;
  int _currentStep = 0;

  // Advanced settings
  List<Map<String, dynamic>> _knockoutRules = [];
  Map<String, double> _weightingConfiguration = {};

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    _vacancyController.dispose();
    _minExperienceController.dispose();
    _maxExperienceController.dispose();
    _salaryController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ThemedDialog(
      title: 'Create New Job',
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Stepper
              _buildStepper(themeProvider),
              const SizedBox(height: 24),

              // Content based on current step
              Expanded(
                child: _buildStepContent(themeProvider),
              ),

              // Actions
              _buildActions(themeProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper(ThemeProvider themeProvider) {
    return Row(
      children: List.generate(3, (index) {
        final isCompleted = index < _currentStep;
        final isCurrent = index == _currentStep;

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFFC10D00)
                      : isCurrent
                          ? const Color(0xFFC10D00).withValues(alpha: 0.8)
                          : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                isCurrent ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                ),
              ),
              if (index < 2) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted
                        ? const Color(0xFFC10D00)
                        : Colors.grey.shade300,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStepContent(ThemeProvider themeProvider) {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfo(themeProvider);
      case 1:
        return _buildJobDetails(themeProvider);
      case 2:
        return _buildAdvancedSettings(themeProvider);
      default:
        return Container();
    }
  }

  Widget _buildBasicInfo(ThemeProvider themeProvider) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Job Title',
              border: OutlineInputBorder(),
              errorText: _titleController.text.isEmpty
                  ? 'Please enter a job title'
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Job Description',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _requirementsController,
            decoration: InputDecoration(
              labelText: 'Requirements (one per line)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _vacancyController,
                  decoration: InputDecoration(
                    labelText: 'Vacancies',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _salaryController,
                  decoration: InputDecoration(
                    labelText: 'Salary Range',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _locationController,
            decoration: InputDecoration(
              labelText: 'Location',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobDetails(ThemeProvider themeProvider) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Job Details',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Category selection
          Text(
            'Category',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: [
              'Engineering',
              'Marketing',
              'Sales',
              'HR',
              'Finance',
              'Operations',
            ].map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedCategory = value!);
            },
          ),
          const SizedBox(height: 16),

          // Type selection
          Text(
            'Employment Type',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: [
              'Full-time',
              'Part-time',
              'Contract',
              'Internship',
            ].map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedType = value!);
            },
          ),
          const SizedBox(height: 16),

          // Level selection
          Text(
            'Experience Level',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedLevel,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: [
              'Entry-level',
              'Mid-level',
              'Senior',
              'Lead',
              'Manager',
            ].map((level) {
              return DropdownMenuItem(
                value: level,
                child: Text(level),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedLevel = value!);
            },
          ),
          const SizedBox(height: 16),

          // Experience range
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minExperienceController,
                  decoration: InputDecoration(
                    labelText: 'Min Experience (years)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _maxExperienceController,
                  decoration: InputDecoration(
                    labelText: 'Max Experience (years)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Remote option
          CheckboxListTile(
            title: Text(
              'Remote Work Available',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            value: _isRemote,
            onChanged: (value) {
              setState(() => _isRemote = value!);
            },
          ),

          // Active status
          CheckboxListTile(
            title: Text(
              'Active (Published)',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            value: _isActive,
            onChanged: (value) {
              setState(() => _isActive = value!);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettings(ThemeProvider themeProvider) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advanced Settings',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Knockout Rules',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Advanced knockout rules configuration coming soon...',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weighting Configuration',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Advanced weighting configuration coming soon...',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ThemeProvider themeProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Previous button
        if (_currentStep > 0)
          ElevatedButton(
            onPressed: () {
              setState(() => _currentStep--);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: const Color(0xFFC10D00),
              side: const BorderSide(color: Color(0xFFC10D00)),
            ),
            child: Text('Previous'),
          )
        else
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: const Color(0xFFC10D00),
              side: const BorderSide(color: Color(0xFFC10D00)),
            ),
            child: Text('Cancel'),
          ),

        // Next/Create button
        if (_currentStep < 2)
          ElevatedButton(
            onPressed: _validateAndNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC10D00),
              foregroundColor: Colors.white,
            ),
            child: Text('Next'),
          )
        else
          ElevatedButton(
            onPressed: _isLoading ? null : _createJob,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC10D00),
              foregroundColor: Colors.white,
            ),
            child: Text(_isLoading ? 'Creating...' : 'Create Job'),
          ),
      ],
    );
  }

  void _validateAndNext() {
    if (_currentStep == 0) {
      if (_formKey.currentState!.validate()) {
        setState(() => _currentStep++);
      }
    } else {
      setState(() => _currentStep++);
    }
  }

  Future<void> _createJob() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final jobData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'requirements': _requirementsController.text
            .split('\n')
            .where((r) => r.isNotEmpty)
            .toList(),
        'vacancy': int.parse(_vacancyController.text),
        'salary_range': _salaryController.text,
        'location': _locationController.text,
        'category': _selectedCategory,
        'type': _selectedType,
        'level': _selectedLevel,
        'min_experience': int.parse(_minExperienceController.text),
        'max_experience': int.parse(_maxExperienceController.text),
        'is_remote': _isRemote,
        'status': _isActive ? 'active' : 'inactive',
        'knockout_rules': _knockoutRules,
        'weighting_configuration': _weightingConfiguration,
      };

      final createdJob = await _adminService.createJob(jobData);
      widget.onJobCreated(createdJob);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Job "${createdJob['title']}" created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create job: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
