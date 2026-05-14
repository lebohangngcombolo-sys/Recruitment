import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../constants/brand_tokens.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/themed_dialog.dart';
import '../../widgets/themed_surface_card.dart';
import '../../widgets/state_widgets.dart';

class AdminSettingsScreen extends StatefulWidget {
  final bool embedded;

  const AdminSettingsScreen({
    super.key,
    this.embedded = false,
  });

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _loading = true;

  // Preferences
  bool _notificationsEnabled = true;
  bool _jobAlertsEnabled = true;
  bool _profileVisible = true;
  bool _enrollmentCompleted = false;

  // MFA
  bool _mfaEnabled = false;
  bool _mfaLoading = false;
  String? _mfaSecret;
  List<String> _backupCodes = [];
  int _backupCodesRemaining = 0;

  // Password Reset
  final TextEditingController _resetCurrentPassword = TextEditingController();
  final TextEditingController _resetNewPassword = TextEditingController();
  final TextEditingController _resetConfirmPassword = TextEditingController();
  bool _resetPasswordLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() => _loading = true);

      // Mock settings data - replace with actual API calls
      final mockSettings = {
        'notifications_enabled': true,
        'job_alerts_enabled': true,
        'profile_visible': true,
        'enrollment_completed': false,
        'mfa_enabled': false,
        'mfa_secret': null,
        'mfa_qr_code': null,
        'backup_codes': [],
        'backup_codes_remaining': 0,
      };

      setState(() {
        _notificationsEnabled =
            (mockSettings['notifications_enabled'] as bool?) ?? true;
        _jobAlertsEnabled =
            (mockSettings['job_alerts_enabled'] as bool?) ?? true;
        _profileVisible = (mockSettings['profile_visible'] as bool?) ?? true;
        _enrollmentCompleted =
            (mockSettings['enrollment_completed'] as bool?) ?? false;
        _mfaEnabled = (mockSettings['mfa_enabled'] as bool?) ?? false;
        _mfaSecret = mockSettings['mfa_secret'] as String?;
        _backupCodes =
            List<String>.from(mockSettings['backup_codes'] as Iterable? ?? []);
        _backupCodesRemaining =
            (mockSettings['backup_codes_remaining'] as int?) ?? 0;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: BrandTokens.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final body = _loading
        ? const ThemedLoadingState(
            message: 'Loading Settings...',
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Preferences'),
                const SizedBox(height: 16),
                _buildPreferencesSection(),
                const SizedBox(height: 32),
                _buildSectionHeader('Security'),
                const SizedBox(height: 16),
                _buildSecuritySection(),
                const SizedBox(height: 32),
                _buildSectionHeader('Password Reset'),
                const SizedBox(height: 16),
                _buildPasswordResetSection(),
              ],
            ),
          );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor:
            themeProvider.isDarkMode ? BrandTokens.darkSurface : Colors.white,
        elevation: 0,
        title: Text(
          'Admin Settings',
          style: GoogleFonts.poppins(
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(
          color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      body: body,
    );
  }

  Widget _buildSectionHeader(String title) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: BrandTokens.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return ThemedSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToggleItem(
            'Push Notifications',
            _notificationsEnabled,
            (value) => _updateSetting('notifications_enabled', value),
            'Receive notifications about applications and interviews',
          ),
          const SizedBox(height: 16),
          _buildToggleItem(
            'Job Alerts',
            _jobAlertsEnabled,
            (value) => _updateSetting('job_alerts_enabled', value),
            'Get alerts for new job postings and candidate applications',
          ),
          const SizedBox(height: 16),
          _buildToggleItem(
            'Profile Visibility',
            _profileVisible,
            (value) => _updateSetting('profile_visible', value),
            'Control profile visibility in the system',
          ),
          const SizedBox(height: 16),
          _buildToggleItem(
            'Enrollment Completed',
            _enrollmentCompleted,
            (value) => _updateSetting('enrollment_completed', value),
            'Mark enrollment process as completed',
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(
    String title,
    bool value,
    Function(bool) onChanged,
    String description,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? BrandTokens.darkSurface.withValues(alpha: 0.5)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: themeProvider.isDarkMode
                        ? Colors.white70
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: BrandTokens.primary,
            inactiveThumbColor: themeProvider.isDarkMode
                ? Colors.grey.shade600
                : Colors.grey.shade400,
            activeTrackColor: themeProvider.isDarkMode
                ? BrandTokens.primary.withValues(alpha: 0.3)
                : BrandTokens.primary.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ThemedSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MFA Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode
                  ? BrandTokens.primary.withValues(alpha: 0.1)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Two-Factor Authentication',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    if (!_mfaEnabled)
                      TextButton(
                        onPressed: _enableMfa,
                        style: TextButton.styleFrom(
                          foregroundColor: BrandTokens.primary,
                        ),
                        child: Text(
                          'Enable',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _mfaEnabled ? 'Enabled' : 'Disabled',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _mfaEnabled ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_mfaEnabled && _mfaSecret != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'MFA is configured for your account',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: themeProvider.isDarkMode
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Backup Codes: $_backupCodesRemaining',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: themeProvider.isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _regenerateBackupCodes,
                            style: TextButton.styleFrom(
                              foregroundColor: BrandTokens.primary,
                            ),
                            child: Text(
                              'Regenerate',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // MFA Setup Button
          if (!_mfaEnabled)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showMfaSetupDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandTokens.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(BrandTokens.buttonRadius),
                  ),
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
                    : Text(
                        'Setup Two-Factor Authentication',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPasswordResetSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ThemedSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Reset',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Change your account password for security purposes',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          CustomTextField(
            controller: _resetCurrentPassword,
            label: 'Current Password',
            obscureText: true,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _resetNewPassword,
            label: 'New Password',
            obscureText: true,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _resetConfirmPassword,
            label: 'Confirm New Password',
            obscureText: true,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _resetPasswordLoading ? null : _resetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandTokens.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
                ),
              ),
              child: _resetPasswordLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Reset Password',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      setState(() => _loading = true);

      // Mock API call - replace with actual API call
      await Future.delayed(const Duration(seconds: 1));

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Setting updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating setting: $e'),
          backgroundColor: BrandTokens.primary,
        ),
      );
    }
  }

  Future<void> _enableMfa() async {
    try {
      setState(() => _mfaLoading = true);

      // Mock API call - replace with actual API call
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _mfaEnabled = true;
        _mfaLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('MFA enabled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _mfaLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error enabling MFA: $e'),
          backgroundColor: BrandTokens.primary,
        ),
      );
    }
  }

  Future<void> _regenerateBackupCodes() async {
    try {
      setState(() => _mfaLoading = true);

      // Mock API call - replace with actual API call
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _backupCodes = ['123456', '789012', '345678', '901234'];
        _backupCodesRemaining = _backupCodes.length;
        _mfaLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup codes regenerated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _mfaLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error regenerating backup codes: $e'),
          backgroundColor: BrandTokens.primary,
        ),
      );
    }
  }

  Future<void> _resetPassword() async {
    if (_resetCurrentPassword.text.isEmpty ||
        _resetNewPassword.text.isEmpty ||
        _resetConfirmPassword.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all password fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_resetNewPassword.text != _resetConfirmPassword.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() => _resetPasswordLoading = true);

      // Mock API call - replace with actual API call
      await Future.delayed(const Duration(seconds: 2));

      setState(() => _resetPasswordLoading = false);

      _resetCurrentPassword.clear();
      _resetNewPassword.clear();
      _resetConfirmPassword.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _resetPasswordLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resetting password: $e'),
          backgroundColor: BrandTokens.primary,
        ),
      );
    }
  }

  void _showMfaSetupDialog() {
    final tokenController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ThemedDialog(
        title: 'Setup Two-Factor Authentication',
        subtitle: 'Scan the QR code or enter a manual code to verify',
        icon: Icon(Icons.shield_outlined, color: BrandTokens.primary),
        iconColor: BrandTokens.primary,
        showCloseButton: false,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scan this QR code with your authenticator app',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(BrandTokens.cardRadius),
                ),
                child: Center(
                  child: Text(
                    'QR Code Placeholder',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: tokenController,
                label: 'Or enter manual code',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _mfaLoading
                ? null
                : () {
                    // Mock MFA setup
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('MFA setup completed'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandTokens.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BrandTokens.buttonRadius),
              ),
            ),
            child: _mfaLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Verify',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
