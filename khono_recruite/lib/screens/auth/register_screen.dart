import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../../providers/theme_provider.dart';

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

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();

  bool _obscurePassword = true;
  bool loading = false;

  String passwordStrength = '';
  Color passwordStrengthColor = Colors.red;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.95,
      upperBound: 1.0,
    );

    _scaleAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  void checkPasswordStrength(String password) {
    if (password.isEmpty) {
      passwordStrength = '';
      passwordStrengthColor = Colors.red;
    } else if (password.length < 6) {
      passwordStrength = 'Weak';
      passwordStrengthColor = Colors.red;
    } else {
      int strengthPoints = 0;
      if (RegExp(r'[A-Z]').hasMatch(password)) strengthPoints++;
      if (RegExp(r'[a-z]').hasMatch(password)) strengthPoints++;
      if (RegExp(r'[0-9]').hasMatch(password)) strengthPoints++;
      if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password))
        strengthPoints++;

      if (strengthPoints <= 2) {
        passwordStrength = 'Weak';
        passwordStrengthColor = Colors.red;
      } else if (strengthPoints == 3) {
        passwordStrength = 'Medium';
        passwordStrengthColor = Colors.orange;
      } else {
        passwordStrength = 'Strong';
        passwordStrengthColor = Colors.green;
      }
    }
    setState(() {});
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
    final body = result['body'] is Map<String, dynamic> ? result['body'] as Map<String, dynamic> : <String, dynamic>{};

    if (status != 201 && status != 200) {
      final errors = body['errors'];
      final errorMsg = body['error'];
      final errorMessage = errors is List
          ? errors.join('\n')
          : (errorMsg is String ? errorMsg : 'Registration failed.');

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

    // When email is not configured, backend returns access_token and dashboard; log user in and go there.
    final accessToken = body['access_token'] as String?;
    if (accessToken != null && accessToken.isNotEmpty) {
      final refreshToken = body['refresh_token'] as String?;
      await AuthService.saveTokens(accessToken, refreshToken);
      final user = body['user'];
      if (user is Map<String, dynamic>) {
        await AuthService.saveUserInfo(user);
      }
      final dashboardPath = body['dashboard'] as String? ?? '/enrollment';
      if (!context.mounted) return;
      // Routes expect query param 'token' for dashboard deep links
      final safePath = dashboardPath.startsWith('/') ? dashboardPath : '/$dashboardPath';
      context.go('$safePath?token=${Uri.encodeComponent(accessToken)}');
      return;
    }

    // Email verification required: go to verify-email page
    context.go(
      '/verify-email?email=${Uri.encodeComponent(emailController.text.trim())}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final size = MediaQuery.of(context).size;

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

          // Main Content - scroll fills screen so scroll works from anywhere
          Center(
            child: SizedBox.expand(
              child: ScrollConfiguration(
                behavior: _NoScrollbarScrollBehavior(),
                child: SingleChildScrollView(
                  child: Center(
                    child: MouseRegion(
                      onEnter: (_) => kIsWeb ? _animationController.forward() : null,
                      onExit: (_) => kIsWeb ? _animationController.reverse() : null,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: size.width > 800 ? 400 : size.width * 0.9,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 32),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 16),
                          Text(
                            "GET STARTED",
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(2, 2),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Register Account",
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Text fields: same style as login (white background, grey border)
                          CustomTextField(
                            label: "First Name",
                            controller: firstNameController,
                            backgroundColor: Colors.white,
                            textColor: Colors.black,
                            borderColor: Colors.grey.shade300,
                            labelColor: Colors.white,
                            margin: EdgeInsets.zero,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            label: "Last Name",
                            controller: lastNameController,
                            backgroundColor: Colors.white,
                            textColor: Colors.black,
                            borderColor: Colors.grey.shade300,
                            labelColor: Colors.white,
                            margin: EdgeInsets.zero,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            label: "Email",
                            controller: emailController,
                            inputType: TextInputType.emailAddress,
                            backgroundColor: Colors.white,
                            textColor: Colors.black,
                            borderColor: Colors.grey.shade300,
                            labelColor: Colors.white,
                            margin: EdgeInsets.zero,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),

                          // Password
                          CustomTextField(
                            label: "Password",
                            controller: passwordController,
                            inputType: TextInputType.visiblePassword,
                            obscureText: _obscurePassword,
                            backgroundColor: Colors.white,
                            textColor: Colors.black,
                            borderColor: Colors.grey.shade300,
                            labelColor: Colors.white,
                            margin: EdgeInsets.zero,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => register(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            onChanged: checkPasswordStrength,
                          ),

                          // Password strength indicator
                          if (passwordStrength.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 4.0, bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: passwordStrengthColor,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    passwordStrength,
                                    style: GoogleFonts.poppins(
                                        color: passwordStrengthColor,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 20),

                          // Register Button
                          SizedBox(
                            width: 200,
                            height: 44,
                            child: CustomButton(
                              text: "Register",
                              onPressed: loading ? null : register,
                            ),
                          ),

                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account? ",
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.go('/login'),
                                child: Text(
                                  "Login",
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
                              color: Colors.white,
                            ),
                            onPressed: () => themeProvider.toggleTheme(),
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
          ),

          // Top bar on top so back arrow and logo receive taps
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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

          if (loading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }
}
