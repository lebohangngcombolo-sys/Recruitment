import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../widgets/custom_textfield.dart';
import '../../services/auth_service.dart';
import '../../providers/theme_provider.dart';
import '../../utils/api_endpoints.dart';

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

  // ≡ƒåò MFA State
  bool _mfaEnabled = false;
  bool _mfaLoading = false;
  String? _mfaSecret;
  String? _mfaQrCode;
  List<String> _backupCodes = [];
  int _backupCodesRemaining = 0;

  List<dynamic> documents = [];
  List<String> _certifications = [];
  List<String> _languages = [];
  final String apiBase = ApiEndpoints.candidateBase;

  // Add these helper methods in the _ProfilePageState class (around line 150, after the state variables):

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

  // ignore: unused_element
  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.redAccent.withOpacity(0.7),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(70),
                child: Image(
                  image: _getProfileImageProvider(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.grey.shade400,
                      size: 70,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          fullNameController.text.isNotEmpty
              ? fullNameController.text
              : "Your Name",
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          titleController.text.isNotEmpty ? titleController.text : "Your Title",
          style: GoogleFonts.inter(
            fontSize: 18,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 15),
        if (_mfaEnabled)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user, color: Colors.greenAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  "2FA Enabled",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 30),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    fetchProfileAndSettings();
    _loadMfaStatus();
  }

  // ≡ƒåò MFA METHODS (unchanged)
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

  Future<void> _enableMfa() async {
    setState(() => _mfaLoading = true);
    try {
      final result = await AuthService.enableMfa();
      if (result.containsKey('qr_code')) {
        setState(() {
          _mfaSecret = result['secret'];
          _mfaQrCode = result['qr_code'];
        });
        _showMfaSetupDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to enable MFA: $e")),
      );
    } finally {
      setState(() => _mfaLoading = false);
    }
  }

  Future<void> _verifyMfaSetup(String token) async {
    setState(() => _mfaLoading = true);
    try {
      final result = await AuthService.verifyMfaSetup(token);
      if (result.containsKey('backup_codes')) {
        setState(() {
          _mfaEnabled = true;
          _backupCodes = List<String>.from(result['backup_codes']);
          _backupCodesRemaining = _backupCodes.length;
        });
        Navigator.pop(context);
        _showBackupCodesDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("MFA enabled successfully")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("MFA setup failed: $e")),
      );
    } finally {
      setState(() => _mfaLoading = false);
    }
  }

  Future<void> _disableMfa(String password) async {
    setState(() => _mfaLoading = true);
    try {
      final result = await AuthService.disableMfa(password);
      if (result.containsKey('message')) {
        setState(() {
          _mfaEnabled = false;
          _mfaSecret = null;
          _mfaQrCode = null;
          _backupCodes = [];
          _backupCodesRemaining = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("MFA disabled successfully")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to disable MFA: $e")),
      );
    } finally {
      setState(() => _mfaLoading = false);
    }
  }

  Future<void> _loadBackupCodes() async {
    try {
      final result = await AuthService.getBackupCodes();
      if (result.containsKey('backup_codes')) {
        setState(() {
          _backupCodes = List<String>.from(result['backup_codes']);
          _backupCodesRemaining = _backupCodes.length;
        });
        _showBackupCodesDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load backup codes: $e")),
      );
    }
  }

  Future<void> _regenerateBackupCodes() async {
    setState(() => _mfaLoading = true);
    try {
      final result = await AuthService.regenerateBackupCodes();
      if (result.containsKey('backup_codes')) {
        setState(() {
          _backupCodes = List<String>.from(result['backup_codes']);
          _backupCodesRemaining = _backupCodes.length;
        });
        _showBackupCodesDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Backup codes regenerated")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to regenerate backup codes: $e")),
      );
    } finally {
      setState(() => _mfaLoading = false);
    }
  }

  void _showMfaSetupDialog() {
    final TextEditingController tokenController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            "Setup Two-Factor Authentication",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Scan the QR code with your authenticator app:",
                  style: GoogleFonts.inter(color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_mfaQrCode != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.network(_mfaQrCode!, height: 200, width: 200),
                  ),
                const SizedBox(height: 16),
                Text(
                  "Or enter this secret manually:",
                  style: GoogleFonts.inter(color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _mfaSecret ?? '',
                    style: GoogleFonts.robotoMono(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Enter the 6-digit code from your app:",
                  style: GoogleFonts.inter(color: Colors.black87),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: tokenController,
                  decoration: InputDecoration(
                    labelText: 'Verification Code',
                    labelStyle: GoogleFonts.inter(color: Colors.black54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    hintText: '123456',
                    hintStyle: GoogleFonts.inter(color: Colors.grey),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.robotoMono(
                    fontSize: 18,
                    letterSpacing: 4,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: GoogleFonts.inter(color: Colors.black54),
              ),
            ),
            ElevatedButton(
              onPressed: _mfaLoading
                  ? null
                  : () {
                      if (tokenController.text.length == 6) {
                        _verifyMfaSetup(tokenController.text);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Please enter a 6-digit code")),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _mfaLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      "Verify & Enable",
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupCodesDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.security, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(
              "Backup Codes",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.black,
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
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: _backupCodes
                      .map((code) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.vpn_key,
                                  color: Colors.redAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SelectableText(
                                    code,
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
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
                "ΓÜá∩╕Å These codes won't be shown again. Make sure to save them now!",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              "I've Saved These Codes",
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showDisableMfaDialog() {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          "Disable Two-Factor Authentication",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Enter your password to disable 2FA:",
              style: GoogleFonts.inter(color: Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: GoogleFonts.inter(color: Colors.black54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
              ),
              obscureText: true,
              style: GoogleFonts.inter(color: Colors.black),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: GoogleFonts.inter(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: _mfaLoading
                ? null
                : () {
                    if (passwordController.text.isNotEmpty) {
                      _disableMfa(passwordController.text);
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Please enter your password")),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _mfaLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    "Disable 2FA",
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }

  // EXISTING PROFILE METHODS (unchanged)
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
        // Prefer address (from enrollment) then location
        locationController.text =
            (candidate['address'] ?? candidate['location'] ?? "").toString();

        // Initialize education from enrollment format: education list [{level, institution, graduation_year}]
        String degree = candidate['degree'] ?? "";
        String institution = candidate['institution'] ?? "";
        String graduationYear = candidate['graduation_year'] ?? "";
        final educationList = candidate['education'];
        if (educationList is List && educationList.isNotEmpty) {
          final first = educationList.first;
          if (first is Map) {
            degree = (first['level'] ?? first['degree'] ?? degree).toString();
            institution = (first['institution'] ?? institution).toString();
            graduationYear =
                (first['graduation_year'] ?? graduationYear).toString();
          }
        }
        if (degree.isNotEmpty ||
            institution.isNotEmpty ||
            graduationYear.isNotEmpty) {
          degreeController.text = degree;
          institutionController.text = institution;
          graduationYearController.text = graduationYear;
          _educationControllers.clear();
          _educationControllers.add(TextEditingController(
              text:
                  "$degree${institution.isNotEmpty ? ' at $institution' : ''}${graduationYear.isNotEmpty ? ' ($graduationYear)' : ''}"));
        } else {
          _educationControllers = [TextEditingController()];
        }

        // Work experience from enrollment: list of {position, company, description}
        final workExperience = candidate['work_experience'] ?? [];
        if (workExperience.isNotEmpty && workExperience is List) {
          _workExpControllers.clear();
          for (var exp in workExperience) {
            String text = exp.toString();
            if (exp is Map) {
              final pos = exp['position'] ?? exp['title'] ?? '';
              final co = exp['company'] ?? '';
              final desc = exp['description'] ?? '';
              text = [
                if (pos.isNotEmpty) pos,
                if (co.isNotEmpty) 'at $co',
                if (desc.isNotEmpty) desc
              ].join(' ΓÇó ');
            }
            _workExpControllers.add(TextEditingController(text: text));
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
        // From enrollment: certifications and languages (persisted with profile)
        _certifications = List<String>.from(
            (candidate['certifications'] ?? []).map((e) => e.toString()));
        _languages = List<String>.from(
            (candidate['languages'] ?? []).map((e) => e.toString()));
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

  Future<void> updateProfile() async {
    try {
      // Collect all work experience entries
      final workExpEntries = _workExpControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      // Collect all education entries
      final educationEntries = _educationControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      // For backward compatibility, set the first work experience to the original controller
      if (workExpEntries.isNotEmpty) {
        workExpController.text = workExpEntries.first;
      }

      // For backward compatibility, set the first education to the original controllers
      if (educationEntries.isNotEmpty) {
        // You might want to parse the education string back into degree, institution, year
        // For now, we'll just use the first entry
        final firstEducation = educationEntries.first;
        degreeController.text = firstEducation;
        institutionController.text = "";
        graduationYearController.text = "";
      }

      final payload = {
        "full_name": fullNameController.text,
        "phone": phoneController.text,
        "gender": _getLabelFromValue(_selectedGender, genderOptions),
        "dob": _selectedDate != null
            ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
            : null,
        "nationality":
            _getLabelFromValue(_selectedNationality, nationalityOptions),
        "id_number": idNumberController.text,
        "bio": bioController.text,
        "location": locationController.text,
        "title": _getLabelFromValue(_selectedTitle, titleOptions),
        "degree": degreeController.text,
        "institution": institutionController.text,
        "graduation_year": graduationYearController.text,
        "skills":
            skillsController.text.split(",").map((e) => e.trim()).toList(),
        "work_experience": workExpEntries,
        "job_title": jobTitleController.text,
        "company": companyController.text,
        "years_of_experience": yearsOfExpController.text,
        "linkedin": linkedinController.text,
        "github": githubController.text,
        "portfolio": portfolioController.text,
        "user_profile": {"email": emailController.text},
      };

      final res = await http.put(
        Uri.parse("$apiBase/profile"),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json'
        },
        body: json.encode(payload),
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile updated successfully")));
        setState(() => showProfileSummary = true);
      }
    } catch (e) {
      debugPrint("Error updating profile: $e");
    }
  }

  Future<void> updateSettings() async {
    try {
      final payload = {
        "dark_mode": darkMode,
        "notifications_enabled": notificationsEnabled,
        "job_alerts_enabled": jobAlertsEnabled,
        "profile_visible": profileVisible,
        "enrollment_completed": enrollmentCompleted,
      };

      final res = await http.put(
        Uri.parse("$apiBase/settings"),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json'
        },
        body: json.encode(payload),
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Settings updated successfully")));
      }
    } catch (e) {
      debugPrint("Error updating settings: $e");
    }
  }

  ImageProvider<Object> _getProfileImageProvider() {
    if (_profileImage != null) {
      if (kIsWeb) return MemoryImage(_profileImageBytes!);
      return FileImage(File(_profileImage!.path));
    }
    if (_profileImageUrl.isNotEmpty) return NetworkImage(_profileImageUrl);
    return const AssetImage("assets/images/profile_placeholder.png");
  }

  Widget _modernCard(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.circle, color: Colors.redAccent, size: 8),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 0, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    if (loading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Full-background image
            Positioned.fill(
              child: Image.asset(
                themeProvider.backgroundImage,
                fit: BoxFit.cover,
              ),
            ),

            // Loading indicator
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Loading Profile...",
                    style: GoogleFonts.inter(
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
        primaryColor: Colors.redAccent,
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

            // Foreground content
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Transparent Sidebar
                Container(
                  width: 280,
                  height: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withValues(alpha: 0.05), // almost invisible
                    border: Border(
                        right: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1))),
                  ),
                  child: Column(
                    children: [
                      // Profile Section (transparent background)
                      Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(50),
                                  child: Image(
                                    image: _getProfileImageProvider(),
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                      child: Icon(
                                        Icons.person,
                                        color:
                                            Colors.white.withValues(alpha: 0.3),
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _pickProfileImage,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent
                                          .withValues(alpha: 0.8),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            fullNameController.text.isNotEmpty
                                ? fullNameController.text
                                : "Your Name",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            titleController.text.isNotEmpty
                                ? titleController.text
                                : "Your Title",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_mfaEnabled) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified,
                                      color: Colors.greenAccent, size: 12),
                                  const SizedBox(width: 6),
                                  Text(
                                    "2FA Enabled",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 40),
                      // Navigation buttons
                      _sidebarButton("Profile", Icons.person_outline_rounded),
                      _sidebarButton("Settings", Icons.settings_outlined),
                      _sidebarButton("2FA", Icons.security_outlined),
                      _sidebarButton(
                          "Reset Password", Icons.lock_reset_rounded),
                    ],
                  ),
                ),

                // Main Content Area (transparent)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    color: Colors.transparent, // fully see-through
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildSelectedTab(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarButton(String title, IconData icon) {
    final isSelected = selectedSidebar == title;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? Colors.redAccent.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05), // subtle transparent bg
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            setState(() {
              selectedSidebar = title;
              if (title == "Profile") showProfileSummary = true;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: isSelected
                  ? Border.all(color: Colors.redAccent.withValues(alpha: 0.3))
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? Colors.redAccent
                      : Colors.white, // white for crystal-clear bg
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Colors.redAccent
                        : Colors.white, // white for normal
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
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

  // ENHANCED 2FA TAB
  Widget _build2FATab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.redAccent),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Two-Factor Authentication",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Add an extra layer of security to your account",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 30),

          // Security Status Card
          _modernCard(
            "Security Status",
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _mfaEnabled
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _mfaEnabled ? Icons.verified : Icons.security,
                        color: _mfaEnabled ? Colors.green : Colors.orange,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _mfaEnabled ? "2FA Enabled" : "2FA Disabled",
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _mfaEnabled
                                ? "Your account is protected with two-factor authentication"
                                : "Add an extra layer of security to your account",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          if (_mfaEnabled) ...[
                            const SizedBox(height: 8),
                            Text(
                              "$_backupCodesRemaining backup codes remaining",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!_mfaEnabled) ...[
                  Text(
                    "Two-factor authentication adds an additional layer of security to your account by requiring more than just a password to sign in.",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _mfaLoading ? null : _enableMfa,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _mfaLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.security, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "Enable 2FA",
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ] else ...[
                  // MFA Management when enabled
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _mfaOption(
                        "View Backup Codes",
                        "Get your current backup codes",
                        Icons.backup,
                        onTap: _loadBackupCodes,
                      ),
                      _mfaOption(
                        "Regenerate Backup Codes",
                        "Generate new backup codes (invalidates old ones)",
                        Icons.refresh,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.white,
                              title: Text(
                                "Regenerate Backup Codes",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              content: Text(
                                "This will invalidate all your existing backup codes. Are you sure?",
                                style: GoogleFonts.inter(color: Colors.black54),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    "Cancel",
                                    style: GoogleFonts.inter(
                                        color: Colors.black54),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _regenerateBackupCodes();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                  ),
                                  child: Text(
                                    "Regenerate",
                                    style:
                                        GoogleFonts.inter(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _mfaLoading ? null : _showDisableMfaDialog,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _mfaLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.redAccent),
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.remove_circle_outline, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Disable 2FA",
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Security Tips Card
          if (_mfaEnabled) ...[
            const SizedBox(height: 20),
            _modernCard(
              "Security Tips",
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _securityTip(
                    "Save Backup Codes",
                    "Keep your backup codes in a safe place. You'll need them if you lose access to your authenticator app.",
                    Icons.warning_amber,
                    color: Colors.orange,
                  ),
                  _securityTip(
                    "Use Authenticator App",
                    "We recommend using Google Authenticator, Authy, or Microsoft Authenticator.",
                    Icons.security,
                    color: Colors.redAccent,
                  ),
                  _securityTip(
                    "Secure Your Device",
                    "Make sure your phone is protected with a PIN, pattern, or biometric lock.",
                    Icons.phone_android,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ],

          // How It Works Card
          const SizedBox(height: 20),
          _modernCard(
            "How It Works",
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _howItWorksStep(1, "Scan QR Code",
                    "Use your authenticator app to scan the QR code"),
                _howItWorksStep(
                    2, "Enter Code", "Enter the 6-digit code from your app"),
                _howItWorksStep(3, "Save Backup Codes",
                    "Keep your backup codes in a safe place"),
                _howItWorksStep(4, "Enhanced Security",
                    "Your account is now protected with 2FA"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mfaOption(String title, String subtitle, IconData icon,
      {required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.redAccent, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _securityTip(String title, String content, IconData icon,
      {Color color = Colors.blue}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _howItWorksStep(int step, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Profile Summary
  Widget _buildProfileSummary() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.redAccent),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Profile Overview",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => setState(() => showProfileSummary = false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: Icon(Icons.edit, size: 16),
                label: Text(
                  "Edit Profile",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "View and manage your profile information",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 30),

          // Personal Information Card
          _modernCard(
            "Personal Information",
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow("Full Name", fullNameController.text),
                _infoRow("Email", emailController.text),
                _infoRow("Phone", phoneController.text),
                if (locationController.text.isNotEmpty)
                  _infoRow("Address", locationController.text),
                _infoRow("Nationality", nationalityController.text),
                _infoRow("Title", titleController.text),
                if (bioController.text.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade100),
                  const SizedBox(height: 16),
                  Text(
                    "Bio",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bioController.text,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Education & Skills Card
          _modernCard(
            "Education & Skills",
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (degreeController.text.isNotEmpty)
                  _infoRow("Degree", degreeController.text),
                if (institutionController.text.isNotEmpty)
                  _infoRow("Institution", institutionController.text),
                if (graduationYearController.text.isNotEmpty)
                  _infoRow("Graduation Year", graduationYearController.text),
                if (skillsController.text.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade100),
                  const SizedBox(height: 16),
                  Text(
                    "Skills",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: skillsController.text.split(',').map((skill) {
                      final trimmedSkill = skill.trim();
                      if (trimmedSkill.isEmpty) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          trimmedSkill,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (_certifications.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade100),
                  const SizedBox(height: 16),
                  Text(
                    "Certifications",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _certifications.map((c) {
                      final t = c.trim();
                      if (t.isEmpty) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          t,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (_languages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade100),
                  const SizedBox(height: 16),
                  Text(
                    "Languages",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _languages.map((lang) {
                      final t = lang.trim();
                      if (t.isEmpty) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          t,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          // Online Profiles Card
          if (linkedinController.text.isNotEmpty ||
              githubController.text.isNotEmpty ||
              portfolioController.text.isNotEmpty)
            _modernCard(
              "Online Profiles",
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (linkedinController.text.isNotEmpty)
                    _linkRow("LinkedIn", linkedinController.text,
                        Icons.work_outline),
                  if (githubController.text.isNotEmpty)
                    _linkRow("GitHub", githubController.text, Icons.code),
                  if (portfolioController.text.isNotEmpty)
                    _linkRow(
                        "Portfolio", portfolioController.text, Icons.public),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.redAccent, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: GestureDetector(
              onTap: () {
                final uri = Uri.tryParse(value) ?? Uri();
                launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.blue.shade600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Profile Form
  // Profile Form - Fixed dropdown values
  Widget _buildProfileForm() {
    // Define dropdown options - Use unique values
    final List<Map<String, String>> genderOptions = [
      {'value': '', 'label': 'Select Gender'},
      {'value': 'male', 'label': 'Male'},
      {'value': 'female', 'label': 'Female'},
      {'value': 'other', 'label': 'Other'},
      {'value': 'prefer_not_to_say', 'label': 'Prefer not to say'}
    ];

    final List<Map<String, String>> nationalityOptions = [
      {'value': '', 'label': 'Select Nationality'},
      {'value': 'south_african', 'label': 'South African'},
      {'value': 'tanzanian', 'label': 'Tanzanian'},
      {'value': 'ugandan', 'label': 'Ugandan'},
      {'value': 'rwandan', 'label': 'Rwandan'},
      {'value': 'burundian', 'label': 'Burundian'},
      {'value': 'south_sudanese', 'label': 'South Sudanese'},
      {'value': 'other', 'label': 'Other'}
    ];

    final List<Map<String, String>> titleOptions = [
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

    return SingleChildScrollView(
      child: Column(
        children: [
          // Modern Header with gradient
          Container(
            margin: const EdgeInsets.only(bottom: 30),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.grey.shade100,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          setState(() => showProfileSummary = true),
                      icon: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.arrow_back_rounded,
                            color: Colors.redAccent, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Edit Profile",
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Update your profile information",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shadowColor: Colors.redAccent.withValues(alpha: 0.3),
                      ),
                      icon: Icon(Icons.save_rounded, size: 18),
                      label: Text(
                        "Save Changes",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: Colors.grey.shade200, height: 1),
              ],
            ),
          ),

          // Profile Picture Section
          _modernCard(
            "Profile Picture",
            Column(
              children: [
                GestureDetector(
                  onTap: _pickProfileImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.redAccent.withValues(alpha: 0.1),
                              Colors.redAccent.withValues(alpha: 0.3),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.3),
                            width: 3,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(70),
                          child: Image(
                            image: _getProfileImageProvider(),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person,
                                color: Colors.grey.shade400,
                                size: 50,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Tap the camera icon to update your profile photo",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Personal Information
          _modernCard(
            "Personal Information",
            Column(
              children: [
                // Title dropdown
                _buildStyledDropdown(
                  label: "Title",
                  value: _selectedTitle?.toLowerCase(),
                  options: titleOptions,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedTitle = newValue == '' ? null : newValue;
                      titleController.text = titleOptions.firstWhere(
                        (opt) => opt['value'] == newValue,
                        orElse: () => {'label': '', 'value': ''},
                      )['label']!;
                    });
                  },
                ),
                const SizedBox(height: 20),

                CustomTextField(
                  label: "Full Name",
                  controller: fullNameController,
                  backgroundColor: Colors.transparent,
                  borderColor: Colors.grey.shade300,
                  focusedBorderColor: Colors.redAccent,
                  borderRadius: 12,
                  borderWidth: 1.5,
                  focusedBorderWidth: 2,
                  textColor: Colors.black87,
                  labelColor: Colors.grey.shade700,
                  hintColor: Colors.grey.shade500,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
                const SizedBox(height: 20),

                CustomTextField(
                  label: "Email",
                  controller: emailController,
                  backgroundColor: Colors.transparent,
                  borderColor: Colors.grey.shade300,
                  focusedBorderColor: Colors.redAccent,
                  borderRadius: 12,
                  borderWidth: 1.5,
                  focusedBorderWidth: 2,
                  textColor: Colors.black87,
                  labelColor: Colors.grey.shade700,
                  hintColor: Colors.grey.shade500,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                ),
                const SizedBox(height: 20),

                CustomTextField(
                  label: "Phone",
                  controller: phoneController,
                  backgroundColor: Colors.transparent,
                  borderColor: Colors.grey.shade300,
                  focusedBorderColor: Colors.redAccent,
                  borderRadius: 12,
                  borderWidth: 1.5,
                  focusedBorderWidth: 2,
                  textColor: Colors.black87,
                  labelColor: Colors.grey.shade700,
                  hintColor: Colors.grey.shade500,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  inputType: TextInputType.phone,
                ),
                const SizedBox(height: 20),

                // Gender dropdown
                _buildStyledDropdown(
                  label: "Gender",
                  value: _selectedGender?.toLowerCase(),
                  options: genderOptions,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedGender = newValue == '' ? null : newValue;
                      genderController.text = genderOptions.firstWhere(
                        (opt) => opt['value'] == newValue,
                        orElse: () => {'label': '', 'value': ''},
                      )['label']!;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Date of Birth
                _buildDatePickerField(),
                const SizedBox(height: 20),

                // Nationality dropdown
                _buildStyledDropdown(
                  label: "Nationality",
                  value: _selectedNationality?.toLowerCase(),
                  options: nationalityOptions,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedNationality = newValue == '' ? null : newValue;
                      nationalityController.text =
                          nationalityOptions.firstWhere(
                        (opt) => opt['value'] == newValue,
                        orElse: () => {'label': '', 'value': ''},
                      )['label']!;
                    });
                  },
                ),
                const SizedBox(height: 20),

                CustomTextField(
                  label: "ID Number",
                  controller: idNumberController,
                  backgroundColor: Colors.transparent,
                  borderColor: Colors.grey.shade300,
                  focusedBorderColor: Colors.redAccent,
                  borderRadius: 12,
                  borderWidth: 1.5,
                  focusedBorderWidth: 2,
                  textColor: Colors.black87,
                  labelColor: Colors.grey.shade700,
                  hintColor: Colors.grey.shade500,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                ),
                const SizedBox(height: 20),

                CustomTextField(
                  label: "Bio",
                  controller: bioController,
                  maxLines: 4,
                  backgroundColor: Colors.transparent,
                  borderColor: Colors.grey.shade300,
                  focusedBorderColor: Colors.redAccent,
                  borderRadius: 12,
                  borderWidth: 1.5,
                  focusedBorderWidth: 2,
                  textColor: Colors.black87,
                  labelColor: Colors.grey.shade700,
                  hintColor: Colors.grey.shade500,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  hintText: "Tell us about yourself...",
                  prefixIcon: Icon(Icons.description_outlined, size: 20),
                ),
                const SizedBox(height: 20),

                CustomTextField(
                  label: "Location",
                  controller: locationController,
                  backgroundColor: Colors.transparent,
                  borderColor: Colors.grey.shade300,
                  focusedBorderColor: Colors.redAccent,
                  borderRadius: 12,
                  borderWidth: 1.5,
                  focusedBorderWidth: 2,
                  textColor: Colors.black87,
                  labelColor: Colors.grey.shade700,
                  hintColor: Colors.grey.shade500,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                  hintText: "City, Country",
                ),
              ],
            ),
          ),

          // Education Section
          _modernCard(
            "Education",
            Column(
              children: [
                ..._educationControllers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final controller = entry.value;
                  return Container(
                    margin: EdgeInsets.only(
                      bottom:
                          index == _educationControllers.length - 1 ? 0 : 20,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: index == 0
                                ? "Education"
                                : "Additional Education",
                            controller: controller,
                            maxLines: 2,
                            backgroundColor: Colors.transparent,
                            borderColor: Colors.grey.shade300,
                            focusedBorderColor: Colors.redAccent,
                            borderRadius: 12,
                            borderWidth: 1.5,
                            focusedBorderWidth: 2,
                            textColor: Colors.black87,
                            labelColor: Colors.grey.shade700,
                            hintColor: Colors.grey.shade500,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            hintText:
                                "e.g., BSc Computer Science at University (2020)",
                            prefixIcon: Icon(
                              Icons.school_outlined,
                              size: 20,
                              color: index == 0
                                  ? Colors.redAccent
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (_educationControllers.length > 1)
                          Container(
                            margin: const EdgeInsets.only(left: 12),
                            child: IconButton(
                              onPressed: () {
                                setState(() {
                                  _educationControllers.removeAt(index);
                                });
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.redAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.remove_rounded,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),

                // Add more education button
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _educationControllers.add(TextEditingController());
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.redAccent.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                    ),
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    label: Text(
                      "Add Another Education",
                      style: GoogleFonts.inter(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Skills Section
          _modernCard(
            "Skills",
            Column(
              children: [
                CustomTextField(
                  label: "Skills (comma separated)",
                  controller: skillsController,
                  backgroundColor: Colors.transparent,
                  borderColor: Colors.grey.shade300,
                  focusedBorderColor: Colors.redAccent,
                  borderRadius: 12,
                  borderWidth: 1.5,
                  focusedBorderWidth: 2,
                  textColor: Colors.black87,
                  labelColor: Colors.grey.shade700,
                  hintColor: Colors.grey.shade500,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  hintText: "e.g., Python, Flutter, React, Project Management",
                  prefixIcon: Icon(Icons.code_outlined, size: 20),
                  maxLines: 3,
                ),
              ],
            ),
          ),

          // Work Experience Section
          _modernCard(
            "Work Experience",
            Column(
              children: [
                CustomTextField(
                  label: "Job Title",
                  controller: jobTitleController,
                  backgroundColor: Colors.transparent,
                  borderColor: Colors.grey.shade300,
                  focusedBorderColor: Colors.redAccent,
                  borderRadius: 12,
                  borderWidth: 1.5,
                  focusedBorderWidth: 2,
                  textColor: Colors.black87,
                  labelColor: Colors.grey.shade700,
                  hintColor: Colors.grey.shade500,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: Icon(Icons.work_outline_rounded, size: 20),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: "Company",
                        controller: companyController,
                        backgroundColor: Colors.transparent,
                        borderColor: Colors.grey.shade300,
                        focusedBorderColor: Colors.redAccent,
                        borderRadius: 12,
                        borderWidth: 1.5,
                        focusedBorderWidth: 2,
                        textColor: Colors.black87,
                        labelColor: Colors.grey.shade700,
                        hintColor: Colors.grey.shade500,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: Icon(Icons.business_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: CustomTextField(
                        label: "Years of Experience",
                        controller: yearsOfExpController,
                        backgroundColor: Colors.transparent,
                        borderColor: Colors.grey.shade300,
                        focusedBorderColor: Colors.redAccent,
                        borderRadius: 12,
                        borderWidth: 1.5,
                        focusedBorderWidth: 2,
                        textColor: Colors.black87,
                        labelColor: Colors.grey.shade700,
                        hintColor: Colors.grey.shade500,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: Icon(Icons.timeline_outlined, size: 20),
                        inputType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Dynamic work experience entries
                ..._workExpControllers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final controller = entry.value;
                  return Container(
                    margin: EdgeInsets.only(
                      bottom: index == _workExpControllers.length - 1 ? 0 : 20,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: index == 0
                                ? "Work Experience Details"
                                : "Additional Experience",
                            controller: controller,
                            maxLines: 3,
                            backgroundColor: Colors.transparent,
                            borderColor: Colors.grey.shade300,
                            focusedBorderColor: Colors.redAccent,
                            borderRadius: 12,
                            borderWidth: 1.5,
                            focusedBorderWidth: 2,
                            textColor: Colors.black87,
                            labelColor: Colors.grey.shade700,
                            hintColor: Colors.grey.shade500,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            hintText:
                                "Describe your responsibilities and achievements...",
                            prefixIcon: Icon(
                              Icons.description_outlined,
                              size: 20,
                              color: index == 0
                                  ? Colors.redAccent
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (_workExpControllers.length > 1)
                          Container(
                            margin: const EdgeInsets.only(left: 12),
                            child: IconButton(
                              onPressed: () {
                                setState(() {
                                  _workExpControllers.removeAt(index);
                                });
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.redAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.remove_rounded,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),

                // Add more experience button
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _workExpControllers.add(TextEditingController());
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.redAccent.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                    ),
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    label: Text(
                      "Add Another Experience",
                      style: GoogleFonts.inter(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Online Profiles Section
          _modernCard(
            "Online Profiles",
            Column(
              children: [
                CustomTextField(
                  label: "LinkedIn",
                  controller: linkedinController,
                  backgroundColor: Colors.transparent,
                  borderColor: Colors.grey.shade300,
                  focusedBorderColor: Colors.redAccent,
                  borderRadius: 12,
                  borderWidth: 1.5,
                  focusedBorderWidth: 2,
                  textColor: Colors.black87,
                  labelColor: Colors.grey.shade700,
                  hintColor: Colors.grey.shade500,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  hintText: "https://linkedin.com/in/yourprofile",
                  prefixIcon: Icon(Icons.link_outlined, size: 20),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  label: "GitHub",
                  controller: githubController,
                  backgroundColor: Colors.transparent,
                  borderColor: Colors.grey.shade300,
                  focusedBorderColor: Colors.redAccent,
                  borderRadius: 12,
                  borderWidth: 1.5,
                  focusedBorderWidth: 2,
                  textColor: Colors.black87,
                  labelColor: Colors.grey.shade700,
                  hintColor: Colors.grey.shade500,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  hintText: "https://github.com/yourusername",
                  prefixIcon: Icon(Icons.code_outlined, size: 20),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  label: "Portfolio",
                  controller: portfolioController,
                  backgroundColor: Colors.transparent,
                  borderColor: Colors.grey.shade300,
                  focusedBorderColor: Colors.redAccent,
                  borderRadius: 12,
                  borderWidth: 1.5,
                  focusedBorderWidth: 2,
                  textColor: Colors.black87,
                  labelColor: Colors.grey.shade700,
                  hintColor: Colors.grey.shade500,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  hintText: "https://yourportfolio.com",
                  prefixIcon: Icon(Icons.public_outlined, size: 20),
                ),
              ],
            ),
          ),

          // Save Button Section
          Container(
            margin: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    shadowColor: Colors.redAccent.withValues(alpha: 0.4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.save_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        "Save All Changes",
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => showProfileSummary = true),
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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

// Helper method for styled dropdown
  Widget _buildStyledDropdown({
    required String label,
    required String? value,
    required List<Map<String, String>> options,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: options.map((Map<String, String> option) {
                return DropdownMenuItem<String>(
                  value: option['value'],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      option['label']!,
                      style: GoogleFonts.inter(
                        color: option['value']!.isEmpty
                            ? Colors.grey.shade500
                            : Colors.black87,
                        fontSize: 15,
                        fontWeight: option['value']!.isEmpty
                            ? FontWeight.w400
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Select $label',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade500,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              icon: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.grey.shade600,
                  size: 24,
                ),
              ),
              dropdownColor: Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              style: GoogleFonts.inter(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

// Helper method for date picker field
  Widget _buildDatePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Date of Birth",
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate ??
                  DateTime.now().subtract(const Duration(days: 365 * 18)),
              firstDate: DateTime(1900),
              lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
              builder: (context, child) {
                return Theme(
                  data: ThemeData.light().copyWith(
                    colorScheme: ColorScheme.light(
                      primary: Colors.redAccent,
                      onPrimary: Colors.white,
                      surface: Colors.white,
                    ),
                    dialogTheme: DialogThemeData(backgroundColor: Colors.white),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                _selectedDate = picked;
                dobController.text = DateFormat('yyyy-MM-dd').format(picked);
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDate != null
                        ? DateFormat('MMMM dd, yyyy').format(_selectedDate!)
                        : 'Select Date',
                    style: GoogleFonts.inter(
                      color: _selectedDate != null
                          ? Colors.black87
                          : Colors.grey.shade500,
                      fontSize: 15,
                      fontWeight: _selectedDate != null
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.grey.shade600,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Settings Tab
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Settings",
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Manage your account preferences",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 30),
          _modernCard(
            "Preferences",
            Column(
              children: [
                _settingsSwitch(
                  "Dark Mode",
                  "Enable dark theme",
                  Icons.dark_mode_outlined,
                  darkMode,
                  (v) => setState(() => darkMode = v),
                ),
                _settingsSwitch(
                  "Notifications",
                  "Receive push notifications",
                  Icons.notifications_outlined,
                  notificationsEnabled,
                  (v) => setState(() => notificationsEnabled = v),
                ),
                _settingsSwitch(
                  "Job Alerts",
                  "Get notified about new jobs",
                  Icons.work_outline,
                  jobAlertsEnabled,
                  (v) => setState(() => jobAlertsEnabled = v),
                ),
                _settingsSwitch(
                  "Profile Visibility",
                  "Make your profile visible to employers",
                  Icons.visibility_outlined,
                  profileVisible,
                  (v) => setState(() => profileVisible = v),
                ),
                _settingsSwitch(
                  "Enrollment Completed",
                  "Mark enrollment as completed",
                  Icons.check_circle_outline,
                  enrollmentCompleted,
                  (v) => setState(() => enrollmentCompleted = v),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: updateSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "Save Settings",
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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

  Widget _settingsSwitch(String title, String subtitle, IconData icon,
      bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.redAccent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: Colors.redAccent.withValues(alpha: 0.3),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? Colors.redAccent
                  : Colors.grey;
            }),
          ),
        ],
      ),
    );
  }

  // Reset Password Tab
  Widget _buildResetPasswordTab() {
    final TextEditingController currentPassword = TextEditingController();
    final TextEditingController newPassword = TextEditingController();
    final TextEditingController confirmPassword = TextEditingController();
    bool isLoading = false;

    Future<void> changePassword() async {
      if (newPassword.text != confirmPassword.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("New passwords do not match")),
        );
        return;
      }

      setState(() => isLoading = true);

      try {
        final response = await http.post(
          Uri.parse(ApiEndpoints.changeCandidatePassword),
          headers: {
            "Authorization": "Bearer ${widget.token}",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "current_password": currentPassword.text,
            "new_password": newPassword.text,
          }),
        );

        final data = jsonDecode(response.body);

        if (response.statusCode == 200 && data["success"] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Password updated successfully")),
          );
          currentPassword.clear();
          newPassword.clear();
          confirmPassword.clear();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(data["message"] ?? "Failed to update password")),
          );
        }
      } catch (e) {
        debugPrint("Password change error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Error changing password. Please try again.")),
        );
      } finally {
        setState(() => isLoading = false);
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Reset Password",
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Change your account password",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 30),
          _modernCard(
            "Change Password",
            Column(
              children: [
                CustomTextField(
                  label: "Current Password",
                  controller: currentPassword,
                  obscureText: true,
                  textColor: Colors.black,
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  label: "New Password",
                  controller: newPassword,
                  obscureText: true,
                  textColor: Colors.black,
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  label: "Confirm New Password",
                  controller: confirmPassword,
                  obscureText: true,
                  textColor: Colors.black,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 208, 32, 51),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            "Reset Password",
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
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
}
