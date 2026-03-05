import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  static const Color primaryColor = Color(0xFF991A1A);
  static const Color strokeColor = Color(0xFFC10D00);

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

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

  Widget _socialIcon(String assetPath, String url) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () async {
          final Uri uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              assetPath,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.link,
                size: 24,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitForm() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final message = _messageController.text.trim();
    if (name.isEmpty || email.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill in all fields.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: primaryColor,
        ),
      );
      return;
    }
    // Optional: open mailto so user can send from their client
    final mailto = Uri(
      scheme: 'mailto',
      path: 'support@khono.co.za',
      query: _encodeQueryParameters({
        'subject': 'Contact from $name',
        'body': 'From: $name ($email)\n\n$message',
      }),
    );
    launchUrl(mailto);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Opening your email client. We\'ll get back to you soon.',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
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
                    const Spacer(),
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
                child: SingleChildScrollView(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 900),
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact Us',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Reach out for support, partnerships, or feedback.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Contact info row
                          Row(
                            children: [
                              const Icon(Icons.email, color: primaryColor),
                              const SizedBox(width: 10),
                              Text(
                                'support@khono.co.za',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.phone, color: primaryColor),
                              const SizedBox(width: 10),
                              Text(
                                '+27 00 000 0000',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          // Contact form
                          Text(
                            'Send us a message',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Your name',
                              labelStyle: GoogleFonts.poppins(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.white24),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.white24),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: primaryColor, width: 1.5),
                              ),
                            ),
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Your email',
                              labelStyle: GoogleFonts.poppins(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.white24),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.white24),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: primaryColor, width: 1.5),
                              ),
                            ),
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _messageController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: 'Message',
                              labelStyle: GoogleFonts.poppins(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.white24),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.white24),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: primaryColor, width: 1.5),
                              ),
                            ),
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Send message',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          // Social icons
                          Text(
                            'Follow us',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _socialIcon(
                                'assets/icons/Instagram1.png',
                                'https://www.instagram.com/yourprofile',
                              ),
                              _socialIcon(
                                'assets/icons/x1.png',
                                'https://x.com/yourprofile',
                              ),
                              _socialIcon(
                                'assets/icons/LinkedIn1.png',
                                'https://www.linkedin.com/in/yourprofile',
                              ),
                              _socialIcon(
                                'assets/icons/facebook1.png',
                                'https://www.facebook.com/yourprofile',
                              ),
                              _socialIcon(
                                'assets/icons/YouTube1.png',
                                'https://www.youtube.com/yourchannel',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
