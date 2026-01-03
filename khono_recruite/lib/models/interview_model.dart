class Interview {
  final int? id;
  final int candidateId;
  final int hiringManagerId;
  final int? applicationId;
  final DateTime scheduledTime;
  final String status;
  final DateTime? createdAt;

  // -------------------
  // Google Calendar fields (NEW)
  // -------------------
  final String? googleCalendarEventId;
  final String? googleCalendarEventLink;
  final String? googleCalendarHangoutLink;
  final DateTime? lastCalendarSync;

  Interview({
    this.id,
    required this.candidateId,
    required this.hiringManagerId,
    this.applicationId,
    required this.scheduledTime,
    this.status = 'scheduled',
    this.createdAt,

    // Calendar
    this.googleCalendarEventId,
    this.googleCalendarEventLink,
    this.googleCalendarHangoutLink,
    this.lastCalendarSync,
  });

  // -------------------
  // JSON Factory
  // -------------------
  factory Interview.fromJson(Map<String, dynamic> json) {
    return Interview(
      id: json['id'],
      candidateId: json['candidate_id'],
      hiringManagerId: json['hiring_manager_id'],
      applicationId: json['application_id'],
      scheduledTime: DateTime.parse(json['scheduled_time']),
      status: json['status'] ?? 'scheduled',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,

      // Calendar fields
      googleCalendarEventId: json['google_calendar_event_id'],
      googleCalendarEventLink: json['google_calendar_event_link'],
      googleCalendarHangoutLink: json['google_calendar_hangout_link'],
      lastCalendarSync: json['last_calendar_sync'] != null
          ? DateTime.parse(json['last_calendar_sync'])
          : null,
    );
  }

  // -------------------
  // JSON Serializer
  // -------------------
  Map<String, dynamic> toJson() {
    return {
      'candidate_id': candidateId,
      'hiring_manager_id': hiringManagerId,
      'application_id': applicationId,
      'scheduled_time': scheduledTime.toIso8601String(),
      'status': status,
    };
  }

  // =====================================================
  // 🧠 UI-Friendly Helpers (OPTIONAL BUT RECOMMENDED)
  // =====================================================

  /// True if interview has a linked Google Calendar event
  bool get hasCalendarEvent =>
      googleCalendarEventId != null && googleCalendarEventId!.isNotEmpty;

  /// True if calendar event exists and was synced
  bool get isCalendarSynced => lastCalendarSync != null;

  /// True if a Google Meet / Hangout link exists
  bool get hasMeetingLink =>
      googleCalendarHangoutLink != null &&
      googleCalendarHangoutLink!.isNotEmpty;

  /// Prefer Google Meet link, fallback to manual meeting link
  String? get meetingLink =>
      googleCalendarHangoutLink ?? googleCalendarEventLink;

  /// Human-readable sync time (for UI labels)
  String? get lastSyncedLabel {
    if (lastCalendarSync == null) return null;
    return lastCalendarSync!.toLocal().toString();
  }
}
