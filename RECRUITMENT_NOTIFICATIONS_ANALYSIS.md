# Recruitment User Notifications – In-Depth Analysis (Admin & Hiring Manager)

This document provides a **thorough analysis** of the current notification implementation for Admin and Hiring Manager, with **current code snippets** from the codebase, and maps it to your acceptance criteria for real-time candidate-activity notifications.

---

## 1. Backend – Current Implementation

### 1.1 Model (`server/app/models.py`)

**Notification** has `id`, `user_id` (FK to `users.id`), `message`, `type`, `interview_id`, `is_read`, `created_at`. **No `title` field.**

```626:657:server/app/models.py
class Notification(db.Model):
    __tablename__ = 'notifications'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)

    # Core content
    message = db.Column(db.String(500), nullable=False)

    # 🆕 Classification
    type = db.Column(db.String(50), nullable=False, default="info")

    # 🆕 Context linking
    interview_id = db.Column(db.Integer, db.ForeignKey('interviews.id'), nullable=True)

    # State
    is_read = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # Relationships
    user = db.relationship('User', back_populates='notifications')
    interview = db.relationship('Interview', backref='notifications')

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "message": self.message,
            "type": self.type,
            "interview_id": self.interview_id,
            "is_read": self.is_read,
            "created_at": self.created_at.isoformat()
        }
```

**Gap:** `to_dict()` does not include a `title`; the Flutter app uses `n['title'] ?? "Notification"`, so every item shows the same label.

---

### 1.2 API – GET notifications

**Route:** `GET /api/admin/notifications/<user_id>`. Returns that user’s notifications (newest first) and `unread_count`. Protected by `@role_required(["admin", "hiring_manager"])`. **Does not enforce “current user can only request own notifications”.**

```756:774:server/app/routes/admin_routes.py
# ----------------- NOTIFICATIONS -----------------
@admin_bp.route("/notifications/<int:user_id>", methods=["GET"])
@role_required(["admin", "hiring_manager"])
def get_notifications(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404

    notifications = Notification.query.filter_by(user_id=user_id)\
                                      .order_by(Notification.created_at.desc())\
                                      .all()
    
    unread_count = Notification.query.filter_by(user_id=user_id, is_read=False).count()

    data = [n.to_dict() for n in notifications]

    return jsonify({
        "user_id": user_id,
        "unread_count": unread_count,
        "notifications": data
    }), 200
```

**Gap:** Any admin or hiring manager can request any `user_id`; if the requirement is “users see only their own”, the backend should enforce `user_id == current_user.id` for non-admin roles.

---

### 1.3 Notification creation – no central helper / no real-time

**notification_service** creates notifications and **emits SocketIO**; admin routes **do not use it** – they write to DB only.

```1:56:server/app/services/notification_service.py
from app.models import Notification, User
from app.extensions import db, socketio
from flask_socketio import emit
from flask import current_app

# Create notification for a user
def create_notification(user_id, message):
    try:
        notification = Notification(user_id=user_id, message=message)
        db.session.add(notification)
        db.session.commit()

        # Emit real-time notification
        socketio.emit(
            f"notification_{user_id}",
            notification.to_dict(),
            broadcast=True
        )
        return notification
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Create notification error: {str(e)}")
        raise

# Notify all admins
def notify_admins(message):
    # ... creates Notification for each admin and emits notification_{admin.id}
```

**Gap:** Admin routes build `Notification(...)` and `db.session.add(notif)` directly; they never call `notification_service.create_notification`, so **in-app real-time push for admin/HM is not wired**.

**Note:** `notification_service` has `mark_notification_read(notification_id)` but there is **no HTTP endpoint** in admin routes that exposes it; the Flutter app does not call mark-as-read.

---

## 2. Critical bugs – Wrong `user_id` for candidate notifications

`Notification.user_id` must be **User.id** (FK to `users.id`). In several places the code uses **Candidate.id** as `user_id`.

### 2.1 Schedule interview (~1035)

`candidate_id` from the request is **Candidate.id** (from application/candidate), but it is used as `user_id`:

```1033:1038:server/app/routes/admin_routes.py
            # Create in-app notification
            notif = Notification(
                user_id=candidate_id,
                message=f"Your {interview_type} interview has been scheduled for {scheduled_time.strftime('%Y-%m-%d %H:%M:%S')}."
            )
            db.session.add(notif)
```

**Fix:** Resolve the candidate’s **User.id**, e.g. `Candidate.query.get(candidate_id).user_id`, and use that for `user_id`. Only create the notification if `user_id` is not None.

---

### 2.2 Reschedule (~1196)

`interview.candidate_id` is **candidates.id**, not **users.id**:

```1194:1202:server/app/routes/admin_routes.py
        # Create candidate notification
        notif = Notification(
            user_id=interview.candidate_id,
            message=f"Your interview has been rescheduled from "
                    f"{old_time.strftime('%Y-%m-%d %H:%M:%S')} to "
                    f"{new_time.strftime('%Y-%m-%d %H:%M:%S')}."
        )
        db.session.add(notif)
```

**Fix:** Use `interview.candidate.user_id` (and guard if `interview.candidate` or `interview.candidate.user_id` is None).

---

### 2.3 Cancel interview (~1296) – **correct**

Here the code correctly uses the candidate’s **User.id**:

```1293:1302:server/app/routes/admin_routes.py
        # Add notification
        notif = Notification(
            user_id=candidate.user_id,
            message=f"Your interview scheduled for {interview_details['scheduled_time'].strftime('%Y-%m-%d %H:%M:%S')} has been cancelled."
        )
        db.session.add(notif)
```

---

### 2.4 Completed / no-show / feedback (HM) – **correct**

These use `interview.hiring_manager_id` (User.id) or `interview.candidate.user_id`:

```1734:1743:server/app/routes/admin_routes.py
            # Create notification for hiring manager to submit feedback
            notif = Notification(
                user_id=interview.hiring_manager_id,
                message=f"Interview with {interview.candidate.full_name} marked as completed. "
                       f"Please submit your feedback.",
                type="feedback_reminder",
                interview_id=interview_id
            )
            db.session.add(notif)
```

```1792:1798:server/app/routes/admin_routes.py
            if interview.candidate:
                notif = Notification(
                    user_id=interview.candidate.user_id,
                    message="Interview feedback has been submitted. You'll hear back soon regarding next steps.",
                    type="info"
                )
                db.session.add(notif)
```

---

### 2.5 24h and 1h reminders – **wrong for candidate**

Candidate notification uses `interview.candidate_id` (candidates.id):

```2234:2250:server/app/routes/admin_routes.py
    # Send in-app notification
    notif_candidate = Notification(
        user_id=interview.candidate_id,
        message=f"Reminder: Your interview is tomorrow at {interview.scheduled_time.strftime('%H:%M')}. Please be prepared.",
        type="reminder",
        interview_id=interview.id
    )
    db.session.add(notif_candidate)

    notif_interviewer = Notification(
        user_id=interview.hiring_manager_id,
        ...
    )
```

**Fix:** Use `interview.candidate.user_id` for the candidate notification (and only create if candidate has a user).

---

### 2.6 Pipeline status → interview (~4154) – **correct**

Uses `application.candidate.user_id` and guards for missing candidate/user:

```4152:4158:server/app/routes/admin_routes.py
            if not existing_interview:
                # Create a placeholder interview or notification
                notification = Notification(
                    user_id=application.candidate.user_id if application.candidate and application.candidate.user_id else None,
                    message=f"Your application for {application.requisition.title if application.requisition else 'the position'} has moved to interview stage.",
                    type="status_update"
                )
                db.session.add(notification)
```

**Note:** If `user_id` is `None`, the model has `nullable=False` on `user_id`, so this will raise at commit; either skip adding the notification when `user_id` is None or make `user_id` nullable and filter nulls in the API.

---

## 3. Interview reminders never run

`sender_interview_reminders()` is a plain function that finds `InterviewReminder` rows with `scheduled_time` in the next 5 minutes and calls `send_24_hour_reminder` / `send_1_hour_reminder`. **There is no Celery task, cron job, or scheduler that calls it.**

```2158:2204:server/app/routes/admin_routes.py
def send_interview_reminders():
    """
    Background task to send scheduled reminders
    Run this via cron job every 5 minutes
    """
    try:
        now = datetime.utcnow()
        upcoming = now + timedelta(minutes=5)  # Check next 5 minutes
        
        # Find reminders due to be sent
        pending_reminders = InterviewReminder.query.filter(
            InterviewReminder.scheduled_time >= now,
            InterviewReminder.scheduled_time <= upcoming,
            InterviewReminder.status == "pending"
        ).all()
        # ... sends 24h / 1h reminder and updates status
        db.session.commit()
```

**Gap:** Nothing in the codebase invokes `send_interview_reminders()`. Reminders are only scheduled via `POST /api/admin/interviews/reminders/schedule`; they are never processed. So 24h/1h “upcoming interview” reminders are never sent.

---

## 4. Frontend – Admin & Hiring Manager

### 4.1 Screens and entry point

- **Admin:** Sidebar has “Notifications” → `NotificationsScreen()` (same widget for the notifications “page”).
- **Hiring Manager:** Same: “Notifications” in sidebar → same `NotificationsScreen()` (under `hiring_manager/notifications_screen.dart`; almost identical to admin’s).

Admin dashboard wiring:

```901:902:khono_recruite/lib/screens/admin/admin_dashboard.dart
      case "notifications":
        return const NotificationsScreen();
```

Hiring manager dashboard wiring:

```887:888:khono_recruite/lib/screens/hiring_manager/hiring_manager_dashboard.dart
      case "notifications":
        return NotificationsScreen();
```

---

### 4.2 Fetch flow

On load, the screen calls `AuthService.getUserId()` then `GET ${ApiEndpoints.getNotifications}/$userId` (i.e. `GET /api/admin/notifications/<userId>`).

**Admin notifications_screen.dart** (snippet – fetch and local HTTP helper):

```27:84:khono_recruite/lib/screens/admin/notifications_screen.dart
  Future<void> fetchNotifications() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final userId = await AuthService.getUserId();
      final data = await getNotifications(userId);
      setState(() => notifications = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
      setState(() => errorMessage = "Failed to load notifications");
    } finally {
      setState(() => loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications(int userId) async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(
      Uri.parse("${ApiEndpoints.getNotifications}/$userId"),
      ...
    );

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body is Map && body.containsKey('notifications')) {
        final list = body['notifications'];
        if (list is List) {
          return list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
      ...
    }
```

**Note:** Admin screen uses `jsonDecode` but does **not** import `dart:convert`; adding `import 'dart:convert';` is required. Hiring manager screen has the same pattern and the same potential missing import.

---

### 4.3 UI rendering – title, message, timestamp

List shows **title** (`n['title'] ?? "Notification"`), **message**, and **created_at**. Pull-to-refresh refetches. Backend has no `title`, so **every item shows “Notification”.**

```194:227:khono_recruite/lib/screens/admin/notifications_screen.dart
                                    children: [
                                      Text(
                                        n['title'] ?? "Notification",
                                        style: TextStyle(
                                          color: themeProvider.isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        n['message'] ?? "",
                                        ...
                                      ),
                                      if (createdAt != null)
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: Text(
                                            "${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-..."
```

**Gaps:**

- **Unread:** API returns `unread_count` but the app does **not** show an unread badge in the sidebar and does **not** mark items as read when opened.
- **Action:** Tapping a notification does **nothing** (no navigation to interview/application/job).
- **Real-time:** List updates only on refresh; there is **no WebSocket listener** for `notification_{user_id}`.

---

### 4.4 API endpoint (Flutter)

```133:133:khono_recruite/lib/utils/api_endpoints.dart
  static String get getNotifications => "$adminBase/notifications";
```

So the full URL is `GET ${AppConfig.apiBase}/api/admin/notifications/$userId`.

---

## 5. Notification triggers – summary (backend)

| Trigger                     | Recipient(s)     | When                         | Location (admin_routes) | user_id used        | Correct? |
|----------------------------|------------------|------------------------------|--------------------------|---------------------|----------|
| Interview scheduled        | Candidate        | POST schedule                | ~1035                    | `candidate_id`      | No (Candidate.id) |
| Interview rescheduled      | Candidate        | Reschedule                   | ~1196                    | `interview.candidate_id` | No (Candidate.id) |
| Interview cancelled        | Candidate        | Cancel                       | ~1296                    | `candidate.user_id` | Yes |
| Interview completed        | Hiring manager   | Status → completed           | ~1736                    | `interview.hiring_manager_id` | Yes |
| No-show                    | Hiring manager   | Status → no_show            | ~1755                    | `interview.hiring_manager_id` | Yes |
| Feedback next steps        | Candidate        | Status → feedback_submitted  | ~1794                    | `interview.candidate.user_id` | Yes |
| Feedback submitted         | Hiring manager   | Submit feedback              | ~1960                    | `interview.hiring_manager_id` | Yes |
| 24h reminder              | Candidate + HM   | send_24_hour_reminder()      | ~2236, ~2244             | candidate: `interview.candidate_id`; HM: correct | Candidate: No |
| 1h reminder               | Candidate + HM   | send_1_hour_reminder()       | ~2282, ~2290             | Same as above       | Candidate: No |
| Pipeline → interview       | Candidate        | Application status update    | ~4154                    | `application.candidate.user_id` (with guard) | Yes* |

\* Pipeline notification can fail if `user_id` is None because the column is non-nullable.

---

## 6. Acceptance criteria vs current state (your new AC)

| Criterion | Status | Notes |
|-----------|--------|------|
| **Triggers:** new application, status change, message, CV update, interview scheduled | Partially met | Status changes and “interview scheduled” exist; candidate recipient broken where `user_id` is Candidate.id. New application / CV update / message triggers not implemented. |
| **In-app:** Bell with unread count; panel with timestamp, type; tap navigates; mark as read | Not met | No bell/unread in sidebar; no mark-as-read API called; no navigation on tap; backend has no `title`, so type/title UX is limited. |
| **Email:** Immediate or digest; unsubscribe per trigger | Partially met | Interview-related emails exist (invite, reschedule, cancel, reminders); no digest, no per-trigger unsubscribe. |
| **Preferences:** Settings page, enable/disable triggers, email frequency (immediate/daily/off) | Not met | No notification preferences API or settings UI. |
| **Backend:** notifications table; async queue; list, mark read, unread count, preferences | Partially met | Table and list/unread_count exist; no mark-read endpoint; no preferences; reminders not run by any queue/scheduler. |
| **Frontend:** Bell, panel, settings UI | Partially met | Panel exists; no bell with badge; no settings UI. |

---

## 7. Recommended fixes and improvements (concise)

1. **Fix candidate notification recipient**  
   Everywhere a notification is for “the candidate”, set `user_id = candidate.user_id` (resolve from `Candidate`, not use `Candidate.id`). Apply to: schedule interview, reschedule, 24h/1h reminders. Skip creating the notification if `user_id` is None (and fix pipeline case so null `user_id` is not added when column is non-nullable).

2. **Run interview reminders**  
   Add a Celery (or other) periodic task that runs at least every 5 minutes and calls `send_interview_reminders()`. Ensure reminders are created when an interview is scheduled (existing schedule logic or in the same transaction).

3. **Enforce “own notifications only” for non-admin**  
   In `GET /api/admin/notifications/<user_id>`, if current user is `hiring_manager`, require `user_id == current_user.id`; return 403 otherwise.

4. **Add title (and optional link)**  
   Add `title` (and optionally `link_type`/`link_id`) to the Notification model and migration. Set a short title when creating notifications. Expose in `to_dict()` so the app can show it and, later, deep-link.

5. **Use notification service and real-time**  
   Refactor admin routes to create notifications via `notification_service.create_notification(user_id, message, ...)` (extend the service for title/type/interview_id if needed). Then one path both writes to DB and emits SocketIO so Flutter can show live updates when a listener is added.

6. **Frontend: unread and actions**  
   Show `unread_count` in the sidebar (badge) for Admin and HM. On open, call a “mark as read” API for visible items (add `mark_notification_read` endpoint if missing). On tap, if `interview_id` (or link) is present, navigate to the relevant screen.

7. **Frontend: real-time**  
   Subscribe to the same SocketIO event the server would emit (e.g. `notification_{user_id}`) and append or refresh the list when an event is received.

8. **Admin/HM notifications_screen**  
   Add `import 'dart:convert';` where `jsonDecode` is used. Optionally use `unread_count` from the API response for a badge once the sidebar supports it.

---

## 8. Definition of done – summary

- **Triggers:** Status changes (schedule, reschedule, cancel, completed, no-show, feedback, pipeline move) and upcoming interviews (24h and 1h) all create notifications with **correct user_id** (candidate = User.id).
- **Recipients:** Admin and Hiring Manager receive their own notifications via GET; authorization is explicit (e.g. HM only own).
- **Timing:** One-off at action time; upcoming = 24h and 1h before interview, executed by a scheduled job.
- **Data:** Notification has title, message, type, optional link; reminders use existing InterviewReminder and Interview.
- **Real-time:** Creation path uses notification_service so SocketIO is emitted; Flutter listens and updates the list.
- **UX:** Bell with unread count; mark as read; tap navigates to candidate/job/interview where applicable.

This gives a single source of truth for what exists, what’s broken, and what to build next, with current code snippets for implementation and refactoring.
