"""
Job Service Layer for business logic
"""
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from flask import current_app, request
from sqlalchemy import or_, and_, desc, asc
from sqlalchemy.orm import Query

from app.extensions import db
from app.models import Requisition, User, Application, JobActivityLog, Candidate
from app.schemas.job_schemas import (
    job_create_schema, job_update_schema, job_filter_schema, job_activity_filter_schema
)


class JobService:
    """Service for job/requisition operations"""
    
    @staticmethod
    def create_job(data: Dict, user_id: int) -> Tuple[Optional[Requisition], Optional[Dict]]:
        """
        Create a new job posting
        
        Args:
            data: Job data
            user_id: ID of user creating the job
            
        Returns:
            Tuple of (job object, error dict)
        """
        try:
            # Validate input data
            validated_data = job_create_schema.load(data)
            
            # Check for duplicate active job titles
            existing_job = Requisition.query.filter(
                Requisition.title == validated_data["title"],
                Requisition.is_active == True
            ).first()
            
            if existing_job:
                return None, {"error": "Job title already exists for an active position"}
            
            # Create job
            job = Requisition(
                **validated_data,
                created_by=user_id,
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow()
            )
            
            db.session.add(job)
            # Ensure job.id is assigned before logging activity
            db.session.flush()
            
            # Log activity (job.id is now set)
            JobService._log_activity(
                action="CREATE",
                job_id=job.id,
                user_id=user_id,
                details={"title": job.title, "category": job.category}
            )
            
            db.session.commit()
            
            return job, None
            
        except Exception as e:
            db.session.rollback()
            current_app.logger.error(f"Create job error: {str(e)}", exc_info=True)
            return None, {"error": "Internal server error", "message": str(e)}
    
    @staticmethod
    def update_job(job_id: int, data: Dict, user_id: int) -> Tuple[Optional[Requisition], Optional[Dict]]:
        """
        Update a job posting
        
        Args:
            job_id: ID of job to update
            data: Update data
            user_id: ID of user updating the job
            
        Returns:
            Tuple of (updated job object, error dict)
        """
        try:
            job = Requisition.query.get(job_id)
            if not job:
                return None, {"error": "Job not found"}
            
            # Validate update data
            validated_data = job_update_schema.load(data, partial=True)
            
            # Check title uniqueness if being updated
            if "title" in validated_data and validated_data["title"] != job.title:
                existing_job = Requisition.query.filter(
                    Requisition.title == validated_data["title"],
                    Requisition.is_active == True,
                    Requisition.id != job_id
                ).first()
                
                if existing_job:
                    return None, {"error": "Job title already exists for another active position"}
            
            # Track changes for audit log
            changes = {}
            
            # Update job fields
            for key, value in validated_data.items():
                if hasattr(job, key) and getattr(job, key) != value:
                    changes[key] = {
                        "old": getattr(job, key),
                        "new": value
                    }
                    setattr(job, key, value)
            
            job.updated_at = datetime.utcnow()
            
            # Log activity if there were changes
            if changes:
                JobService._log_activity(
                    action="UPDATE",
                    job_id=job.id,
                    user_id=user_id,
                    details={"changes": changes}
                )
            
            db.session.commit()
            
            return job, None
            
        except Exception as e:
            db.session.rollback()
            current_app.logger.error(f"Update job error for job {job_id}: {str(e)}", exc_info=True)
            return None, {"error": "Internal server error", "message": str(e)}
    
    @staticmethod
    def delete_job(job_id: int, user_id: int) -> Tuple[Optional[Dict], Optional[Dict]]:
        """
        Soft delete a job posting
        
        Args:
            job_id: ID of job to delete
            user_id: ID of user deleting the job
            
        Returns:
            Tuple of (success dict, error dict)
        """
        try:
            job = Requisition.query.get(job_id)
            if not job:
                return None, {"error": "Job not found"}
            
            if not job.is_active:
                return None, {"error": "Job is already deleted"}
            
            # Check if job has active applications
            active_applications = Application.query.filter_by(
                job_id=job_id,
                status="active"
            ).count()
            
            if active_applications > 0:
                return None, {
                    "error": "Cannot delete job with active applications",
                    "active_applications": active_applications
                }
            
            # Soft delete
            job.is_active = False
            job.deleted_at = datetime.utcnow()
            job.updated_at = datetime.utcnow()
            
            # Log activity
            JobService._log_activity(
                action="DELETE",
                job_id=job.id,
                user_id=user_id,
                details={"title": job.title, "reason": "soft_delete"}
            )
            
            db.session.commit()
            
            return {
                "message": "Job soft deleted successfully",
                "job_id": job_id,
                "deleted_at": job.deleted_at.isoformat()
            }, None
            
        except Exception as e:
            db.session.rollback()
            current_app.logger.error(f"Delete job error for job {job_id}: {str(e)}", exc_info=True)
            return None, {"error": "Internal server error", "message": str(e)}
    
    @staticmethod
    def restore_job(job_id: int, user_id: int) -> Tuple[Optional[Dict], Optional[Dict]]:
        """
        Restore a soft-deleted job
        
        Args:
            job_id: ID of job to restore
            user_id: ID of user restoring the job
            
        Returns:
            Tuple of (success dict, error dict)
        """
        try:
            job = Requisition.query.get(job_id)
            if not job:
                return None, {"error": "Job not found"}
            
            if job.is_active:
                return None, {"error": "Job is already active"}
            
            # Restore job
            job.is_active = True
            job.deleted_at = None
            job.updated_at = datetime.utcnow()
            
            # Log activity
            JobService._log_activity(
                action="RESTORE",
                job_id=job.id,
                user_id=user_id,
                details={"title": job.title}
            )
            
            db.session.commit()
            
            return {
                "message": "Job restored successfully",
                "job_id": job_id,
                "is_active": job.is_active
            }, None
            
        except Exception as e:
            db.session.rollback()
            current_app.logger.error(f"Restore job error for job {job_id}: {str(e)}", exc_info=True)
            return None, {"error": "Internal server error", "message": str(e)}
    
    @staticmethod
    def get_job_with_stats(job_id: int, user_id: int) -> Tuple[Optional[Dict], Optional[Dict]]:
        """
        Get job with detailed statistics
        
        Args:
            job_id: ID of job to get
            user_id: ID of user requesting
            
        Returns:
            Tuple of (job dict with stats, error dict)
        """
        try:
            job = Requisition.query.get(job_id)
            if not job:
                return None, {"error": "Job not found"}
            
            # Log view activity
            JobService._log_activity(
                action="VIEW_DETAILED",
                job_id=job.id,
                user_id=user_id,
                details={"section": "detailed_statistics"}
            )
            
            # Get application statistics
            applications = Application.query.filter_by(requisition_id=job_id).all()
            applications_count = len(applications)
            
            # Status breakdown
            status_counts = {}
            for app in applications:
                status_counts[app.status] = status_counts.get(app.status, 0) + 1
            
            # Get activity log count
            activity_count = JobActivityLog.query.filter_by(job_id=job_id).count()
            
            # Recent activities (last 5)
            recent_activities = JobActivityLog.query.filter_by(job_id=job_id)\
                .order_by(JobActivityLog.timestamp.desc())\
                .limit(5)\
                .all()
            
            # Get hiring manager info
            hiring_manager = None
            if job.created_by:
                user = User.query.get(job.created_by)
                if user:
                    hiring_manager = {
                        "id": user.id,
                        "name": user.full_name,
                        "email": user.email
                    }
            
            # Prepare job data
            job_data = job.to_dict()
            job_data.update({
                "statistics": {
                    "total_applications": applications_count,
                    "applications_by_status": status_counts,
                    "activity_log_count": activity_count,
                    "created_at": job.created_at.isoformat() if job.created_at else None,
                    "updated_at": job.updated_at.isoformat() if job.updated_at else None,
                    "days_active": (datetime.utcnow() - job.created_at).days if job.created_at else 0
                },
                "hiring_manager": hiring_manager,
                "recent_activities": [
                    {
                        "action": act.action,
                        "timestamp": act.timestamp.isoformat(),
                        "user_id": act.user_id,
                        "user_name": act.user_relation.full_name if act.user_relation else None
                    }
                    for act in recent_activities
                ]
            })
            
            return job_data, None
            
        except Exception as e:
            current_app.logger.error(f"Get detailed job error for job {job_id}: {str(e)}", exc_info=True)
            return None, {"error": "Internal server error", "message": str(e)}
    
    @staticmethod
    def list_jobs(filters: Dict) -> Tuple[Optional[Dict], Optional[Dict]]:
        """
        List jobs with filtering, sorting, and pagination
        
        Args:
            filters: Filter parameters
            
        Returns:
            Tuple of (jobs list dict, error dict)
        """
        try:
            # Validate filters
            validated_filters = job_filter_schema.load(filters)
            
            # Build query
            query = Requisition.query
            
            # Apply status filter
            status = validated_filters.get('status', 'active')
            if status == 'active':
                query = query.filter_by(is_active=True)
            elif status == 'inactive':
                query = query.filter_by(is_active=False)
            # 'all' includes both active and inactive
            
            # Apply category filter
            category = validated_filters.get('category')
            if category:
                query = query.filter_by(category=category)
            
            # Apply search filter
            search = validated_filters.get('search')
            if search:
                search_term = f"%{search}%"
                query = query.filter(
                    or_(
                        Requisition.title.ilike(search_term),
                        Requisition.description.ilike(search_term),
                        Requisition.job_summary.ilike(search_term),
                        Requisition.required_skills.contains([search])
                    )
                )
            
            # Apply sorting
            sort_by = validated_filters.get('sort_by', 'created_at')
            sort_order = validated_filters.get('sort_order', 'desc')
            
            sort_column = getattr(Requisition, sort_by)
            if sort_order == 'desc':
                query = query.order_by(desc(sort_column))
            else:
                query = query.order_by(asc(sort_column))
            
            # Pagination
            page = validated_filters.get('page', 1)
            per_page = validated_filters.get('per_page', 20)
            
            paginated_jobs = query.paginate(
                page=page,
                per_page=per_page,
                error_out=False
            )
            
            # Prepare response
            jobs_data = []
            for job in paginated_jobs.items:
                job_dict = job.to_dict()
                # Add application count for each job
                app_count = Application.query.filter_by(requisition_id=job.id).count()
                job_dict['application_count'] = app_count
                jobs_data.append(job_dict)
            
            response = {
                "jobs": jobs_data,
                "pagination": {
                    "page": paginated_jobs.page,
                    "per_page": paginated_jobs.per_page,
                    "total_pages": paginated_jobs.pages,
                    "total_items": paginated_jobs.total,
                    "has_next": paginated_jobs.has_next,
                    "has_prev": paginated_jobs.has_prev
                },
                "filters": {
                    "category": category,
                    "status": status,
                    "search": search,
                    "sort_by": sort_by,
                    "sort_order": sort_order
                }
            }
            
            return response, None
            
        except Exception as e:
            current_app.logger.error(f"List jobs error: {str(e)}", exc_info=True)
            return None, {"error": "Internal server error", "message": str(e)}
    
    @staticmethod
    def get_job_activity(job_id: int, filters: Dict) -> Tuple[Optional[Dict], Optional[Dict]]:
        """
        Get activity log for a specific job
        
        Args:
            job_id: ID of job
            filters: Pagination filters
            
        Returns:
            Tuple of (activity log dict, error dict)
        """
        try:
            # Check if job exists
            job = Requisition.query.get(job_id)
            if not job:
                return None, {"error": "Job not found"}
            
            # Validate filters
            validated_filters = job_activity_filter_schema.load(filters)
            
            # Get activity logs
            query = JobActivityLog.query.filter_by(job_id=job_id)\
                .order_by(desc(JobActivityLog.timestamp))
            
            # Pagination
            page = validated_filters.get('page', 1)
            per_page = validated_filters.get('per_page', 50)
            
            paginated_activities = query.paginate(
                page=page,
                per_page=per_page,
                error_out=False
            )
            
            # Format response
            activities_data = []
            for activity in paginated_activities.items:
                user_info = {
                    "id": activity.user_relation.id,
                    "name": activity.user_relation.full_name,
                    "email": activity.user_relation.email
                } if activity.user_relation else {"id": activity.user_id, "name": "Unknown"}
                
                activities_data.append({
                    "id": activity.id,
                    "action": activity.action,
                    "user": user_info,
                    "details": activity.details,
                    "ip_address": activity.ip_address,
                    "timestamp": activity.timestamp.isoformat()
                })
            
            return {
                "job_id": job_id,
                "job_title": job.title,
                "activities": activities_data,
                "pagination": {
                    "page": paginated_activities.page,
                    "per_page": paginated_activities.per_page,
                    "total_pages": paginated_activities.pages,
                    "total_items": paginated_activities.total,
                    "has_next": paginated_activities.has_next,
                    "has_prev": paginated_activities.has_prev
                }
            }, None
            
        except Exception as e:
            current_app.logger.error(f"Get job activity error for job {job_id}: {str(e)}", exc_info=True)
            return None, {"error": "Internal server error", "message": str(e)}
    
    @staticmethod
    def _log_activity(action: str, job_id: int, user_id: int, details: Dict = None):
        """
        Log job-related activities for audit trail
        
        Args:
            action: Action type
            job_id: Job ID
            user_id: User ID
            details: Additional details
        """
        try:
            activity = JobActivityLog(
                job_id=job_id,
                user_id=user_id,
                action=action,
                details=details or {},
                ip_address=request.remote_addr if request else None,
                user_agent=request.user_agent.string if request and request.user_agent else None,
                timestamp=datetime.utcnow()
            )
            db.session.add(activity)
            # Note: We don't commit here - it will be committed with the main transaction
        except Exception as e:
            current_app.logger.error(f"Failed to log activity: {e}")

    @staticmethod
    def build_job_spec_for_cv(requisition: Requisition) -> str:
        """
        Build a single job spec string from all relevant job fields for CV comparison.
        Used by CV analyser so manual and AI-generated job details are assessed consistently.
        """
        if not requisition:
            return ""
        parts = []
        if requisition.title:
            parts.append(f"Role: {requisition.title}")
        if requisition.description:
            parts.append(f"Description: {requisition.description}")
        if requisition.responsibilities:
            r = requisition.responsibilities
            items = r if isinstance(r, list) else []
            if items:
                parts.append("Responsibilities: " + " | ".join(str(x) for x in items))
        if requisition.qualifications:
            q = requisition.qualifications
            items = q if isinstance(q, list) else []
            if items:
                parts.append("Qualifications: " + " | ".join(str(x) for x in items))
        if requisition.required_skills:
            s = requisition.required_skills
            items = s if isinstance(s, list) else []
            if items:
                parts.append("Required skills: " + ", ".join(str(x) for x in items))
        min_exp = requisition.min_experience
        if min_exp is not None and (isinstance(min_exp, (int, float)) and float(min_exp) > 0):
            parts.append(f"Minimum experience: {float(min_exp)} years")
        if requisition.category:
            parts.append(f"Category: {requisition.category}")
        if requisition.job_summary:
            parts.append(f"Summary: {requisition.job_summary}")
        if requisition.company_details:
            parts.append(f"Company: {requisition.company_details}")
        if parts:
            return "\n\n".join(parts)
        # Ensure non-empty so offline CV analyser has text to match
        return requisition.description or (requisition.title or "Job application")

    @staticmethod
    def evaluate_knockout_rules(job: Requisition, candidate: Candidate) -> List[Dict]:
        """Evaluate knockout rules against candidate data."""
        violations = []
        rules = job.knockout_rules or []

        candidate_skills = [str(s).lower() for s in (candidate.skills or [])]
        candidate_certs = [str(c).lower() for c in (candidate.certifications or [])]
        candidate_education = [
            (e.get("degree", "") if isinstance(e, dict) else str(e)).lower()
            for e in (candidate.education or [])
        ]
        candidate_location = (candidate.location or "").lower()

        profile = candidate.profile or {}
        years_experience = (
            profile.get("years_experience")
            or profile.get("experience_years")
            or profile.get("years_of_experience")
            or 0
        )
        try:
            years_experience = float(years_experience)
        except (TypeError, ValueError):
            years_experience = 0

        expected_salary = profile.get("expected_salary") or profile.get("salary_expectation") or 0
        try:
            expected_salary = float(expected_salary)
        except (TypeError, ValueError):
            expected_salary = 0

        def _compare(left, operator, right):
            try:
                if operator == ">=":
                    return left >= right
                if operator == ">":
                    return left > right
                if operator == "==":
                    return left == right
                if operator == "!=":
                    return left != right
                if operator == "<":
                    return left < right
                if operator == "<=":
                    return left <= right
            except Exception:
                return False
            return False

        for rule in rules:
            rule_type = rule.get("type")
            operator = rule.get("operator")
            value = rule.get("value")

            if operator is None:
                violations.append({**rule, "reason": "Missing operator"})
                continue

            if rule_type == "certification":
                target = str(value).lower()
                has_cert = target in candidate_certs
                passed = _compare(has_cert, operator, True)
            elif rule_type == "skills":
                target = str(value).lower()
                has_skill = target in candidate_skills
                passed = _compare(has_skill, operator, True)
            elif rule_type == "education":
                target = str(value).lower()
                has_edu = any(target in item for item in candidate_education)
                passed = _compare(has_edu, operator, True)
            elif rule_type == "location":
                target = str(value).lower()
                passed = _compare(candidate_location, operator, target)
            elif rule_type == "salary":
                try:
                    target = float(value)
                except (TypeError, ValueError):
                    target = 0
                passed = _compare(expected_salary, operator, target)
            elif rule_type == "experience":
                try:
                    target = float(value)
                except (TypeError, ValueError):
                    target = 0
                passed = _compare(years_experience, operator, target)
            else:
                passed = True

            if not passed:
                violations.append(rule)

        return violations
