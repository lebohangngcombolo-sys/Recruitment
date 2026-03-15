import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../utils/api_endpoints.dart';
import '../../providers/theme_provider.dart';

class InterviewListScreen extends StatefulWidget {
  const InterviewListScreen({super.key});

  @override
  State<InterviewListScreen> createState() => _InterviewListScreenState();
}

class _InterviewListScreenState extends State<InterviewListScreen> {
  List<dynamic> interviews = [];
  List<dynamic> availableSlots = [];
  bool loading = true;
  bool slotsLoading = false;

  @override
  void initState() {
    super.initState();
    fetchInterviews();
    fetchAvailableSlots();
  }

  Future<void> fetchAvailableSlots() async {
    setState(() => slotsLoading = true);
    try {
      final response = await AuthService.authorizedGet(
        ApiEndpoints.getInterviewSlotsAvailable,
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            availableSlots = decoded['slots'] ?? [];
            slotsLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => slotsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => slotsLoading = false);
    }
  }

  Future<void> fetchInterviews() async {
    setState(() => loading = true);
    try {
      final response = await AuthService.authorizedGet(
        ApiEndpoints.getInterviewsAll,
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> cancelInterview(int id) async {
    try {
      final response = await AuthService.authorizedDelete(ApiEndpoints.cancelInterview(id));

      if (response.statusCode == 200) {
        // Success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Interview cancelled successfully")),
        );
        // Refresh interview list
        fetchInterviews();
      } else {
        // Parse backend error message
        final err = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err['error'] ?? 'Failed to cancel interview')),
        );
      }
    } catch (e) {
      // Network or unexpected errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> rescheduleInterview(int id, DateTime newTime) async {
    try {
      final response = await AuthService.authorizedPut(
        ApiEndpoints.rescheduleInterview(id),
        {"scheduled_time": newTime.toIso8601String()},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Interview rescheduled")));
        fetchInterviews();
        fetchAvailableSlots();
      } else {
        final err = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err['error'] ?? 'Failed to reschedule')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> rescheduleToSlot(int interviewId, int slotId) async {
    try {
      final response = await AuthService.authorizedPut(
        ApiEndpoints.rescheduleInterview(interviewId),
        {"slot_id": slotId},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Interview rescheduled to selected slot")));
          Navigator.of(context).pop(true);
          fetchInterviews();
          fetchAvailableSlots();
        }
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _openBookingLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }

  void showRescheduleDialog(int id) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        final isDark = themeProvider.isDarkMode;
        final bg = (isDark ? const Color(0xFF14131E) : Colors.white).withValues(alpha: 0.98);
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  'Reschedule interview',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      Text(
                        'Pick date & time',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('Choose date and time'),
                        onPressed: () async {
                          Navigator.pop(context);
                          final picked = await showDatePicker(
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
                            if (time != null && mounted) {
                              final newDateTime = DateTime(
                                picked.year, picked.month, picked.day,
                                time.hour, time.minute,
                              );
                              rescheduleInterview(id, newDateTime);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Or use an available slot',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if (slotsLoading)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (availableSlots.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'No available slots. Add slots in your calendar or pick date & time above.',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                          ),
                        )
                      else
                        ...availableSlots.map<Widget>((slot) {
                          final start = slot['start_time'] != null
                              ? DateFormat('MMM d, yyyy · HH:mm').format(DateTime.parse(slot['start_time']))
                              : '—';
                          return ListTile(
                            title: Text(start, style: GoogleFonts.poppins(fontSize: 13)),
                            trailing: TextButton(
                              onPressed: () => rescheduleToSlot(id, slot['id'] as int),
                              child: const Text('Use this slot'),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result == true) {}
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
      default:
        return Colors.grey;
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
                                    "${interviews.length} interviews scheduled",
                                    style: GoogleFonts.inter(
                                      color: themeProvider.isDarkMode
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (availableSlots.isNotEmpty)
                                    Text(
                                      "${availableSlots.length} available slots (use when rescheduling)",
                                      style: GoogleFonts.inter(
                                        color: themeProvider.isDarkMode
                                            ? Colors.grey.shade500
                                            : Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              const Spacer(),
                              IconButton(
                                icon: slotsLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.refresh),
                                onPressed: slotsLoading ? null : () => fetchAvailableSlots(),
                                tooltip: 'Refresh available slots',
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: redColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "Active",
                                  style: GoogleFonts.inter(
                                    color: redColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
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
                              children: interviews.map((i) {
                                final scheduled = i['scheduled_time'] != null
                                    ? DateFormat('MMM dd, yyyy • HH:mm').format(
                                        DateTime.parse(i['scheduled_time']))
                                    : 'Not Scheduled';

                                final statusRaw = i['status'] ?? 'scheduled';
                                final statusLabel = i['status_label'] ?? statusRaw.toString().replaceAll('_', ' ').split(' ').map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}').join(' ');
                                final status = statusLabel is String ? statusLabel : (i['status'] ?? 'Scheduled').toString();
                                final statusColor = getStatusColor(statusRaw is String ? statusRaw : 'scheduled');
                                final bookingLink = i['booking_link'] ?? i['meeting_link'];

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
                                        color: Colors.black
                                            .withValues(alpha: 0.08),
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
                                          color: statusColor.withValues(
                                              alpha: 0.1),
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
                                                color: statusColor.withValues(
                                                    alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                status.toUpperCase(),
                                                style: GoogleFonts.inter(
                                                  color: statusColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
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
                                                    color: redColor.withValues(
                                                        alpha: 0.1),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color:
                                                          redColor.withValues(
                                                              alpha: 0.2),
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
                                                                  .withValues(
                                                                      alpha:
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
                                                      color: Colors.green,
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
                                                  if (bookingLink != null && bookingLink.toString().isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    OutlinedButton.icon(
                                                      icon: const Icon(Icons.link, size: 16),
                                                      label: Text(
                                                        'Booking link / Join interview',
                                                        style: GoogleFonts.poppins(fontSize: 12),
                                                      ),
                                                      onPressed: () => _openBookingLink(bookingLink.toString()),
                                                      style: OutlinedButton.styleFrom(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        foregroundColor: redColor,
                                                        side: BorderSide(color: redColor),
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 16),
                                                  // Action Buttons
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
                                                                    .red
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
                                                          child: ElevatedButton
                                                              .icon(
                                                            icon: const Icon(
                                                                Icons
                                                                    .cancel_outlined,
                                                                size: 16),
                                                            label: Text(
                                                              "Cancel",
                                                              style: GoogleFonts
                                                                  .inter(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                            onPressed: () =>
                                                                cancelInterview(
                                                                    i['id']),
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              backgroundColor:
                                                                  Colors.red,
                                                              foregroundColor:
                                                                  Colors.white,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          12),
                                                              shape:
                                                                  RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
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
                                                                color: redColor
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
                                                          child: ElevatedButton
                                                              .icon(
                                                            icon: const Icon(
                                                                Icons.schedule,
                                                                size: 16),
                                                            label: Text(
                                                              "Reschedule",
                                                              style: GoogleFonts
                                                                  .inter(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                            onPressed: () =>
                                                                showRescheduleDialog(
                                                                    i['id']),
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              backgroundColor:
                                                                  redColor,
                                                              foregroundColor:
                                                                  Colors.white,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          12),
                                                              shape:
                                                                  RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12),
                                                              ),
                                                            ),
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
}
