import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield2.dart';
import '../../providers/theme_provider.dart';
import 'verification_screen.dart';
import 'login_screen.dart';

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
    };

    final result = await AuthService.register(data);
    setState(() => loading = false);

    final status = result['status'];
    final body = result['body'];

    if (status != 201) {
      final errorMessage =
          body["errors"]?.join("\n") ?? body["error"] ?? "Registration failed.";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VerificationScreen(
          email: emailController.text.trim(),
        ),
      ),
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

          // Logos
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    "assets/images/logo2.png",
                    width: 300,
                    height: 120,
                  ),
                  Image.asset(
                    "assets/images/logo.png",
                    width: 300,
                    height: 120,
                  ),
                ],
              ),
            ),
          ),

          // Main Content
          Center(
            child: SingleChildScrollView(
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
                          const Text(
                            "GET STARTED",
                            style: TextStyle(
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
                          const Text(
                            "Register Account",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Email
                          CustomTextField(
                            label: "Email",
                            controller: emailController,
                            inputType: TextInputType.emailAddress,
                            textColor: const Color.fromARGB(255, 189, 4, 4),
                            backgroundColor: Colors.transparent,
                          ),
                          const SizedBox(height: 12),

                          // Password
                          CustomTextField(
                            label: "Password",
                            controller: passwordController,
                            inputType: TextInputType.visiblePassword,
                            obscureText: _obscurePassword,
                            textColor: const Color.fromARGB(255, 199, 12, 12),
                            backgroundColor: Colors.transparent,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: const Color.fromARGB(255, 199, 12, 12),
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
                                    style:
                                        TextStyle(color: passwordStrengthColor),
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
                              const Text(
                                "Already have an account? ",
                                style: TextStyle(color: Colors.white70),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Login",
                                  style: TextStyle(color: Colors.redAccent),
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

          if (loading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }
}
