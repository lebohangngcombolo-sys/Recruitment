# Recruitee Integration – Admin Job Sync (Complete Guide)

This guide covers everything an admin needs to know about the Recruitee job sync: how it works, the API endpoints, database fields, data mapping, failure handling, and the Flutter frontend implementation.

---

## 1. Database Fields (on `requisitions` table)

| Field | Type | Purpose |
|-------|------|---------|
| `recruitee_id` | VARCHAR(100) | Recruitee's offer ID (set after first successful push) |
| `sync_to_recruitee` | BOOLEAN | Admin toggle – if false, job is never synced |
| `last_synced_at` | TIMESTAMP | Time of last successful sync |
| `last_synced_source` | VARCHAR(20) | `'local'` (pushed from app) or `'recruitee'` (webhook) – prevents loops |

**Indexes** are created on `recruitee_id` and `sync_to_recruitee` for performance.

---

## 2. Admin API Endpoints (JWT-protected)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/admin/integrations/recruitee/status` | Check integration status & connection |
| POST | `/api/admin/integrations/recruitee/jobs/{id}/toggle-sync` | Enable/disable sync for one job |
| POST | `/api/admin/integrations/recruitee/jobs/{id}/sync` | Push one job (create or update) |
| POST | `/api/admin/integrations/recruitee/sync/jobs` | Bulk sync (all approved, active, sync-enabled jobs) |
| GET | `/api/admin/integrations/recruitee/offers` | List Recruitee offers (read-only) |
| GET | `/api/admin/integrations/recruitee/sync-history` | Audit log of all sync attempts |
| POST | `/api/admin/integrations/recruitee/process-retries` | Manually trigger pending retries |

---

## 3. Data Mapping (Requisition → Recruitee Offer)

| App Field | Recruitee Field | Notes |
|-----------|-----------------|-------|
| `title` | `title` | Required |
| `description` | `description` | HTML supported |
| `location` | `location` | Free text |
| `category` | `department` | Maps your job category |
| `is_active` (true/false) | `status` (published/closed) | Active jobs become "published" |
| `employment_type` | `employment_type` | Maps to Recruitee's enum |
| `salary_min` + `salary_max` | `salary` (formatted string) | e.g. "ZAR 50,000 - 80,000" |
| `id` (primary key) | `external_id` | Used for matching updates |

**Partial update support** – Only changed fields are sent on subsequent syncs (saves bandwidth and respects rate limits).

---

## 4. Sync Flow (Step by Step)

### 4.1 First Sync (Create)

1. Admin toggles sync ON for a job.
2. Admin clicks **Sync Now** → `POST /jobs/{id}/sync`.
3. Backend checks: job must be `approval_status = 'approved'`.
4. Loop prevention: skip if `last_synced_source == 'recruitee'`.
5. Creates a `RecruiteeSyncHistory` record with status `pending`.
6. Calls `POST /offers` to Recruitee with mapped data.
7. Recruitee returns `{"offer": {"id": "12345"}}`.
8. Stores `recruitee_id = "12345"` and updates `last_synced_at`, `last_synced_source = 'local'`.
9. Updates history to `success` and stores response.
10. Returns success with `recruitee_url`.

### 4.2 Subsequent Sync (Update)

- Same flow but uses `PATCH /offers/{recruitee_id}`.
- Only changed fields are sent (partial update).

### 4.3 Failure & Auto-Retry

If Recruitee returns an error (5xx, timeout, rate limit), history status becomes `failed`.

An automatic retry is scheduled with **exponential backoff**:

- 1st retry: 5 minutes
- 2nd retry: 15 minutes
- 3rd retry: 45 minutes

After 3 failures, stops (requires manual retry).

Admin sees "Retry pending" badge and can force a retry via `POST /process-retries`.

### 4.4 Loop Prevention

If a job was last updated from Recruitee (via webhook), `last_synced_source = 'recruitee'`.

The sync job will skip pushing back to Recruitee, breaking infinite loops.

---

## 5. Security Features

| Feature | Implementation |
|---------|----------------|
| Admin only | All endpoints require valid JWT with admin role |
| API token | Stored in `.env` only (never in code) |
| Rate limiting | Client limits to 900 requests/hour (buffer below Recruitee's 1000) |
| Retries | Automatic with exponential backoff |
| Webhook signature | HMAC-SHA256 verification (optional) |
| Audit log | Every sync attempt stored in `recruitee_sync_history` |

---

## 6. Flutter Frontend Implementation

### 6.1 Add Methods to `AdminService`

```dart
// lib/services/admin_service.dart

Future<Map<String, dynamic>> getRecruiteeStatus() async { ... }
Future<bool> toggleJobSync(int jobId, bool enabled) async { ... }
Future<Map<String, dynamic>> syncJobToRecruitee(int jobId) async { ... }
Future<Map<String, dynamic>> bulkSyncJobs({List<int>? jobIds, bool onlyActive = true}) async { ... }
Future<List<dynamic>> getSyncHistory({String? entityType, int? entityId, String? status, int limit = 50}) async { ... }
Future<Map<String, dynamic>> processRetries() async { ... }
```

### 6.2 Job Management Screen – Add Sync Controls

```dart
// Inside the job row widget
Switch(
  value: job['sync_to_recruitee'] ?? false,
  onChanged: (value) => _toggleJobSync(job['id'], value),
),
IconButton(
  icon: Icon(Icons.cloud_upload),
  onPressed: () => _syncJob(job['id']),
  tooltip: 'Sync to Recruitee',
),
if (job['recruitee_url'] != null)
  IconButton(
    icon: Icon(Icons.open_in_new),
    onPressed: () => launchUrl(job['recruitee_url']),
  ),
IconButton(
  icon: Icon(Icons.history),
  onPressed: () => _showSyncHistory(job['id'], job['title']),
),
```

### 6.3 Sync Status Badge

```dart
Widget _syncStatusBadge(Map<String, dynamic> job) {
  if (job['approval_status'] != 'approved') return Chip(label: Text('Needs approval'), color: Colors.grey);
  if (!job['sync_to_recruitee']) return Chip(label: Text('Sync disabled'), color: Colors.grey);
  if (job['recruitee_id'] == null) return Chip(label: Text('Ready to sync'), color: Colors.orange);
  if (job['last_synced_source'] == 'recruitee') return Chip(label: Text('From Recruitee'), color: Colors.blue);
  return Chip(label: Text('Synced'), color: Colors.green);
}
```

### 6.4 Sync History Screen

Create `lib/screens/admin/sync_history_screen.dart`:

- Fetches history via `getSyncHistory(entityType: 'job', entityId: jobId)`.
- Displays a list of attempts with status (success/failed/pending), error messages, retry count, and next retry time.
- Allows manual retry for failed items.

### 6.5 Bulk Sync Dialog

Create `lib/widgets/bulk_sync_dialog.dart`:

- Shows a list of eligible jobs (approved, active, not synced).
- Checkboxes to select jobs.
- Calls `bulkSyncJobs()` and shows progress/results.

### 6.6 Integration Status Card

Create `lib/widgets/recruitee_integration_card.dart`:

- Shows connection status, company ID, pending retries count.
- Buttons: "Test Connection", "View History", "Process Retries".

---

## 7. Admin Interaction Walkthrough

### Step 1 – Enable Sync for a Job

1. Admin goes to **Jobs → Manage Jobs**.
2. Finds a job (e.g., "Senior Developer") that is **approved**.
3. Clicks the **toggle switch** → switch turns blue → "Sync Now" button appears.

### Step 2 – Sync the Job

1. Clicks **Sync Now** → button shows spinner.
2. After 1-2 seconds:
   - **Success**: Badge turns green "Synced", "View in Recruitee" link appears, toast "✓ Synced successfully".
   - **Failure**: Badge turns orange "Retry pending", toast "⚠ Sync failed – retry scheduled in 5 minutes".

### Step 3 – Bulk Sync

1. Clicks **Bulk Sync** button (top right).
2. Selects multiple jobs from the dialog.
3. Clicks **Sync Selected** → progress bar, then results summary with success/failed counts.

### Step 4 – Monitor Status

1. Goes to **Settings → Integrations → Recruitee**.
2. Sees connection status, pending retries with countdowns.
3. Can click **Process All Retries Now** to force immediate retry.

### Step 5 – Investigate Failures

1. Clicks **History** icon on a job row.
2. Views full audit log: timestamps, actions, error messages, request/response payloads.
3. Expands a failed entry to see the exact API error.

---

## 8. Summary Diagram

```
Admin action → Flutter UI → AdminService → Flask API → RecruiteeClient → Recruitee API
                                                                               │
                                                                               ▼
                                                              success / failure + auto-retry
                                                                               │
                                                                               ▼
                                                              Update database + sync history
```

All sync attempts are fully logged, retries are automatic, and admins have complete control via the UI. The integration is ready to be dropped into your existing Flutter admin panel.
