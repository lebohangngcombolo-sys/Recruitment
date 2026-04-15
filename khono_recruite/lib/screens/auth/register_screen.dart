import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_version.dart';

/// Hides the scrollbar while keeping scroll behavior (e.g. for auth screens).
class _NoScrollbarScrollBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();

  bool _obscurePassword = true;
  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final data = {
      "email": emailController.text.trim(),
      "password": passwordController.text.trim(),
      "first_name": firstNameController.text.trim(),
      "last_name": lastNameController.text.trim(),
      "role": "candidate",
    };

    final result = await AuthService.register(data);
    setState(() => loading = false);

    final status = result['status'] as int? ?? 0;
    final body = result['body'] is Map<String, dynamic>
        ? result['body'] as Map<String, dynamic>
        : <String, dynamic>{};

    if (status != 201 && status != 200) {
      final errors = body['errors'];
      final errorMsg = body['error'];
      String errorMessage;
      if (status == 409) {
        errorMessage =
            'An account with this email already exists. Please log in or use a different email.';
      } else {
        errorMessage = errors is List
            ? (errors.isNotEmpty
                ? errors.join('\n')
                : (errorMsg is String ? errorMsg : 'Registration failed.'))
            : (errorMsg is String ? errorMsg : 'Registration failed.');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    try {
      // When email is not configured, backend returns access_token and dashboard; log user in and go there.
      final accessToken = body['access_token'] as String?;
      if (accessToken != null && accessToken.isNotEmpty) {
        final refreshToken = body['refresh_token'] as String?;
        await AuthService.saveTokens(accessToken, refreshToken);
        final user = body['user'];
        if (user is Map<String, dynamic>) {
          await AuthService.saveUserInfo(user);
        }
        if (!context.mounted) return;
        final dashboardPath = body['dashboard'] as String? ?? '/enrollment';
        final safePath =
            dashboardPath.startsWith('/') ? dashboardPath : '/$dashboardPath';
        context.go('$safePath?token=${Uri.encodeComponent(accessToken)}');
        return;
      }

      // Email verification required: go to verify-email page (backend sent the code by email, or returned it if email failed)
      final email = emailController.text.trim();
      final codeFromServer = body['verification_code'] as String?;
      if (!context.mounted) return;
      String verifyUrl = '/verify-email?email=${Uri.encodeComponent(email)}';
      if (codeFromServer != null && codeFromServer.isNotEmpty) {
        verifyUrl += '&code=${Uri.encodeComponent(codeFromServer)}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Email could not be sent. Use the code shown on the next screen to verify.'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
      context.go(verifyUrl);
    } catch (e, st) {
      // Defensive: any uncaught error (e.g. storage, navigation) — still try to reach verify-email so user can enter code
      if (context.mounted) {
        debugPrint('Register post-201 error: $e $st');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Registration succeeded. Please check your email for the verification code.')),
        );
        context.go(
          '/verify-email?email=${Uri.encodeComponent(emailController.text.trim())}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final size = MediaQuery.of(context).size;
    final contentWidth = size.width > 840 ? 410.0 : size.width * 0.92;
    final logoWidth = size.width > 840 ? 360.0 : contentWidth;
    final logoHeight = size.width > 840 ? 68.0 : 56.0;
    const headingFontSize = 17.21;
    const headingLineHeight = 24.6;
    const headingLetterSpacing = 0.17; // ~1% at 17.21
    const buttonWidth = 199.11;
    const buttonHeight = 32.22;
    const buttonGap = 10.16;
    const lightInk = Color(0xFF090812);
    final onSurface = isDark ? Colors.white : lightInk;
    final onSurfaceMuted = isDark
        ? Colors.white.withValues(alpha: 0.78)
        : lightInk.withValues(alpha: 0.72);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.redAccent,
        onPressed: themeProvider.toggleTheme,
        tooltip: themeProvider.isDarkMode
            ? 'Switch to light mode'
            : 'Switch to dark mode',
        child: Icon(
          themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
          color: Colors.white,
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child:
                Image.asset(themeProvider.backgroundImage, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.36)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          SafeArea(
            child: ScrollConfiguration(
              behavior: _NoScrollbarScrollBehavior(),
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: size.height - 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: logoWidth,
                        height: logoHeight,
                        child: Image.asset(
                          'assets/icons/khono.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: contentWidth,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: SizedBox(
                                  width: contentWidth,
                                  child: Text(
                                    'Register your account details:',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    style: GoogleFonts.poppins(
                                      color: onSurface,
                                      fontSize: headingFontSize,
                                      height:
                                          headingLineHeight / headingFontSize,
                                      letterSpacing: headingLetterSpacing,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDarkTextField(
                                      isDark: isDark,
                                      label: 'First Name',
                                      hint: 'Name',
                                      controller: firstNameController,
                                      action: TextInputAction.next,
                                      validator: (value) => (value == null ||
                                              value.trim().isEmpty)
                                          ? 'First name is required'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildDarkTextField(
                                      isDark: isDark,
                                      label: 'Last Name',
                                      hint: 'Surname',
                                      controller: lastNameController,
                                      action: TextInputAction.next,
                                      validator: (value) => (value == null ||
                                              value.trim().isEmpty)
                                          ? 'Last name is required'
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildDarkTextField(
                                isDark: isDark,
                                label: 'Email Address',
                                hint: 'name.surname@khonology.com',
                                controller: emailController,
                                action: TextInputAction.next,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  final v = value?.trim() ?? '';
                                  if (v.isEmpty) return 'Email is required';
                                  if (!v.contains('@'))
                                    return 'Enter a valid email';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildDarkTextField(
                                isDark: isDark,
                                label: 'Password',
                                hint: '********',
                                controller: passwordController,
                                action: TextInputAction.done,
                                obscure: _obscurePassword,
                                onSubmitted: (_) => register(),
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: onSurfaceMuted,
                                    size: 18,
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                                validator: (value) {
                                  final v = value?.trim() ?? '';
                                  if (v.isEmpty) return 'Password is required';
                                  if (v.length < 6)
                                    return 'At least 6 characters';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              Center(
                                child: SizedBox(
                                  width: size.width > 840
                                      ? 2 * buttonWidth + buttonGap - 28
                                      : contentWidth - 32,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: buttonHeight,
                                          child: ElevatedButton(
                                            onPressed:
                                                loading ? null : register,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFC10D00),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shadowColor: Colors.transparent,
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        20.32),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 20.32,
                                                vertical: 0,
                                              ),
                                            ),
                                            child: loading
                                                ? const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                              Color>(
                                                        Colors.white,
                                                      ),
                                                    ),
                                                  )
                                                : Text(
                                                    'REGISTER',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 11.06,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 0.11,
                                                      height: 1,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: buttonGap),
                                      Expanded(
                                        child: SizedBox(
                                          height: buttonHeight,
                                          child: ElevatedButton(
                                            onPressed: () => context.go('/'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFA2A5AA),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shadowColor: Colors.transparent,
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        20.32),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 20.32,
                                                vertical: 0,
                                              ),
                                            ),
                                            child: Text(
                                              'BACK',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11.06,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.11,
                                                height: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Already have an account? ',
                                      style: GoogleFonts.poppins(
                                        color: onSurfaceMuted,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => context.go('/login'),
                                      child: Text(
                                        'Log In',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFFC10D00),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
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
                      const SizedBox(height: 16),
                      Opacity(
                        opacity: 0.92,
                        child: Image.asset(
                          isDark
                              ? 'assets/images/discs.png'
                              : 'assets/images/logo.png',
                          width: 120,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.black12,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  kDisplayVersion,
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white70 : onSurfaceMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          if (loading)
            Center(
              child: CircularProgressIndicator(
                color: isDark ? Colors.white : const Color(0xFFC10D00),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDarkTextField({
    required bool isDark,
    required String label,
    required String hint,
    required TextEditingController controller,
    required TextInputAction action,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    const lightInk = Color(0xFF090812);
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.78) : lightInk;
    final textColor = isDark ? Colors.white : lightInk;
    final hintColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : lightInk.withValues(alpha: 0.6);
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.64) : lightInk;
    final focusedColor = isDark ? Colors.white : lightInk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: labelColor,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscure,
          textInputAction: action,
          onFieldSubmitted: onSubmitted,
          style: GoogleFonts.poppins(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: hintColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: Colors.transparent,
            suffixIcon: suffix,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            errorStyle: GoogleFonts.poppins(
              color: const Color(0xFFFF8E8E),
              fontSize: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: borderColor,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: borderColor,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: focusedColor,
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
