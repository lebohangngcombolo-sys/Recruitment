# Recruitee Webhook Setup Guide

This guide explains how to set up Recruitee webhooks to integrate with your recruitment platform, enabling real-time sync of candidate and job data.

## Overview

The Recruitee webhook implementation supports:
- **Async processing** with Celery for non-blocking responses
- **Signature verification** with HMAC-SHA256 for security
- **Idempotency** to prevent duplicate processing
- **Event logging** for debugging and audit trails
- **CV pipeline integration** for automatic candidate analysis

## Local Testing with ngrok

Since Recruitee needs to reach your webhook endpoint publicly, use ngrok for local development.

### Install ngrok

```bash
# Download from https://ngrok.com/download
# Or via package manager (Windows)
winget install ngrok.ngrok
```

### Start ngrok

```bash
# Start ngrok tunnel to your Flask server (default port 5000)
ngrok http 5000
```

You'll get a URL like: `https://abc123.ngrok.io`

### Configure Webhook URL

Your webhook endpoint will be:
```
https://abc123.ngrok.io/webhooks/recruitee
```

Replace `abc123.ngrok.io` with your actual ngrok URL.

## Webhook Secret Generation

Generate a secure webhook secret:

```bash
# Generate a random 32-byte hex string
openssl rand -hex 32
```

Example output:
```
a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2
```

### Add to Environment Variables

Add to your `.env` file:
```bash
RECRUITEE_WEBHOOK_SECRET=a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2
```

## Recruitee Configuration

### Step 1: Access Recruitee Settings

1. Log in to Recruitee (https://khonology1.recruitee.com)
2. Go to **Settings** → **Apps & Integrations**
3. Find **Webhooks** section
4. Click **Add webhook**

### Step 2: Configure Webhook

Fill in the webhook configuration:

| Field | Value |
|-------|-------|
| **URL** | `https://your-domain.com/webhooks/recruitee` |
| **Events** | Select events you need (see below) |
| **Secret** | Paste your generated webhook secret |

### Step 3: Select Events

For your recruitment system with CV autofill, enable:

**Required Events:**
- `candidate.created` - Triggers CV analysis for new candidates
- `candidate.updated` - Syncs profile updates from Recruitee

**Optional Events:**
- `candidate.moved` - Updates application status/pipeline stage
- `placement.created` - Creates local application records
- `offer.created` - Syncs job posting updates
- `offer.updated` - Syncs job changes

### Step 4: Test the Webhook

After saving the webhook configuration:

1. In Recruitee, create a test candidate
2. Check your server logs: `tail -f logs/app.log`
3. Verify webhook received: Look for `Recruitee webhook received: candidate.created`
4. Check webhook logs in database via admin endpoint

## Supported Event Handlers

### candidate.created
**Action:** Creates or links candidate in local database, triggers CV analysis if CV file present.

**Flow:**
```
Recruitee → Webhook → Celery Task → Create Candidate → CV Analysis → Database
```

### candidate.updated
**Action:** Syncs profile updates from Recruitee to local candidate record.

**Flow:**
```
Recruitee → Webhook → Celery Task → Update Candidate → Database
```

### candidate.moved
**Action:** Updates application status when candidate moves through pipeline stages.

**Flow:**
```
Recruitee → Webhook → Celery Task → Update Application Status → Database
```

### placement.created
**Action:** Creates local application record when candidate applies to job.

**Flow:**
```
Recruitee → Webhook → Celery Task → Create Application → Database
```

## Database Migration

Run the migration to add webhook logging table:

```bash
cd /mnt/c/Users/User/Recruitment/server
source .venv/bin/activate
python migrations/add_recruitee_webhook_logs.py
```

## Admin Endpoints

### View Webhook Logs
```bash
GET /api/admin/integrations/recruitee/webhook-logs
```

Returns all webhook logs with processing status.

### View Sync History
```bash
GET /api/admin/integrations/recruitee/sync-history
```

Returns sync operation history for jobs and candidates.

## Troubleshooting

### Webhook Not Triggering

**Check:**
1. ngrok is running and URL is correct
2. Recruitee webhook URL matches ngrok URL + `/webhooks/recruitee`
3. Server is running on port 5000
4. Firewall isn't blocking connections

**Test manually:**
```bash
curl -X POST https://your-ngrok-url.ngrok.io/webhooks/recruitee \
  -H "Content-Type: application/json" \
  -d '{"event":"test","data":{"test":true}}'
```

### Signature Verification Failing

**Check:**
1. `RECRUITEE_WEBHOOK_SECRET` matches in both `.env` and Recruitee
2. Secret is not wrapped in quotes
3. No extra whitespace in secret

### Duplicate Events Processing

**Expected behavior:** The webhook handler checks for idempotency using `event_id`. Duplicate events are skipped automatically.

**Verify:**
```sql
SELECT event_id, event_type, processed, processing_status 
FROM recruitee_webhook_logs 
ORDER BY created_at DESC LIMIT 10;
```

### Celery Task Not Processing

**Check:**
1. Celery worker is running: `celery -A celery_worker worker -l info`
2. Redis is running: `redis-cli ping` should return `PONG`
3. Task is queued: Check Celery logs

**Debug:**
```python
# In Python shell
from app.tasks.recruitee_webhook_tasks import process_recruitee_webhook
result = process_recruitee_webhook.delay('candidate.created', {}, 'test_event_id', None)
print(result.status)  # Should be 'PENDING' or 'SUCCESS'
```

## Security Best Practices

1. **Always use signature verification** in production
2. **Keep webhook secret secure** - never commit to git
3. **Use HTTPS** for webhook endpoints (ngrok provides this automatically)
4. **Monitor webhook logs** for suspicious activity
5. **Rate limit** webhook endpoint if needed

## Production Deployment

For production deployment on Render/Railway/AWS:

1. **Set environment variables:**
   ```bash
   RECRUITEE_ENABLED=true
   RECRUITEE_WEBHOOK_SECRET=<your-generated-secret>
   RECRUITEE_API_TOKEN=<your-api-token>
   RECRUITEE_COMPANY_ID=130989
   ```

2. **Update webhook URL** in Recruitee to production URL:
   ```
   https://your-production-domain.com/webhooks/recruitee
   ```

3. **Ensure Celery worker** is running in production
4. **Monitor webhook logs** regularly

## Event Payload Structure

Recruitee sends JSON payloads with the following structure:

```json
{
  "event": "candidate.created",
  "event_id": "evt_abc123",
  "data": {
    "candidate": {
      "id": 12345,
      "email": "candidate@example.com",
      "name": "John Doe",
      "cv_file": {
        "url": "https://example.com/cv.pdf"
      }
    }
  }
}
```

## Next Steps

After webhook setup is complete:

1. Test with a real candidate creation in Recruitee
2. Verify candidate appears in local database
3. Check CV analysis is triggered if CV file present
4. Monitor webhook logs for errors
5. Enable additional events as needed
