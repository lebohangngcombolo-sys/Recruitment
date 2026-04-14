import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_textfield.dart';
import '../../providers/theme_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
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
    emailController.dispose();
    super.dispose();
  }

  void submit() async {
    if (emailController.text.trim().isEmpty) return;

    setState(() => loading = true);
    final response =
        await AuthService.forgotPassword(emailController.text.trim());
    setState(() => loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response['message'] ?? "Check your email")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final onBg = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final onBgMuted = isDark ? Colors.white70 : const Color(0xFF424242);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(themeProvider.backgroundImage),
                fit: BoxFit.cover,
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

          // Top bar: back arrow + logo only
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: onBg, size: 28),
                    onPressed: () => Navigator.pop(context),
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

          // ---------- Centered Content ----------
          Center(
            child: SingleChildScrollView(
              child: MouseRegion(
                onEnter: kIsWeb ? (_) => _animationController.forward() : null,
                onExit: kIsWeb ? (_) => _animationController.reverse() : null,
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
                        Icon(
                          Icons.lock_reset,
                          size: 40,
                          color: onBg,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "FORGOT PASSWORD",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: onBg,
                            fontFamily: 'Poppins',
                            shadows: isDark
                                ? [
                                    const Shadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(2, 2))
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Enter your email to receive reset instructions",
                          style: TextStyle(
                            fontSize: 16,
                            color: onBgMuted,
                            fontFamily: 'Poppins',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        CustomTextField(
                          label: "Email",
                          controller: emailController,
                          inputType: TextInputType.emailAddress,
                          backgroundColor: Colors.white,
                          textColor: Colors.black,
                          borderColor: Colors.grey.shade300,
                          labelColor: onBg,
                          borderRadius: 15,
                          borderWidth: 1,
                          focusedBorderWidth: 1.5,
                        ),
                        const SizedBox(height: 24),
                        // Medium Rounded Button
                        SizedBox(
                          width: 200,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: loading ? null : submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC10D00),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(22), // Rounded
                              ),
                              elevation: 5,
                            ),
                            child: loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text(
                                    "SUBMIT",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Theme Toggle
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(
                              themeProvider.isDarkMode
                                  ? Icons.light_mode
                                  : Icons.dark_mode,
                              color: onBg,
                              size: 20,
                            ),
                            onPressed: () => themeProvider.toggleTheme(),
                          ),
                        ),
                        const SizedBox(height: 16),
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
              child: Center(
                child: CircularProgressIndicator(
                  color: isDark ? Colors.white : const Color(0xFFC10D00),
                  strokeWidth: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
