import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/admin_service.dart';
import '../../widgets/custom_button.dart';
import 'candidate_detail_screen.dart';
import '../../providers/theme_provider.dart';

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

  static const List<String> _statusOptions = [
    'all',
    'screening',
    'assessment',
    'interview',
    'offer',
    'hired',
    'rejected',
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
      final words = query
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList();
      list = list.where((c) {
        final name = (c['full_name'] ?? c['name'] ?? '')
            .toString()
            .toLowerCase();
        final email = (c['email'] ?? '').toString().toLowerCase();
        final job = (c['job_title'] ?? '').toString().toLowerCase();
        final s = '$name $email $job';
        return words.every((w) => s.contains(w));
      }).toList();
    }
    if (_statusFilter != 'all') {
      list = list
          .where(
            (c) =>
                (c['status'] ?? '').toString().toLowerCase() == _statusFilter,
          )
          .toList();
    }
    if (_jobFilter != null && _jobFilter!.isNotEmpty) {
      list = list
          .where((c) => (c['job_title'] ?? '').toString() == _jobFilter)
          .toList();
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
        rawApplications = await admin.getApplicationsForMyJobs(
          page: 1,
          perPage: 500,
        );
      } else {
        rawApplications = await admin.getJobApplications(
          widget.jobId,
          page: 1,
          perPage: 100,
        );
      }

      final fetched = (rawApplications).map<Map<String, dynamic>>((
        dynamic app,
      ) {
        final map = Map<String, dynamic>.from(app as Map);
        final candidateData = (map['candidate'] is Map)
            ? Map<String, dynamic>.from(map['candidate'] as Map)
            : {};
        return {
          'application_id': map['application_id'] ?? map['id'],
          'candidate_id': candidateData['id'] ?? map['candidate_id'],
          'full_name':
              candidateData['full_name'] ??
              candidateData['name'] ??
              map['full_name'],
          'email': candidateData['email'],
          'phone': candidateData['phone'],
          'status': map['status'],
          'cv_score': map['cv_score'] ?? map['overall_score'] ?? 0,
          'assessment_score': map['assessment_score'] ?? 0,
          'overall_score':
              map['overall_score'] ??
              (map['scoring_breakdown']?['overall'] ?? 0),
          'job_title': map['job_title'],
          'job_id': map['job_id'],
          'cv_parser_result': map['cv_parser_result'] ?? {},
          'candidate': candidateData,
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
          content: Text(
            "Candidate ID not found",
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
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
    return '${parts[0].substring(0, 1)}${parts[parts.length - 1].substring(0, 1)}'
        .toUpperCase();
  }

  Widget _buildCandidatesTable(ThemeProvider themeProvider) {
    final list = _filteredCandidates();
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;
    final borderColor = themeProvider.isDarkMode
        ? Colors.grey.shade800
        : Colors.grey.shade300;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color:
            (themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white)
                .withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade900
                  : Colors.grey.shade200,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Candidate',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Email',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Job applied',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, index) {
                final c = list[index];
                final status = (c['status'] ?? '—').toString();
                final statusColor = status == 'hired'
                    ? Colors.green
                    : status == 'rejected'
                    ? Colors.red
                    : Colors.orange;
                return InkWell(
                  onTap: () => openCandidateDetails(c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            c['full_name'] ?? c['name'] ?? '—',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            (c['email'] ?? '—').toString(),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            (c['job_title'] ?? '—').toString(),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    color:
                        (themeProvider.isDarkMode
                                ? const Color(0xFF14131E)
                                : Colors.white)
                            .withValues(alpha: 0.9),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.jobId <= 0 ? "All Candidates" : "Candidates",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        CustomButton(
                          text: "Refresh",
                          onPressed: fetchShortlist,
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade800
                        : Colors.grey,
                  ),

                  // Search and filters
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _searchController,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black87,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search by name, email, or job title...',
                            hintStyle: TextStyle(
                              fontFamily: 'Poppins',
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.grey,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: themeProvider.isDarkMode
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade400,
                              ),
                            ),
                            filled: true,
                            fillColor: themeProvider.isDarkMode
                                ? Colors.grey.shade900.withValues(alpha: 0.5)
                                : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Status: ',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: themeProvider.isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.black54,
                              ),
                            ),
                            DropdownButton<String>(
                              value: _statusFilter,
                              underline: const SizedBox(),
                              borderRadius: BorderRadius.circular(8),
                              dropdownColor: themeProvider.isDarkMode
                                  ? const Color(0xFF14131E)
                                  : Colors.white,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 14,
                              ),
                              items: _statusOptions
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(
                                        s == 'all'
                                            ? 'All'
                                            : s[0].toUpperCase() +
                                                  s.substring(1),
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: themeProvider.isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _statusFilter = v ?? 'all'),
                            ),
                            if (widget.jobId <= 0 &&
                                _jobTitleOptions.length > 1) ...[
                              const SizedBox(width: 24),
                              Text(
                                'Job: ',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: themeProvider.isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.black54,
                                ),
                              ),
                              DropdownButton<String?>(
                                value: _jobFilter,
                                underline: const SizedBox(),
                                borderRadius: BorderRadius.circular(8),
                                dropdownColor: themeProvider.isDarkMode
                                    ? const Color(0xFF14131E)
                                    : Colors.white,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: themeProvider.isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 14,
                                ),
                                items: _jobTitleOptions
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t == 'All jobs' ? null : t,
                                        child: Text(
                                          t,
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            color: themeProvider.isDarkMode
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(
                                  () => _jobFilter =
                                      (v == 'All jobs' || v == null) ? null : v,
                                ),
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
                            child: CircularProgressIndicator(
                              color: Colors.redAccent,
                            ),
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
                                fontSize: 16,
                              ),
                            ),
                          )
                        : _filteredCandidates().isEmpty
                        ? Center(
                            child: Text(
                              candidates.isEmpty
                                  ? "No candidates found"
                                  : "No candidates match your search or filter",
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: themeProvider.isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.black54,
                                fontSize: 16,
                              ),
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

  // CV Preview and Download Methods
  Future<void> _previewCV(String cvUrl) async {
    try {
      final uri = Uri.parse(cvUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.inAppWebView);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not preview CV')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error previewing CV: $e')));
      }
    }
  }

  Future<void> _downloadCV(String cvUrl) async {
    try {
      final uri = Uri.parse(cvUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not download CV')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error downloading CV: $e')));
      }
    }
  }
}
