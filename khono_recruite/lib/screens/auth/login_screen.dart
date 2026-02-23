import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../widgets/custom_textfield.dart';
import '../../providers/theme_provider.dart';
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
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool loading = false;
  bool _obscurePassword = true;

  // 🆕 MFA state variables - PROPERLY TYPED
  String? _mfaSessionToken;
  String? _userId; // 🆕 Ensure this is String, not int
  bool _showMfaForm = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.95,
      upperBound: 1.0,
    );
    _scaleAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _animationController.value = 1.0;
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // 🆕 UPDATED LOGIN WITH MFA SUPPORT - Navigation approach
  void _login() async {
    setState(() => loading = true);
    try {
      final result = await AuthService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (result['ok'] == true) {
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
          // Normal login without MFA — prefetch current user so dashboard shows name from first paint
          try {
            await AuthService.getCurrentUser(token: result['access_token']);
          } catch (_) {}
          _navigateToDashboard(
            token: result['access_token'],
            role: result['role'],
            dashboard: result['dashboard'],
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?.toString() ?? "Login failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login error: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
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
        try {
          await AuthService.getCurrentUser(token: result['access_token']);
        } catch (_) {}
        _navigateToDashboard(
          token: result['access_token'] as String,
          role: (result['user']?['role'] ?? result['role']) as String? ?? 'candidate',
          dashboard: result['dashboard'] as String? ?? '/candidate-dashboard',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message']?.toString() ?? "MFA verification failed")),
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
          try {
            await AuthService.getCurrentUser(token: loginResult['access_token']);
          } catch (_) {}
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final size = MediaQuery.of(context).size;

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

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/dark.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Centered Content - scroll fills screen so scroll works from anywhere
          Center(
            child: SizedBox.expand(
              child: ScrollConfiguration(
                behavior: _NoScrollbarScrollBehavior(),
                child: SingleChildScrollView(
                  child: Center(
                    child: MouseRegion(
                      onEnter: (_) =>
                          kIsWeb ? _animationController.forward() : null,
                      onExit: (_) =>
                          kIsWeb ? _animationController.reverse() : null,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: size.width > 800 ? 400 : size.width * 0.9,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 16),
                              Text(
                                "WELCOME BACK",
                                style: GoogleFonts.poppins(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(2, 2))
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                "Login",
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 24),
                              CustomTextField(
                                label: "Email",
                                controller: emailController,
                                inputType: TextInputType.emailAddress,
                                backgroundColor: Colors.white,
                                textColor: Colors.black,
                                borderColor: Colors.grey.shade300,
                                labelColor: Colors.white,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 12),
                              CustomTextField(
                                label: "Password",
                                controller: passwordController,
                                obscureText: _obscurePassword,
                                backgroundColor: Colors.white,
                                textColor: Colors.black,
                                borderColor: Colors.grey.shade300,
                                labelColor: Colors.white,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _login(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey.shade600,
                                  ),
                                  onPressed: () {
                                    setState(() =>
                                        _obscurePassword = !_obscurePassword);
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () => context.push('/forgot-password'),
                                  child: Text(
                                    "Forgot Password?",
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Updated Login Button - Medium size and C10D00 color
                              SizedBox(
                                width: 200, // Medium width
                                height: 44, // Medium height
                                child: ElevatedButton(
                                  onPressed: loading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(
                                        0xFFC10D00), // C10D00 background
                                    foregroundColor: Colors.white, // White text
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    elevation: 5,
                                  ),
                                  child: loading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : Text(
                                          "LOGIN",
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // 🆕 Enterprise SSO Button - White with C10D00 text and icon
                              SizedBox(
                                width: 200, // Same medium width as login button
                                height:
                                    44, // Same medium height as login button
                                child: ElevatedButton(
                                  onPressed: loading
                                      ? null
                                      : () => context.push('/sso-enterprise'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.white, // White background
                                    foregroundColor:
                                        const Color(0xFFC10D00), // C10D00 text
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    elevation: 5,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.business,
                                        size: 18,
                                        color: const Color(
                                            0xFFC10D00), // C10D00 icon
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Enterprise SSO",
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                      child: Divider(
                                          color: Colors.white
                                              .withValues(alpha: 0.4))),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Text(
                                      "Or login with",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                      child: Divider(
                                          color: Colors.white
                                              .withValues(alpha: 0.4))),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const FaIcon(FontAwesomeIcons.google,
                                        color: Colors.white, size: 32),
                                    onPressed: loading
                                        ? null
                                        : () => _socialLogin("Google"),
                                  ),
                                  const SizedBox(width: 24),
                                  IconButton(
                                    icon: const FaIcon(FontAwesomeIcons.github,
                                        color: Colors.white, size: 32),
                                    onPressed: loading
                                        ? null
                                        : () => _socialLogin("GitHub"),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: loading
                                        ? null
                                        : () => context.go('/register'),
                                    child: Text(
                                      "Register",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              IconButton(
                                icon: Icon(
                                    themeProvider.isDarkMode
                                        ? Icons.light_mode
                                        : Icons.dark_mode,
                                    color: Colors.white),
                                onPressed: loading
                                    ? null
                                    : () => themeProvider.toggleTheme(),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top bar on top so back arrow and logo receive taps
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 28),
                      onPressed: () => context.go('/'),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => context.go('/'),
                      child: Image.asset(
                        "assets/icons/khono.png",
                        height: 40,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (loading && !_showMfaForm)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}
