import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../utils/app_version.dart';

class SplashLandingPage extends StatefulWidget {
  const SplashLandingPage({super.key});

  @override
  State<SplashLandingPage> createState() => _SplashLandingPageState();
}

class _SplashLandingPageState extends State<SplashLandingPage>
    with TickerProviderStateMixin {
  static const double _logoWidth = 609.02;
  static const double _logoHeight = 114.34;
  static const double _titleFontSize = 24.59;
  static const double _subtitleFontSize = 17.21;
  static const double _buttonWidth = 201.3;
  static const double _buttonHeight = 32.58;
  static const double _buttonRadius = 20.54;
  static const double _buttonGap = 10.27;
  static const double _discSize = 127.85;

  late AnimationController _emergenceController;
  late AnimationController _breathingController;
  late AnimationController _gearController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _breathingAnimation;
  late Animation<double> _gearRotationAnimation;
  bool _showActions = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimationSequence();
  }

  void _setupAnimations() {
    _emergenceController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _emergenceController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _emergenceController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );

    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _breathingAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOut,
      ),
    );

    _gearController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _gearRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(
      CurvedAnimation(
        parent: _gearController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _startAnimationSequence() async {
    await _emergenceController.forward();
    if (!mounted) return;

    _breathingController.repeat(reverse: true);

    // Exactly 3 full turns before revealing CTA buttons.
    for (var i = 0; i < 3; i++) {
      _gearController.reset();
      await _gearController.forward();
      if (!mounted) return;
    }

    _breathingController.stop();
    if (!mounted) return;
    setState(() {
      _showActions = true;
    });
  }

  @override
  void dispose() {
    _emergenceController.dispose();
    _breathingController.dispose();
    _gearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtitleColor = isDark
        ? Colors.white.withOpacity(0.92)
        : const Color(0xFF424242).withOpacity(0.95);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF14131E) : const Color(0xFFF5F5F7),
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
            child: Image.asset(
              themeProvider.backgroundImage,
              fit: BoxFit.cover,
              alignment: const Alignment(0.12, 0.0),
            ),
          ),
          Positioned.fill(
            child: Container(
              color: isDark
                  ? Colors.black.withOpacity(0.32)
                  : Colors.black.withOpacity(0.06),
            ),
          ),
          AnimatedBuilder(
            animation: Listenable.merge([
              _scaleAnimation,
              _fadeAnimation,
              _breathingAnimation,
              _gearRotationAnimation,
            ]),
            builder: (context, child) {
              final textBlockWidth = (MediaQuery.of(context).size.width - 64)
                  .clamp(320.0, 1172.74)
                  .toDouble();

              final breathingScale = _breathingController.isAnimating
                  ? _breathingAnimation.value
                  : 1.0;

              final rotation = _gearController.isAnimating
                  ? _gearRotationAnimation.value
                  : 0.0;

              return Opacity(
                opacity: _fadeAnimation.value,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                        SizedBox(
                          width: textBlockWidth,
                          child: Text(
                            'Automated Recruitment Workflow',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              color: titleColor,
                              fontSize: _titleFontSize,
                              fontWeight: FontWeight.w600,
                              height: 24.6 / _titleFontSize,
                              letterSpacing: 0.24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: textBlockWidth,
                          child: Text(
                            'Accelerate hiring with structured, criteria-driven talent acquisition.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              color: subtitleColor,
                              fontSize: _subtitleFontSize,
                              fontWeight: FontWeight.w600,
                              height: 24.6 / _subtitleFontSize,
                              letterSpacing: 0.17,
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _showActions
                              ? Row(
                                  key: const ValueKey('cta-buttons'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: _buttonWidth,
                                      height: _buttonHeight,
                                      child: ElevatedButton(
                                        onPressed: () => context.go('/login'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFC10D00),
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              _buttonRadius,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'GET STARTED',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: _buttonGap),
                                    SizedBox(
                                      width: _buttonWidth,
                                      height: _buttonHeight,
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            context.go('/register'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: isDark
                                              ? Colors.white
                                              : const Color(0xFF1A1A1A),
                                          side: BorderSide(
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black45,
                                            width: 1.2,
                                          ),
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              _buttonRadius,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'REGISTER',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                        SizedBox(height: _showActions ? 76 : 40),
                        Transform.scale(
                          scale: _scaleAnimation.value * breathingScale,
                          child: Transform.rotate(
                            angle: rotation,
                            child: Image.asset(
                              isDark
                                  ? 'assets/images/discs.png'
                                  : 'assets/images/logo.png',
                              width: _discSize,
                              height: _discSize,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.65)
                    : Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
              ),
              child: Text(
                kDisplayVersion,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
