import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/admin_service.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/api_endpoints.dart';

class CVReviewsScreen extends StatefulWidget {
  const CVReviewsScreen({super.key});

  @override
  State<CVReviewsScreen> createState() => _CVReviewsScreenState();
}

class _CVReviewsScreenState extends State<CVReviewsScreen> {
  final AdminService admin = AdminService();
  List<Map<String, dynamic>> cvReviews = [];
  List<Map<String, dynamic>> filteredReviews = [];
  bool loading = true;
  String? selectedFilter;

  @override
  void initState() {
    super.initState();
    fetchCVReviews();
  }

  Future<void> fetchCVReviews() async {
    setState(() => loading = true);
    try {
      final List<Map<String, dynamic>> all = [];
      var page = 1;
      while (true) {
        final batch = await admin.listCVReviews(
          page: page,
          perPage: 200,
          scope: 'all',
        );
        all.addAll(batch);
        if (batch.length < 200) break;
        page++;
      }
      if (!mounted) return;
      setState(() {
        cvReviews = List<Map<String, dynamic>>.from(all);
        // Apply initial filter to only show entries with valid Cloudinary cv_url
        filteredReviews = cvReviews.where((review) {
          final url = review['cv_url'] as String?;
          return url != null &&
              url.trim().isNotEmpty &&
              url.contains('cloudinary.com');
        }).toList();
      });
    } catch (e) {
      debugPrint("Error fetching CV reviews: $e");
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
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
            content: Text('Error previewing CV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void applyFilter(String? filter) {
    setState(() {
      selectedFilter = filter;
      var base = cvReviews;
      // Only show entries with a valid Cloudinary cv_url
      base = base.where((review) {
        final url = review['cv_url'] as String?;
        return url != null &&
            url.trim().isNotEmpty &&
            url.contains('cloudinary.com');
      }).toList();
      if (filter == null) {
        filteredReviews = List.from(base);
      } else {
        filteredReviews = base.where((review) {
          final score = (review['cv_score'] ?? 0).toDouble();
          final label = getScoreLabel(score);
          return label == filter;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 1000
        ? 3
        : screenWidth > 600
            ? 2
            : 1;

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
                  child: cvReviews.isEmpty
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
                                "No CV Reviews Found",
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
                                "CV reviews will appear here once available",
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
                            // Header with stats
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
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
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
                                        "CV Reviews",
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: themeProvider.isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        "${filteredReviews.length} candidates ${selectedFilter != null ? '($selectedFilter)' : ''}",
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

                                  // Filter Dropdown Button
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedFilter,
                                        icon: Icon(
                                          Icons.filter_list,
                                          color: Colors.redAccent,
                                          size: 20,
                                        ),
                                        elevation: 16,
                                        style: GoogleFonts.inter(
                                          color: themeProvider.isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 12,
                                        ),
                                        dropdownColor: themeProvider.isDarkMode
                                            ? const Color(0xFF14131E)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        hint: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Text(
                                            "Filter by",
                                            style: GoogleFonts.inter(
                                              color: Colors.redAccent,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        onChanged: (String? newValue) {
                                          applyFilter(newValue);
                                        },
                                        items: <String>[
                                          'All',
                                          'Excellent',
                                          'Good',
                                          'Needs Review'
                                        ].map<DropdownMenuItem<String>>(
                                            (String value) {
                                          return DropdownMenuItem<String>(
                                            value:
                                                value == 'All' ? null : value,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8),
                                              child: Text(
                                                value,
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color:
                                                      themeProvider.isDarkMode
                                                          ? Colors.white
                                                          : Colors.black87,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Grid of CV reviews
                            Expanded(
                              child: GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 20,
                                  crossAxisSpacing: 20,
                                  childAspectRatio: 0.75,
                                ),
                                itemCount: filteredReviews.length,
                                itemBuilder: (_, index) {
                                  final review = filteredReviews[index];
                                  final score =
                                      (review['cv_score'] ?? 0).toDouble();
                                  final scoreColor = getScoreColor(score);
                                  final scoreLabel = getScoreLabel(score);

                                  final cvParser =
                                      review['cv_parser_result'] ?? {};
                                  final skills = cvParser['skills'] ?? [];
                                  final education = cvParser['education'] ?? [];
                                  final workExp =
                                      cvParser['work_experience'] ?? [];

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: (themeProvider.isDarkMode
                                              ? const Color(0xFF14131E)
                                              : Colors.white)
                                          .withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.1),
                                          blurRadius: 15,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        // Header with score
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: scoreColor.withValues(
                                                alpha: 0.1),
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(20),
                                              topRight: Radius.circular(20),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  CircularPercentIndicator(
                                                    radius: 30,
                                                    lineWidth: 6,
                                                    percent: (score / 100)
                                                        .clamp(0.0, 1.0),
                                                    center: Text(
                                                      "${score.toStringAsFixed(0)}%",
                                                      style: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                        color: scoreColor,
                                                      ),
                                                    ),
                                                    progressColor: scoreColor,
                                                    backgroundColor:
                                                        themeProvider.isDarkMode
                                                            ? Colors
                                                                .grey.shade800
                                                            : Colors
                                                                .grey.shade200,
                                                    circularStrokeCap:
                                                        CircularStrokeCap.round,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      review['full_name'] ??
                                                          "Unknown Candidate",
                                                      style: GoogleFonts.inter(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: themeProvider
                                                                .isDarkMode
                                                            ? Colors.white
                                                            : Colors.black87,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: scoreColor
                                                            .withValues(
                                                                alpha: 0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: Text(
                                                        scoreLabel,
                                                        style:
                                                            GoogleFonts.inter(
                                                          color: scoreColor,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // CV Fit Score
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          "CV Fit Score",
                                                          style:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 12,
                                                            color: themeProvider
                                                                    .isDarkMode
                                                                ? Colors.grey
                                                                    .shade400
                                                                : Colors.grey
                                                                    .shade700,
                                                          ),
                                                        ),
                                                        Text(
                                                          "${score.toStringAsFixed(1)}%",
                                                          style:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 12,
                                                            color: scoreColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    LinearPercentIndicator(
                                                      lineHeight: 6,
                                                      percent: (score / 100)
                                                          .clamp(0.0, 1.0),
                                                      backgroundColor:
                                                          themeProvider
                                                                  .isDarkMode
                                                              ? Colors
                                                                  .grey.shade800
                                                              : Colors.grey
                                                                  .shade200,
                                                      progressColor: scoreColor,
                                                      barRadius:
                                                          const Radius.circular(
                                                              3),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 16),

                                                // Skills
                                                if (skills.isNotEmpty)
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        "Skills",
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 12,
                                                          color: themeProvider
                                                                  .isDarkMode
                                                              ? Colors
                                                                  .grey.shade400
                                                              : Colors.grey
                                                                  .shade700,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Wrap(
                                                        spacing: 6,
                                                        runSpacing: 6,
                                                        children: skills
                                                            .take(4)
                                                            .map<Widget>(
                                                                (s) =>
                                                                    Container(
                                                                      padding: const EdgeInsets
                                                                          .symmetric(
                                                                          horizontal:
                                                                              8,
                                                                          vertical:
                                                                              4),
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: Colors
                                                                            .redAccent
                                                                            .withValues(alpha: 0.1),
                                                                        borderRadius:
                                                                            BorderRadius.circular(12),
                                                                      ),
                                                                      child:
                                                                          Text(
                                                                        s.toString(),
                                                                        style: GoogleFonts
                                                                            .inter(
                                                                          fontSize:
                                                                              10,
                                                                          color:
                                                                              Colors.redAccent,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                        ),
                                                                      ),
                                                                    ))
                                                            .toList(),
                                                      ),
                                                      if (skills.length > 4)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(top: 4),
                                                          child: Text(
                                                            "+${skills.length - 4} more",
                                                            style: GoogleFonts
                                                                .inter(
                                                              fontSize: 10,
                                                              color: themeProvider
                                                                      .isDarkMode
                                                                  ? Colors.grey
                                                                      .shade500
                                                                  : Colors.grey
                                                                      .shade500,
                                                            ),
                                                          ),
                                                        ),
                                                      const SizedBox(
                                                          height: 12),
                                                    ],
                                                  ),

                                                // Education
                                                if (education.isNotEmpty)
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        "Education",
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 12,
                                                          color: themeProvider
                                                                  .isDarkMode
                                                              ? Colors
                                                                  .grey.shade400
                                                              : Colors.grey
                                                                  .shade700,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      ...education
                                                          .take(2)
                                                          .map<Widget>(
                                                              (edu) => Padding(
                                                                    padding: const EdgeInsets
                                                                        .only(
                                                                        bottom:
                                                                            4),
                                                                    child: Text(
                                                                      "• ${edu['degree'] ?? ''} - ${edu['institution'] ?? ''}",
                                                                      style: GoogleFonts
                                                                          .inter(
                                                                        fontSize:
                                                                            10,
                                                                        color: themeProvider.isDarkMode
                                                                            ? Colors.grey.shade500
                                                                            : Colors.grey.shade600,
                                                                      ),
                                                                      maxLines:
                                                                          1,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                  )),
                                                      const SizedBox(
                                                          height: 12),
                                                    ],
                                                  ),

                                                // Work Experience
                                                if (workExp.isNotEmpty)
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          "Experience",
                                                          style:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 12,
                                                            color: themeProvider
                                                                    .isDarkMode
                                                                ? Colors.grey
                                                                    .shade400
                                                                : Colors.grey
                                                                    .shade700,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 6),
                                                        ...workExp
                                                            .take(2)
                                                            .map<Widget>(
                                                                (exp) =>
                                                                    Padding(
                                                                      padding: const EdgeInsets
                                                                          .only(
                                                                          bottom:
                                                                              4),
                                                                      child:
                                                                          Text(
                                                                        "• ${exp['role'] ?? ''} at ${exp['company'] ?? ''}",
                                                                        style: GoogleFonts
                                                                            .inter(
                                                                          fontSize:
                                                                              10,
                                                                          color: themeProvider.isDarkMode
                                                                              ? Colors.grey.shade500
                                                                              : Colors.grey.shade600,
                                                                        ),
                                                                        maxLines:
                                                                            1,
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                      ),
                                                                    )),
                                                      ],
                                                    ),
                                                  ),
                                                const SizedBox(height: 12),

                                                // Preview CV button
                                                Align(
                                                  alignment:
                                                      Alignment.bottomRight,
                                                  child: ElevatedButton.icon(
                                                    onPressed: () =>
                                                        _previewCV(review),
                                                    icon: const Icon(
                                                        Icons.remove_red_eye,
                                                        size: 16),
                                                    label: const Text(
                                                        'Preview CV'),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          Colors.redAccent,
                                                      foregroundColor:
                                                          Colors.white,
                                                      minimumSize:
                                                          const Size(100, 36),
                                                      textStyle:
                                                          GoogleFonts.inter(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600),
                                                    ),
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
    );
  }
}
