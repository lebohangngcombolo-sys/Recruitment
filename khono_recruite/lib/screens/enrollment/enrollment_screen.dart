import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import 'enrollment_drop_stub.dart'
    if (dart.library.html) 'enrollment_drop_web.dart' as enrollment_drop;

/// Khonology theme for onboarding (match app).
const Color _kKhonologyRed = Color(0xFFC10D00);
const Color _kOnboardingCardBg = Color(0xFF2A2A2A);
const Color _kSuccess = Color(0xFF22C55E);

class EnrollmentScreen extends StatefulWidget {
  final String token;
  const EnrollmentScreen({super.key, required this.token});

  @override
  _EnrollmentScreenState createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen>
    with SingleTickerProviderStateMixin {
  bool _isDarkMode = true;

  Color get _enrollText => _isDarkMode ? Colors.white : const Color(0xFF090812);
  Color get _enrollMuted => _isDarkMode
      ? Colors.white70
      : const Color(0xFF090812).withValues(alpha: 0.72);
  Color get _enrollSoft => _isDarkMode
      ? Colors.white54
      : const Color(0xFF090812).withValues(alpha: 0.58);
  Color get _enrollCardBg => _isDarkMode
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.white.withValues(alpha: 0.74);
  Color get _enrollCardBorder => _isDarkMode
      ? Colors.white.withValues(alpha: 0.10)
      : const Color(0xFF090812).withValues(alpha: 0.20);
  Color get _enrollOverlay => _isDarkMode
      ? Colors.black.withValues(alpha: 0.4)
      : Colors.black.withValues(alpha: 0.06);

  late TabController _tabController;
  int currentStep = 0;
  bool loading = false;
  bool profileLoading = false;
  bool _loggingIn = false;
  String? userName;
  String? userEmail;
  PlatformFile? selectedCV;

  // --- 3-step onboarding flow ---
  /// 0 = CV Upload, 1 = Processing, 2 = Review. When true, user chose "Fill out manually" and we show the 4-step form.
  bool _choseManual = false;
  int _onboardingStep = 0;
  int _processingStage =
      0; // 0..3 for Reading, Education, Experience, Finalizing
  bool _processingComplete = false;
  bool _processingError = false;
  bool _processingStarted = false;

  final ScrollController _scrollController = ScrollController();
  final ScrollController _step3SectionScrollController = ScrollController();
  bool _isProgressCollapsed = false;

  /// True when CV parse/upload failed; drop zone border shows red. Cleared when user selects a new file.
  bool _cvUploadFailed = false;
  String _step3ActiveSection = 'personal';
  List<String> _parsedSkills = [];
  List<Map<String, String>> _parsedEducation = [];
  List<Map<String, String>> _parsedExperience = [];
  Map<String, dynamic>? _backendCareerSummary;

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
        debugPrint(
            "getCurrentUser timed out after ${timeoutDuration.inSeconds}s");
        throw TimeoutException('Profile load timed out', timeoutDuration);
      });
      if (!mounted) return;
      // Do not use profile when token expired or unauthorized
      if (profile['unauthorized'] == true ||
          (profile['error'] != null && !profile.containsKey('user'))) {
        debugPrint("Profile load skipped (unauthorized or token expired)");
        return;
      }

      final cachedName = AuthService.getCachedDisplayName();

      String? resolvedName = profile['user']?['profile']?['full_name'] ??
          profile['full_name'] ??
          profile['name'];
      if (resolvedName == null || resolvedName.trim().isEmpty) {
        resolvedName = cachedName;
      }
      if (resolvedName == null || resolvedName.trim().isEmpty) {
        resolvedName = await AuthService.getPersistedDisplayName();
      }

      final resolvedEmail = profile['user']?['email'] ??
          profile['email'] ??
          profile['user']?['profile']?['email'];

      setState(() {
        userName = resolvedName?.toString().trim();
        userEmail = resolvedEmail?.toString();
        if (userName != null && userName!.isNotEmpty) {
          nameController.text = userName!;
        }
      });
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
      try {
        final localUser = await AuthService.getUserInfo();
        if (localUser != null && mounted) {
          final user = localUser['user'] ?? localUser;
          final profile =
              user is Map<String, dynamic> ? (user['profile'] ?? {}) : {};
          final candidateProfile =
              localUser['candidate_profile'] ?? localUser['candidate'] ?? {};

          final cachedName = AuthService.getCachedDisplayName();
          String? resolvedName = localUser['full_name']?.toString() ??
              localUser['name']?.toString() ??
              (candidateProfile is Map
                  ? candidateProfile['full_name']?.toString()
                  : null) ??
              (profile is Map ? profile['full_name']?.toString() : null) ??
              cachedName;

          setState(() {
            userName = resolvedName?.trim();
            userEmail = localUser['email']?.toString() ??
                (user is Map ? user['email']?.toString() : null);
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
        if (educationController.text.trim().isEmpty)
          missing.add('Education Level');
        if (universityController.text.trim().isEmpty)
          missing.add('University/College');
        if (graduationYearController.text.trim().isEmpty)
          missing.add('Graduation Year');
        break;
      case 2:
        if (skillsController.text.trim().isEmpty) missing.add('Skills');
        break;
      case 3:
        if (experienceController.text.trim().isEmpty)
          missing.add('Work Experience');
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

  Future<void> _completeEnrollmentInBackground(
      Map<String, dynamic> data) async {
    try {
      final response = await AuthService.completeEnrollment(widget.token, data);
      if (response.containsKey('error')) {
        final message = response['error']?.toString() ?? 'Enrollment failed';
        debugPrint(
            'Enrollment background error: $message; details: ${response['details']}');
        return;
      }
      await AuthService.getCurrentUser(token: widget.token)
          .catchError((_) => <String, dynamic>{});
    } catch (e) {
      debugPrint('Enrollment background request failed: $e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void submitEnrollment() async {
    if (loading) return;
    if (!mounted) return;
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

    // Make "Finish" feel instant: navigate now, complete enrollment in background.
    setState(() => _loggingIn = true);
    unawaited(_completeEnrollmentInBackground(data));
    context.go(
      '/candidate-dashboard?token=${Uri.encodeComponent(widget.token)}',
    );
  }

  // ------------------- Onboarding step builders -------------------
  Widget _buildProgressIndicator() {
    const labels = ['Upload CV', 'Processing', 'Profile Summary'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: _enrollText, size: 24),
            onPressed: () => context.go('/login'),
            tooltip: 'Back to login',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: List.generate(labels.length, (index) {
                final isDone = index < _onboardingStep;
                final isCurrent = index == _onboardingStep;
                final tone = (isDone || isCurrent) ? _kKhonologyRed : _enrollSoft;
                return Expanded(
                  child: InkWell(
                    onTap: index <= _onboardingStep
                        ? () => setState(() => _onboardingStep = index)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCurrent ? tone : tone.withValues(alpha: 0.18),
                              border: Border.all(color: tone, width: 1.2),
                            ),
                            alignment: Alignment.center,
                            child: isDone
                                ? const Icon(Icons.check, size: 12, color: Colors.white)
                                : Text(
                                    '${index + 1}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isCurrent ? Colors.white : tone,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              labels[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color:
                                    (isDone || isCurrent) ? _enrollText : _enrollMuted,
                                fontWeight:
                                    isCurrent ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Your data is secure',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _enrollMuted,
            ),
          ),
        ],
      ),
    );
  }

  static const EdgeInsets _cardMargin =
      EdgeInsets.symmetric(horizontal: 24, vertical: 16);
  static const EdgeInsets _cardMarginInRow =
      EdgeInsets.symmetric(horizontal: 12, vertical: 16);

  Widget _buildOnboardingCard(
      {required Widget child, double maxWidth = 560, bool flexible = false}) {
    final container = Container(
      width: double.infinity,
      margin: flexible ? _cardMarginInRow : _cardMargin,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _enrollCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _enrollCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    final glass = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: container,
      ),
    );
    if (flexible) return glass;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: glass,
      ),
    );
  }

  static const _supportedCVExtensions = ['pdf', 'doc', 'docx', 'txt'];

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
        backgroundColor: _isDarkMode
            ? _kOnboardingCardBg
            : Colors.white.withValues(alpha: 0.96),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _kKhonologyRed, size: 28),
            const SizedBox(width: 12),
            Text(
              'Unsupported file',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _enrollText,
              ),
            ),
          ],
        ),
        content: Text(
          'Please upload a supported document (.pdf, .doc, .docx, .txt).',
          style: GoogleFonts.poppins(
              fontSize: 14, color: _enrollMuted, height: 1.4),
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

  Future<void> _pickCVFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _supportedCVExtensions,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (!_isSupportedCVFile(file.name)) {
        _showUnsupportedFileMessage();
        return;
      }
      _onCVFileReceived(file);
    }
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
        : (hasFile
            ? _kSuccess
            : (_isDarkMode
                ? Colors.white24
                : const Color(0xFF090812).withValues(alpha: 0.24)));
    final Color iconColor =
        _cvUploadFailed ? _kKhonologyRed : (hasFile ? _kSuccess : _enrollSoft);
    return GestureDetector(
      onTap: _pickCVFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
        decoration: BoxDecoration(
          color: _enrollCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: 1.6,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: hasFile
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 40, color: _kSuccess),
                  const SizedBox(height: 10),
                  Text(
                    selectedCV!.name,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: _enrollText,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _enrollMuted,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Icon(Icons.upload_file_outlined, size: 44, color: iconColor),
                  const SizedBox(height: 12),
                  Text(
                    'Drag & drop your CV here',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: _enrollText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'or',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: _enrollMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _pickCVFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kKhonologyRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Choose File',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'PDF, DOCX or TXT (Max 10MB)',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: _enrollSoft,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Focused one-step-at-a-time onboarding.
  Widget _buildSteps1And2SideBySide() {
    return _EnrollmentDropZoneScope(
      onFileDropped: (file) => _onCVFileReceived(file),
      onUnsupportedFile: _showUnsupportedFileMessage,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildProgressIndicator(),
            _buildOnboardingCard(
              maxWidth: 980,
              child: _onboardingStep == 0
                  ? _buildStep1CardContent()
                  : _buildStep2CardContent(),
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
          'Set up your profile',
          style: GoogleFonts.poppins(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: _enrollText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload your CV to automatically create your profile and match you with relevant opportunities.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: _enrollMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: _buildDropZone()),
            const SizedBox(width: 16),
            Container(
              width: 1,
              height: 180,
              color: _enrollCardBorder,
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 6,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: _isDarkMode ? 0.16 : 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _enrollCardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _helperBullet('Your profile will be auto-filled'),
                    const SizedBox(height: 10),
                    _helperBullet('You will only see relevant job opportunities'),
                    const SizedBox(height: 10),
                    _helperBullet('You can edit everything later'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _choseManual = true),
            child: Text(
              'I prefer to enter details manually',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: _enrollText,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: selectedCV != null && selectedCV!.bytes != null
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Continue',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildStep2CardContent() {
    const stages = [
      'Reading your CV',
      'Identifying your skills',
      'Understanding your work experience',
      'Determining your role and level',
      'Preparing your job matches',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Text(
            'Analyzing your experience...',
            style: GoogleFonts.poppins(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: _enrollText,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'This may take a few moments.',
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: _enrollMuted,
            ),
          ),
        ),
        const SizedBox(height: 28),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: _isDarkMode ? 0.16 : 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _enrollCardBorder),
            ),
            child: Column(
              children: List.generate(stages.length, (i) {
                final done = _processingComplete ? true : i < _processingStage;
                final current = !_processingComplete && i == _processingStage;
                return Padding(
                  padding: EdgeInsets.only(bottom: i == stages.length - 1 ? 0 : 12),
                  child: Row(
                    children: [
                      Icon(
                        done ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 22,
                        color: done
                            ? _kSuccess
                            : (current ? const Color(0xFF3B82F6) : _enrollSoft),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          stages[i],
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: current ? FontWeight.w600 : FontWeight.w500,
                            color: done
                                ? _enrollText
                                : (current ? _enrollText : _enrollMuted),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'This helps us match you with the right opportunities from the start.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            color: _enrollMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _processingComplete
                  ? 1.0
                  : (_processingStage + 1) / stages.length,
              minHeight: 6,
              backgroundColor: _isDarkMode
                  ? Colors.white24
                  : const Color(0xFF090812).withValues(alpha: 0.24),
              valueColor: const AlwaysStoppedAnimation<Color>(_kKhonologyRed),
            ),
          ),
        ),
        if (_processingComplete || _processingError) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () => setState(() => _onboardingStep = 2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kKhonologyRed,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Review Profile',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
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

  Widget _helperBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: _kKhonologyRed.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.check, size: 12, color: _kKhonologyRed),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: _enrollMuted,
            ),
          ),
        ),
      ],
    );
  }

  List<String> _allSkills() {
    final fromParsed = _parsedSkills;
    final fromText = skillsController.text
        .split(RegExp(r'[,;\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    return {...fromParsed, ...fromText}.toList();
  }

  double _estimatedExperienceYears() {
    final buffer = StringBuffer(experienceController.text);
    for (final e in _parsedExperience) {
      buffer
        ..write(' ')
        ..write(e['duration'] ?? '')
        ..write(' ')
        ..write(e['description'] ?? '');
    }
    final text = buffer.toString();

    double best = 0;
    final directYears = RegExp(
      r'(\d{1,2}(?:\.\d+)?)\s*\+?\s*(years?|yrs?)',
      caseSensitive: false,
    ).allMatches(text);
    for (final m in directYears) {
      final v = double.tryParse(m.group(1) ?? '');
      if (v != null && v > best) best = v;
    }

    final yearRanges = RegExp(
      r'((?:19|20)\d{2})\s*[-/]\s*((?:19|20)\d{2}|present|current)',
      caseSensitive: false,
    ).allMatches(text);
    final nowYear = DateTime.now().year;
    for (final m in yearRanges) {
      final start = int.tryParse(m.group(1) ?? '');
      final endRaw = (m.group(2) ?? '').toLowerCase();
      final end = (endRaw == 'present' || endRaw == 'current')
          ? nowYear
          : int.tryParse(endRaw);
      if (start != null && end != null && end >= start) {
        final years = (end - start + 1).toDouble();
        if (years > best) best = years;
      }
    }
    return best;
  }

  String _derivePrimaryRole() {
    final backendRole = _backendCareerSummary?['primary_role']?.toString().trim() ?? '';
    if (backendRole.isNotEmpty) return backendRole;
    final parsedRole = _parsedExperience
        .map((e) => (e['position'] ?? '').trim())
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (parsedRole.isNotEmpty) return parsedRole;

    final position = positionController.text.trim();
    if (position.isNotEmpty) return position;

    final skills = _allSkills().map((s) => s.toLowerCase()).join(' ');
    if (skills.contains('react') || skills.contains('frontend')) {
      return 'Frontend Developer';
    }
    if (skills.contains('flutter') || skills.contains('dart')) {
      return 'Mobile Developer';
    }
    if (skills.contains('python') ||
        skills.contains('node') ||
        skills.contains('api')) {
      return 'Software Engineer';
    }
    if (skills.contains('ui') || skills.contains('ux')) return 'UI Engineer';
    return 'Software Professional';
  }

  String _deriveExperienceLevel() {
    final backendLevel =
        _backendCareerSummary?['experience_level']?.toString().trim() ?? '';
    if (backendLevel.isNotEmpty) return backendLevel;
    final years = _estimatedExperienceYears();
    if (years <= 0) return 'Entry-level';
    if (years < 2) return 'Junior';
    if (years < 6) return 'Mid-level';
    return 'Senior';
  }

  int _profileReadiness() {
    final backendReadiness = _backendCareerSummary?['profile_readiness'];
    if (backendReadiness != null) {
      final parsed = int.tryParse(backendReadiness.toString());
      if (parsed != null) {
        return parsed.clamp(0, 100);
      }
    }
    final checks = [
      nameController.text.trim().isNotEmpty,
      (userEmail?.trim().isNotEmpty ?? false),
      skillsController.text.trim().isNotEmpty,
      experienceController.text.trim().isNotEmpty ||
          positionController.text.trim().isNotEmpty,
      educationController.text.trim().isNotEmpty ||
          universityController.text.trim().isNotEmpty,
    ];
    final filled = checks.where((c) => c).length;
    return ((filled / checks.length) * 100).round();
  }

  List<String> _recommendedRoles(String role) {
    final backendRolesRaw = _backendCareerSummary?['recommended_roles'];
    if (backendRolesRaw is List) {
      final backendRoles = backendRolesRaw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (backendRoles.isNotEmpty) return backendRoles;
    }
    final r = role.toLowerCase();
    final skills = _allSkills().map((s) => s.toLowerCase()).toList();
    final roles = <String>{role};

    if (r.contains('frontend') ||
        skills.any((s) => s.contains('react') || s.contains('javascript'))) {
      roles.addAll(['Frontend Developer', 'React Developer', 'UI Engineer']);
    }
    if (skills.any((s) =>
        s.contains('flutter') ||
        s.contains('android') ||
        s.contains('ios') ||
        s.contains('dart'))) {
      roles.addAll(['Mobile Developer', 'Flutter Developer']);
    }
    if (skills.any((s) =>
        s.contains('python') ||
        s.contains('sql') ||
        s.contains('api') ||
        s.contains('node'))) {
      roles.addAll(['Software Engineer', 'Backend Developer']);
    }
    if (roles.length < 3) {
      roles.addAll(['Software Engineer', 'Product Support Engineer']);
    }
    return roles.take(3).toList();
  }

  String _buildCareerSummaryNarrative(String role, String level) {
    final backendSummary = _backendCareerSummary?['summary_text']?.toString().trim() ?? '';
    if (backendSummary.isNotEmpty) return backendSummary;
    final skills = _allSkills().map((s) => s.toLowerCase()).toList();
    final hasEducation = _parsedEducation.isNotEmpty ||
        educationController.text.trim().isNotEmpty ||
        universityController.text.trim().isNotEmpty;
    final hasBackend = skills.any((s) =>
        s.contains('node') ||
        s.contains('python') ||
        s.contains('java') ||
        s.contains('api'));
    final hasFrontend = skills.any((s) =>
        s.contains('react') ||
        s.contains('ui') ||
        s.contains('ux') ||
        s.contains('frontend'));

    if (hasFrontend && !hasBackend) {
      return hasEducation
          ? 'You show a strong $level profile for $role roles, with your education and experience weighted more toward frontend delivery than backend systems.'
          : 'You show a strong $level profile for $role roles, with your experience weighted more toward frontend delivery than backend systems.';
    }
    if (hasBackend && !hasFrontend) {
      return hasEducation
          ? 'You show a strong $level profile for $role roles, with practical backend depth supported by your education and room to broaden frontend-facing delivery.'
          : 'You show a strong $level profile for $role roles, with practical backend depth and room to broaden frontend-facing delivery.';
    }
    return 'You show a balanced $level profile for $role roles, with experience that supports matching to relevant opportunities.';
  }

  Widget _buildProfileRowCard({
    required String title,
    required String value,
    VoidCallback? onEdit,
    int? maxLines = 2,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.04),
        border: Border.all(color: _enrollCardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: _enrollSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: maxLines,
                  overflow:
                      maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: _enrollText,
                    fontWeight: FontWeight.w500,
                  ),
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
                  fontSize: 11.5,
                  color: _kKhonologyRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep3NavItem(
    String keyValue,
    String label,
    IconData icon,
  ) {
    final active = _step3ActiveSection == keyValue;
    return InkWell(
      onTap: () {
        setState(() => _step3ActiveSection = keyValue);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_step3SectionScrollController.hasClients) return;
          _step3SectionScrollController.jumpTo(0);
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: active
              ? _kKhonologyRed.withValues(alpha: 0.14)
              : Colors.transparent,
          border: Border.all(
            color: active
                ? _kKhonologyRed.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              active ? icon : Icons.chevron_right,
              size: 14,
              color: active ? _kKhonologyRed : _enrollMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? _enrollText : _enrollMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3SectionBody() {
    final textStyle = GoogleFonts.poppins(fontSize: 12.5, color: _enrollMuted);
    if (_step3ActiveSection == 'skills') {
      final skills = _parsedSkills.isNotEmpty
          ? _parsedSkills
          : skillsController.text
              .split(RegExp(r'[,;\n]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
      if (skills.isEmpty) return Text('No skills extracted yet.', style: textStyle);
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: skills
            .map(
              (s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _enrollCardBorder),
                ),
                child: Text(s,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: _enrollText, fontWeight: FontWeight.w500)),
              ),
            )
            .toList(),
      );
    }

    if (_step3ActiveSection == 'experience') {
      if (_parsedExperience.isEmpty) {
        return Text(
          experienceController.text.trim().isEmpty
              ? 'No work experience extracted yet.'
              : experienceController.text.trim(),
          style: textStyle,
        );
      }
      return Column(
        children: _parsedExperience
            .map(
              (item) => _buildProfileRowCard(
                title:
                    '${item['position'] ?? 'Role'}${(item['company'] ?? '').isNotEmpty ? ' - ${item['company']}' : ''}',
                value: (item['description'] ?? '').isNotEmpty
                    ? item['description']!
                    : (item['duration'] ?? 'No description provided'),
                maxLines: 3,
              ),
            )
            .toList(),
      );
    }

    if (_step3ActiveSection == 'education') {
      if (_parsedEducation.isEmpty) {
        return Text(
          educationController.text.trim().isEmpty &&
                  universityController.text.trim().isEmpty
              ? 'No education extracted yet.'
              : '${educationController.text.trim()} ${universityController.text.trim()}',
          style: textStyle,
        );
      }
      return Column(
        children: _parsedEducation
            .map(
              (item) => _buildProfileRowCard(
                title: item['level'] ?? 'Education',
                value:
                    '${item['institution'] ?? 'Institution not provided'}${(item['graduation_year'] ?? '').isNotEmpty ? ' • ${item['graduation_year']}' : ''}',
                maxLines: 4,
              ),
            )
            .toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileRowCard(
          title: 'Full Name',
          value: nameController.text.trim().isEmpty
              ? 'Not provided'
              : nameController.text.trim(),
        ),
        _buildProfileRowCard(
          title: 'Email Address',
          value: (userEmail ?? '').trim().isEmpty
              ? 'Not provided'
              : userEmail!.trim(),
        ),
        _buildProfileRowCard(
          title: 'Phone Number',
          value: phoneController.text.trim().isEmpty
              ? 'Not provided'
              : phoneController.text.trim(),
        ),
      ],
    );
  }

  Widget _buildStep3CareerSummary() {
    final primaryRole = _derivePrimaryRole();
    final level = _deriveExperienceLevel();
    final readiness = _profileReadiness();
    final recommended = _recommendedRoles(primaryRole);
    final careerNarrative = _buildCareerSummaryNarrative(primaryRole, level);

    return SafeArea(
      child: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _enrollCardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _enrollCardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(_isDarkMode ? 0.25 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Text(
                  'Review your profile',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _enrollText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We\'ve extracted information from your CV. Please review and edit if needed.',
                  style: GoogleFonts.poppins(fontSize: 12, color: _enrollMuted),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 190,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: _enrollCardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _enrollCardBorder),
                      ),
                      child: Column(
                        children: [
                          _buildStep3NavItem(
                              'personal', 'Personal Info', Icons.person_outline),
                          _buildStep3NavItem('skills', 'Skills', Icons.build_outlined),
                          _buildStep3NavItem('experience', 'Experience',
                              Icons.work_outline_rounded),
                          _buildStep3NavItem(
                              'education', 'Education', Icons.school_outlined),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _enrollCardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _enrollCardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _step3ActiveSection == 'personal'
                                        ? 'Personal Information'
                                        : (_step3ActiveSection == 'skills'
                                            ? 'Skills'
                                            : (_step3ActiveSection == 'experience'
                                                ? 'Work Experience'
                                                : 'Education')),
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _enrollText,
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _showStep3EditMenu(context),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: _enrollCardBorder),
                                    foregroundColor: _kKhonologyRed,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(Icons.edit, size: 14),
                                  label: Text(
                                    'Edit',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Scrollbar(
                                controller: _step3SectionScrollController,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _step3SectionScrollController,
                                  child: _buildStep3SectionBody(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B8B43).withValues(
                                    alpha: _isDarkMode ? 0.18 : 0.10),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF1B8B43)
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                'Profile looks good. You can edit any section if needed.',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: _isDarkMode
                                      ? Colors.green.shade100
                                      : const Color(0xFF166534),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _enrollCardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _enrollCardBorder),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Career Summary',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _enrollText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.black.withValues(
                                      alpha: _isDarkMode ? 0.15 : 0.03),
                                  border: Border.all(color: _enrollCardBorder),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Primary Role\n$primaryRole',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: _enrollText,
                                          fontWeight: FontWeight.w600,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Experience Level\n$level',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: _enrollMuted,
                                          fontWeight: FontWeight.w600,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.black.withValues(
                                      alpha: _isDarkMode ? 0.15 : 0.03),
                                  border: Border.all(color: _enrollCardBorder),
                                ),
                                child: Text(
                                  'Profile Readiness: $readiness%',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: _enrollText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                careerNarrative,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: _enrollMuted,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Recommended Roles For You',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _enrollText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: recommended
                                    .map(
                                      (r) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          color: const Color(0xFF1B8B43)
                                              .withValues(alpha: 0.10),
                                          border: Border.all(
                                            color: const Color(0xFF1B8B43)
                                                .withValues(alpha: 0.28),
                                          ),
                                        ),
                                        child: Text(
                                          r,
                                          style: GoogleFonts.poppins(
                                            fontSize: 10.5,
                                            color: _enrollText,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.04),
                    border: Border.all(color: _enrollCardBorder),
                  ),
                  child: Text(
                    'You will now be taken to your dashboard where you can explore opportunities matched to your profile. We prioritise roles that match your experience to help you focus on the best opportunities.',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: _enrollMuted,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: loading ? null : submitEnrollment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kKhonologyRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Continue to Dashboard',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  // ignore: unused_element
  Widget _buildEmptySection(
      String message, String buttonLabel, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _enrollSoft,
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


  // ignore: unused_element
  void _showEditPersonal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditPersonalSheet(
        isDarkMode: _isDarkMode,
        nameController: nameController,
        phoneController: phoneController,
        addressController: addressController,
        linkedinController: linkedinController,
        onSave: () => setState(() {}),
      ),
    ).then((_) => setState(() {}));
  }

  // ignore: unused_element
  void _showEditEducation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditEducationSheet(
        isDarkMode: _isDarkMode,
        educationController: educationController,
        universityController: universityController,
        graduationYearController: graduationYearController,
        onSave: () => setState(() {}),
      ),
    ).then((_) => setState(() {}));
  }

  // ignore: unused_element
  void _showEditExperience(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditExperienceSheet(
        isDarkMode: _isDarkMode,
        experienceController: experienceController,
        previousCompaniesController: previousCompaniesController,
        positionController: positionController,
        onSave: () => setState(() {}),
      ),
    ).then((_) => setState(() {}));
  }

  void _showEditSkills(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditSkillsSheet(
        isDarkMode: _isDarkMode,
        skillsController: skillsController,
        onSave: () => setState(() {}),
      ),
    ).then((_) => setState(() {}));
  }

  void _showStep3EditMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? const Color(0xFF11131A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        TextStyle titleStyle = GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _enrollText,
        );
        TextStyle itemStyle = GoogleFonts.poppins(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: _enrollText,
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit profile section', style: titleStyle),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Personal information', style: itemStyle),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showEditPersonal(context);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Skills', style: itemStyle),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showEditSkills(context);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Work experience', style: itemStyle),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showEditExperience(context);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Education', style: itemStyle),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showEditEducation(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _enrollText,
              fontFamily: 'Poppins',
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: _enrollMuted,
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _enrollText,
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
              color: _isDarkMode
                  ? Colors.white38
                  : const Color(0xFF090812).withValues(alpha: 0.24),
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
            style: TextStyle(
              fontSize: 14,
              color: _enrollText,
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
                        color: _enrollSoft,
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
    final value =
        controller.text.trim().isEmpty ? null : controller.text.trim();
    final effectiveItems =
        (value != null && !items.contains(value)) ? [value, ...items] : items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _enrollText,
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
              color: _isDarkMode
                  ? Colors.white38
                  : const Color(0xFF090812).withValues(alpha: 0.24),
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
            dropdownColor: _isDarkMode ? Colors.grey[900] : Colors.white,
            style: TextStyle(
              fontSize: 14,
              color: _enrollText,
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
                  color: _enrollSoft,
                  size: 24,
                ),
              ),
            ),
            hint: Text(
              'Select $label',
              style: TextStyle(
                color: _enrollSoft,
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _enrollText,
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _enrollText,
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
                color: _isDarkMode
                    ? Colors.white38
                    : const Color(0xFF090812).withValues(alpha: 0.24),
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
                style: TextStyle(
                  fontSize: 14,
                  color: _enrollText,
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
                      color: _enrollSoft,
                      size: 20,
                    ),
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: _enrollSoft,
                      size: 24,
                    ),
                  ),
                  hintText: "Select your date of birth",
                  hintStyle: TextStyle(
                    color: _enrollSoft,
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
        Text(
          "Gender",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _enrollText,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: boxFillColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isDarkMode
                  ? Colors.white38
                  : const Color(0xFF090812).withValues(alpha: 0.24),
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
            dropdownColor: _isDarkMode ? Colors.grey[900] : Colors.white,
            style: TextStyle(
              fontSize: 14,
              color: _enrollText,
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
                  color: _enrollSoft,
                  size: 20,
                ),
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: _enrollSoft,
                  size: 24,
                ),
              ),
            ),
            hint: Text(
              "Select Gender",
              style: TextStyle(
                color: _enrollSoft,
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _enrollText,
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
    final themeProvider = context.watch<ThemeProvider>();
    _isDarkMode = themeProvider.isDarkMode;

    if (!_choseManual) {
      return Scaffold(
        backgroundColor: _isDarkMode ? const Color(0xFF0F1218) : const Color(0xFFF3F5F8),
        body: profileLoading
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
                        color: _enrollMuted,
                      ),
                    ),
                  ],
                ),
              )
            : _onboardingStep < 2
                ? _buildSteps1And2SideBySide()
                : _buildStep3CareerSummary(),
      );
    }

    final pageBackground = themeProvider.backgroundImage;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(pageBackground),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            color: _enrollOverlay,
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
                        _loggingIn
                            ? "Logging in..."
                            : "Loading Enrollment Form...",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _enrollText,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back,
                                color: _enrollText, size: 26),
                            onPressed: () =>
                                setState(() => _choseManual = false),
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
                                                ? _enrollText
                                                : _enrollMuted,
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                              child: _buildTextField(
                                                  addressController, "Address",
                                                  required: true)),
                                          const SizedBox(width: 16),
                                          Expanded(
                                              child: _buildDateOfBirthField(
                                                  required: true)),
                                        ],
                                      ),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                              child: _buildTextField(
                                                  linkedinController,
                                                  "LinkedIn Profile")),
                                          const SizedBox(width: 16),
                                          Expanded(
                                              child: _buildGenderDropdown()),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                          maxLines: 3, required: true),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                              child: _buildTextField(
                                                  previousCompaniesController,
                                                  "Previous Companies")),
                                          const SizedBox(width: 16),
                                          Expanded(
                                              child: _buildTextField(
                                                  positionController,
                                                  "Position",
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
    _step3SectionScrollController.dispose();
    super.dispose();
  }

  /// Backend HF mapper returns `work_experience` (list of maps); legacy parser uses
  /// `experience` / `position` / `previous_companies`. Normalize so the review step
  /// receives the same shape the UI already expects.
  Map<String, dynamic> _normalizeCvParseResponse(Map<String, dynamic> raw) {
    final out = Map<String, dynamic>.from(raw);

    void pickName() {
      final existing = out['full_name']?.toString().trim() ?? '';
      if (existing.isNotEmpty) return;
      for (final key in ['name', 'candidate_name']) {
        final v = out[key]?.toString().trim();
        if (v != null && v.isNotEmpty) {
          out['full_name'] = v;
          return;
        }
      }
      final sd = out['structured_data'];
      if (sd is Map) {
        final pd = sd['personal_details'];
        if (pd is Map) {
          for (final key in ['full_name', 'name', 'candidate_name']) {
            final fn = pd[key]?.toString().trim();
            if (fn != null && fn.isNotEmpty) {
              out['full_name'] = fn;
              break;
            }
          }
        }
      }
    }

    void mergeStructuredLists() {
      final sd = out['structured_data'];
      if (sd is! Map) return;
      final eduDetails = sd['education_details'];
      if (eduDetails is Map && out['education'] == null) {
        final e = eduDetails['education'];
        if (e is List && e.isNotEmpty) out['education'] = e;
      }
      final prof = sd['professional_details'];
      if (prof is Map) {
        if (out['skills'] == null && prof['skills'] != null) {
          out['skills'] = prof['skills'];
        }
        if (out['experience'] == null && prof['experience'] != null) {
          out['experience'] = prof['experience'];
        }
        if (out['position'] == null && prof['position'] != null) {
          out['position'] = prof['position'];
        }
        if (out['previous_companies'] == null &&
            prof['previous_companies'] != null) {
          out['previous_companies'] = prof['previous_companies'];
        }
        if (out['work_experience'] == null && prof['work_experience'] != null) {
          out['work_experience'] = prof['work_experience'];
        }
      }
    }

    void flattenWorkExperienceList() {
      final wx = out['work_experience'];
      if (wx is! List || wx.isEmpty) return;
      final rows = <Map<String, dynamic>>[];
      for (final e in wx) {
        if (e is Map) rows.add(Map<String, dynamic>.from(e));
      }
      if (rows.isEmpty) return;

      String s(dynamic v) => v?.toString().trim() ?? '';

      final prevEmpty = out['previous_companies'] == null ||
          out['previous_companies'].toString().trim().isEmpty;
      final posEmpty =
          out['position'] == null || out['position'].toString().trim().isEmpty;
      final expEmpty = out['experience'] == null ||
          out['experience'].toString().trim().isEmpty;

      if (prevEmpty) {
        final companies = <String>[];
        for (final m in rows) {
          final c = s(m['company']);
          if (c.isNotEmpty) companies.add(c);
        }
        if (companies.isNotEmpty) {
          out['previous_companies'] = companies.toSet().join(', ');
        }
      }
      if (posEmpty) {
        for (final m in rows) {
          final p =
              s(m['position']).isNotEmpty ? s(m['position']) : s(m['title']);
          if (p.isNotEmpty) {
            out['position'] = p;
            break;
          }
        }
      }
      if (expEmpty) {
        final descs = <String>[];
        for (final m in rows) {
          final d = s(m['description']);
          if (d.isNotEmpty) descs.add(d);
        }
        if (descs.isNotEmpty) out['experience'] = descs.join('\n\n');
      }
    }

    pickName();
    mergeStructuredLists();
    flattenWorkExperienceList();
    return out;
  }

  bool _hasMeaningfulParsedData(Map<String, dynamic> data) {
    bool nonEmptyText(dynamic v) => v is String && v.trim().isNotEmpty;
    bool nonEmptyList(dynamic v) => v is List && v.isNotEmpty;

    const textKeys = [
      'full_name',
      'email',
      'phone',
      'address',
      'linkedin',
      'experience',
      'position',
      'previous_companies',
      'bio',
      'gender',
      'dob',
    ];
    for (final k in textKeys) {
      if (nonEmptyText(data[k])) return true;
    }

    if (nonEmptyText(data['cv_text']) &&
        (data['cv_text'] as String).trim().length >= 40) {
      return true;
    }

    const listKeys = [
      'education',
      'skills',
      'certifications',
      'languages',
      'work_experience',
    ];
    for (final k in listKeys) {
      if (nonEmptyList(data[k])) return true;
    }

    return false;
  }

  Future<void> _runProcessingAndGoToReview() async {
    if (selectedCV == null || selectedCV!.bytes == null) return;
    setState(() {
      _processingStage = 0;
      _processingComplete = false;
      _processingError = false;
      loading = true;
    });
    const stages = [
      'Reading Your CV',
      'Extracting Education…',
      'Extracting Work Experience…',
      'Finalizing…'
    ];
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
      ).timeout(
        const Duration(seconds: 120),
        onTimeout: () => {
          'error':
              'CV analysis timed out. You can still continue and enter your details manually.',
        },
      );
      if (!mounted) return;
      final cvDbg = response['cv_parse_debug'];
      if (cvDbg != null) {
        debugPrint('cv_parse_debug: $cvDbg');
      }
      if (response.containsKey('error')) {
        setState(() {
          _processingError = true;
          _cvUploadFailed = true;
          _processingComplete = true;
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
      Map<String, dynamic> normalized;
      try {
        normalized = _normalizeCvParseResponse(
            Map<String, dynamic>.from(response));
      } catch (_) {
        setState(() {
          _processingError = true;
          _cvUploadFailed = true;
          _processingComplete = true;
          loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unexpected response from CV service. Tap Next to continue manually.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange.shade800,
          ),
        );
        return;
      }
      if (!_hasMeaningfulParsedData(normalized)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'We could not extract much from this CV. Tap Next to review and fill in manually.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      String asText(dynamic v) => v?.toString().trim() ?? '';
      setState(() {
        List<String> toStringList(dynamic v) {
          if (v is List) {
            return v
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
          final text = asText(v);
          if (text.isEmpty) return [];
          return text
              .split(RegExp(r'[,;\n]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }

        List<Map<String, String>> toEducationRows(dynamic v) {
          if (v is! List) return [];
          return v
              .whereType<Map>()
              .map((m) => {
                    'level': asText(m['level']).isNotEmpty
                        ? asText(m['level'])
                        : asText(m['degree']),
                    'institution': asText(m['institution']).isNotEmpty
                        ? asText(m['institution'])
                        : (asText(m['university']).isNotEmpty
                            ? asText(m['university'])
                            : asText(m['school'])),
                    'graduation_year': asText(m['graduation_year']).isNotEmpty
                        ? asText(m['graduation_year'])
                        : asText(m['year']),
                  })
              .toList();
        }

        List<Map<String, String>> toExperienceRows(dynamic v) {
          if (v is! List) return [];
          return v
              .whereType<Map>()
              .map((m) => {
                    'company': asText(m['company']),
                    'position': asText(m['position']).isNotEmpty
                        ? asText(m['position'])
                        : asText(m['title']),
                    'duration': asText(m['duration']),
                    'description': asText(m['description']),
                  })
              .toList();
        }

        final fullName = asText(normalized['full_name']);
        if (fullName.isNotEmpty) {
          nameController.text = fullName;
          userName = fullName;
        }
        final phone = asText(normalized['phone']);
        if (phone.isNotEmpty) phoneController.text = phone;
        final address = asText(normalized['address']);
        if (address.isNotEmpty) addressController.text = address;
        final dob = asText(normalized['dob']);
        if (dob.isNotEmpty) dobController.text = dob;
        final linkedin = asText(normalized['linkedin']);
        if (linkedin.isNotEmpty) linkedinController.text = linkedin;

        // Add gender auto-population
        final genderFromCV = asText(normalized['gender']);
        if (genderFromCV.isNotEmpty) {
          selectedGender = genderFromCV;
        }

        // Handle education as list of objects with proper key mapping
        if (normalized['education'] is List &&
            (normalized['education'] as List).isNotEmpty) {
          final eduList = normalized['education'] as List;
          final firstEdu = eduList[0];
          if (firstEdu is Map) {
            educationController.text = firstEdu['level']?.toString() ??
                firstEdu['degree']?.toString() ??
                '';
            universityController.text = firstEdu['institution']?.toString() ??
                firstEdu['university']?.toString() ??
                firstEdu['school']?.toString() ??
                '';
            graduationYearController.text =
                firstEdu['graduation_year']?.toString() ??
                    firstEdu['year']?.toString() ??
                    '';
          } else {
            educationController.text = eduList.join('\n');
          }
        } else {
          final edu = asText(normalized['education']);
          if (edu.isNotEmpty) educationController.text = edu;
          final uni = asText(normalized['university']);
          if (uni.isNotEmpty) universityController.text = uni;
          final grad = asText(normalized['graduation_year']);
          if (grad.isNotEmpty) graduationYearController.text = grad;
        }

        String listToCsv(dynamic v) => toStringList(v).join(', ');

        final skills = listToCsv(normalized['skills']);
        if (skills.isNotEmpty) skillsController.text = skills;
        final certs = listToCsv(normalized['certifications']);
        if (certs.isNotEmpty) certificationsController.text = certs;
        final langs = listToCsv(normalized['languages']);
        if (langs.isNotEmpty) languagesController.text = langs;
        final experience = asText(normalized['experience']);
        if (experience.isNotEmpty) experienceController.text = experience;
        final position = asText(normalized['position']);
        if (position.isNotEmpty) positionController.text = position;
        // Populate previous companies from CV parser so Work Experience review is not empty.
        final prev = normalized['previous_companies'];
        if (prev is List) {
          previousCompaniesController.text = prev
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .join(', ');
        } else if (prev != null) {
          final prevText = asText(prev);
          if (prevText.isNotEmpty) {
            previousCompaniesController.text = prevText;
          }
        }

        _parsedSkills = toStringList(normalized['skills']);
        _parsedEducation = toEducationRows(normalized['education']);
        _parsedExperience = toExperienceRows(normalized['work_experience']);
        _backendCareerSummary = normalized['career_summary'] is Map
            ? Map<String, dynamic>.from(normalized['career_summary'] as Map)
            : null;
        _step3ActiveSection = 'personal';
        _processingStage = stages.length - 1;
        _processingComplete = true;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processingError = true;
        _cvUploadFailed = true;
        _processingComplete = true;
        loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not parse CV. Tap Next to continue and fill in your details manually.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
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
  State<_EnrollmentDropZoneScope> createState() =>
      _EnrollmentDropZoneScopeState();
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
    required this.isDarkMode,
    required this.nameController,
    required this.phoneController,
    required this.addressController,
    required this.linkedinController,
    required this.onSave,
  });

  final bool isDarkMode;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController linkedinController;
  final VoidCallback onSave;

  Color get _bg => isDarkMode ? _kOnboardingCardBg : Colors.white;
  Color get _fieldBg => isDarkMode
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFF090812).withValues(alpha: 0.04);
  Color get _text => isDarkMode ? Colors.white : const Color(0xFF090812);
  Color get _muted =>
      isDarkMode ? Colors.white70 : const Color(0xFF090812).withValues(alpha: 0.72);
  Color get _border =>
      isDarkMode ? Colors.white24 : const Color(0xFF090812).withValues(alpha: 0.22);

  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            text,
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _muted),
          ),
          if (required)
            Text(
              ' *',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kKhonologyRed),
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
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit Personal Details',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _text),
            ),
            const SizedBox(height: 20),
            _label('Full Name', required: true),
            TextField(
              controller: nameController,
              style: GoogleFonts.poppins(color: _text),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: _fieldBg,
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _kKhonologyRed)),
              ),
            ),
            const SizedBox(height: 16),
            _label('Phone', required: true),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.poppins(color: _text),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: _fieldBg,
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _kKhonologyRed)),
              ),
            ),
            const SizedBox(height: 16),
            _label('Address', required: true),
            TextField(
              controller: addressController,
              maxLines: 2,
              style: GoogleFonts.poppins(color: _text),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: _fieldBg,
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _kKhonologyRed)),
              ),
            ),
            const SizedBox(height: 16),
            _label('LinkedIn Profile'),
            TextField(
              controller: linkedinController,
              style: GoogleFonts.poppins(color: _text),
              decoration: InputDecoration(
                hintText: 'e.g. https://linkedin.com/in/yourprofile',
                hintStyle:
                    GoogleFonts.poppins(color: _muted, fontSize: 14),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: _fieldBg,
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _kKhonologyRed)),
              ),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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
    required this.isDarkMode,
    required this.educationController,
    required this.universityController,
    required this.graduationYearController,
    required this.onSave,
  });

  final bool isDarkMode;
  final TextEditingController educationController;
  final TextEditingController universityController;
  final TextEditingController graduationYearController;
  final VoidCallback onSave;
  Color get _bg => isDarkMode ? _kOnboardingCardBg : Colors.white;
  Color get _fieldBg => isDarkMode
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFF090812).withValues(alpha: 0.04);
  Color get _text => isDarkMode ? Colors.white : const Color(0xFF090812);
  Color get _muted =>
      isDarkMode ? Colors.white70 : const Color(0xFF090812).withValues(alpha: 0.72);
  Color get _border =>
      isDarkMode ? Colors.white24 : const Color(0xFF090812).withValues(alpha: 0.22);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit Education',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: _text),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: educationController,
            style: GoogleFonts.poppins(color: _text),
            decoration: InputDecoration(
              labelText: 'Level / Degree',
              labelStyle: GoogleFonts.poppins(color: _muted),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: _fieldBg,
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _kKhonologyRed)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: universityController,
            style: GoogleFonts.poppins(color: _text),
            decoration: InputDecoration(
              labelText: 'Institution',
              labelStyle: GoogleFonts.poppins(color: _muted),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: _fieldBg,
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _kKhonologyRed)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: graduationYearController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.poppins(color: _text),
            decoration: InputDecoration(
              labelText: 'Graduation Year',
              labelStyle: GoogleFonts.poppins(color: _muted),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: _fieldBg,
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _kKhonologyRed)),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _EditSkillsSheet extends StatelessWidget {
  const _EditSkillsSheet({
    required this.isDarkMode,
    required this.skillsController,
    required this.onSave,
  });

  final bool isDarkMode;
  final TextEditingController skillsController;
  final VoidCallback onSave;
  Color get _bg => isDarkMode ? _kOnboardingCardBg : Colors.white;
  Color get _fieldBg => isDarkMode
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFF090812).withValues(alpha: 0.04);
  Color get _text => isDarkMode ? Colors.white : const Color(0xFF090812);
  Color get _muted =>
      isDarkMode ? Colors.white70 : const Color(0xFF090812).withValues(alpha: 0.72);
  Color get _border =>
      isDarkMode ? Colors.white24 : const Color(0xFF090812).withValues(alpha: 0.22);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit Skills',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: _text),
          ),
          const SizedBox(height: 20),
          Text(
            'Add skills separated by commas. Remove a skill by deleting it.',
            style: GoogleFonts.poppins(fontSize: 13, color: _muted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: skillsController,
            maxLines: 5,
            style: GoogleFonts.poppins(color: _text),
            decoration: InputDecoration(
              labelText: 'Skills',
              hintText: 'e.g. Flutter, Dart, REST APIs, SQL',
              labelStyle: GoogleFonts.poppins(color: _muted),
              hintStyle: GoogleFonts.poppins(color: _muted),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: _fieldBg,
              enabledBorder:
                  OutlineInputBorder(borderSide: BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _kKhonologyRed)),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
    required this.isDarkMode,
    required this.experienceController,
    required this.previousCompaniesController,
    required this.positionController,
    required this.onSave,
  });

  final bool isDarkMode;
  final TextEditingController experienceController;
  final TextEditingController previousCompaniesController;
  final TextEditingController positionController;
  final VoidCallback onSave;
  Color get _bg => isDarkMode ? _kOnboardingCardBg : Colors.white;
  Color get _fieldBg => isDarkMode
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFF090812).withValues(alpha: 0.04);
  Color get _text => isDarkMode ? Colors.white : const Color(0xFF090812);
  Color get _muted =>
      isDarkMode ? Colors.white70 : const Color(0xFF090812).withValues(alpha: 0.72);
  Color get _border =>
      isDarkMode ? Colors.white24 : const Color(0xFF090812).withValues(alpha: 0.22);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit Work Experience',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: _text),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: positionController,
            style: GoogleFonts.poppins(color: _text),
            decoration: InputDecoration(
              labelText: 'Position / Role',
              labelStyle: GoogleFonts.poppins(color: _muted),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: _fieldBg,
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _kKhonologyRed)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: previousCompaniesController,
            style: GoogleFonts.poppins(color: _text),
            decoration: InputDecoration(
              labelText: 'Company',
              labelStyle: GoogleFonts.poppins(color: _muted),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: _fieldBg,
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _kKhonologyRed)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: experienceController,
            maxLines: 3,
            style: GoogleFonts.poppins(color: _text),
            decoration: InputDecoration(
              labelText: 'Responsibilities / Description',
              labelStyle: GoogleFonts.poppins(color: _muted),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: _fieldBg,
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _kKhonologyRed)),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
