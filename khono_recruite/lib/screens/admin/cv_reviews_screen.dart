import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../providers/theme_provider.dart';
import '../../constants/brand_tokens.dart';
import '../../utils/api_endpoints.dart';
import '../../services/cv_analyser_service.dart';
import '../../screens/admin/analysis_screen.dart';
import '../../widgets/themed_surface_card.dart';
import '../../widgets/filter_chip.dart';
import '../../widgets/themed_dialog.dart';
import '../../widgets/state_widgets.dart';

class CVReviewsScreen extends StatefulWidget {
  const CVReviewsScreen({super.key});

  @override
  State<CVReviewsScreen> createState() => _CVReviewsScreenState();
}

class _CVReviewsScreenState extends State<CVReviewsScreen>
    with AutomaticKeepAliveClientMixin {
  final AdminService admin = AdminService();
  final CVAnalyserService cvAnalyser = CVAnalyserService();
  List<Map<String, dynamic>> cvReviews = [];
  List<Map<String, dynamic>> filteredReviews = [];
  bool loading = true;
  bool hasMore = true;
  int currentPage = 1;
  int totalPages = 1;
  final int pageSize = 20;
  final ScrollController _scrollController = ScrollController();
  String? selectedFilter;
  Timer? _searchDebounce;

  bool _analysisInProgress = false;
  String? _analysisStatusText;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    fetchCVReviews();
  }

  Future<void> _analyseCvForCandidate(Map<String, dynamic> review) async {
    if (_analysisInProgress) return;

    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'doc',
          'docx',
          'txt',
          'png',
          'jpg',
          'jpeg',
        ],
      );

      if (picked == null || picked.files.isEmpty) return;

      final file = picked.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Could not read file bytes');
      }

      // Client-side size validation: 15MB
      const maxBytes = 15 * 1024 * 1024;
      if (bytes.length > maxBytes) {
        throw Exception('File too large. Max size is 15MB');
      }

      final filename = file.name;
      final ext = (file.extension ?? '').toLowerCase();
      final contentType = _inferContentType(ext);

      setState(() {
        _analysisInProgress = true;
        _analysisStatusText = 'Uploading…';
      });

      final result = await cvAnalyser.uploadAndPoll(
        bytes: bytes,
        filename: filename,
        contentType: contentType,
        jobDescription: (review['requisition_title'] ?? '').toString(),
        onStatus: (status) {
          if (!mounted) return;
          setState(() {
            _analysisStatusText = 'Status: ${status.status}';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _analysisInProgress = false;
        _analysisStatusText = null;
      });

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AnalysisScreen(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analysisInProgress = false;
        _analysisStatusText = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CV analysis failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _inferContentType(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!loading && hasMore) {
        fetchCVReviews();
      }
    }
  }

  Future<void> fetchCVReviews() async {
    if (!hasMore) return;

    setState(() => loading = true);
    try {
      final batch = await admin.listCVReviews(
        page: currentPage,
        perPage: pageSize,
        scope: 'all',
      );

      setState(() {
        cvReviews.addAll(batch);
        // Apply filter to only show entries with valid Cloudinary cv_url
        final newFiltered = batch.where((review) {
          final url = review['cv_url'] as String?;
          return url != null &&
              url.trim().isNotEmpty &&
              url.contains('cloudinary.com');
        }).toList();

        filteredReviews.addAll(newFiltered);
        hasMore = batch.length == pageSize;
        currentPage++;
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
    return BrandTokens.primary;
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
          return ThemedDialog(
            title: 'CV Preview - ${review['full_name'] ?? 'Unknown'}',
            subtitle: 'Review the candidate\'s CV document',
            icon: Icon(Icons.description_outlined, color: BrandTokens.primary),
            iconColor: BrandTokens.primary,
            showCloseButton: true,
            content: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.6,
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
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC10D00),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
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

  void _showMatchBreakdownDialog(BuildContext context,
      Map<String, dynamic> review, ThemeProvider themeProvider) {
    final parser = review['cv_parser_result'] is Map
        ? Map<String, dynamic>.from(review['cv_parser_result'] as Map)
        : <String, dynamic>{};
    final missingSkills = List<String>.from(parser['missing_skills'] ?? []);
    final suggestions = List<String>.from(parser['suggestions'] ?? []);
    final matchScoreNum = parser['match_score'];
    final recommendation = parser['recommendation'];
    final knockoutViolations =
        List<dynamic>.from(review['knockout_rule_violations'] ?? []);

    final isDark = themeProvider.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'CV match breakdown',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (matchScoreNum != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Match vs role: $matchScoreNum%',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              if (missingSkills.isNotEmpty) ...[
                Text(
                  'Missing skills',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: missingSkills
                      .take(15)
                      .map((s) => Chip(
                            label:
                                Text(s, style: GoogleFonts.inter(fontSize: 11)),
                            backgroundColor:
                                Colors.orange.withValues(alpha: 0.2),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (suggestions.isNotEmpty) ...[
                Text(
                  'Suggestions',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                ...suggestions.take(5).map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        s.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    )),
                const SizedBox(height: 12),
              ],
              if (recommendation != null &&
                  recommendation.toString().trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Gaps / recommendation: $recommendation',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color:
                          isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ),
              if (knockoutViolations.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Knockout (hold)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 6),
                ...knockoutViolations.take(5).map((v) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        v.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                        ),
                      ),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
              ? const ThemedLoadingState(
                  message: "Loading CV Reviews...",
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
                            if (_analysisInProgress ||
                                _analysisStatusText != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    if (_analysisInProgress)
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    if (_analysisInProgress)
                                      const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _analysisStatusText ?? 'Analysing…',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: themeProvider.isDarkMode
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

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
                                      color: BrandTokens.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(
                                          BrandTokens.cardRadius),
                                    ),
                                    child: Icon(
                                      Icons.assignment_outlined,
                                      color: BrandTokens.primary,
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

                                  // Filter Chips
                                  FilterChipGroup(
                                    options: [
                                      'All',
                                      'Excellent',
                                      'Good',
                                      'Needs Review'
                                    ],
                                    selectedValue: selectedFilter ?? 'All',
                                    onSelected: (value) {
                                      applyFilter(
                                          value == 'All' ? null : value);
                                    },
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

                                  return ThemedSurfaceCard(
                                    padding: EdgeInsets.zero,
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
                                                const SizedBox(height: 12),
                                                // Role & Screening
                                                Text(
                                                  review['requisition_title']
                                                          ?.toString() ??
                                                      '—',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: themeProvider
                                                            .isDarkMode
                                                        ? Colors.grey.shade400
                                                        : Colors.grey.shade700,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: (review['screening_outcome']
                                                                    ?.toString() ??
                                                                '')
                                                            .toLowerCase()
                                                            .contains('hold')
                                                        ? Colors.orange
                                                            .withValues(
                                                                alpha: 0.2)
                                                        : Colors.green
                                                            .withValues(
                                                                alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Text(
                                                    review['screening_outcome']
                                                            ?.toString() ??
                                                        'Screened',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: themeProvider
                                                              .isDarkMode
                                                          ? Colors.white70
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                TextButton.icon(
                                                  onPressed: () =>
                                                      _showMatchBreakdownDialog(
                                                          context,
                                                          review,
                                                          themeProvider),
                                                  icon: const Icon(
                                                      Icons.info_outline,
                                                      size: 14),
                                                  label: Text(
                                                    'Match breakdown',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
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
                                                                              BrandTokens.primary,
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
                                                  Column(
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
                                                              ? Colors
                                                                  .grey.shade400
                                                              : Colors.grey
                                                                  .shade700,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      ...workExp
                                                          .take(2)
                                                          .map<Widget>(
                                                            (exp) => Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      bottom:
                                                                          4),
                                                              child: Text(
                                                                "• ${exp['role'] ?? ''} at ${exp['company'] ?? ''}",
                                                                style:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontSize: 10,
                                                                  color: themeProvider.isDarkMode
                                                                      ? Colors
                                                                          .grey
                                                                          .shade500
                                                                      : Colors
                                                                          .grey
                                                                          .shade600,
                                                                ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                          ),
                                                    ],
                                                  ),
                                                const SizedBox(height: 12),

                                                // Preview CV button
                                                Align(
                                                  alignment:
                                                      Alignment.bottomRight,
                                                  child: Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    alignment:
                                                        WrapAlignment.end,
                                                    children: [
                                                      ElevatedButton.icon(
                                                        onPressed: () =>
                                                            _previewCV(review),
                                                        icon: const Icon(
                                                            Icons
                                                                .remove_red_eye,
                                                            size: 16),
                                                        label: const Text(
                                                            'Preview CV'),
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              BrandTokens
                                                                  .primary,
                                                          foregroundColor:
                                                              Colors.white,
                                                          minimumSize:
                                                              const Size(
                                                                  100, 36),
                                                          textStyle:
                                                              GoogleFonts.inter(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                      ElevatedButton.icon(
                                                        onPressed:
                                                            _analysisInProgress
                                                                ? null
                                                                : () =>
                                                                    _analyseCvForCandidate(
                                                                        review),
                                                        icon: const Icon(
                                                            Icons.auto_awesome,
                                                            size: 16),
                                                        label: const Text(
                                                            'Analyse CV'),
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              Colors.black87,
                                                          foregroundColor:
                                                              Colors.white,
                                                          minimumSize:
                                                              const Size(
                                                                  110, 36),
                                                          textStyle:
                                                              GoogleFonts.inter(
                                                            fontSize: 12,
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
