# Hiring Manager Data Scope

## Current behavior

- **Dashboard counts** (`GET /api/admin/dashboard-counts`): Returns global counts (all jobs, candidates, interviews, etc.) for both admin and hiring_manager.
- **Jobs, candidates, applications, interviews**: List endpoints return all records visible to the role; there is no filtering by `hiring_manager_id` for hiring managers.

So today, hiring managers see the same aggregate data as admins. If your product should restrict HMs to only their own jobs/interviews/candidates, the backend needs to apply role-based filtering.

## Optional: scope HM to own data

To scope hiring managers to their own data:

1. **Identify current user**: In admin routes, use `get_jwt_identity()` and load `User` to get `user.role`.
2. **When `role == "hiring_manager"`**:
   - **Jobs**: Filter `Requisition` by `created_by == user_id` (if you have `created_by`) or a dedicated `hiring_manager_id` on the job.
   - **Interviews**: Filter `Interview` by `hiring_manager_id == user_id` (already available on the model).
   - **Candidates / applications**: Filter by jobs the HM owns, or by applications linked to HM’s interviews.
3. **Dashboard counts**: For HM, compute counts from the same filtered queries (e.g. `Interview.query.filter_by(hiring_manager_id=user_id).count()`).

No schema change is required for interviews; `Interview.hiring_manager_id` is already present. For jobs, use `Requisition.created_by` if it exists, or add a `hiring_manager_id` (or similar) to the requisition table if jobs are assigned to HMs.

## References

- `server/app/routes/admin_routes.py`: dashboard_counts, jobs list, interviews, candidates.
- `server/app/models.py`: `Interview.hiring_manager_id`, `Requisition`, `Application`.
