import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/custom_textfield.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

// ------------------- API Base URL -------------------
const String candidateBase = "http://127.0.0.1:5000/api/candidate";

class ProfilePage extends StatefulWidget {
  final String token;
  const ProfilePage({super.key, required this.token});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  bool loading = true;
  bool showProfileSummary = true;
  String selectedSidebar = "Profile";

  // Color scheme matching other candidate screens
  final Color primaryColor = Color(0xFF991A1A);
  final Color strokeColor = Color(0xFFC10D00);
  final Color fillColor = Color(0xFFf2f2f2).withValues(alpha: 0.2);
  String? _selectedGender;
  String? _selectedNationality;
  String? _selectedTitle;
  DateTime? _selectedDate;
  List<TextEditingController> _workExpControllers = [TextEditingController()];
  List<TextEditingController> _educationControllers = [TextEditingController()];

  // Profile Controllers
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController genderController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController nationalityController = TextEditingController();
  final TextEditingController idNumberController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController titleController = TextEditingController();

  // Candidate fields
  final TextEditingController degreeController = TextEditingController();
  final TextEditingController institutionController = TextEditingController();
  final TextEditingController graduationYearController =
      TextEditingController();
  final TextEditingController skillsController = TextEditingController();
  final TextEditingController workExpController = TextEditingController();
  final TextEditingController jobTitleController = TextEditingController();
  final TextEditingController companyController = TextEditingController();
  final TextEditingController yearsOfExpController = TextEditingController();
  final TextEditingController linkedinController = TextEditingController();
  final TextEditingController githubController = TextEditingController();
  final TextEditingController portfolioController = TextEditingController();
  final TextEditingController cvTextController = TextEditingController();
  final TextEditingController cvUrlController = TextEditingController();

  // Profile Image
  XFile? _profileImage;
  Uint8List? _profileImageBytes;
  String _profileImageUrl = "";
  final ImagePicker _picker = ImagePicker();

  // Settings
  bool darkMode = false;
  bool notificationsEnabled = true;
  bool jobAlertsEnabled = true;
  bool profileVisible = true;
  bool enrollmentCompleted = false;

  // 🆕 MFA State
  bool _mfaEnabled = false;
  bool _mfaLoading = false;
  String? _mfaSecret;
  String? _mfaQrCode;

  // Getter to satisfy analyzer - _mfaLoading is used in MFA methods
  bool get mfaLoading => _mfaLoading;
  List<String> _backupCodes = [];
  int _backupCodesRemaining = 0;

  List<dynamic> documents = [];
  final String apiBase = "http://127.0.0.1:5000/api/candidate";

  // Helper methods for dropdown options
  List<Map<String, String>> get genderOptions => [
        {'value': '', 'label': 'Select Gender'},
        {'value': 'male', 'label': 'Male'},
        {'value': 'female', 'label': 'Female'},
        {'value': 'other', 'label': 'Other'},
        {'value': 'prefer_not_to_say', 'label': 'Prefer not to say'}
      ];

  List<Map<String, String>> get nationalityOptions => [
        {'value': '', 'label': 'Select Nationality'},
        {'value': 'kenyan', 'label': 'Kenyan'},
        {'value': 'tanzanian', 'label': 'Tanzanian'},
        {'value': 'ugandan', 'label': 'Ugandan'},
        {'value': 'rwandan', 'label': 'Rwandan'},
        {'value': 'burundian', 'label': 'Burundian'},
        {'value': 'south_sudanese', 'label': 'South Sudanese'},
        {'value': 'other', 'label': 'Other'}
      ];

  List<Map<String, String>> get titleOptions => [
        {'value': '', 'label': 'Select Title'},
        {'value': 'mr', 'label': 'Mr.'},
        {'value': 'mrs', 'label': 'Mrs.'},
        {'value': 'ms', 'label': 'Ms.'},
        {'value': 'miss', 'label': 'Miss'},
        {'value': 'dr', 'label': 'Dr.'},
        {'value': 'prof', 'label': 'Prof.'},
        {'value': 'eng', 'label': 'Eng.'},
        {'value': 'other', 'label': 'Other'}
      ];

  // Helper method to get value from stored data
  String? _getValueFromStoredData(
      String? storedValue, List<Map<String, String>> options) {
    if (storedValue == null || storedValue.isEmpty) return '';

    // Convert stored value to lowercase for comparison
    String lowerValue = storedValue.toLowerCase();

    // Try to find exact match first
    for (var option in options) {
      if (option['label']?.toLowerCase() == lowerValue ||
          option['value'] == lowerValue) {
        return option['value'];
      }
    }

    // If no exact match, try partial match
    for (var option in options) {
      if (option['label']?.toLowerCase().contains(lowerValue) == true ||
          lowerValue.contains(option['value']!)) {
        return option['value'];
      }
    }

    return '';
  }

  // Helper method to get label from value
  String _getLabelFromValue(String? value, List<Map<String, String>> options) {
    if (value == null || value.isEmpty) return '';
    final option = options.firstWhere((opt) => opt['value'] == value,
        orElse: () => {'label': '', 'value': ''});
    return option['label'] ?? '';
  }

  // Helper methods for UI

  // ==================== SIDEBAR NAVIGATION ITEM ====================
  Widget _buildSidebarNavItem(String title, IconData icon,
      {required bool isSelected}) {
    return GestureDetector(
      onTap: () => setState(() => selectedSidebar = title),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? primaryColor : Colors.white.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider<Object> _getProfileImageProvider() {
    if (_profileImage != null) {
      if (kIsWeb) return MemoryImage(_profileImageBytes!);
      return FileImage(File(_profileImage!.path));
    }
    if (_profileImageUrl.isNotEmpty) return NetworkImage(_profileImageUrl);
    return const AssetImage("assets/images/profile_placeholder.png");
  }

  Widget _buildSelectedTab() {
    switch (selectedSidebar) {
      case "Profile":
        return showProfileSummary
            ? _buildProfileSummary()
            : _buildProfileForm();
      case "Settings":
        return _buildSettingsTab();
      case "2FA":
        return _build2FATab();
      case "Reset Password":
        return _buildResetPasswordTab();
      default:
        return _buildProfileSummary();
    }
  }

  @override
  void initState() {
    super.initState();
    fetchProfileAndSettings();
    _loadMfaStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Full-background image
            Positioned.fill(
              child: Image.asset(
                "assets/images/dark.png",
                fit: BoxFit.cover,
              ),
            ),

            // Loading indicator
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Loading Profile...",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: Colors.transparent,
        cardColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Crystal-clear background image
            Positioned.fill(
              child: Image.asset(
                "assets/images/dark.png",
                fit: BoxFit.cover,
              ),
            ),

            // Main content with sidebar
            Row(
              children: [
                // Sidebar
                Container(
                  width: 280,
                  height: double.infinity,
                  color: Color(0xFF313131),
                  child: Column(
                    children: [
                      // Profile Icon at Top
                      Container(
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 20,
                          bottom: 30,
                        ),
                        child: Column(
                          children: [
                            // Profile Avatar
                            GestureDetector(
                              onTap: () => setState(() =>
                                  showProfileSummary = !showProfileSummary),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: _getProfileImageProvider(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Profile Name
                            Text(
                              fullNameController.text.isNotEmpty
                                  ? fullNameController.text
                                  : 'Complete Your Profile',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (jobTitleController.text.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                jobTitleController.text,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Navigation Items
                      Expanded(
                        child: Column(
                          children: [
                            _buildSidebarNavItem(
                                "Profile", Icons.person_outline,
                                isSelected: selectedSidebar == "Profile"),
                            _buildSidebarNavItem(
                                "Settings", Icons.settings_outlined,
                                isSelected: selectedSidebar == "Settings"),
                            _buildSidebarNavItem("2FA", Icons.security_outlined,
                                isSelected: selectedSidebar == "2FA"),
                            _buildSidebarNavItem(
                                "Reset Password", Icons.lock_outline,
                                isSelected:
                                    selectedSidebar == "Reset Password"),
                          ],
                        ),
                      ),

                      // Bottom Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Back Button
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: fillColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: strokeColor),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.arrow_back,
                                        color: primaryColor, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Back',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Logout Button
                            GestureDetector(
                              onTap: () => _showLogoutConfirmation(context),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: strokeColor, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.logout,
                                        color: primaryColor, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Logout',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
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

                // Main Content Area
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildSelectedTab(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PROFILE SUMMARY TAB ====================
  Widget _buildProfileSummary() {
    return SingleChildScrollView(
      key: const ValueKey('profileSummary'),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _getProfileImageProvider(),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickProfileImage,
                            child: Icon(
                              Icons.camera_alt,
                              color: primaryColor,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      fullNameController.text.isNotEmpty
                          ? fullNameController.text
                          : 'Complete Your Profile',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (jobTitleController.text.isNotEmpty)
                      Text(
                        jobTitleController.text,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          showProfileSummary = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Edit Profile'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Profile Information Cards
              _buildInfoCard(
                'Personal Information',
                Icons.person_outline,
                [
                  if (emailController.text.isNotEmpty)
                    _buildInfoRow('Email', emailController.text),
                  if (phoneController.text.isNotEmpty)
                    _buildInfoRow('Phone', phoneController.text),
                  if (locationController.text.isNotEmpty)
                    _buildInfoRow('Location', locationController.text),
                  if (_selectedGender != null)
                    _buildInfoRow('Gender',
                        _getLabelFromValue(_selectedGender, genderOptions)),
                  if (_selectedDate != null)
                    _buildInfoRow('Date of Birth',
                        DateFormat('yyyy-MM-dd').format(_selectedDate!)),
                  if (_selectedNationality != null)
                    _buildInfoRow(
                        'Nationality',
                        _getLabelFromValue(
                            _selectedNationality, nationalityOptions)),
                  if (idNumberController.text.isNotEmpty)
                    _buildInfoRow('ID Number', idNumberController.text),
                ],
              ),
              const SizedBox(height: 16),

              if (bioController.text.isNotEmpty)
                _buildInfoCard(
                  'Bio',
                  Icons.description_outlined,
                  [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        bioController.text,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              if (skillsController.text.isNotEmpty)
                _buildInfoCard(
                  'Skills',
                  Icons.code_outlined,
                  [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: skillsController.text
                          .split(',')
                          .map((skill) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color:
                                          primaryColor.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  skill.trim(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              if (_educationControllers.isNotEmpty &&
                  _educationControllers.first.text.isNotEmpty)
                _buildInfoCard(
                  'Education',
                  Icons.school_outlined,
                  _educationControllers
                      .where((c) => c.text.isNotEmpty)
                      .map((c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              c.text,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 16),

              if (_workExpControllers.isNotEmpty &&
                  _workExpControllers.first.text.isNotEmpty)
                _buildInfoCard(
                  'Work Experience',
                  Icons.work_outline,
                  _workExpControllers
                      .where((c) => c.text.isNotEmpty)
                      .map((c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              c.text,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 16),

              if (linkedinController.text.isNotEmpty ||
                  githubController.text.isNotEmpty ||
                  portfolioController.text.isNotEmpty)
                _buildInfoCard(
                  'Links',
                  Icons.link_outlined,
                  [
                    if (linkedinController.text.isNotEmpty)
                      _buildLinkRow('LinkedIn', linkedinController.text),
                    if (githubController.text.isNotEmpty)
                      _buildLinkRow('GitHub', githubController.text),
                    if (portfolioController.text.isNotEmpty)
                      _buildLinkRow('Portfolio', portfolioController.text),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF2F2F2).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: strokeColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkRow(String label, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final Uri uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              child: Text(
                url,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: primaryColor,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PROFILE FORM TAB ====================
  Widget _buildProfileForm() {
    return Container(
      key: const ValueKey('profileForm'),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      showProfileSummary = true;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  'Edit Profile',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Profile Form
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Information Section
                Text(
                  'Basic Information',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'Select your title',
                    hintStyle: GoogleFonts.poppins(color: Colors.white70),
                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                    prefixIcon:
                        const Icon(Icons.person_outline, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC10D00)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC10D00)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFC10D00), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: fullNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your full name',
                    hintStyle: GoogleFonts.poppins(color: Colors.white70),
                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                    prefixIcon: const Icon(Icons.person, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC10D00)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC10D00)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFC10D00), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  enabled: false,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    hintStyle: GoogleFonts.poppins(color: Colors.white70),
                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                    prefixIcon: const Icon(Icons.email, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC10D00)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC10D00)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFC10D00), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    hintText: 'Enter your phone number',
                    hintStyle: GoogleFonts.poppins(color: Colors.white70),
                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                    prefixIcon: const Icon(Icons.phone, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC10D00)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC10D00)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFC10D00), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: locationController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Location',
                    hintText: 'Enter your location',
                    hintStyle: GoogleFonts.poppins(color: Colors.white70),
                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                    prefixIcon:
                        const Icon(Icons.location_on, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC10D00)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC10D00)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFC10D00), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Gender Dropdown
                Text(
                  'Gender',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue:
                      _selectedGender?.isEmpty ?? true ? null : _selectedGender,
                  hint: Text('Select Gender',
                      style: GoogleFonts.poppins(color: Colors.white70)),
                  items: genderOptions.map((option) {
                    return DropdownMenuItem<String>(
                      value: option['value'],
                      child: Text(
                        option['label']!,
                        style: GoogleFonts.poppins(color: Colors.black),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                      genderController.text =
                          _getLabelFromValue(value, genderOptions);
                    });
                  },
                  dropdownColor: Colors.white,
                  style: GoogleFonts.poppins(color: Colors.white),
                  icon:
                      const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC10D00)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC10D00)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFC10D00), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Date of Birth
                Text(
                  'Date of Birth',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                        dobController.text =
                            DateFormat('yyyy-MM-dd').format(picked);
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      border: Border.all(color: const Color(0xFFC10D00)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: Colors.white70, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedDate != null
                                ? DateFormat('yyyy-MM-dd')
                                    .format(_selectedDate!)
                                : 'Select Date of Birth',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Nationality Dropdown
                Text(
                  'Nationality',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedNationality?.isEmpty ?? true
                      ? null
                      : _selectedNationality,
                  hint: Text('Select Nationality',
                      style: GoogleFonts.poppins(color: Colors.white70)),
                  items: nationalityOptions.map((option) {
                    return DropdownMenuItem<String>(
                      value: option['value'],
                      child: Text(
                        option['label']!,
                        style: GoogleFonts.poppins(color: Colors.black),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedNationality = value;
                      nationalityController.text =
                          _getLabelFromValue(value, nationalityOptions);
                    });
                  },
                  dropdownColor: Colors.white,
                  style: GoogleFonts.poppins(color: Colors.white),
                  icon:
                      const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC10D00)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC10D00)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFC10D00), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                // ID Number Field
                Text(
                  'ID Number',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: idNumberController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'ID Number',
                    hintText: 'Enter your ID number',
                    hintStyle: GoogleFonts.poppins(color: Colors.white70),
                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                    prefixIcon: const Icon(Icons.badge, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC10D00)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC10D00)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFC10D00), width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Bio Section
                _buildFormSection('Bio', [
                  CustomTextField(
                    controller: bioController,
                    label: 'Bio',
                    hintText: 'Tell us about yourself',
                    prefixIcon: const Icon(Icons.description),
                    maxLines: 4,
                  ),
                ]),

                const SizedBox(height: 16),

                // Professional Information
                _buildFormSection('Professional Information', [
                  CustomTextField(
                    controller: jobTitleController,
                    label: 'Job Title',
                    hintText: 'Enter your current job title',
                    prefixIcon: const Icon(Icons.work),
                  ),
                  CustomTextField(
                    controller: companyController,
                    label: 'Company',
                    hintText: 'Enter your current company',
                    prefixIcon: const Icon(Icons.business),
                  ),
                  CustomTextField(
                    controller: yearsOfExpController,
                    label: 'Years of Experience',
                    hintText: 'Enter years of experience',
                    prefixIcon: const Icon(Icons.timeline),
                  ),
                ]),

                const SizedBox(height: 16),

                // Skills Section
                _buildFormSection('Skills', [
                  CustomTextField(
                    controller: skillsController,
                    label: 'Skills',
                    hintText: 'Enter skills separated by commas',
                    prefixIcon: const Icon(Icons.code),
                  ),
                ]),

                const SizedBox(height: 16),

                // Education Section
                _buildFormSection('Education', [
                  ..._buildDynamicList(_educationControllers, 'Education',
                      (index) {
                    setState(() {
                      _educationControllers.removeAt(index);
                    });
                  }),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _educationControllers.add(TextEditingController());
                      });
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Education'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor.withAlpha(50),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ]),

                const SizedBox(height: 16),

                // Work Experience Section
                _buildFormSection('Work Experience', [
                  ..._buildDynamicList(_workExpControllers, 'Work Experience',
                      (index) {
                    setState(() {
                      _workExpControllers.removeAt(index);
                    });
                  }),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _workExpControllers.add(TextEditingController());
                      });
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Work Experience'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor.withAlpha(50),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ]),

                const SizedBox(height: 16),

                // Links Section
                _buildFormSection('Links', [
                  CustomTextField(
                    controller: linkedinController,
                    label: 'LinkedIn',
                    hintText: 'Enter your LinkedIn URL',
                    prefixIcon: const Icon(Icons.link),
                  ),
                  CustomTextField(
                    controller: githubController,
                    label: 'GitHub',
                    hintText: 'Enter your GitHub URL',
                    prefixIcon: const Icon(Icons.link),
                  ),
                  CustomTextField(
                    controller: portfolioController,
                    label: 'Portfolio',
                    hintText: 'Enter your portfolio URL',
                    prefixIcon: const Icon(Icons.link),
                  ),
                ]),

                const SizedBox(height: 30),

                // Save Button
                ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  List<Widget> _buildDynamicList(List<TextEditingController> controllers,
      String label, Function(int) onRemove) {
    List<Widget> widgets = [];
    for (int i = 0; i < controllers.length; i++) {
      widgets.add(
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: controllers[i],
                label: '$label ${i + 1}',
                hintText: 'Enter $label',
              ),
            ),
            if (controllers.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                onPressed: () => onRemove(i),
              ),
          ],
        ),
      );
      if (i < controllers.length - 1) const SizedBox(height: 8);
    }
    return widgets;
  }

  // ==================== LOGOUT FUNCTIONALITY ====================
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: strokeColor, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Logout',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to logout?',
                style: GoogleFonts.poppins(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(color: Colors.black87),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await AuthService.logout();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => LoginScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Logout',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    try {
      setState(() => loading = true);

      // Prepare work experience data
      List<String> workExpList = _workExpControllers
          .where((c) => c.text.isNotEmpty)
          .map((c) => c.text)
          .toList();

      // Prepare education data
      List<String> educationList = _educationControllers
          .where((c) => c.text.isNotEmpty)
          .map((c) => c.text)
          .toList();

      // Prepare skills list
      List<String> skillsList = skillsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final Map<String, dynamic> profileData = {
        'full_name': fullNameController.text,
        'phone': phoneController.text,
        'gender': _selectedGender,
        'dob': dobController.text,
        'nationality': _selectedNationality,
        'id_number': idNumberController.text,
        'bio': bioController.text,
        'location': locationController.text,
        'title': _selectedTitle,
        'job_title': jobTitleController.text,
        'company': companyController.text,
        'years_of_experience': yearsOfExpController.text,
        'skills': skillsList,
        'work_experience': workExpList,
        'education': educationList,
        'linkedin': linkedinController.text,
        'github': githubController.text,
        'portfolio': portfolioController.text,
      };

      final response = await http.put(
        Uri.parse("$apiBase/profile"),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(profileData),
      );

      if (response.statusCode == 200) {
        setState(() {
          showProfileSummary = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to update profile: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  // ==================== SETTINGS TAB ====================
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      key: const ValueKey('settings'),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add an extra layer of security to your account',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),

              // Appearance Settings
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSwitchTile(
                    'Dark Mode',
                    darkMode,
                    Icons.dark_mode_outlined,
                    (value) => setState(() => darkMode = value),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Notification Settings
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSwitchTile(
                    'Push Notifications',
                    notificationsEnabled,
                    Icons.notifications_outlined,
                    (value) => setState(() => notificationsEnabled = value),
                  ),
                  _buildSwitchTile(
                    'Job Alerts',
                    jobAlertsEnabled,
                    Icons.work_outline,
                    (value) => setState(() => jobAlertsEnabled = value),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Privacy Settings
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSwitchTile(
                    'Profile Visible to Employers',
                    profileVisible,
                    Icons.visibility_outlined,
                    (value) => setState(() => profileVisible = value),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Save Settings Button
              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Save Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value,
    IconData icon,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC10D00), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: primaryColor,
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    try {
      setState(() => loading = true);

      final Map<String, dynamic> settingsData = {
        'dark_mode': darkMode,
        'notifications_enabled': notificationsEnabled,
        'job_alerts_enabled': jobAlertsEnabled,
        'profile_visible': profileVisible,
      };

      final response = await http.put(
        Uri.parse("$apiBase/settings"),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(settingsData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save settings: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  // ==================== 2FA TAB ====================
  Widget _build2FATab() {
    return SingleChildScrollView(
      key: const ValueKey('2fa'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Two-Factor Authentication',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add an extra layer of security to your account',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 30),

          // 2FA Status Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: strokeColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _mfaEnabled ? Icons.verified : Icons.security_outlined,
                      color: _mfaEnabled ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '2FA Status',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _mfaEnabled ? 'Enabled' : 'Disabled',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: _mfaEnabled ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_mfaEnabled) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Backup codes remaining: $_backupCodesRemaining',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          if (!_mfaEnabled)
            ElevatedButton.icon(
              onPressed: _setupMFA,
              icon: const Icon(Icons.security),
              label: const Text('Enable 2FA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: strokeColor),
              ),
              child: ElevatedButton.icon(
                onPressed: _showBackupCodesDialog,
                icon: const Icon(Icons.key),
                label: const Text('View Backup Codes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: strokeColor),
              ),
              child: ElevatedButton.icon(
                onPressed: _disableMFA,
                icon: const Icon(Icons.security_outlined),
                label: const Text('Disable 2FA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setupMFA() async {
    setState(() => _mfaLoading = true);
    try {
      final result = await AuthService.getMfaStatus();
      // Note: setupMfa method needs to be implemented in AuthService
      // final result2 = await AuthService.setupMfa();
      if (result.containsKey('mfa_enabled')) {
        setState(() {
          _mfaEnabled = result['mfa_enabled'];
          _backupCodesRemaining = result['backup_codes_remaining'] ?? 0;
        });
      }
      // setState(() {
      //   _mfaSecret = result2['secret'];
      //   _mfaQrCode = result2['qr_code'];
      // });

      if (_mfaQrCode != null) {
        _showMFASetupDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error setting up MFA: $e')),
      );
    } finally {
      setState(() => _mfaLoading = false);
    }
  }

  void _showMFASetupDialog() {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Setup 2FA',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_mfaQrCode != null) Image.network(_mfaQrCode!, height: 200),
              const SizedBox(height: 16),
              Text(
                'Scan this QR code with Google Authenticator or enter the code manually:',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
              const SizedBox(height: 8),
              SelectableText(
                _mfaSecret ?? '',
                style: GoogleFonts.robotoMono(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Enter 6-digit code',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
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
            onPressed: () => _verifyMFACode(codeController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyMFACode(String code) async {
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit code')),
      );
      return;
    }

    setState(() => _mfaLoading = true);
    try {
      // Note: verifyMfa method needs to be implemented in AuthService
      // final result = await AuthService.verifyMfa(code);
      final result = {'success': false, 'message': 'Method not implemented'};
      if (result['success'] == true) {
        setState(() {
          _mfaEnabled = true;
          _backupCodes = <String>[];
          _backupCodesRemaining = _backupCodes.length;
        });
        Navigator.pop(context); // Close dialog
        _showBackupCodesDialog(); // Show backup codes
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid code. Please try again.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying code: $e')),
      );
    } finally {
      setState(() => _mfaLoading = false);
    }
  }

  Future<void> _disableMFA() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable 2FA'),
        content: const Text(
            'Are you sure you want to disable two-factor authentication?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _mfaLoading = true);
      try {
        // Note: disableMfa method needs to be implemented in AuthService
        // final result = await AuthService.disableMfa();
        final result = {'success': false, 'message': 'Method not implemented'};
        if (result['success'] == true) {
          setState(() {
            _mfaEnabled = false;
            _backupCodes = [];
            _backupCodesRemaining = 0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('2FA disabled successfully')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error disabling 2FA: $e')),
        );
      } finally {
        setState(() => _mfaLoading = false);
      }
    }
  }

  void _showBackupCodesDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: fillColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: strokeColor),
        ),
        title: Row(
          children: [
            Icon(Icons.security, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              "Backup Codes",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Save these backup codes in a secure place. Each code can be used once if you lose access to your authenticator app.",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: strokeColor),
                ),
                child: Column(
                  children: _backupCodes
                      .map((code) => Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: fillColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: strokeColor.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.vpn_key,
                                  color: primaryColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SelectableText(
                                    code,
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "⚠️ These codes won't be shown again. Make sure to save them now!",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: strokeColor),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "I've Saved These Codes",
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== RESET PASSWORD TAB ====================
  Widget _buildResetPasswordTab() {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    return SingleChildScrollView(
      key: const ValueKey('resetPassword'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reset Password',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Change your account password',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 30),

          // Current Password Field
          Text(
            'Current Password',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: currentPasswordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter your current password',
              hintStyle: GoogleFonts.poppins(color: Colors.white70),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFC10D00)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFC10D00)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFC10D00), width: 2),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // New Password Field
          Text(
            'New Password',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: newPasswordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter your new password',
              hintStyle: GoogleFonts.poppins(color: Colors.white70),
              prefixIcon: const Icon(Icons.lock, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFC10D00)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFC10D00)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFC10D00), width: 2),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Confirm Password Field
          Text(
            'Confirm New Password',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: confirmPasswordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Confirm your new password',
              hintStyle: GoogleFonts.poppins(color: Colors.white70),
              prefixIcon: const Icon(Icons.lock, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFC10D00)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFC10D00)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFC10D00), width: 2),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Reset Button
          ElevatedButton(
            onPressed: () => _resetPassword(
              currentPasswordController.text,
              newPasswordController.text,
              confirmPasswordController.text,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Reset Password',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword(
      String current, String newPass, String confirm) async {
    // Validation
    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (newPass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    if (newPass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters')),
      );
      return;
    }

    setState(() => loading = true);
    try {
      final response = await http.post(
        Uri.parse("$apiBase/reset-password"),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'current_password': current,
          'new_password': newPass,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successfully')),
        );
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(error['message'] ?? 'Failed to reset password')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resetting password: $e')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  // ==================== MFA Methods ====================
  Future<void> _loadMfaStatus() async {
    try {
      final result = await AuthService.getMfaStatus();
      if (result.containsKey('mfa_enabled')) {
        setState(() {
          _mfaEnabled = result['mfa_enabled'];
          _backupCodesRemaining = result['backup_codes_remaining'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint("Error loading MFA status: $e");
    }
  }

  // ==================== API Methods ====================
  Future<void> fetchProfileAndSettings() async {
    try {
      final profileRes = await http.get(
        Uri.parse("$apiBase/profile"),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json'
        },
      );

      if (profileRes.statusCode == 200) {
        final data = json.decode(profileRes.body)['data'];
        final user = data['user'] ?? {};
        final candidate = data['candidate'] ?? {};

        fullNameController.text = candidate['full_name'] ?? "";
        emailController.text = user['profile']['email'] ?? "";
        phoneController.text = candidate['phone'] ?? "";

        // Initialize dropdown values using helper methods
        final storedGender = candidate['gender'] ?? "";
        _selectedGender = _getValueFromStoredData(storedGender, genderOptions);
        genderController.text =
            _getLabelFromValue(_selectedGender, genderOptions);

        final storedNationality = candidate['nationality'] ?? "";
        _selectedNationality =
            _getValueFromStoredData(storedNationality, nationalityOptions);
        nationalityController.text =
            _getLabelFromValue(_selectedNationality, nationalityOptions);

        final storedTitle = candidate['title'] ?? "";
        _selectedTitle = _getValueFromStoredData(storedTitle, titleOptions);
        titleController.text = _getLabelFromValue(_selectedTitle, titleOptions);

        // Initialize date
        if (candidate['dob'] != null && candidate['dob'].isNotEmpty) {
          _selectedDate = DateTime.tryParse(candidate['dob']);
          dobController.text = candidate['dob'] ?? "";
        }

        idNumberController.text = candidate['id_number'] ?? "";
        bioController.text = candidate['bio'] ?? "";
        locationController.text = candidate['location'] ?? "";

        // Initialize education and work experience
        final degree = candidate['degree'] ?? "";
        final institution = candidate['institution'] ?? "";
        final graduationYear = candidate['graduation_year'] ?? "";

        if (degree.isNotEmpty || institution.isNotEmpty) {
          _educationControllers.clear();
          _educationControllers.add(TextEditingController(
              text:
                  "$degree${institution.isNotEmpty ? ' at $institution' : ''}${graduationYear.isNotEmpty ? ' ($graduationYear)' : ''}"));
        } else {
          _educationControllers = [TextEditingController()];
        }

        final workExperience = candidate['work_experience'] ?? [];
        if (workExperience.isNotEmpty && workExperience is List) {
          _workExpControllers.clear();
          for (var exp in workExperience) {
            _workExpControllers
                .add(TextEditingController(text: exp.toString()));
          }
        } else {
          _workExpControllers = [TextEditingController()];
        }

        // Initialize the workExpController with first entry for backward compatibility
        if (_workExpControllers.isNotEmpty) {
          workExpController.text = _workExpControllers.first.text;
        }

        skillsController.text = (candidate['skills'] ?? []).join(", ");
        jobTitleController.text = candidate['job_title'] ?? "";
        companyController.text = candidate['company'] ?? "";
        yearsOfExpController.text = candidate['years_of_experience'] ?? "";
        linkedinController.text = candidate['linkedin'] ?? "";
        githubController.text = candidate['github'] ?? "";
        portfolioController.text = candidate['portfolio'] ?? "";
        documents = candidate['documents'] ?? [];
        _profileImageUrl = candidate['profile_picture'] ?? "";
      }

      final settingsRes = await http.get(
        Uri.parse("$apiBase/settings"),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json'
        },
      );

      if (settingsRes.statusCode == 200) {
        final data = json.decode(settingsRes.body);
        darkMode = data['dark_mode'] ?? false;
        notificationsEnabled = data['notifications_enabled'] ?? true;
        enrollmentCompleted = data['enrollment_completed'] ?? false;
        jobAlertsEnabled = data['job_alerts_enabled'] ?? true;
        profileVisible = data['profile_visible'] ?? true;
      }
    } catch (e) {
      debugPrint("Error fetching profile/settings: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _pickProfileImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) _profileImageBytes = await pickedFile.readAsBytes();
      setState(() => _profileImage = pickedFile);
      await uploadProfileImage();
    }
  }

  Future<void> uploadProfileImage() async {
    if (_profileImage == null) return;
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("$apiBase/upload_profile_picture"),
      );
      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          kIsWeb
              ? _profileImageBytes!
              : File(_profileImage!.path).readAsBytesSync(),
          filename: _profileImage!.name,
        ),
      );

      var response = await request.send();
      final respStr = await response.stream.bytesToString();
      final respJson = json.decode(respStr);

      if (response.statusCode == 200 && respJson['success'] == true) {
        setState(() {
          _profileImageUrl = respJson['data']['profile_picture'];
          _profileImage = null;
          _profileImageBytes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile picture updated")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Upload failed: ${response.statusCode}")));
      }
    } catch (e) {
      debugPrint("Profile image upload error: $e");
    }
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    genderController.dispose();
    dobController.dispose();
    nationalityController.dispose();
    idNumberController.dispose();
    bioController.dispose();
    locationController.dispose();
    titleController.dispose();
    degreeController.dispose();
    institutionController.dispose();
    graduationYearController.dispose();
    skillsController.dispose();
    workExpController.dispose();
    jobTitleController.dispose();
    companyController.dispose();
    yearsOfExpController.dispose();
    linkedinController.dispose();
    githubController.dispose();
    portfolioController.dispose();
    cvTextController.dispose();
    cvUrlController.dispose();

    for (var controller in _workExpControllers) {
      controller.dispose();
    }
    for (var controller in _educationControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
