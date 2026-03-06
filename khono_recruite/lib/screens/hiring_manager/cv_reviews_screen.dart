import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/admin_service.dart';
import '../../providers/theme_provider.dart';

class CVReviewsScreen extends StatefulWidget {
  const CVReviewsScreen({super.key});

  @override
  State<CVReviewsScreen> createState() => _CVReviewsScreenState();
}

class _CVReviewsScreenState extends State<CVReviewsScreen> {
  final AdminService admin = AdminService();
  List<Map<String, dynamic>> cvReviews = [];
  List<Map<String, dynamic>> allCVs = [];
  bool loading = true;
  bool showAllCVs = false;
  String searchQuery = '';
  String selectedGender = 'All';
  String selectedScoreFilter = 'All';

  @override
  void initState() {
    super.initState();
    fetchCVReviews();
  }

  Future<void> fetchCVReviews() async {
    setState(() => loading = true);
    try {
      final [reviewsData, allCVsData] = await Future.wait([
        admin.listCVReviews(),
        admin.listAllCVs(),
      ]);
      if (!mounted) return;
      setState(() {
        cvReviews = List<Map<String, dynamic>>.from(reviewsData);
        allCVs = List<Map<String, dynamic>>.from(allCVsData);
      });
    } catch (e) {
      debugPrint("Error fetching CV data: $e");
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get displayedCVs {
    var base = showAllCVs ? allCVs : cvReviews;

    // Only show users that have a full name
    base = base
        .where((cv) {
          final name = cv['full_name'];
          return name is String && name.trim().isNotEmpty;
        })
        .toList();

    // Only show CVs with a valid uploaded URL (Cloudinary)
    base = base
        .where((cv) {
          final url = cv['cv_url'];
          if (url == null || url is! String) return false;
          return url.trim().isNotEmpty && url.contains('cloudinary.com');
        })
        .toList();

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
  static const double _kCardOpacityLight = 0.98; // light mode: thick, minimal see-through (match analytics)

  // Design system
  static const Color _kPrimary = Color(0xFFC10D00);
  static const Color _kDarkSurface = Color(0xFF2C3E50);
  static const double _kCardRadius = 16;
  static const double _kBadgeRadius = 20;
  static const double _kSearchRadius = 25;
  static const double _kInputRadius = 4;
  static const double _kMainPadding = 16;
  static const double _kSmallGap = 8;

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
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_kPrimary),
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
                                showAllCVs
                                    ? "No CVs Found"
                                    : "No CV Reviews Found",
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
                                showAllCVs
                                    ? "CVs will appear here once candidates upload them"
                                    : "CV reviews will appear here once available",
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
                                      ? _kDarkSurface.withValues(alpha: _kCardAndHeaderOpacity)
                                      : Colors.white.withValues(alpha: _kCardAndHeaderOpacity),
                                  borderRadius: BorderRadius.circular(_kCardRadius),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
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
                                              showAllCVs
                                                  ? "All CVs"
                                                  : "Candidate Reviews",
                                              style: GoogleFonts.poppins(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w600,
                                                color: themeProvider.isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
                                            Text(
                                              showAllCVs
                                                  ? "${allCVs.length} total CVs uploaded"
                                                  : "${cvReviews.length} candidates reviewed",
                                              style: GoogleFonts.poppins(
                                                color: themeProvider.isDarkMode
                                                    ? Colors.grey.shade400
                                                    : Colors.black87,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: _kMainPadding, vertical: _kSmallGap),
                                          decoration: BoxDecoration(
                                            color: _kPrimary
                                                .withValues(alpha: _kTranslucentOpacity),
                                            borderRadius:
                                                BorderRadius.circular(_kBadgeRadius),
                                          ),
                                          child: Text(
                                            showAllCVs
                                                ? "All CVs"
                                                : "Reviewed CVs",
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
                                    // Filter toggle buttons
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(
                                                () => showAllCVs = false),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: _kMainPadding, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: !showAllCVs
                                                    ? _kPrimary.withValues(alpha: _kTranslucentOpacity)
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(_kCardRadius),
                                                border: Border.all(
                                                  color: _kPrimary
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Text(
                                                "Reviewed CVs",
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.poppins(
                                                  color: !showAllCVs
                                                      ? Colors.white
                                                      : _kPrimary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: _kSmallGap),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () =>
                                                setState(() => showAllCVs = true),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: _kMainPadding, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: showAllCVs
                                                    ? _kPrimary.withValues(alpha: _kTranslucentOpacity)
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(_kCardRadius),
                                                border: Border.all(
                                                  color: _kPrimary
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Text(
                                                "All CVs",
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.poppins(
                                                  color: showAllCVs
                                                      ? Colors.white
                                                      : _kPrimary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
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
                                          flex: 2,
                                          child: TextField(
                                            onChanged: (value) => setState(
                                                () => searchQuery = value),
                                            decoration: InputDecoration(
                                              hintText: 'Search by name...',
                                              hintStyle: GoogleFonts.poppins(
                                                  color: themeProvider.isDarkMode
                                                      ? Colors.white54
                                                      : Colors.black54),
                                              prefixIcon: Icon(Icons.search,
                                                  color: themeProvider.isDarkMode
                                                      ? Colors.white70
                                                      : Colors.black54),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(_kSearchRadius),
                                              ),
                                              filled: true,
                                              fillColor: themeProvider.isDarkMode
                                                  ? _kDarkSurface.withValues(alpha: _kTranslucentOpacity)
                                                  : Colors.white.withValues(alpha: _kTranslucentOpacity),
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
                                          child: DropdownButtonFormField<String>(
                                            value: selectedGender,
                                            onChanged: (value) => setState(
                                                () => selectedGender = value!),
                                            items: ['All', 'Male', 'Female']
                                                .map((gender) => DropdownMenuItem(
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
                                                  color: themeProvider.isDarkMode
                                                      ? Colors.white70
                                                      : Colors.black54),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(_kInputRadius)),
                                              filled: true,
                                              fillColor: themeProvider.isDarkMode
                                                  ? _kDarkSurface.withValues(alpha: _kTranslucentOpacity)
                                                  : Colors.white.withValues(alpha: _kTranslucentOpacity),
                                            ),
                                            dropdownColor: themeProvider.isDarkMode
                                                ? _kDarkSurface.withValues(alpha: _kTranslucentOpacity)
                                                : Colors.white.withValues(alpha: _kTranslucentOpacity),
                                            style: GoogleFonts.poppins(
                                                color: themeProvider.isDarkMode
                                                    ? Colors.white
                                                    : Colors.black),
                                          ),
                                        ),
                                        const SizedBox(width: _kMainPadding),
                                        // Score filter
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            value: selectedScoreFilter,
                                            onChanged: (value) => setState(() =>
                                                selectedScoreFilter = value!),
                                            items: [
                                              'All',
                                              'Above 70%',
                                              'Above 50%',
                                              'Below 50%'
                                            ]
                                                .map((filter) => DropdownMenuItem(
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
                                                  color: themeProvider.isDarkMode
                                                      ? Colors.white70
                                                      : Colors.black54),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(_kInputRadius)),
                                              filled: true,
                                              fillColor: themeProvider.isDarkMode
                                                  ? _kDarkSurface.withValues(alpha: _kTranslucentOpacity)
                                                  : Colors.white.withValues(alpha: _kTranslucentOpacity),
                                            ),
                                            dropdownColor: themeProvider.isDarkMode
                                                ? _kDarkSurface.withValues(alpha: _kTranslucentOpacity)
                                                : Colors.white.withValues(alpha: _kTranslucentOpacity),
                                            style: GoogleFonts.poppins(
                                                color: themeProvider.isDarkMode
                                                    ? Colors.white
                                                    : Colors.black),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: _kMainPadding)),

                            // Candidates table (same design & opacity, faster browse for 200–1000 rows)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: _kMainPadding),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: themeProvider.isDarkMode
                                        ? _kDarkSurface.withValues(alpha: _kCardAndHeaderOpacity)
                                        : Colors.white.withValues(alpha: _kCardOpacityLight),
                                    borderRadius: BorderRadius.circular(_kCardRadius),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
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
                                            horizontal: _kMainPadding, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: themeProvider.isDarkMode
                                              ? _kDarkSurface.withValues(alpha: _kCardAndHeaderOpacity)
                                              : Colors.white.withValues(alpha: _kCardOpacityLight),
                                          borderRadius: const BorderRadius.vertical(
                                              top: Radius.circular(_kCardRadius)),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                                flex: 2,
                                                child: Text('Candidate',
                                                    style: GoogleFonts.poppins(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                        color: themeProvider.isDarkMode
                                                            ? Colors.white70
                                                            : Colors.black87))),
                                            Expanded(
                                                flex: 1,
                                                child: Center(
                                                    child: Text('Gender',
                                                        style: GoogleFonts.poppins(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 14,
                                                            color: themeProvider.isDarkMode
                                                                ? Colors.white70
                                                                : Colors.black87))),
                                            ),
                                            Expanded(
                                                flex: 1,
                                                child: Center(
                                                    child: Text('CV Score',
                                                        style: GoogleFonts.poppins(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 14,
                                                            color: themeProvider.isDarkMode
                                                                ? Colors.white70
                                                                : Colors.black87))),
                                            ),
                                            const SizedBox(width: 100),
                                          ],
                                        ),
                                      ),
                                      Divider(
                                          height: 1,
                                          color: themeProvider.isDarkMode
                                              ? Colors.white.withValues(alpha: 0.1)
                                              : Colors.black.withValues(alpha: 0.1)),
                                      SizedBox(
                                        height: 420,
                                        child: ListView.builder(
                                          itemCount: displayedCVs.length,
                                          itemBuilder: (context, index) {
                                            final review = displayedCVs[index];
                                            final hasScore = review.containsKey('cv_score') &&
                                                review['cv_score'] != null;
                                            final score = hasScore
                                                ? (review['cv_score'] ?? 0).toDouble()
                                                : 0.0;
                                            final cvUrl = review['cv_url'] as String?;
                                            final isLast = index == displayedCVs.length - 1;
                                            return Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: _kMainPadding, vertical: _kSmallGap),
                                              decoration: BoxDecoration(
                                                color: themeProvider.isDarkMode
                                                    ? _kDarkSurface.withValues(alpha: _kCardAndHeaderOpacity)
                                                    : Colors.white.withValues(alpha: _kCardOpacityLight),
                                                borderRadius: isLast
                                                    ? const BorderRadius.vertical(
                                                        bottom: Radius.circular(_kCardRadius))
                                                    : null,
                                                border: isLast
                                                    ? null
                                                    : Border(
                                                        bottom: BorderSide(
                                                          color: themeProvider.isDarkMode
                                                              ? Colors.white.withValues(alpha: 0.15)
                                                              : Colors.black.withValues(alpha: 0.12),
                                                          width: 1,
                                                        ),
                                                      ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 2,
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 36,
                                                          height: 36,
                                                          decoration: const BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            color: _kPrimary,
                                                          ),
                                                          child: const Icon(
                                                            Icons.person,
                                                            color: Colors.white,
                                                            size: 18,
                                                          ),
                                                        ),
                                                        const SizedBox(width: _kSmallGap),
                                                        Expanded(
                                                          child: Text(
                                                            review['full_name'] ?? 'Unknown',
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 13,
                                                              fontWeight: FontWeight.w500,
                                                              color: themeProvider.isDarkMode
                                                                  ? Colors.white
                                                                  : Colors.black,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Center(
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 10, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: _kPrimary.withValues(
                                                              alpha: (review['gender'] == null ||
                                                                      review['gender'] == '' ||
                                                                      review['gender'] == 'N/A')
                                                                  ? _kCardAndHeaderOpacity
                                                                  : _kTranslucentOpacity),
                                                          borderRadius:
                                                              BorderRadius.circular(_kCardRadius),
                                                        ),
                                                        child: Text(
                                                          review['gender'] ?? 'N/A',
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w600,
                                                            color: Colors.white,
                                                          ),
                                                          textAlign: TextAlign.center,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Center(
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            hasScore ? Icons.star : Icons.star_border,
                                                            color: themeProvider.isDarkMode
                                                                ? (hasScore ? Colors.white : Colors.white70)
                                                                : Colors.black,
                                                            size: 16,
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            hasScore
                                                                ? '${score.toStringAsFixed(1)}%'
                                                                : '—',
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w600,
                                                              color: themeProvider.isDarkMode
                                                                  ? (hasScore ? Colors.white : Colors.white70)
                                                                  : Colors.black,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 100,
                                                    child: ElevatedButton(
                                                      onPressed: cvUrl != null && cvUrl.isNotEmpty
                                                          ? () => launch(cvUrl)
                                                          : null,
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: cvUrl != null &&
                                                                cvUrl.isNotEmpty
                                                            ? _kPrimary
                                                            : (themeProvider.isDarkMode
                                                                ? _kDarkSurface
                                                                    .withValues(alpha: _kCardAndHeaderOpacity)
                                                                : Colors.grey.shade300
                                                                    .withValues(alpha: _kCardOpacityLight)),
                                                        foregroundColor: Colors.white,
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 8, vertical: 8),
                                                        minimumSize: Size.zero,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(_kCardRadius),
                                                        ),
                                                        elevation: cvUrl != null && cvUrl.isNotEmpty ? 2 : 0,
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.remove_red_eye, size: 14),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            'Preview',
                                                            style: GoogleFonts.poppins(
                                                              fontWeight: FontWeight.w600,
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
