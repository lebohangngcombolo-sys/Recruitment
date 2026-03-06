import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';
import '../../utils/api_endpoints.dart';

/// In-dialog schedule: location, date & time or pick a slot.
/// Returns payload: candidate_id, application_id, scheduled_time (or slot_id), location (as meeting_link when custom).
/// Caller should POST to schedule interview API so "Final Interview Scheduled" is applied.
class InterviewScheduleDialog extends StatefulWidget {
  final String token;
  final int? candidateId;
  /// If provided, single application is used; otherwise applications are fetched and user picks.
  final int? applicationId;
  /// Optional job (requisition) id for filtering slots.
  final int? jobId;

  const InterviewScheduleDialog({
    super.key,
    required this.token,
    this.candidateId,
    this.applicationId,
    this.jobId,
  });

  @override
  State<InterviewScheduleDialog> createState() => _InterviewScheduleDialogState();
}

class _InterviewScheduleDialogState extends State<InterviewScheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  final AdminService _admin = AdminService();
  List<Map<String, dynamic>> _applications = [];
  String? _selectedApplicationId;
  int? _selectedSlotId;
  DateTime? _dateTime;
  final _locationController = TextEditingController();
  String _interviewType = 'Online';
  bool _loadingApplications = true;
  bool _loadingSlots = false;
  List<Map<String, dynamic>> _slots = [];
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    if (widget.applicationId != null) {
      _selectedApplicationId = widget.applicationId.toString();
      _applications = [
        {'application_id': widget.applicationId, 'job_id': widget.jobId, 'job_title': 'Application'}
      ];
      _loadingApplications = false;
      _fetchSlots();
    } else if (widget.candidateId != null) {
      _fetchApplications();
    } else {
      _loadingApplications = false;
    }
  }

  Future<void> _fetchApplications() async {
    if (widget.candidateId == null) return;
    setState(() => _loadingApplications = true);
    try {
      final res = await AuthService.authorizedGet(
        '${ApiEndpoints.adminBase}/applications?candidate_id=${widget.candidateId}',
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        final apps = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        setState(() {
          _applications = apps;
          _loadingApplications = false;
          _selectedApplicationId = apps.isNotEmpty ? apps.first['application_id']?.toString() : null;
        });
        if (_selectedApplicationId != null) _fetchSlots();
      } else {
        setState(() => _loadingApplications = false);
      }
    } catch (_) {
      setState(() => _loadingApplications = false);
    }
  }

  int? get _selectedJobId {
    if (_selectedApplicationId == null) return widget.jobId;
    for (final a in _applications) {
      if (a['application_id']?.toString() == _selectedApplicationId) {
        final j = a['job_id'];
        return j is int ? j : (j != null ? int.tryParse(j.toString()) : null);
      }
    }
    return widget.jobId;
  }

  Future<void> _fetchSlots() async {
    setState(() {
      _loadingSlots = true;
      _slots = [];
      _selectedSlotId = null;
    });
    try {
      final slots = await _admin.getAvailableInterviewSlots(requisitionId: _selectedJobId);
      if (mounted) {
        setState(() {
          _slots = List<Map<String, dynamic>>.from(slots);
          _loadingSlots = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        _slots = [];
        _loadingSlots = false;
      });
    }
  }

  Future<void> _pickDateTime() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) { setState(() => _isPicking = false); return; }
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) { setState(() => _isPicking = false); return; }
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _selectedSlotId = null;
      _isPicking = false;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedApplicationId == null) return;
    final applicationId = int.tryParse(_selectedApplicationId!);
    if (applicationId == null) return;

    final useSlot = _selectedSlotId != null;
    if (!useSlot && _dateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an available slot or choose date & time')),
      );
      return;
    }

    final payload = <String, dynamic>{
      'candidate_id': widget.candidateId,
      'application_id': applicationId,
      'interview_type': _interviewType,
    };

    if (useSlot) {
      payload['slot_id'] = _selectedSlotId;
    } else {
      payload['scheduled_time'] = _dateTime!.toIso8601String();
      payload['meeting_link'] = _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim();
      // For in-person, location can be in meeting_link as address
      if (_interviewType == 'In-Person' && _locationController.text.trim().isNotEmpty) {
        payload['meeting_link'] = _locationController.text.trim();
      }
    }

    // Include location in payload for callers that expect it (same as meeting_link when custom)
    payload['location'] = _locationController.text.trim();

    Navigator.pop(context, payload);
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasApplication = _selectedApplicationId != null && _applications.isNotEmpty;

    return Dialog(
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 560),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Schedule Interview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_loadingApplications)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_applications.isEmpty && widget.applicationId == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No applications found for this candidate.', style: TextStyle(color: AppColors.textGrey)),
                        )
                      else if (_applications.length > 1) ...[
                        const Text('Application', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: _selectedApplicationId,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: _applications.map((a) {
                            final id = a['application_id']?.toString();
                            final title = a['job_title']?.toString() ?? 'Application';
                            return DropdownMenuItem(value: id, child: Text(title, overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (v) {
                            setState(() => _selectedApplicationId = v);
                            _fetchSlots();
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (hasApplication) ...[
                        // Pick from available slots
                        const Text('Pick from your available slots', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        const SizedBox(height: 6),
                        if (_loadingSlots)
                          const Padding(padding: EdgeInsets.all(8), child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))))
                        else if (_slots.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('No slots available. Use custom date & time below.', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                          )
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 140),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _slots.length,
                              itemBuilder: (context, i) {
                                final slot = _slots[i];
                                final id = slot['id'] as int?;
                                final start = slot['start_time'];
                                DateTime? startDt;
                                if (start is String) startDt = DateTime.tryParse(start);
                                final selected = id != null && _selectedSlotId == id;
                                return InkWell(
                                  onTap: () => setState(() {
                                    _selectedSlotId = id;
                                    _dateTime = null;
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                            size: 20, color: selected ? AppColors.primaryRed : AppColors.textGrey),
                                        const SizedBox(width: 8),
                                        Text(
                                          startDt != null ? '${startDt.toLocal()}' : 'Slot',
                                          style: TextStyle(fontSize: 13, color: AppColors.textDark, fontWeight: selected ? FontWeight.w600 : null),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 10),
                        const Text('Or choose custom date & time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickDateTime,
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Date & Time', border: OutlineInputBorder()),
                            child: Text(
                              _dateTime != null ? _dateTime!.toLocal().toString() : 'Pick date and time',
                              style: TextStyle(color: _dateTime != null ? AppColors.textDark : AppColors.textGrey, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location / Meeting link',
                            border: OutlineInputBorder(),
                            hintText: 'Address for in-person or link for online',
                          ),
                          validator: (v) => null,
                        ),
                        if (_slots.isEmpty) ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _interviewType,
                            decoration: const InputDecoration(labelText: 'Interview type', border: OutlineInputBorder(), isDense: true),
                            items: ['Online', 'In-Person', 'Phone'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setState(() => _interviewType = v ?? 'Online'),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (hasApplication && widget.candidateId != null) ? _submit : null,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: AppColors.primaryWhite),
                  child: const Text('Schedule'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
