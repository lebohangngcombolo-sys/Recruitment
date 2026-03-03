# AI Assessment Creation – Frontend, Backend & Database Analysis

This document analyses the **AI-powered creation of assessment questions** (the "Generate AI Questions" flow) end-to-end, and notes where problems can appear.

---

## 1. Flow overview

1. User opens **Job form** (Create/Edit Job) → **Assessment** tab → selects **Create custom questions**.
2. User clicks **Generate AI Questions** (green psychology icon).
3. **AIQuestionDialog** opens: job title, difficulty (Easy/Medium/Hard), number of questions (3/5/8/10).
4. User clicks **Generate Questions** → frontend calls backend (or client-side Gemini fallback).
5. Backend (or Gemini) returns a list of questions; dialog closes and **replaces** the form’s question list.
6. User can edit questions, add more, or click **Save Job**; questions are sent as `assessment_pack.questions` (or a test pack is selected instead).

**Database:** AI-generated questions are **not** stored in a separate “AI assessments” table. They are treated like manually entered questions: stored in `requisitions.assessment_pack` (JSON) when using “Create custom questions”, or in `test_packs.questions` if the user first saves as a test pack. So the **AI creation** feature is frontend + backend AI only; persistence is the same as for non-AI assessments.

---

## 2. Frontend

### 2.1 Entry points

| Location | File | Trigger |
|----------|------|--------|
| Hiring Manager job form | `khono_recruite/lib/screens/hiring_manager/job_management.dart` | `_showAIQuestionDialog()` at ~573; button at ~1191 |
| Admin job form | `khono_recruite/lib/screens/admin/job_management.dart` | `_showAIQuestionDialog()` at ~1625; button at ~2203 |

Both use the same pattern: green **Generate AI Questions** icon in the Assessment tab when “Create custom questions” is selected. The button is only visible when the custom-questions block is rendered; if that block fails layout (e.g. the previous `Expanded` inside `SingleChildScrollView` bug in the hiring manager form), the button never appears and the AI flow is unreachable.

### 2.2 AIQuestionDialog

- **Widget:** `AIQuestionDialog` (defined in the same file in both admin and hiring manager).
- **Inputs:** `jobTitle` (from the form’s `title`), `onQuestionsGenerated` callback.
- **State:** `difficulty` (Easy/Medium/Hard), `questionCount` (3/5/8/10), `_isGenerating`.
- **Action:** On “Generate Questions”, calls:
  ```dart
  AIService.generateAssessmentQuestions(
    jobTitle: widget.jobTitle,
    difficulty: difficulty,
    questionCount: questionCount,
  )
  ```
  then `onQuestionsGenerated(questions)` and closes the dialog.
- **Callback (e.g. hiring manager):** `questions.clear(); questions.addAll(generatedQuestions);`

So the form’s `questions` list is **replaced** by the AI result. No merge with existing questions.

**Possible issue:** If the user opens the dialog with an **empty job title**, the backend returns `400 - job_title is required`. The dialog does not validate or prefill the title; it just shows “Job: $jobTitle”. So empty title → API error. Best practice: disable the “Generate AI Questions” button when `title.trim().isEmpty`, or show a warning in the dialog.

### 2.3 AIService.generateAssessmentQuestions (Flutter)

**File:** `khono_recruite/lib/services/ai_service.dart` (~281–327)

**Logic:**

1. **Backend first:**  
   - `POST` to `ApiEndpoints.generateQuestions` (`/api/ai/generate_questions`) with `job_title`, `difficulty`, `question_count`.  
   - Uses `AuthService.getAccessToken()` for `Authorization: Bearer <token>`.  
   - On 200, parses `data['questions']` and returns `List<Map<String, dynamic>>`.

2. **If backend fails (exception or non-200):**  
   - Fallback: `_tryGenerateQuestionsGemini(...)` (client-side Firebase/Gemini).  
   - Requires `_generativeModel != null` (set from `main.dart` when Firebase is configured).

3. **If Gemini also fails:**  
   - Returns `_getFallbackAssessmentQuestions(jobTitle, difficulty, questionCount)` – a fixed list of template questions (same shape: `question`, `options`, `answer`, `weight`).

So the user always gets **some** list of questions; the only way to see an error is if the dialog shows the SnackBar from the `catch` in `_generateQuestions()`. That happens when both backend and Gemini throw and the fallback is not used – but in the current code the fallback is always used after Gemini fails. So the only way to get “Error generating questions” in the UI is if the backend returns non-200 and the client does not have Gemini configured (or Gemini throws and the fallback is not reached due to another bug). Typical failure mode in practice: **backend returns 502/503** (e.g. AI quota or key invalid) and **client has no Gemini** → exception → SnackBar error.

**Expected question shape (all sources):**  
`{ "question": string, "options": List<String>, "answer": int (0–3), "weight": num }`.  
The form and `_normalizeQuestions` accept also `correct_answer` / `question_text` for compatibility.

### 2.4 Normalization and save

- **Form state:** Each item is a map with `question`, `options`, `answer`, `weight` (and optionally `correct_answer` / `question_text`).
- **`_normalizeQuestions` (e.g. hiring manager ~526):** Builds a list with `question` (from `map['question']` only – not `question_text`), `options` (4 items), `answer` (from `map['answer'] ?? map['correct_answer']`), `weight`.
- **Save job payload:** `assessment_pack: { questions: normalizedQuestions.map(q => { question, options, correct_answer: q.answer, weight }) }`.

So AI-generated questions (with `question`, `answer`) are correctly normalized and saved as `correct_answer` for the backend.

---

## 3. Backend

### 3.1 Route

**File:** `server/app/routes/ai_routes.py`

- **Endpoint:** `POST /api/ai/generate_questions`
- **Auth:** `@role_required(["admin", "hiring_manager"])` – candidates cannot call it.
- **Body (JSON):** `job_title` (or `jobTitle`), optional `difficulty` (default `"medium"`), optional `question_count` / `questionCount` (default 5, clamped 1–20).
- **Validation:** Returns 400 if `job_title` is missing or empty.
- **Handler:** Calls `AIService().generate_assessment_questions(job_title, difficulty, question_count)` and returns `{"questions": questions}` with 200, or 502/503 on error.

### 3.2 AIService.generate_assessment_questions (Python)

**File:** `server/app/services/ai_service.py` (~280–319)

- **Prompt:** Asks the model to return JSON: `{ "questions": [ { "question", "options", "answer", "weight" } ] }` with clear rules (4 options, answer 0–3, etc.).
- **Call:** `self._call_ai(prompt, ...)` which:
  - Prefers **Gemini** (Google AI) when `GEMINI_API_KEY` is set; on failure falls back to **OpenRouter**.
  - OpenRouter is used if Gemini is not set or fails after retry.
- **Parsing:** Extracts first `{ ... }` from the response, parses JSON, takes `parsed.get("questions") or []`. No normalization of keys (e.g. no mapping of `question_text` → `question`). So if the model returns different keys, the frontend might get empty or wrong fields.
- **Errors:** Raises `RuntimeError` on parse failure or if `_call_ai` fails (e.g. quota, invalid key). These become 502/503 and the Flutter client sees an exception and can show “Error generating questions”.

**Typical failure causes:**

- **Gemini:** 429 (quota), 404 (wrong model name), or empty/invalid JSON.
- **OpenRouter:** 401 (invalid/revoked key), 503, or invalid JSON.
- **Both failing** → 502 to client → user sees error in SnackBar unless the client fallback (Gemini or template questions) is used.

### 3.3 Environment

- **Gemini:** `GEMINI_API_KEY`, optional `GEMINI_MODEL` (e.g. `gemini-2.0-flash`).
- **OpenRouter:** `OPENROUTER_API_KEY`, optional `OPENROUTER_MODEL`.

If both are missing or broken, all backend AI calls fail.

---

## 4. Database

- **No dedicated table for “AI-generated” assessments.**  
  AI output is just a list of questions in memory; persistence is the same as for manual questions:
  - **Custom questions:** Stored in `requisitions.assessment_pack` (JSON) when the user clicks **Save Job**.
  - **Test pack:** If the user first clicks **Save as Test Pack**, questions go into `test_packs.questions`; the job can then use `requisitions.test_pack_id` to point to that pack.
- **Schema:** `requisitions.assessment_pack` default `{"questions": []}`; each question in the list can have `question`/`question_text`, `options`, `correct_answer`/`correct_option`, `weight`. The assessment service and candidate submission accept both naming conventions for the correct answer.

So the **AI creation** feature does not introduce new DB schema or migration requirements; it only affects how the `questions` list is **produced** before save.

---

## 5. End-to-end data shape

| Stage | Shape |
|-------|--------|
| Backend AI response | `{ "questions": [ { "question", "options", "answer", "weight" } ] }` |
| Flutter after API | `List<Map<String, dynamic>>` with same keys |
| Form state | `question`, `options`, `answer`, `weight` (and optional `correct_answer` / `question_text` in normalization) |
| Save job payload | `assessment_pack.questions[].{ question, options, correct_answer, weight }` |
| DB (requisition) | `assessment_pack` JSON as received |
| Candidate assessment | Backend uses `correct_option` or `correct_answer` (0-based index) when scoring |

So the AI path is consistent with the rest of the app as long as the model returns `question` and `answer`. If the model sometimes returns `question_text` or `correct_option`, the frontend `_normalizeQuestions` does **not** currently map `question_text` → `question`; only `answer` / `correct_answer` are unified. So empty question text could appear in the form if the backend ever returned `question_text` only. The current prompts ask for `question` and `answer`, so this is a potential fragility rather than a current bug.

---

## 6. Summary of likely problems and fixes

| Problem | Layer | Cause | Fix / check |
|--------|--------|--------|-------------|
| “Generate AI Questions” button not visible | Frontend | Assessment tab content (e.g. custom-questions block) not laid out – e.g. `Expanded` inside unbounded height. | Already addressed in hiring manager (Column + shrinkWrap ListView). Ensure no similar layout in admin; do a full app restart after changes. |
| “Error generating questions” in SnackBar | Frontend + Backend | Backend returns 502/503 (AI key invalid, quota, or parse error); client may have no Gemini or Gemini also fails. | Check server logs for 502/503 and exact exception; ensure at least one of GEMINI_API_KEY or OPENROUTER_API_KEY is valid; confirm model name (e.g. gemini-2.0-flash). Client: ensure Firebase/Gemini is configured if you rely on fallback. |
| 400 job_title is required | Backend | User opened dialog with empty job title. | Disable “Generate AI Questions” when `title.trim().isEmpty`, or show validation in dialog and block Generate until title is non-empty. |
| Empty or wrong question text after generation | Backend / model | Model returns `question_text` instead of `question`, or malformed JSON. | Backend: optionally normalize keys (e.g. map `question_text` → `question`) before returning. Frontend: in `_normalizeQuestions` or when applying generated questions, accept `map['question'] ?? map['question_text']` so both work. |
| Questions not saved | Frontend | User forgets to click Save Job, or save fails (e.g. validation). | AI only fills the form; user must click Save Job. Check for save errors (e.g. weightings not 100%, or network) and show clear message. |

---

## 7. Quick checklist for “AI creation not working”

1. **UI:** Can you see the **Assessment** tab and, with “Create custom questions” selected, the **Generate AI Questions** (green) and **Save as Test Pack** (blue) buttons? If not, layout/visibility of the custom-questions block is the first thing to fix (and was fixed for the hiring manager form).
2. **Auth:** Are you logged in as **admin** or **hiring_manager**? (Candidate cannot call the API.)
3. **Job title:** Is the job title field non-empty when you open the dialog and click Generate?
4. **Backend:** Is the server running and does `POST /api/ai/generate_questions` get called? Check network tab and server logs for 200 vs 400/502/503.
5. **AI keys:** In `server/.env`, are `GEMINI_API_KEY` and/or `OPENROUTER_API_KEY` set and valid? Have you hit quota (e.g. Gemini 429)?
6. **After generation:** Do questions appear in the form? If yes, do you then click **Save Job**? If save fails, check weightings (must total 100%) and any server error message.

This covers the full path of **AI creation of assessments** from frontend button → dialog → backend (or client Gemini) → form update → save to DB, and where it can fail.
