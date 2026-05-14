# Hiring Manager Data Scope

## Canonical HM scope contract

This project now treats HM data as **owned requisition scope**:

- HM can read only data tied to requisitions where `requisitions.created_by == hm_user_id`.
- HM can read interviews they own directly (`interviews.hiring_manager_id == hm_user_id`) or interviews tied to applications in their requisitions.
- HM can mutate only applications/recommendations/statuses tied to their owned requisitions.
- Admin/HR remain global-scope users.

## Canonical pipeline status contract

UI-facing statuses must be normalized to:

- `screening`
- `assessment`
- `recommended`
- `interview`
- `offer`
- `hired`
- `rejected`

Legacy/internal statuses are mapped at API boundary (example: `assessment_submitted -> assessment`, `disqualified -> rejected`).

## Canonical recommendation contract

Pipeline recommendation choices are:

- `Proceed to Final Interview`
- `Hold`
- `Reject`

Any free-form notes are stored separately as supporting context.

## HM scoped endpoints (pipeline critical path)

- `GET /api/admin/pipeline/stats`
- `GET /api/admin/applications/filtered`
- `GET /api/admin/jobs/with-stats`
- `GET /api/admin/interviews/dashboard/<timeframe>`
- `GET /api/admin/pipeline/stages/count`
- `GET /api/admin/pipeline/quick-stats`
- `PATCH /api/admin/applications/<id>/status` (scope-guarded)
- `PATCH /api/admin/applications/<id>/recommendation` (scope-guarded)

### Rollout flag

- `ENABLE_HM_SCOPED_PIPELINE_READS` (default `true`): when disabled, read endpoints fall back to global visibility for rapid rollback.

## References

- `server/app/routes/admin_routes.py`
- `server/app/routes/candidate_routes.py`
- `server/app/models.py`
