import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/theme_provider.dart';
import 'job_details_page.dart';

class SavedJobsScreen extends StatefulWidget {
  final String token;
  const SavedJobsScreen({super.key, required this.token});

  @override
  _SavedJobsScreenState createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen> {
  List<Map<String, dynamic>> _savedJobs = [];
  bool _loading = true;

  final Color primaryColor = Color(0xFF991A1A);
  final Color strokeColor = Color(0xFFC10D00);
  bool _isDarkMode = true;
  Color get _textPrimary =>
      _isDarkMode ? Colors.white : const Color(0xFF090812);
  Color get _textSecondary => _isDarkMode
      ? Colors.white70
      : const Color(0xFF090812).withValues(alpha: 0.72);
  Color get _textSoft => _isDarkMode
      ? Colors.white54
      : const Color(0xFF090812).withValues(alpha: 0.58);

  @override
  void initState() {
    super.initState();
    _loadSavedJobs();
  }

  Future<void> _loadSavedJobs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJobsJson = prefs.getString('saved_jobs');
      if (savedJobsJson != null && savedJobsJson.isNotEmpty) {
        final List<dynamic> savedList = jsonDecode(savedJobsJson);
        final savedJobsList = savedList
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (mounted) {
          setState(() {
            _savedJobs = savedJobsList;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _savedJobs = [];
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _unsaveJob(Map<String, dynamic> job) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jobId = job['id']?.toString();
      if (jobId == null) return;

      final updatedSavedJobs = _savedJobs
          .where((savedJob) => savedJob['id']?.toString() != jobId)
          .toList();

      await prefs.setString('saved_jobs', jsonEncode(updatedSavedJobs));

      if (mounted) {
        setState(() {
          _savedJobs = updatedSavedJobs;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Job removed from saved',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to remove saved job',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildSavedJobTile(Map<String, dynamic> savedJob) {
    final company = (savedJob['company']?.toString().trim().isNotEmpty == true)
        ? (savedJob['company'] ?? '')
        : '—';
    final location = (savedJob['location']?.toString().trim().isNotEmpty == true)
        ? (savedJob['location'] ?? '')
        : '—';
    final jobType = _formatJobType(
      savedJob['type'] ?? savedJob['employment_type'] ?? 'Full Time',
    );
    final savedDate = savedJob['saved_at']?.toString();
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => JobDetailsPage(job: savedJob)),
          );
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          savedJob['title'] ?? 'Job Title',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          company,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                jobType,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                location,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          _unsaveJob(savedJob);
                        },
                        icon: Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 20,
                        ),
                        padding: EdgeInsets.all(4),
                        constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ],
              ),
              if (savedDate != null) ...[
                SizedBox(height: 8),
                Text(
                  'Saved ${_formatDate(savedDate)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.black38,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatJobType(String type) {
    switch (type.toLowerCase()) {
      case 'full_time':
        return 'Full Time';
      case 'part_time':
        return 'Part Time';
      case 'remote':
        return 'Remote';
      case 'contract':
        return 'Contract';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    _isDarkMode = themeProvider.isDarkMode;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Saved Jobs',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(themeProvider.backgroundImage),
            fit: BoxFit.cover,
          ),
        ),
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  color: strokeColor,
                ),
              )
            : _savedJobs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border,
                          color: _textSoft,
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No saved jobs yet',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: _textSecondary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap the heart icon on jobs to save them here.',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _textSoft,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _savedJobs.length,
                    itemBuilder: (context, index) {
                      final savedJob = _savedJobs[index];
                      return _buildSavedJobTile(savedJob);
                    },
                  ),
      ),
    );
  }
}
