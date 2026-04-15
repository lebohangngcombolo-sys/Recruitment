import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/candidate_service.dart';
import '../../utils/api_endpoints.dart';
import '../../widgets/cv_preview_dialog.dart';
import 'assessment_page.dart';
import 'cv_upload_page.dart';

/// Display status for UI. Backend status is mapped to one of these.
enum _DisplayStatus { inProgress, applied, interview, offer, rejected }

class JobsAppliedPage extends StatefulWidget {
  final String token;
  final List<Map<String, dynamic>>? initialApplications;
  const JobsAppliedPage({
    super.key,
    required this.token,
    this.initialApplications,
  });

  @override
  State<JobsAppliedPage> createState() => _JobsAppliedPageState();
}

class _JobsAppliedPageState extends State<JobsAppliedPage> {
  static List<Map<String, dynamic>>? _cachedTrackableApplications;
  List<Map<String, dynamic>> applications = [];
  bool loading = true;
  int _selectedTabIndex = 0; // 0=All, 1=In Progress, 2=Offers, 3=Unsuccessful
  int _currentPage = 0;
  Map<String, dynamic>? _drawerApplication;
  bool _drawerVisible = false;
  static const int _rowsPerPage = 7;

  static const Color _accentRed = Color(0xFFC10D00);
  static const Color _actionBlue = Color(0xFF6EA8FE);
  static const Color _cardDark = Color(0xFF252525);
  static const Color _borderLight = Color(0xFF3A3A3A);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialApplications;
    if (initial != null && initial.isNotEmpty) {
      applications = List<Map<String, dynamic>>.from(initial);
      loading = false;
      _cachedTrackableApplications = List<Map<String, dynamic>>.from(initial);
    }
    final cached = _cachedTrackableApplications;
    if ((initial == null || initial.isEmpty) &&
        cached != null &&
        cached.isNotEmpty) {
      applications = List<Map<String, dynamic>>.from(cached);
      loading = false;
    }
    _fetchApplications();
  }

  /// Include applications that are submitted or completed (same as dashboard "My applications").
  static bool _isTrackableApplication(dynamic app) {
    final raw = app is Map ? app['status']?.toString() : null;
    final status = raw?.toLowerCase().trim();
    if (status == null || status.isEmpty) return false;
    return status == 'applied' ||
        status == 'assessment_submitted' ||
        status == 'disqualified' ||
        status.contains('offer');
  }

  /// Map backend status to display status. If CV or assessment is missing → In progress. Otherwise Applied/Interview/Offer/Unsuccessful.
  static _DisplayStatus _toDisplayStatus(Map<String, dynamic> app) {
    if (!_assessmentCompleted(app) || !_cvUploaded(app)) {
      return _DisplayStatus.inProgress;
    }
    final status = (app['status']?.toString() ?? '').toLowerCase();
    final interviewStatus =
        (app['interview_status']?.toString() ?? '').toLowerCase();
    if (status == 'disqualified') return _DisplayStatus.rejected;
    if (status.contains('offer')) return _DisplayStatus.offer;
    if (status == 'assessment_submitted' && interviewStatus == 'scheduled') {
      return _DisplayStatus.interview;
    }
    return _DisplayStatus.applied;
  }

  /// Applied tab shows only complete applications (have CV + assessment, status Applied or Interview).
  bool _showInAppliedTab(_DisplayStatus display) =>
      display == _DisplayStatus.applied || display == _DisplayStatus.interview;
  bool _showInOffers(_DisplayStatus display) => display == _DisplayStatus.offer;
  bool _showInRejected(_DisplayStatus display) =>
      display == _DisplayStatus.rejected;

  List<Map<String, dynamic>> get _filteredApplications {
    if (applications.isEmpty) return [];
    switch (_selectedTabIndex) {
      case 1:
        return applications
            .where((a) => _showInAppliedTab(_toDisplayStatus(a)))
            .toList();
      case 2:
        return applications
            .where((a) => _showInOffers(_toDisplayStatus(a)))
            .toList();
      case 3:
        return applications
            .where((a) => _showInRejected(_toDisplayStatus(a)))
            .toList();
      default:
        return applications;
    }
  }

  int _countApplied() =>
      applications.where((a) => _showInAppliedTab(_toDisplayStatus(a))).length;
  int _countOffers() =>
      applications.where((a) => _showInOffers(_toDisplayStatus(a))).length;
  int _countRejected() =>
      applications.where((a) => _showInRejected(_toDisplayStatus(a))).length;

  Future<void> _fetchApplications() async {
    setState(() => loading = true);
    final role = await AuthService.getRole();
    if (role != 'candidate') {
      if (mounted) setState(() => loading = false);
      return;
    }
    try {
      // Use current token from storage so we don't use a stale token from the dashboard URL
      final token = await AuthService.getAccessToken() ?? widget.token;
      if (token.isEmpty && mounted) {
        setState(() => applications = []);
        return;
      }
      final apps = await CandidateService.getApplications(token);
      final list = List<dynamic>.from(apps);
      final trackable = list
          .where(_isTrackableApplication)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) {
        setState(() {
          applications = trackable;
          _currentPage = 0;
        });
      }
      _cachedTrackableApplications = List<Map<String, dynamic>>.from(trackable);
    } catch (e) {
      debugPrint("Error fetching applications: $e");
      if (mounted) setState(() => applications = []);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _openDrawer(Map<String, dynamic> app) {
    setState(() {
      _drawerApplication = app;
      _drawerVisible = true;
    });
  }

  void _closeDrawer() {
    setState(() {
      _drawerVisible = false;
      _drawerApplication = null;
    });
  }

  String _emptyStateTitle() {
    switch (_selectedTabIndex) {
      case 0:
        return 'No applications yet';
      case 1:
        return 'No applied applications';
      case 2:
        return 'No offers yet';
      case 3:
        return 'No rejected applications';
      default:
        return 'No applications in this category';
    }
  }

  String _emptyStateSubtitle() {
    switch (_selectedTabIndex) {
      case 0:
        return 'Your applications will appear here.';
      case 1:
        return 'Complete applications (CV + assessment) will appear here.';
      case 2:
        return 'Offers will appear here when you receive them.';
      case 3:
        return 'Unsuccessful applications will appear here.';
      default:
        return 'Your applications will appear here.';
    }
  }

  String _dateApplied(Map<String, dynamic> app) {
    final created = app['created_at']?.toString();
    if (created != null && created.length >= 10)
      return created.substring(0, 10);
    final saved = app['saved_at']?.toString();
    if (saved != null && saved.length >= 10) return saved.substring(0, 10);
    return '—';
  }

  static bool _assessmentCompleted(Map<String, dynamic> app) {
    final status = app['status']?.toString() ?? '';
    if (status == 'assessment_submitted') return true;
    final result = app['assessment_result'];
    return result != null && result is Map && result.isNotEmpty;
  }

  static bool _cvUploaded(Map<String, dynamic> app) {
    final url = app['resume_url']?.toString();
    return url != null && url.trim().isNotEmpty;
  }

  /// Shows CV in-app via backend proxy (avoids 401 and opens inside the app).
  Future<void> _previewCv(
      BuildContext context, Map<String, dynamic> app) async {
    if (!_cvUploaded(app)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CV link not available')),
        );
      }
      return;
    }
    final applicationId = app['application_id'];
    if (applicationId == null) return;
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in again to preview CV')),
        );
      }
      return;
    }
    final proxyUrl =
        '${ApiEndpoints.candidateBase}/applications/$applicationId/cv-preview?access_token=${Uri.encodeComponent(token)}';
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => CvPreviewDialog(
        url: proxyUrl,
        title: 'CV Preview — ${app['job_title']?.toString() ?? 'CV'}',
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/dark.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                _buildTabs(),
                Expanded(child: _buildContent()),
              ],
            ),
            if (_drawerVisible && _drawerApplication != null)
              _buildRightDrawer(_drawerApplication!),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () async {
              if (context.canPop()) {
                context.pop();
              } else {
                final token = widget.token.isNotEmpty
                    ? widget.token
                    : (await AuthService.getAccessToken() ?? '');
                if (!context.mounted) return;
                context.go(
                    '/candidate-dashboard?token=${Uri.encodeComponent(token)}');
              }
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "Job Application Tracker",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
            onPressed: loading ? null : _fetchApplications,
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabLabels = ['All', 'Applied', 'Offers', 'Unsuccessful'];
    final tabCounts = [
      applications.length,
      _countApplied(),
      _countOffers(),
      _countRejected(),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: List.generate(4, (i) {
          final selected = _selectedTabIndex == i;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color:
                  selected ? _accentRed : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => setState(() {
                  _selectedTabIndex = i;
                  _currentPage = 0;
                }),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? _accentRed : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tabLabels[i],
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${tabCounts[i]}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildContent() {
    if (loading && applications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_accentRed),
        ),
      );
    }
    final rows = _filteredApplications;
    final totalPages =
        rows.isEmpty ? 1 : ((rows.length + _rowsPerPage - 1) ~/ _rowsPerPage);
    if (_currentPage >= totalPages) {
      _currentPage = totalPages - 1;
    }
    final start = _currentPage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, rows.length);
    final visibleRows = rows.sublist(start, end);
    if (rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_off_outlined, size: 56, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              _emptyStateTitle(),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _emptyStateSubtitle(),
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white54),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth - 24.0
            : 1100.0;
        final hasActionColumn = !_drawerVisible;
        final minRequiredWidth = hasActionColumn ? 920.0 : 760.0;
        final effectiveWidth =
            tableWidth < minRequiredWidth ? minRequiredWidth : tableWidth;
        const indexColWidth = 40.0;
        final contentWidth = effectiveWidth - indexColWidth;

        // Enterprise-like proportional sizing so the table fills the full area.
        final jobTitleWidth =
            hasActionColumn ? contentWidth * 0.28 : contentWidth * 0.34;
        final companyWidth =
            hasActionColumn ? contentWidth * 0.22 : contentWidth * 0.26;
        final dateWidth =
            hasActionColumn ? contentWidth * 0.17 : contentWidth * 0.20;
        final statusWidth =
            hasActionColumn ? contentWidth * 0.18 : contentWidth * 0.20;
        final actionWidth = hasActionColumn
            ? contentWidth -
                (jobTitleWidth + companyWidth + dateWidth + statusWidth)
            : 0.0;

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            children: [
              Container(
                width: tableWidth,
                decoration: BoxDecoration(
                  color: _cardDark.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderLight, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: effectiveWidth,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                          Colors.white.withValues(alpha: 0.06)),
                      headingTextStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                      dataRowColor: WidgetStateProperty.resolveWith((states) {
                        return Colors.transparent;
                      }),
                      dataTextStyle: GoogleFonts.poppins(
                          fontSize: 14, color: Colors.white),
                      dataRowMinHeight: 44,
                      dataRowMaxHeight: 50,
                      border: TableBorder(
                        horizontalInside:
                            BorderSide(color: _borderLight, width: 1),
                        verticalInside:
                            BorderSide(color: _borderLight, width: 1),
                      ),
                      columnSpacing: 8,
                      horizontalMargin: 8,
                      columns: [
                        DataColumn(
                          columnWidth: const FixedColumnWidth(indexColWidth),
                          label: const Text('#'),
                        ),
                        DataColumn(
                          columnWidth: FixedColumnWidth(jobTitleWidth),
                          label: const Text('Job Title'),
                        ),
                        DataColumn(
                          columnWidth: FixedColumnWidth(companyWidth),
                          label: const Text('Company'),
                        ),
                        DataColumn(
                          columnWidth: FixedColumnWidth(dateWidth),
                          label: const Text('Date Applied'),
                        ),
                        DataColumn(
                          columnWidth: FixedColumnWidth(statusWidth),
                          label: const Text('Application Status'),
                        ),
                        if (!_drawerVisible)
                          DataColumn(
                            columnWidth: FixedColumnWidth(actionWidth),
                            label: const Text('Action'),
                          ),
                      ],
                      rows: List.generate(visibleRows.length, (i) {
                        final app = visibleRows[i];
                        final displayStatus = _toDisplayStatus(app);
                        final jobTitle = app['job_title']?.toString() ?? '—';
                        final company = app['company']?.toString() ?? '—';
                        final cells = [
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('${start + i + 1}'),
                            ),
                          ),
                          DataCell(
                            Tooltip(
                              message: jobTitle,
                              child: Text(
                                jobTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Tooltip(
                              message: company,
                              child: Text(
                                company,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text(_dateApplied(app))),
                          DataCell(
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: _buildStatusPill(displayStatus),
                            ),
                          ),
                        ];
                        if (!_drawerVisible) {
                          cells.add(
                            DataCell(
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () => _openDrawer(app),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                  ),
                                  child: Text(
                                    'View Application',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return DataRow(cells: cells);
                      }),
                    ),
                  ),
                ),
              ),
              if (rows.length > _rowsPerPage) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: tableWidth,
                  child: Row(
                    children: [
                      Text(
                        'Showing ${start + 1}-${end} of ${rows.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: _currentPage > 0
                            ? () => setState(() => _currentPage--)
                            : null,
                        icon: const Icon(Icons.chevron_left, size: 18),
                        label: Text(
                          'Previous',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: _currentPage > 0
                                ? Colors.white30
                                : Colors.white12,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_currentPage + 1} / $totalPages',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _currentPage < totalPages - 1
                            ? () => setState(() => _currentPage++)
                            : null,
                        icon: const Icon(Icons.chevron_right, size: 18),
                        iconAlignment: IconAlignment.end,
                        label: Text(
                          'Next',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: _currentPage < totalPages - 1
                                ? Colors.white30
                                : Colors.white12,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusPill(_DisplayStatus status) {
    String label;
    Color bg;
    switch (status) {
      case _DisplayStatus.inProgress:
        label = 'In progress';
        bg = Colors.grey.shade700.withValues(alpha: 0.4);
        break;
      case _DisplayStatus.applied:
        label = 'Applied';
        bg = Colors.amber.shade700.withValues(alpha: 0.25);
        break;
      case _DisplayStatus.interview:
        label = 'Interview';
        bg = Colors.blue.shade700.withValues(alpha: 0.25);
        break;
      case _DisplayStatus.offer:
        label = 'Offer';
        bg = Colors.green.shade700.withValues(alpha: 0.25);
        break;
      case _DisplayStatus.rejected:
        label = 'Unsuccessful';
        bg = Colors.red.shade700.withValues(alpha: 0.25);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildRightDrawer(Map<String, dynamic> app) {
    final displayStatus = _toDisplayStatus(app);
    final assessmentDone = _assessmentCompleted(app);
    final cvDone = _cvUploaded(app);
    final showAssessmentButton = !assessmentDone;
    final showCvButton = !cvDone;
    final singleAction = showAssessmentButton
        ? 'Continue Assessment'
        : (showCvButton ? 'Upload CV' : null);

    return Stack(
      children: [
        GestureDetector(
          onTap: _closeDrawer,
          child: Container(
            color: Colors.black54,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: MediaQuery.of(context).size.width * 0.38,
          child: Material(
            elevation: 16,
            shadowColor: Colors.black54,
            child: Container(
              decoration: BoxDecoration(
                color: _cardDark,
                border: Border(left: BorderSide(color: _borderLight)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(-4, 0),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDrawerHeader(app),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _drawerSectionTitle('Application Status'),
                          const SizedBox(height: 8),
                          _buildStatusPill(displayStatus),
                          if (displayStatus == _DisplayStatus.interview) ...[
                            _buildScheduledInterviewInfo(app),
                          ],
                          if (displayStatus == _DisplayStatus.rejected) ...[
                            const SizedBox(height: 20),
                            _buildUnsuccessfulExplanation(app),
                          ],
                          if (displayStatus != _DisplayStatus.rejected) ...[
                            const SizedBox(height: 24),
                            _drawerSectionTitle('Application Requirements'),
                            const SizedBox(height: 12),
                            _requirementRow('Assessment', assessmentDone),
                            const SizedBox(height: 10),
                            _requirementRow('CV Upload', cvDone),
                            if (singleAction != null) ...[
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    _closeDrawer();
                                    if (singleAction == 'Continue Assessment') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AssessmentPage(
                                            applicationId:
                                                app['application_id'] as int,
                                            draftData: app['draft_data'] is Map
                                                ? Map<String, dynamic>.from(
                                                    app['draft_data'] as Map)
                                                : null,
                                          ),
                                        ),
                                      ).then((_) => _fetchApplications());
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CVUploadScreen(
                                            applicationId:
                                                app['application_id'] as int,
                                          ),
                                        ),
                                      ).then((_) => _fetchApplications());
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _accentRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    singleAction,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (_cvUploaded(app)) ...[
                              const SizedBox(height: 24),
                              _drawerSectionTitle('Documents'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 18, color: Colors.green.shade400),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'CV uploaded',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _previewCv(context, app),
                                    icon: Icon(
                                      Icons.visibility_outlined,
                                      size: 18,
                                      color: _actionBlue,
                                    ),
                                    label: Text(
                                      'Preview',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _actionBlue,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      backgroundColor:
                                          _actionBlue.withValues(alpha: 0.10),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (app['cv_analysis'] != null) ...[
                              const SizedBox(height: 24),
                              _buildCVAnalysisSection(app['cv_analysis']),
                            ],
                          ],
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
    );
  }

  /// Shows date, time and type when the Hiring Manager has scheduled an interview (Interview tab).
  Widget _buildScheduledInterviewInfo(Map<String, dynamic> app) {
    final scheduled = app['scheduled_interview'];
    if (scheduled is! Map) return const SizedBox.shrink();
    final timeStr = scheduled['scheduled_time']?.toString();
    final type = scheduled['interview_type']?.toString() ?? 'Interview';
    final meetingLink = scheduled['meeting_link']?.toString().trim();
    String dateLabel = 'Scheduled';
    if (timeStr != null && timeStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(timeStr);
        dateLabel =
            '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        dateLabel = timeStr;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade900.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: Colors.blue.shade700.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_available,
                    size: 18, color: Colors.blue.shade300),
                const SizedBox(width: 8),
                Text(
                  'Interview scheduled',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$type — $dateLabel',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
            ),
            if (meetingLink != null && meetingLink.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                meetingLink,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.blue.shade300),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(Map<String, dynamic> app) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _borderLight)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app['job_title']?.toString() ?? '—',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  app['company']?.toString() ?? '—',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Applied: ${_dateApplied(app)}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: _closeDrawer,
          ),
        ],
      ),
    );
  }

  /// Shown in the drawer when application status is Unsuccessful. Explains why in a supportive way.
  Widget _buildUnsuccessfulExplanation(Map<String, dynamic> app) {
    final recommendation = app['recommendation']?.toString().trim();
    final violations = app['knockout_rule_violations'];
    final hasViolations = violations is List && violations.isNotEmpty;
    final recLower = recommendation?.toLowerCase() ?? '';
    final isInternalCode = recLower == 'pass' ||
        recLower == 'fail' ||
        recLower == 'moderate' ||
        recLower == 'strong_hire' ||
        recLower == 'hire' ||
        recLower == 'no_hire' ||
        recLower == 'strong_no_hire' ||
        recLower == 'not_sure';
    final hasCandidateFriendlyRecommendation = recommendation != null &&
        recommendation.isNotEmpty &&
        recommendation.length > 2 &&
        recommendation.length < 200 &&
        !isInternalCode;

    String message;
    if (hasCandidateFriendlyRecommendation) {
      message = recommendation;
    } else if (recLower == 'fail') {
      message =
          'After review, this application did not meet the requirements for this role. '
          'We encourage you to apply for other positions that match your skills and experience.';
    } else if (hasViolations) {
      message =
          'This role had specific requirements that were not met on this occasion. '
          'We encourage you to apply for other positions that match your skills and experience.';
    } else {
      message = 'This application was not successful on this occasion. '
          'We encourage you to apply for other roles that match your experience.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why wasn\'t I successful?',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white70,
      ),
    );
  }

  Widget _requirementRow(String label, bool completed) {
    return Row(
      children: [
        Icon(
          completed ? Icons.check_circle : Icons.cancel_outlined,
          size: 20,
          color: completed ? Colors.green.shade400 : Colors.grey.shade500,
        ),
        const SizedBox(width: 10),
        Text(
          '$label: ${completed ? "Completed" : (label == "CV Upload" ? "Missing" : "Incomplete")}',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: completed ? Colors.white : Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildCVAnalysisSection(Map<String, dynamic> analysis) {
    final status = analysis['status']?.toString() ?? 'pending';
    final result = analysis['result'] is Map
        ? analysis['result'] as Map<String, dynamic>
        : {};
    final advice = result['advice'] ??
        result['feedback'] ??
        result['analysis_summary'] ??
        '';
    final score = analysis['overall_score'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber.shade300, size: 18),
              const SizedBox(width: 8),
              Text(
                'AI CV Feedback & Advice',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade300,
                ),
              ),
              const Spacer(),
              if (status == 'completed')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(score * 10).toStringAsFixed(0)}/10',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade300,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (status == 'processing' || status == 'pending')
            Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Analysis in progress...',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.white60,
                  ),
                ),
              ],
            )
          else if (status == 'failed')
            Text(
              'Analysis failed or not available for this CV.',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
            )
          else ...[
            Text(
              advice.isEmpty
                  ? 'Your CV has been successfully processed against this job description.'
                  : advice,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            if (result['strengths'] != null &&
                (result['strengths'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Key Strengths:',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: (result['strengths'] as List)
                    .map((s) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            s.toString(),
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: Colors.blue.shade200),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Full-screen in-app CV preview using backend proxy (avoids Cloudinary 401).
