import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/knockout_rules_builder.dart';
import '../../widgets/weighting_configuration_widget.dart';
import '../../services/admin_service.dart';
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
    setState(() => loading = true);
    try {
      final data = await admin.listJobs();
      jobs = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error fetching jobs: $e")));
    }
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
  final salaryMinController = TextEditingController();
  final salaryMaxController = TextEditingController();
  String salaryCurrency = "ZAR";
  String salaryPeriod = "monthly";
  List<Map<String, dynamic>> questions = [];
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

  @override
  void initState() {
    super.initState();
    title = widget.job?['title'] ?? '';
    description = widget.job?['description'] ?? '';
    skillsController.text = (widget.job?['required_skills'] ?? []).join(", ");
    minExpController.text = (widget.job?['min_experience'] ?? 0).toString();
    jobSummary = widget.job?['job_summary'] ?? '';
    responsibilitiesController.text =
        (widget.job?['responsibilities'] ?? []).join(", ");
    qualificationsController.text =
        (widget.job?['qualifications'] ?? []).join(", ");
    companyName = widget.job?['company'] ?? '';
    jobLocation = widget.job?['location'] ?? '';
    companyDetails = widget.job?['company_details'] ?? '';
    salaryCurrency = widget.job?['salary_currency'] ?? 'ZAR';
    salaryMinController.text = (widget.job?['salary_min'] ?? '').toString();
    salaryMaxController.text = (widget.job?['salary_max'] ?? '').toString();
    salaryPeriod = widget.job?['salary_period'] ?? 'monthly';
    category = widget.job?['category'] ?? '';
    employmentType = widget.job?['employment_type'] ?? 'full_time';

    final jobWeightings = widget.job?['weightings'];
    if (jobWeightings is Map) {
      weightings = {
        "cv": (jobWeightings["cv"] ?? 60).toInt(),
        "assessment": (jobWeightings["assessment"] ?? 40).toInt(),
        "interview": (jobWeightings["interview"] ?? 0).toInt(),
        "references": (jobWeightings["references"] ?? 0).toInt(),
      };
    }

    knockoutRules = _normalizeKnockoutRules(widget.job?['knockout_rules']);

    if (widget.job != null &&
        widget.job!['assessment_pack'] != null &&
        widget.job!['assessment_pack']['questions'] != null) {
      questions =
          _normalizeQuestions(widget.job!['assessment_pack']['questions']);
    }

    _tabController = TabController(length: 2, vsync: this);
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

  List<Map<String, dynamic>> _normalizeKnockoutRules(dynamic raw) {
    if (raw is! List) return [];
    return raw.map<Map<String, dynamic>>((rule) {
      if (rule is Map<String, dynamic>) {
        return Map<String, dynamic>.from(rule);
      }
      return {
        "type": "skills",
        "field": "skills",
        "operator": "==",
        "value": rule.toString(),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _normalizeQuestions(dynamic raw) {
    if (raw is! List) return [];
    return raw.map<Map<String, dynamic>>((item) {
      final Map<String, dynamic> question =
          item is Map<String, dynamic> ? Map<String, dynamic>.from(item) : {};
      final rawOptions = question["options"];
      final List<dynamic> options =
          rawOptions is List ? List.from(rawOptions) : [];
      while (options.length < 4) {
        options.add("");
      }
      final normalizedOptions = options.take(4).map((opt) {
        return opt == null ? "" : opt.toString();
      }).toList();

      final rawAnswer = question["answer"] ?? question["correct_answer"];
      int answer = 0;
      if (rawAnswer is num) {
        answer = rawAnswer.toInt();
      } else if (rawAnswer is String) {
        answer = int.tryParse(rawAnswer) ?? 0;
      }
      if (answer < 0 || answer > 3) answer = 0;

      final rawWeight = question["weight"];
      double weight = 1;
      if (rawWeight is num) {
        weight = rawWeight.toDouble();
      } else if (rawWeight is String) {
        weight = double.tryParse(rawWeight) ?? 1;
      }
      if (weight <= 0) weight = 1;

      return {
        "question": question["question"]?.toString() ?? "",
        "options": normalizedOptions,
        "answer": answer,
        "weight": weight,
      };
    }).toList();
  }

  Future<void> saveJob() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final totalWeight = weightings.values.fold<int>(0, (sum, v) => sum + v);
    if (totalWeight != 100) {
      setState(() {
        weightingsError = "Weightings must total 100%";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Weightings must total 100%")),
      );
      return;
    } else {
      setState(() {
        weightingsError = null;
      });
    }

    final skills = skillsController.text
        .split(",")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final responsibilities = responsibilitiesController.text
        .split(",")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final qualifications = qualificationsController.text
        .split(",")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final normalizedQuestions = _normalizeQuestions(questions);
    final jobData = {
      'title': title,
      'description': description,
      'company': companyName,
      'location': jobLocation,
      'job_summary': jobSummary,
      'employment_type': employmentType,
      'responsibilities': responsibilities,
      'qualifications': qualifications,
      'company_details': companyDetails,
      'salary_min': double.tryParse(salaryMinController.text),
      'salary_max': double.tryParse(salaryMaxController.text),
      'salary_currency': salaryCurrency,
      'salary_period': salaryPeriod,
      'category': category,
      'required_skills': skills,
      'min_experience': double.tryParse(minExpController.text) ?? 0,
      'weightings': weightings,
      'knockout_rules': knockoutRules,
      'assessment_pack': {
        'questions': normalizedQuestions.map((q) {
          return {
            "question": q["question"],
            "options": q["options"],
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
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
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
        height: 720,
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
                            CustomTextField(
                              label: "Title",
                              initialValue: title,
                              hintText: "Enter job title",
                              onChanged: (v) => title = v,
                              validator: (v) =>
                                  v == null || v.isEmpty ? "Enter title" : null,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Description",
                              initialValue: description,
                              hintText: "Enter job description",
                              maxLines: 4,
                              onChanged: (v) => description = v,
                              validator: (v) => v == null || v.isEmpty
                                  ? "Enter description"
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Job Summary",
                              initialValue: jobSummary,
                              hintText: "Brief job summary",
                              maxLines: 3,
                              onChanged: (v) => jobSummary = v,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Responsibilities",
                              controller: responsibilitiesController,
                              hintText: "Comma separated list",
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Qualifications",
                              controller: qualificationsController,
                              hintText: "Comma separated list",
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Company",
                              initialValue: companyName,
                              hintText: "Company name",
                              onChanged: (v) => companyName = v,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Location",
                              initialValue: jobLocation,
                              hintText: "City, Country or Remote",
                              onChanged: (v) => jobLocation = v,
                            ),
                            const SizedBox(height: 16),
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
                            CustomTextField(
                              label: "Salary Currency",
                              initialValue: salaryCurrency,
                              hintText: "ZAR, USD, EUR",
                              onChanged: (v) =>
                                  salaryCurrency = v.isEmpty ? "ZAR" : v,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: salaryPeriod,
                              decoration: const InputDecoration(
                                labelText: "Salary Period",
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: "monthly",
                                  child: Text("Per Month"),
                                ),
                                DropdownMenuItem(
                                  value: "yearly",
                                  child: Text("Per Year"),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => salaryPeriod = value);
                              },
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Company Details",
                              initialValue: companyDetails,
                              hintText: "About the company",
                              maxLines: 3,
                              onChanged: (v) => companyDetails = v,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Category",
                              initialValue: category,
                              hintText: "Engineering, Marketing...",
                              onChanged: (v) => category = v,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Required Skills",
                              controller: skillsController,
                              hintText: "Comma separated skills",
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: "Minimum Experience (years)",
                              controller: minExpController,
                              inputType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: employmentType,
                              decoration: const InputDecoration(
                                labelText: "Employment Type",
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: "full_time",
                                  child: Text("Full Time"),
                                ),
                                DropdownMenuItem(
                                  value: "part_time",
                                  child: Text("Part Time"),
                                ),
                                DropdownMenuItem(
                                  value: "contract",
                                  child: Text("Contract"),
                                ),
                                DropdownMenuItem(
                                  value: "internship",
                                  child: Text("Internship"),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  employmentType = value;
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Evaluation Weightings",
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(height: 8),
                            WeightingConfigurationWidget(
                              weightings: weightings,
                              errorText: weightingsError,
                              onChanged: (updated) {
                                setState(() {
                                  weightings = updated;
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Knockout Rules",
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(height: 8),
                            KnockoutRulesBuilder(
                              rules: knockoutRules,
                              onChanged: (updated) {
                                setState(() {
                                  knockoutRules = updated;
                                });
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
                    child: Column(
                      children: [
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
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        decoration: InputDecoration(
                                          labelText: "Question",
                                          labelStyle: TextStyle(
                                            color: themeProvider.isDarkMode
                                                ? Colors.grey.shade400
                                                : Colors.black87,
                                          ),
                                        ),
                                        initialValue: q["question"],
                                        onChanged: (v) => q["question"] = v,
                                        style: TextStyle(
                                          color: themeProvider.isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      ...List.generate(4, (i) {
                                        return TextFormField(
                                          decoration: InputDecoration(
                                            labelText: "Option ${i + 1}",
                                            labelStyle: TextStyle(
                                              color: themeProvider.isDarkMode
                                                  ? Colors.grey.shade400
                                                  : Colors.black87,
                                            ),
                                          ),
                                          initialValue: q["options"][i],
                                          onChanged: (v) => q["options"][i] = v,
                                          style: TextStyle(
                                            color: themeProvider.isDarkMode
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        );
                                      }),
                                      DropdownButton<int>(
                                        value: q["answer"],
                                        items: List.generate(
                                          4,
                                          (i) => DropdownMenuItem(
                                            value: i,
                                            child:
                                                Text("Correct: Option ${i + 1}",
                                                    style: TextStyle(
                                                      color: themeProvider
                                                              .isDarkMode
                                                          ? Colors.white
                                                          : Colors.black87,
                                                    )),
                                          ),
                                        ),
                                        onChanged: (v) =>
                                            setState(() => q["answer"] = v!),
                                      ),
                                      TextFormField(
                                        decoration: InputDecoration(
                                          labelText: "Weight",
                                          labelStyle: TextStyle(
                                            color: themeProvider.isDarkMode
                                                ? Colors.grey.shade400
                                                : Colors.black87,
                                          ),
                                        ),
                                        initialValue: q["weight"].toString(),
                                        keyboardType: TextInputType.number,
                                        onChanged: (v) => q["weight"] =
                                            double.tryParse(v) ?? 1,
                                        style: TextStyle(
                                          color: themeProvider.isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
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
