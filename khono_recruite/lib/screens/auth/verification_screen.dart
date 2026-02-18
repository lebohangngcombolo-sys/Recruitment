import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/six_digit_code_field.dart';
import '../../providers/theme_provider.dart';

class VerificationScreen extends StatefulWidget {
  final String email;
  const VerificationScreen({super.key, required this.email});

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with SingleTickerProviderStateMixin {
  String verificationCode = '';
  bool loading = false;

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
    super.dispose();
  }

  void _onCodeChanged(String code) {
    setState(() {
      verificationCode = code;
    });
  }

  void _onCodeCompleted(String code) {
    setState(() {
      verificationCode = code;
    });
    // Optionally auto-submit when code is complete
    // verify();
  }

  void verify() async {
    if (verificationCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the complete 6-digit code")),
      );
      return;
    }

    setState(() => loading = true);

    final response = await AuthService.verifyEmail({
      "email": widget.email,
      "code": verificationCode.trim(),
    });

    setState(() => loading = false);

    if (response.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['error'])),
      );
    } else {
      if (!context.mounted) return;
      final token = response['access_token'] as String? ?? '';
      context.go('/enrollment?token=${Uri.encodeComponent(token)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ---------- Background Image ----------
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/dark.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Top bar: back arrow + logo only
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 28),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/register'),
                  ),
                  const SizedBox(width: 12),
                  Image.asset(
                    "assets/icons/khono.png",
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),

          // ---------- Centered Content - Glass container removed ----------
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: MouseRegion(
                onEnter: (_) => kIsWeb ? _animationController.forward() : null,
                onExit: (_) => kIsWeb ? _animationController.reverse() : null,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: size.width > 800 ? 420 : size.width * 0.85,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 16),
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 36,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Email Verification",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            "Code sent to ${widget.email}",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 6-Digit Code Input using custom widget
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Text(
                                  "Enter verification code",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SixDigitCodeField(
                                onCodeChanged: _onCodeChanged,
                                onCodeCompleted: _onCodeCompleted,
                                onSubmit: verify,
                                autoFocus: true,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Verify Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: CustomButton(
                            text: "Verify & Continue",
                            onPressed: verify,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Resend code option
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Didn't receive code? ",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text("Resend code functionality")),
                                  );
                                },
                                child: const Text(
                                  "Resend",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Theme toggle
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(
                              themeProvider.isDarkMode
                                  ? Icons.light_mode
                                  : Icons.dark_mode,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () => themeProvider.toggleTheme(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (loading)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
