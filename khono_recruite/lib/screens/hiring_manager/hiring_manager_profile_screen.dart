// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/api_endpoints.dart';

class HiringManagerProfileScreen extends StatefulWidget {
  final String token;

  /// When set (e.g. when embedded in dashboard), back button calls this instead of popping.
  final VoidCallback? onBack;

  const HiringManagerProfileScreen({
    super.key,
    required this.token,
    this.onBack,
  });

  @override
  State<HiringManagerProfileScreen> createState() =>
      _HiringManagerProfileScreenState();
}

class _HiringManagerProfileScreenState
    extends State<HiringManagerProfileScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _preferredNameController =
      TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _managerController = TextEditingController();

  String? _selectedDepartment;
  String? _selectedDesignation;
  String? _profileImageUrl;

  final List<String> _departments = const [
    'Management',
    'Operations',
    'Finance',
    'HR',
    'Sales',
  ];

  final List<String> _designations = const [
    'Director',
    'Developer',
    'Support Analyst',
    'Learner',
    'UX Designer',
    'AWS Cloud Engineer',
    'Tester',
    'Finance',
    'Business Analyst',
    'Manager',
    'Delivery Manager',
    'Analyst',
    'Sales Person',
    'HR',
    'Junior Analyst',
  ];

  String? _phoneError;
  String? _emailError;
  bool _loading = true;
  bool _saving = false;
  bool _dataLoaded = false;

  bool _isEditing = false;
  bool _dirty = false;

  XFile? _profileImage;
  Uint8List? _profileImageBytes;
  final ImagePicker _picker = ImagePicker();

  void _markDirty() {
    if (!_dataLoaded) return;
    if (mounted) setState(() => _dirty = true);
  }

  bool _validateFields() {
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    bool isValid = true;

    if (mounted) {
      setState(() {
        if (phone.isNotEmpty && phone.length != 10) {
          _phoneError =
              'Please enter a valid 10-digit phone number\nExample: 0123456789';
          isValid = false;
        } else {
          _phoneError = null;
        }

        if (email.isNotEmpty &&
            !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
          _emailError = 'Please enter a valid email address';
          isValid = false;
        } else {
          _emailError = null;
        }
      });
    }
    if (_firstNameController.text.trim().isEmpty ||
        _surnameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      isValid = false;
    }

    return isValid;
  }

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_markDirty);
    _surnameController.addListener(_markDirty);
    _emailController.addListener(_markDirty);
    _phoneController.addListener(_markDirty);
    _preferredNameController.addListener(_markDirty);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_markDirty);
    _surnameController.removeListener(_markDirty);
    _emailController.removeListener(_markDirty);
    _phoneController.removeListener(_markDirty);
    _preferredNameController.removeListener(_markDirty);
    _firstNameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _preferredNameController.dispose();
    _designationController.dispose();
    _managerController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = await AuthService.getUserProfile(widget.token);
      final user = data['user'] as Map<String, dynamic>?;
      if (user == null) return;

      final profile = Map<String, dynamic>.from(user['profile'] ?? {});
      final email = (user['email'] ?? '').toString();
      final firstName = (profile['first_name'] ??
              profile['full_name']?.toString().split(' ').first ??
              '')
          .toString();
      final lastName = (profile['last_name'] ??
              profile['full_name']?.toString().split(' ').skip(1).join(' ') ??
              '')
          .toString();
      final phone = (profile['phone'] ?? '').toString();
      final deptRaw = (profile['department'] ?? '').toString().trim();
      final desigRaw = (profile['designation'] ?? '').toString().trim();
      final preferred = (profile['preferred_name'] ?? '').toString();
      final manager = (profile['managed_by'] ?? '').toString();
      final profileImageUrl = (profile['profile_picture'] ?? '').toString();

      String? matchedDept;
      if (deptRaw.isNotEmpty) {
        try {
          matchedDept = _departments.firstWhere(
            (d) => d.toLowerCase() == deptRaw.toLowerCase(),
          );
        } catch (_) {
          matchedDept = null;
        }
      }

      String? matchedDesig;
      if (desigRaw.isNotEmpty) {
        try {
          matchedDesig = _designations.firstWhere(
            (d) => d.toLowerCase() == desigRaw.toLowerCase(),
          );
        } catch (_) {
          matchedDesig = null;
        }
      }

      setState(() {
        _firstNameController.text = firstName;
        _surnameController.text = lastName;
        _emailController.text = email;
        _phoneController.text = phone;
        _preferredNameController.text = preferred;
        _managerController.text = manager;
        _selectedDepartment = matchedDept;
        _selectedDesignation = matchedDesig;
        _profileImageUrl = profileImageUrl.isNotEmpty ? profileImageUrl : null;

        _isEditing = false;
        _dirty = false;
      });
    } catch (e) {
      debugPrint('Error loading hiring manager profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _dataLoaded = true;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_saving || !_validateFields()) return;

    if (mounted) setState(() => _saving = true);
    try {
      final profileData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _surnameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'department': _selectedDepartment ?? '',
        'designation': _selectedDesignation ?? '',
        'preferred_name': _preferredNameController.text.trim(),
        'managed_by': _managerController.text.trim(),
        'profile_picture': _profileImageUrl ?? '',
      };

      final response = await http.put(
        Uri.parse(ApiEndpoints.updateAuthProfile),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({'profile': profileData}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _isEditing = false;
            _dirty = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        }
      } else {
        final body = json.decode(response.body);
        final msg =
            body['error'] ?? body['message'] ?? 'Failed to save profile';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg.toString())),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickProfileImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) _profileImageBytes = await pickedFile.readAsBytes();
      if (mounted) setState(() => _profileImage = pickedFile);
      await _uploadProfileImage();
    }
  }

  /// Uploads image to backend; backend uses Cloudinary (.env) and saves URL to user profile.
  Future<void> _uploadProfileImage() async {
    if (_profileImage == null) return;
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiEndpoints.uploadAuthProfilePicture),
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
        final url = respJson['data']?['profile_picture']?.toString() ?? '';
        if (mounted) {
          setState(() {
            _profileImageUrl = url.isNotEmpty ? url : null;
            _profileImage = null;
            _profileImageBytes = null;
          });
        }
      } else {
        final msg = respJson['message'] ?? 'Upload failed';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg.toString())),
          );
        }
      }
    } catch (e) {
      debugPrint('Profile image upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  ImageProvider<Object> _getProfileImageProvider() {
    if (_profileImage != null) {
      if (kIsWeb) return MemoryImage(_profileImageBytes!);
      return FileImage(File(_profileImage!.path));
    }
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return NetworkImage(_profileImageUrl!);
    }
    return const AssetImage('assets/images/profile_placeholder.png');
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    if (_loading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(themeProvider.backgroundImage),
              fit: BoxFit.cover,
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(themeProvider.backgroundImage),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!_isEditing)
                      ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () {
                                setState(() {
                                  _isEditing = true;
                                  _dirty = false;
                                });
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC10D00),
                        ),
                        child: const Text(
                          'Edit',
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: (_saving || !_dirty) ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC10D00),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(fontFamily: 'Poppins'),
                              ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFC10D00).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _pickProfileImage,
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: (_profileImage != null ||
                                      (_profileImageUrl != null &&
                                          _profileImageUrl!.isNotEmpty))
                                  ? Colors.grey.shade700
                                  : const Color(0xFFC10D00),
                              backgroundImage: (_profileImage != null ||
                                      (_profileImageUrl != null &&
                                          _profileImageUrl!.isNotEmpty))
                                  ? _getProfileImageProvider()
                                  : null,
                              child: (_profileImage == null &&
                                      (_profileImageUrl == null ||
                                          _profileImageUrl!.isEmpty))
                                  ? const Icon(
                                      Icons.person,
                                      size: 44,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap to upload',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hiring Manager',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Text(
                              _emailController.text.isEmpty
                                  ? 'Loading...'
                                  : _emailController.text,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFC10D00).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildEditableField(
                                  'First Name',
                                  _firstNameController,
                                  readOnly: !_isEditing,
                                ),
                                const SizedBox(height: 16),
                                _buildEditableField(
                                  'Surname',
                                  _surnameController,
                                  readOnly: !_isEditing,
                                ),
                                const SizedBox(height: 16),
                                _buildEditableField(
                                  'Email Address',
                                  _emailController,
                                  errorText: _emailError,
                                  readOnly: !_isEditing,
                                ),
                                const SizedBox(height: 16),
                                _buildEditableField(
                                  'Phone Number',
                                  _phoneController,
                                  errorText: _phoneError,
                                  readOnly: !_isEditing,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDropdownField(
                                  'Department',
                                  _selectedDepartment,
                                  _departments,
                                  (String? newValue) {
                                    if (!_isEditing) return;
                                    setState(() {
                                      _selectedDepartment = newValue;
                                      _dirty = true;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildDropdownField(
                                  'Designation',
                                  _selectedDesignation,
                                  _designations,
                                  (String? newValue) {
                                    if (!_isEditing) return;
                                    setState(() {
                                      _selectedDesignation = newValue;
                                      _dirty = true;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildEditableField(
                                  'Preferred Name',
                                  _preferredNameController,
                                  readOnly: !_isEditing,
                                ),
                                const SizedBox(height: 16),
                                _buildEditableField(
                                  'Manager',
                                  _managerController,
                                  readOnly: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller, {
    String? errorText,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: readOnly
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: errorText != null
                  ? Colors.redAccent
                  : Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            style: TextStyle(
              color: readOnly ? Colors.white70 : Colors.white,
              fontSize: 16,
              fontFamily: 'Poppins',
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              errorText: errorText,
              errorStyle: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                height: 0.8,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    String? initialValue,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: DropdownButtonFormField<String>(
            value: initialValue,
            dropdownColor: Colors.grey[800],
            style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[800]!.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            hint: Text(
              'Select $label',
              style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins'),
            ),
            items: items
                .map((String item) =>
                    DropdownMenuItem<String>(value: item, child: Text(item)))
                .toList(),
            onChanged: _isEditing ? onChanged : null,
          ),
        ),
      ],
    );
  }
}
