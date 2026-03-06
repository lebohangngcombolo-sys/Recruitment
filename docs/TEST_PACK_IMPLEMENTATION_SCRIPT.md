# Test Pack (Assessment Pack) Feature – Implementation Script

This document records all code changes for the reusable test pack feature so they can be reapplied after merge conflicts. The feature allows recruiters to select predefined technical or role-specific test packs when creating or editing a job requisition.

---

## 1. Backend: Models

**File:** `server/app/models.py`

### 1.1 Insert TestPack class (before `# ------------------- REQUISITION -------------------`)

```python
# ------------------- TEST PACK -------------------
class TestPack(db.Model):
    """
    Reusable assessment pack (technical or role-specific) for requisitions.
    questions: list of {"question_text", "options", "correct_option", "weight"?}
    """
    __tablename__ = 'test_packs'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(200), nullable=False)
    category = db.Column(db.String(50), nullable=False)  # 'technical' | 'role-specific'
    description = db.Column(db.Text, default="")
    questions = db.Column(MutableList.as_mutable(JSON), default=list)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    deleted_at = db.Column(db.DateTime, nullable=True)

    requisitions = db.relationship(
        'Requisition',
        backref=db.backref('test_pack', lazy=True),
        foreign_keys='Requisition.test_pack_id'
    )

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "category": self.category,
            "description": self.description or "",
            "questions": self.questions or [],
            "question_count": len(self.questions or []),
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "deleted_at": self.deleted_at.isoformat() if self.deleted_at else None,
        }
```

### 1.2 On Requisition class

- Add after `assessment_pack` column:
  - `test_pack_id = db.Column(db.Integer, db.ForeignKey('test_packs.id'), nullable=True)`
- In `to_dict()`, add after `"assessment_pack": self.assessment_pack`:
  - `"test_pack_id": self.test_pack_id,`
  - `"test_pack": self.test_pack.to_dict() if self.test_pack and not self.test_pack.deleted_at else None,`

---

## 2. Backend: Migration

**File:** `server/migrations/versions/20260219_add_test_packs_and_requisition_test_pack_id.py`

Create this file (revision `20260219_test_packs`, down_revision = your current head, e.g. `20260216_add_indexes`). See the actual migration file in the repo for full content.

---

## 3. Backend: Assessment service (question resolver)

**File:** `server/app/services/assessment_service.py`

- Add at module level (after imports):

```python
def get_questions_for_requisition(requisition):
    if not requisition:
        return []
    if requisition.test_pack_id and requisition.test_pack and not requisition.test_pack.deleted_at:
        return list(requisition.test_pack.questions or [])
    pack = requisition.assessment_pack or {}
    return list(pack.get("questions") or [])
```

- In `submit_candidate_assessment`, replace:
  - `questions = application.requisition.assessment_pack.get("questions", [])`
  - with: `questions = get_questions_for_requisition(application.requisition)`
- When reading correct answer for scoring, use: `q.get("correct_option", q.get("correct_answer", 0))` so both formats work.

---

## 4. Backend: Candidate routes (get + submit assessment)

**File:** `server/app/routes/candidate_routes.py`

- **Get assessment:** Instead of returning `application.requisition.assessment_pack`, build:
  - `questions = get_questions_for_requisition(application.requisition)` (import from `app.services.assessment_service`)
  - Return `"assessment_pack": {"questions": questions}`.
- **Submit assessment:** Get questions via `get_questions_for_requisition(application.requisition)`. In the scoring loop, support both `correct_option` and `correct_answer` (0–3) for letter-based comparison.

---

## 5. Backend: Test pack routes

**File:** `server/app/routes/test_pack_routes.py`

New file: blueprint with GET `/test-packs`, GET `/test-packs/<id>`, POST `/test-packs`, PUT `/test-packs/<id>`, DELETE `/test-packs/<id>` (soft delete). All require JWT and role admin/hiring_manager/hr. Register blueprint in `app/__init__.py` with `url_prefix="/api/admin"`.

---

## 6. Backend: Job schemas

**File:** `server/app/schemas/job_schemas.py`

- In `JobBaseSchema`, add: `test_pack_id = fields.Int(allow_none=True, load_default=None, dump_default=None)`.
- In `JobCreateSchema.validate_assessment_pack`: if `data.get("test_pack_id")` is set, skip validation (allow empty assessment_pack).
- In `JobUpdateSchema`, add: `test_pack_id = fields.Int(allow_none=True)`.

---

## 7. Backend: Job service

No code change required: `JobService.create_job` and `update_job` use `validated_data` and set attributes on Requisition; once `test_pack_id` is in the schema, it is applied automatically.

---

## 8. Frontend: API endpoints

**File:** `khono_recruite/lib/utils/api_endpoints.dart`

Add after job-related endpoints:

- `static final getTestPacks = "$adminBase/test-packs";`
- `static String getTestPackById(int id) => "$adminBase/test-packs/$id";`
- `static final createTestPack = "$adminBase/test-packs";`
- `static String updateTestPack(int id) => "$adminBase/test-packs/$id";`
- `static String deleteTestPack(int id) => "$adminBase/test-packs/$id";`

---

## 9. Frontend: Job form (test pack selector) – TODO

In Admin and/or Hiring Manager job create/edit screens (e.g. `job_management.dart` or shared `job_form.dart`):

- Call `GET /api/admin/test-packs` when opening the form (or when Assessment tab is shown).
- Add dropdown: “Assessment: Test pack (optional)” with option “None / Custom questions” and list of packs (name, category, question_count).
- Bind value to `test_pack_id` (nullable).
- On create/update job, include `test_pack_id` in the payload.
- When a test pack is selected, optionally hide or make read-only the manual questions editor; when “None” is selected, show the existing MCQ editor.

---

## 10. Optional: “Save as Test Pack” (Phase 2)

In the Hiring Manager job form Assessment tab, add a button “Save as Test Pack” that takes the current inline questions and opens a dialog (name, category, description) then calls `POST /api/admin/test-packs` with the question list.

---

## Checklist

- [x] TestPack model and Requisition.test_pack_id
- [x] Migration
- [x] get_questions_for_requisition and use in get/submit assessment
- [x] Test pack CRUD API and blueprint registration
- [x] Job schemas (test_pack_id, validation when test_pack_id set)
- [x] Flutter API endpoints for test packs
- [ ] Frontend: test pack dropdown in job create/edit (to be done in job_management / job_form)
- [ ] (Optional) Save as Test Pack button and dialog

---

## Running the migration

From `server/`:

```bash
flask db upgrade
```

Or:

```bash
alembic upgrade head
```

## Verifying

1. Create a test pack via `POST /api/admin/test-packs` with name, category, questions.
2. Create or update a job with `test_pack_id` set; confirm the job returns `test_pack` in its dict.
3. As a candidate, apply to that job, get assessment, and submit; confirm questions come from the pack and scoring works.
