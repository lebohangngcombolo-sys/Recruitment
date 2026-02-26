import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

class JobDetailsPage extends StatefulWidget {
  final Map<String, dynamic> job;
  final Map<String, dynamic>? draftData;

  const JobDetailsPage({
    super.key,
    required this.job,
    this.draftData,
  });

  @override
  State<JobDetailsPage> createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends State<JobDetailsPage> {
  int? applicationId;
  bool submitting = false;
  bool loadingProfile = true;

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController portfolioController = TextEditingController();
  final TextEditingController coverLetterController = TextEditingController();

  // Enrollment-style Theme Colors
  final Color _cardDark = Colors.black.withOpacity(0.55); // Card background
  final Color _accentRed = const Color(0xFFC10D00); // Main red
  final Color _textPrimary = Colors.white; // Main text
  final Color _textSecondary = Colors.grey.shade300; // Secondary text
  @override
  void initState() {
    super.initState();
    _loadCandidateProfile();

    if (widget.draftData != null) {
      final draft = widget.draftData!;
      fullNameController.text = draft["full_name"] ?? "";
      phoneController.text = draft["phone"] ?? "";
      portfolioController.text = draft["portfolio"] ?? "";
      coverLetterController.text = draft["cover_letter"] ?? "";
      applicationId = draft["application_id"];
    }
  }

  Future<void> _loadCandidateProfile() async {
    try {
      debugPrint("Loading candidate profile...");

      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        debugPrint("No token found");
        setState(() => loadingProfile = false);
        return;
      }

      debugPrint("Token found, fetching user data...");
      Map<String, dynamic> profileData = {};

      try {
        final response = await AuthService.getCurrentUser(token: token);
        debugPrint("Full response from getCurrentUser: $response");

        // Never treat auth-error response as profile data
        if (response['unauthorized'] == true ||
            (response['error'] != null && !response.containsKey('user'))) {
          debugPrint(
              "Token expired or unauthorized; skipping profile population");
          profileData = {};
        } else if (response.containsKey('user')) {
          final userData = response['user'];

          // If there's nested candidate_profile data, merge it with user data
          if (response.containsKey('candidate_profile')) {
            profileData = {...userData, ...response['candidate_profile']};
            debugPrint("Merged user + candidate profile data");
          } else {
            // Use user data directly (might contain candidate fields if backend uses flat structure)
            profileData = userData;
            debugPrint("Using user data only");
          }
          debugPrint("Final profile data for population: $profileData");
        } else {
          // Fallback only when response looks like success (has useful keys, not an error)
          if (response['msg'] == null && response['error'] == null) {
            profileData = Map<String, dynamic>.from(response);
            debugPrint("Using response data directly");
          } else {
            profileData = {};
          }
          debugPrint("Final profile data for population: $profileData");
        }
      } catch (e) {
        debugPrint("Error from getCurrentUser: $e");
      }

      setState(() {
        // Only populate if fields are empty (don't override draft data)
        if (fullNameController.text.isEmpty) {
          final name = _extractName(profileData);
          if (name.isNotEmpty) {
            fullNameController.text = name;
            debugPrint("Auto-populated name: $name");
          } else {
            debugPrint("No name found in profile");
          }
        }

        if (phoneController.text.isEmpty) {
          final phone = _extractPhone(profileData);
          if (phone.isNotEmpty) {
            phoneController.text = phone;
            debugPrint("Auto-populated phone: $phone");
          } else {
            debugPrint("No phone found in profile");
          }
        }

        if (portfolioController.text.isEmpty) {
          final portfolio = _extractPortfolio(profileData);
          if (portfolio.isNotEmpty) {
            portfolioController.text = portfolio;
            debugPrint("Auto-populated portfolio: $portfolio");
          } else {
            debugPrint("No portfolio found in profile");
          }
        }

        loadingProfile = false;
      });
    } catch (e) {
      debugPrint("Error loading candidate profile: $e");
      setState(() {
        loadingProfile = false;
      });
    }
  }

  String _extractName(Map<String, dynamic> profile) {
    // Try various name fields from both user and candidate data
    return profile['full_name'] ??
        profile['name'] ??
        '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim() ??
        profile['email']?.split('@').first ??
        '';
  }

  String _extractPhone(Map<String, dynamic> profile) {
    // Try various phone field names
    return profile['phone']?.toString() ??
        profile['phone_number']?.toString() ??
        profile['mobile']?.toString() ??
        '';
  }

  String _extractPortfolio(Map<String, dynamic> profile) {
    // Try various portfolio/link fields
    return profile['linkedin'] ??
        profile['portfolio'] ??
        profile['github'] ??
        profile['website'] ??
        profile['cv_url'] ??
        '';
  }

  Future<void> loadDraft() async {
    if (applicationId == null) return;

    final token = await AuthService.getAccessToken();
    try {
      final res = await http.get(
        Uri.parse(
            "http://127.0.0.1:5000/api/candidate/applications/$applicationId/draft"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          fullNameController.text =
              data["full_name"] ?? fullNameController.text;
          phoneController.text = data["phone"] ?? phoneController.text;
          portfolioController.text =
              data["portfolio"] ?? portfolioController.text;
          coverLetterController.text =
              data["cover_letter"] ?? coverLetterController.text;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error loading draft: $e")));
    }
  }

  Future<void> saveDraftAndExit() async {
    if (applicationId == null) return;

    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to save your draft.")),
      );
      return;
    }
    try {
      final payload = {
        "draft_data": {
          "job_details": {
            "application_id": applicationId,
            "full_name": fullNameController.text,
            "phone": phoneController.text,
            "portfolio": portfolioController.text,
            "cover_letter": coverLetterController.text,
          }
        },
        "last_saved_screen": "job_details"
      };

      final res = await http.post(
        Uri.parse(
            "http://127.0.0.1:5000/api/candidate/applications/$applicationId/draft"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode(payload),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Draft saved successfully")),
        );

        Navigator.pop(context, true); // send "refresh" to dashboard
      } else {
        final data = _safeJsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data is Map
                  ? (data["error"] ?? "Failed to save draft")
                  : "Failed to save draft")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> applyJob() async {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      _showSignInToApplyDialog();
      return;
    }
    if (!mounted) return;
    setState(() => submitting = true);

    try {
      final res = await http.post(
        Uri.parse(
            "http://127.0.0.1:5000/api/candidate/apply/${widget.job["id"]}"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({
          "full_name": fullNameController.text,
          "phone": phoneController.text,
          "portfolio": portfolioController.text,
          "cover_letter": coverLetterController.text,
        }),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = _safeJsonDecode(res.body);
        if (data is! Map) {
          throw Exception("Invalid apply response");
        }
        if (!mounted) return;
        await AuthService.clearPendingApplyJob();
        setState(() {
          applicationId = data["application_id"];
        });
        final message = data["message"]?.toString() ?? "Applied successfully!";
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } else if (res.statusCode == 401) {
        await AuthService.clearAuthState();
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Session expired. Please sign in to apply.")),
        );
      } else {
        final data = _safeJsonDecode(res.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data is Map
                  ? (data["error"] ?? "Apply failed")
                  : "Apply failed")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (!mounted) return;
      setState(() => submitting = false);
    }
  }

  void _showSignInToApplyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign in to continue',
          style: GoogleFonts.poppins(
            color: _textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        content: Text(
          'Please log in or create an account to continue with your application.',
          style: GoogleFonts.poppins(
            color: _textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService.setPendingApplyJob(widget.job);
              if (!context.mounted) return;
              context.push('/register');
            },
            child: Text(
              'Create account',
              style: GoogleFonts.poppins(
                color: _accentRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService.setPendingApplyJob(widget.job);
              if (!context.mounted) return;
              context.push('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Log in',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  dynamic _safeJsonDecode(String body) {
    try {
      return json.decode(body);
    } catch (_) {
      return null;
    }
  }

  String _formatSalary(Map<String, dynamic> job) {
    final currency = (job['salary_currency']?.toString().isNotEmpty ?? false)
        ? job['salary_currency'].toString()
        : 'ZAR';
    final symbol = _currencySymbol(currency);
    final min = (job['salary_min'] is num) ? job['salary_min'] as num : null;
    final max = (job['salary_max'] is num) ? job['salary_max'] as num : null;
    final period = _formatSalaryPeriod(job['salary_period']);

    if (min == null && max == null) {
      return "Salary not specified";
    }

    final minText = min != null ? _formatNumber(min) : null;
    final maxText = max != null ? _formatNumber(max) : null;

    if (minText != null && maxText != null) {
      return "$symbol$minText - $symbol$maxText$period";
    }
    if (minText != null) {
      return "$symbol$minText$period";
    }
    return "$symbol$maxText$period";
  }

  String _formatNumber(num value) {
    final rounded = value.toDouble();
    return rounded % 1 == 0
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(2);
  }

  String _currencySymbol(String currency) {
    final code = currency.toUpperCase();
    if (code == 'ZAR') return 'R';
    if (code == 'USD') return '\$';
    if (code == 'EUR') return 'Γé¼';
    if (code == 'GBP') return '┬ú';
    return '$code ';
  }

  String _formatSalaryPeriod(dynamic period) {
    final value = period?.toString().toLowerCase();
    if (value == 'yearly') {
      return ' per year';
    }
    if (value == 'monthly') {
      return ' per month';
    }
    return '';
  }

  String _formatEmploymentType(dynamic type) {
    final value = type?.toString().toLowerCase();
    if (value == 'full_time') return 'Full Time';
    if (value == 'part_time') return 'Part Time';
    if (value == 'contract') return 'Contract';
    if (value == 'internship') return 'Internship';
    return type?.toString() ?? 'Full Time';
  }

  @override
  void dispose() {
    fullNameController.dispose();
    phoneController.dispose();
    portfolioController.dispose();
    coverLetterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsibilities = widget.job["responsibilities"];
    final List<String> responsibilitiesList = (responsibilities is List)
        ? List<String>.from(responsibilities)
        : ["Responsibility 1", "Responsibility 2", "Responsibility 3"];

    final qualifications = widget.job["qualifications"];
    final List<String> qualificationsList = (qualifications is List)
        ? List<String>.from(qualifications)
        : ["Qualification 1", "Qualification 2", "Qualification 3"];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Image - UNCHANGED
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/dark.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            color: Colors.black.withOpacity(0.4),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Banner - UNCHANGED
                Stack(
                  children: [
                    Image.asset(
                      widget.job["banner"] ?? "assets/images/team1.jpg",
                      width: double.infinity,
                      height: 400,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      height: 400,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 40,
                      left: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: _accentRed.withOpacity(0.6), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 40,
                      left: 24,
                      right: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.job["title"] ?? "",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${widget.job["company"] ?? ""} ΓÇó ${widget.job["location"] ?? ""}",
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main Column
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildEnhancedCard(
                                  Icons.description_outlined,
                                  "Job Description",
                                  _accentRed,
                                  [
                                    Text(
                                      widget.job["description"] ??
                                          "No description available.",
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: _textPrimary,
                                        height: 1.6,
                                      ),
                                    )
                                  ],
                                ),
                                _buildEnhancedCard(
                                  Icons.checklist_outlined,
                                  "Responsibilities",
                                  _accentRed,
                                  responsibilitiesList
                                      .map((r) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(Icons.circle,
                                                    size: 8, color: _accentRed),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    r,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      color: _textPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                ),
                                _buildEnhancedCard(
                                  Icons.school_outlined,
                                  "Qualifications",
                                  _accentRed,
                                  qualificationsList
                                      .map((q) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(Icons.verified,
                                                    size: 16,
                                                    color: _accentRed),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    q,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      color: _textPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                          // Right Column
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildEnhancedCard(
                                  Icons.assignment_outlined,
                                  "Job Summary",
                                  _accentRed,
                                  [
                                    _buildSummaryRow(
                                        Icons.calendar_today_outlined,
                                        "Published On",
                                        widget.job["published_on"] ??
                                            "01 Jan, 2045"),
                                    _buildSummaryRow(
                                        Icons.people_outlined,
                                        "Vacancy",
                                        widget.job["vacancy"]?.toString() ??
                                            "1"),
                                    _buildSummaryRow(
                                        Icons.schedule_outlined,
                                        "Job Nature",
                                        _formatEmploymentType(
                                            widget.job["employment_type"] ??
                                                widget.job["type"])),
                                    _buildSummaryRow(
                                        Icons.attach_money_outlined,
                                        "Salary",
                                        _formatSalary(widget.job)),
                                    _buildSummaryRow(
                                        Icons.location_on_outlined,
                                        "Location",
                                        widget.job["location"] ?? "New York"),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildEnhancedCard(
                                  Icons.business_outlined,
                                  "Company Details",
                                  _accentRed,
                                  [
                                    Text(
                                      widget.job["company_details"] ??
                                          "No details available.",
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: _textPrimary,
                                        height: 1.6,
                                      ),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: loadingProfile
                                ? Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: CircularProgressIndicator(
                                        color: _accentRed),
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 320,
                                        child: ElevatedButton(
                                          onPressed:
                                              submitting ? null : applyJob,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _accentRed,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 24, vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            elevation: 2,
                                          ),
                                          child: submitting
                                              ? SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.send_outlined,
                                                        size: 20,
                                                        color: Colors.white),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Text(
                                                        "Proceed With Application",
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 16,
                                                          color: Colors.white,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
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
                const SizedBox(height: 40),
                _buildEnhancedFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Helper Widgets ----------------
  Widget _buildEnhancedCard(
      IconData icon, String title, Color color, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: _accentRed.withOpacity(0.6), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: _accentRed, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _accentRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialIcon(String assetPath, String url) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () async {
          final Uri uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            assetPath,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
            color: _textPrimary,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.link, size: 20, color: _textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedFooter() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardDark,
        border: Border(
          top: BorderSide(color: _accentRed.withOpacity(0.6), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/logo3.png',
            width: 200,
            height: 100,
            fit: BoxFit.contain,
            color: _textPrimary,
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _socialIcon('assets/icons/Instagram1.png',
                  'https://www.instagram.com/yourprofile'),
              _socialIcon('assets/icons/x1.png', 'https://x.com/yourprofile'),
              _socialIcon('assets/icons/LinkedIn1.png',
                  'https://www.linkedin.com/in/yourprofile'),
              _socialIcon('assets/icons/facebook1.png',
                  'https://www.facebook.com/yourprofile'),
              _socialIcon('assets/icons/YouTube1.png',
                  'https://www.youtube.com/yourchannel'),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            "┬⌐ 2025 Khonology. All rights reserved.",
            style: GoogleFonts.poppins(
              color: _textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
