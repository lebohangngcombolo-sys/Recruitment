import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../services/candidate_service.dart';
import 'job_details_page.dart';

class BrowseAllJobsPage extends StatefulWidget {
  final String token;

  const BrowseAllJobsPage({super.key, required this.token});

  @override
  State<BrowseAllJobsPage> createState() => _BrowseAllJobsPageState();
}

class _BrowseAllJobsPageState extends State<BrowseAllJobsPage> {
  static const _fetchTimeout = Duration(seconds: 8);
  static const _pageSize = 20;
  static const _jobTypes = ['Featured', 'Full Time', 'Part Time', 'Remote'];

  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _applications = [];
  bool _loading = true;
  int _selectedTabIndex = 0;
  int _page = 0;

  final Color primaryColor = Color(0xFF991A1A);
  final Color strokeColor = Color(0xFFC10D00);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        CandidateService.getAvailableJobs(widget.token)
            .timeout(_fetchTimeout, onTimeout: () => <Map<String, dynamic>>[]),
        CandidateService.getApplications(widget.token)
            .timeout(const Duration(seconds: 5), onTimeout: () => <dynamic>[]),
      ]);
      if (!mounted) return;
      final jobList = (results[0] as Iterable).map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
      final appList = results[1] as Iterable;
      final appMaps = appList.whereType<Map>().map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        _jobs = jobList;
        _applications = appMaps;
        _loading = false;
        _page = 0;
      });
    } catch (_) {
      if (mounted) setState(() {
        _jobs = [];
        _applications = [];
        _loading = false;
      });
    }
  }

  bool _hasApplicationForJob(Map<String, dynamic> job) {
    final jobId = job['id'];
    if (jobId == null) return false;
    for (final app in _applications) {
      if (app['job_id'] == jobId) return true;
    }
    return false;
  }

  List<Map<String, dynamic>> _getFilteredJobs() {
    final typeFilter = _jobTypes[_selectedTabIndex];
    var list = _jobs.where((j) => !_hasApplicationForJob(j)).toList();
    if (typeFilter != 'Featured') {
      list = list.where((j) {
        final t = (j['type'] ?? j['employment_type'] ?? '').toString().toLowerCase();
        final loc = (j['location'] ?? '').toString().toLowerCase();
        if (typeFilter == 'Full Time') return t.contains('full') || t == 'full_time';
        if (typeFilter == 'Part Time') return t.contains('part') || t == 'part_time';
        if (typeFilter == 'Remote') return loc.contains('remote') || t.contains('remote');
        return true;
      }).toList();
    }
    return list;
  }

  List<Map<String, dynamic>> _getPaginated() {
    final list = _getFilteredJobs();
    final start = _page * _pageSize;
    if (start >= list.length) return [];
    final end = (start + _pageSize).clamp(0, list.length);
    return list.sublist(start, end);
  }

  int _getTotal() => _getFilteredJobs().length;

  String _formatJobType(dynamic value) {
    if (value == null) return 'Full Time';
    final t = value.toString().toLowerCase();
    if (t.contains('full') || t == 'full_time') return 'Full Time';
    if (t.contains('part') || t == 'part_time') return 'Part Time';
    if (t.contains('remote')) return 'Remote';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1A1A1A),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/dark.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => context.canPop() ? context.pop() : context.go('/candidate-dashboard?token=${Uri.encodeComponent(widget.token)}'),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Browse All Jobs',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Row(
                        children: List.generate(_jobTypes.length, (i) {
                          final isSelected = _selectedTabIndex == i;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedTabIndex = i;
                              _page = 0;
                            }),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: isSelected ? primaryColor : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Text(
                                _jobTypes[i],
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? Colors.white : Colors.white70,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      Container(height: 1, color: Colors.white24),
                      SizedBox(height: 24),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? Center(
                          child: CircularProgressIndicator(color: strokeColor),
                        )
                      : _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final total = _getTotal();
    if (total == 0) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No jobs to show. Check back later.',
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final paginated = _getPaginated();
    final start = _page * _pageSize + 1;
    final end = (_page * _pageSize + paginated.length).clamp(0, total);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTableHeader(),
                  ...paginated.map((job) {
                    final j = Map<String, dynamic>.from(job);
                    if (!j.containsKey('type') && j.containsKey('employment_type')) j['type'] = j['employment_type'];
                    return _buildTableRow(j);
                  }),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Color(0xFF252525),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing $start to $end of $total',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _page > 0 ? () => setState(() => _page--) : null,
                      child: Text('Previous', style: GoogleFonts.poppins(color: _page > 0 ? strokeColor : Colors.white38)),
                    ),
                    SizedBox(width: 8),
                    TextButton(
                      onPressed: (_page + 1) * _pageSize < total ? () => setState(() => _page++) : null,
                      child: Text('Next', style: GoogleFonts.poppins(color: (_page + 1) * _pageSize < total ? strokeColor : Colors.white38)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: _headerCell('Job Position')),
          Expanded(flex: 2, child: _headerCell('Company')),
          Expanded(flex: 1, child: _headerCell('Location')),
          SizedBox(width: 160),
        ],
      ),
    );
  }

  Widget _headerCell(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> job) {
    final company = (job['company']?.toString().trim().isNotEmpty == true) ? (job['company'] ?? '') : '—';
    final location = (job['location']?.toString().trim().isNotEmpty == true) ? (job['location'] ?? '') : '—';
    final jobType = _formatJobType(job['type'] ?? job['employment_type']);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              job['title'] ?? 'Job Title',
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(company, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                SizedBox(height: 2),
                Text(jobType, style: GoogleFonts.poppins(fontSize: 13, color: Colors.white60)),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(location, style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => JobDetailsPage(job: job)),
                  );
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Color(0xFF3A3A3A),
                  side: BorderSide(color: Colors.white38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: Text('View Details', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => JobDetailsPage(job: job)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: strokeColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: Text('Apply', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
