import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../utils/api_endpoints.dart';
import '../../providers/theme_provider.dart';
import 'candidate_detail_screen.dart';

class CandidatesByJobScreen extends StatefulWidget {
  const CandidatesByJobScreen({super.key});

  @override
  State<CandidatesByJobScreen> createState() => _CandidatesByJobScreenState();
}

class _CandidatesByJobScreenState extends State<CandidatesByJobScreen> {
  Map<String, List<dynamic>> applicationsByJob = {};
  Map<String, dynamic> jobDetails = {};
  bool loading = true;
  String searchQuery = '';
  String statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    try {
      final response = await AuthService.authorizedGet(
        ApiEndpoints.getFilteredApplications,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final applications = data['applications'] as List<dynamic>;

        // Group applications by job
        Map<String, List<dynamic>> grouped = {};
        Map<String, dynamic> jobs = {};

        for (var app in applications) {
          final jobId = app['job_id'].toString();
          final jobTitle = app['job_title'] ?? 'Unknown Job';

          if (!grouped.containsKey(jobId)) {
            grouped[jobId] = [];
            jobs[jobId] = {
              'title': jobTitle,
              'id': jobId,
              'status': app['job_status'] ?? 'active',
            };
          }
          grouped[jobId]!.add(app);
        }

        if (mounted) {
          setState(() {
            applicationsByJob = grouped;
            jobDetails = jobs;
            loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => loading = false);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load applications')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  List<dynamic> _filterApplications(List<dynamic> applications) {
    var filtered = applications;

    // Apply status filter
    if (statusFilter != 'all') {
      filtered =
          filtered.where((app) => app['status'] == statusFilter).toList();
    }

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((app) {
        final candidate = app['candidate'] ?? {};
        final name = (candidate['full_name'] ?? '').toString().toLowerCase();
        final email = (candidate['email'] ?? '').toString().toLowerCase();
        return name.contains(searchQuery.toLowerCase()) ||
            email.contains(searchQuery.toLowerCase());
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor:
          themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor:
            themeProvider.isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        elevation: 0,
        title: Text(
          'Candidates by Job',
          style: GoogleFonts.inter(
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(
          color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search and filter section
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search candidates...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          fillColor: themeProvider.isDarkMode
                              ? const Color(0xFF2A2A3E)
                              : Colors.white,
                          filled: true,
                        ),
                        onChanged: (value) {
                          setState(() => searchQuery = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: statusFilter,
                        decoration: InputDecoration(
                          labelText: 'Filter by Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          fillColor: themeProvider.isDarkMode
                              ? const Color(0xFF2A2A3E)
                              : Colors.white,
                          filled: true,
                        ),
                        onChanged: (value) {
                          setState(() => statusFilter = value!);
                        },
                        items: const [
                          DropdownMenuItem(
                              value: 'all', child: Text('All Status')),
                          DropdownMenuItem(
                              value: 'applied', child: Text('Applied')),
                          DropdownMenuItem(
                              value: 'screening', child: Text('Screening')),
                          DropdownMenuItem(
                              value: 'assessment', child: Text('Assessment')),
                          DropdownMenuItem(
                              value: 'interview', child: Text('Interview')),
                          DropdownMenuItem(
                              value: 'offer', child: Text('Offer')),
                          DropdownMenuItem(
                              value: 'hired', child: Text('Hired')),
                          DropdownMenuItem(
                              value: 'rejected', child: Text('Rejected')),
                        ],
                      ),
                    ],
                  ),
                ),

                // Jobs and candidates list
                Expanded(
                  child: applicationsByJob.isEmpty
                      ? Center(
                          child: Text(
                            'No applications found',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: applicationsByJob.keys.length,
                          itemBuilder: (context, index) {
                            final jobId =
                                applicationsByJob.keys.elementAt(index);
                            final job = jobDetails[jobId]!;
                            final applications =
                                _filterApplications(applicationsByJob[jobId]!);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Job header
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.work,
                                          color: Colors.redAccent,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                job['title'],
                                                style: GoogleFonts.inter(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      themeProvider.isDarkMode
                                                          ? Colors.white
                                                          : Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                '${applications.length} candidates • Status: ${job['status']}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: themeProvider
                                                          .isDarkMode
                                                      ? Colors.grey.shade400
                                                      : Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Candidates list
                                    if (applications.isEmpty)
                                      Text(
                                        'No candidates match the current filters',
                                        style: GoogleFonts.inter(
                                          color: themeProvider.isDarkMode
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      )
                                    else
                                      ...applications
                                          .map(
                                              (app) => _buildCandidateCard(app))
                                          .toList(),
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

  Widget _buildCandidateCard(Map<String, dynamic> application) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final candidate = application['candidate'] as Map<String, dynamic>? ?? {};
    final status = application['status'] as String? ?? 'unknown';

    Color getStatusColor(String status) {
      switch (status.toLowerCase()) {
        case 'applied':
          return Colors.blue;
        case 'screening':
          return Colors.blue;
        case 'assessment':
          return Colors.orange;
        case 'interview':
          return Colors.purple;
        case 'offer':
          return Colors.green;
        case 'hired':
          return Colors.teal;
        case 'rejected':
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: themeProvider.isDarkMode
              ? Colors.grey.shade700
              : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CandidateDetailScreen(
                candidateId: candidate['id'],
                applicationId: application['id'],
              ),
            ),
          );
        },
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.redAccent.withOpacity(0.1),
              child: Text(
                (candidate['full_name'] ?? 'U')[0].toString().toUpperCase(),
                style: GoogleFonts.inter(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate['full_name'] ?? 'Unknown Candidate',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                  Text(
                    candidate['email'] ?? 'No email',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: getStatusColor(status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
