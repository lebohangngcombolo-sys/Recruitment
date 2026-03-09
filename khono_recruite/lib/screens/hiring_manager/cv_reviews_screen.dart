import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../providers/theme_provider.dart';
import '../../utils/api_endpoints.dart';

class CVReviewsScreen extends StatefulWidget {
  const CVReviewsScreen({super.key});

  @override
  State<CVReviewsScreen> createState() => _CVReviewsScreenState();
}

class _CVReviewsScreenState extends State<CVReviewsScreen> {
  final AdminService admin = AdminService();
  List<Map<String, dynamic>> cvReviews = [];
  bool loading = true;
  String searchQuery = '';
  String selectedGender = 'All';
  String selectedScoreFilter = 'All';
  String selectedAnalysisFilter = 'All';

  @override
  void initState() {
    super.initState();
    fetchCVReviews();
  }

  Future<void> fetchCVReviews() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final List<Map<String, dynamic>> all = [];
      var page = 1;
      while (true) {
        final batch = await admin.listCVReviews(
          page: page,
          perPage: 200,
          search: searchQuery.isNotEmpty ? searchQuery : null,
          scope: 'all',
        );
        all.addAll(batch);
        if (batch.length < 200) break;
        page++;
      }
      if (!mounted) return;
      setState(() {
        cvReviews = List<Map<String, dynamic>>.from(all);
      });
    } catch (e) {
      debugPrint("Error fetching CV data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  void _showCVAnalysis(Map<String, dynamic> review) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final cvAnalysis = review['cv_analysis'];
    if (cvAnalysis == null || cvAnalysis is! Map) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No CV analysis available yet',
            style: GoogleFonts.inter(),
          ),
        ),
      );
      return;
    }

    List<String> asStringList(dynamic value) {
      if (value == null) return <String>[];
      if (value is List) {
        return value
            .where((e) => e != null)
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      final s = value.toString().trim();
      if (s.isEmpty) return <String>[];
      return <String>[s];
    }

    Widget sectionTitle(String text) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      );
    }

    Widget chips(List<String> values) {
      if (values.isEmpty) {
        return Text(
          '—',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
          ),
        );
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values
            .map(
              (v) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(_kBadgeRadius),
                  border: Border.all(
                    color: _kPrimary.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Text(
                  v,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    final status = (cvAnalysis['status'] as String?) ?? 'unknown';
    final matchScore = cvAnalysis['match_score'];
    final rawScore = cvAnalysis['raw_score'];
    final summary = (cvAnalysis['summary'] as String?)?.trim() ?? '';
    final strengths = asStringList(cvAnalysis['strengths']);
    final weaknesses = asStringList(cvAnalysis['weaknesses']);
    final skills = asStringList(cvAnalysis['extracted_skills']);
    final recommendation =
        (cvAnalysis['recommendation'] as String?)?.trim() ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.92,
            height: MediaQuery.of(context).size.height * 0.82,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        themeProvider.isDarkMode ? _kDarkSurface : Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CV Analysis - ${review['full_name'] ?? 'Unknown'}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _kPrimary.withValues(alpha: 0.12),
                                    borderRadius:
                                        BorderRadius.circular(_kBadgeRadius),
                                    border: Border.all(
                                      color: _kPrimary.withValues(alpha: 0.35),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Status: $status',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (matchScore != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _kPrimary.withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(_kBadgeRadius),
                                      border: Border.all(
                                        color:
                                            _kPrimary.withValues(alpha: 0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'Match: $matchScore%',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: themeProvider.isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 10),
                                if (rawScore != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _kPrimary.withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(_kBadgeRadius),
                                      border: Border.all(
                                        color:
                                            _kPrimary.withValues(alpha: 0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'Raw: $rawScore%',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: themeProvider.isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sectionTitle('Summary'),
                        Text(
                          summary.isNotEmpty ? summary : '—',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: themeProvider.isDarkMode
                                ? Colors.white70
                                : Colors.black87,
                          ),
                        ),
                        sectionTitle('Strengths'),
                        chips(strengths),
                        sectionTitle('Weaknesses'),
                        chips(weaknesses),
                        sectionTitle('Extracted skills'),
                        chips(skills),
                        sectionTitle('Recommendation'),
                        Text(
                          recommendation.isNotEmpty ? recommendation : '—',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: themeProvider.isDarkMode
                                ? Colors.white70
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> get displayedCVs {
    var base = cvReviews;

    // Only show users that have a full name
    base = base.where((cv) {
      final name = cv['full_name'];
      return name is String && name.trim().isNotEmpty;
    }).toList();

    // Only show CVs with a valid uploaded URL
    // Prefer application-level resume_url, fall back to candidate-level cv_url.
    base = base.where((cv) {
      final resumeUrl = cv['resume_url'];
      final candidateUrl = cv['cv_url'];
      final url = (resumeUrl is String && resumeUrl.trim().isNotEmpty)
          ? resumeUrl
          : (candidateUrl is String ? candidateUrl : null);
      if (url == null) return false;
      return url.trim().isNotEmpty;
    }).toList();

    // Filter by search query
    if (searchQuery.isNotEmpty) {
      base = base
          .where((cv) =>
              (cv['full_name'] as String?)
                  ?.toLowerCase()
                  .contains(searchQuery.toLowerCase()) ??
              false)
          .toList();
    }

    // Filter by gender
    if (selectedGender != 'All') {
      base = base.where((cv) => cv['gender'] == selectedGender).toList();
    }

    // Filter by score
    if (selectedScoreFilter != 'All') {
      switch (selectedScoreFilter) {
        case 'Above 70%':
          base = base.where((cv) {
            double score = (cv['cv_score'] as num?)?.toDouble() ?? 0.0;
            return score >= 70;
          }).toList();
          break;
        case 'Above 50%':
          base = base.where((cv) {
            double score = (cv['cv_score'] as num?)?.toDouble() ?? 0.0;
            return score >= 50;
          }).toList();
          break;
        case 'Below 50%':
          base = base.where((cv) {
            double score = (cv['cv_score'] as num?)?.toDouble() ?? 0.0;
            return score < 50;
          }).toList();
          break;
      }
    }

    // Filter by analysis status
    if (selectedAnalysisFilter != 'All') {
      base = base.where((cv) {
        final cvAnalysis = cv['cv_analysis'];
        final status =
            (cvAnalysis is Map ? (cvAnalysis['status'] as String?) : null) ??
                'not_analyzed';
        if (selectedAnalysisFilter == 'Analyzed') {
          return status.toLowerCase() == 'completed';
        }
        if (selectedAnalysisFilter == 'Not analyzed') {
          return status.toLowerCase() != 'completed';
        }
        return true;
      }).toList();
    }

    return base;
  }

  Color getScoreColor(double score) {
    if (score >= 70) return Colors.green;
    if (score >= 50) return Colors.orange;
    return _kPrimary;
  }

  String getScoreLabel(double score) {
    if (score >= 70) return 'Excellent';
    if (score >= 50) return 'Good';
    return 'Needs Review';
  }

  static const double _kTranslucentOpacity = 0.9;
  static const double _kCardAndHeaderOpacity = 0.7; // dark mode
  static const double _kCardOpacityLight =
      0.98; // light mode: thick, minimal see-through (match analytics)

  // Design system
  static const Color _kPrimary = Color(0xFFC10D00);
  static const Color _kDarkSurface = Color(0xFF2C3E50);
  static const double _kCardRadius = 16;
  static const double _kBadgeRadius = 20;
  static const double _kSearchRadius = 25;
  static const double _kInputRadius = 4;
  static const double _kMainPadding = 16;
  static const double _kSmallGap = 8;

  Future<void> _previewCV(Map<String, dynamic> review) async {
    try {
      final applicationId = review['application_id'] as int?;
      if (applicationId == null) {
        throw Exception('Missing application ID');
      }

      // Use admin proxy endpoint for in-app preview
      final token = await AuthService.getAccessToken();
      final cvUrl =
          '${ApiEndpoints.adminBase}/applications/$applicationId/cv-preview';

      // Show modal dialog with WebView
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CV Preview - ${review['full_name'] ?? 'Unknown'}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: WebViewWidget(
                      controller: WebViewController()
                        ..loadRequest(
                          Uri.parse(cvUrl),
                          headers: {
                            'Authorization': 'Bearer $token',
                          },
                        ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error previewing CV: $e',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      // 🌆 Dynamic background implementation
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(themeProvider.backgroundImage),
            fit: BoxFit.cover,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: loading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_kPrimary),
                      ),
                      const SizedBox(height: _kMainPadding),
                      Text(
                        "Loading CV Reviews...",
                        style: GoogleFonts.poppins(
                          color: themeProvider.isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(_kMainPadding),
                  child: displayedCVs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 80,
                                color: themeProvider.isDarkMode
                                    ? Colors.grey.shade600
                                    : Colors.grey.shade300,
                              ),
                              const SizedBox(height: _kMainPadding),
                              Text(
                                "No CV Reviews Found",
                                style: GoogleFonts.poppins(
                                  color: themeProvider.isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: _kSmallGap),
                              Text(
                                "CV reviews will appear here once available",
                                style: GoogleFonts.poppins(
                                  color: themeProvider.isDarkMode
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : CustomScrollView(
                          slivers: [
                            // Header with stats and filter toggle (scrolls with content)
                            SliverToBoxAdapter(
                              child: Container(
                                padding: const EdgeInsets.all(_kMainPadding),
                                decoration: BoxDecoration(
                                  color: themeProvider.isDarkMode
                                      ? _kDarkSurface.withValues(
                                          alpha: _kCardAndHeaderOpacity)
                                      : Colors.white.withValues(
                                          alpha: _kCardAndHeaderOpacity),
                                  borderRadius:
                                      BorderRadius.circular(_kCardRadius),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 15,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Candidate Reviews",
                                              style: GoogleFonts.poppins(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w600,
                                                color: themeProvider.isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
                                            Text(
                                              "${displayedCVs.length} candidates reviewed",
                                              style: GoogleFonts.poppins(
                                                color: themeProvider.isDarkMode
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: _kMainPadding,
                                              vertical: _kSmallGap),
                                          decoration: BoxDecoration(
                                            color: _kPrimary.withValues(
                                                alpha: _kTranslucentOpacity),
                                            borderRadius: BorderRadius.circular(
                                                _kBadgeRadius),
                                          ),
                                          child: Text(
                                            "Reviewed CVs",
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: _kMainPadding),
                                    // Analysis status filter
                                    Row(
                                      children: [
                                        Text(
                                          'Analysis Status: ',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: themeProvider.isDarkMode
                                                ? Colors.white70
                                                : Colors.black54,
                                          ),
                                        ),
                                        Expanded(
                                          child: DropdownButton<String>(
                                            value: selectedAnalysisFilter,
                                            isDense: true,
                                            underline: const SizedBox(),
                                            dropdownColor:
                                                themeProvider.isDarkMode
                                                    ? _kDarkSurface
                                                    : Colors.white,
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: themeProvider.isDarkMode
                                                  ? Colors.white
                                                  : _kPrimary,
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                  value: 'All',
                                                  child: Text('All')),
                                              DropdownMenuItem(
                                                  value: 'Analyzed',
                                                  child: Text('Analyzed')),
                                              DropdownMenuItem(
                                                  value: 'Not analyzed',
                                                  child: Text('Not analyzed')),
                                            ],
                                            onChanged: (value) => setState(() =>
                                                selectedAnalysisFilter =
                                                    value!),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: _kMainPadding),
                                    // Search and filters row
                                    Row(
                                      children: [
                                        // Search bar
                                        Expanded(
                                          flex: 3,
                                          child: TextField(
                                            onChanged: (value) => setState(
                                                () => searchQuery = value),
                                            decoration: InputDecoration(
                                              hintText: 'Search by name...',
                                              hintStyle: GoogleFonts.poppins(
                                                  color:
                                                      themeProvider.isDarkMode
                                                          ? Colors.white54
                                                          : Colors.black54),
                                              prefixIcon: Icon(Icons.search,
                                                  color:
                                                      themeProvider.isDarkMode
                                                          ? Colors.white70
                                                          : Colors.black54),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        _kSearchRadius),
                                              ),
                                              filled: true,
                                              fillColor: themeProvider
                                                      .isDarkMode
                                                  ? _kDarkSurface.withValues(
                                                      alpha:
                                                          _kTranslucentOpacity)
                                                  : Colors.white.withValues(
                                                      alpha:
                                                          _kTranslucentOpacity),
                                            ),
                                            style: GoogleFonts.poppins(
                                                color: themeProvider.isDarkMode
                                                    ? Colors.white
                                                    : Colors.black),
                                          ),
                                        ),
                                        const SizedBox(width: _kMainPadding),
                                        // Gender filter
                                        Expanded(
                                          flex: 2,
                                          child:
                                              DropdownButtonFormField<String>(
                                            value: selectedGender,
                                            onChanged: (value) => setState(
                                                () => selectedGender = value!),
                                            items: ['All', 'Male', 'Female']
                                                .map((gender) =>
                                                    DropdownMenuItem(
                                                      value: gender,
                                                      child: Text(gender,
                                                          style: GoogleFonts.poppins(
                                                              color: themeProvider
                                                                      .isDarkMode
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .black)),
                                                    ))
                                                .toList(),
                                            decoration: InputDecoration(
                                              labelText: 'Gender',
                                              labelStyle: GoogleFonts.poppins(
                                                  color:
                                                      themeProvider.isDarkMode
                                                          ? Colors.white70
                                                          : Colors.black54),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          _kInputRadius)),
                                              filled: true,
                                              fillColor: themeProvider
                                                      .isDarkMode
                                                  ? _kDarkSurface.withValues(
                                                      alpha:
                                                          _kTranslucentOpacity)
                                                  : Colors.white.withValues(
                                                      alpha:
                                                          _kTranslucentOpacity),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                            ),
                                            dropdownColor: themeProvider
                                                    .isDarkMode
                                                ? _kDarkSurface.withValues(
                                                    alpha: _kTranslucentOpacity)
                                                : Colors.white.withValues(
                                                    alpha:
                                                        _kTranslucentOpacity),
                                            style: GoogleFonts.poppins(
                                                color: themeProvider.isDarkMode
                                                    ? Colors.white
                                                    : Colors.black),
                                            isExpanded: true,
                                          ),
                                        ),
                                        const SizedBox(width: _kMainPadding),
                                        // Score filter
                                        Expanded(
                                          flex: 2,
                                          child:
                                              DropdownButtonFormField<String>(
                                            value: selectedScoreFilter,
                                            onChanged: (value) => setState(() =>
                                                selectedScoreFilter = value!),
                                            items: [
                                              'All',
                                              'Above 70%',
                                              'Above 50%',
                                              'Below 50%'
                                            ]
                                                .map((filter) =>
                                                    DropdownMenuItem(
                                                      value: filter,
                                                      child: Text(filter,
                                                          style: GoogleFonts.poppins(
                                                              color: themeProvider
                                                                      .isDarkMode
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .black)),
                                                    ))
                                                .toList(),
                                            decoration: InputDecoration(
                                              labelText: 'Score',
                                              labelStyle: GoogleFonts.poppins(
                                                  color:
                                                      themeProvider.isDarkMode
                                                          ? Colors.white70
                                                          : Colors.black54),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          _kInputRadius)),
                                              filled: true,
                                              fillColor: themeProvider
                                                      .isDarkMode
                                                  ? _kDarkSurface.withValues(
                                                      alpha:
                                                          _kTranslucentOpacity)
                                                  : Colors.white.withValues(
                                                      alpha:
                                                          _kTranslucentOpacity),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                            ),
                                            dropdownColor: themeProvider
                                                    .isDarkMode
                                                ? _kDarkSurface.withValues(
                                                    alpha: _kTranslucentOpacity)
                                                : Colors.white.withValues(
                                                    alpha:
                                                        _kTranslucentOpacity),
                                            style: GoogleFonts.poppins(
                                                color: themeProvider.isDarkMode
                                                    ? Colors.white
                                                    : Colors.black),
                                            isExpanded: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(
                                child: SizedBox(height: _kMainPadding)),

                            // Candidates table (same design & opacity, faster browse for 200–1000 rows)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: _kMainPadding),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: themeProvider.isDarkMode
                                        ? _kDarkSurface.withValues(
                                            alpha: _kCardAndHeaderOpacity)
                                        : Colors.white.withValues(
                                            alpha: _kCardOpacityLight),
                                    borderRadius:
                                        BorderRadius.circular(_kCardRadius),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 15,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Table header row
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: _kMainPadding,
                                            vertical: 12),
                                        decoration: BoxDecoration(
                                          color: themeProvider.isDarkMode
                                              ? _kDarkSurface.withValues(
                                                  alpha: _kCardAndHeaderOpacity)
                                              : Colors.white.withValues(
                                                  alpha: _kCardOpacityLight),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(
                                                      _kCardRadius)),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                                flex: 3,
                                                child: Text('Candidate',
                                                    style: GoogleFonts.poppins(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 14,
                                                        color: themeProvider
                                                                .isDarkMode
                                                            ? Colors.white70
                                                            : Colors.black87))),
                                            Expanded(
                                              flex: 1,
                                              child: Center(
                                                  child: Text('Gender',
                                                      style: GoogleFonts.poppins(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14,
                                                          color: themeProvider
                                                                  .isDarkMode
                                                              ? Colors.white70
                                                              : Colors
                                                                  .black87))),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Center(
                                                  child: Text('CV Score',
                                                      style: GoogleFonts.poppins(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14,
                                                          color: themeProvider
                                                                  .isDarkMode
                                                              ? Colors.white70
                                                              : Colors
                                                                  .black87))),
                                            ),
                                            const SizedBox(width: 100),
                                          ],
                                        ),
                                      ),
                                      Divider(
                                          height: 1,
                                          color: themeProvider.isDarkMode
                                              ? Colors.white
                                                  .withValues(alpha: 0.1)
                                              : Colors.black
                                                  .withValues(alpha: 0.1)),
                                      SizedBox(
                                        height: 420,
                                        child: ListView.builder(
                                          itemCount: displayedCVs.length,
                                          itemBuilder: (context, index) {
                                            final review = displayedCVs[index];
                                            final hasScore = review
                                                    .containsKey('cv_score') &&
                                                review['cv_score'] != null;
                                            final score = hasScore
                                                ? (review['cv_score'] ?? 0)
                                                    .toDouble()
                                                : 0.0;
                                            final isLast = index ==
                                                displayedCVs.length - 1;
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: _kMainPadding,
                                                      vertical: _kSmallGap),
                                              decoration: BoxDecoration(
                                                color: themeProvider.isDarkMode
                                                    ? _kDarkSurface.withValues(
                                                        alpha:
                                                            _kCardAndHeaderOpacity)
                                                    : Colors.white.withValues(
                                                        alpha:
                                                            _kCardOpacityLight),
                                                borderRadius: isLast
                                                    ? const BorderRadius
                                                        .vertical(
                                                        bottom: Radius.circular(
                                                            _kCardRadius))
                                                    : null,
                                                border: isLast
                                                    ? null
                                                    : Border(
                                                        bottom: BorderSide(
                                                          color: themeProvider
                                                                  .isDarkMode
                                                              ? Colors.white
                                                                  .withValues(
                                                                      alpha:
                                                                          0.15)
                                                              : Colors.black
                                                                  .withValues(
                                                                      alpha:
                                                                          0.12),
                                                          width: 1,
                                                        ),
                                                      ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 3,
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 36,
                                                          height: 36,
                                                          decoration:
                                                              const BoxDecoration(
                                                            shape:
                                                                BoxShape.circle,
                                                            color: _kPrimary,
                                                          ),
                                                          child: const Icon(
                                                            Icons.person,
                                                            color: Colors.white,
                                                            size: 18,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: _kSmallGap),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                review['full_name'] ??
                                                                    'Unknown',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: themeProvider
                                                                          .isDarkMode
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .black,
                                                                ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                              const SizedBox(
                                                                  height: 2),
                                                              Text(
                                                                'ID: ${review['application_id'] ?? 'N/A'}',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w400,
                                                                  color: themeProvider
                                                                          .isDarkMode
                                                                      ? Colors
                                                                          .white70
                                                                      : Colors
                                                                          .black54,
                                                                ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Center(
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 10,
                                                                vertical: 6),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: _kPrimary.withValues(
                                                              alpha: (review['gender'] ==
                                                                          null ||
                                                                      review['gender'] ==
                                                                          '' ||
                                                                      review['gender'] ==
                                                                          'N/A')
                                                                  ? _kCardAndHeaderOpacity
                                                                  : _kTranslucentOpacity),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  _kCardRadius),
                                                        ),
                                                        child: Text(
                                                          review['gender'] ??
                                                              'N/A',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors.white,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Center(
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            hasScore
                                                                ? Icons.star
                                                                : Icons
                                                                    .star_border,
                                                            color: themeProvider
                                                                    .isDarkMode
                                                                ? (hasScore
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .white70)
                                                                : Colors.black,
                                                            size: 16,
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            hasScore
                                                                ? '${score.toStringAsFixed(1)}%'
                                                                : '—',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: themeProvider
                                                                      .isDarkMode
                                                                  ? (hasScore
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .white70)
                                                                  : Colors
                                                                      .black,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 100,
                                                    child: ElevatedButton(
                                                      onPressed: () =>
                                                          _previewCV(review),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            _kPrimary,
                                                        foregroundColor:
                                                            Colors.white,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 8),
                                                        minimumSize: Size.zero,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  _kCardRadius),
                                                        ),
                                                        elevation: 2,
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .remove_red_eye,
                                                              size: 14),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            'Preview',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  SizedBox(
                                                    width: 100,
                                                    child: ElevatedButton(
                                                      onPressed: () =>
                                                          _showCVAnalysis(
                                                              review),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            _kPrimary,
                                                        foregroundColor:
                                                            Colors.white,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 8),
                                                        minimumSize: Size.zero,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  _kCardRadius),
                                                        ),
                                                        elevation: 2,
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons.analytics,
                                                            size: 14,
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            'Analysis',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
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
        ),
      ),
    );
  }
}
