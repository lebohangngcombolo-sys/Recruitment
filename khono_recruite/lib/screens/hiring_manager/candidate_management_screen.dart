import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart';
import '../../widgets/custom_button.dart';
import 'analytics_export_stub.dart' if (dart.library.html) 'analytics_export_web.dart' as analytics_export;
import 'candidate_detail_screen.dart';

class CandidateManagementScreen extends StatefulWidget {
  final int jobId;

  const CandidateManagementScreen({super.key, required this.jobId});

  @override
  _CandidateManagementScreenState createState() =>
      _CandidateManagementScreenState();
}

class _CandidateManagementScreenState extends State<CandidateManagementScreen> {
  final AdminService admin = AdminService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> candidates = [];
  bool loading = true;
  String? statusMessage;
  String _statusFilter = 'all';
  String? _jobFilter;
  bool _isExportingShortlist = false;
  bool _isExportingCsv = false;

  static const List<String> _statusOptions = [
    'all', 'screening', 'assessment', 'interview', 'offer', 'hired', 'rejected',
  ];

  static const List<String> _recommendationOptions = [
    'Proceed to Final Interview',
    'Hold',
    'Reject',
  ];

  @override
  void initState() {
    super.initState();
    fetchShortlist();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filteredCandidates() {
    var list = candidates;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      final words = query.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
      list = list.where((c) {
        final name = (c['full_name'] ?? c['name'] ?? '').toString().toLowerCase();
        final email = (c['email'] ?? '').toString().toLowerCase();
        final job = (c['job_title'] ?? '').toString().toLowerCase();
        final s = '$name $email $job';
        return words.every((w) => s.contains(w));
      }).toList();
    }
    if (_statusFilter != 'all') {
      list = list.where((c) => (c['status'] ?? '').toString().toLowerCase() == _statusFilter).toList();
    }
    if (_jobFilter != null && _jobFilter!.isNotEmpty) {
      list = list.where((c) => (c['job_title'] ?? '').toString() == _jobFilter).toList();
    }
    return list;
  }

  List<String> get _jobTitleOptions {
    final titles = <String>{};
    for (final c in candidates) {
      final t = (c['job_title'] ?? '').toString();
      if (t.isNotEmpty) titles.add(t);
    }
    return ['All jobs', ...titles.toList()..sort()];
  }

  Future<void> fetchShortlist() async {
    setState(() {
      loading = true;
      statusMessage = null;
    });

    try {
      List<dynamic> rawApplications;
      if (widget.jobId <= 0) {
        rawApplications = await admin.getAllApplicationsForMyJobs();
      } else {
        rawApplications = await admin.shortlistCandidates(widget.jobId);
      }

      final fetched = (rawApplications).map<Map<String, dynamic>>((dynamic app) {
        final map = Map<String, dynamic>.from(app as Map);
        final candidateData = (map['candidate'] is Map)
            ? Map<String, dynamic>.from(map['candidate'] as Map)
            : {};
        return {
          'application_id': map['application_id'] ?? map['id'],
          'candidate_id': candidateData['id'] ?? map['candidate_id'],
          'full_name': candidateData['full_name'] ??
              candidateData['name'] ??
              map['full_name'],
          'email': candidateData['email'] ?? map['email'],
          'phone': candidateData['phone'] ?? map['phone'],
          'status': map['status'],
          'cv_score': map['cv_score'] ?? map['overall_score'] ?? 0,
          'assessment_score': map['assessment_score'] ?? 0,
          'overall_score': map['overall_score'] ??
              (map['scoring_breakdown']?['overall'] ?? 0),
          'job_title': map['job_title'],
          'job_id': map['job_id'],
          'cv_parser_result': map['cv_parser_result'] ?? {},
          'candidate': candidateData,
          'recommendation': map['recommendation'],
        };
      }).toList();

      fetched.sort((a, b) {
        final aScore = (a['overall_score'] ?? 0).toDouble();
        final bScore = (b['overall_score'] ?? 0).toDouble();
        return bScore.compareTo(aScore);
      });

      if (!mounted) return;
      setState(() {
        candidates = fetched;
        statusMessage = fetched.isEmpty
            ? (widget.jobId <= 0
                ? "No candidates have applied to your jobs yet."
                : "No candidates have applied to this job yet.")
            : null;
      });
    } catch (e) {
      debugPrint("Error fetching candidates: $e");
      if (!mounted) return;
      setState(() {
        candidates = [];
        statusMessage = "Failed to load candidates: $e";
      });
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<Uint8List?> _buildShortlistPdf() async {
    final list = _filteredCandidates();
    Uint8List headerBytes;
    Uint8List footerBytes;
    try {
      headerBytes = (await rootBundle.load('assets/images/logo2.png')).buffer.asUint8List();
      footerBytes = (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load logo images: $e')),
        );
      }
      return null;
    }
    final headerImage = pw.MemoryImage(headerBytes);
    final footerImage = pw.MemoryImage(footerBytes);

    pw.ThemeData pdfTheme;
    try {
      final poppinsRegular = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
      final poppinsBold = await rootBundle.load('assets/fonts/Poppins-Bold.ttf');
      pdfTheme = pw.ThemeData.withFont(
        base: pw.Font.ttf(Uint8List.fromList(poppinsRegular.buffer.asUint8List()).buffer.asByteData()),
        bold: pw.Font.ttf(Uint8List.fromList(poppinsBold.buffer.asUint8List()).buffer.asByteData()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load fonts: $e')),
        );
      }
      return null;
    }

    final generatedOn = DateFormat('EEEE, d MMMM yyyy · HH:mm').format(DateTime.now());
    final title = widget.jobId <= 0 ? 'Candidates (all jobs)' : 'Candidates';
    final doc = pw.Document(theme: pdfTheme);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Image(headerImage, width: 180, height: 56),
        ),
        footer: (pw.Context context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(footerImage, width: 140, height: 42),
              pw.Text(
                'Page ${context.pageNumber + 1}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        build: (pw.Context context) {
          final rows = <pw.Widget>[
            pw.Header(level: 0, text: 'Shortlist / Candidates Report', textStyle: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Paragraph(text: '$title · Generated on: $generatedOn', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 12),
          ];
          if (list.isEmpty) {
            rows.add(pw.Paragraph(text: 'No candidates to export. Apply filters or refresh.', style: const pw.TextStyle(fontSize: 10)));
          } else {
            rows.add(pw.Table.fromTextArray(
              context: context,
              data: [
                ['Candidate', 'Email', 'Job applied', 'CV Score', 'Overall', 'Status', 'Recommendation'],
                ...list.map((c) {
                  final cv = c['cv_score'] != null ? (c['cv_score'] is num ? (c['cv_score'] as num).toStringAsFixed(0) : c['cv_score'].toString()) : '—';
                  final ov = c['overall_score'] != null ? (c['overall_score'] is num ? (c['overall_score'] as num).toStringAsFixed(0) : c['overall_score'].toString()) : '—';
                  return [
                    (c['full_name'] ?? c['name'] ?? '—').toString(),
                    (c['email'] ?? '—').toString(),
                    (c['job_title'] ?? '—').toString(),
                    cv,
                    ov,
                    (c['status'] ?? '—').toString(),
                    (c['recommendation'] ?? '—').toString(),
                  ];
                }),
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
            ));
          }
          return rows;
        },
      ),
    );
    return doc.save();
  }

  static String _csvEscape(String? s) {
    if (s == null) return '';
    final t = s.replaceAll('"', '""');
    return t.contains(',') || t.contains('"') || t.contains('\n') ? '"$t"' : t;
  }

  Future<void> _exportShortlistCsv() async {
    final list = _filteredCandidates();
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No candidates to export. Apply filters or refresh.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isExportingCsv = true);
    try {
      const header = 'Candidate,Email,Job applied,CV Score,Assessment Score,Overall,Status,Recommendation';
      final rows = list.map((c) {
        final cv = c['cv_score'] != null ? (c['cv_score'] is num ? (c['cv_score'] as num).toString() : c['cv_score'].toString()) : '';
        final assess = c['assessment_score'] != null ? (c['assessment_score'] is num ? (c['assessment_score'] as num).toString() : c['assessment_score'].toString()) : '';
        final ov = c['overall_score'] != null ? (c['overall_score'] is num ? (c['overall_score'] as num).toString() : c['overall_score'].toString()) : '';
        return '${_csvEscape((c['full_name'] ?? c['name'] ?? '').toString())},${_csvEscape((c['email'] ?? '').toString())},${_csvEscape((c['job_title'] ?? '').toString())},$cv,$assess,$ov,${_csvEscape((c['status'] ?? '').toString())},${_csvEscape((c['recommendation'] ?? '').toString())}';
      });
      final csv = '$header\n${rows.join('\n')}';
      final filename = 'shortlist_export_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.csv';
      await analytics_export.downloadShortlistCsv(context, csv, filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  Future<void> _exportShortlistPdf() async {
    final list = _filteredCandidates();
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No candidates to export. Apply filters or refresh.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isExportingShortlist = true);
    try {
      final bytes = await _buildShortlistPdf();
      if (bytes == null || !mounted) return;
      final filename = 'shortlist_export_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.pdf';
      analytics_export.downloadShortlistPdf(context, bytes, filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingShortlist = false);
    }
  }

  Future<void> _setRecommendation(Map<String, dynamic> c, String value) async {
    final applicationId = c['application_id'] ?? c['id'];
    if (applicationId == null) return;
    try {
      await admin.updateApplicationRecommendation(applicationId as int, value);
      if (!mounted) return;
      setState(() {
        final idx = candidates.indexWhere((x) =>
            (x['application_id'] ?? x['id']) == applicationId);
        if (idx >= 0) candidates[idx]['recommendation'] = value;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recommendation set to $value', style: const TextStyle(fontFamily: 'Poppins'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set recommendation: $e', style: const TextStyle(fontFamily: 'Poppins')), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  static Color _recommendationColor(String? rec, ThemeProvider themeProvider) {
    if (rec == null || rec.isEmpty) return themeProvider.isDarkMode ? Colors.grey : Colors.grey.shade700;
    final lower = rec.toLowerCase();
    if (lower.contains('proceed') || lower.contains('final interview')) return Colors.green;
    if (lower.contains('hold')) return Colors.orange;
    if (lower.contains('reject')) return Colors.red;
    return themeProvider.isDarkMode ? Colors.grey : Colors.grey.shade700;
  }

  void openCandidateDetails(Map<String, dynamic> candidate) {
    final candidateId = candidate['candidate_id'] ?? candidate['id'];
    final applicationId = candidate['application_id'];

    if (candidateId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CandidateDetailScreen(
            candidateId: candidateId,
            applicationId: applicationId,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Candidate ID not found", style: const TextStyle(fontFamily: 'Poppins')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // Helper method to safely get initials
  String getInitials(String? fullName) {
    if (fullName == null || fullName.isEmpty) return "?";
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) return "?";
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0].substring(0, 1)}${parts[parts.length - 1].substring(0, 1)}'.toUpperCase();
  }

  Widget _buildCandidatesTable(ThemeProvider themeProvider) {
    final list = _filteredCandidates();
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    final borderColor = themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.grey.shade200,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('Candidate', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14, color: textColor))),
                Expanded(flex: 2, child: Text('Email', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14, color: textColor))),
                Expanded(flex: 2, child: Text('Job applied', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14, color: textColor))),
                Expanded(flex: 1, child: Text('CV', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 12, color: textColor))),
                Expanded(flex: 1, child: Text('Overall', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 12, color: textColor))),
                Expanded(flex: 1, child: Text('Status', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14, color: textColor))),
                Expanded(flex: 2, child: Text('Recommendation', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 12, color: textColor))),
                const SizedBox(width: 120),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, index) {
                final c = list[index];
                final status = (c['status'] ?? '—').toString();
                // Match Job Management applicants: blue badge for application status (assessment_submitted, in_progress, etc.)
                final Color statusColor;
                if (status == 'hired') {
                  statusColor = Colors.green;
                } else if (status == 'rejected') {
                  statusColor = Colors.red;
                } else {
                  statusColor = themeProvider.isDarkMode ? Colors.blue.shade200 : Colors.blue.shade800;
                }
                final rec = (c['recommendation'] ?? '').toString();
                final recColor = _recommendationColor(rec.isEmpty ? null : rec, themeProvider);
                final cvScore = c['cv_score'] != null ? (c['cv_score'] is num ? (c['cv_score'] as num).toDouble() : double.tryParse(c['cv_score'].toString()) ?? 0.0) : 0.0;
                final overallScore = c['overall_score'] != null ? (c['overall_score'] is num ? (c['overall_score'] as num).toDouble() : double.tryParse(c['overall_score'].toString()) ?? 0.0) : 0.0;
                return InkWell(
                  onTap: () => openCandidateDetails(c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text(c['full_name'] ?? c['name'] ?? '—', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: textColor), overflow: TextOverflow.ellipsis)),
                        Expanded(flex: 2, child: Text((c['email'] ?? '—').toString(), style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: textColor), overflow: TextOverflow.ellipsis)),
                        Expanded(flex: 2, child: Text((c['job_title'] ?? '—').toString(), style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: textColor), overflow: TextOverflow.ellipsis)),
                        Expanded(flex: 1, child: Text(cvScore.toStringAsFixed(0), style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: textColor))),
                        Expanded(flex: 1, child: Text(overallScore.toStringAsFixed(0), style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: textColor))),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(status, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: statusColor), overflow: TextOverflow.ellipsis, maxLines: 1),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: rec.isNotEmpty
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: recColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(rec, style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w500, color: recColor), overflow: TextOverflow.ellipsis, maxLines: 1),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.more_vert, size: 18, color: textColor),
                                onSelected: (value) => _setRecommendation(c, value),
                                itemBuilder: (context) => _recommendationOptions
                                    .map((opt) => PopupMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12))))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return DefaultTextStyle(
      style: TextStyle(
        fontFamily: 'Poppins',
        color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
      ),
      child: Scaffold(
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
          body: SafeArea(
            child: Column(
              children: [
                // Sticky header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  color: (themeProvider.isDarkMode
                          ? const Color(0xFF14131E)
                          : Colors.white)
                      .withValues(alpha: 0.9),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.jobId <= 0 ? "All Candidates" : "Candidates",
                            style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black87),
                          ),
                          if (widget.jobId > 0)
                            Text(
                              'Ranked shortlist',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.black54,
                              ),
                            ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isExportingCsv ? null : _exportShortlistCsv,
                            icon: _isExportingCsv
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.table_chart_outlined, size: 20),
                            label: Text(_isExportingCsv ? 'Exporting…' : 'Export CSV'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: themeProvider.isDarkMode ? Colors.white70 : Colors.black87,
                              side: BorderSide(color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _isExportingShortlist ? null : _exportShortlistPdf,
                            icon: _isExportingShortlist
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.picture_as_pdf_outlined, size: 20),
                            label: Text(_isExportingShortlist ? 'Exporting…' : 'Export PDF'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: themeProvider.isDarkMode ? Colors.white70 : Colors.black87,
                              side: BorderSide(color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 12),
                          CustomButton(
                            text: "Refresh",
                            onPressed: fetchShortlist,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(
                    height: 1,
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade800
                        : Colors.grey),

                // Search and filters
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search by name, email, or job title...',
                          hintStyle: TextStyle(
                            fontFamily: 'Poppins',
                            color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
                          ),
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
                            ),
                          ),
                          filled: true,
                          fillColor: themeProvider.isDarkMode
                              ? Colors.grey.shade900.withValues(alpha: 0.5)
                              : Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text('Status: ', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.black54)),
                          DropdownButton<String>(
                            value: _statusFilter,
                            underline: const SizedBox(),
                            borderRadius: BorderRadius.circular(8),
                            dropdownColor: themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white,
                            style: TextStyle(fontFamily: 'Poppins', color: themeProvider.isDarkMode ? Colors.white : Colors.black87, fontSize: 14),
                            items: _statusOptions.map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s == 'all' ? 'All' : s[0].toUpperCase() + s.substring(1), style: TextStyle(fontFamily: 'Poppins', color: themeProvider.isDarkMode ? Colors.white : Colors.black87)),
                            )).toList(),
                            onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                          ),
                          if (widget.jobId <= 0 && _jobTitleOptions.length > 1) ...[
                            const SizedBox(width: 24),
                            Text('Job: ', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.black54)),
                            DropdownButton<String?>(
                              value: _jobFilter,
                              underline: const SizedBox(),
                              borderRadius: BorderRadius.circular(8),
                              dropdownColor: themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white,
                              style: TextStyle(fontFamily: 'Poppins', color: themeProvider.isDarkMode ? Colors.white : Colors.black87, fontSize: 14),
                              items: _jobTitleOptions.map((t) => DropdownMenuItem(
                                value: t == 'All jobs' ? null : t,
                                child: Text(t, style: TextStyle(fontFamily: 'Poppins', color: themeProvider.isDarkMode ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (v) => setState(() => _jobFilter = (v == 'All jobs' || v == null) ? null : v),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Table: loading / message / empty / list
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.redAccent),
                        )
                      : statusMessage != null
                          ? Center(
                              child: Text(
                                statusMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: themeProvider.isDarkMode
                                        ? Colors.grey.shade300
                                        : Colors.black54,
                                    fontSize: 16),
                              ),
                            )
                          : _filteredCandidates().isEmpty
                              ? Center(
                                  child: Text(
                                    candidates.isEmpty ? "No candidates found" : "No candidates match your search or filter",
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: themeProvider.isDarkMode
                                            ? Colors.grey.shade400
                                            : Colors.black54,
                                        fontSize: 16),
                                  ),
                                )
                              : _buildCandidatesTable(themeProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
