import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/app_state_manager.dart';
import '../../utils/api_endpoints.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/themed_surface_card.dart';
import '../../widgets/state_widgets.dart';
import 'candidate_detail_screen.dart';

class CandidateListScreen extends StatefulWidget {
  const CandidateListScreen({super.key});

  @override
  State<CandidateListScreen> createState() => _CandidateListScreenState();
}

class _CandidateListScreenState extends State<CandidateListScreen> {
  List<dynamic> candidates = [];
  bool loading = true;
  int? hoveredIndex;

  TextEditingController searchController = TextEditingController();
  int currentPage = 1;
  int totalPages = 1;
  int perPage = 12;
  String searchQuery = "";
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    fetchCandidates();
  }

  @override
  void dispose() {
    searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        searchQuery = query;
        currentPage = 1; // Reset to first page on new search
      });
      fetchCandidates(refresh: true);
    });
  }

  Future<void> fetchCandidates({bool refresh = false}) async {
    if (refresh) {
      // Clear existing data for fresh load
      if (mounted) {
        setState(() {
          candidates.clear();
          loading = true;
        });
      }
      appStateManager.clearCache('candidates');
    }

    try {
      // Use AppStateManager for cached fetching
      final data = await appStateManager.fetchWithCache(
        'candidates_p${currentPage}_q_$searchQuery',
        () async {
          final response = await AuthService.authorizedGet(
            "${ApiEndpoints.adminBase}/candidates/all?page=$currentPage&per_page=$perPage&search=$searchQuery",
          );

          if (response.statusCode != 200) {
            throw Exception(
                'Failed to load candidates: ${response.statusCode}');
          }

          final responseData = jsonDecode(response.body);
          return responseData;
        },
        forceRefresh: refresh,
      );

      if (mounted) {
        setState(() {
          candidates = data['candidates'] ?? [];
          totalPages = data['pages'] ?? 1;
          currentPage = data['current_page'] ?? 1;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);

        // Show appropriate error message
        String errorMessage = 'Error loading candidates';
        if (e.toString().contains('Network')) {
          errorMessage = 'Network error - please check your connection';
        } else if (e.toString().contains('401') ||
            e.toString().contains('token')) {
          errorMessage = 'Session expired - please login again';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$errorMessage: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => fetchCandidates(refresh: true),
            ),
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
          appBar: AppBar(
            title: Text(
              "Candidate Directory",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  controller: searchController,
                  onChanged: _onSearchChanged,
                  style: GoogleFonts.poppins(
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: "Search by name, email, location...",
                    hintStyle: GoogleFonts.poppins(
                      color: themeProvider.isDarkMode
                          ? Colors.white54
                          : Colors.black54,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              searchController.clear();
                              _onSearchChanged("");
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: (themeProvider.isDarkMode
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            backgroundColor: (themeProvider.isDarkMode
                    ? const Color(0xFF14131E)
                    : Colors.white)
                .withOpacity(0.95),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => fetchCandidates(refresh: true),
                tooltip: 'Refresh candidates',
              ),
            ],
            foregroundColor:
                themeProvider.isDarkMode ? Colors.white : Colors.black87,
            iconTheme: IconThemeData(
                color:
                    themeProvider.isDarkMode ? Colors.white : Colors.black87),
          ),
          body: RefreshIndicator(
            onRefresh: () => fetchCandidates(refresh: true),
            child: loading
                ? const ThemedLoadingState(
                    message: "Loading Candidates...",
                  )
                : candidates.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 80,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No Candidates Found",
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
                              "Candidates will appear here once they register",
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
                        children: [
                          // Header with stats
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: ThemedStatCard(
                              title: "Candidate Directory",
                              value: "${candidates.length}",
                              icon: Icons.people_alt,
                              iconColor: Colors.redAccent,
                            ),
                          ),
                          // Candidates Grid
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                int cardsPerRow = 1;
                                double width = constraints.maxWidth;

                                if (width >= 1200) {
                                  cardsPerRow = 3;
                                } else if (width >= 800) {
                                  cardsPerRow = 2;
                                }

                                double cardWidth =
                                    (width - (20 * (cardsPerRow + 1))) /
                                        cardsPerRow;

                                return SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: Wrap(
                                    spacing: 20,
                                    runSpacing: 20,
                                    children:
                                        candidates.asMap().entries.map((entry) {
                                      int index = entry.key;
                                      var c = entry.value;

                                      bool isHovered = hoveredIndex == index;

                                      return MouseRegion(
                                        onEnter: kIsWeb
                                            ? (_) => setState(
                                                () => hoveredIndex = index)
                                            : null,
                                        onExit: kIsWeb
                                            ? (_) => setState(
                                                () => hoveredIndex = null)
                                            : null,
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          transform: isHovered
                                              ? (Matrix4.identity()
                                                ..translateByVector3(
                                                    vm.Vector3(0, -8, 0)))
                                              : Matrix4.identity(),
                                          width: cardWidth,
                                          child: ThemedSurfaceCard(
                                            padding: EdgeInsets.zero,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Header with avatar
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(20),
                                                  decoration: BoxDecoration(
                                                    color: Colors.redAccent
                                                        .withValues(
                                                            alpha: 0.03),
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(20),
                                                      topRight:
                                                          Radius.circular(20),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Stack(
                                                        children: [
                                                          Container(
                                                            width: 60,
                                                            height: 60,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors
                                                                  .redAccent
                                                                  .withValues(
                                                                      alpha:
                                                                          0.1),
                                                              shape: BoxShape
                                                                  .circle,
                                                              border:
                                                                  Border.all(
                                                                color: Colors
                                                                    .redAccent
                                                                    .withValues(
                                                                        alpha:
                                                                            0.2),
                                                                width: 2,
                                                              ),
                                                            ),
                                                            child:
                                                                c['profile_picture'] !=
                                                                        null
                                                                    ? ClipOval(
                                                                        child: Image
                                                                            .network(
                                                                          c['profile_picture'],
                                                                          width:
                                                                              60,
                                                                          height:
                                                                              60,
                                                                          fit: BoxFit
                                                                              .cover,
                                                                        ),
                                                                      )
                                                                    : Icon(
                                                                        Icons
                                                                            .person,
                                                                        size:
                                                                            30,
                                                                        color: Colors
                                                                            .redAccent
                                                                            .withValues(alpha: 0.6),
                                                                      ),
                                                          ),
                                                          Positioned(
                                                            bottom: 0,
                                                            right: 0,
                                                            child: Container(
                                                              width: 16,
                                                              height: 16,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .green,
                                                                shape: BoxShape
                                                                    .circle,
                                                                border:
                                                                    Border.all(
                                                                  color: Colors
                                                                      .white,
                                                                  width: 2,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(width: 16),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              c['full_name'] ??
                                                                  'Unknown Candidate',
                                                              style: GoogleFonts
                                                                  .inter(
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: themeProvider
                                                                        .isDarkMode
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .black87,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                            const SizedBox(
                                                                height: 4),
                                                            Text(
                                                              c['email'] ??
                                                                  'No email provided',
                                                              style: GoogleFonts
                                                                  .inter(
                                                                color: themeProvider.isDarkMode
                                                                    ? Colors
                                                                        .grey
                                                                        .shade400
                                                                    : Colors
                                                                        .grey
                                                                        .shade600,
                                                                fontSize: 12,
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
                                                // Details section
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(20),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      _buildInfoRow(
                                                        icon: Icons.phone,
                                                        label: "Phone",
                                                        value:
                                                            c['phone'] ?? 'N/A',
                                                        themeProvider:
                                                            themeProvider,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      _buildInfoRow(
                                                        icon: Icons.location_on,
                                                        label: "Location",
                                                        value: c['location'] ??
                                                            'N/A',
                                                        themeProvider:
                                                            themeProvider,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      _buildInfoRow(
                                                        icon: Icons.female,
                                                        label: "Gender",
                                                        value: c['gender'] ??
                                                            'N/A',
                                                        themeProvider:
                                                            themeProvider,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      _buildInfoRow(
                                                        icon: Icons.badge,
                                                        label: "ID Number",
                                                        value: c['id_number'] ??
                                                            'N/A',
                                                        themeProvider:
                                                            themeProvider,
                                                      ),
                                                      if (c['applications_summary'] !=
                                                              null &&
                                                          (c['applications_summary']
                                                                  as List)
                                                              .isNotEmpty) ...[
                                                        const SizedBox(
                                                            height: 8),
                                                        _buildInfoRow(
                                                          icon: Icons.work,
                                                          label: "Jobs applied",
                                                          value:
                                                              "${(c['applications_summary'] as List).length} job(s): ${(c['applications_summary'] as List).map((a) => a is Map ? (a['job_title'] ?? '') : '').where((s) => s.isNotEmpty).take(3).join(', ')}${(c['applications_summary'] as List).length > 3 ? '...' : ''}",
                                                          themeProvider:
                                                              themeProvider,
                                                        ),
                                                      ],
                                                      const SizedBox(
                                                          height: 16),
                                                      // Action buttons
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: Colors
                                                                        .blue
                                                                        .withValues(
                                                                            alpha:
                                                                                0.3),
                                                                    blurRadius:
                                                                        8,
                                                                    offset:
                                                                        const Offset(
                                                                            0,
                                                                            4),
                                                                  ),
                                                                ],
                                                              ),
                                                              child:
                                                                  ElevatedButton
                                                                      .icon(
                                                                icon: const Icon(
                                                                    Icons
                                                                        .visibility,
                                                                    size: 16),
                                                                label: Text(
                                                                  "View Profile",
                                                                  style:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                                onPressed: () {
                                                                  final summary =
                                                                      c['applications_summary']
                                                                          as List?;
                                                                  final firstAppId = summary !=
                                                                              null &&
                                                                          summary
                                                                              .isNotEmpty &&
                                                                          summary.first
                                                                              is Map
                                                                      ? (summary
                                                                              .first
                                                                          as Map)['application_id']
                                                                      : null;
                                                                  if (firstAppId !=
                                                                      null) {
                                                                    Navigator.of(
                                                                            context)
                                                                        .push(
                                                                      MaterialPageRoute(
                                                                        builder:
                                                                            (_) =>
                                                                                CandidateDetailScreen(
                                                                          candidateId:
                                                                              c['id'] as int,
                                                                          applicationId:
                                                                              firstAppId as int,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  } else {
                                                                    ScaffoldMessenger.of(
                                                                            context)
                                                                        .showSnackBar(
                                                                      const SnackBar(
                                                                          content:
                                                                              Text('No applications yet')),
                                                                    );
                                                                  }
                                                                },
                                                                style: ElevatedButton
                                                                    .styleFrom(
                                                                  backgroundColor:
                                                                      Colors
                                                                          .blue,
                                                                  foregroundColor:
                                                                      Colors
                                                                          .white,
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          12),
                                                                  shape:
                                                                      RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            12),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors
                                                                      .redAccent
                                                                      .withValues(
                                                                          alpha:
                                                                              0.3),
                                                                  blurRadius: 8,
                                                                  offset:
                                                                      const Offset(
                                                                          0, 4),
                                                                ),
                                                              ],
                                                            ),
                                                            child: IconButton(
                                                              onPressed: () {},
                                                              icon: const Icon(
                                                                  Icons
                                                                      .more_vert,
                                                                  color: Colors
                                                                      .white),
                                                              style: IconButton
                                                                  .styleFrom(
                                                                backgroundColor:
                                                                    Colors
                                                                        .redAccent,
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        12),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Pagination Controls
                          if (totalPages > 1)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildPageButton(
                                    icon: Icons.chevron_left,
                                    enabled: currentPage > 1,
                                    onPressed: () {
                                      setState(() => currentPage--);
                                      fetchCandidates(refresh: true);
                                    },
                                    themeProvider: themeProvider,
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    "Page $currentPage of $totalPages",
                                    style: GoogleFonts.poppins(
                                      color: themeProvider.isDarkMode
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  _buildPageButton(
                                    icon: Icons.chevron_right,
                                    enabled: currentPage < totalPages,
                                    onPressed: () {
                                      setState(() => currentPage++);
                                      fetchCandidates(refresh: true);
                                    },
                                    themeProvider: themeProvider,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
    required ThemeProvider themeProvider,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: enabled
                ? (themeProvider.isDarkMode
                    ? Colors.white12
                    : Colors.black.withValues(alpha: 0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled
                  ? (themeProvider.isDarkMode ? Colors.white24 : Colors.black12)
                  : Colors.transparent,
            ),
          ),
          child: Icon(
            icon,
            color: enabled
                ? (themeProvider.isDarkMode ? Colors.white : Colors.black87)
                : (themeProvider.isDarkMode ? Colors.white24 : Colors.black12),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeProvider themeProvider,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: themeProvider.isDarkMode
              ? Colors.grey.shade400
              : Colors.grey.shade500,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  color:
                      themeProvider.isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
