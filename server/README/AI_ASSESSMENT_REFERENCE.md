# AI Assessment Generation Reference

This document provides guidelines and examples for generating realistic job assessments using AI, based on the schema and patterns observed in the existing recruitment system.

## 1. Database Schema & Field Conventions

### Test Pack Structure (Reusable)

```json
{
  "name": "Role Name Assessment Pack",
  "category": "technical" | "role-specific",
  "description": "Brief description of the assessment.",
  "questions": [
    {
      "question_text": "Question text",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correct_option": 0,
      "weight": 1
    }
  ]
}
```

- **category** must be one of `"technical"` or `"role-specific"`.
- **options** must contain exactly 4 strings.
- **correct_option** must be an integer 0–3.
- **weight** is optional; if omitted, the system defaults to 1.

### Inline Assessment Pack (in Job)

When a job does not reference a test pack, its assessment is stored in `requisition.assessment_pack` as:

```json
{
  "questions": [ ... ]
}
```

The scoring engine accepts both `correct_option` (preferred) and `correct_answer` (backward-compatible).

---

## 2. The Behavioural Triad (Canonical 3-Question Template)

The majority of existing assessments use this fixed set of three behavioural questions, with the role name inserted. Always include this triad as the **first three questions** in any new test pack to maintain consistency with existing candidate data and scoring patterns.

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

Replace `[ROLE]` with the exact job title (e.g. "Senior Python Developer").

---

## 3. Role-Specific Technical/Domain Questions

After the behavioural triad, add **5–8 role-specific questions** that test practical knowledge and skills. Base these on:

- Required skills listed in the job requisition.
- Common tools, frameworks, and methodologies for the role.
- Real-world scenarios and best practices.

### Question Quality Guidelines

**Good questions are:**

- Specific and contextual (e.g. "What is the purpose of Flask's @app.route decorator?").
- Role-relevant and test practical knowledge.
- Have clear, distinct options (no ambiguous "all of the above" unless carefully designed).
- Balanced correct-answer distribution (avoid always putting the correct answer in option C).

**Avoid:**

- Placeholder questions like "1+1" (used only for quick tests).
- Ambiguous or trick questions.
- Questions about version-specific details that change frequently.
- Culturally biased or overly academic content.

### Example Technical Questions by Domain

| Domain   | Sample Question                                      | Correct Option                 |
|----------|------------------------------------------------------|--------------------------------|
| Python   | "What is the difference between a list and a tuple?" | Lists mutable, tuples immutable |
| SQL      | "Which SQL clause is used to filter records?"        | WHERE                          |
| React    | "What is the purpose of the useEffect hook?"         | Perform side effects           |
| DevOps   | "What is the main purpose of Docker?"                | Containerization               |
| QA       | "What does regression testing ensure?"               | Existing features still work   |
| Sales    | "What does BANT stand for?"                          | Budget, Authority, Need, Timeline |

---

## 4. Scoring & Recommendations

- **Percentage score** = (number of correct answers / total questions) × 100.
- **Recommendation mapping** (as used in existing data):
  - **&lt; 40%** → fail
  - **40–59%** → optional review (not yet in use, but can be added)
  - **≥ 60%** → pass (or proceed for certain stages)
- Weightings (per job) combine CV, assessment, interview, and reference scores.

---

## 5. Generating New Test Packs with AI

When the `/api/ai/generate_questions` endpoint is called, the AI should receive a prompt like:

```
Generate {question_count} assessment questions for a "{job_title}" position with {difficulty} difficulty level.
Requirements:
- Questions must be relevant to the job role.
- Difficulty: {difficulty} (easy, medium, hard).
- Each question must have exactly 4 options.
- "answer" field should be the index (0–3) of the correct option.
- Questions should test practical knowledge and skills.
- Return only valid JSON.
```

The AI output should use the preferred format:

```json
{
  "questions": [
    {
      "question": "...",
      "options": ["...", "...", "...", "..."],
      "answer": 0,
      "weight": 1
    }
  ]
}
```

(The system maps `answer` to `correct_option` internally.)

---

## 6. Building a Realistic Library – Key Recommendations

1. **Normalise field names:** Use `question_text` and `correct_option` in all new test packs.
2. **Always include the behavioural triad** as the first three questions.
3. **Add 5–8 technical/domain questions** derived from the job's required skills.
4. **Avoid placeholders** – replace them with meaningful questions.
5. **Link jobs to test packs** via `test_pack_id` for reusability and easier updates.
6. **Use consistent recommendation values:** pass, fail, proceed (and optionally review).
7. **Weight** each question with `weight: 1` unless weighted scoring is explicitly needed.

---

## 7. Example Complete Test Pack (Senior Python Developer)

```json
{
  "name": "Senior Python Developer Assessment Pack",
  "category": "technical",
  "description": "Assessment for Senior Python Developer roles covering Python, Flask, PostgreSQL, and backend best practices.",
  "questions": [
    {
      "question_text": "What is your primary experience level with Senior Python Developer responsibilities?",
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
      "question_text": "What motivates you most in a Senior Python Developer position?",
      "options": ["Salary", "Learning opportunities", "Team collaboration", "Autonomy"],
      "correct_option": 1,
      "weight": 1
    },
    {
      "question_text": "In Python, what is the difference between a list and a tuple?",
      "options": ["Lists are mutable, tuples are immutable", "Tuples are lists", "No difference", "Lists are used for strings"],
      "correct_option": 0,
      "weight": 1
    },
    {
      "question_text": "What is the purpose of Flask's `@app.route` decorator?",
      "options": ["To define a database model", "To map a URL to a function", "To handle HTTP errors", "To create a template"],
      "correct_option": 1,
      "weight": 1
    },
    {
      "question_text": "Which SQL command is used to retrieve data from a database?",
      "options": ["INSERT", "UPDATE", "SELECT", "DELETE"],
      "correct_option": 2,
      "weight": 1
    },
    {
      "question_text": "What does ORM stand for in web development?",
      "options": ["Object-Relational Mapping", "Operating Resource Module", "Object Request Model", "Online Record Management"],
      "correct_option": 0,
      "weight": 1
    },
    {
      "question_text": "What is the average time complexity of searching for an item in a Python dictionary?",
      "options": ["O(n)", "O(log n)", "O(1)", "O(n²)"],
      "correct_option": 2,
      "weight": 1
    }
  ]
}
```

---

## 8. Roles and Categories from Existing Database

Use these as a starting point for new assessments:

| Role                      | Category           |
|---------------------------|--------------------|
| Senior Python Developer   | Engineering        |
| Data Analyst             | Information technology |
| Senior Full Stack Developer | Engineering     |
| Mid-Level Backend Developer | Engineering    |
| QA Tester                 | Engineering        |
| Customer Support Officer  | Engineering / Support |
| Frontend Developer        | Engineering        |
| Delivery Lead             | Engineering        |
| Financial Advisor         | Finance            |
| Marketing Agent/Sales     | Sales / Marketing  |
| Freelancer Tester         | Operations         |
| DevOps Engineer           | Engineering        |
| Product Manager          | Product            |

(You may add more as needed.)

---

## 9. Files Created

- **realistic_test_packs.json** – A collection of 13 test packs ready to be imported into the database (via `POST /api/test-packs` or a custom import script).
- **AI_ASSESSMENT_REFERENCE.md** – This guide for AI-assisted generation.

To import the test packs, you can use a simple Python script that reads the JSON and sends each pack to the `POST /api/test-packs` endpoint (or directly insert into the database). The existing `dump_assessments_library.py` script can be adapted for loading.

### Next Steps

1. Review the generated test packs and adjust any questions to better match your specific requirements.
2. Use the AI reference to fine-tune your prompt and ensure consistent output.
3. Consider creating additional packs for roles like HR Manager, Customer Success Manager, etc., following the same pattern.
