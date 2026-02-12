import 'package:flutter/material.dart';
import '../../services/job_service.dart';

class JobForm extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Function() onSaved;
  final bool isAdminMode;
  final bool asBottomSheet;

  const JobForm({
    super.key,
    this.initialData,
    required this.onSaved,
    this.isAdminMode = false,
    this.asBottomSheet = false,
  });

  @override
  _JobFormState createState() => _JobFormState();
}

class _JobFormState extends State<JobForm> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final JobService _jobService = JobService();

  // Basic Info
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _jobSummaryController = TextEditingController();
  final TextEditingController _companyDetailsController =
      TextEditingController();

  // Classification
  String _category = 'Engineering';
  String _department = 'Technology';
  String _employmentType = 'full_time';
  String _status = 'draft';

  // Experience & Level
  final TextEditingController _minExperienceController =
      TextEditingController();
  String _seniority = 'Mid-Level';

  // Location
  final TextEditingController _locationController = TextEditingController();
  String _locationType = 'On-site';

  // Salary (Admin only)
  final TextEditingController _salaryMinController = TextEditingController();
  final TextEditingController _salaryMaxController = TextEditingController();
  String _currency = 'USD';

  // Dates
  DateTime? _startDateFrom;
  DateTime? _startDateTo;
  bool _startDateFlexible = false;
  DateTime? _applicationDeadline;

  // Numbers
  final TextEditingController _vacancyController =
      TextEditingController(text: '1');
  bool _isActive = true;

  // Skills & Requirements
  List<Map<String, dynamic>> _requiredSkills = [];
  List<Map<String, dynamic>> _preferredSkills = [];
  List<Map<String, dynamic>> _certifications = [];
  final TextEditingController _qualificationsController =
      TextEditingController();
  final TextEditingController _responsibilitiesController =
      TextEditingController();

  // Assessment
  Map<String, double> _weightings = {
    'cv': 40.0,
    'assessment': 30.0,
    'interview': 20.0,
    'references': 10.0,
  };
  List<Map<String, dynamic>> _knockoutRules = [];
  List<Map<String, dynamic>> _assessmentQuestions = [];

  // State
  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: widget.isAdminMode ? 5 : 4, vsync: this);
    _isEditMode = widget.initialData != null;
    _loadInitialData();
  }

  void _loadInitialData() {
    if (widget.initialData != null) {
      final data = widget.initialData!;

      // Basic Info
      _titleController.text = data['title'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _jobSummaryController.text = data['job_summary'] ?? '';
      _companyDetailsController.text = data['company_details'] ?? '';

      // Classification
      _category = data['category'] ?? 'Engineering';
      _department = data['department'] ?? 'Technology';
      _employmentType = data['employment_type'] ?? 'full_time';
      _status = data['status'] ?? 'draft';

      // Experience & Level
      _minExperienceController.text = data['min_experience']?.toString() ?? '0';
      _seniority = data['seniority'] ?? 'Mid-Level';

      // Location
      _locationController.text = data['location'] ?? '';
      _locationType = data['location_type'] ?? 'On-site';

      // Salary
      if (data['salary_range_min'] != null) {
        _salaryMinController.text = data['salary_range_min'].toString();
      }
      if (data['salary_range_max'] != null) {
        _salaryMaxController.text = data['salary_range_max'].toString();
      }
      _currency = data['currency'] ?? 'USD';

      // Dates
      if (data['start_date_from'] != null) {
        _startDateFrom = DateTime.tryParse(data['start_date_from']);
      }
      if (data['start_date_to'] != null) {
        _startDateTo = DateTime.tryParse(data['start_date_to']);
      }
      _startDateFlexible = data['start_date_flexible'] ?? false;
      if (data['application_deadline'] != null) {
        _applicationDeadline = DateTime.tryParse(data['application_deadline']);
      }

      // Numbers
      _vacancyController.text = data['vacancy']?.toString() ?? '1';
      _isActive = data['is_active'] ?? true;

      // Skills & Requirements
      if (data['required_skills'] != null && data['required_skills'] is List) {
        _requiredSkills =
            List<Map<String, dynamic>>.from(data['required_skills']);
      }
      if (data['preferred_skills'] != null &&
          data['preferred_skills'] is List) {
        _preferredSkills =
            List<Map<String, dynamic>>.from(data['preferred_skills']);
      }
      if (data['certifications'] != null && data['certifications'] is List) {
        _certifications =
            List<Map<String, dynamic>>.from(data['certifications']);
      }

      if (data['qualifications'] != null && data['qualifications'] is List) {
        _qualificationsController.text =
            List<String>.from(data['qualifications']).join('\n');
      }

      if (data['responsibilities'] != null &&
          data['responsibilities'] is List) {
        _responsibilitiesController.text =
            List<String>.from(data['responsibilities']).join('\n');
      }

      // Assessment
      if (data['weightings'] != null && data['weightings'] is Map) {
        _weightings = Map<String, double>.from(data['weightings']);
      }
      if (data['knockout_rules'] != null && data['knockout_rules'] is List) {
        _knockoutRules =
            List<Map<String, dynamic>>.from(data['knockout_rules']);
      }
      if (data['assessment_pack'] != null &&
          data['assessment_pack']['questions'] != null &&
          data['assessment_pack']['questions'] is List) {
        _assessmentQuestions = List<Map<String, dynamic>>.from(
            data['assessment_pack']['questions']);
      }
    }
  }

  Future<void> _saveJob() async {
    final formState = _formKey.currentState;
    if (formState == null) return;
    if (!formState.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Build job data
      final jobData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'job_summary': _jobSummaryController.text.trim(),
        'category': _category,
        'department': _department,
        'employment_type': _employmentType,
        'status': _status,
        'min_experience': double.tryParse(_minExperienceController.text) ?? 0.0,
        'seniority': _seniority,
        'location': _locationController.text.trim(),
        'location_type': _locationType,
        'vacancy': int.tryParse(_vacancyController.text) ?? 1,
        'is_active': _isActive,

        // Parse text areas
        'qualifications': _qualificationsController.text
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList(),
        'responsibilities': _responsibilitiesController.text
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList(),

        // Skills
        'required_skills': _requiredSkills,
        'preferred_skills': _preferredSkills,
        'certifications': _certifications,

        // Assessment
        'weightings': _weightings,
        'knockout_rules': _knockoutRules,
        'assessment_pack': {
          'questions': _assessmentQuestions,
        },
      };

      // Add company details
      if (_companyDetailsController.text.isNotEmpty) {
        jobData['company_details'] = _companyDetailsController.text.trim();
      }

      // Add dates
      if (_startDateFrom != null) {
        jobData['start_date_from'] = _startDateFrom!.toIso8601String();
      }
      if (_startDateTo != null) {
        jobData['start_date_to'] = _startDateTo!.toIso8601String();
      }
      jobData['start_date_flexible'] = _startDateFlexible;

      if (_applicationDeadline != null) {
        jobData['application_deadline'] =
            _applicationDeadline!.toIso8601String();
      }

      // Add salary (admin only)
      if (widget.isAdminMode) {
        if (_salaryMinController.text.isNotEmpty) {
          final salaryMin = double.tryParse(_salaryMinController.text);
          if (salaryMin != null) jobData['salary_range_min'] = salaryMin;
        }
        if (_salaryMaxController.text.isNotEmpty) {
          final salaryMax = double.tryParse(_salaryMaxController.text);
          if (salaryMax != null) jobData['salary_range_max'] = salaryMax;
        }
      }

      // API call
      if (_isEditMode) {
        await _jobService.updateJob(widget.initialData!['id'], jobData);
      } else {
        await _jobService.createJob(jobData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode
              ? 'Job updated successfully!'
              : 'Job created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      const Tab(text: 'Basic Info'),
      const Tab(text: 'Requirements'),
      const Tab(text: 'Skills'),
      const Tab(text: 'Assessment'),
      if (widget.isAdminMode) const Tab(text: 'Admin'),
    ];

    final tabViews = <Widget>[
      _buildBasicInfoTab(),
      _buildRequirementsTab(),
      _buildSkillsTab(),
      _buildAssessmentTab(),
      if (widget.isAdminMode) _buildAdminTab(),
    ];

    if (widget.asBottomSheet) {
      return SafeArea(
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditMode ? 'Edit Job' : 'Create New Job',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: tabs,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: tabViews,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveJob,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isEditMode ? 'Save Changes' : 'Save Job'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Job' : 'Create New Job'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: tabViews,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveJob,
        label: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(_isEditMode ? 'Update Job' : 'Create Job'),
        icon: const Icon(Icons.save),
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Job Title *',
                hintText: 'Enter job title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Job title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Enter detailed job description',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Description is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _jobSummaryController,
              decoration: const InputDecoration(
                labelText: 'Job Summary',
                hintText: 'Brief summary of the job',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _category,
                    items: const [
                      'Engineering',
                      'Marketing',
                      'Sales',
                      'HR',
                      'Finance',
                      'Operations',
                      'Technology'
                    ]
                        .map((category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _category = value!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _department,
                    items: const [
                      'Technology',
                      'Sales',
                      'Marketing',
                      'HR',
                      'Finance',
                      'Operations',
                      'Engineering'
                    ]
                        .map((department) => DropdownMenuItem(
                              value: department,
                              child: Text(department),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _department = value!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _companyDetailsController,
              decoration: const InputDecoration(
                labelText: 'Company Details',
                hintText: 'About the company/department',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Employment Type',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _employmentType,
                  items: const [
                    'full_time',
                    'part_time',
                    'contract',
                    'internship'
                  ]
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child:
                                Text(type.replaceAll('_', ' ').toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _employmentType = value!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Seniority Level',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _seniority,
                  items: const [
                    'Junior',
                    'Mid-Level',
                    'Senior',
                    'Lead',
                    'Principal'
                  ]
                      .map((seniority) => DropdownMenuItem(
                            value: seniority,
                            child: Text(seniority),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _seniority = value);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _minExperienceController,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Experience (years)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final exp = double.tryParse(value);
                      if (exp == null || exp < 0) {
                        return 'Enter valid experience';
                      }
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _vacancyController,
                  decoration: const InputDecoration(
                    labelText: 'Number of Vacancies',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final vacancy = int.tryParse(value);
                      if (vacancy == null || vacancy < 1) {
                        return 'Enter valid number';
                      }
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'City, Country',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Location Type',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _locationType,
                  items: const ['On-site', 'Remote', 'Hybrid']
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _locationType = value!),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Dates Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start Dates',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Start From'),
                          subtitle: Text(_startDateFrom != null
                              ? _startDateFrom!.toString().split(' ')[0]
                              : 'Select date'),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDateFrom ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              setState(() => _startDateFrom = date);
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: const Text('Start To'),
                          subtitle: Text(_startDateTo != null
                              ? _startDateTo!.toString().split(' ')[0]
                              : 'Select date'),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDateTo ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              setState(() => _startDateTo = date);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Flexible Start Date'),
                    value: _startDateFlexible,
                    onChanged: (value) =>
                        setState(() => _startDateFlexible = value ?? false),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Application Deadline'),
                    subtitle: Text(_applicationDeadline != null
                        ? _applicationDeadline!.toString().split(' ')[0]
                        : 'Select date'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _applicationDeadline ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() => _applicationDeadline = date);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Skills Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Skills',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addSkill,
                      ),
                    ],
                  ),
                  if (_requiredSkills.isEmpty && _preferredSkills.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No skills added',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    Column(
                      children: [
                        if (_requiredSkills.isNotEmpty) ...[
                          const Text('Required Skills:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ..._requiredSkills
                              .map((skill) => ListTile(
                                    title: Text(skill['name'] ?? ''),
                                    subtitle: Text(skill['description'] ?? ''),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => setState(
                                          () => _requiredSkills.remove(skill)),
                                    ),
                                  ))
                              .toList(),
                        ],
                        if (_preferredSkills.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text('Preferred Skills:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ..._preferredSkills
                              .map((skill) => ListTile(
                                    title: Text(skill['name'] ?? ''),
                                    subtitle: Text(skill['description'] ?? ''),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => setState(
                                          () => _preferredSkills.remove(skill)),
                                    ),
                                  ))
                              .toList(),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Certifications
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Certifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addCertification,
                      ),
                    ],
                  ),
                  if (_certifications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No certifications added',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._certifications.map((cert) {
                      return ListTile(
                        title: Text(cert['name'] ?? ''),
                        subtitle: Text(cert['issuer'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              setState(() => _certifications.remove(cert)),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Qualifications
          TextFormField(
            controller: _qualificationsController,
            decoration: const InputDecoration(
              labelText: 'Qualifications (one per line)',
              hintText:
                  'Bachelor\'s degree in Computer Science\n5+ years of experience\netc.',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
          ),

          const SizedBox(height: 20),

          // Responsibilities
          TextFormField(
            controller: _responsibilitiesController,
            decoration: const InputDecoration(
              labelText: 'Responsibilities (one per line)',
              hintText:
                  'Develop and maintain software applications\nCollaborate with cross-functional teams\netc.',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Weightings Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assessment Weightings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._weightings.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(entry.key.toUpperCase()),
                          ),
                          Expanded(
                            child: Slider(
                              value: entry.value,
                              min: 0,
                              max: 100,
                              divisions: 20,
                              label: '${entry.value.round()}%',
                              onChanged: (value) {
                                setState(() {
                                  _weightings[entry.key] = value;
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            child: Text('${entry.value.round()}%'),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Knockout Rules
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Knockout Rules',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addKnockoutRule,
                      ),
                    ],
                  ),
                  if (_knockoutRules.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No knockout rules added',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._knockoutRules.map((rule) {
                      return ListTile(
                        title: Text(rule['description'] ?? ''),
                        subtitle: Text(rule['condition'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              setState(() => _knockoutRules.remove(rule)),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Assessment Questions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Assessment Questions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addAssessmentQuestion,
                      ),
                    ],
                  ),
                  if (_assessmentQuestions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No assessment questions added',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._assessmentQuestions.map((question) {
                      return ListTile(
                        title: Text(question['question'] ?? ''),
                        subtitle: Text(question['type'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => setState(
                              () => _assessmentQuestions.remove(question)),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Salary Range
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Salary Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _salaryMinController,
                          decoration: const InputDecoration(
                            labelText: 'Minimum Salary',
                            border: OutlineInputBorder(),
                            prefixText: '\$',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _salaryMaxController,
                          decoration: const InputDecoration(
                            labelText: 'Maximum Salary',
                            border: OutlineInputBorder(),
                            prefixText: '\$',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: _currency,
                          items: const ['USD', 'EUR', 'GBP', 'ZAR']
                              .map((currency) => DropdownMenuItem(
                                    value: currency,
                                    child: Text(currency),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _currency = value!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Status & Activation
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Job Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _status,
                    items: const [
                      'draft',
                      'active',
                      'paused',
                      'closed',
                      'archived'
                    ]
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _status = value!),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Active Job'),
                    subtitle:
                        const Text('Job is visible and accepting applications'),
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addSkill() {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final descriptionController = TextEditingController();
        final yearsController = TextEditingController();
        bool isRequired = true;

        return AlertDialog(
          title: const Text('Add Skill'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Skill Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: yearsController,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Years (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (context, setState) {
                    return CheckboxListTile(
                      title: const Text('Required Skill'),
                      value: isRequired,
                      onChanged: (value) =>
                          setState(() => isRequired = value ?? false),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final skill = {
                  'name': nameController.text,
                  'description': descriptionController.text,
                  'min_years': yearsController.text.isNotEmpty
                      ? double.tryParse(yearsController.text)
                      : null,
                  'required': isRequired,
                };

                setState(() {
                  if (isRequired) {
                    _requiredSkills.add(skill);
                  } else {
                    _preferredSkills.add(skill);
                  }
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addCertification() {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final issuerController = TextEditingController();
        final versionController = TextEditingController();

        return AlertDialog(
          title: const Text('Add Certification'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Certification Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: issuerController,
                  decoration: const InputDecoration(
                    labelText: 'Issuing Organization',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: versionController,
                  decoration: const InputDecoration(
                    labelText: 'Version (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _certifications.add({
                    'name': nameController.text,
                    'issuer': issuerController.text,
                    'version': versionController.text.isNotEmpty
                        ? versionController.text
                        : null,
                    'required': false,
                  });
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addKnockoutRule() {
    showDialog(
      context: context,
      builder: (context) {
        final descriptionController = TextEditingController();
        final conditionController = TextEditingController();

        return AlertDialog(
          title: const Text('Add Knockout Rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: conditionController,
                  decoration: const InputDecoration(
                    labelText: 'Condition',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _knockoutRules.add({
                    'description': descriptionController.text,
                    'condition': conditionController.text,
                  });
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addAssessmentQuestion() {
    showDialog(
      context: context,
      builder: (context) {
        final questionController = TextEditingController();
        String questionType = 'multiple_choice';

        return AlertDialog(
          title: const Text('Add Assessment Question'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: questionController,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (context, setState) {
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Question Type',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: questionType,
                      items: const [
                        'multiple_choice',
                        'text',
                        'boolean',
                        'rating'
                      ]
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(
                                    type.replaceAll('_', ' ').toUpperCase()),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => questionType = value!),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _assessmentQuestions.add({
                    'question': questionController.text,
                    'type': questionType,
                  });
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _jobSummaryController.dispose();
    _companyDetailsController.dispose();
    _minExperienceController.dispose();
    _locationController.dispose();
    _salaryMinController.dispose();
    _salaryMaxController.dispose();
    _vacancyController.dispose();
    _qualificationsController.dispose();
    _responsibilitiesController.dispose();
    super.dispose();
  }
}
