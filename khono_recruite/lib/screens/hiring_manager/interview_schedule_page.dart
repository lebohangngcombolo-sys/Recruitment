import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';
import '../../providers/theme_provider.dart';
import '../../utils/api_endpoints.dart';

class ScheduleInterviewPage extends StatefulWidget {
  final int candidateId;
  const ScheduleInterviewPage({Key? key, required this.candidateId})
      : super(key: key);

  @override
  State<ScheduleInterviewPage> createState() => _ScheduleInterviewPageState();
}

class _ScheduleInterviewPageState extends State<ScheduleInterviewPage> {
  final _formKey = GlobalKey<FormState>();
  final AdminService _admin = AdminService();
  List<dynamic> applications = [];
  String? selectedApplication;
  DateTime? selectedDateTime;
  int? selectedSlotId;
  List<Map<String, dynamic>> availableSlots = [];
  bool loadingSlots = false;
  String interviewType = "Online";
  TextEditingController meetingLinkController = TextEditingController();

  bool isSubmitting = false;
  String message = "";

  Future<void> _openManageAvailability() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final primaryRed = const Color.fromRGBO(151, 18, 8, 1);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ManageSlotsDialog(
        admin: _admin,
        themeProvider: themeProvider,
        primaryRed: primaryRed,
        jobId: () {
          if (selectedApplication == null) return null;
          for (final a in applications) {
            if (a is Map && a["application_id"].toString() == selectedApplication) {
              final j = a["job_id"];
              return j is int ? j : (j != null ? int.tryParse(j.toString()) : null);
            }
          }
          return null;
        }(),
        onSlotChanged: () {
          if (selectedApplication != null) fetchAvailableSlots();
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    fetchApplications();
  }

  Future<void> fetchApplications() async {
    try {
      final res = await AuthService.authorizedGet(
          "${ApiEndpoints.adminBase}/applications?candidate_id=${widget.candidateId}");
      if (res.statusCode == 200) {
        setState(() => applications = jsonDecode(res.body));
      } else {
        setState(
            () => message = "Failed to fetch applications: ${res.statusCode}");
      }
    } catch (e) {
      setState(() => message = "Error fetching applications: $e");
    }
  }

  Future<void> fetchAvailableSlots() async {
    if (selectedApplication == null) {
      setState(() {
        availableSlots = [];
        selectedSlotId = null;
      });
      return;
    }
    Map<String, dynamic>? app;
    for (final a in applications) {
      if (a is Map && a["application_id"].toString() == selectedApplication) {
        app = Map<String, dynamic>.from(a);
        break;
      }
    }
    final jobId = app?["job_id"];
    setState(() => loadingSlots = true);
    try {
      final slots = await _admin.getAvailableInterviewSlots(
        requisitionId: jobId is int ? jobId : (jobId != null ? int.tryParse(jobId.toString()) : null),
      );
      setState(() {
        availableSlots = List<Map<String, dynamic>>.from(slots);
        loadingSlots = false;
        selectedSlotId = null;
      });
    } catch (e) {
      setState(() {
        availableSlots = [];
        loadingSlots = false;
        selectedSlotId = null;
        message = "Could not load slots: $e";
      });
    }
  }

  Future<void> pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      selectedDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      selectedSlotId = null;
    });
  }

  Future<void> scheduleInterview() async {
    if (!_formKey.currentState!.validate()) return;

    final useSlot = selectedSlotId != null;
    if (!useSlot && selectedDateTime == null) {
      setState(() => message = "Pick an available slot or choose a date & time.");
      return;
    }

    setState(() {
      isSubmitting = true;
      message = "";
    });

    final Map<String, dynamic> data = {
      "candidate_id": widget.candidateId,
      "application_id": int.tryParse(selectedApplication ?? "0") ?? 0,
    };
    if (useSlot) {
      data["slot_id"] = selectedSlotId;
    } else {
      data["scheduled_time"] = selectedDateTime!.toIso8601String();
      data["interview_type"] = interviewType;
      data["meeting_link"] =
          interviewType == "Online" ? meetingLinkController.text : null;
    }

    try {
      final result = await _admin.scheduleInterview(data);
      setState(() => message =
          result["message"] ?? "Interview scheduled successfully.");
    } catch (e) {
      setState(() => message = "Request failed: $e");
    }

    setState(() => isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryRed = const Color.fromRGBO(151, 18, 8, 1);

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
              "Schedule Interview",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
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
          body: Container(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 24),
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
                            color: primaryRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.calendar_today,
                            color: primaryRed,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Schedule Interview",
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: themeProvider.isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Set up interview details for the candidate",
                                style: GoogleFonts.inter(
                                  color: themeProvider.isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Message Alert
                  if (message.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: (message.startsWith("Error")
                                ? Colors.red.shade50
                                : Colors.green.shade50)
                            .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: message.startsWith("Error")
                              ? Colors.red.shade200
                              : Colors.green.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            message.startsWith("Error")
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            color: message.startsWith("Error")
                                ? Colors.red
                                : Colors.green.shade600,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              message,
                              style: GoogleFonts.inter(
                                color: message.startsWith("Error")
                                    ? Colors.red
                                    : Colors.green.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Form Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Job Application Dropdown
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: (themeProvider.isDarkMode
                                      ? const Color(0xFF14131E)
                                      : Colors.white)
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.work_outline,
                                      color: primaryRed,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Job Application",
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: themeProvider.isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedApplication,
                                  decoration: InputDecoration(
                                    labelText: "Select Job Application",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: primaryRed,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: (themeProvider.isDarkMode
                                            ? const Color(0xFF14131E)
                                            : Colors.grey.shade50)
                                        .withValues(alpha: 0.9),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    labelStyle: GoogleFonts.inter(
                                      color: themeProvider.isDarkMode
                                          ? Colors.grey.shade400
                                          : Colors.black87,
                                    ),
                                  ),
                                  items: applications.map((a) {
                                    final jobTitle =
                                        a["job_title"] ?? "Unknown Position";
                                    return DropdownMenuItem<String>(
                                      value: a["application_id"].toString(),
                                      child: Text(
                                        jobTitle,
                                        style: GoogleFonts.inter(
                                          color: themeProvider.isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      selectedApplication = val;
                                      selectedSlotId = null;
                                      selectedDateTime = null;
                                    });
                                    fetchAvailableSlots();
                                  },
                                  validator: (val) => val == null
                                      ? "Select a job application"
                                      : null,
                                  style: GoogleFonts.inter(
                                    color: themeProvider.isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  dropdownColor: (themeProvider.isDarkMode
                                          ? const Color(0xFF14131E)
                                          : Colors.white)
                                      .withValues(alpha: 0.95),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Pick from available slots (when application selected)
                          if (selectedApplication != null) ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: (themeProvider.isDarkMode
                                        ? const Color(0xFF14131E)
                                        : Colors.white)
                                    .withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.event_available,
                                        color: primaryRed,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Pick from your available slots",
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            color: themeProvider.isDarkMode
                                                ? Colors.white
                                                : Colors.black87,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: _openManageAvailability,
                                        icon: Icon(Icons.add, size: 18, color: primaryRed),
                                        label: Text(
                                          "Manage availability",
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: primaryRed,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (loadingSlots)
                                    const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    )
                                  else if (availableSlots.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        "No available slots. Add slots under Manage availability, or use custom date & time below.",
                                        style: GoogleFonts.inter(
                                          color: themeProvider.isDarkMode
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    )
                                  else
                                    ...availableSlots.map((slot) {
                                      final id = slot["id"] as int?;
                                      final start = slot["start_time"];
                                      DateTime? startDt;
                                      if (start != null) {
                                        if (start is String) {
                                          startDt = DateTime.tryParse(start);
                                        }
                                      }
                                      final end = slot["end_time"];
                                      DateTime? endDt;
                                      if (end != null) {
                                        if (end is String) {
                                          endDt = DateTime.tryParse(end);
                                        }
                                      }
                                      final type =
                                          slot["interview_type"] ?? "Online";
                                      final link =
                                          slot["meeting_link"] as String?;
                                      final selected = id != null &&
                                          selectedSlotId == id;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 8.0),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => setState(() {
                                              selectedSlotId = id;
                                              selectedDateTime = null;
                                            }),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: selected
                                                    ? primaryRed
                                                        .withValues(alpha: 0.15)
                                                    : (themeProvider.isDarkMode
                                                            ? const Color(
                                                                0xFF14131E)
                                                            : Colors.grey
                                                                .shade50)
                                                        .withValues(alpha: 0.9),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: selected
                                                      ? primaryRed
                                                      : (themeProvider
                                                              .isDarkMode
                                                          ? Colors.grey.shade800
                                                          : Colors.grey
                                                              .shade300),
                                                  width: selected ? 2 : 1,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    selected
                                                        ? Icons
                                                            .radio_button_checked
                                                        : Icons
                                                            .radio_button_off,
                                                    color: selected
                                                        ? primaryRed
                                                        : Colors.grey.shade600,
                                                    size: 22,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          startDt != null
                                                              ? "${startDt.toLocal()}"
                                                              : "Slot",
                                                          style: GoogleFonts
                                                              .inter(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: themeProvider
                                                                    .isDarkMode
                                                                ? Colors.white
                                                                : Colors
                                                                    .black87,
                                                          ),
                                                        ),
                                                        if (endDt != null)
                                                          Text(
                                                            "Until ${endDt.toLocal()}",
                                                            style: GoogleFonts
                                                                .inter(
                                                              fontSize: 12,
                                                              color: themeProvider
                                                                      .isDarkMode
                                                                  ? Colors
                                                                      .grey
                                                                      .shade400
                                                                  : Colors
                                                                      .grey
                                                                      .shade600,
                                                            ),
                                                          ),
                                                        if (type.isNotEmpty)
                                                          Text(
                                                            type,
                                                            style: GoogleFonts
                                                                .inter(
                                                              fontSize: 12,
                                                              color: primaryRed,
                                                            ),
                                                          ),
                                                        if (link != null &&
                                                            link.isNotEmpty)
                                                          Text(
                                                            "Link: $link",
                                                            style: GoogleFonts
                                                                .inter(
                                                              fontSize: 11,
                                                              color: themeProvider
                                                                      .isDarkMode
                                                                  ? Colors
                                                                      .grey
                                                                      .shade400
                                                                  : Colors
                                                                      .grey
                                                                      .shade600,
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
                                          ),
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Or choose custom date & time
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: (themeProvider.isDarkMode
                                      ? const Color(0xFF14131E)
                                      : Colors.white)
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      color: primaryRed,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Or choose custom date & time",
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: themeProvider.isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: pickDateTime,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: (themeProvider.isDarkMode
                                                ? const Color(0xFF14131E)
                                                : Colors.grey.shade50)
                                            .withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: themeProvider.isDarkMode
                                              ? Colors.grey.shade800
                                              : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            color: primaryRed,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              selectedDateTime != null
                                                  ? "Scheduled for: ${selectedDateTime!.toLocal()}"
                                                  : "Pick date and time",
                                              style: GoogleFonts.inter(
                                                color: selectedDateTime != null
                                                    ? (themeProvider.isDarkMode
                                                        ? Colors.white
                                                        : Colors.black87)
                                                    : Colors.grey.shade600,
                                                fontWeight:
                                                    selectedDateTime != null
                                                        ? FontWeight.w500
                                                        : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_drop_down,
                                            color: Colors.grey.shade500,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Interview Type & Meeting Link
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: (themeProvider.isDarkMode
                                      ? const Color(0xFF14131E)
                                      : Colors.white)
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.video_call_outlined,
                                      color: primaryRed,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Interview Details",
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: themeProvider.isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  initialValue: interviewType,
                                  decoration: InputDecoration(
                                    labelText: "Interview Type",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: primaryRed,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: (themeProvider.isDarkMode
                                            ? const Color(0xFF14131E)
                                            : Colors.grey.shade50)
                                        .withValues(alpha: 0.9),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    labelStyle: GoogleFonts.inter(
                                      color: themeProvider.isDarkMode
                                          ? Colors.grey.shade400
                                          : Colors.black87,
                                    ),
                                  ),
                                  items: ["Online", "In-Person", "Phone"]
                                      .map((type) => DropdownMenuItem(
                                            value: type,
                                            child: Text(
                                              type,
                                              style: GoogleFonts.inter(
                                                color: themeProvider.isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (val) =>
                                      setState(() => interviewType = val!),
                                  style: GoogleFonts.inter(
                                    color: themeProvider.isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  dropdownColor: (themeProvider.isDarkMode
                                          ? const Color(0xFF14131E)
                                          : Colors.white)
                                      .withValues(alpha: 0.95),
                                ),
                                const SizedBox(height: 16),
                                if (interviewType == "Online")
                                  TextFormField(
                                    controller: meetingLinkController,
                                    decoration: InputDecoration(
                                      labelText: "Meeting Link (optional)",
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: primaryRed,
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: (themeProvider.isDarkMode
                                              ? const Color(0xFF14131E)
                                              : Colors.grey.shade50)
                                          .withValues(alpha: 0.9),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                      labelStyle: GoogleFonts.inter(
                                        color: themeProvider.isDarkMode
                                            ? Colors.grey.shade400
                                            : Colors.black87,
                                      ),
                                    ),
                                    style: GoogleFonts.inter(
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Schedule Button
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryRed.withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              icon: Icon(
                                isSubmitting
                                    ? Icons.hourglass_top
                                    : Icons.schedule,
                                size: 20,
                              ),
                              label: Text(
                                isSubmitting
                                    ? "Scheduling Interview..."
                                    : "Schedule Interview",
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              onPressed:
                                  isSubmitting ? null : scheduleInterview,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryRed,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(60),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
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

class _ManageSlotsDialog extends StatefulWidget {
  final AdminService admin;
  final ThemeProvider themeProvider;
  final Color primaryRed;
  final int? jobId;
  final VoidCallback onSlotChanged;

  const _ManageSlotsDialog({
    required this.admin,
    required this.themeProvider,
    required this.primaryRed,
    required this.jobId,
    required this.onSlotChanged,
  });

  @override
  State<_ManageSlotsDialog> createState() => _ManageSlotsDialogState();
}

class _ManageSlotsDialogState extends State<_ManageSlotsDialog> {
  List<Map<String, dynamic>> _slots = [];
  bool _loading = true;
  String? _error;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final slots = await widget.admin.getInterviewSlots(
        requisitionId: widget.jobId,
        fromNow: true,
      );
      if (mounted) setState(() {
        _slots = slots;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() {
        _slots = [];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _addSlot() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (startTime == null || !mounted) return;
    int endHour = startTime.hour;
    int endMin = startTime.minute + 30;
    if (endMin >= 60) {
      endMin -= 60;
      endHour += 1;
    }
    if (endHour >= 24) endHour = 23;
    final endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: endHour, minute: endMin),
    );
    if (endTime == null || !mounted) return;
    final start = DateTime(date.year, date.month, date.day, startTime.hour, startTime.minute);
    var end = DateTime(date.year, date.month, date.day, endTime.hour, endTime.minute);
    if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
      end = start.add(const Duration(minutes: 30));
    }
    try {
      await widget.admin.createInterviewSlot(
        startTime: start,
        endTime: end,
        interviewType: 'Online',
        requisitionId: widget.jobId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Slot added')),
        );
        await _load();
        widget.onSlotChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteSlot(int slotId, bool isAvailable) async {
    if (!isAvailable) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete slot?'),
        content: const Text('This slot will be removed from your availability.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await widget.admin.deleteInterviewSlot(slotId);
      if (mounted) {
        await _load();
        widget.onSlotChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryRed = widget.primaryRed;
    return AlertDialog(
      title: Text(
        'Manage availability',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 400,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: GoogleFonts.inter(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ..._slots.map((slot) {
                    final id = slot['id'] as int?;
                    final start = slot['start_time'];
                    final available = slot['is_available'] == true;
                    DateTime? startDt;
                    if (start is String) startDt = DateTime.tryParse(start);
                    return ListTile(
                      title: Text(
                        startDt != null ? '${startDt.toLocal()}' : 'Slot',
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                      subtitle: Text(
                        available ? 'Available' : 'Booked',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: available ? Colors.green : Colors.grey,
                        ),
                      ),
                      trailing: available && id != null
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteSlot(id, true),
                            )
                          : null,
                    );
                  }),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _addSlot,
                    icon: Icon(Icons.add, size: 20, color: primaryRed),
                    label: Text(
                      'Add slot',
                      style: GoogleFonts.inter(color: primaryRed, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryRed,
                      side: BorderSide(color: primaryRed),
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
