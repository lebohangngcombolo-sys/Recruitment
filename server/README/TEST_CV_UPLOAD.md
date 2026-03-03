# Test: CV appears in database (candidate upload)

## Prerequisites

- **Server** running: `python run.py` (port 5000)
- **Flutter app** running (e.g. `flutter run -d chrome`)
- A **candidate** user who has **applied to at least one job** (so there is an `application_id`)

## Steps on the candidate side

1. **Log in** as a candidate in the app.
2. Go to **Jobs Applied** (or the screen where you see your applications).
3. Find an application that still shows **“Upload CV”** or **“CV missing”**.
4. Open that application and tap **Upload CV** (or the CV upload step).
5. Select a **PDF or DOCX** file and confirm upload.
6. Wait for success (e.g. “CV uploaded” or “Resume uploaded”).

## What gets saved in the database

After a successful upload, the backend:

- Uploads the file to **Cloudinary** (folder `Candidate_CV`).
- Saves the CV URL in:
  - **`applications.resume_url`** (for that application)
  - **`candidates.cv_url`** (and optionally **`candidates.cv_text`**)

## Verify in the database (DBeaver / SQL)

Run this to see recent applications and their CV URLs, and the candidate’s `cv_url`:

```sql
-- Recent applications with CV status and candidate CV URL
SELECT
  a.id AS application_id,
  a.resume_url AS application_resume_url,
  a.created_at AS application_created_at,
  c.id AS candidate_id,
  c.cv_url AS candidate_cv_url,
  c.cv_text IS NOT NULL AS has_cv_text
FROM applications a
JOIN candidates c ON c.id = a.candidate_id
ORDER BY a.created_at DESC
LIMIT 20;
```

- If the candidate just uploaded a CV for an application:
  - **`application_resume_url`** should be a Cloudinary URL (e.g. `https://res.cloudinary.com/...`).
  - **`candidate_cv_url`** for that same candidate should be the same URL.
  - **`has_cv_text`** may be true if text was extracted.

To check only the **candidates** table (e.g. the row you care about):

```sql
SELECT id, user_id, full_name, cv_url,
       LEFT(cv_text, 80) AS cv_text_preview
FROM candidates
ORDER BY id DESC
LIMIT 10;
```

After a successful candidate upload, the row for that candidate should have **`cv_url`** set to the Cloudinary URL (no longer NULL).

### If `candidate_cv_url` is still NULL for existing rows

The backend only started writing `candidates.cv_url` when you upload a resume after that change. To backfill **existing** applications (so every candidate with at least one `resume_url` gets a `cv_url`), run this once in DBeaver (PostgreSQL). It sets each candidate’s `cv_url` to the resume URL from their most recent application that has one:

```sql
-- Backfill candidates.cv_url from latest application per candidate (run once)
UPDATE candidates c
SET cv_url = sub.resume_url
FROM (
  SELECT DISTINCT ON (candidate_id) candidate_id, resume_url
  FROM applications
  WHERE resume_url IS NOT NULL AND resume_url != ''
  ORDER BY candidate_id, created_at DESC
) sub
WHERE c.id = sub.candidate_id
  AND (c.cv_url IS NULL OR c.cv_url = '');
```

Then re-run the verification query; `candidate_cv_url` should be filled where `application_resume_url` exists.
