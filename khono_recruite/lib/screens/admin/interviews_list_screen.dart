import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../utils/api_endpoints.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart'; // Add this import

class InterviewListScreen extends StatefulWidget {
  const InterviewListScreen({super.key});

  @override
  State<InterviewListScreen> createState() => _InterviewListScreenState();
}

class _InterviewListScreenState extends State<InterviewListScreen> {
  List<dynamic> interviews = [];
  List<dynamic> candidates = [];
  bool loading = true;
  String _selectedFilter =
      'all'; // 'all', 'today', 'upcoming', 'past', 'action_required'
  final AdminService _adminService = AdminService(); // Add service instance

  @override
  void initState() {
    super.initState();
    fetchInterviews();
    fetchCandidates();
  }

  // Filter interviews based on selected filter
  List<dynamic> get filteredInterviews {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'today':
        return interviews.where((i) {
          if (i['scheduled_time'] == null) return false;
          final scheduled = DateTime.parse(i['scheduled_time']);
          return scheduled.year == now.year &&
              scheduled.month == now.month &&
              scheduled.day == now.day;
        }).toList();
      case 'upcoming':
        return interviews.where((i) {
          if (i['scheduled_time'] == null) return false;
          final scheduled = DateTime.parse(i['scheduled_time']);
          return scheduled.isAfter(now) && i['status'] == 'scheduled';
        }).toList();
      case 'past':
        return interviews.where((i) {
          if (i['scheduled_time'] == null) return false;
          final scheduled = DateTime.parse(i['scheduled_time']);
          return scheduled.isBefore(now) ||
              i['status'] == 'completed' ||
              i['status'] == 'cancelled';
        }).toList();
      case 'action_required':
        return interviews.where((i) {
          return i['status'] == 'feedback_pending' ||
              i['status'] == 'no_show' ||
              i['status'] == 'cancelled_by_candidate';
        }).toList();
      default:
        return interviews;
    }
  }

  Future<void> fetchCandidates() async {
    try {
      final response = await AuthService.authorizedGet(
        "${ApiEndpoints.adminBase}/candidates/all",
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          candidates = data['candidates'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading candidates: $e')));
      }
    }
  }

  Future<void> fetchInterviews() async {
    setState(() => loading = true);
    try {
      final response = await AuthService.authorizedGet(
        "${ApiEndpoints.adminBase}/interviews/all",
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          interviews = decoded['interviews'] ?? [];
          loading = false;
        });
      } else {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load interviews')),
        );
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> cancelInterview(int id) async {
    final url = "${ApiEndpoints.adminBase}/interviews/cancel/$id";

    try {
      // Make DELETE request with authorization
      final response = await AuthService.authorizedDelete(url);

      if (response.statusCode == 200) {
        // Success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Interview cancelled successfully")),
          );
        }
        // Refresh interview list
        fetchInterviews();
      } else {
        // Parse backend error message
        final err = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(err['error'] ?? 'Failed to cancel interview')),
          );
        }
      }
    } catch (e) {
      // Network or unexpected errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> rescheduleInterview(int id, DateTime newTime) async {
    final url = "${ApiEndpoints.adminBase}/interviews/reschedule/$id";
    try {
      final response = await AuthService.authorizedPut(url, {
        "scheduled_time": newTime.toIso8601String(),
      });
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Interview rescheduled")),
          );
        }
        fetchInterviews();
      } else {
        final err = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err['error'] ?? 'Failed to reschedule')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // New method: Update interview status
  Future<void> updateInterviewStatus(int id, String status,
      {String? notes}) async {
    try {
      await _adminService.updateInterviewStatus(
        interviewId: id,
        status: status,
        notes: notes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("Interview marked as ${status.replaceAll('_', ' ')}")),
        );
      }

      fetchInterviews();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  // New method: Submit feedback
  Future<void> submitFeedback(BuildContext context, int interviewId) async {
    final result = await showDialog(
      context: context,
      builder: (context) => FeedbackDialog(interviewId: interviewId),
    );

    if (result == true) {
      fetchInterviews();
    }
  }

  // New method: View feedback summary
  Future<void> viewFeedbackSummary(int interviewId) async {
    try {
      final feedback = await _adminService.getInterviewFeedback(interviewId);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => FeedbackSummaryDialog(feedback: feedback),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load feedback: $e')),
        );
      }
    }
  }

  void showRescheduleDialog(int id) async {
    DateTime? picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );

    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        final newDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        );
        rescheduleInterview(id, newDateTime);
      }
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'rescheduled':
        return Colors.orange;
      case 'feedback_pending':
        return Colors.amber;
      case 'no_show':
        return Colors.deepOrange;
      case 'cancelled_by_candidate':
        return Colors.purple;
      case 'feedback_submitted':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return '⏰';
      case 'completed':
        return '✅';
      case 'cancelled':
        return '❌';
      case 'rescheduled':
        return '🔄';
      case 'feedback_pending':
        return '📝';
      case 'no_show':
        return '🚫';
      case 'cancelled_by_candidate':
        return '👤❌';
      case 'feedback_submitted':
        return '📊';
      default:
        return '📅';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final width = MediaQuery.of(context).size.width;
    final redColor = const Color.fromRGBO(151, 18, 8, 1);

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
              "Interview Schedule",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
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
                        "Loading Interviews...",
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
              : interviews.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 80,
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade600
                                : Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No Interviews Scheduled",
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
                            "Interviews will appear here once scheduled",
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
                        // NEW: Filter tabs
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip('All', 'all', themeProvider),
                                const SizedBox(width: 8),
                                _buildFilterChip(
                                    'Today', 'today', themeProvider),
                                const SizedBox(width: 8),
                                _buildFilterChip(
                                    'Upcoming', 'upcoming', themeProvider),
                                const SizedBox(width: 8),
                                _buildFilterChip('Past', 'past', themeProvider),
                                const SizedBox(width: 8),
                                _buildFilterChip('Action Required',
                                    'action_required', themeProvider),
                              ],
                            ),
                          ),
                        ),

                        // Header with stats
                        Container(
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: (themeProvider.isDarkMode
                                    ? const Color(0xFF14131E)
                                    : Colors.white)
                                .withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: redColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.calendar_today,
                                  color: redColor,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Interview Schedule",
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    "${filteredInterviews.length} interviews (${interviews.length} total)",
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
                              // NEW: Status summary
                              Wrap(
                                spacing: 8,
                                children: [
                                  _buildStatusBadge(
                                      'Scheduled', Colors.blue, themeProvider),
                                  _buildStatusBadge(
                                      'Pending', Colors.amber, themeProvider),
                                  _buildStatusBadge(
                                      'Completed', Colors.green, themeProvider),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Interviews Grid
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Wrap(
                              spacing: 20,
                              runSpacing: 20,
                              children: filteredInterviews.map((i) {
                                final scheduled = i['scheduled_time'] != null
                                    ? DateFormat('MMM dd, yyyy • HH:mm').format(
                                        DateTime.parse(i['scheduled_time']))
                                    : 'Not Scheduled';

                                final status = i['status'] ?? 'Scheduled';
                                final statusColor = getStatusColor(status);
                                final statusIcon = getStatusIcon(status);

                                return Container(
                                  width: width < 600 ? double.infinity : 400,
                                  decoration: BoxDecoration(
                                    color: (themeProvider.isDarkMode
                                            ? const Color(0xFF14131E)
                                            : Colors.white)
                                        .withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 15,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: themeProvider.isDarkMode
                                          ? Colors.grey.shade800
                                          : Colors.grey.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Header with status
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.1),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(20),
                                            topRight: Radius.circular(20),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: statusColor
                                                    .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    statusIcon,
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    status.toUpperCase(),
                                                    style: GoogleFonts.inter(
                                                      color: statusColor,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Spacer(),
                                            Icon(
                                              Icons.calendar_today,
                                              color: statusColor,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              scheduled,
                                              style: GoogleFonts.inter(
                                                color: themeProvider.isDarkMode
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade600,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Content
                                      Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Candidate Avatar
                                            Stack(
                                              children: [
                                                Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    color: redColor
                                                        .withValues(alpha: 0.1),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: redColor
                                                          .withValues(alpha: 0.2),
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child:
                                                      i['candidate_picture'] !=
                                                              null
                                                          ? ClipOval(
                                                              child:
                                                                  Image.network(
                                                                i['candidate_picture'],
                                                                width: 60,
                                                                height: 60,
                                                                fit: BoxFit
                                                                    .cover,
                                                              ),
                                                            )
                                                          : Icon(
                                                              Icons.person,
                                                              size: 30,
                                                              color: redColor
                                                                  .withValues(alpha: 
                                                                      0.6),
                                                            ),
                                                ),
                                                Positioned(
                                                  bottom: 0,
                                                  right: 0,
                                                  child: Container(
                                                    width: 16,
                                                    height: 16,
                                                    decoration: BoxDecoration(
                                                      color: statusColor,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: Colors.white,
                                                        width: 2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 16),
                                            // Candidate Details
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    i['job_title'] ??
                                                        'No Job Title',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: themeProvider
                                                              .isDarkMode
                                                          ? Colors.white
                                                          : Colors.black87,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  _buildDetailRow(
                                                    icon: Icons.person,
                                                    text: i['candidate_name'] ??
                                                        'Unknown Candidate',
                                                    themeProvider:
                                                        themeProvider,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  _buildDetailRow(
                                                    icon: Icons.video_call,
                                                    text:
                                                        "Type: ${i['interview_type'] ?? 'N/A'}",
                                                    themeProvider:
                                                        themeProvider,
                                                  ),
                                                  // NEW: Feedback info
                                                  if (i['feedback_submitted_at'] !=
                                                      null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 4),
                                                      child: _buildDetailRow(
                                                        icon: Icons.feedback,
                                                        text:
                                                            "Feedback submitted: ${DateFormat('MMM dd').format(DateTime.parse(i['feedback_submitted_at']))}",
                                                        themeProvider:
                                                            themeProvider,
                                                      ),
                                                    ),
                                                  const SizedBox(height: 16),
                                                  // Action Buttons
                                                  Column(
                                                    children: [
                                                      // NEW: Status-specific buttons
                                                      if (status ==
                                                          'scheduled') ...[
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child:
                                                                  _buildActionButton(
                                                                icon: Icons
                                                                    .check_circle,
                                                                label:
                                                                    "Mark Complete",
                                                                color: Colors
                                                                    .green,
                                                                onPressed: () =>
                                                                    updateInterviewStatus(
                                                                        i['id'],
                                                                        'completed'),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 8),
                                                            Expanded(
                                                              child:
                                                                  _buildActionButton(
                                                                icon: Icons
                                                                    .no_accounts,
                                                                label:
                                                                    "No Show",
                                                                color: Colors
                                                                    .orange,
                                                                onPressed: () =>
                                                                    updateInterviewStatus(
                                                                        i['id'],
                                                                        'no_show'),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                      ],
                                                      if (status ==
                                                              'completed' ||
                                                          status ==
                                                              'feedback_pending') ...[
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child:
                                                                  _buildActionButton(
                                                                icon: Icons
                                                                    .feedback,
                                                                label: status ==
                                                                        'completed'
                                                                    ? "Submit Feedback"
                                                                    : "View Feedback",
                                                                color:
                                                                    Colors.blue,
                                                                onPressed: () => status ==
                                                                        'completed'
                                                                    ? submitFeedback(
                                                                        context,
                                                                        i['id'])
                                                                    : viewFeedbackSummary(
                                                                        i['id']),
                                                              ),
                                                            ),
                                                            if (status ==
                                                                'completed') ...[
                                                              const SizedBox(
                                                                  width: 8),
                                                              Expanded(
                                                                child:
                                                                    _buildActionButton(
                                                                  icon: Icons
                                                                      .schedule,
                                                                  label:
                                                                      "Pending",
                                                                  color: Colors
                                                                      .amber,
                                                                  onPressed: () =>
                                                                      updateInterviewStatus(
                                                                          i['id'],
                                                                          'feedback_pending'),
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                      ],
                                                      // Original buttons
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child:
                                                                _buildActionButton(
                                                              icon: Icons
                                                                  .cancel_outlined,
                                                              label: "Cancel",
                                                              color: Colors.red,
                                                              onPressed: () =>
                                                                  cancelInterview(
                                                                      i['id']),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                            child:
                                                                _buildActionButton(
                                                              icon: Icons
                                                                  .schedule,
                                                              label:
                                                                  "Reschedule",
                                                              color: redColor,
                                                              onPressed: () =>
                                                                  showRescheduleDialog(
                                                                      i['id']),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      // NEW: Direct Feedback Button for feedback_pending interviews
                                                      if (status ==
                                                          'feedback_pending') ...[
                                                        const SizedBox(
                                                            height: 12),
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
                                                                    .amber
                                                                    .withValues(alpha: 
                                                                        0.3),
                                                                blurRadius: 8,
                                                                offset:
                                                                    const Offset(
                                                                        0, 4),
                                                              ),
                                                            ],
                                                          ),
                                                          child: ElevatedButton
                                                              .icon(
                                                            icon: const Icon(
                                                                Icons.feedback,
                                                                size: 18),
                                                            label: Text(
                                                              "Give Feedback",
                                                              style: GoogleFonts
                                                                  .inter(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                            onPressed: () =>
                                                                submitFeedback(
                                                                    context,
                                                                    i['id']),
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              backgroundColor:
                                                                  Colors.amber,
                                                              foregroundColor:
                                                                  Colors
                                                                      .black87,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          14,
                                                                      horizontal:
                                                                          20),
                                                              shape:
                                                                  RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12),
                                                              ),
                                                              minimumSize:
                                                                  const Size(
                                                                      double
                                                                          .infinity,
                                                                      48),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      {required IconData icon,
      required String text,
      required ThemeProvider themeProvider}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: themeProvider.isDarkMode
              ? Colors.grey.shade400
              : Colors.grey.shade500,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // NEW: Filter chip widget
  Widget _buildFilterChip(
      String label, String value, ThemeProvider themeProvider) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          color: isSelected
              ? Colors.white
              : themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      backgroundColor: themeProvider.isDarkMode
          ? Colors.grey.shade800.withValues(alpha: 0.5)
          : Colors.grey.shade200,
      selectedColor: const Color.fromRGBO(151, 18, 8, 1),
      checkmarkColor: Colors.white,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? const Color.fromRGBO(151, 18, 8, 1)
              : themeProvider.isDarkMode
                  ? Colors.grey.shade700
                  : Colors.grey.shade300,
        ),
      ),
    );
  }

  // NEW: Status badge widget
  Widget _buildStatusBadge(
      String label, Color color, ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade300
                  : Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Reusable action button widget
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// NEW: Feedback Dialog
// NEW: Feedback Summary Dialog (Updated to show all fields)
class FeedbackSummaryDialog extends StatelessWidget {
  final List<Map<String, dynamic>> feedback;

  const FeedbackSummaryDialog({super.key, required this.feedback});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return AlertDialog(
      title: Text(
        "Interview Feedback Summary",
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: feedback.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.feedback_outlined,
                      size: 48,
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No feedback submitted yet",
                      style: GoogleFonts.inter(
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: feedback.length,
                itemBuilder: (context, index) {
                  final item = feedback[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade800.withValues(alpha: 0.5)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Interviewer info
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue.withValues(alpha: 0.1),
                              child: Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['interviewer_name'] ?? 'Unknown',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(
                                      DateTime.parse(item['submitted_at'] ??
                                          DateTime.now().toIso8601String()),
                                    ),
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
                          ],
                        ),

                        // Ratings
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildRatingItem("Overall", item['overall_rating']),
                            if (item['technical_skills'] != null)
                              _buildRatingItem(
                                  "Tech", item['technical_skills']),
                            if (item['communication'] != null)
                              _buildRatingItem("Comm", item['communication']),
                            if (item['culture_fit'] != null)
                              _buildRatingItem("Culture", item['culture_fit']),
                            if (item['problem_solving'] != null)
                              _buildRatingItem(
                                  "Problem", item['problem_solving']),
                            if (item['experience_relevance'] != null)
                              _buildRatingItem(
                                  "Exp", item['experience_relevance']),
                            if (item['average_rating'] != null)
                              _buildRatingItem("Avg", item['average_rating']),
                          ],
                        ),

                        // Recommendation
                        if (item['recommendation'] != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getRecommendationColor(
                                      item['recommendation'])
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getRecommendationColor(
                                        item['recommendation'])
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getRecommendationIcon(
                                      item['recommendation']),
                                  size: 14,
                                  color: _getRecommendationColor(
                                      item['recommendation']),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatRecommendation(item['recommendation']),
                                  style: GoogleFonts.inter(
                                    color: _getRecommendationColor(
                                        item['recommendation']),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Notes
                        if (item['strengths'] != null &&
                            item['strengths'].isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            "Strengths:",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            item['strengths'],
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],

                        if (item['weaknesses'] != null &&
                            item['weaknesses'].isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            "Areas for Improvement:",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            item['weaknesses'],
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],

                        if (item['additional_notes'] != null &&
                            item['additional_notes'].isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            "Additional Notes:",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            item['additional_notes'],
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],

                        if (item['private_notes'] != null &&
                            item['private_notes'].isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.lock,
                                      size: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Private Notes (Hiring Team Only):",
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['private_notes'],
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
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
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Close",
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: const Color.fromRGBO(151, 18, 8, 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingItem(String label, dynamic rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getRatingColor(rating),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            rating?.toString() ?? '-',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRatingColor(dynamic rating) {
    if (rating == null) return Colors.grey;
    final value = rating is int ? rating : double.parse(rating.toString());
    if (value >= 4.5) return Colors.green.shade700;
    if (value >= 4) return Colors.green.shade500;
    if (value >= 3.5) return Colors.green.shade300;
    if (value >= 3) return Colors.amber.shade600;
    if (value >= 2.5) return Colors.orange.shade600;
    if (value >= 2) return Colors.orange.shade800;
    return Colors.red.shade600;
  }

  Color _getRecommendationColor(String recommendation) {
    switch (recommendation) {
      case 'strong_hire':
        return Colors.green.shade800;
      case 'hire':
        return Colors.green;
      case 'no_hire':
        return Colors.orange;
      case 'strong_no_hire':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getRecommendationIcon(String recommendation) {
    switch (recommendation) {
      case 'strong_hire':
        return Icons.star;
      case 'hire':
        return Icons.thumb_up;
      case 'no_hire':
        return Icons.thumb_down;
      case 'strong_no_hire':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _formatRecommendation(String recommendation) {
    switch (recommendation) {
      case 'strong_hire':
        return 'Strong Hire';
      case 'hire':
        return 'Hire';
      case 'no_hire':
        return 'No Hire';
      case 'strong_no_hire':
        return 'Strong No Hire';
      case 'not_sure':
        return 'Not Sure';
      default:
        return recommendation.replaceAll('_', ' ');
    }
  }
}

// NEW: Updated Feedback Dialog that matches your AdminService method
class FeedbackDialog extends StatefulWidget {
  final int interviewId;

  const FeedbackDialog({super.key, required this.interviewId});

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  int _overallRating = 3;
  String _recommendation = 'hire';

  // Additional rating fields (1-5)
  int? _technicalSkills;
  int? _communication;
  int? _cultureFit;
  int? _problemSolving;
  int? _experienceRelevance;

  // Text feedback
  String _strengths = '';
  String _weaknesses = '';
  String _additionalNotes = '';
  String _privateNotes = '';

  final AdminService _adminService = AdminService();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return AlertDialog(
      title: Text(
        "Submit Interview Feedback",
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall Rating
              _buildRatingSection(
                title: "Overall Rating *",
                currentRating: _overallRating,
                onRatingChanged: (rating) {
                  setState(() {
                    _overallRating = rating;
                  });
                },
                required: true,
              ),

              const SizedBox(height: 20),

              // Recommendation (required)
              Text(
                "Recommendation *",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade300
                      : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _recommendation,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'strong_hire',
                    child: Row(
                      children: [
                        Icon(Icons.star, color: Colors.green[800]),
                        const SizedBox(width: 8),
                        Text("Strong Hire", style: GoogleFonts.inter()),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'hire',
                    child: Row(
                      children: [
                        Icon(Icons.thumb_up, color: Colors.green),
                        const SizedBox(width: 8),
                        Text("Hire", style: GoogleFonts.inter()),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'no_hire',
                    child: Row(
                      children: [
                        Icon(Icons.thumb_down, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text("No Hire", style: GoogleFonts.inter()),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'strong_no_hire',
                    child: Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red),
                        const SizedBox(width: 8),
                        Text("Strong No Hire", style: GoogleFonts.inter()),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'not_sure',
                    child: Row(
                      children: [
                        Icon(Icons.help, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text("Not Sure", style: GoogleFonts.inter()),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _recommendation = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a recommendation';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Additional Ratings (Optional)
              Text(
                "Additional Ratings (Optional)",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.isDarkMode
                      ? Colors.grey.shade300
                      : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),

              _buildOptionalRating(
                label: "Technical Skills",
                currentRating: _technicalSkills,
                onRatingChanged: (rating) {
                  setState(() {
                    _technicalSkills = rating;
                  });
                },
              ),

              _buildOptionalRating(
                label: "Communication",
                currentRating: _communication,
                onRatingChanged: (rating) {
                  setState(() {
                    _communication = rating;
                  });
                },
              ),

              _buildOptionalRating(
                label: "Culture Fit",
                currentRating: _cultureFit,
                onRatingChanged: (rating) {
                  setState(() {
                    _cultureFit = rating;
                  });
                },
              ),

              _buildOptionalRating(
                label: "Problem Solving",
                currentRating: _problemSolving,
                onRatingChanged: (rating) {
                  setState(() {
                    _problemSolving = rating;
                  });
                },
              ),

              _buildOptionalRating(
                label: "Experience Relevance",
                currentRating: _experienceRelevance,
                onRatingChanged: (rating) {
                  setState(() {
                    _experienceRelevance = rating;
                  });
                },
              ),

              const SizedBox(height: 20),

              // Strengths
              TextFormField(
                decoration: InputDecoration(
                  labelText: "Strengths",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
                onChanged: (value) => _strengths = value,
              ),

              const SizedBox(height: 16),

              // Weaknesses / Areas for Improvement
              TextFormField(
                decoration: InputDecoration(
                  labelText: "Areas for Improvement",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
                onChanged: (value) => _weaknesses = value,
              ),

              const SizedBox(height: 16),

              // Additional Notes
              TextFormField(
                decoration: InputDecoration(
                  labelText: "Additional Notes",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
                onChanged: (value) => _additionalNotes = value,
              ),

              const SizedBox(height: 16),

              // Private Notes (Only visible to hiring team)
              TextFormField(
                decoration: InputDecoration(
                  labelText: "Private Notes (Hiring Team Only)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText:
                      "These notes are only visible to hiring managers and admins",
                ),
                maxLines: 2,
                onChanged: (value) => _privateNotes = value,
              ),

              const SizedBox(height: 20),

              // Required fields note
              Text(
                "* Required fields",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: Text(
            "Cancel",
            style: GoogleFonts.inter(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _submitting
              ? null
              : () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() {
                      _submitting = true;
                    });

                    try {
                      // Call your existing AdminService method with all parameters
                      await _adminService.submitInterviewFeedback(
                        interviewId: widget.interviewId,
                        overallRating: _overallRating,
                        recommendation: _recommendation,
                        technicalSkills: _technicalSkills,
                        communication: _communication,
                        cultureFit: _cultureFit,
                        problemSolving: _problemSolving,
                        experienceRelevance: _experienceRelevance,
                        strengths: _strengths.isNotEmpty ? _strengths : null,
                        weaknesses: _weaknesses.isNotEmpty ? _weaknesses : null,
                        additionalNotes: _additionalNotes.isNotEmpty
                            ? _additionalNotes
                            : null,
                        privateNotes:
                            _privateNotes.isNotEmpty ? _privateNotes : null,
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Feedback submitted successfully"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(context, true);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Failed to submit feedback: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (context.mounted) {
                        setState(() {
                          _submitting = false;
                        });
                      }
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(151, 18, 8, 1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  "Submit Feedback",
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }

  Widget _buildRatingSection({
    required String title,
    required int currentRating,
    required Function(int) onRatingChanged,
    bool required = false,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade300
                  : Colors.grey.shade700,
            ),
            children: required
                ? [
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red),
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
            final ratingValue = index + 1;
            return GestureDetector(
              onTap: () => onRatingChanged(ratingValue),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: currentRating >= ratingValue
                      ? _getRatingColor(ratingValue)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: currentRating >= ratingValue
                        ? _getRatingColor(ratingValue)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: currentRating >= ratingValue
                          ? Colors.white
                          : Colors.grey.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      ratingValue.toString(),
                      style: GoogleFonts.inter(
                        color: currentRating >= ratingValue
                            ? Colors.white
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildOptionalRating({
    required String label,
    required int? currentRating,
    required Function(int) onRatingChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Row(
          children: List.generate(5, (index) {
            final ratingValue = index + 1;
            final isSelected = currentRating == ratingValue;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: OutlinedButton(
                  onPressed: () => onRatingChanged(ratingValue),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isSelected
                        ? _getRatingColor(ratingValue)
                        : Colors.transparent,
                    foregroundColor:
                        isSelected ? Colors.white : Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? _getRatingColor(ratingValue)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    ratingValue.toString(),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 5:
        return Colors.green.shade700;
      case 4:
        return Colors.green.shade500;
      case 3:
        return Colors.amber.shade600;
      case 2:
        return Colors.orange.shade600;
      case 1:
        return Colors.red.shade600;
      default:
        return Colors.grey;
    }
  }
}
