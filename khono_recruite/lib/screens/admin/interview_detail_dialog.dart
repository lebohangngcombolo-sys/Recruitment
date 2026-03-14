import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/theme_provider.dart';
import 'feedback_dialog.dart';

/// Dialog for displaying detailed interview information
class InterviewDetailDialog extends StatefulWidget {
  final Map<String, dynamic> interview;
  final Function(int, String) onStatusUpdate;
  final Function(int) onCancel;

  const InterviewDetailDialog({
    super.key,
    required this.interview,
    required this.onStatusUpdate,
    required this.onCancel,
  });

  @override
  State<InterviewDetailDialog> createState() => _InterviewDetailDialogState();
}

class _InterviewDetailDialogState extends State<InterviewDetailDialog> {
  bool _isUpdating = false;

  Color _getStatusColor(String status) {
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
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'Not scheduled';

    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMMM dd, yyyy at hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);

    try {
      await widget.onStatusUpdate(widget.interview['id'], newStatus);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _cancelInterview() async {
    setState(() => _isUpdating = true);

    try {
      await widget.onCancel(widget.interview['id']);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel interview: $e')),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final status = widget.interview['status'] ?? 'scheduled';
    final candidate = widget.interview['candidate'] ?? {};
    final hiringManager = widget.interview['hiring_manager'] ?? {};

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade800
                    : const Color(0xFFF8F9FA),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFC10D00),
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate['full_name'] ?? 'Unknown Candidate',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        if (candidate['email'] != null)
                          Text(
                            candidate['email'],
                            style: TextStyle(
                              fontSize: 14,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(status).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Interview Details Section
                    _buildSection(
                      title: 'Interview Details',
                      icon: Icons.calendar_today,
                      children: [
                        _buildDetailRow(
                          'Scheduled Time',
                          _formatDateTime(widget.interview['scheduled_time']),
                        ),
                        if (widget.interview['interview_type'] != null)
                          _buildDetailRow(
                            'Interview Type',
                            widget.interview['interview_type'],
                          ),
                        if (widget.interview['meeting_link'] != null)
                          _buildDetailRow(
                            'Meeting Link',
                            widget.interview['meeting_link'],
                            isLink: true,
                          ),
                        if (widget.interview['google_calendar_event_link'] !=
                            null)
                          _buildDetailRow(
                            'Calendar Event',
                            'View in Google Calendar',
                            isLink: true,
                            url: widget.interview['google_calendar_event_link'],
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // People Section
                    _buildSection(
                      title: 'People',
                      icon: Icons.people,
                      children: [
                        _buildDetailRow(
                          'Candidate',
                          candidate['full_name'] ?? 'Unknown',
                        ),
                        if (candidate['email'] != null)
                          _buildDetailRow(
                            'Candidate Email',
                            candidate['email'],
                          ),
                        _buildDetailRow(
                          'Hiring Manager',
                          hiringManager['full_name'] ?? 'Unknown',
                        ),
                        if (hiringManager['email'] != null)
                          _buildDetailRow(
                            'Manager Email',
                            hiringManager['email'],
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Actions Section
                    _buildActionsSection(status),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade900
                    : Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isUpdating ? null : () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: const Color(0xFFC10D00),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade700
                  : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isLink = false, String? url}) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: themeProvider.isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: isLink
                ? InkWell(
                    onTap: () {
                      // Handle link tap
                    },
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(String currentStatus) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.settings,
              size: 20,
              color: const Color(0xFFC10D00),
            ),
            const SizedBox(width: 8),
            Text(
              'Actions',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (currentStatus == 'scheduled')
              ElevatedButton(
                onPressed:
                    _isUpdating ? null : () => _updateStatus('completed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isUpdating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Mark Complete'),
              ),
            if (currentStatus == 'scheduled' || currentStatus == 'rescheduled')
              ElevatedButton(
                onPressed: _isUpdating ? null : _cancelInterview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: _isUpdating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cancel Interview'),
              ),
            if (currentStatus == 'completed')
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => FeedbackDialog(
                      interviewId: widget.interview['id'],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC10D00),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Feedback'),
              ),
          ],
        ),
      ],
    );
  }
}
