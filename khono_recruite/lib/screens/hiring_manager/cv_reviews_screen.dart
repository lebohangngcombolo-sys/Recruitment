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
    return Colors.redAccent;
  }

  String getScoreLabel(double score) {
    if (score >= 70) return 'Excellent';
    if (score >= 50) return 'Good';
    return 'Needs Review';
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
          appBar: AppBar(
            title: Text(
              "CV Reviews Dashboard",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: (themeProvider.isDarkMode
                    ? const Color(0xFF14131E)
                    : Colors.white)
                .withValues(alpha: 0.9),
            elevation: 0,
            foregroundColor:
                themeProvider.isDarkMode ? Colors.white : Colors.black87,
            iconTheme: IconThemeData(
                color:
                    themeProvider.isDarkMode ? Colors.white : Colors.black87),
          ),
          body: loading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.redAccent),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Loading CV Reviews...",
                        style: GoogleFonts.inter(
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
                  padding: const EdgeInsets.all(20),
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
                              const SizedBox(height: 16),
                              Text(
                                showAllCVs
                                    ? "No CVs Found"
                                    : "No CV Reviews Found",
                                style: GoogleFonts.inter(
                                  color: themeProvider.isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                showAllCVs
                                    ? "CVs will appear here once candidates upload them"
                                    : "CV reviews will appear here once available",
                                style: GoogleFonts.inter(
                                  color: themeProvider.isDarkMode
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with stats and filter toggle
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: (themeProvider.isDarkMode
                                        ? const Color(0xFF14131E)
                                        : Colors.white)
                                    .withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(16),
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
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.assignment_outlined,
                                          color: Colors.redAccent,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            showAllCVs
                                                ? "All CVs"
                                                : "CV Reviews",
                                            style: GoogleFonts.poppins(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                              color: themeProvider.isDarkMode
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            showAllCVs
                                                ? "${allCVs.length} total CVs uploaded"
                                                : "${cvReviews.length} candidates reviewed",
                                            style: GoogleFonts.inter(
                                              color: themeProvider.isDarkMode
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: (showAllCVs
                                                  ? Colors.blue
                                                  : Colors.redAccent)
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          showAllCVs
                                              ? "All CVs"
                                              : "Reviewed CVs",
                                          style: GoogleFonts.inter(
                                            color: showAllCVs
                                                ? Colors.blue
                                                : Colors.redAccent,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Filter toggle buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(
                                              () => showAllCVs = false),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: !showAllCVs
                                                  ? const Color(0xFFC10D00)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: const Color(0xFFC10D00)
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              "Reviewed CVs",
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(
                                                color: !showAllCVs
                                                    ? Colors.white
                                                    : const Color(0xFFC10D00),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () =>
                                              setState(() => showAllCVs = true),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: showAllCVs
                                                  ? const Color(0xFFC10D00)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: const Color(0xFFC10D00)
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              "All CVs",
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(
                                                color: showAllCVs
                                                    ? Colors.white
                                                    : const Color(0xFFC10D00),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
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
                                            hintStyle: TextStyle(
                                                color: themeProvider.isDarkMode
                                                    ? Colors.white54
                                                    : Colors.black54),
                                            prefixIcon: Icon(Icons.search,
                                                color: themeProvider.isDarkMode
                                                    ? Colors.white70
                                                    : Colors.black54),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            filled: true,
                                            fillColor: themeProvider.isDarkMode
                                                ? Colors.grey[800]
                                                : Colors.grey[100],
                                          ),
                                          style: TextStyle(
                                              color: themeProvider.isDarkMode
                                                  ? Colors.white
                                                  : Colors.black),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
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
                                                        style: TextStyle(
                                                            color: themeProvider
                                                                    .isDarkMode
                                                                ? Colors.white
                                                                : Colors
                                                                    .black)),
                                                  ))
                                              .toList(),
                                          decoration: InputDecoration(
                                            labelText: 'Gender',
                                            labelStyle: TextStyle(
                                                color: themeProvider.isDarkMode
                                                    ? Colors.white70
                                                    : Colors.black54),
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            filled: true,
                                            fillColor: themeProvider.isDarkMode
                                                ? Colors.grey[800]
                                                : Colors.grey[100],
                                          ),
                                          dropdownColor:
                                              themeProvider.isDarkMode
                                                  ? Colors.grey[800]
                                                  : Colors.white,
                                          style: TextStyle(
                                              color: themeProvider.isDarkMode
                                                  ? Colors.white
                                                  : Colors.black),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
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
                                                        style: TextStyle(
                                                            color: themeProvider
                                                                    .isDarkMode
                                                                ? Colors.white
                                                                : Colors
                                                                    .black)),
                                                  ))
                                              .toList(),
                                          decoration: InputDecoration(
                                            labelText: 'Score',
                                            labelStyle: TextStyle(
                                                color: themeProvider.isDarkMode
                                                    ? Colors.white70
                                                    : Colors.black54),
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            filled: true,
                                            fillColor: themeProvider.isDarkMode
                                                ? Colors.grey[800]
                                                : Colors.grey[100],
                                          ),
                                          dropdownColor:
                                              themeProvider.isDarkMode
                                                  ? Colors.grey[800]
                                                  : Colors.white,
                                          style: TextStyle(
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
                            const SizedBox(height: 20),

                            // Candidate CV Cards
                            Expanded(
                              child: ListView.builder(
                                itemCount: displayedCVs.length,
                                itemBuilder: (context, index) {
                                  final review = displayedCVs[index];
                                  final hasScore =
                                      review.containsKey('cv_score') &&
                                          review['cv_score'] != null;
                                  final score = hasScore
                                      ? (review['cv_score'] ?? 0).toDouble()
                                      : 0.0;
                                  final cvUrl = review['cv_url'] as String?;

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 16),
                                    elevation: 8,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: LinearGradient(
                                          colors: themeProvider.isDarkMode
                                              ? [
                                                  const Color(0xFF1E1E2E)
                                                      .withValues(alpha: 0.9),
                                                  const Color(0xFF2A2A3E)
                                                      .withValues(alpha: 0.9),
                                                ]
                                              : [
                                                  Colors.white
                                                      .withValues(alpha: 0.95),
                                                  Colors.grey.shade50
                                                      .withValues(alpha: 0.95),
                                                ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.1),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Header with Name and Gender
                                            Row(
                                              children: [
                                                Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        const Color(0xFFC10D00),
                                                        Colors.red.shade700,
                                                      ],
                                                    ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.person,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        review['full_name'] ??
                                                            'Unknown Candidate',
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: themeProvider
                                                                  .isDarkMode
                                                              ? Colors.white
                                                              : Colors.black87,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 10,
                                                                vertical: 4),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: (review['gender'] ==
                                                                      'Male'
                                                                  ? Colors.blue
                                                                  : review['gender'] ==
                                                                          'Female'
                                                                      ? Colors
                                                                          .pink
                                                                      : Colors
                                                                          .grey)
                                                              .withValues(
                                                                  alpha: 0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                          border: Border.all(
                                                            color: (review['gender'] ==
                                                                        'Male'
                                                                    ? Colors
                                                                        .blue
                                                                    : review['gender'] ==
                                                                            'Female'
                                                                        ? Colors
                                                                            .pink
                                                                        : Colors
                                                                            .grey)
                                                                .withValues(
                                                                    alpha: 0.3),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          review['gender'] ??
                                                              'N/A',
                                                          style:
                                                              GoogleFonts.inter(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: review[
                                                                        'gender'] ==
                                                                    'Male'
                                                                ? Colors.blue
                                                                    .shade700
                                                                : review['gender'] ==
                                                                        'Female'
                                                                    ? Colors
                                                                        .pink
                                                                        .shade700
                                                                    : Colors
                                                                        .grey
                                                                        .shade700,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            // Score Section
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: hasScore
                                                    ? Colors.amber
                                                        .withValues(alpha: 0.1)
                                                    : Colors.grey
                                                        .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: hasScore
                                                      ? Colors.amber.withValues(
                                                          alpha: 0.3)
                                                      : Colors.grey.withValues(
                                                          alpha: 0.3),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    hasScore
                                                        ? Icons.star
                                                        : Icons.star_border,
                                                    color: hasScore
                                                        ? Colors.amber.shade600
                                                        : Colors.grey,
                                                    size: 24,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    hasScore
                                                        ? 'CV Score: ${score.toStringAsFixed(1)}%'
                                                        : 'CV Score: Not Available',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: hasScore
                                                          ? Colors
                                                              .amber.shade800
                                                          : Colors
                                                              .grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            // Preview Button
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                onPressed: cvUrl != null &&
                                                        cvUrl.isNotEmpty
                                                    ? () => launch(cvUrl)
                                                    : null,
                                                icon: const Icon(
                                                    Icons.remove_red_eye),
                                                label: const Text('Preview CV'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: cvUrl !=
                                                              null &&
                                                          cvUrl.isNotEmpty
                                                      ? const Color(0xFFC10D00)
                                                      : Colors.grey.shade400,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 14),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  elevation: cvUrl != null &&
                                                          cvUrl.isNotEmpty
                                                      ? 4
                                                      : 0,
                                                  shadowColor:
                                                      const Color(0xFFC10D00)
                                                          .withValues(
                                                              alpha: 0.3),
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
                            ),
                          ],
                        ),
                ),
        ),
      ),
    );
  }
}
