# Edit Test Packs & Cherry-Pick Questions – Analysis

## 1. Database

### test_packs
| Column       | Type      | Notes |
|-------------|-----------|--------|
| id          | int PK    | |
| name        | varchar(200) | |
| category    | varchar(50)  | `technical` \| `role-specific` |
| description | text      | |
| questions   | JSON      | Array of `{question_text, options[], correct_option, weight}` |
| created_at  | datetime  | |
| updated_at  | datetime  | |
| deleted_at  | datetime  | Soft delete |

- No separate `questions` table; questions live inside the pack JSON.
- Backend reads/writes the full `questions` array on create/update.

### requisitions (jobs)
| Column         | Type  | Notes |
|----------------|-------|--------|
| test_pack_id   | int FK nullable | If set, assessment comes from pack |
| assessment_pack| JSON  | `{ "questions": [ ... ] }` when not using a pack |

**Resolution:** `get_questions_for_requisition()` returns either `test_pack.questions` (full pack) or `assessment_pack.questions` (inline). There is no “selected question indices” on the job; it’s all-or-nothing per source.

---

## 2. Backend (Server)

### Routes – `server/app/routes/test_pack_routes.py`
- **GET /api/admin/test-packs** – List active packs (optional `?category=technical|role-specific`).
- **GET /api/admin/test-packs/:id** – Get one pack (404 if deleted).
- **POST /api/admin/test-packs** – Create: body `name`, `category`, `description?`, `questions` (list).
- **PUT /api/admin/test-packs/:id** – Update: partial `name`, `category`, `description`, `questions` (full replace if sent).
- **DELETE /api/admin/test-packs/:id** – Soft-delete.

All require JWT + role `admin` | `hiring_manager` | `hr`.

### Assessment – `server/app/services/assessment_service.py`
- `get_questions_for_requisition(requisition)` → from `test_pack.questions` if `test_pack_id` set and pack not deleted, else `assessment_pack.questions`.
- No support for “subset of pack” on the job; backend always returns the full list for the chosen source.

**Conclusion:** Backend already supports full edit of a pack (including `questions`). No API changes required for editing packs. Cherry-pick can be implemented client-side by copying selected questions into `assessment_pack.questions` and clearing `test_pack_id`.

---

## 3. Flutter – Current Behaviour

### Test pack management – `lib/screens/admin/test_pack_management_screen.dart`
- Lists packs (name, category, question count, description).
- **Add** → `SaveTestPackDialog(initialQuestions: [])` → create pack via API.
- **Edit** → `SaveTestPackDialog(initialQuestions: pack.questions, initialName, initialCategory, initialDescription)` → update pack via API.
- **Delete** → confirm then soft-delete via API.

### SaveTestPackDialog – `lib/widgets/save_test_pack_dialog.dart`
- Fields: **Pack name**, **Category** (technical / role-specific), **Description**.
- Shows only **“Questions: N”**; does **not** show or edit the question list. On submit it sends `initialQuestions` normalized to `question_text`, `options`, `correct_option`, `weight`. So when editing a pack, the user can change only name/category/description; questions are unchanged.

**Gap:** Users cannot add, remove, or edit individual questions inside a pack in the app.

### Job form (Hiring Manager) – `lib/screens/hiring_manager/job_management.dart`
- **Assessment source:** “Use a test pack” vs “Create custom questions”.
- **Use a test pack:** Dropdown of packs; saves `test_pack_id`. All questions from the pack are used; no subset.
- **Create custom questions:** Full editor: list of questions, each with question text, 4 options, correct answer, weight, delete; “Add Question”, “Generate AI”, “Save as Test Pack”.

**Gap:** No way to pick only some questions from a chosen pack (cherry-pick) for this job.

### Job form (Admin) – `lib/screens/admin/job_management.dart`
- Same structure: `JobFormDialog` with test pack dropdown and custom questions list. Same gaps as hiring manager form.

### API / model
- **TestPackService** – getTestPacks, getTestPack(id), createTestPack(data), updateTestPack(id, data), deleteTestPack(id). Used by both admin and hiring manager.
- **TestPack** model – id, name, category, description, questions (list of maps), questionCount.

---

## 4. Implementation Summary

### A. Edit packs in the app
- **Where:** `SaveTestPackDialog` (or a dedicated full-screen editor opened from Test Pack Management).
- **What:** Show the pack’s questions in an editable list:
  - For each question: question text, 4 options, correct answer (0–3), weight, delete.
  - Buttons: Add question, Save (send name, category, description, questions to PUT).
- **Backend:** No change; PUT already accepts `questions`.
- **Result:** Users can create/edit a pack and fully edit its questions (add, edit, remove) in the app.

### B. Cherry-pick questions for a job
- **Where:** Job form (Hiring Manager and Admin) – Assessment tab, when “Use a test pack” is selected and a pack is chosen.
- **What:** After selecting a pack, show “Customize questions” (e.g. expandable section) listing the pack’s questions with checkboxes. “Use selected” (or “Apply”) copies the selected questions into the **custom questions** list and switches the form to “Create custom questions” (clear `test_pack_id`, set `assessment_pack.questions` to the selected list).
- **Backend:** No change; job stores inline `assessment_pack.questions` and `test_pack_id: null`.
- **Result:** User can cherry-pick which questions from a pack to use for that job; the job then has its own copy of those questions and no longer references the pack.

---

## 5. Files to Touch

| File | Change |
|------|--------|
| `lib/widgets/save_test_pack_dialog.dart` | Add editable question list (add/edit/remove per question), same shape as job form’s question cards; submit full `questions` to API. |
| `lib/screens/hiring_manager/job_management.dart` | When _useTestPack && _testPackId != null: show pack questions with checkboxes + “Use selected” copying into `questions` and switching to custom mode. |
| `lib/screens/admin/job_management.dart` | Same cherry-pick UI when using a test pack. |
| (optional) `docs/EDIT_PACKS_AND_CHERRYPICK.md` | This analysis. |

No database or backend API changes required.
