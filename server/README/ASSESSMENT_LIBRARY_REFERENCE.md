# Assessment Library Reference – Database Export & AI Guide

**Purpose:** Realistic library and reference for AI-generated assessments.  
**Source:** Live database `recruitement_deploy` (Render PostgreSQL).  
**Exported:** 2026-02-23.

---

## 1. Summary Statistics (Current Database)

| Metric | Count |
|--------|-------|
| **Test packs (total)** | 2 |
| **Test packs (active)** | 2 |
| **Requisitions / jobs (total)** | 12 |
| **Requisitions (active)** | 11 |
| **Jobs linked to a test pack** | 0 |
| **Jobs with inline assessment_pack questions** | 10 |
| **Assessment results (candidate submissions)** | 13 |

**Takeaway:** All current jobs use **inline** `assessment_pack` questions; no job uses `test_pack_id`. The two test packs exist as reusable templates and mirror the same question patterns used inline.

---

## 2. Schema Conventions (Critical for AI)

### 2.1 Two Question Formats in the Database

The codebase accepts **both** shapes. Normalize to one when generating.

**Format A (test_packs + some jobs)** – preferred for new content:

```json
{
  "question_text": "What is your primary experience level with frontend developer responsibilities?",
  "options": ["Beginner", "Intermediate", "Advanced", "Expert"],
  "correct_option": 2,
  "weight": 1
}
```

**Format B (AI generate_questions + some jobs)**:

```json
{
  "question": "1+1",
  "options": ["1", "2", "3", "4"],
  "correct_answer": 1,
  "weight": 2
}
```

**Resolution in code:** `assessment_service.get_questions_for_requisition` uses `test_pack.questions` or `assessment_pack.questions`. Scoring uses `correct_option` or `correct_answer` (0-based index). For a **realistic library**, always output:

- `question_text` (or `question` if matching existing AI output)
- `options` (array of exactly 4 strings)
- `correct_option` (0–3) — prefer this over `correct_answer` for consistency
- `weight` (optional, default 1)

### 2.2 Test Pack Structure

```json
{
  "id": 1,
  "name": "Freelancer Tester Assessment Pack",
  "category": "technical",
  "description": "",
  "questions": [ /* array of question objects */ ],
  "created_at": "...",
  "updated_at": "...",
  "deleted_at": null
}
```

- **category:** `"technical"` or `"role-specific"` (only these two values).
- **questions:** List of objects with `question_text`, `options`, `correct_option`, `weight`.

### 2.3 Job (Requisition) Assessment Fields

- **test_pack_id:** Optional FK to `test_packs.id`. If set and pack not deleted, questions come from the pack.
- **assessment_pack:** JSON `{ "questions": [ ... ] }`. Used when `test_pack_id` is null or pack is deleted.
- **weightings:** e.g. `{"cv": 60, "assessment": 40, "interview": 0, "references": 0}`. Used for overall score.

---

## 3. Existing Test Packs (Full Content)

### Pack #1: Freelancer Tester Assessment Pack  
**Category:** technical  
**Question count:** 6

| # | Question | Options | Correct index |
|---|----------|---------|----------------|
| 1 | What is your primary experience level with freelancer tester responsibilities? | Beginner, Intermediate, Advanced, Expert | 2 |
| 2 | How would you handle a challenging situation in this role? | Seek help immediately, Try to solve it myself, Research and consult, Delegate to others | 2 |
| 3 | What motivates you most in a freelancer tester position? | Salary, Learning opportunities, Team collaboration, Autonomy | 1 |
| 4 | (duplicate of Q1) | (same) | 2 |
| 5 | (duplicate of Q2) | (same) | 2 |
| 6 | (duplicate of Q3) | (same) | 1 |

### Pack #2: Delivery Lead Assessment Pack  
**Category:** technical  
**Question count:** 3

| # | Question | Options | Correct index |
|---|----------|---------|----------------|
| 1 | What is your primary experience level with delivery lead responsibilities? | Beginner, Intermediate, Advanced, Expert | 2 |
| 2 | How would you handle a challenging situation in this role? | Seek help immediately, Try to solve it myself, Research and consult, Delegate to others | 2 |
| 3 | What motivates you most in a delivery lead position? | Salary, Learning opportunities, Team collaboration, Autonomy | 1 |

**Pattern:** All current packs use the same three question types, with role name injected: experience level, handling challenges, motivation. Correct answers: experience = index 2 (Advanced), challenges = index 2 (Research and consult), motivation = index 1 (Learning opportunities).

---

## 4. Existing Jobs and Their Assessments

### Jobs without assessments (0 questions)

- **#19** Senior Python Developer (Mock) – inactive, no questions.
- **#23** QA Tester – 0 inline questions.

### Jobs with placeholder / non-role questions (e.g. "1+1", "2+2")

- **#20** data analyst – 1 Q: "1+1" → options ["1","2","3","4"], correct 0 (weight 2).
- **#21** Senior Full Stack Developer – 2 Qs: "1+1" (correct 1), "2+2" (correct 3).
- **#22** Mid-Level Backend Developer – 2 Qs: "1+1", "2+2" (both correct 0).
- **#24** Customer Support Officer – 1 Q: "1+1" (correct 1).

### Jobs with role-based 3-question set (AI-style)

Same triad as test packs, with role name in the question:

1. What is your primary experience level with **[role]** responsibilities? → Beginner, Intermediate, Advanced, Expert (correct: 2).
2. How would you handle a challenging situation in this role? → Seek help immediately, Try to solve it myself, Research and consult, Delegate to others (correct: 2).
3. What motivates you most in a **[role]** position? → Salary, Learning opportunities, Team collaboration, Autonomy (correct: 1).

**Jobs using this set:**

- **#25** Frontend Developer – 3 Qs.
- **#26** Data Analyst – 3 Qs.
- **#27** Delivery Lead – 3 Qs.
- **#28** Financial Advisor – 3 Qs.
- **#29** Marketing Agent/Sales – 3 Qs.
- **#30** Freelancer Tester – 6 Qs (same triad repeated twice).

---

## 5. Assessment Results (Candidate Submissions)

| Candidate       | Job                      | Score (raw) | %      | Recommendation |
|-----------------|--------------------------|------------|--------|----------------|
| Leano Mcebo     | Freelancer Tester        | 2/6        | 33.33% | fail           |
| (blank)         | Marketing Agent/Sales    | 0/3        | 0%     | fail           |
| (blank)         | Delivery Lead            | 0/3        | 0%     | fail           |
| (blank)         | Freelancer Tester        | 0/6        | 0%     | fail           |
| (blank)         | Financial Advisor        | 1/3        | 33.33% | fail           |
| Dzunisani Mabunda | Data Analyst           | 3/3        | 100%   | pass           |
| Dzunisani Mabunda | Customer Support Officer | 1/1      | 100%   | pass           |
| (blank)         | Customer Support Officer | 1/1      | 100%   | pass           |
| (blank)         | Mid-Level Backend Developer | 0/2   | 0%     | fail           |
| (blank)         | Senior Full Stack Developer | 1/2  | 33.33% | fail           |
| Top Poril       | Mid-Level Backend Developer | 0/2   | 0%     | fail           |
| Dzunisani Mabunda | Senior Full Stack Developer | 3/3  | 100%   | pass           |
| Jane Applicant  | Senior Python Developer (Mock) | 9   | 90%    | proceed        |

**Recommendation values seen:** `pass`, `fail`, `proceed`. Use these for consistency.

---

## 6. Roles and Categories in the Database

**Job titles (roles) present:**

- Senior Python Developer (Mock), data analyst, Senior Full Stack Developer, Mid-Level Backend Developer, QA Tester, Customer Support Officer, Frontend Developer, Data Analyst, Delivery Lead, Financial Advisor, Marketing Agent/Sales, Freelancer Tester.

**Categories:** Engineering, Information technology, Engneering (typo), Finance, Operations.

**Companies:** ACME Corp, khonology / Khonology, TechCorp Solutions, (empty).

Use these roles and categories when generating job-specific assessments so the library stays aligned with real usage.

---

## 7. Reference Question Bank for AI (Role-Agnostic Triad)

Use this as the **canonical 3-question template** for any role. Substitute `[ROLE]` with the job title (e.g. "Frontend Developer", "Data Analyst").

```json
[
  {
    "question_text": "What is your primary experience level with [ROLE] responsibilities?",
    "options": ["Beginner", "Intermediate", "Advanced", "Expert"],
    "correct_option": 2,
    "weight": 1
  },
  {
    "question_text": "How would you handle a challenging situation in this role?",
    "options": ["Seek help immediately", "Try to solve it myself", "Research and consult", "Delegate to others"],
    "correct_option": 2,
    "weight": 1
  },
  {
    "question_text": "What motivates you most in a [ROLE] position?",
    "options": ["Salary", "Learning opportunities", "Team collaboration", "Autonomy"],
    "correct_option": 1,
    "weight": 1
  }
]
```

For **technical/role-specific** variety, add domain questions (e.g. for Backend: APIs, databases; for QA: test types, tools; for Data Analyst: SQL, visualisation).

---

## 8. Recommendations for a Realistic Library

1. **Normalise field names:** Prefer `question_text` and `correct_option` in new content so it matches test_packs and most of the app logic.
2. **Always 4 options,** correct index 0–3.
3. **Use the triad above** for soft/behavioural fit; add **role-specific technical questions** for technical roles (Engineering, QA, Data Analyst, etc.).
4. **Avoid placeholders** like "1+1"/"2+2" in production; use them only for quick tests.
5. **Link jobs to test packs** where possible: create one pack per role or per category and set `requisition.test_pack_id` so updates to the pack apply to all linked jobs.
6. **Recommendation:** Derive from percentage (e.g. &lt;40% fail, 40–59% review, ≥60% pass) and use values `pass`, `fail`, `proceed` (or add `review` if needed).
7. **Weight:** Use `weight: 1` per question unless you need weighted scoring; then keep total weight consistent per assessment.

---

## 9. Files Generated

- **assessment_library_export.json** – Full dump: test_packs, requisitions, assessment_results (summary + full), stats.
- **assessment_library_report.md** – Human-readable report (this document’s source data).
- **ASSESSMENT_LIBRARY_REFERENCE.md** – This file: schema, conventions, and AI reference.

Use **assessment_library_export.json** for programmatic use and **ASSESSMENT_LIBRARY_REFERENCE.md** as the main reference for AI-generated assessments.
