import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class FindTalentPage extends StatelessWidget {
  const FindTalentPage({super.key});

  static const Color primaryColor = Color(0xFF991A1A);
  static const Color strokeColor = Color(0xFFC10D00);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1A1A1A),
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
              // Nav bar (same as landing / candidate dashboard)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                      child: Image.asset(
                        'assets/icons/khono.png',
                        height: 40,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Spacer(),
                    GestureDetector(
                      onTap: () => context.go('/'),
                      child: _buildNavItem('Home', color: Colors.white),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/about-us'),
                      child: _buildNavItem('About Us', color: Colors.white),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/contact'),
                      child: _buildNavItem('Contact', color: Colors.white),
                    ),
                    ElevatedButton(
                      onPressed: () => context.go('/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: strokeColor,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: Colors.black.withOpacity(0.25),
                        padding: EdgeInsets.symmetric(
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
                    SizedBox(width: 16),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hero heading and subheading (scrolls with content)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Welcome to KhonoTalent",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 48,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "CONNECT | MATCH | SUCCEED",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: strokeColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(32),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: GridView.count(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  children: [
                                    Image.asset('assets/images/collaggge.jpg',
                                        fit: BoxFit.cover),
                                    Image.asset('assets/images/Mosa.jpg',
                                        fit: BoxFit.cover),
                                    Image.asset('assets/images/office.jpg',
                                        fit: BoxFit.cover),
                                    Image.asset('assets/images/thato.png',
                                        fit: BoxFit.cover),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 24),
                            Expanded(
                              flex: 1,
                                child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Investing in Africa's talent is what we believe in",
                                        style: GoogleFonts.poppins(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Khonology Academy is a technology-focused FinTech Incubator. Our portfolio companies make us who we are, and we know that their accomplishments measure our success. When you join us, you\'ll get immediate access to mentorship from strategic industry experts and skills applicable across any industry.',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'The Academy offers a 12ΓÇæmonth internship where learning happens on the job. '
                                        'Interns build software development skills and a strong base in finance, data, '
                                        'economics, technology and soft skills by delivering projects that use the same '
                                        'tools as South Africa\'s leading firms. We do this because we believe sustainable '
                                        'growth depends on a support ecosystem that can sustain itselfΓÇöand that starts '
                                        'with people who are ready to lead it.',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 24),
                                      ElevatedButton(
                                        onPressed: () => context.push('/intern-stories'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: strokeColor,
                                          foregroundColor: Colors.white,
                                          elevation: 2,
                                          shadowColor:
                                              Colors.black.withOpacity(0.25),
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          'Read more',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
            ],
          ),
        ],
      ),
    );
  }
}
