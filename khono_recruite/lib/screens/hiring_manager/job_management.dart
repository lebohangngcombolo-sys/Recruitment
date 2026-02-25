// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/weighting_configuration_widget.dart';
import '../../widgets/knockout_rules_builder.dart';
import '../../services/admin_service.dart';
import '../../services/ai_service.dart';
import '../../services/test_pack_service.dart';
import '../../models/test_pack.dart';
import '../../widgets/save_test_pack_dialog.dart';
import '../../providers/theme_provider.dart';

class JobManagement extends StatefulWidget {
  final Function(int jobId)? onJobSelected;

  const JobManagement({super.key, this.onJobSelected});

  @override
  _JobManagementState createState() => _JobManagementState();
}

class _JobManagementState extends State<JobManagement> {
  final AdminService admin = AdminService();
  List<Map<String, dynamic>> jobs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchJobs();
  }

  Future<void> fetchJobs() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final data = await admin.listJobs();
      if (!mounted) return;
      jobs = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error fetching jobs: $e")));
      }
    }
    if (!mounted) return;
    setState(() => loading = false);
  }

  void openJobForm({Map<String, dynamic>? job}) {
    showDialog(
      context: context,
      builder: (_) => JobFormDialog(job: job, onSaved: fetchJobs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      // 🌆 Dynamic background implementation
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(themeProvider.backgroundImage),
            fit: BoxFit.cover,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.redAccent))
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Job Management",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          CustomButton(
                            text: "Add Job",
                            onPressed: () => openJobForm(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(
                          color: themeProvider.isDarkMode
                              ? Colors.grey.shade800
                              : Colors.grey),
                      const SizedBox(height: 20),

                      // Job List
                      Expanded(
                        child: jobs.isEmpty
                            ? Center(
                                child: Text(
                                  "No jobs available",
                                  style: TextStyle(
                                    color: themeProvider.isDarkMode
                                        ? Colors.grey.shade400
                                        : Colors.black54,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: jobs.length,
                                itemBuilder: (_, index) {
                                  final job = jobs[index];
                                  return Card(
                                    color: (themeProvider.isDarkMode
                                            ? const Color(0xFF14131E)
                                            : Colors.white)
                                        .withOpacity(0.9),
                                    elevation: 3,
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                            color: themeProvider.isDarkMode
                                                ? Colors.grey.shade800
                                                : Colors.grey,
                                            width: 0.3)),
                                    child: ListTile(
                                      title: Text(
                                        job['title'] ?? '',
                                        style: TextStyle(
                                          color: themeProvider.isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 18,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              job['description'] ?? '',
                                              style: TextStyle(
                                                color: themeProvider.isDarkMode
                                                    ? Colors.grey.shade400
                                                    : Colors.black54,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (job['created_by_user'] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4),
                                                child: Text(
                                                  "Created by: ${job['created_by_user']['name'] ?? job['created_by_user']['email'] ?? 'Unknown'}",
                                                  style: TextStyle(
                                                    color: themeProvider
                                                            .isDarkMode
                                                        ? Colors.grey.shade400
                                                        : Colors.black54,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.blueAccent),
                                            onPressed: () =>
                                                openJobForm(job: job),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.redAccent),
                                            onPressed: () async {
                                              try {
                                                await admin.deleteJob(
                                                    job['id'] as int);
                                                fetchJobs();
                                              } catch (e) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                  content: Text(
                                                      "Error deleting job: $e"),
                                                ));
                                              }
                                            },
                                          ),
                                          if (widget.onJobSelected != null)
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.check_circle,
                                                  color: Colors.green),
                                              tooltip: "Select Job",
                                              onPressed: () =>
                                                  widget.onJobSelected!(
                                                      job['id'] as int),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// ---------------- Job + Assessment Form Dialog ----------------
class JobFormDialog extends StatefulWidget {
  final Map<String, dynamic>? job;
  final VoidCallback onSaved;

  const JobFormDialog({super.key, this.job, required this.onSaved});

  @override
  _JobFormDialogState createState() => _JobFormDialogState();
}

class _JobFormDialogState extends State<JobFormDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late String title;
  late String description;
  String jobSummary = "";
  TextEditingController responsibilitiesController = TextEditingController();
  TextEditingController qualificationsController = TextEditingController();
  String companyName = "";
  String jobLocation = "";
  String companyDetails = "";
  String category = "";
  final skillsController = TextEditingController();
  final minExpController = TextEditingController();
  final descriptionController = TextEditingController();
  final categoryController = TextEditingController();
  final companyDetailsController = TextEditingController();
  String salaryCurrency = "ZAR";
  String salaryPeriod = "monthly";
  final TextEditingController salaryMinController = TextEditingController();
  final TextEditingController salaryMaxController = TextEditingController();
  List<Map<String, dynamic>> questions = [];
  int? _testPackId;
  List<TestPack> _testPacks = [];
  bool _useTestPack = false;
  bool _loadingTestPacks = false;
  /// When using a test pack, which questions are selected for cherry-pick (by index).
  List<bool> _cherryPickSelected = [];
  final TestPackService _testPackService = TestPackService();
  Map<String, int> weightings = {
    "cv": 60,
    "assessment": 40,
    "interview": 0,
    "references": 0,
  };
  List<Map<String, dynamic>> knockoutRules = [];
  String employmentType = "full_time";
  String? weightingsError;
  late TabController _tabController;
  final AdminService admin = AdminService();
  bool _isGeneratingWithAI = false;

  @override
  void initState() {
    super.initState();
    title = widget.job?['title'] ?? '';
    description = widget.job?['description'] ?? '';
    descriptionController.text = description;

    salaryCurrency = widget.job?['salary_currency'] ?? 'ZAR';
    salaryMinController.text = (widget.job?['salary_min'] ?? '').toString();
    salaryMaxController.text = (widget.job?['salary_max'] ?? '').toString();
    salaryPeriod = widget.job?['salary_period'] ?? 'monthly';

    // Format existing responsibilities as bullet points
    final existingResponsibilities = widget.job?['responsibilities'] ?? [];
    responsibilitiesController.text =
        existingResponsibilities.map((r) => "• $r").join('\n');

    // Format existing qualifications as bullet points
    final existingQualifications = widget.job?['qualifications'] ?? [];
    qualificationsController.text =
        existingQualifications.map((q) => "• $q").join('\n');

    // Format existing skills as bullet points
    final existingSkills = widget.job?['required_skills'] ?? [];
    skillsController.text = existingSkills.map((s) => "• $s").join('\n');

    minExpController.text = (widget.job?['min_experience'] ?? 0).toString();
    jobSummary = widget.job?['job_summary'] ?? '';
    companyDetails = widget.job?['company_details'] ?? '';
    companyDetailsController.text = companyDetails;
    category = widget.job?['category'] ?? '';
    categoryController.text = category;

    if (widget.job != null &&
        widget.job!['assessment_pack'] != null &&
        widget.job!['assessment_pack']['questions'] != null) {
      questions =
          _normalizeQuestions(widget.job!['assessment_pack']['questions']);
    }
    final tpId = widget.job?['test_pack_id'];
    if (tpId != null && tpId is int) {
      _testPackId = tpId;
      _useTestPack = true;
    }

    // Load weightings (CV %, Assessment %, etc.) and knockout rules when editing
    final rawWeightings = widget.job?['weightings'];
    if (rawWeightings is Map) {
      weightings = {
        "cv": (rawWeightings["cv"] is int) ? rawWeightings["cv"] as int : (rawWeightings["cv"] is num) ? (rawWeightings["cv"] as num).toInt() : 60,
        "assessment": (rawWeightings["assessment"] is int) ? rawWeightings["assessment"] as int : (rawWeightings["assessment"] is num) ? (rawWeightings["assessment"] as num).toInt() : 40,
        "interview": (rawWeightings["interview"] is int) ? rawWeightings["interview"] as int : (rawWeightings["interview"] is num) ? (rawWeightings["interview"] as num).toInt() : 0,
        "references": (rawWeightings["references"] is int) ? rawWeightings["references"] as int : (rawWeightings["references"] is num) ? (rawWeightings["references"] as num).toInt() : 0,
      };
    }
    final rawRules = widget.job?['knockout_rules'];
    if (rawRules is List) {
      knockoutRules = rawRules.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    _tabController = TabController(length: 2, vsync: this);
    _loadTestPacks();
  }

  Future<void> _loadTestPacks() async {
    setState(() => _loadingTestPacks = true);
    try {
      final packs = await _testPackService.getTestPacks();
      if (mounted) setState(() => _testPacks = packs);
    } catch (_) {}
    if (mounted) setState(() => _loadingTestPacks = false);
  }

  Future<void> _saveAsTestPack() async {
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one question first')),
      );
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SaveTestPackDialog(
        initialQuestions: questions,
        initialName: title.trim().isEmpty ? null : '$title Assessment Pack',
      ),
    );
    if (result == null || !mounted) return;
    try {
      final pack = await _testPackService.createTestPack(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test pack "${pack.name}" created')),
      );
      setState(() {
        _testPacks = [..._testPacks, pack];
        _useTestPack = true;
        _testPackId = pack.id;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  /// Build the "Customize questions" (cherry-pick) section when a test pack is selected.
  Widget _buildCherryPickSection(ThemeProvider themeProvider) {
    TestPack? selectedPack;
    for (final p in _testPacks) {
      if (p.id == _testPackId) {
        selectedPack = p;
        break;
      }
    }
    if (selectedPack == null || selectedPack.questions.isEmpty) return const SizedBox.shrink();
    if (_cherryPickSelected.length != selectedPack.questions.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _cherryPickSelected = List.filled(selectedPack!.questions.length, true));
      });
      return const SizedBox.shrink();
    }
    final packQuestions = selectedPack.questions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customize questions',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: themeProvider.isDarkMode ? Colors.grey.shade300 : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Select which questions to use for this job. "Use selected" will copy them as custom questions.',
          style: TextStyle(
            fontSize: 12,
            color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            border: Border.all(color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: packQuestions.length,
            itemBuilder: (_, i) {
              final q = packQuestions[i];
              final text = (q['question_text'] ?? q['question'] ?? '').toString();
              final short = text.length > 60 ? '${text.substring(0, 60)}...' : text;
              return CheckboxListTile(
                value: _cherryPickSelected[i],
                onChanged: (v) => setState(() => _cherryPickSelected[i] = v ?? true),
                title: Text(
                  short,
                  style: TextStyle(
                    fontSize: 13,
                    color: themeProvider.isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _applyCherryPickedQuestions(selectedPack!),
          icon: const Icon(Icons.checklist, size: 18),
          label: const Text('Use selected'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _applyCherryPickedQuestions(TestPack pack) {
    final selected = <Map<String, dynamic>>[];
    for (var i = 0; i < pack.questions.length; i++) {
      if (i < _cherryPickSelected.length && _cherryPickSelected[i]) {
        final q = Map<String, dynamic>.from(pack.questions[i]);
        selected.add({
          'question': q['question_text'] ?? q['question'] ?? '',
          'options': (q['options'] is List)
              ? List<String>.from((q['options'] as List).map((e) => e.toString()))
              : ['', '', '', ''],
          'answer': (q['correct_option'] ?? q['correct_answer'] ?? 0) is num
              ? ((q['correct_option'] ?? q['correct_answer'] ?? 0) as num).toInt()
              : 0,
          'weight': (q['weight'] ?? 1) is num ? (q['weight'] as num).toInt() : 1,
        });
      }
    }
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one question')),
      );
      return;
    }
    setState(() {
      questions = selected;
      _useTestPack = false;
      _testPackId = null;
      _cherryPickSelected = [];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Using ${selected.length} question(s) as custom assessment')),
    );
  }

  @override
  void dispose() {
    responsibilitiesController.dispose();
    qualificationsController.dispose();
    skillsController.dispose();
    minExpController.dispose();
    salaryMinController.dispose();
    salaryMaxController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _normalizeQuestions(dynamic raw) {
    if (raw == null) return [];

    final List<dynamic> items;
    if (raw is List) {
      items = raw;
    } else {
      return [];
    }

    final normalized = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      final optsRaw = map['options'];
      final options = (optsRaw is List)
          ? optsRaw.map((e) => e?.toString() ?? '').toList()
          : <String>['', '', '', ''];
      while (options.length < 4) {
        options.add('');
      }

      normalized.add({
        'question': (map['question'] ?? '').toString(),
        'options': options.take(4).toList(),
        'answer': (map['answer'] ?? map['correct_answer'] ?? 0) is num
            ? ((map['answer'] ?? map['correct_answer'] ?? 0) as num).toInt()
            : 0,
        'weight':
            (map['weight'] ?? 1) is num ? (map['weight'] as num).toInt() : 1,
      });
    }
    return normalized;
  }

  void addQuestion() {
    setState(() {
      questions.add({
        "question": "",
        "options": ["", "", "", ""],
        "answer": 0,
        "weight": 1,
      });
    });
  }

  void _showAIQuestionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AIQuestionDialog(
          jobTitle: title,
          onQuestionsGenerated: (generatedQuestions) {
            setState(() {
              questions.clear();
              questions.addAll(generatedQuestions);
            });
          },
        );
      },
    );
  }

  Future<void> _generateWithAI() async {
    if (title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a job title first")),
      );
      return;
    }

    setState(() => _isGeneratingWithAI = true);

    try {
      // Show initial message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Generating job details with AI..."),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      final jobDetails = await AIService.generateJobDetails(title.trim());

      if (!mounted) return;
      setState(() {
        description = jobDetails['description'] ?? '';
        descriptionController.text = description;

        // Format responsibilities as bullet points
        final responsibilities = jobDetails['responsibilities'] as List? ?? [];
        responsibilitiesController.text =
            responsibilities.map((r) => "• $r").join('\n');

        // Format qualifications as bullet points
        final qualifications = jobDetails['qualifications'] as List? ?? [];
        qualificationsController.text =
            qualifications.map((q) => "• $q").join('\n');

        companyDetails = jobDetails['company_details'] ?? '';
        companyDetailsController.text = companyDetails;

        category = jobDetails['category'] ?? '';
        categoryController.text = category;

        // Format skills as bullet points
        final skills = jobDetails['required_skills'] as List? ?? [];
        skillsController.text = skills.map((s) => "• $s").join('\n');

        minExpController.text = jobDetails['min_experience']?.toString() ?? '0';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Job details generated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      String errorMessage = e.toString();

      // Check if it's a retry-related error
      if (errorMessage.contains('after 3 attempts')) {
        errorMessage =
            "All AI models are currently busy. Using smart template instead.";
      } else if (errorMessage.contains('quota') ||
          errorMessage.contains('rate limit')) {
        errorMessage = "AI quota exceeded. Trying alternative models...";
      } else if (errorMessage.contains('Gemini failed') ||
          errorMessage.contains('OpenRouter failed') ||
          errorMessage.contains('DeepSeek failed')) {
        errorMessage = "Primary AI models unavailable. Using backup system...";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor:
              errorMessage.contains("success") ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingWithAI = false);
    }
  }

  Future<void> saveJob() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final responsibilities = responsibilitiesController.text
        .split("\n")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.startsWith('• ')
            ? e.substring(2)
            : e) // Remove bullet point prefix
        .where((e) => e.isNotEmpty)
        .toList();

    final qualifications = qualificationsController.text
        .split("\n")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.startsWith('• ')
            ? e.substring(2)
            : e) // Remove bullet point prefix
        .where((e) => e.isNotEmpty)
        .toList();

    final skills = skillsController.text
        .split("\n")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.startsWith('• ')
            ? e.substring(2)
            : e) // Remove bullet point prefix
        .where((e) => e.isNotEmpty)
        .toList();

    final normalizedQuestions = _normalizeQuestions(questions);
    final totalWeight = weightings.values.fold<int>(0, (a, b) => a + b);
    if (totalWeight != 100) {
      setState(() => weightingsError = "Weightings must total 100% (current: $totalWeight%)");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Adjust CV and Assessment percentages so they total 100%."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final Map<String, int> adjustedWeightings = Map<String, int>.from(weightings);

    final jobData = <String, dynamic>{
      'title': (title).trim().isEmpty ? 'Untitled Position' : title.trim(),
      'description': () {
        final fromController = descriptionController.text.trim();
        final fromState = description.trim();
        final value = fromController.isNotEmpty ? fromController : fromState;
        return value.isEmpty ? 'No description provided' : value;
      }(),
      'company': companyName.trim(),
      'location': jobLocation.trim(),
      'job_summary': jobSummary.trim(),
      'employment_type': employmentType,
      'responsibilities': responsibilities,
      'qualifications': qualifications,
      'company_details': companyDetails.trim(),
      'salary_min': double.tryParse(salaryMinController.text),
      'salary_max': double.tryParse(salaryMaxController.text),
      'salary_currency': salaryCurrency,
      'salary_period': salaryPeriod,
      'category': category.trim().isEmpty ? 'General' : category.trim(),
      'required_skills': skills,
      'min_experience': double.tryParse(minExpController.text) ?? 0,
      'weightings': adjustedWeightings,
      'knockout_rules': knockoutRules,
      'vacancy': 1,
      'test_pack_id': _useTestPack ? _testPackId : null,
      'assessment_pack': {
        'questions': normalizedQuestions.map((q) {
          return <String, dynamic>{
            "question": q["question"] as String? ?? "",
            "options": q["options"] as List<dynamic>? ?? [],
            "correct_answer": q["answer"],
            "weight": q["weight"] ?? 1
          };
        }).toList()
      },
    };

    try {
      if (widget.job == null) {
        await admin.createJob(jobData);
      } else {
        await admin.updateJob(widget.job!['id'] as int, jobData);
      }
      if (!mounted) return;
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error saving job: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 650,
        height: 800, // Increased height to accommodate expanded fields
        decoration: BoxDecoration(
          color: (themeProvider.isDarkMode
                  ? const Color(0xFF14131E)
                  : Colors.white)
              .withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: "Job Details"),
                Tab(text: "Assessment"),
              ],
              labelColor: Colors.redAccent,
              unselectedLabelColor: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.black54,
              indicatorColor: Colors.redAccent,
              indicatorWeight: 3,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Job Details Form
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    label: "Title",
                                    initialValue: title,
                                    hintText: "Enter job title",
                                    onChanged: (v) => title = v,
                                    validator: (v) => v == null || v.isEmpty
                                        ? "Enter title"
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue),
                                  ),
                                  child: IconButton(
                                    icon: _isGeneratingWithAI
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.blue),
                                            ),
                                          )
                                        : const Icon(Icons.auto_awesome,
                                            color: Colors.blue),
                                    onPressed: _isGeneratingWithAI
                                        ? null
                                        : _generateWithAI,
                                    tooltip: "Generate with AI",
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Description",
                              controller: descriptionController,
                              hintText: "Enter job description",
                              maxLines: 5,
                              expands: false,
                              onChanged: (v) => description = v,
                              validator: (v) => v == null || v.isEmpty
                                  ? "Enter description"
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Responsibilities",
                              controller: responsibilitiesController,
                              hintText: "Comma separated list",
                              maxLines: 4,
                              expands: false,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Qualifications",
                              controller: qualificationsController,
                              hintText: "Comma separated list",
                              maxLines: 4,
                              expands: false,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Company Details",
                              controller: companyDetailsController,
                              hintText: "About the company",
                              maxLines: 4,
                              expands: false,
                              onChanged: (v) => companyDetails = v,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Category",
                              controller: categoryController,
                              hintText: "Engineering, Marketing...",
                              onChanged: (v) => category = v,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Required Skills",
                              controller: skillsController,
                              hintText: "Comma separated skills",
                              maxLines: 3,
                              expands: false,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Minimum Experience (years)",
                              controller: minExpController,
                              inputType: TextInputType.number,
                            ),
                            const SizedBox(height: 24),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Salary",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: themeProvider.isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    label: "Salary Min",
                                    controller: salaryMinController,
                                    inputType: TextInputType.number,
                                    hintText: "e.g. 30000",
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CustomTextField(
                                    label: "Salary Max",
                                    controller: salaryMaxController,
                                    inputType: TextInputType.number,
                                    hintText: "e.g. 45000",
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    label: "Currency",
                                    initialValue: salaryCurrency,
                                    hintText: "ZAR, USD, EUR",
                                    onChanged: (v) {
                                      setState(() {
                                        salaryCurrency =
                                            v.isEmpty ? "ZAR" : v;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: salaryPeriod,
                                    decoration: InputDecoration(
                                      labelText: "Period",
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: "monthly",
                                        child: Text("Per month"),
                                      ),
                                      DropdownMenuItem(
                                        value: "yearly",
                                        child: Text("Per year"),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => salaryPeriod = value);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Evaluation weightings (must total 100%)",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: themeProvider.isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            WeightingConfigurationWidget(
                              weightings: weightings,
                              errorText: weightingsError,
                              onChanged: (updated) {
                                setState(() {
                                  weightings = updated;
                                  final total = updated.values.fold<int>(0, (a, b) => a + b);
                                  weightingsError = total == 100 ? null : "Weightings must total 100%";
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Knockout rules",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: themeProvider.isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            KnockoutRulesBuilder(
                              rules: knockoutRules,
                              onChanged: (updated) {
                                setState(() => knockoutRules = updated);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Assessment Tab
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Assessment source",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Radio<bool>(
                              value: true,
                              groupValue: _useTestPack,
                              onChanged: (v) =>
                                  setState(() => _useTestPack = true),
                              activeColor: Colors.redAccent,
                            ),
                            const Text("Use a test pack"),
                            const SizedBox(width: 24),
                            Radio<bool>(
                              value: false,
                              groupValue: _useTestPack,
                              onChanged: (v) =>
                                  setState(() {
                                    _useTestPack = false;
                                    _testPackId = null;
                                  }),
                              activeColor: Colors.redAccent,
                            ),
                            const Text("Create custom questions"),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_useTestPack) ...[
                          if (_loadingTestPacks)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.redAccent)),
                            )
                          else
                            DropdownButtonFormField<int?>(
                              value: _testPackId,
                              decoration: InputDecoration(
                                labelText: "Select test pack",
                                border: const OutlineInputBorder(),
                                labelStyle: TextStyle(
                                  color: themeProvider.isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.black87,
                                ),
                              ),
                              dropdownColor: themeProvider.isDarkMode
                                  ? const Color(0xFF14131E)
                                  : Colors.white,
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text("None"),
                                ),
                                ..._testPacks.map(
                                  (p) => DropdownMenuItem<int?>(
                                    value: p.id,
                                    child: Text(
                                      "${p.name} (${p.category}) – ${p.questionCount} questions",
                                      style: TextStyle(
                                        color: themeProvider.isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _testPackId = v;
                                  _cherryPickSelected = [];
                                  if (v != null) {
                                    for (final p in _testPacks) {
                                      if (p.id == v) {
                                        _cherryPickSelected =
                                            List.filled(p.questions.length, true);
                                        break;
                                      }
                                    }
                                  }
                                });
                              },
                            ),
                          const SizedBox(height: 16),
                          if (_testPackId != null) ...[
                            _buildCherryPickSection(themeProvider),
                          ],
                        ],
                        if (!_useTestPack) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Assessment Questions",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.psychology,
                                          color: Colors.green),
                                      onPressed: _showAIQuestionDialog,
                                      tooltip: "Generate AI Questions",
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.save_alt,
                                          color: Colors.blue),
                                      onPressed: _saveAsTestPack,
                                      tooltip: "Save as Test Pack",
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView.builder(
                            itemCount: questions.length,
                            itemBuilder: (_, index) {
                              final q = questions[index];
                              return Card(
                                color: (themeProvider.isDarkMode
                                        ? const Color(0xFF14131E)
                                        : Colors.white)
                                    .withOpacity(0.9),
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Question Header
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: Colors.blue
                                                      .withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              "Question ${index + 1}",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.orange
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: Colors.orange
                                                      .withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              "Weight: ${q["weight"] ?? 1}",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Question Field
                                      CustomTextField(
                                        label: "Question",
                                        initialValue: q["question"],
                                        hintText: "Enter your question here",
                                        maxLines: 3,
                                        expands: false,
                                        onChanged: (v) => q["question"] = v,
                                      ),
                                      const SizedBox(height: 16),

                                      // Options Section
                                      Text(
                                        "Answer Options",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: themeProvider.isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ...List.generate(4, (i) {
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: Row(
                                            children: [
                                              // Option Indicator
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: q["answer"] == i
                                                      ? Colors.green.withValues(
                                                          alpha: 0.2)
                                                      : Colors.grey.withValues(
                                                          alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: q["answer"] == i
                                                        ? Colors.green
                                                        : Colors.grey
                                                            .withValues(
                                                                alpha: 0.3),
                                                    width: q["answer"] == i
                                                        ? 2
                                                        : 1,
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    String.fromCharCode(
                                                        65 + i), // A, B, C, D
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: q["answer"] == i
                                                          ? Colors.green
                                                          : Colors
                                                              .grey.shade600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),

                                              // Option Field
                                              Expanded(
                                                child: CustomTextField(
                                                  label:
                                                      "Option ${String.fromCharCode(65 + i)}",
                                                  initialValue: q["options"][i],
                                                  hintText:
                                                      "Enter option ${String.fromCharCode(65 + i)}",
                                                  maxLines: 2,
                                                  expands: false,
                                                  onChanged: (v) =>
                                                      q["options"][i] = v,
                                                ),
                                              ),

                                              // Correct Answer Indicator
                                              IconButton(
                                                onPressed: () => setState(
                                                    () => q["answer"] = i),
                                                icon: Icon(
                                                  q["answer"] == i
                                                      ? Icons.check_circle
                                                      : Icons
                                                          .radio_button_unchecked,
                                                  color: q["answer"] == i
                                                      ? Colors.green
                                                      : Colors.grey.shade400,
                                                ),
                                                tooltip:
                                                    "Mark as correct answer",
                                              ),
                                            ],
                                          ),
                                        );
                                      }),

                                      const SizedBox(height: 16),

                                      // Weight Field
                                      Row(
                                        children: [
                                          Expanded(
                                            child: CustomTextField(
                                              label: "Question Weight",
                                              initialValue:
                                                  q["weight"].toString(),
                                              hintText: "Enter weight (1-10)",
                                              inputType: TextInputType.number,
                                              onChanged: (v) => q["weight"] =
                                                  double.tryParse(v) ?? 1,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.red
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.red
                                                      .withValues(alpha: 0.3)),
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red),
                                              onPressed: () {
                                                setState(() {
                                                  questions.removeAt(index);
                                                });
                                              },
                                              tooltip: "Delete Question",
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        CustomButton(
                            text: "Add Question", onPressed: addQuestion),
                        ],
                      ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CustomButton(text: "Save Job", onPressed: saveJob),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// AI Question Generation Dialog
class AIQuestionDialog extends StatefulWidget {
  final String jobTitle;
  final Function(List<Map<String, dynamic>>) onQuestionsGenerated;

  const AIQuestionDialog({
    super.key,
    required this.jobTitle,
    required this.onQuestionsGenerated,
  });

  @override
  _AIQuestionDialogState createState() => _AIQuestionDialogState();
}

class _AIQuestionDialogState extends State<AIQuestionDialog> {
  final _formKey = GlobalKey<FormState>();
  String difficulty = 'Medium';
  int questionCount = 5;
  bool _isGenerating = false;

  final List<String> difficultyLevels = ['Easy', 'Medium', 'Hard'];
  final List<int> questionCounts = [3, 5, 8, 10];

  Future<void> _generateQuestions() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isGenerating = true);

    try {
      final questions = await AIService.generateAssessmentQuestions(
        jobTitle: widget.jobTitle,
        difficulty: difficulty,
        questionCount: questionCount,
      );

      if (!mounted) return;
      widget.onQuestionsGenerated(questions);
      Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Generated $questionCount questions successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error generating questions: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 450,
        height: 400,
        decoration: BoxDecoration(
          color: (themeProvider.isDarkMode
                  ? const Color(0xFF14131E)
                  : Colors.white)
              .withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.psychology,
                      color: Colors.green,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Generate AI Questions",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Job Title Display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.work, size: 20, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Job: ${widget.jobTitle}",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Difficulty Level
                Text(
                  "Difficulty Level",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: difficulty,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: themeProvider.isDarkMode
                        ? Colors.grey.shade800
                        : Colors.grey.shade100,
                  ),
                  items: difficultyLevels.map((level) {
                    return DropdownMenuItem(
                      value: level,
                      child: Text(level),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => difficulty = value!);
                  },
                ),
                const SizedBox(height: 20),

                // Number of Questions
                Text(
                  "Number of Questions",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: questionCount,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: themeProvider.isDarkMode
                        ? Colors.grey.shade800
                        : Colors.grey.shade100,
                  ),
                  items: questionCounts.map((count) {
                    return DropdownMenuItem(
                      value: count,
                      child: Text("$count questions"),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => questionCount = value!);
                  },
                ),
                const Spacer(),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade400
                                : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isGenerating ? null : _generateQuestions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isGenerating
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text("Generating..."),
                                ],
                              )
                            : Text("Generate Questions"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
