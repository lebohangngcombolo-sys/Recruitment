import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  static const Color accentRed = Color(0xFFC10D00);

  Widget _buildNavItem(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: color ?? Colors.white70,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }

  List<Widget> _buildSideBySideLeftContent() {
    return [
      Center(
        child: Text(
          "WHO WE ARE",
          style: GoogleFonts.poppins(
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildRightContent() {
    return [
      Text(
        "With our name constructed from two building blocks: The Venda word \"Khono\" that means key, and the word \"technology\", we believe Khonology holds the key to unlocking Africa's value by leveraging digitisation & digitalisation as the key enablers to empowering Africa.",
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 16,
          height: 1.6,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        "You joining us helps us contribute to the Vision on empowering Africa's people and communities through technology.",
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 16,
          height: 1.6,
        ),
      ),
    ];
  }

  Widget _buildValuesSection(bool useSideBySide) {
    final baseStyle = GoogleFonts.poppins(
      color: Colors.white,
      fontSize: 20,
      height: 1.65,
    );
    final boldStyle = GoogleFonts.poppins(
      color: Colors.white,
      fontSize: 20,
      height: 1.65,
      fontWeight: FontWeight.bold,
    );
    final leftContent = RichText(
      textAlign: TextAlign.left,
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: 'Attitude, aptitude', style: boldStyle),
          const TextSpan(text: ' and having the '),
          TextSpan(text: 'desire to succeed', style: boldStyle),
          const TextSpan(
              text:
                  ' are common traits that all our people are connected by. Our '),
          TextSpan(text: 'values charter', style: boldStyle),
          const TextSpan(text: ' is core to who we are.'),
        ],
      ),
    );
    final cultureParagraph = Text(
      "Knowledge, collaboration and transformation are the 3 key pillars that encompass our culture. Our desire to positively use our knowledge, collaborate with great talent, empowers us to create value and transform Africa.",
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 18,
        height: 1.65,
      ),
    );
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: useSideBySide
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        leftContent,
                        const SizedBox(height: 24),
                        cultureParagraph,
                      ],
                    ),
                  ),
                  Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    color: Colors.white24,
                  ),
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Center(
                          child: Text(
                            "OUR CULTURE",
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                leftContent,
                const SizedBox(height: 24),
                cultureParagraph,
                const SizedBox(height: 28),
                Center(
                  child: Text(
                    "OUR CULTURE",
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCollaborateSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "COLLABORATE WITH US\nTO TAKE YOU TO THE\nNEXT LEVEL",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 44,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "KHONOLOGY CAREERS",
            style: GoogleFonts.poppins(
              fontSize: 20,
              color: accentRed,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Column(
            children: [
              Text(
                "We want to collaborate with you and take your career to the next level. Join Khonology and be part of the movement that looks to impact Africa's society and economy. Joining us offers an opportunity to lead the change and become empowered in an organisation that stands for empowering Africa's businesses, people and you.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "If you would like to partner with us, click below to see our career opportunities.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => context.push('/register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentRed,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Click to apply',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/dark.png',
              fit: BoxFit.cover,
            ),
          ),
          Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/'),
                      child: Image.asset(
                        'assets/icons/khono.png',
                        height: 40,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.go('/'),
                      child: _buildNavItem('Home', color: Colors.white),
                    ),
                    _buildNavItem('About Us', color: Colors.white),
                    GestureDetector(
                      onTap: () => context.push('/contact'),
                      child: _buildNavItem('Contact', color: Colors.white),
                    ),
                    ElevatedButton(
                      onPressed: () => context.go('/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentRed,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.25),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Login',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final useSideBySide = constraints.maxWidth >= 700;
                    final padding = const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 32);
                    final borderedSection = Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white24,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(32),
                      child: useSideBySide
                          ? IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.max,
                                      children: _buildSideBySideLeftContent(),
                                    ),
                                  ),
                                  Container(
                                    width: 2,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    color: Colors.white24,
                                  ),
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: _buildRightContent(),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: _buildSideBySideLeftContent()
                                ..add(const SizedBox(height: 20))
                                ..addAll(_buildRightContent()),
                            ),
                    );
                    final valuesSection = _buildValuesSection(useSideBySide);
                    return SingleChildScrollView(
                      padding: padding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Text(
                              "KHONOLOGY'S VISION IS TO\nDIGITISE AFRICA",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 36,
                                color: accentRed,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          borderedSection,
                          const SizedBox(height: 32),
                          valuesSection,
                          _buildCollaborateSection(context),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
