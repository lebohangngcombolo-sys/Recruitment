import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../services/admin_service.dart';

/// Interview slots (HM availability) for smart scheduling and self-service booking.
/// Linked from Meetings screen; separate from general meeting scheduling.
class InterviewSlotsPage extends StatefulWidget {
  const InterviewSlotsPage({super.key});

  @override
  State<InterviewSlotsPage> createState() => _InterviewSlotsPageState();
}

class _InterviewSlotsPageState extends State<InterviewSlotsPage> {
  final AdminService _api = AdminService();
  final List<InterviewSlotModel> _slots = [];
  bool _isLoading = true;
  bool _fromNowOnly = true;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() => _isLoading = true);
    try {
      final list = await _api.getInterviewSlots(fromNow: _fromNowOnly);
      setState(() {
        _slots.clear();
        _slots.addAll(list.map((e) => InterviewSlotModel.fromJson(e)));
      });
      if (kDebugMode) debugPrint('Interview slots loaded: ${_slots.length}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load slots: $e', style: GoogleFonts.inter()),
          backgroundColor: AppColors.primaryRed,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode
          ? const Color(0xFF0B0B13)
          : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(themeProvider),
              const SizedBox(height: 20),
              Expanded(child: _buildSlotsSection(themeProvider)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back,
                color: themeProvider.isDarkMode ? Colors.white : AppColors.textDark,
              ),
            ),
            Text(
              'Interview Slots',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: themeProvider.isDarkMode ? Colors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _showAddSlotDialog(themeProvider),
          icon: const Icon(Icons.add, size: 20),
          label: Text('Add Slot', style: GoogleFonts.inter()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSlotsSection(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode ? const Color(0xFF14131E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              FilterChip(
                label: const Text('Upcoming only'),
                selected: _fromNowOnly,
                onSelected: (v) {
                  setState(() => _fromNowOnly = v);
                  _loadSlots();
                },
                selectedColor: AppColors.primaryRed.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 8),
              Text(
                '${_slots.length} slot(s)',
                style: GoogleFonts.inter(
                  color: themeProvider.isDarkMode ? Colors.grey : AppColors.textGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _slots.isEmpty
                    ? Center(
                        child: Text(
                          'No interview slots. Add slots so candidates can book via self-service.',
                          style: GoogleFonts.inter(
                            color: themeProvider.isDarkMode ? Colors.grey : AppColors.textGrey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _slots.length,
                        itemBuilder: (context, index) {
                          final slot = _slots[index];
                          return _buildSlotCard(slot, themeProvider);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(InterviewSlotModel slot, ThemeProvider themeProvider) {
    final isAvailable = slot.isAvailable;
    final start = slot.startTime;
    final end = slot.endTime;
    final range = '${DateFormat('MMM d, y • HH:mm').format(start)} – ${DateFormat('HH:mm').format(end)}';

    return Card(
      color: themeProvider.isDarkMode ? const Color(0xFF1E1E2C) : Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(
          isAvailable ? Icons.event_available : Icons.event_busy,
          color: isAvailable ? Colors.green : Colors.orange,
        ),
        title: Text(
          range,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          isAvailable ? 'Available for booking' : 'Booked',
          style: GoogleFonts.inter(
            color: themeProvider.isDarkMode ? Colors.grey : AppColors.textGrey,
            fontSize: 12,
          ),
        ),
        trailing: isAvailable
            ? IconButton(
                onPressed: () => _deleteSlot(slot),
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Future<void> _deleteSlot(InterviewSlotModel slot) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete slot?'),
        content: const Text(
          'This will remove the slot. Only available (unbooked) slots can be deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _api.deleteInterviewSlot(slot.id);
      await _loadSlots();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slot deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.primaryRed,
        ),
      );
    }
  }

  void _showAddSlotDialog(ThemeProvider themeProvider) {
    final now = DateTime.now();
    DateTime start = now.add(const Duration(hours: 1));
    DateTime end = start.add(const Duration(hours: 1));
    final linkController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Add interview slot', style: GoogleFonts.poppins()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Start'),
                  subtitle: Text(DateFormat('MMM d, y HH:mm').format(start)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: start,
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (d == null) return;
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
                    if (t != null) {
                      setDialogState(() {
                        start = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                        if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
                          end = start.add(const Duration(hours: 1));
                        }
                      });
                    }
                  },
                ),
                ListTile(
                  title: const Text('End'),
                  subtitle: Text(DateFormat('MMM d, y HH:mm').format(end)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: end,
                      firstDate: start,
                      lastDate: start.add(const Duration(days: 1)),
                    );
                    if (d == null) return;
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(end));
                    if (t != null) {
                      setDialogState(() {
                        end = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: linkController,
                  decoration: const InputDecoration(
                    labelText: 'Meeting link (optional)',
                    hintText: 'https://meet.google.com/...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('End must be after start')),
                  );
                  return;
                }
                try {
                  await _api.createInterviewSlot(
                    startTime: start,
                    endTime: end,
                    meetingLink: linkController.text.trim().isEmpty ? null : linkController.text.trim(),
                  );
                  Navigator.pop(ctx);
                  await _loadSlots();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Slot added')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.primaryRed),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: Colors.white),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class InterviewSlotModel {
  final int id;
  final DateTime startTime;
  final DateTime endTime;
  final String? meetingLink;
  final String interviewType;
  final bool isAvailable;

  InterviewSlotModel({
    required this.id,
    required this.startTime,
    required this.endTime,
    this.meetingLink,
    this.interviewType = 'Online',
    required this.isAvailable,
  });

  static InterviewSlotModel fromJson(Map<String, dynamic> json) {
    return InterviewSlotModel(
      id: json['id'] as int,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      meetingLink: json['meeting_link'] as String?,
      interviewType: json['interview_type'] as String? ?? 'Online',
      isAvailable: json['is_available'] as bool? ?? (json['interview_id'] == null),
    );
  }
}
