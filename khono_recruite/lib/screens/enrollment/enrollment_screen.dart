import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/auth_service.dart';
import '../candidate/candidate_dashboard.dart';

class EnrollmentScreen extends StatefulWidget {
  final String token;
  const EnrollmentScreen({super.key, required this.token});

  @override
  _EnrollmentScreenState createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int currentStep = 0;
  bool loading = false;
  bool profileLoading = true;
  String? userName;
  PlatformFile? selectedCV;

  final ScrollController _scrollController = ScrollController();
  bool _isProgressCollapsed = false;

  // ------------------- Personal Details -------------------
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController linkedinController = TextEditingController();
  String? selectedGender;

  // ------------------- Education -------------------
  final TextEditingController educationController = TextEditingController();
  final TextEditingController universityController = TextEditingController();
  final TextEditingController graduationYearController =
      TextEditingController();

  // ------------------- Skills -------------------
  final TextEditingController skillsController = TextEditingController();
  final TextEditingController certificationsController =
      TextEditingController();
  final TextEditingController languagesController = TextEditingController();

  // ------------------- Experience -------------------
  final TextEditingController experienceController = TextEditingController();
  final TextEditingController previousCompaniesController =
      TextEditingController();
  final TextEditingController positionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchUserProfile();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final scrollOffset = _scrollController.offset;
    final shouldCollapse = scrollOffset > 50;

    if (shouldCollapse != _isProgressCollapsed) {
      setState(() {
        _isProgressCollapsed = shouldCollapse;
      });
    }
  }

  void _fetchUserProfile() async {
    try {
      final profile = await AuthService.getCurrentUser(token: widget.token);
      setState(() {
        userName = profile['full_name'] ??
            profile['name'] ??
            profile['email']?.split('@').first;
        if (userName != null && userName!.isNotEmpty) {
          nameController.text = userName!;
        }
        profileLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
      try {
        final localUser = await AuthService.getUserInfo();
        if (localUser != null) {
          setState(() {
            userName = localUser['full_name'] ??
                localUser['name'] ??
                localUser['email']?.split('@').first;
            if (userName != null && userName!.isNotEmpty) {
              nameController.text = userName!;
            }
          });
        }
      } catch (e) {
        debugPrint("Error fetching local user info: $e");
      }
      setState(() => profileLoading = false);
    }
  }

  void nextStep() {
    if (currentStep < 3) {
      setState(() => currentStep++);
      _tabController.animateTo(currentStep);
    } else {
      submitEnrollment();
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      setState(() => currentStep--);
      _tabController.animateTo(currentStep);
    }
  }

  void submitEnrollment() async {
    setState(() => loading = true);

    final data = {
      "full_name": nameController.text.trim(),
      "phone": phoneController.text.trim(),
      "address": addressController.text.trim(),
      "dob": dobController.text.trim(),
      "linkedin": linkedinController.text.trim(),
      "gender": selectedGender,

      // ---------- JSON fields ----------
      "education": [
        {
          "level": educationController.text.trim(),
          "institution": universityController.text.trim(),
          "graduation_year": graduationYearController.text.trim(),
        }
      ],

      "skills": skillsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),

      "certifications": certificationsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),

      "languages": languagesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),

      "work_experience": [
        {
          "description": experienceController.text.trim(),
          "company": previousCompaniesController.text.trim(),
          "position": positionController.text.trim(),
        }
      ],
    };

    final response = await AuthService.completeEnrollment(widget.token, data);

    setState(() => loading = false);

    if (response.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['error'])),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CandidateDashboard(token: widget.token),
        ),
      );
    }
  }

  // ------------------- CV Parsing -------------------
  Future<void> _parseCV(PlatformFile cvFile) async {
    setState(() => loading = true);

    try {
      if (cvFile.bytes == null) {
        throw Exception('CV file bytes are missing');
      }

      final token = widget.token; // JWT from login

      final response = await AuthService.parseCV(
        token: token,
        fileBytes: cvFile.bytes!,
        fileName: cvFile.name,
      );

      if (response.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['error'])),
        );
        return;
      }

      setState(() {
        nameController.text = response['full_name'] ?? '';
        phoneController.text = response['phone'] ?? '';
        addressController.text = response['address'] ?? '';
        dobController.text = response['dob'] ?? '';
        linkedinController.text = response['linkedin'] ?? '';
        educationController.text = (response['education'] ?? []).join(', ');
        skillsController.text = (response['skills'] ?? []).join(', ');
        certificationsController.text =
            (response['certifications'] ?? []).join(', ');
        languagesController.text = (response['languages'] ?? []).join(', ');
        experienceController.text = response['experience'] ?? '';
        positionController.text = response['position'] ?? '';
      });
    } catch (e) {
      debugPrint('Error parsing CV: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to parse CV')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  // ------------------- UI Builders -------------------
  Widget _buildStepIndicator(int index) {
    final isActive = currentStep == index;
    final isCompleted = currentStep > index;

    return GestureDetector(
      onTap: () {
        if (index <= currentStep) {
          setState(() => currentStep = index);
          _tabController.animateTo(index);
        }
      },
      child: Container(
        width: _isProgressCollapsed ? 40 : 48,
        height: _isProgressCollapsed ? 40 : 48,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.redAccent
              : isCompleted
                  ? Colors.green
                  : Colors.grey.shade300,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive
                ? Colors.redAccent
                : isCompleted
                    ? Colors.green
                    : Colors.grey.shade400,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            (index + 1).toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: _isProgressCollapsed ? 16 : 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  String _getStepLabel(int index) {
    switch (index) {
      case 0:
        return "Personal Information";
      case 1:
        return "Education Background";
      case 2:
        return "Skills & Certifications";
      case 3:
        return "Work Experience";
      default:
        return "";
    }
  }

  Widget _buildModernCard(Widget child, {String? title, String? subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text,
      int maxLines = 1,
      IconData? prefixIcon,
      bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            readOnly: readOnly,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 2,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              prefixIcon: prefixIcon != null
                  ? Container(
                      margin: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(
                        prefixIcon,
                        color: Colors.redAccent,
                        size: 22,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDateOfBirthField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Date of Birth",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _selectDate(),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AbsorbPointer(
              child: TextField(
                controller: dobController,
                readOnly: true,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.redAccent,
                      width: 2,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  prefixIcon: Container(
                    margin: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: Colors.grey.shade500,
                      size: 28,
                    ),
                  ),
                  hintText: "Select your date of birth",
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.redAccent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogTheme: DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        dobController.text = "${picked.year.toString().padLeft(4, '0')}-"
            "${picked.month.toString().padLeft(2, '0')}-"
            "${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Gender",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            initialValue: selectedGender,
            onChanged: (String? newValue) {
              setState(() {
                selectedGender = newValue;
              });
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 2,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Colors.redAccent,
                  size: 22,
                ),
              ),
            ),
            dropdownColor: Colors.white,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
            icon: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.arrow_drop_down_rounded,
                color: Colors.grey.shade500,
                size: 28,
              ),
            ),
            hint: Text(
              "Select Gender",
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            items: <String>['Male', 'Female', 'Other', 'Prefer not to say']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ------------------- Build UI -------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: loading || profileLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(22),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Loading Enrollment Form...",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                const SizedBox(height: 50),
                SizedBox(
                  height: _isProgressCollapsed ? 70 : 120,
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(4, (index) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildStepIndicator(index),
                                if (!_isProgressCollapsed) ...[
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      _getStepLabel(index),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: currentStep >= index
                                            ? Colors.black87
                                            : Colors.grey.shade400,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // ------------------- Step 1: Personal Details -------------------
                      SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: Column(
                          children: [
                            _buildModernCard(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTextField(nameController, "Full Name"),
                                  _buildTextField(phoneController, "Phone",
                                      keyboardType: TextInputType.phone),
                                  _buildTextField(addressController, "Address"),
                                  _buildDateOfBirthField(),
                                  _buildTextField(
                                      linkedinController, "LinkedIn Profile"),
                                  _buildGenderDropdown(),
                                ],
                              ),
                              title: "Personal Details",
                              subtitle: "Enter your basic information",
                            ),
                            _buildModernCard(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      FilePickerResult? result =
                                          await FilePicker.platform.pickFiles(
                                        type: FileType.custom,
                                        allowedExtensions: [
                                          'pdf',
                                          'doc',
                                          'docx'
                                        ],
                                      );

                                      if (result != null) {
                                        setState(() {
                                          selectedCV = result.files.first;
                                        });

                                        await _parseCV(selectedCV!);
                                      }
                                    },
                                    icon: const Icon(Icons.upload_file_rounded),
                                    label: Text(selectedCV != null
                                        ? "CV Selected"
                                        : "Upload CV"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  if (selectedCV != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      "Selected file: ${selectedCV!.name}",
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              title: "CV Upload",
                              subtitle: "Upload your CV to auto-fill fields",
                            ),
                          ],
                        ),
                      ),

                      // ------------------- Step 2: Education -------------------
                      SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: Column(
                          children: [
                            _buildModernCard(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTextField(
                                      educationController, "Education Level"),
                                  _buildTextField(universityController,
                                      "University/College"),
                                  _buildTextField(graduationYearController,
                                      "Graduation Year",
                                      keyboardType: TextInputType.number),
                                ],
                              ),
                              title: "Education Background",
                            ),
                          ],
                        ),
                      ),

                      // ------------------- Step 3: Skills -------------------
                      SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: Column(
                          children: [
                            _buildModernCard(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTextField(skillsController, "Skills"),
                                  _buildTextField(certificationsController,
                                      "Certifications"),
                                  _buildTextField(
                                      languagesController, "Languages"),
                                ],
                              ),
                              title: "Skills & Certifications",
                            ),
                          ],
                        ),
                      ),

                      // ------------------- Step 4: Experience -------------------
                      SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: Column(
                          children: [
                            _buildModernCard(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTextField(
                                      experienceController, "Work Experience",
                                      maxLines: 3),
                                  _buildTextField(previousCompaniesController,
                                      "Previous Companies"),
                                  _buildTextField(
                                      positionController, "Position"),
                                ],
                              ),
                              title: "Work Experience",
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ------------------- Navigation Buttons -------------------
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      if (currentStep > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: previousStep,
                            child: const Text("Back"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      if (currentStep > 0) const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: nextStep,
                          child: Text(currentStep == 3 ? "Submit" : "Next"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
