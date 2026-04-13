import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_version.dart';
import 'mfa_verification_screen.dart'; // 🆕 Import MFA screen
// 🆕 Import SSO Enterprise screen

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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const double _logoWidth = 609.02;
  static const double _logoHeight = 114.34;
  static const double _panelWidth = 360;
  static const double _fieldWidth = 310;
  static const double _titleBlockHeight = 52;
  static const double _subtitleBlockHeight = 44;
  static const double _inputHeight = 38;
  static const double _buttonHeight = 38;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool loading = false;
  bool _obscurePassword = true;
  String? _loginErrorMessage;

  // 🆕 MFA state variables - PROPERLY TYPED
  String? _mfaSessionToken;
  String? _userId; // 🆕 Ensure this is String, not int
  bool _showMfaForm = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // 🆕 UPDATED LOGIN WITH MFA SUPPORT - Navigation approach
  void _login() async {
    setState(() {
      loading = true;
      _loginErrorMessage = null;
    });
    try {
      final result = await AuthService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      ).timeout(const Duration(seconds: 15));

      if (result['success'] == true) {
        // 🆕 Check if MFA is required
        if (result['mfa_required'] == true) {
          // 🆕 STORE THE MFA SESSION TOKEN IN STATE
          setState(() {
            _mfaSessionToken = result['mfa_session_token'];
            _userId =
                result['user_id']?.toString() ?? ''; // 🆕 Convert to string
          });

          // Navigate to MFA verification screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MfaVerificationScreen(
                mfaSessionToken: result['mfa_session_token'],
                userId:
                    result['user_id']?.toString() ?? '', // 🆕 Convert to string
                onVerify: _verifyMfa,
                onBack: () {
                  Navigator.pop(context);
                  // 🆕 Clear MFA state when going back
                  setState(() {
                    _mfaSessionToken = null;
                    _userId = null;
                  });
                },
                isLoading: false,
              ),
            ),
          );
        } else {
          // Fast-first navigation: don't block dashboard redirect on profile prefetch.
          unawaited(_prefetchCurrentUser(result['access_token']));
          _navigateToDashboard(
            token: result['access_token'],
            role: result['role'],
            dashboard: result['dashboard'],
          );
        }
      } else {
        setState(() {
          _loginErrorMessage = _friendlyLoginMessage(
            result['error']?.toString() ?? result['message']?.toString(),
          );
        });
      }
    } catch (e) {
      setState(() {
        _loginErrorMessage = _friendlyLoginMessage(e.toString());
      });
    } finally {
      setState(() => loading = false);
    }
  }

  String _friendlyLoginMessage(String? raw) {
    final msg = (raw ?? '').toLowerCase();
    if (msg.contains('credential') ||
        msg.contains('invalid') ||
        msg.contains('incorrect') ||
        msg.contains('password') ||
        msg.contains('email')) {
      return 'Email or password is incorrect. Please try again.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Login is taking too long. Please try again in a moment.';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'We could not connect. Please check your internet and try again.';
    }
    return 'Something is wrong. Please try again.';
  }

// 🆕 MFA VERIFICATION - Updated for navigation approach
  void _verifyMfa(String token) async {
    // 🆕 ADD NULL SAFETY CHECK
    if (_mfaSessionToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("MFA session expired. Please login again.")),
      );
      return;
    }

    try {
      final result = await AuthService.verifyMfaLogin(_mfaSessionToken!, token);

      if (result['success'] == true) {
        // 🆕 CLEAR MFA STATE AFTER SUCCESS
        setState(() {
          _mfaSessionToken = null;
          _userId = null;
        });

        // Pop MFA screen, prefetch current user so dashboard shows name from first paint, then navigate
        Navigator.pop(context); // Close MFA screen
        unawaited(_prefetchCurrentUser(result['access_token']));
        _navigateToDashboard(
          token: result['access_token'] as String,
          role: (result['user']?['role'] ?? result['role']) as String? ??
              'candidate',
          dashboard: result['dashboard'] as String? ?? '/candidate-dashboard',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  result['message']?.toString() ?? "MFA verification failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("MFA verification error: $e")),
      );
    }
  }

  // 🆕 BACK TO LOGIN FORM
  void _backToLogin() {
    setState(() {
      _showMfaForm = false;
      _mfaSessionToken = null;
      _userId = null;
    });
  }

  Future<void> _prefetchCurrentUser(String token) async {
    try {
      await AuthService.getCurrentUser(token: token);
    } catch (_) {}
  }

  // ------------------- SOCIAL LOGIN -------------------
  void _socialLogin(String provider) async {
    setState(() => loading = true);
    try {
      final url = provider == "Google"
          ? AuthService.googleOAuthUrl
          : AuthService.githubOAuthUrl;

      if (kIsWeb) {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), webOnlyWindowName: "_self");
        }
      } else {
        final loginResult = provider == "Google"
            ? await AuthService.loginWithGoogle()
            : await AuthService.loginWithGithub();

        if (loginResult['access_token'] != null) {
          unawaited(_prefetchCurrentUser(loginResult['access_token']));
          _navigateToDashboard(
            token: loginResult['access_token'],
            role: loginResult['role'],
            dashboard: loginResult['dashboard'],
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Social login error: $e")));
      setState(() => loading = false);
    }
  }

  // ------------------- NAVIGATION HELPER -------------------
  // Use GoRouter (context.go) so we don't trigger Navigator._debugLocked.
  // Defer to next frame so navigation runs after current build completes.
  Future<void> _navigateToDashboard({
    required String token,
    required String role,
    required String dashboard,
  }) async {
    final encodedToken = Uri.encodeComponent(token);
    final path = switch (role) {
      "admin" => '/admin-dashboard?token=$encodedToken',
      "hiring_manager" => '/hiring-manager-dashboard?token=$encodedToken',
      "hr" => '/hr-dashboard?token=$encodedToken',
      "candidate" when dashboard == "/enrollment" =>
        '/enrollment?token=$encodedToken',
      _ => '/candidate-dashboard?token=$encodedToken',
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      context.go(path);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🆕 Show MFA form if required
    if (_showMfaForm) {
      return MfaVerificationScreen(
        mfaSessionToken: _mfaSessionToken!,
        userId: _userId!,
        onVerify: _verifyMfa,
        onBack: _backToLogin,
        isLoading: loading,
      );
    }

    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final panelColor = isDark
        ? const Color(0xFF1F1F26).withOpacity(0.92)
        : Colors.white.withOpacity(0.94);
    final fieldFill = isDark ? const Color(0xFF3D3F40) : const Color(0xFFECECEF);
    final fieldText = isDark ? const Color(0xFFA8ABB2) : const Color(0xFF2C2C2C);
    final hintColor =
        isDark ? const Color(0xFFA8ABB2) : const Color(0xFF6B6B6B);
    final titleColor = isDark ? const Color(0xFFF2F4F8) : const Color(0xFF1A1A1A);
    final subtitleColor = isDark ? const Color(0xFFD0D4DB) : const Color(0xFF5C5C5C);
    final panelBorder =
        isDark ? Colors.white10 : Colors.black.withOpacity(0.08);
    final panelShadowOpacity = isDark ? 0.45 : 0.12;

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
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(themeProvider.backgroundImage),
                  fit: BoxFit.cover,
                  alignment: Alignment(0.12, 0.0),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              color: isDark
                  ? Colors.black.withOpacity(0.28)
                  : Colors.black.withOpacity(0.06),
            ),
          ),

          Center(
            child: ScrollConfiguration(
              behavior: _NoScrollbarScrollBehavior(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: _logoWidth,
                      height: _logoHeight,
                      child: Image.asset(
                        'assets/icons/khono.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: _panelWidth,
                      decoration: BoxDecoration(
                        color: panelColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: panelBorder, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(panelShadowOpacity),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(17, 19, 17, 18),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: _fieldWidth,
                                  height: _titleBlockHeight,
                                  child: Center(
                                    child: Text(
                                      "Automated Recruitment Workflow",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        color: titleColor,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w600,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: _fieldWidth,
                                  height: _subtitleBlockHeight,
                                  child: Text(
                                    "Enter your user details to sign in as directed below.",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: subtitleColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildInput(
                                  controller: emailController,
                                  hint: "Email",
                                  action: TextInputAction.next,
                                  fillColor: fieldFill,
                                  textColor: fieldText,
                                  hintColor: hintColor,
                                ),
                                const SizedBox(height: 10),
                                _buildInput(
                                  controller: passwordController,
                                  hint: "Password",
                                  action: TextInputAction.done,
                                  obscure: _obscurePassword,
                                  onSubmitted: (_) => _login(),
                                  fillColor: fieldFill,
                                  textColor: fieldText,
                                  hintColor: hintColor,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey.shade600,
                                      size: 16,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: _fieldWidth,
                                  height: _buttonHeight,
                                  child: ElevatedButton(
                                    onPressed: loading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFC10D00),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20.54),
                                      ),
                                    ),
                                    child: loading
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            "LOGIN",
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _socialCircle(
                                      icon: Image.asset(
                                        'assets/icons/google.png',
                                        width: 16,
                                        height: 16,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.g_mobiledata_rounded,
                                          size: 18,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      onTap: loading
                                          ? null
                                          : () => _socialLogin("Google"),
                                    ),
                                    const SizedBox(width: 10),
                                    _socialCircle(
                                      icon: Image.asset(
                                        'assets/icons/microsoft.png',
                                        width: 16,
                                        height: 16,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.window_rounded,
                                          size: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      onTap: null,
                                    ),
                                    const SizedBox(width: 10),
                                    _socialCircle(
                                      icon: Image.asset(
                                        'assets/icons/github.png',
                                        width: 16,
                                        height: 16,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.code_rounded,
                                          size: 15,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      onTap: loading
                                          ? null
                                          : () => _socialLogin("GitHub"),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 34),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 32,
                                        child: ElevatedButton(
                                          onPressed: () => context.go('/'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isDark
                                                ? Colors.white54
                                                : Colors.grey.shade300,
                                            foregroundColor: Colors.black87,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                          child: Text(
                                            "BACK",
                                            style: GoogleFonts.poppins(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: SizedBox(
                                        height: 32,
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              context.push('/forgot-password'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isDark
                                                ? Colors.white
                                                : const Color(0xFF1A1A1A),
                                            side: BorderSide(
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black45,
                                              width: 1.1,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                          child: Text(
                                            "FORGOT PASSWORD",
                                            style: GoogleFonts.poppins(
                                              fontSize: 10.2,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_loginErrorMessage != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFC10D00),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                              ),
                              child: Text(
                                _loginErrorMessage!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
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
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.65)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.black12,
                  width: 0.8,
                ),
              ),
              child: Text(
                kDisplayVersion,
                style: GoogleFonts.poppins(
                  color: subtitleColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required TextInputAction action,
    required Color fillColor,
    required Color textColor,
    required Color hintColor,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    return SizedBox(
      width: _fieldWidth,
      height: _inputHeight,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        textInputAction: action,
        onSubmitted: onSubmitted,
        style: GoogleFonts.poppins(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            color: hintColor,
            fontSize: 8.5,
            fontWeight: FontWeight.w500,
          ),
          suffixIcon: suffix,
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _socialCircle({required Widget icon, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 31,
        height: 31,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }
}
