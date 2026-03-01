import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/candidate_service.dart';
import '../../utils/api_endpoints.dart';
import 'assessment_page.dart';
import 'cv_upload_page.dart';

/// Display status for UI. Backend status is mapped to one of these.
enum _DisplayStatus { inProgress, applied, interview, offer, rejected }

class JobsAppliedPage extends StatefulWidget {
  final String token;
  const JobsAppliedPage({super.key, required this.token});

  @override
  State<JobsAppliedPage> createState() => _JobsAppliedPageState();
}

class _JobsAppliedPageState extends State<JobsAppliedPage> {
  List<Map<String, dynamic>> applications = [];
  bool loading = true;
  int _selectedTabIndex = 0; // 0=All, 1=In Progress, 2=Offers, 3=Rejected
  Map<String, dynamic>? _drawerApplication;
  bool _drawerVisible = false;

  static const Color _accentRed = Color(0xFFC10D00);
  static const Color _cardDark = Color(0xFF252525);
  static const Color _borderLight = Color(0xFF3A3A3A);

  @override
  void initState() {
    super.initState();
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

  /// Map backend status to display status. If CV or assessment is missing → In progress. Otherwise Applied/Interview/Offer/Rejected.
  static _DisplayStatus _toDisplayStatus(Map<String, dynamic> app) {
    if (!_assessmentCompleted(app) || !_cvUploaded(app)) {
      return _DisplayStatus.inProgress;
    }
    final status = (app['status']?.toString() ?? '').toLowerCase();
    final interviewStatus = (app['interview_status']?.toString() ?? '').toLowerCase();
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
  bool _showInRejected(_DisplayStatus display) => display == _DisplayStatus.rejected;

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

  int _countApplied() => applications
      .where((a) => _showInAppliedTab(_toDisplayStatus(a)))
      .length;
  int _countOffers() => applications
      .where((a) => _showInOffers(_toDisplayStatus(a)))
      .length;
  int _countRejected() => applications
      .where((a) => _showInRejected(_toDisplayStatus(a)))
      .length;

  Future<void> _fetchApplications() async {
    setState(() => loading = true);
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
      if (mounted) setState(() => applications = trackable);
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
        return 'Rejected applications will appear here.';
      default:
        return 'Your applications will appear here.';
    }
  }

  String _dateApplied(Map<String, dynamic> app) {
    final created = app['created_at']?.toString();
    if (created != null && created.length >= 10) return created.substring(0, 10);
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
  Future<void> _previewCv(BuildContext context, Map<String, dynamic> app) async {
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
    final proxyUrl = '${ApiEndpoints.candidateBase}/applications/$applicationId/cv-preview?access_token=${Uri.encodeComponent(token)}';
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _CvPreviewDialog(
        url: proxyUrl,
        jobTitle: app['job_title']?.toString() ?? 'CV',
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
                context.go('/candidate-dashboard?token=${Uri.encodeComponent(token)}');
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
    final tabLabels = ['All', 'Applied', 'Offers', 'Rejected'];
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
              color: selected ? _accentRed : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => setState(() => _selectedTabIndex = i),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_accentRed),
        ),
      );
    }
    final rows = _filteredApplications;
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
        final tableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth - 24.0 : 800.0;
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Container(
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
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.06)),
              headingTextStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
              dataRowColor: WidgetStateProperty.resolveWith((states) {
                return Colors.transparent;
              }),
              dataTextStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
              border: TableBorder(
                horizontalInside: BorderSide(color: _borderLight, width: 1),
                verticalInside: BorderSide(color: _borderLight, width: 1),
              ),
              columnSpacing: 12,
              horizontalMargin: 8,
              columns: [
                DataColumn(
                  columnWidth: const FixedColumnWidth(28),
                  label: const Text('#'),
                ),
                DataColumn(
                  columnWidth: const FixedColumnWidth(100),
                  label: const Text('Job Title'),
                ),
                DataColumn(
                  columnWidth: const FixedColumnWidth(90),
                  label: const Text('Company'),
                ),
                DataColumn(
                  columnWidth: const FixedColumnWidth(100),
                  label: const Text('Date Applied'),
                ),
                DataColumn(
                  columnWidth: const FlexColumnWidth(1.0),
                  label: const Text('Application Status'),
                ),
                if (!_drawerVisible)
                  DataColumn(
                    columnWidth: const FlexColumnWidth(1.0),
                    label: const Text('Action'),
                  ),
              ],
              rows: List.generate(rows.length, (i) {
                final app = rows[i];
                final displayStatus = _toDisplayStatus(app);
                final cells = [
                  DataCell(Align(alignment: Alignment.centerLeft, child: Text('${i + 1}'))),
                  DataCell(Text(
                    app['job_title']?.toString() ?? '—',
                    overflow: TextOverflow.ellipsis,
                  )),
                DataCell(Text(
                  app['company']?.toString() ?? '—',
                  overflow: TextOverflow.ellipsis,
                )),
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _openDrawer(app),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        ),
                        child: Text(
                          'View Application',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
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
        label = 'Rejected';
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
                                          applicationId: app['application_id'] as int,
                                          draftData: app['draft_data'] is Map
                                              ? Map<String, dynamic>.from(app['draft_data'] as Map)
                                              : null,
                                        ),
                                      ),
                                    ).then((_) => _fetchApplications());
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CVUploadScreen(
                                          applicationId: app['application_id'] as int,
                                        ),
                                      ),
                                    ).then((_) => _fetchApplications());
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accentRed,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                                Icon(Icons.check_circle, size: 18, color: Colors.green.shade400),
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
                                  icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFFC10D00)),
                                  label: Text(
                                    'Preview',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFC10D00),
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
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
}

/// Full-screen in-app CV preview using backend proxy (avoids Cloudinary 401).
class _CvPreviewDialog extends StatefulWidget {
  final String url;
  final String jobTitle;
  final VoidCallback onClose;

  const _CvPreviewDialog({
    required this.url,
    required this.jobTitle,
    required this.onClose,
  });

  @override
  State<_CvPreviewDialog> createState() => _CvPreviewDialogState();
}

class _CvPreviewDialogState extends State<_CvPreviewDialog> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..loadRequest(Uri.parse(widget.url));
    if (!kIsWeb) {
      _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      _controller.setNavigationDelegate(
        NavigationDelegate(onPageFinished: (_) {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.85;
    final width = MediaQuery.of(context).size.width * 0.9;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: width.clamp(320.0, 900.0),
        height: height.clamp(400.0, 900.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a1a),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3A3A3A)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'CV Preview — ${widget.jobTitle}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: widget.onClose,
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF3A3A3A)),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: WebViewWidget(controller: _controller),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
