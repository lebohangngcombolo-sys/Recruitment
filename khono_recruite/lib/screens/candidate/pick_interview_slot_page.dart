import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/candidate_service.dart';

/// Candidate self-service: pick an available interview slot for an application.
class PickInterviewSlotPage extends StatefulWidget {
  final int applicationId;
  final String jobTitle;

  const PickInterviewSlotPage({
    super.key,
    required this.applicationId,
    this.jobTitle = 'Interview',
  });

  @override
  State<PickInterviewSlotPage> createState() => _PickInterviewSlotPageState();
}

class _PickInterviewSlotPageState extends State<PickInterviewSlotPage> {
  List<Map<String, dynamic>> _slots = [];
  bool _loading = true;
  String? _error;
  bool _booking = false;
  int? _bookingSlotId;

  static const Color _accentRed = Color(0xFFC10D00);

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loading = true;
      _error = null;
      _slots = [];
    });
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _error = 'Please log in again';
          _loading = false;
        });
        return;
      }
      final slots = await CandidateService.getApplicationInterviewSlots(
          widget.applicationId, token);
      if (mounted) {
        setState(() {
          _slots = slots;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _bookSlot(int slotId) async {
    setState(() {
      _booking = true;
      _bookingSlotId = slotId;
      _error = null;
    });
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _error = 'Please log in again';
          _booking = false;
          _bookingSlotId = null;
        });
        return;
      }
      await CandidateService.bookInterviewSlot(
          widget.applicationId, slotId, token);
      if (mounted) {
        setState(() {
          _booking = false;
          _bookingSlotId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interview scheduled successfully. Check your email for details.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _booking = false;
          _bookingSlotId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text(
          'Pick a slot',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF252525),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.jobTitle,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose an available time for your interview.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade300),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.red.shade200,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC10D00)),
                  ),
                ),
              )
            else if (_slots.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 48,
                        color: Colors.white38,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No available slots right now. The hiring team may add more soon.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _loadSlots,
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        label: Text(
                          'Refresh',
                          style: GoogleFonts.poppins(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _slots.length,
                  itemBuilder: (context, i) {
                    final slot = _slots[i];
                    final id = slot['id'] as int?;
                    final start = slot['start_time'];
                    final end = slot['end_time'];
                    DateTime? startDt;
                    if (start != null && start is String) {
                      startDt = DateTime.tryParse(start);
                    }
                    DateTime? endDt;
                    if (end != null && end is String) {
                      endDt = DateTime.tryParse(end);
                    }
                    final type = slot['interview_type']?.toString() ?? 'Online';
                    final link = slot['meeting_link']?.toString();
                    final isBooking = _booking && _bookingSlotId == id;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: const Color(0xFF252525),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: isBooking
                            ? null
                            : () {
                                if (id != null) _bookSlot(id);
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    color: _accentRed,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      startDt != null
                                          ? '${startDt.toLocal()}'
                                          : 'Slot',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  if (isBooking)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Color(0xFFC10D00)),
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                ],
                              ),
                              if (endDt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Until ${endDt.toLocal()}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                              if (type.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  type,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: _accentRed,
                                  ),
                                ),
                              ],
                              if (link != null && link.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Meeting link provided after booking',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
