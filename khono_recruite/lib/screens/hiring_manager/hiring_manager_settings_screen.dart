import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/api_endpoints.dart';
import '../../widgets/custom_textfield.dart';

class HiringManagerSettingsScreen extends StatefulWidget {
  final String token;
  final VoidCallback? onBack;

  const HiringManagerSettingsScreen({
    super.key,
    required this.token,
    this.onBack,
  });

  @override
  State<HiringManagerSettingsScreen> createState() =>
      _HiringManagerSettingsScreenState();
}

class _HiringManagerSettingsScreenState
    extends State<HiringManagerSettingsScreen> {
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
  String? _mfaQrCode;
  List<String> _backupCodes = [];
  int _backupCodesRemaining = 0;

  final TextEditingController _resetCurrentPassword = TextEditingController();
  final TextEditingController _resetNewPassword = TextEditingController();
  final TextEditingController _resetConfirmPassword = TextEditingController();
  bool _resetPasswordLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadMfaStatus();
  }

  @override
  void dispose() {
    _resetCurrentPassword.dispose();
    _resetNewPassword.dispose();
    _resetConfirmPassword.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final res = await http.get(
        Uri.parse(ApiEndpoints.currentUser),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        final user = data['user'] ?? data;
        final profile = user['profile'] is Map ? user['profile'] as Map : null;
        final prefs = profile != null && profile['preferences'] is Map
            ? profile['preferences'] as Map
            : null;
        if (prefs != null) {
          setState(() {
            _notificationsEnabled = prefs['notifications_enabled'] != false;
            _jobAlertsEnabled = prefs['job_alerts_enabled'] != false;
            _profileVisible = prefs['profile_visible'] != false;
            _enrollmentCompleted = prefs['enrollment_completed'] == true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMfaStatus() async {
    try {
      final result = await AuthService.getMfaStatus();
      if (result.containsKey('mfa_enabled') && mounted) {
        setState(() {
          _mfaEnabled = result['mfa_enabled'] == true;
          _backupCodesRemaining = result['backup_codes_remaining'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading MFA status: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final res = await http.get(
        Uri.parse(ApiEndpoints.currentUser),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );
      if (res.statusCode != 200) return;
      final data = json.decode(res.body);
      final user = data['user'] ?? data;
      final existing = Map<String, dynamic>.from(
        user['profile'] is Map ? user['profile'] as Map : {},
      );
      existing['preferences'] = {
        'dark_mode': themeProvider.isDarkMode,
        'notifications_enabled': _notificationsEnabled,
        'job_alerts_enabled': _jobAlertsEnabled,
        'profile_visible': _profileVisible,
        'enrollment_completed': _enrollmentCompleted,
      };
      final putRes = await http.put(
        Uri.parse(ApiEndpoints.updateAuthProfile),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'profile': existing}),
      );
      if (putRes.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings updated successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error saving preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Future<void> _enableMfa() async {
    setState(() => _mfaLoading = true);
    try {
      final result = await AuthService.enableMfa();
      if (result.containsKey('qr_code') && mounted) {
        setState(() {
          _mfaSecret = result['secret'];
          _mfaQrCode = result['qr_code'];
        });
        _showMfaSetupDialog();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to enable MFA: ${result['error'] ?? result['message'] ?? 'Unknown'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to enable MFA: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _mfaLoading = false);
    }
  }

  Future<void> _verifyMfaSetup(String token) async {
    setState(() => _mfaLoading = true);
    try {
      final result = await AuthService.verifyMfaSetup(token);
      if (result.containsKey('backup_codes') && mounted) {
        setState(() {
          _mfaEnabled = true;
          _backupCodes = List<String>.from(result['backup_codes']);
          _backupCodesRemaining = _backupCodes.length;
        });
        Navigator.pop(context);
        _showBackupCodesDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MFA enabled successfully')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('MFA setup failed: ${result['error'] ?? result['message'] ?? 'Unknown'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('MFA setup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _mfaLoading = false);
    }
  }

  Future<void> _disableMfa(String password) async {
    setState(() => _mfaLoading = true);
    try {
      final result = await AuthService.disableMfa(password);
      if (result.containsKey('message') && mounted) {
        setState(() {
          _mfaEnabled = false;
          _mfaSecret = null;
          _mfaQrCode = null;
          _backupCodes = [];
          _backupCodesRemaining = 0;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MFA disabled successfully')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disable MFA: ${result['error'] ?? result['message'] ?? 'Unknown'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disable MFA: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _mfaLoading = false);
    }
  }

  Future<void> _loadBackupCodes() async {
    try {
      final result = await AuthService.getBackupCodes();
      if (result.containsKey('backup_codes') && mounted) {
        setState(() {
          _backupCodes = List<String>.from(result['backup_codes']);
          _backupCodesRemaining = _backupCodes.length;
        });
        _showBackupCodesDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load backup codes: $e')),
        );
      }
    }
  }

  Future<void> _regenerateBackupCodes() async {
    setState(() => _mfaLoading = true);
    try {
      final result = await AuthService.regenerateBackupCodes();
      if (result.containsKey('backup_codes') && mounted) {
        setState(() {
          _backupCodes = List<String>.from(result['backup_codes']);
          _backupCodesRemaining = _backupCodes.length;
        });
        _showBackupCodesDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup codes regenerated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to regenerate backup codes: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _mfaLoading = false);
    }
  }

  void _showMfaSetupDialog() {
    final tokenController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Setup Two-Factor Authentication'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Scan the QR code with your authenticator app:',
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
                const Text('Or enter this secret manually:', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _mfaSecret ?? '',
                    style: const TextStyle(fontFamily: 'Monospace', fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Enter the 6-digit code from your app:'),
                const SizedBox(height: 8),
                TextField(
                  controller: tokenController,
                  decoration: const InputDecoration(
                    labelText: 'Verification Code',
                    border: OutlineInputBorder(),
                    hintText: '123456',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, letterSpacing: 4),
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
              onPressed: _mfaLoading
                  ? null
                  : () {
                      if (tokenController.text.length == 6) {
                        _verifyMfaSetup(tokenController.text);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a 6-digit code')),
                        );
                      }
                    },
              child: _mfaLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify & Enable'),
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
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.orange),
            SizedBox(width: 8),
            Text('Backup Codes'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Save these backup codes in a secure place. Each code can be used once if you lose access to your authenticator app.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
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
                                Icon(Icons.vpn_key, color: Colors.grey.shade600, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SelectableText(
                                    code,
                                    style: const TextStyle(
                                        fontFamily: 'Monospace',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "These codes won't be shown again. Make sure to save them now!",
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("I've Saved These Codes"),
          ),
        ],
      ),
    );
  }

  void _showDisableMfaDialog() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable Two-Factor Authentication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your password to disable 2FA:'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text.isNotEmpty) {
                _disableMfa(passwordController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disable 2FA'),
          ),
        ],
      ),
    );
  }

  Widget _modernCard(String title, Widget child, {Color? headerColor}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: headerColor ?? Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: themeProvider.isDarkMode ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }

  Widget _settingsSwitch(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    void Function(bool) onChanged,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                    color: themeProvider.isDarkMode ? Colors.white : Colors.grey.shade800,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: Colors.redAccent.withValues(alpha: 0.5),
            activeThumbColor: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _mfaOption(String title, String subtitle, IconData icon, {required VoidCallback onTap}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
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
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.blue, size: 20),
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
                          color: themeProvider.isDarkMode ? Colors.white : Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _securityTip(String title, String content, IconData icon, {Color color = Colors.blue}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
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
                    color: themeProvider.isDarkMode ? Colors.white : Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: const TextStyle(
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
                    color: themeProvider.isDarkMode ? Colors.white : Colors.grey.shade800,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
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
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: themeProvider.isDarkMode ? Colors.white : Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 24),

          // ---------- Preferences ----------
          _modernCard(
            'Preferences',
            Column(
              children: [
                _settingsSwitch(
                  'Dark Mode',
                  'Enable dark theme',
                  Icons.dark_mode_outlined,
                  themeProvider.isDarkMode,
                  (v) {
                    themeProvider.toggleTheme();
                    setState(() {});
                  },
                ),
                _settingsSwitch(
                  'Notifications',
                  'Receive push notifications',
                  Icons.notifications_outlined,
                  _notificationsEnabled,
                  (v) => setState(() => _notificationsEnabled = v),
                ),
                _settingsSwitch(
                  'Job Alerts',
                  'Get notified about new jobs',
                  Icons.work_outline,
                  _jobAlertsEnabled,
                  (v) => setState(() => _jobAlertsEnabled = v),
                ),
                _settingsSwitch(
                  'Profile Visibility',
                  'Make your profile visible to employers',
                  Icons.visibility_outlined,
                  _profileVisible,
                  (v) => setState(() => _profileVisible = v),
                ),
                _settingsSwitch(
                  'Enrollment Completed',
                  'Mark enrollment as completed',
                  Icons.check_circle_outline,
                  _enrollmentCompleted,
                  (v) => setState(() => _enrollmentCompleted = v),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _savePreferences,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Save Settings',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---------- 2FA ----------
          _modernCard(
            'Two-Factor Authentication',
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _mfaEnabled ? '2FA Enabled' : '2FA Disabled',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.isDarkMode ? Colors.white : Colors.grey.shade800,
                            ),
                          ),
                          Text(
                            _mfaEnabled
                                ? 'Your account is protected with two-factor authentication'
                                : 'Add an extra layer of security to your account',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          if (_mfaEnabled) ...[
                            const SizedBox(height: 8),
                            Text(
                              '$_backupCodesRemaining backup codes remaining',
                              style: GoogleFonts.inter(
                                fontSize: 12,
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
                const SizedBox(height: 20),
                if (!_mfaEnabled) ...[
                  Text(
                    'Two-factor authentication adds an additional layer of security by requiring more than just a password to sign in.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.security),
                                SizedBox(width: 8),
                                Text('Enable 2FA'),
                              ],
                            ),
                    ),
                  ),
                ] else ...[
                  _mfaOption(
                    'View Backup Codes',
                    'Get your current backup codes',
                    Icons.backup,
                    onTap: _loadBackupCodes,
                  ),
                  _mfaOption(
                    'Regenerate Backup Codes',
                    'Generate new backup codes (invalidates old ones)',
                    Icons.refresh,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Regenerate Backup Codes'),
                          content: const Text(
                            'This will invalidate all your existing backup codes. Are you sure?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _regenerateBackupCodes();
                              },
                              child: const Text('Regenerate'),
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
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _mfaLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.remove_circle_outline),
                                SizedBox(width: 8),
                                Text('Disable 2FA'),
                              ],
                            ),
                    ),
                  ),
                ],
                if (_mfaEnabled) ...[
                  const SizedBox(height: 24),
                  _securityTip(
                    'Save Backup Codes',
                    "Keep your backup codes in a safe place. You'll need them if you lose access to your authenticator app.",
                    Icons.warning_amber,
                    color: Colors.orange,
                  ),
                  _securityTip(
                    'Use Authenticator App',
                    'We recommend using Google Authenticator, Authy, or Microsoft Authenticator.',
                    Icons.security,
                    color: Colors.blue,
                  ),
                  _securityTip(
                    'Secure Your Device',
                    'Make sure your phone is protected with a PIN, pattern, or biometric lock.',
                    Icons.phone_android,
                    color: Colors.green,
                  ),
                ],
                const SizedBox(height: 24),
                _howItWorksStep(1, 'Scan QR Code', 'Use your authenticator app to scan the QR code'),
                _howItWorksStep(2, 'Enter Code', 'Enter the 6-digit code from your app'),
                _howItWorksStep(3, 'Save Backup Codes', "Keep your backup codes in a safe place"),
                _howItWorksStep(4, 'Enhanced Security', 'Your account is now protected with 2FA'),
              ],
            ),
            headerColor: Colors.blue.withValues(alpha: 0.1),
          ),

          // ---------- Reset Password ----------
          _buildResetPasswordSection(),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    if (_resetNewPassword.text != _resetConfirmPassword.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }
    setState(() => _resetPasswordLoading = true);
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.changeCandidatePassword),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'current_password': _resetCurrentPassword.text,
          'new_password': _resetNewPassword.text,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully')),
        );
        _resetCurrentPassword.clear();
        _resetNewPassword.clear();
        _resetConfirmPassword.clear();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to update password')),
        );
      }
    } catch (e) {
      debugPrint('Password change error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error changing password. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _resetPasswordLoading = false);
    }
  }

  Widget _buildResetPasswordSection() {
    return _modernCard(
      'Reset Password',
      Column(
        children: [
          CustomTextField(
            label: 'Current Password',
            controller: _resetCurrentPassword,
            obscureText: true,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'New Password',
            controller: _resetNewPassword,
            obscureText: true,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Confirm New Password',
            controller: _resetConfirmPassword,
            obscureText: true,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _resetPasswordLoading ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
