import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import 'enrollment_drop_stub.dart' if (dart.library.html) 'enrollment_drop_web.dart' as enrollment_drop;

/// Khonology theme for onboarding (match app).
const Color _kKhonologyRed = Color(0xFFC10D00);
const Color _kOnboardingCardBg = Color(0xFF2A2A2A);
const Color _kSuccess = Color(0xFF22C55E);
const Color _kWarning = Color(0xFFB91C1C);
const Color _kWarningText = Color(0xFFFECACA);

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
  bool profileLoading = false;
  bool _loggingIn = false;
  String? userName;
  PlatformFile? selectedCV;

  // --- 3-step onboarding flow ---
  /// 0 = CV Upload, 1 = Processing, 2 = Review. When true, user chose "Fill out manually" and we show the 4-step form.
  bool _choseManual = false;
  int _onboardingStep = 0;
  int _processingStage = 0; // 0..3 for Reading, Education, Experience, Finalizing
  bool _processingComplete = false;
  bool _processingError = false;
  bool _processingStarted = false;

  final ScrollController _scrollController = ScrollController();
  bool _isProgressCollapsed = false;

  /// Which review sections are expanded (Show more). Key: 'education' | 'skills' | 'experience'.
  final Map<String, bool> _reviewSectionExpanded = {};

  /// Which main review headings are collapsed. Key: 'personal' | 'education' | 'skills' | 'experience'. false = expanded.
  final Map<String, bool> _reviewSectionCollapsed = {};

  /// True when CV parse/upload failed; drop zone border shows red. Cleared when user selects a new file.
  bool _cvUploadFailed = false;

  // Define the custom red color
  final Color customRed = const Color(0xFFC10D00);

  // Define the box fill color: #f2f2f2 with 40% opacity
  final Color boxFillColor = const Color(0xFFF2F2F2).withValues(alpha: 0.2);

  static const List<String> _educationLevels = [
    'Matric',
    'National Certificate (N4-N6)',
    'Diploma',
    "Bachelor's Degree",
    'Honours',
    "Master's Degree",
    'PhD',
    'Other',
  ];

  static const List<String> _universities = [
    'University of Cape Town',
    'University of the Witwatersrand',
    'Stellenbosch University',
    'University of Pretoria',
    'University of Johannesburg',
    'North-West University',
    'Rhodes University',
    'University of KwaZulu-Natal',
    'University of the Free State',
    'Cape Peninsula University of Technology',
    'Tshwane University of Technology',
    'Durban University of Technology',
    'Varsity College',
    'Vega School',
    'VUT',
    'Other',
  ];

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
    const timeoutDuration = Duration(seconds: 15);
    try {
      final profile = await AuthService.getCurrentUser(token: widget.token)
          .timeout(timeoutDuration, onTimeout: () {
        debugPrint("getCurrentUser timed out after ${timeoutDuration.inSeconds}s");
        throw TimeoutException('Profile load timed out', timeoutDuration);
      });
      if (!mounted) return;
      // Do not use profile when token expired or unauthorized
      if (profile['unauthorized'] == true || (profile['error'] != null && !profile.containsKey('user'))) {
        debugPrint("Profile load skipped (unauthorized or token expired)");
        return;
      }
      setState(() {
        userName = profile['user']?['profile']?['full_name'] ??
            profile['full_name'] ??
            profile['name'] ??
            profile['user']?['email']?.split('@').first ??
            profile['email']?.split('@').first;
        if (userName != null && userName!.isNotEmpty) {
          nameController.text = userName!;
        }
      });
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
      try {
        final localUser = await AuthService.getUserInfo();
        if (localUser != null && mounted) {
          setState(() {
            userName = localUser['full_name'] ??
                localUser['name'] ??
                localUser['email']?.split('@').first;
            if (userName != null && userName!.isNotEmpty) {
              nameController.text = userName!;
            }
          });
        }
      } catch (e2) {
        debugPrint("Error fetching local user info: $e2");
      }
    }
  }

  /// Returns list of missing required field names for the current step; empty if valid.
  List<String> _getMissingRequiredFields() {
    final missing = <String>[];
    switch (currentStep) {
      case 0:
        if (nameController.text.trim().isEmpty) missing.add('Full Name');
        if (phoneController.text.trim().isEmpty) missing.add('Phone');
        if (addressController.text.trim().isEmpty) missing.add('Address');
        if (dobController.text.trim().isEmpty) missing.add('Date of Birth');
        break;
      case 1:
        if (educationController.text.trim().isEmpty) missing.add('Education Level');
        if (universityController.text.trim().isEmpty) missing.add('University/College');
        if (graduationYearController.text.trim().isEmpty) missing.add('Graduation Year');
        break;
      case 2:
        if (skillsController.text.trim().isEmpty) missing.add('Skills');
        break;
      case 3:
        if (experienceController.text.trim().isEmpty) missing.add('Work Experience');
        if (positionController.text.trim().isEmpty) missing.add('Position');
        break;
    }
    return missing;
  }

  void _showRequiredFieldsDialog(List<String> missing) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Required fields'),
        content: Text(
          'Please fill in all required fields:\n${missing.join(', ')}',
          style: const TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  void nextStep() {
    final missing = _getMissingRequiredFields();
    if (missing.isNotEmpty) {
      _showRequiredFieldsDialog(missing);
      return;
    }
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
    if (dobController.text.trim().isNotEmpty) {
      data["dob"] = dobController.text.trim();
    }

    final response = await AuthService.completeEnrollment(widget.token, data);

    if (response.containsKey('error')) {
      setState(() => loading = false);
      final message = response['error']?.toString() ?? 'Enrollment failed';
      debugPrint('Enrollment error: $message; details: ${response['details']}');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } else {
      if (!context.mounted) return;
      setState(() {
        _loggingIn = true;
      });
      Future.delayed(const Duration(milliseconds: 1200), () async {
        if (!context.mounted) return;
        try {
          await AuthService.getCurrentUser(token: widget.token);
        } catch (_) {}
        if (!context.mounted) return;
        context.go('/candidate-dashboard?token=${Uri.encodeComponent(widget.token)}');
      });
    }
  }

  // ------------------- Onboarding step builders -------------------
  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () {
              context.go('/login');
            },
            tooltip: 'Back to login',
          ),
          const SizedBox(width: 8),
          Text(
            'Step ${_onboardingStep + 1} of 3',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  static const EdgeInsets _cardMargin = EdgeInsets.symmetric(horizontal: 24, vertical: 16);
  static const EdgeInsets _cardMarginInRow = EdgeInsets.symmetric(horizontal: 12, vertical: 16);

  Widget _buildOnboardingCard({required Widget child, double maxWidth = 560, bool flexible = false}) {
    final container = Container(
      width: double.infinity,
      margin: flexible ? _cardMarginInRow : _cardMargin,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _kOnboardingCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    if (flexible) return container;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: container,
      ),
    );
  }

  static const _supportedCVExtensions = ['pdf', 'doc', 'docx'];

  bool _isSupportedCVFile(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return _supportedCVExtensions.contains(ext);
  }

  void _showUnsupportedFileMessage() {
    // Don't change border state — just show the dialog so the UI stays snappy
    // and we don't override a valid file's success state.
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _kOnboardingCardBg,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _kKhonologyRed, size: 28),
            const SizedBox(width: 12),
            Text(
              'Unsupported file',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Text(
          'Please upload a PDF or Word document (.pdf, .doc, .docx).',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: _kKhonologyRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onCVFileReceived(PlatformFile file) {
    if (!_isSupportedCVFile(file.name)) {
      _showUnsupportedFileMessage();
      return;
    }
    setState(() {
      selectedCV = file;
      _cvUploadFailed = false;
    });
  }

  Widget _buildDropZone() {
    final hasFile = selectedCV != null;
    final Color borderColor = _cvUploadFailed
        ? _kKhonologyRed
        : (hasFile ? _kSuccess : Colors.white24);
    final Color iconColor = _cvUploadFailed
        ? _kKhonologyRed
        : (hasFile ? _kSuccess : Colors.white54);
    return GestureDetector(
      onTap: () async {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx'],
        );
        if (result != null && result.files.isNotEmpty && mounted) {
          final file = result.files.first;
          if (!_isSupportedCVFile(file.name)) {
            _showUnsupportedFileMessage();
            return;
          }
          setState(() {
            selectedCV = file;
            _cvUploadFailed = false;
          });
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: hasFile
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 40,
                    color: _kSuccess,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selectedCV!.name,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  if (selectedCV!.bytes == null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Preparing file…',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white54,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'doc', 'docx'],
                          );
                          if (result != null && result.files.isNotEmpty && mounted) {
                            final file = result.files.first;
                            if (!_isSupportedCVFile(file.name)) {
                              _showUnsupportedFileMessage();
                              return;
                            }
                            setState(() {
                              selectedCV = file;
                              _cvUploadFailed = false;
                            });
                          }
                        },
                        icon: Icon(Icons.check_circle, size: 18, color: _kSuccess),
                        label: Text(
                          'Uploaded',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: _kSuccess,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kSuccess,
                          side: BorderSide(color: _kSuccess, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            selectedCV = null;
                            _cvUploadFailed = false;
                          });
                        },
                        child: Text(
                          'Clear',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 48,
                    color: iconColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Drag & drop your CV here or',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'doc', 'docx'],
                      );
                      if (result != null && result.files.isNotEmpty && mounted) {
                        final file = result.files.first;
                        if (!_isSupportedCVFile(file.name)) {
                          _showUnsupportedFileMessage();
                          return;
                        }
                        setState(() {
                          selectedCV = file;
                          _cvUploadFailed = false;
                        });
                      }
                    },
                    icon: const Icon(Icons.upload_file, size: 20),
                    label: const Text('Upload CV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kKhonologyRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Step 1 and Step 2 share one space side by side; Step 3 is on its own.
  Widget _buildSteps1And2SideBySide() {
    return _EnrollmentDropZoneScope(
      onFileDropped: (file) => _onCVFileReceived(file),
      onUnsupportedFile: _showUnsupportedFileMessage,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildProgressIndicator(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildOnboardingCard(
                      flexible: true,
                      child: _onboardingStep == 0
                          ? _buildStep1CardContent()
                          : _buildStep1CompleteContent(),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Stack(
                      children: [
                        _buildOnboardingCard(
                          flexible: true,
                          child: _onboardingStep == 0
                              ? _buildStep2PlaceholderContent()
                              : _buildStep2CardContent(),
                        ),
                        if (loading && !_processingComplete)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: CircularProgressIndicator(
                                        color: _kKhonologyRed,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Processing…',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1CardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Welcome! Let\'s get started',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload your CV to autofill your profile.',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.white70,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Upload your CV',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              ' *',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kKhonologyRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildDropZone(),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'PDF, DOCX, or DOC files',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white54,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _choseManual = true),
            child: Text(
              'I don\'t have a CV – Fill out manually',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: selectedCV != null &&
                  selectedCV!.bytes != null
                  ? () {
                      setState(() {
                        _onboardingStep = 1;
                        if (!_processingComplete) {
                          _processingStarted = false;
                          _processingComplete = false;
                          _processingError = false;
                        }
                      });
                      if (!_processingComplete) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_processingStarted) return;
                          _processingStarted = true;
                          _runProcessingAndGoToReview();
                        });
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kKhonologyRed,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade700,
                disabledForegroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Next',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep1CompleteContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: _kSuccess, size: 28),
            const SizedBox(width: 12),
            Text(
              'Step 1 complete',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (selectedCV != null)
          Text(
            selectedCV!.name,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white70,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => setState(() => _onboardingStep = 0),
          child: Text(
            'Previous',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2PlaceholderContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Step 2: Processing',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload your CV on the left and click Next to extract your details.',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.white70,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildStep2CardContent() {
    const stages = [
      'Reading Your CV',
      'Extracting Education…',
      'Extracting Work Experience…',
      'Finalizing…',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Processing Your Information',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Extracting details from your CV…',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.white70,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        ...List.generate(stages.length, (i) {
          final done = _processingComplete ? true : i < _processingStage;
          final current = !_processingComplete && i == _processingStage;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 24,
                  color: done ? _kSuccess : (current ? _kKhonologyRed : Colors.white38),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stages[i],
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: current ? FontWeight.w600 : FontWeight.w500,
                      color: done ? Colors.white : (current ? _kKhonologyRed : Colors.white70),
                    ),
                  ),
                ),
                if (current && loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kKhonologyRed,
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _processingComplete ? 1.0 : (_processingStage + 1) / stages.length,
            minHeight: 6,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(_kKhonologyRed),
          ),
        ),
        const SizedBox(height: 12),
        if (loading && !_processingComplete)
          Text(
            'Please wait a moment…',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white54,
            ),
          ),
        if (_processingComplete || _processingError) ...[
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() => _onboardingStep = 0),
                child: Text(
                  'Previous',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _processingError
                    ? null
                    : () => setState(() => _onboardingStep = 2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kKhonologyRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Next',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStep3Review() {
    final nameOk = nameController.text.trim().isNotEmpty;
    final educationOk = educationController.text.trim().isNotEmpty || universityController.text.trim().isNotEmpty;
    final skillsOk = skillsController.text.trim().isNotEmpty;
    final experienceOk = experienceController.text.trim().isNotEmpty || positionController.text.trim().isNotEmpty;
    final responsibilitiesMissing = experienceController.text.trim().isEmpty && positionController.text.trim().isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildProgressIndicator(),
          _buildOnboardingCard(
            maxWidth: 1100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Review Your Profile',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We\'ve filled in your details. Please review and complete any missing info.',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                if (!_reviewRequiredComplete) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kWarning,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: _kWarningText),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Complete required fields to continue.',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: _kWarningText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 520,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: _buildCollapsibleReviewSection(
                                sectionKey: 'personal',
                                title: 'Personal Details',
                                completed: nameOk,
                                onEdit: () => _showEditPersonal(context),
                                expandBody: true,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildReviewRow('Full Name', nameController.text, null),
                                    _buildReviewRow('Email', userName ?? '—', null),
                                    _buildReviewRow('Phone', phoneController.text, null),
                                    _buildReviewRow('Address', addressController.text, null),
                                    _buildReviewRow('Date of Birth', dobController.text.trim().isEmpty ? '—' : dobController.text, null),
                                    _buildReviewRow('LinkedIn', linkedinController.text.trim().isEmpty ? '—' : linkedinController.text, null),
                                    _buildReviewRow('Gender', selectedGender ?? '—', null),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _buildCollapsibleReviewSection(
                                sectionKey: 'skills',
                                title: 'Skills',
                                completed: skillsOk,
                                onEdit: null,
                                expandBody: true,
                                child: skillsOk
                                    ? _buildSkillsReviewContent()
                                    : Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          'No skills listed',
                                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.white54),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: _buildCollapsibleReviewSection(
                                sectionKey: 'education',
                                title: 'Education',
                                completed: educationOk,
                                onEdit: () => _showEditEducation(context),
                                expandBody: true,
                                child: educationOk
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ..._getEducationEntries(educationController.text)
                                              .map((entry) => _buildEducationEntryBlock(entry)),
                                          if (universityController.text.trim().isNotEmpty && _getEducationEntries(educationController.text).isEmpty)
                                            _buildEducationEntryBlock(universityController.text.trim()),
                                        ],
                                      )
                                    : _buildEmptySection('No education details found', 'Add Education', () => _showEditEducation(context)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _buildCollapsibleReviewSection(
                                sectionKey: 'experience',
                                title: 'Work Experience',
                                completed: experienceOk && !responsibilitiesMissing,
                                onEdit: () => _showEditExperience(context),
                                expandBody: true,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (experienceOk || positionController.text.trim().isNotEmpty) ...[
                                      ..._getWorkExperienceSummaries().map(
                                        (m) => _buildWorkExperienceSummaryCard(
                                          m['company']!,
                                          m['role']!,
                                          m['year']!,
                                        ),
                                      ),
                                    ] else
                                      _buildEmptySection('No work experience added', 'Add Experience', () => _showEditExperience(context)),
                                    if (responsibilitiesMissing)
                                      Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _kWarning,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.warning_amber_rounded, size: 18, color: _kWarningText),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Missing: Responsibilities – Please complete this field.',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  color: _kWarningText,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _onboardingStep = 1),
                      child: Text(
                        'Previous',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _reviewRequiredComplete ? submitEnrollment : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kKhonologyRed,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade700,
                        disabledForegroundColor: Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Finish',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Collapsible block: tap header to expand/collapse. When [expandBody] is true, body is in [Expanded] + scrollable for equal-height layout.
  Widget _buildCollapsibleReviewSection({
    required String sectionKey,
    required String title,
    required bool completed,
    required Widget child,
    VoidCallback? onEdit,
    bool expandBody = false,
  }) {
    final isCollapsed = _reviewSectionCollapsed[sectionKey] ?? false;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: child,
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: expandBody ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _reviewSectionCollapsed[sectionKey] = !isCollapsed),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    isCollapsed ? Icons.expand_more : Icons.expand_less,
                    size: 24,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    completed ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20,
                    color: completed ? _kSuccess : Colors.white38,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (onEdit != null)
                    TextButton(
                      onPressed: onEdit,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Edit',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _kKhonologyRed,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (expandBody)
            Expanded(
              child: isCollapsed ? const SizedBox.shrink() : SingleChildScrollView(child: body),
            )
          else if (!isCollapsed)
            body,
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, VoidCallback? onEdit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '—' : value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onEdit != null)
            TextButton(
              onPressed: onEdit,
              child: Text(
                'Edit',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kKhonologyRed,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptySection(String message, String buttonLabel, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white54,
              ),
            ),
          ),
          TextButton(
            onPressed: onAdd,
            child: Text(
              buttonLabel,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kKhonologyRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const int _kReviewCollapsedListItems = 3;

  /// Splits education text into separate entries (by newline, or by comma if no newlines).
  List<String> _getEducationEntries(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return [];
    if (trimmed.contains('\n')) {
      return trimmed.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return trimmed.split(RegExp(r',\s*')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Excludes reference-like items (emails, phones, "Reference" header, "Name - Company" lines).
  List<String> _filterSkillsOnly(List<String> items) {
    final phoneLike = RegExp(r'^\+?[\d\s\-]{10,}$');
    return items.where((s) {
      final t = s.trim();
      if (t.isEmpty) return false;
      if (t.contains('@')) return false;
      if (t.toLowerCase().contains('reference')) return false;
      if (phoneLike.hasMatch(t)) return false;
      return true;
    }).toList();
  }

  /// One card per job: company, role, year only (no long description).
  List<Map<String, String>> _getWorkExperienceSummaries() {
    final company = previousCompaniesController.text.trim();
    final role = positionController.text.trim();
    final desc = experienceController.text.trim();
    final year = _extractYearFromText(desc);
    if (company.isEmpty && role.isEmpty && desc.isEmpty) return [];
    return [
      {'company': company.isNotEmpty ? company : '—', 'role': role.isNotEmpty ? role : '—', 'year': year},
    ];
  }

  String _extractYearFromText(String text) {
    final m = RegExp(r'(?:20|19)\d{2}').firstMatch(text);
    if (m != null) return m.group(0)!;
    final m2 = RegExp(r'\d{1,2}/\s*(?:20|19)?\d{2}').firstMatch(text);
    if (m2 != null) return m2.group(0)!;
    if (text.toLowerCase().contains('current')) return 'Current';
    return '—';
  }

  Widget _buildEducationEntryBlock(String entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        entry,
        style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70, height: 1.35),
      ),
    );
  }

  Widget _buildWorkExperienceSummaryCard(String company, String role, String year) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            company,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            role,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 2),
          Text(
            year,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  /// Skills section: show only skill items (filter out references, emails, phones).
  Widget _buildSkillsReviewContent() {
    final rawItems = skillsController.text
        .split(RegExp(r'[,;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final skillsOnly = _filterSkillsOnly(rawItems);
    if (skillsOnly.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'No skills listed',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.white54),
        ),
      );
    }
    return _buildExpandableListReview('skills', 'Skills', skillsOnly.join(', '), null);
  }

  /// Review section for comma-separated list (e.g. skills): show first N items, then "Show more (X more)".
  Widget _buildExpandableListReview(String sectionKey, String listLabel, String commaSeparatedValue, VoidCallback? onEdit) {
    final isExpanded = _reviewSectionExpanded[sectionKey] ?? false;
    final items = commaSeparatedValue
        .split(RegExp(r'[,;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final hasMore = items.length > _kReviewCollapsedListItems;
    final visibleItems = isExpanded ? items : items.take(_kReviewCollapsedListItems).toList();
    final hiddenCount = items.length - visibleItems.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  listLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (onEdit != null)
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Edit',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kKhonologyRed,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (visibleItems.isEmpty)
            Text(
              '—',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70, height: 1.3),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ...visibleItems.map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      item,
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                onTap: () => setState(() => _reviewSectionExpanded[sectionKey] = !isExpanded),
                child: Text(
                  isExpanded ? 'Show less' : 'Show more (${hiddenCount} more)',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kKhonologyRed,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showEditPersonal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditPersonalSheet(
        nameController: nameController,
        phoneController: phoneController,
        addressController: addressController,
        dobController: dobController,
        linkedinController: linkedinController,
        selectedGender: selectedGender,
        onGenderChanged: (v) => setState(() => selectedGender = v),
        onSave: () => setState(() {}),
        onTapDateOfBirth: (ctx) => _selectDate(ctx),
      ),
    ).then((_) => setState(() {}));
  }

  void _showEditEducation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditEducationSheet(
        educationController: educationController,
        universityController: universityController,
        graduationYearController: graduationYearController,
        onSave: () => setState(() {}),
      ),
    ).then((_) => setState(() {}));
  }

  void _showEditExperience(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditExperienceSheet(
        experienceController: experienceController,
        previousCompaniesController: previousCompaniesController,
        positionController: positionController,
        onSave: () => setState(() {}),
      ),
    ).then((_) => setState(() {}));
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
        width: _isProgressCollapsed ? 32 : 36,
        height: _isProgressCollapsed ? 32 : 36,
        decoration: BoxDecoration(
          color: isActive
              ? customRed
              : isCompleted
                  ? Colors.green
                  : Colors.grey.shade300,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive
                ? customRed
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
              fontSize: _isProgressCollapsed ? 12 : 14,
              fontWeight: FontWeight.w800,
              fontFamily: 'Poppins',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade300,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
        child,
        const SizedBox(height: 12),
      ],
    );
  }

  /// Manual form only: Back / Next buttons, centered, just below the step content.
  Widget _buildManualFormNavButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (currentStep > 0) ...[
            SizedBox(
              width: 320,
              child: Container(
                decoration: BoxDecoration(
                  color: customRed,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: customRed.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: previousStep,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      alignment: Alignment.center,
                      child: const Text(
                        "Back",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          SizedBox(
            width: 320,
            child: Container(
              decoration: BoxDecoration(
                color: customRed,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: customRed.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: nextStep,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    alignment: Alignment.center,
                    child: Text(
                      currentStep == 3 ? "Submit" : "Next",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text,
      int maxLines = 1,
      IconData? prefixIcon,
      bool readOnly = false,
      bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: customRed,
                  fontFamily: 'Poppins',
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: boxFillColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white38,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            readOnly: readOnly,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontFamily: 'Poppins',
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              prefixIcon: prefixIcon != null
                  ? Container(
                      margin: const EdgeInsets.only(left: 10, right: 6),
                      child: Icon(
                        prefixIcon,
                        color: Colors.white38,
                        size: 20,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildDropdown(
    TextEditingController controller,
    String label,
    List<String> items, {
    bool required = false,
  }) {
    final value = controller.text.trim().isEmpty ? null : controller.text.trim();
    final effectiveItems = (value != null && !items.contains(value))
        ? [value, ...items]
        : items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: customRed,
                  fontFamily: 'Poppins',
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: boxFillColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white38,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            dropdownColor: Colors.grey[900],
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontFamily: 'Poppins',
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.grey.shade300,
                  size: 24,
                ),
              ),
            ),
            hint: Text(
              'Select $label',
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
            items: effectiveItems.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                controller.text = newValue ?? '';
              });
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildDateOfBirthField({bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Date of Birth",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: customRed,
                  fontFamily: 'Poppins',
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _selectDate(),
          child: Container(
            decoration: BoxDecoration(
              color: boxFillColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white38,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: AbsorbPointer(
              absorbing: true,
              child: TextField(
                controller: dobController,
                readOnly: true,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  prefixIcon: Container(
                    margin: const EdgeInsets.only(left: 10, right: 6),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.white38,
                      size: 20,
                    ),
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: Colors.grey.shade300,
                      size: 24,
                    ),
                  ),
                  hintText: "Select your date of birth",
                  hintStyle: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _selectDate([BuildContext? pickerContext]) async {
    final ctx = pickerContext ?? context;
    if (!mounted) return;
    final DateTime? picked = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (BuildContext dialogContext, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: customRed,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogTheme: DialogThemeData(backgroundColor: Colors.white),
            textTheme: ThemeData.light().textTheme.apply(
                  fontFamily: 'Poppins',
                ),
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
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: boxFillColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white38,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 1),
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
            dropdownColor: Colors.grey[900],
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontFamily: 'Poppins',
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 10, right: 6),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.grey.shade300,
                  size: 24,
                ),
              ),
            ),
            hint: Text(
              "Select Gender",
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
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
                      color: Colors.white,
                      fontFamily: 'Poppins',
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
    if (!_choseManual) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/dark.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Container(color: Colors.black.withValues(alpha: 0.4)),
            profileLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: _kKhonologyRed),
                        const SizedBox(height: 20),
                        Text(
                          'Loading…',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  )
                : _onboardingStep < 2
                    ? _buildSteps1And2SideBySide()
                    : _buildStep3Review(),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/dark.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            color: Colors.black.withValues(alpha: 0.4),
          ),
          loading || profileLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: customRed,
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
                      Text(
                        _loggingIn ? "Logging in..." : "Loading Enrollment Form...",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                            onPressed: () => setState(() => _choseManual = false),
                            tooltip: 'Back',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: _isProgressCollapsed ? 56 : 84,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(4, (index) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildStepIndicator(index),
                                    if (!_isProgressCollapsed) ...[
                                      const SizedBox(height: 2),
                                      SizedBox(
                                        width: 100,
                                        child: Text(
                                          _getStepLabel(index),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: currentStep >= index
                                                ? Colors.white
                                                : Colors.grey.shade300,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'Poppins',
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
                    const SizedBox(height: 6),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          // ------------------- Step 1: Personal Details -------------------
                          SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 6),
                            child: Column(
                              children: [
                                _buildModernCard(
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                              child: _buildTextField(
                                                  nameController, "Full Name",
                                                  required: true)),
                                          const SizedBox(width: 16),
                                          Expanded(
                                              child: _buildTextField(
                                                  phoneController, "Phone",
                                                  keyboardType:
                                                      TextInputType.phone,
                                                  required: true)),
                                        ],
                                      ),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                              child: _buildTextField(
                                                  addressController, "Address",
                                                  required: true)),
                                          const SizedBox(width: 16),
                                          Expanded(child: _buildDateOfBirthField(required: true)),
                                        ],
                                      ),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                              child: _buildTextField(
                                                  linkedinController,
                                                  "LinkedIn Profile")),
                                          const SizedBox(width: 16),
                                          Expanded(child: _buildGenderDropdown()),
                                        ],
                                      ),
                                    ],
                                  ),
                                  title: "Personal Details",
                                  subtitle: "Enter your basic information",
                                ),
                                _buildManualFormNavButtons(),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                              child: _buildDropdown(
                                                  educationController,
                                                  "Education Level",
                                                  _educationLevels,
                                                  required: true)),
                                          const SizedBox(width: 16),
                                          Expanded(
                                              child: _buildDropdown(
                                                  universityController,
                                                  "University/College",
                                                  _universities,
                                                  required: true)),
                                        ],
                                      ),
                                      _buildTextField(graduationYearController,
                                          "Graduation Year",
                                          keyboardType: TextInputType.number,
                                          required: true),
                                    ],
                                  ),
                                  title: "Education Background",
                                ),
                                _buildManualFormNavButtons(),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                              child: _buildTextField(
                                                  skillsController, "Skills",
                                                  required: true)),
                                          const SizedBox(width: 16),
                                          Expanded(
                                              child: _buildTextField(
                                                  certificationsController,
                                                  "Certifications")),
                                        ],
                                      ),
                                      _buildTextField(
                                          languagesController, "Languages"),
                                    ],
                                  ),
                                  title: "Skills & Certifications",
                                ),
                                _buildManualFormNavButtons(),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildTextField(experienceController,
                                          "Work Experience",
                                          maxLines: 3,
                                          required: true),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                              child: _buildTextField(
                                                  previousCompaniesController,
                                                  "Previous Companies")),
                                          const SizedBox(width: 16),
                                          Expanded(
                                              child: _buildTextField(
                                                  positionController, "Position",
                                                  required: true)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  title: "Work Experience",
                                ),
                                _buildManualFormNavButtons(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  Future<void> _runProcessingAndGoToReview() async {
    if (selectedCV == null || selectedCV!.bytes == null) return;
    setState(() {
      _processingStage = 0;
      _processingComplete = false;
      _processingError = false;
      loading = true;
    });
    const stages = ['Reading Your CV', 'Extracting Education…', 'Extracting Work Experience…', 'Finalizing…'];
    for (int i = 0; i < stages.length; i++) {
      if (!mounted) return;
      setState(() => _processingStage = i);
      await Future.delayed(const Duration(milliseconds: 600));
    }
    try {
      final response = await AuthService.parseCV(
        token: widget.token,
        fileBytes: selectedCV!.bytes!,
        fileName: selectedCV!.name,
      );
      if (!mounted) return;
      if (response.containsKey('error')) {
        setState(() {
          _processingError = true;
          _cvUploadFailed = true;
          loading = false;
        });
        final message = response['error'].toString();
        final isUnauthorized = response['unauthorized'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade700,
            action: isUnauthorized
                ? SnackBarAction(
                    label: 'Log in',
                    textColor: Colors.white,
                    onPressed: () => context.go('/login'),
                  )
                : null,
          ),
        );
        return;
      }
      setState(() {
        nameController.text = response['full_name'] ?? '';
        phoneController.text = response['phone'] ?? '';
        addressController.text = response['address'] ?? '';
        dobController.text = response['dob'] ?? '';
        linkedinController.text = response['linkedin'] ?? '';
        educationController.text = (response['education'] is List)
            ? (response['education'] as List).join('\n')
            : (response['education']?.toString() ?? '');
        skillsController.text = (response['skills'] is List)
            ? (response['skills'] as List).join(', ')
            : (response['skills']?.toString() ?? '');
        certificationsController.text = (response['certifications'] is List)
            ? (response['certifications'] as List).join(', ')
            : (response['certifications']?.toString() ?? '');
        languagesController.text = (response['languages'] is List)
            ? (response['languages'] as List).join(', ')
            : (response['languages']?.toString() ?? '');
        experienceController.text = response['experience']?.toString() ?? '';
        positionController.text = response['position']?.toString() ?? '';
        _processingStage = stages.length - 1;
        _processingComplete = true;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processingError = true;
        _cvUploadFailed = true;
        loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to parse CV'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  bool get _reviewRequiredComplete {
    final name = nameController.text.trim();
    return name.isNotEmpty;
  }
}

class _EnrollmentDropZoneScope extends StatefulWidget {
  const _EnrollmentDropZoneScope({
    required this.onFileDropped,
    this.onUnsupportedFile,
    required this.child,
  });
  final void Function(PlatformFile file) onFileDropped;
  final void Function()? onUnsupportedFile;
  final Widget child;

  @override
  State<_EnrollmentDropZoneScope> createState() => _EnrollmentDropZoneScopeState();
}

class _EnrollmentDropZoneScopeState extends State<_EnrollmentDropZoneScope> {
  @override
  void initState() {
    super.initState();
    enrollment_drop.registerEnrollmentDropZone(
      context: context,
      onFileDropped: widget.onFileDropped,
      onUnsupportedFile: widget.onUnsupportedFile,
    );
  }

  @override
  void dispose() {
    enrollment_drop.unregisterEnrollmentDropZone();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _EditPersonalSheet extends StatelessWidget {
  const _EditPersonalSheet({
    required this.nameController,
    required this.phoneController,
    required this.addressController,
    required this.dobController,
    required this.linkedinController,
    required this.selectedGender,
    required this.onGenderChanged,
    required this.onSave,
    this.onTapDateOfBirth,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController dobController;
  final TextEditingController linkedinController;
  final String? selectedGender;
  final ValueChanged<String?> onGenderChanged;
  final VoidCallback onSave;
  final void Function(BuildContext context)? onTapDateOfBirth;

  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            text,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
          if (required)
            Text(
              ' *',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _kKhonologyRed),
            ),
        ],
      ),
    );
  }

  List<String> _getMissingRequiredFields() {
    final missing = <String>[];
    if (nameController.text.trim().isEmpty) missing.add('Full Name');
    if (phoneController.text.trim().isEmpty) missing.add('Phone');
    if (addressController.text.trim().isEmpty) missing.add('Address');
    if (dobController.text.trim().isEmpty) missing.add('Date of Birth');
    return missing;
  }

  void _showRequiredDialog(BuildContext context, List<String> missing) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Required fields'),
        content: Text(
          'Please fill in all required fields:\n${missing.join(', ')}',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: _kOnboardingCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit Personal Details',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 20),
            _label('Full Name', required: true),
            TextField(
              controller: nameController,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 16),
            _label('Phone', required: true),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 16),
            _label('Address', required: true),
            TextField(
              controller: addressController,
              maxLines: 2,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 16),
            _label('Date of Birth', required: true),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (onTapDateOfBirth != null) {
                  onTapDateOfBirth!(context);
                }
              },
              child: AbsorbPointer(
                absorbing: true,
                child: TextField(
                  controller: dobController,
                  readOnly: true,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Tap to pick date',
                    hintStyle: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    suffixIcon: Icon(Icons.calendar_today_rounded, color: Colors.white54, size: 22),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _label('LinkedIn Profile'),
            TextField(
              controller: linkedinController,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. https://linkedin.com/in/yourprofile',
                hintStyle: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 16),
            _label('Gender'),
            DropdownButtonFormField<String>(
              value: selectedGender?.isEmpty ?? true ? null : selectedGender,
              onChanged: onGenderChanged,
              dropdownColor: Colors.grey.shade900,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
              hint: Text('Select Gender', style: GoogleFonts.poppins(color: Colors.white54)),
              items: <String>['Male', 'Female', 'Other', 'Prefer not to say']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: GoogleFonts.poppins(color: Colors.white)),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
            onPressed: () {
              final missing = _getMissingRequiredFields();
              if (missing.isNotEmpty) {
                _showRequiredDialog(context, missing);
                return;
              }
              onSave();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kKhonologyRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
        ),
      ),
    );
  }
}

class _EditEducationSheet extends StatelessWidget {
  const _EditEducationSheet({
    required this.educationController,
    required this.universityController,
    required this.graduationYearController,
    required this.onSave,
  });

  final TextEditingController educationController;
  final TextEditingController universityController;
  final TextEditingController graduationYearController;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: _kOnboardingCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit Education',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: educationController,
            style: GoogleFonts.poppins(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Level / Degree',
              labelStyle: GoogleFonts.poppins(color: Colors.white70),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: universityController,
            style: GoogleFonts.poppins(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Institution',
              labelStyle: GoogleFonts.poppins(color: Colors.white70),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: graduationYearController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.poppins(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Graduation Year',
              labelStyle: GoogleFonts.poppins(color: Colors.white70),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              onSave();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kKhonologyRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _EditExperienceSheet extends StatelessWidget {
  const _EditExperienceSheet({
    required this.experienceController,
    required this.previousCompaniesController,
    required this.positionController,
    required this.onSave,
  });

  final TextEditingController experienceController;
  final TextEditingController previousCompaniesController;
  final TextEditingController positionController;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: _kOnboardingCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit Work Experience',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: positionController,
            style: GoogleFonts.poppins(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Position / Role',
              labelStyle: GoogleFonts.poppins(color: Colors.white70),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: previousCompaniesController,
            style: GoogleFonts.poppins(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Company',
              labelStyle: GoogleFonts.poppins(color: Colors.white70),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: experienceController,
            maxLines: 3,
            style: GoogleFonts.poppins(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Responsibilities / Description',
              labelStyle: GoogleFonts.poppins(color: Colors.white70),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              onSave();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kKhonologyRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
