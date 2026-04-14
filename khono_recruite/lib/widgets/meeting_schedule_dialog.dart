import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:khono_recruite/constants/app_colors.dart';
import 'package:khono_recruite/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/team_member.dart';

class MeetingScheduleDialog extends StatefulWidget {
  final List<TeamMember> teamMembers;
  final int? threadId;

  const MeetingScheduleDialog({
    super.key,
    required this.teamMembers,
    this.threadId,
  });

  @override
  State<MeetingScheduleDialog> createState() => _MeetingScheduleDialogState();
}

class _MeetingScheduleDialogState extends State<MeetingScheduleDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _duration = 60; // Default 60 minutes
  List<int> _selectedParticipantIds = [];

  @override
  void initState() {
    super.initState();
    // Default to tomorrow at 10:00 AM
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _selectedDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String _formatDateTime() {
    if (_selectedDate == null || _selectedTime == null) {
      return 'Select date and time';
    }

    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    return DateFormat('MMM dd, yyyy at hh:mm a').format(dateTime);
  }

  String _getScheduledAtIso() {
    if (_selectedDate == null || _selectedTime == null) {
      return '';
    }

    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    ).toUtc();

    return dateTime.toIso8601String();
  }

  bool _isFormValid() {
    return _titleController.text.trim().isNotEmpty &&
        _selectedDate != null &&
        _selectedTime != null &&
        _selectedParticipantIds.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color:
              themeProvider.isDarkMode ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Schedule Meeting',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Form Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Meeting Title *',
                        hintText: 'Enter meeting title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: themeProvider.isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade50,
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Meeting description or agenda',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: themeProvider.isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade50,
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 16),

                    // Date & Time
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate ??
                                    DateTime.now().add(const Duration(days: 1)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setState(() => _selectedDate = date);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                                color: themeProvider.isDarkMode
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade50,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedDate != null
                                          ? DateFormat('MMM dd, yyyy')
                                              .format(_selectedDate!)
                                          : 'Select date',
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _selectedTime ??
                                    const TimeOfDay(hour: 10, minute: 0),
                              );
                              if (time != null) {
                                setState(() => _selectedTime = time);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                                color: themeProvider.isDarkMode
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade50,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedTime != null
                                          ? _selectedTime!.format(context)
                                          : 'Select time',
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDateTime(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Duration
                    Text(
                      'Duration',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [30, 60, 90, 120].map((minutes) {
                        final isSelected = _duration == minutes;
                        return Expanded(
                          child: Padding(
                            padding:
                                EdgeInsets.only(right: minutes == 120 ? 0 : 8),
                            child: InkWell(
                              onTap: () => setState(() => _duration = minutes),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : themeProvider.isDarkMode
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${minutes} min',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: isSelected
                                        ? Colors.white
                                        : themeProvider.isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Location
                    TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Location (Optional)',
                        hintText: 'Meeting room or video conference link',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: themeProvider.isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade50,
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 16),

                    // Participants
                    Text(
                      'Participants *',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: themeProvider.isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade50,
                      ),
                      child: Column(
                        children: widget.teamMembers.map((member) {
                          final isSelected =
                              _selectedParticipantIds.contains(member.id);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedParticipantIds.add(member.id);
                                } else {
                                  _selectedParticipantIds.remove(member.id);
                                }
                              });
                            },
                            title: Text(
                              member.name,
                              style: GoogleFonts.poppins(),
                            ),
                            subtitle: Text(
                              member.role,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            activeColor: AppColors.primary,
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isFormValid()
                                ? () {
                                    final meetingData = {
                                      'title': _titleController.text.trim(),
                                      'description':
                                          _descriptionController.text.trim(),
                                      'scheduled_at': _getScheduledAtIso(),
                                      'duration_minutes': _duration,
                                      'location':
                                          _locationController.text.trim(),
                                      'participant_ids':
                                          _selectedParticipantIds,
                                      if (widget.threadId != null)
                                        'thread_id': widget.threadId,
                                    };
                                    Navigator.of(context).pop(meetingData);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Schedule Meeting',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
