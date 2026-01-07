from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity, get_jwt
from app.extensions import db
from app.models import User, Requisition, Candidate, Application, AssessmentResult, Interview, Notification, AuditLog, Conversation, SharedNote, Meeting, CVAnalysis, InterviewFeedback, Offer, OfferStatus
from datetime import datetime, timedelta
from app.utils.decorators import role_required
from app.services.email_service import EmailService
from app.services.audit_service import AuditService
from app.services.audit2 import AuditService
from flask_cors import cross_origin
from sqlalchemy import func, and_, or_
import bleach
from marshmallow import ValidationError
from app.services.job_service import JobService
from app.schemas.job_schemas import (
    job_create_schema, job_update_schema, job_response_schema,
    job_list_schema, job_filter_schema, job_activity_log_schema
)






admin_bp = Blueprint("admin_bp", __name__)

# ----------------- ANALYTICS ROUTES -----------------
@admin_bp.route('/analytics/dashboard', methods=['GET'])
@role_required(["admin", "hiring_manager"])
def get_dashboard_stats():
    """Get overall dashboard statistics"""
    
    # Total counts
    total_users = User.query.count()
    total_candidates = Candidate.query.count()
    total_requisitions = Requisition.query.count()
    total_applications = Application.query.count()
    
    # Application status breakdown
    application_statuses = db.session.query(
        Application.status,
        func.count(Application.id)
    ).group_by(Application.status).all()
    
    status_breakdown = {status: count for status, count in application_statuses}
    
    # Recent activity (last 7 days)
    week_ago = datetime.utcnow() - timedelta(days=7)
    
    new_users_week = User.query.filter(User.created_at >= week_ago).count()
    new_applications_week = Application.query.filter(Application.created_at >= week_ago).count()
    new_requisitions_week = Requisition.query.filter(Requisition.created_at >= week_ago).count()
    
    # Average scores
    avg_cv_score = db.session.query(func.avg(Application.cv_score)).scalar() or 0
    avg_assessment_score = db.session.query(func.avg(Application.assessment_score)).scalar() or 0
    
    return jsonify({
        'total_users': total_users,
        'total_candidates': total_candidates,
        'total_requisitions': total_requisitions,
        'total_applications': total_applications,
        'application_status_breakdown': status_breakdown,
        'recent_activity': {
            'new_users': new_users_week,
            'new_applications': new_applications_week,
            'new_requisitions': new_requisitions_week
        },
        'average_scores': {
            'cv_score': round(float(avg_cv_score), 2),
            'assessment_score': round(float(avg_assessment_score), 2)
        }
    })

@admin_bp.route('/analytics/users-growth', methods=['GET'])
@role_required(["admin", "hiring_manager"])
def get_users_growth():
    """Get user growth data over time"""
    
    days = int(request.args.get('days', 30))
    start_date = datetime.utcnow() - timedelta(days=days)
    
    # User growth data
    user_growth = db.session.query(
        func.date(User.created_at).label('date'),
        func.count(User.id).label('count')
    ).filter(
        User.created_at >= start_date
    ).group_by(
        func.date(User.created_at)
    ).order_by('date').all()
    
    # Candidate growth data
    candidate_growth = db.session.query(
        func.date(User.created_at).label('date'),
        func.count(User.id).label('count')
    ).filter(
        User.created_at >= start_date,
        User.role == 'candidate'
    ).group_by(
        func.date(User.created_at)
    ).order_by('date').all()
    
    return jsonify({
        'user_growth': [{'date': str(date), 'count': count} for date, count in user_growth],
        'candidate_growth': [{'date': str(date), 'count': count} for date, count in candidate_growth]
    })

@admin_bp.route('/analytics/applications-analysis', methods=['GET'])
@role_required(["admin", "hiring_manager"])
def get_applications_analysis():
    """Get detailed applications analysis"""
    
    # Applications by requisition
    apps_by_requisition = db.session.query(
        Requisition.title,
        func.count(Application.id).label('application_count')
    ).join(
        Application, Requisition.id == Application.requisition_id
    ).group_by(
        Requisition.id, Requisition.title
    ).order_by(
        func.count(Application.id).desc()
    ).limit(10).all()
    
    # Score distribution
    score_ranges = [
        ('0-20', 0, 20),
        ('21-40', 21, 40),
        ('41-60', 41, 60),
        ('61-80', 61, 80),
        ('81-100', 81, 100)
    ]
    
    cv_score_distribution = []
    for label, min_score, max_score in score_ranges:
        count = Application.query.filter(
            and_(
                Application.cv_score >= min_score,
                Application.cv_score <= max_score
            )
        ).count()
        cv_score_distribution.append({'range': label, 'count': count})
    
    # Monthly applications
    monthly_apps = db.session.query(
        func.date_trunc('month', Application.created_at).label('month'),
        func.count(Application.id).label('count')
    ).group_by(
        func.date_trunc('month', Application.created_at)
    ).order_by('month').all()
    
    return jsonify({
        'applications_by_requisition': [
            {'requisition': title, 'count': count} 
            for title, count in apps_by_requisition
        ],
        'cv_score_distribution': cv_score_distribution,
        'monthly_applications': [
            {'month': month.strftime('%Y-%m'), 'count': count} 
            for month, count in monthly_apps
        ]
    })

@admin_bp.route('/analytics/interviews-analysis', methods=['GET'])
@role_required(["admin", "hiring_manager"])
def get_interviews_analysis():
    """Get interviews analysis"""
    
    # Interview status breakdown
    interview_statuses = db.session.query(
        Interview.status,
        func.count(Interview.id)
    ).group_by(Interview.status).all()
    
    # Interviews by type
    interviews_by_type = db.session.query(
        Interview.interview_type,
        func.count(Interview.id)
    ).filter(Interview.interview_type.isnot(None)).group_by(Interview.interview_type).all()
    
    # Monthly scheduled interviews
    monthly_interviews = db.session.query(
        func.date_trunc('month', Interview.scheduled_time).label('month'),
        func.count(Interview.id).label('count')
    ).group_by(
        func.date_trunc('month', Interview.scheduled_time)
    ).order_by('month').all()
    
    return jsonify({
        'interview_status_breakdown': [
            {'status': status, 'count': count} 
            for status, count in interview_statuses
        ],
        'interviews_by_type': [
            {'type': interview_type, 'count': count} 
            for interview_type, count in interviews_by_type
        ],
        'monthly_interviews': [
            {'month': month.strftime('%Y-%m'), 'count': count} 
            for month, count in monthly_interviews
        ]
    })

@admin_bp.route('/analytics/assessments-analysis', methods=['GET'])
@role_required(["admin", "hiring_manager"])
def get_assessments_analysis():
    """Get assessments analysis"""
    
    # Assessment score distribution
    assessment_score_ranges = [
        ('0-20', 0, 20),
        ('21-40', 21, 40),
        ('41-60', 41, 60),
        ('61-80', 61, 80),
        ('81-100', 81, 100)
    ]
    
    assessment_score_distribution = []
    for label, min_score, max_score in assessment_score_ranges:
        count = AssessmentResult.query.filter(
            and_(
                AssessmentResult.percentage_score >= min_score,
                AssessmentResult.percentage_score <= max_score
            )
        ).count()
        assessment_score_distribution.append({'range': label, 'count': count})
    
    # Recommendation breakdown
    recommendation_breakdown = db.session.query(
        AssessmentResult.recommendation,
        func.count(AssessmentResult.id)
    ).filter(AssessmentResult.recommendation.isnot(None)).group_by(
        AssessmentResult.recommendation
    ).all()
    
    # Average scores by requisition
    avg_scores_by_req = db.session.query(
        Requisition.title,
        func.avg(AssessmentResult.percentage_score).label('avg_score')
    ).join(Application, Application.requisition_id == Requisition.id).join(
        AssessmentResult, AssessmentResult.application_id == Application.id
    ).group_by(Requisition.id, Requisition.title).all()
    
    return jsonify({
        'assessment_score_distribution': assessment_score_distribution,
        'recommendation_breakdown': [
            {'recommendation': rec, 'count': count} 
            for rec, count in recommendation_breakdown
        ],
        'average_scores_by_requisition': [
            {'requisition': title, 'avg_score': round(float(avg_score or 0), 2)} 
            for title, avg_score in avg_scores_by_req
        ]
    })
"""
Job Routes for admin/hiring manager
"""

@admin_bp.route("/jobs", methods=["POST"])
@jwt_required()
@role_required(["admin", "hiring_manager"])
def create_job():
    """Create a new job posting"""
    try:
        data = request.get_json()
        
        # Validate input using schema
        try:
            validated_data = job_create_schema.load(data)
        except ValidationError as e:
            return jsonify({
                "error": "Validation failed",
                "details": e.messages
            }), 400
        
        current_user_id = get_jwt_identity()
        
        # Use service to create job
        job, error = JobService.create_job(validated_data, current_user_id)
        
        if error:
            return jsonify(error), error.get('status_code', 400)
        
        # Return response
        return jsonify({
            "message": "Job created successfully",
            "job": job_response_schema.dump(job),
            "job_id": job.id
        }), 201
        
    except Exception as e:
        current_app.logger.error(f"Create job route error: {str(e)}", exc_info=True)
        return jsonify({
            "error": "Internal server error",
            "message": str(e)
        }), 500


@admin_bp.route("/jobs/<int:job_id>", methods=["PUT"])
@jwt_required()
@role_required(["admin", "hiring_manager"])
def update_job(job_id):
    """Update a job posting (partial updates allowed)"""
    try:
        data = request.get_json()
        
        # Validate update data
        try:
            validated_data = job_update_schema.load(data, partial=True)
        except ValidationError as e:
            return jsonify({
                "error": "Validation failed",
                "details": e.messages
            }), 400
        
        current_user_id = get_jwt_identity()
        
        # Use service to update job
        job, error = JobService.update_job(job_id, validated_data, current_user_id)
        
        if error:
            return jsonify(error), error.get('status_code', 400)
        
        return jsonify({
            "message": "Job updated successfully",
            "job": job_response_schema.dump(job)
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Update job route error for job {job_id}: {str(e)}", exc_info=True)
        return jsonify({
            "error": "Internal server error",
            "message": str(e)
        }), 500


@admin_bp.route("/jobs/<int:job_id>", methods=["DELETE"])
@jwt_required()
@role_required(["admin", "hiring_manager"])
def delete_job(job_id):
    """Soft delete a job posting"""
    try:
        current_user_id = get_jwt_identity()
        
        # Use service to delete job
        result, error = JobService.delete_job(job_id, current_user_id)
        
        if error:
            return jsonify(error), error.get('status_code', 400)
        
        return jsonify(result), 200
        
    except Exception as e:
        current_app.logger.error(f"Delete job route error for job {job_id}: {str(e)}", exc_info=True)
        return jsonify({
            "error": "Internal server error",
            "message": str(e)
        }), 500


@admin_bp.route("/jobs/<int:job_id>", methods=["GET"])
@jwt_required()
@role_required(["admin", "hiring_manager"])
def get_job(job_id):
    """Get a specific job by ID"""
    try:
        job = Requisition.query.get(job_id)
        if not job:
            return jsonify({"error": "Job not found"}), 404
        
        # Log view activity
        current_user_id = get_jwt_identity()
        JobService._log_activity(
            action="VIEW",
            job_id=job.id,
            user_id=current_user_id
        )
        
        return jsonify(job_response_schema.dump(job)), 200
        
    except Exception as e:
        current_app.logger.error(f"Get job route error for job {job_id}: {str(e)}", exc_info=True)
        return jsonify({
            "error": "Internal server error",
            "message": str(e)
        }), 500


@admin_bp.route("/jobs/<int:job_id>/detailed", methods=["GET"])
@jwt_required()
@role_required(["admin", "hiring_manager"])
def get_job_detailed(job_id):
    """Get detailed information about a job including statistics"""
    try:
        current_user_id = get_jwt_identity()
        
        # Use service to get job with statistics
        job_data, error = JobService.get_job_with_stats(job_id, current_user_id)
        
        if error:
            return jsonify(error), error.get('status_code', 400)
        
        return jsonify(job_data), 200
        
    except Exception as e:
        current_app.logger.error(f"Get detailed job route error for job {job_id}: {str(e)}", exc_info=True)
        return jsonify({
            "error": "Internal server error",
            "message": str(e)
        }), 500


@admin_bp.route("/jobs", methods=["GET"])
@jwt_required()
@role_required(["admin", "hiring_manager"])
def list_jobs():
    """List jobs with filtering, sorting, and pagination"""
    try:
        # Get query parameters
        filters = {
            'page': request.args.get('page', 1, type=int),
            'per_page': request.args.get('per_page', 20, type=int),
            'category': request.args.get('category'),
            'status': request.args.get('status', 'active'),
            'sort_by': request.args.get('sort_by', 'created_at'),
            'sort_order': request.args.get('sort_order', 'desc'),
            'search': request.args.get('search')
        }
        
        # Use service to list jobs
        jobs_data, error = JobService.list_jobs(filters)
        
        if error:
            return jsonify(error), error.get('status_code', 400)
        
        return jsonify(jobs_data), 200
        
    except Exception as e:
        current_app.logger.error(f"List jobs route error: {str(e)}", exc_info=True)
        return jsonify({
            "error": "Internal server error",
            "message": str(e)
        }), 500


@admin_bp.route("/jobs/<int:job_id>/restore", methods=["POST"])
@jwt_required()
@role_required(["admin", "hiring_manager"])
def restore_job(job_id):
    """Restore a soft-deleted job"""
    try:
        current_user_id = get_jwt_identity()
        
        # Use service to restore job
        result, error = JobService.restore_job(job_id, current_user_id)
        
        if error:
            return jsonify(error), error.get('status_code', 400)
        
        return jsonify(result), 200
        
    except Exception as e:
        current_app.logger.error(f"Restore job route error for job {job_id}: {str(e)}", exc_info=True)
        return jsonify({
            "error": "Internal server error",
            "message": str(e)
        }), 500


@admin_bp.route("/jobs/<int:job_id>/activity", methods=["GET"])
@jwt_required()
@role_required(["admin", "hiring_manager"])
def get_job_activity(job_id):
    """Get audit log for a specific job"""
    try:
        # Get pagination parameters
        filters = {
            'page': request.args.get('page', 1, type=int),
            'per_page': request.args.get('per_page', 50, type=int)
        }
        
        # Use service to get activity log
        activity_data, error = JobService.get_job_activity(job_id, filters)
        
        if error:
            return jsonify(error), error.get('status_code', 400)
        
        return jsonify(activity_data), 200
        
    except Exception as e:
        current_app.logger.error(f"Get job activity route error for job {job_id}: {str(e)}", exc_info=True)
        return jsonify({
            "error": "Internal server error",
            "message": str(e)
        }), 500


@admin_bp.route("/jobs/<int:job_id>/applications", methods=["GET"])
@jwt_required()
@role_required(["admin", "hiring_manager", "hr"])
def get_job_applications(job_id):
    """Get applications for a specific job"""
    try:
        # Check if job exists
        job = Requisition.query.get(job_id)
        if not job:
            return jsonify({"error": "Job not found"}), 404
        
        # Get pagination parameters
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 20, type=int)
        status = request.args.get('status')
        
        # Build query
        query = Application.query.filter_by(requisition_id=job_id)
        
        # Apply status filter
        if status:
            query = query.filter_by(status=status)
        
        # Paginate
        applications = query.paginate(
            page=page,
            per_page=per_page,
            error_out=False
        )
        
        # Prepare response
        response = {
            "job_id": job_id,
            "job_title": job.title,
            "applications": [app.to_dict() for app in applications.items],
            "pagination": {
                "page": applications.page,
                "per_page": applications.per_page,
                "total_pages": applications.pages,
                "total_items": applications.total,
                "has_next": applications.has_next,
                "has_prev": applications.has_prev
            }
        }
        
        return jsonify(response), 200
        
    except Exception as e:
        current_app.logger.error(f"Get job applications error for job {job_id}: {str(e)}", exc_info=True)
        return jsonify({
            "error": "Internal server error",
            "message": str(e)
        }), 500


@admin_bp.route("/jobs/stats", methods=["GET"])
@jwt_required()
@role_required(["admin", "hiring_manager", "hr"])
def get_job_statistics():
    """Get overall job statistics"""
    try:
        # Get date range
        start_date = request.args.get('start_date')
        end_date = request.args.get('end_date')
        
        # Base queries
        total_jobs = Requisition.query.count()
        active_jobs = Requisition.query.filter_by(is_active=True).count()
        inactive_jobs = Requisition.query.filter_by(is_active=False).count()
        
        # Category distribution
        categories = db.session.query(
            Requisition.category,
            func.count(Requisition.id).label('count')
        ).filter_by(is_active=True).group_by(Requisition.category).all()
        
        # Applications per job (average) using a subquery
        subquery = (
            db.session.query(
                func.count(Application.id).label('app_count')
            )
            .join(Requisition)
            .filter(Requisition.is_active == True)
            .group_by(Requisition.id)
            .subquery()
        )

        avg_applications = db.session.query(
            func.avg(subquery.c.app_count)
        ).scalar() or 0
        
        # Recent activity (last 30 days)
        thirty_days_ago = datetime.utcnow() - timedelta(days=30)
        recent_jobs = Requisition.query.filter(
            Requisition.created_at >= thirty_days_ago
        ).count()
        
        # Vacancy statistics
        total_vacancies = db.session.query(
            func.sum(Requisition.vacancy)
        ).filter_by(is_active=True).scalar() or 0
        
        response = {
            "overall": {
                "total_jobs": total_jobs,
                "active_jobs": active_jobs,
                "inactive_jobs": inactive_jobs,
                "total_vacancies": total_vacancies,
                "average_applications_per_job": round(float(avg_applications), 2),
                "recent_jobs_last_30_days": recent_jobs
            },
            "by_category": [
                {"category": cat, "count": count}
                for cat, count in categories
            ]
        }
        
        return jsonify(response), 200
        
    except Exception as e:
        current_app.logger.error(f"Get job statistics error: {str(e)}", exc_info=True)
        return jsonify({
            "error": "Internal server error",
            "message": str(e)
        }), 500

# ----------------- CANDIDATE MANAGEMENT -----------------
@admin_bp.route("/candidates", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def list_candidates():
    candidates = Candidate.query.all()
    return jsonify([c.to_dict() for c in candidates])

@admin_bp.route("/applications/<int:application_id>", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def get_application(application_id):
    application = Application.query.get_or_404(application_id)
    assessment = AssessmentResult.query.filter_by(application_id=application.id).first()
    
    # Get candidate data
    candidate = Candidate.query.get(application.candidate_id) if application.candidate_id else None
    
    # Get user data for email
    user = None
    if candidate and candidate.user_id:
        user = User.query.get(candidate.user_id)
    
    return jsonify({
        "application": application.to_dict(),
        "assessment": assessment.to_dict() if assessment else {},
        "candidate": {
            "full_name": candidate.full_name if candidate else "Unknown Candidate",
            "email": user.email if user else "No email",
            "phone": candidate.phone if candidate else "No phone",
            "education": candidate.education if candidate else [],
            "skills": candidate.skills if candidate else [],
            "work_experience": candidate.work_experience if candidate else [],
        } if candidate else {}
    })

@admin_bp.route("/jobs/<int:job_id>/shortlist", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def shortlist_candidates(job_id):
    job = Requisition.query.get_or_404(job_id)
    applications = Application.query.filter_by(requisition_id=job.id).all()
    shortlisted = []

    for app in applications:
        profile = app.candidate.profile or {}
        cv_score = profile.get("cv_score", 0)
        assessment_score = app.assessment_score or 0

        try:
            overall = (
                (cv_score * job.weightings.get("cv", 60) / 100) +
                (assessment_score * job.weightings.get("assessment", 40) / 100)
            )
        except Exception:
            overall = 0

        app.overall_score = overall
        shortlisted.append({
            "application_id": app.id,
            "candidate_id": app.candidate_id,
            "full_name": app.candidate.full_name,
            "cv_score": cv_score,
            "assessment_score": assessment_score,
            "overall_score": overall,
            "status": app.status
        })

    db.session.commit()
    shortlisted_sorted = sorted(shortlisted, key=lambda x: x["overall_score"], reverse=True)
    return jsonify(shortlisted_sorted)


# ----------------- NOTIFICATIONS -----------------
@admin_bp.route("/notifications/<int:user_id>", methods=["GET"])
@role_required(["admin", "hiring_manager"])
def get_notifications(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404

    notifications = Notification.query.filter_by(user_id=user_id)\
                                      .order_by(Notification.created_at.desc())\
                                      .all()
    
    unread_count = Notification.query.filter_by(user_id=user_id, is_read=False).count()

    data = [n.to_dict() for n in notifications]

    return jsonify({
        "user_id": user_id,
        "unread_count": unread_count,
        "notifications": data
    }), 200




@admin_bp.route("/cv-reviews", methods=["GET", "OPTIONS"])
@role_required(["admin", "hiring_manager", "hr"])
@cross_origin()
def list_cv_reviews():
    if request.method == "OPTIONS":
        return '', 200

    applications = Application.query.all()
    reviews = []

    for app in applications:
        candidate = None
        cv_url = None
        cv_parser = app.cv_parser_result or {}

        if app.candidate_id:
            candidate = Candidate.query.get(app.candidate_id)
            cv_url = candidate.cv_url if candidate else None

        reviews.append({
            "application_id": app.id,
            "status": app.status,
            "resume_url": app.resume_url,
            "cv_score": app.cv_score,
            "cv_parser_result": {
                "skills": cv_parser.get("skills", []),
                "education": cv_parser.get("education", []),
                "work_experience": cv_parser.get("work_experience", []),
            },
            "application_recommendation": app.recommendation,
            "assessment_score": app.assessment_score,
            "overall_score": app.overall_score,

            "candidate_id": candidate.id if candidate else None,
            "full_name": candidate.full_name if candidate else None,
            "cv_url": cv_url,
        })

    return jsonify(reviews), 200



# ----------------- USERS MANAGEMENT -----------------
@admin_bp.route("/users", methods=["GET"])
@role_required(["admin"])
def list_users():
    users = User.query.all()
    result = []
    for u in users:
        profile = u.profile or {}
        full_name = profile.get("full_name") or profile.get("name") or None

        result.append({
            "id": u.id,
            "email": u.email,
            "role": u.role,
            "name": full_name,
            "is_verified": u.is_verified,
            "enrollment_completed": u.enrollment_completed,
            "dark_mode": u.dark_mode,
            "created_at": u.created_at.isoformat() if u.created_at else None
        })

    return jsonify(result), 200


@admin_bp.route("/users/<int:user_id>", methods=["DELETE"])
@role_required(["admin"])
def delete_user(user_id):
    user = User.query.get_or_404(user_id)

    # prevent deleting self
    admin_id = get_jwt_identity()
    if admin_id == user.id:
        return jsonify({"error": "You cannot delete your own account"}), 400

    # delete user
    db.session.delete(user)

    # log audit
    audit = AuditLog(
        admin_id=admin_id,
        action=f"Deleted user {user.email}",
        target_user_id=user.id
    )
    db.session.add(audit)
    db.session.commit()

    return jsonify({"message": "User deleted successfully"}), 200


# ----------------- AUDIT LOGS -----------------
@admin_bp.route("/audits", methods=["GET"])
@role_required(["admin"])
def list_audits():
    """
    Fetch paginated and filtered audit logs.
    Supports:
    - Pagination: ?page=1&per_page=20
    - Filtering: ?user_id=5&action=login
    - Date range: ?start_date=2025-09-01&end_date=2025-09-30
    - Keyword search: ?q=updated
    """

    try:
        # --- Pagination parameters ---
        page = request.args.get("page", 1, type=int)
        per_page = request.args.get("per_page", 20, type=int)

        # --- Filters ---
        user_id = request.args.get("user_id", type=int)
        action = request.args.get("action", type=str)
        start_date = request.args.get("start_date")
        end_date = request.args.get("end_date")
        search = request.args.get("q", type=str)

        # --- Build query dynamically ---
        query = AuditLog.query

        if user_id:
            query = query.filter_by(user_id=user_id)

        if action:
            query = query.filter(AuditLog.action.ilike(f"%{action}%"))

        if search:
            query = query.filter(AuditLog.details.ilike(f"%{search}%"))

        if start_date:
            try:
                start = datetime.fromisoformat(start_date)
                query = query.filter(AuditLog.timestamp >= start)
            except ValueError:
                return jsonify({"error": "Invalid start_date format. Use YYYY-MM-DD"}), 400

        if end_date:
            try:
                end = datetime.fromisoformat(end_date)
                query = query.filter(AuditLog.timestamp <= end)
            except ValueError:
                return jsonify({"error": "Invalid end_date format. Use YYYY-MM-DD"}), 400

        # --- Ordering ---
        query = query.order_by(AuditLog.timestamp.desc())

        # --- Pagination ---
        pagination = query.paginate(page=page, per_page=per_page, error_out=False)
        logs = [log.to_dict() for log in pagination.items]

        return jsonify({
            "total": pagination.total,
            "page": pagination.page,
            "pages": pagination.pages,
            "per_page": pagination.per_page,
            "results": logs
        }), 200

    except Exception as e:
        current_app.logger.error(f"Error fetching audit logs: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500

@admin_bp.route("/dashboard-counts", methods=["GET"])
@role_required(["admin", "hiring_manager"])
def dashboard_counts():
    try:
        counts = {
            "jobs": Requisition.query.count(),
            "candidates": Candidate.query.count(),
            "cv_reviews": Application.query.count(),
            "audits": AuditLog.query.count(),
            "interviews": Interview.query.count()
        }
        return jsonify(counts), 200
    except Exception as e:
        current_app.logger.error(f"Dashboard counts error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500


# =====================================================
# 📅 INTERVIEW MANAGEMENT ROUTES (with Google Calendar)
# =====================================================

@admin_bp.route("/jobs/interviews", methods=["GET", "POST"])
@admin_bp.route("/interviews", methods=["GET", "POST"])  # backward compatibility
@role_required(["admin", "hiring_manager", "hr"])
def manage_interviews():
    try:
        # ---------------- GET ----------------
        if request.method == "GET":
            candidate_id = request.args.get("candidate_id", type=int)
            if not candidate_id:
                return jsonify({"error": "candidate_id query parameter is required"}), 400

            interviews = Interview.query.filter_by(candidate_id=candidate_id).all()

            enriched = []
            for i in interviews:
                candidate_profile_picture = None
                if i.candidate and getattr(i.candidate, "profile_picture", None):
                    candidate_profile_picture = i.candidate.profile_picture

                enriched.append({
                    "id": i.id,
                    "candidate_id": i.candidate_id,
                    "candidate_name": i.candidate.full_name if i.candidate else None,
                    "candidate_profile_picture": candidate_profile_picture,
                    "hiring_manager_id": i.hiring_manager_id,
                    "application_id": i.application_id,
                    "job_title": i.application.requisition.title if i.application and i.application.requisition else None,
                    "scheduled_time": i.scheduled_time.isoformat(),
                    "interview_type": i.interview_type,
                    "meeting_link": i.meeting_link,
                    "status": i.status,
                    "google_calendar_event_id": i.google_calendar_event_id,
                    "google_calendar_event_link": i.google_calendar_event_link,
                    "google_calendar_hangout_link": i.google_calendar_hangout_link,
                    "last_calendar_sync": i.last_calendar_sync.isoformat() if i.last_calendar_sync else None,
                    "created_at": i.created_at.isoformat()
                })

            return jsonify(enriched), 200

        # ---------------- POST (Schedule) ----------------
        elif request.method == "POST":
            data = request.get_json()
            candidate_id = data.get("candidate_id")
            application_id = data.get("application_id")
            scheduled_time_str = data.get("scheduled_time")
            interview_type = data.get("interview_type", "Online")
            meeting_link = data.get("meeting_link")

            if not all([candidate_id, application_id, scheduled_time_str]):
                return jsonify({"error": "Missing required fields"}), 400

            try:
                scheduled_time = datetime.fromisoformat(scheduled_time_str)
            except ValueError:
                return jsonify({"error": "Invalid datetime format. Use ISO format."}), 400

            hiring_manager_id = get_jwt_identity()

            # Create interview
            interview = Interview(
                candidate_id=candidate_id,
                application_id=application_id,
                hiring_manager_id=hiring_manager_id,
                scheduled_time=scheduled_time,
                interview_type=interview_type,
                meeting_link=meeting_link
            )

            db.session.add(interview)
            db.session.flush()  # Get the interview ID

            # Create in-app notification
            notif = Notification(
                user_id=candidate_id,
                message=f"Your {interview_type} interview has been scheduled for {scheduled_time.strftime('%Y-%m-%d %H:%M:%S')}."
            )
            db.session.add(notif)

            # Fetch candidate and hiring manager details
            candidate_profile = Candidate.query.get(candidate_id)
            hiring_manager = User.query.get(hiring_manager_id)

            # Google Calendar Integration
            google_calendar_event = None
            if current_app.config.get('GOOGLE_CALENDAR_ENABLED'):
                try:
                    from app.services.google_calendar_service import GoogleCalendarService
                    calendar_service = GoogleCalendarService()
                    
                    if candidate_profile and candidate_profile.user and hiring_manager:
                        interview_data = {
                            "id": interview.id,
                            "candidate_id": candidate_id,
                            "candidate_name": candidate_profile.full_name or "Candidate",
                            "job_title": interview.application.requisition.title if interview.application and interview.application.requisition else "Position",
                            "scheduled_time": scheduled_time.isoformat(),
                            "interview_type": interview_type,
                            "meeting_link": meeting_link,
                            "status": interview.status,
                            "application_id": application_id
                        }
                        
                        google_calendar_event = calendar_service.create_interview_event(
                            interview_data=interview_data,
                            candidate_email=candidate_profile.user.email,
                            hiring_manager_email=hiring_manager.email
                        )
                        
                        if google_calendar_event:
                            # Use the update_calendar_info method from Interview model
                            interview.update_calendar_info(google_calendar_event)
                            current_app.logger.info(f"Google Calendar event created for interview {interview.id}")
                except Exception as e:
                    current_app.logger.error(f"Google Calendar integration failed: {e}", exc_info=True)
                    # Continue without failing the interview creation

            db.session.commit()

            # Send email notification
            if candidate_profile and candidate_profile.user:
                EmailService.send_interview_invitation(
                    email=candidate_profile.user.email,
                    candidate_name=candidate_profile.full_name,
                    interview_date=scheduled_time.strftime("%A, %d %B %Y at %H:%M"),
                    interview_type=interview_type,
                    meeting_link=interview.meeting_link,
                    calendar_link=google_calendar_event.get('html_link') if google_calendar_event else None
                )

            # Return enriched interview data
            enriched_interview = {
                "id": interview.id,
                "candidate_id": interview.candidate_id,
                "candidate_name": candidate_profile.full_name if candidate_profile else None,
                "candidate_profile_picture": candidate_profile.profile_picture if candidate_profile and getattr(candidate_profile, "profile_picture", None) else None,
                "hiring_manager_id": interview.hiring_manager_id,
                "application_id": interview.application_id,
                "job_title": interview.application.requisition.title if interview.application and interview.application.requisition else None,
                "scheduled_time": interview.scheduled_time.isoformat(),
                "interview_type": interview.interview_type,
                "meeting_link": interview.meeting_link,
                "status": interview.status,
                "google_calendar_event_id": interview.google_calendar_event_id,
                "google_calendar_event_link": interview.google_calendar_event_link,
                "google_calendar_hangout_link": interview.google_calendar_hangout_link,
                "last_calendar_sync": interview.last_calendar_sync.isoformat() if interview.last_calendar_sync else None,
                "created_at": interview.created_at.isoformat()
            }

            return jsonify({
                "message": "Interview scheduled successfully.",
                "interview": enriched_interview,
                "calendar_event_created": google_calendar_event is not None
            }), 201

    except Exception as e:
        current_app.logger.error(f"Interview route error: {e}", exc_info=True)
        db.session.rollback()
        return jsonify({"error": "Internal server error"}), 500


# =====================================================
# ♻️ RESCHEDULE INTERVIEW (with Google Calendar)
# =====================================================
@admin_bp.route("/interviews/reschedule/<int:interview_id>", methods=["PATCH", "PUT"])
@role_required(["admin", "hiring_manager", "hr"])
def reschedule_interview(interview_id):
    try:
        # Fetch interview
        interview = Interview.query.get_or_404(interview_id)
        data = request.get_json()
        new_time_str = data.get("scheduled_time")
        new_meeting_link = data.get("meeting_link")  # Optional: allow updating meeting link too

        if not new_time_str:
            return jsonify({"error": "New scheduled_time required"}), 400

        # Parse ISO datetime
        try:
            new_time = datetime.fromisoformat(new_time_str)
        except ValueError:
            return jsonify({"error": "Invalid datetime format. Use ISO format."}), 400

        old_time = interview.scheduled_time
        interview.scheduled_time = new_time
        
        # Update meeting link if provided
        if new_meeting_link is not None:
            interview.meeting_link = new_meeting_link
        
        # Google Calendar Update
        calendar_updated = False
        if current_app.config.get('GOOGLE_CALENDAR_ENABLED') and interview.google_calendar_event_id:
            try:
                from app.services.google_calendar_service import GoogleCalendarService
                calendar_service = GoogleCalendarService()
                
                # Fetch candidate and hiring manager details
                candidate = interview.candidate
                hiring_manager = User.query.get(interview.hiring_manager_id)
                
                if candidate and candidate.user and hiring_manager:
                    interview_data = {
                        "id": interview.id,
                        "candidate_id": interview.candidate_id,
                        "candidate_name": candidate.full_name if candidate else "Candidate",
                        "job_title": interview.application.requisition.title if interview.application and interview.application.requisition else "Position",
                        "scheduled_time": new_time.isoformat(),
                        "interview_type": interview.interview_type,
                        "meeting_link": interview.meeting_link,
                        "status": interview.status,
                        "application_id": interview.application_id
                    }
                    
                    google_calendar_event = calendar_service.update_interview_event(
                        event_id=interview.google_calendar_event_id,
                        interview_data=interview_data,
                        candidate_email=candidate.user.email,
                        hiring_manager_email=hiring_manager.email
                    )
                    
                    if google_calendar_event:
                        calendar_updated = True
                        # Update last sync timestamp
                        interview.last_calendar_sync = datetime.utcnow()
                        current_app.logger.info(f"Google Calendar event updated for interview {interview.id}")
            except Exception as e:
                current_app.logger.error(f"Google Calendar update failed: {e}", exc_info=True)
                # Continue without failing the reschedule

        db.session.commit()

        # Create candidate notification
        notif = Notification(
            user_id=interview.candidate_id,
            message=f"Your interview has been rescheduled from "
                    f"{old_time.strftime('%Y-%m-%d %H:%M:%S')} to "
                    f"{new_time.strftime('%Y-%m-%d %H:%M:%S')}."
        )
        db.session.add(notif)
        db.session.commit()

        # Send reschedule email
        candidate_user = interview.candidate.user
        if candidate_user and candidate_user.email:
            candidate_name = candidate_user.profile.get("full_name")
            if not candidate_name:
                candidate_name = f"{candidate_user.profile.get('first_name', '')} {candidate_user.profile.get('last_name', '')}".strip()

            # Get updated calendar link
            calendar_link = interview.google_calendar_event_link if interview.google_calendar_event_link else None

            EmailService.send_interview_reschedule_email(
                email=candidate_user.email,
                candidate_name=candidate_name or "Candidate",
                old_time=old_time.strftime("%A, %d %B %Y at %H:%M"),
                new_time=new_time.strftime("%A, %d %B %Y at %H:%M"),
                interview_type=interview.interview_type or "Online",
                meeting_link=interview.meeting_link,
                calendar_link=calendar_link
            )

        # Audit log
        current_admin_id = get_jwt_identity()
        AuditService.record_action(
            admin_id=current_admin_id,
            action="Rescheduled Interview",
            target_user_id=interview.candidate_id,
            details=f"Interview {interview_id} rescheduled from {old_time} to {new_time}"
        )

        return jsonify({
            "message": "Interview rescheduled successfully.",
            "interview": interview.to_dict(),
            "calendar_event_updated": calendar_updated
        }), 200

    except Exception as e:
        current_app.logger.error(f"Reschedule interview error: {e}", exc_info=True)
        db.session.rollback()
        return jsonify({"error": "Internal server error"}), 500


# =====================================================
# ❌ CANCEL INTERVIEW (with Google Calendar)
# =====================================================
@admin_bp.route("/interviews/cancel/<int:interview_id>", methods=["DELETE", "OPTIONS"])
@role_required(["admin", "hiring_manager", "hr"])
def cancel_interview(interview_id):
    # Handle CORS preflight
    if request.method == "OPTIONS":
        return jsonify({"status": "OK"}), 200

    try:
        # Fetch the interview
        interview = Interview.query.get(interview_id)
        if not interview:
            return jsonify({"success": False, "error": f"Interview with ID {interview_id} not found"}), 404

        # Fetch candidate
        candidate = Candidate.query.get(interview.candidate_id)
        if not candidate:
            return jsonify({"success": False, "error": "Candidate profile not found"}), 404

        # Store interview details for email before deletion
        interview_details = {
            'scheduled_time': interview.scheduled_time,
            'interview_type': interview.interview_type,
            'meeting_link': interview.meeting_link,
            'google_calendar_event_id': interview.google_calendar_event_id
        }

        # Google Calendar deletion
        calendar_deleted = False
        if current_app.config.get('GOOGLE_CALENDAR_ENABLED') and interview.google_calendar_event_id:
            try:
                from app.services.google_calendar_service import GoogleCalendarService
                calendar_service = GoogleCalendarService()
                calendar_deleted = calendar_service.delete_interview_event(interview.google_calendar_event_id)
                if calendar_deleted:
                    current_app.logger.info(f"Google Calendar event deleted for interview {interview.id}")
            except Exception as e:
                current_app.logger.error(f"Google Calendar deletion failed: {e}", exc_info=True)
                # Continue with interview cancellation even if calendar deletion fails

        # Fetch the linked user (for email)
        user = User.query.get(candidate.user_id)

        # Delete the interview
        db.session.delete(interview)
        db.session.commit()

        # Add notification
        notif = Notification(
            user_id=candidate.user_id,
            message=f"Your interview scheduled for {interview_details['scheduled_time'].strftime('%Y-%m-%d %H:%M:%S')} has been cancelled."
        )
        db.session.add(notif)
        db.session.commit()

        # Send cancellation email
        if user and user.email:
            EmailService.send_interview_cancellation(
                email=user.email,
                candidate_name=candidate.full_name,
                interview_date=interview_details['scheduled_time'].strftime("%A, %d %B %Y at %H:%M"),
                interview_type=interview_details['interview_type'],
                reason="The interview has been cancelled by the admin."
            )

        # Log the action
        AuditService.log(
            user_id=candidate.user_id,
            action="Interview Cancelled",
            details=f"Interview ID {interview_id} cancelled by admin/hiring manager"
        )

        # Return success response for frontend
        return jsonify({
            "success": True,
            "message": "Interview cancelled successfully.",
            "interview_id": interview_id,
            "calendar_event_deleted": calendar_deleted
        }), 200

    except Exception as e:
        current_app.logger.error(f"Cancel interview error: {e}", exc_info=True)
        db.session.rollback()
        return jsonify({"success": False, "error": "Internal server error"}), 500


# =====================================================
# 📅 GOOGLE CALENDAR SYNC ROUTES
# =====================================================

@admin_bp.route("/interviews/calendar/sync", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def sync_google_calendar():
    """Sync interviews with Google Calendar"""
    try:
        if not current_app.config.get('GOOGLE_CALENDAR_ENABLED'):
            return jsonify({"error": "Google Calendar integration is disabled"}), 400
        
        from app.services.google_calendar_service import GoogleCalendarService
        
        calendar_service = GoogleCalendarService()
        events = calendar_service.get_user_events()
        
        # Get all interviews from database
        interviews = Interview.query.filter(
            Interview.scheduled_time >= datetime.utcnow()
        ).all()
        
        # Create a mapping of interview IDs to events
        interview_events = []
        for interview in interviews:
            event_info = None
            
            # Try to find matching event
            for event in events:
                if event.get('interview_id') == str(interview.id):
                    event_info = event
                    break
            
            interview_events.append({
                "interview_id": interview.id,
                "candidate_name": interview.candidate.full_name if interview.candidate else None,
                "scheduled_time": interview.scheduled_time.isoformat() if interview.scheduled_time else None,
                "status": interview.status,
                "has_calendar_event": bool(interview.google_calendar_event_id),
                "calendar_event_synced": bool(event_info),
                "calendar_event_id": interview.google_calendar_event_id,
                "calendar_event_link": interview.google_calendar_event_link,
                "last_sync": interview.last_calendar_sync.isoformat() if interview.last_calendar_sync else None
            })
        
        return jsonify({
            "events": events,
            "interview_sync_status": interview_events,
            "calendar_events_count": len(events),
            "interviews_count": len(interviews)
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Google Calendar sync error: {e}", exc_info=True)
        return jsonify({"error": "Failed to sync with Google Calendar"}), 500


@admin_bp.route("/interviews/<int:interview_id>/calendar/sync", methods=["POST"])
@role_required(["admin", "hiring_manager", "hr"])
def sync_single_interview(interview_id):
    """Sync a single interview with Google Calendar"""
    try:
        interview = Interview.query.get_or_404(interview_id)
        
        if not current_app.config.get('GOOGLE_CALENDAR_ENABLED'):
            return jsonify({"error": "Google Calendar integration is disabled"}), 400
        
        # Fetch candidate and hiring manager
        candidate = interview.candidate
        hiring_manager = User.query.get(interview.hiring_manager_id)
        
        if not candidate or not candidate.user or not hiring_manager:
            return jsonify({"error": "Candidate or hiring manager not found"}), 404
        
        from app.services.google_calendar_service import GoogleCalendarService
        calendar_service = GoogleCalendarService()
        
        interview_data = {
            "id": interview.id,
            "candidate_id": interview.candidate_id,
            "candidate_name": candidate.full_name,
            "job_title": interview.application.requisition.title if interview.application and interview.application.requisition else "Position",
            "scheduled_time": interview.scheduled_time.isoformat(),
            "interview_type": interview.interview_type,
            "meeting_link": interview.meeting_link,
            "status": interview.status,
            "application_id": interview.application_id
        }
        
        if interview.google_calendar_event_id:
            # Try to get the existing event first
            existing_event = calendar_service.get_interview_event(interview.google_calendar_event_id)
            
            if existing_event:
                # Update existing event
                result = calendar_service.update_interview_event(
                    event_id=interview.google_calendar_event_id,
                    interview_data=interview_data,
                    candidate_email=candidate.user.email,
                    hiring_manager_email=hiring_manager.email
                )
                action = "updated"
            else:
                # Event doesn't exist, create new one
                result = calendar_service.create_interview_event(
                    interview_data=interview_data,
                    candidate_email=candidate.user.email,
                    hiring_manager_email=hiring_manager.email
                )
                action = "recreated"
        else:
            # Create new event
            result = calendar_service.create_interview_event(
                interview_data=interview_data,
                candidate_email=candidate.user.email,
                hiring_manager_email=hiring_manager.email
            )
            action = "created"
        
        if result:
            # Update interview with Google Calendar info
            interview.update_calendar_info(result)
            db.session.commit()
            
            return jsonify({
                "message": f"Interview successfully {action} in Google Calendar",
                "calendar_event": result,
                "interview": interview.to_dict()
            }), 200
        else:
            return jsonify({"error": "Failed to sync with Google Calendar"}), 500
            
    except Exception as e:
        current_app.logger.error(f"Single interview sync error: {e}", exc_info=True)
        return jsonify({"error": "Failed to sync interview with Google Calendar"}), 500


# =====================================================
# 🔄 BULK SYNC INTERVIEWS
# =====================================================

@admin_bp.route("/interviews/calendar/bulk-sync", methods=["POST"])
@role_required(["admin", "hiring_manager", "hr"])
def bulk_sync_interviews():
    """Sync multiple interviews with Google Calendar"""
    try:
        if not current_app.config.get('GOOGLE_CALENDAR_ENABLED'):
            return jsonify({"error": "Google Calendar integration is disabled"}), 400
        
        data = request.get_json()
        interview_ids = data.get("interview_ids", [])
        
        if not interview_ids:
            return jsonify({"error": "No interview IDs provided"}), 400
        
        results = []
        success_count = 0
        failure_count = 0
        
        from app.services.google_calendar_service import GoogleCalendarService
        calendar_service = GoogleCalendarService()
        
        for interview_id in interview_ids:
            try:
                interview = Interview.query.get(interview_id)
                if not interview:
                    results.append({
                        "interview_id": interview_id,
                        "status": "failed",
                        "error": "Interview not found"
                    })
                    failure_count += 1
                    continue
                
                # Fetch candidate and hiring manager
                candidate = interview.candidate
                hiring_manager = User.query.get(interview.hiring_manager_id)
                
                if not candidate or not candidate.user or not hiring_manager:
                    results.append({
                        "interview_id": interview_id,
                        "status": "failed",
                        "error": "Candidate or hiring manager not found"
                    })
                    failure_count += 1
                    continue
                
                interview_data = {
                    "id": interview.id,
                    "candidate_id": interview.candidate_id,
                    "candidate_name": candidate.full_name,
                    "job_title": interview.application.requisition.title if interview.application and interview.application.requisition else "Position",
                    "scheduled_time": interview.scheduled_time.isoformat(),
                    "interview_type": interview.interview_type,
                    "meeting_link": interview.meeting_link,
                    "status": interview.status,
                    "application_id": interview.application_id
                }
                
                if interview.google_calendar_event_id:
                    # Update existing event
                    result = calendar_service.update_interview_event(
                        event_id=interview.google_calendar_event_id,
                        interview_data=interview_data,
                        candidate_email=candidate.user.email,
                        hiring_manager_email=hiring_manager.email
                    )
                    action = "updated"
                else:
                    # Create new event
                    result = calendar_service.create_interview_event(
                        interview_data=interview_data,
                        candidate_email=candidate.user.email,
                        hiring_manager_email=hiring_manager.email
                    )
                    action = "created"
                
                if result:
                    interview.update_calendar_info(result)
                    success_count += 1
                    results.append({
                        "interview_id": interview_id,
                        "status": "success",
                        "action": action,
                        "calendar_event_id": result.get('event_id')
                    })
                else:
                    failure_count += 1
                    results.append({
                        "interview_id": interview_id,
                        "status": "failed",
                        "error": "Calendar event creation/update failed"
                    })
                    
            except Exception as e:
                current_app.logger.error(f"Failed to sync interview {interview_id}: {e}")
                failure_count += 1
                results.append({
                    "interview_id": interview_id,
                    "status": "failed",
                    "error": str(e)
                })
        
        db.session.commit()
        
        return jsonify({
            "message": f"Bulk sync completed: {success_count} successful, {failure_count} failed",
            "results": results,
            "success_count": success_count,
            "failure_count": failure_count
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Bulk sync error: {e}", exc_info=True)
        db.session.rollback()
        return jsonify({"error": "Failed to perform bulk sync"}), 500


# =====================================================
# 🔍 GET INTERVIEW CALENDAR STATUS
# =====================================================

@admin_bp.route("/interviews/<int:interview_id>/calendar/status", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def get_interview_calendar_status(interview_id):
    """Get Google Calendar status for a specific interview"""
    try:
        interview = Interview.query.get_or_404(interview_id)
        
        status = {
            "interview_id": interview.id,
            "has_calendar_event": bool(interview.google_calendar_event_id),
            "calendar_event_id": interview.google_calendar_event_id,
            "calendar_event_link": interview.google_calendar_event_link,
            "calendar_hangout_link": interview.google_calendar_hangout_link,
            "last_sync": interview.last_calendar_sync.isoformat() if interview.last_calendar_sync else None,
            "scheduled_time": interview.scheduled_time.isoformat() if interview.scheduled_time else None,
            "status": interview.status
        }
        
        if current_app.config.get('GOOGLE_CALENDAR_ENABLED') and interview.google_calendar_event_id:
            try:
                from app.services.google_calendar_service import GoogleCalendarService
                calendar_service = GoogleCalendarService()
                event = calendar_service.get_interview_event(interview.google_calendar_event_id)
                
                if event:
                    status["calendar_event_exists"] = True
                    status["calendar_event_status"] = event.get('status', 'unknown')
                    status["calendar_event_updated"] = event.get('updated')
                    status["attendees"] = [
                        {"email": attendee.get('email'), "responseStatus": attendee.get('responseStatus')}
                        for attendee in event.get('attendees', [])
                    ]
                else:
                    status["calendar_event_exists"] = False
                    status["calendar_event_status"] = "not_found"
            except Exception as e:
                current_app.logger.error(f"Failed to get calendar event status: {e}")
                status["calendar_event_error"] = str(e)
        
        return jsonify(status), 200
        
    except Exception as e:
        current_app.logger.error(f"Get calendar status error: {e}", exc_info=True)
        return jsonify({"error": "Failed to get calendar status"}), 500
    
@admin_bp.route("/applications", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def get_candidate_applications():
    try:
        candidate_id = request.args.get("candidate_id", type=int)

        # If candidate_id is provided, filter by it
        if candidate_id:
            candidate = Candidate.query.get(candidate_id)
            if not candidate:
                return jsonify({"error": "Candidate not found"}), 404
            applications = Application.query.filter_by(candidate_id=candidate.id).all()
        else:
            # No candidate_id → return all applications
            applications = Application.query.all()

        result = []
        for app in applications:
            assessment_result = AssessmentResult.query.filter_by(application_id=app.id).first()
            result.append({
                "application_id": app.id,
                "candidate_id": app.candidate_id,
                "job_title": app.requisition.title if app.requisition else None,
                "status": app.status,
                "cv_score": app.cv_score,
                "assessment_score": assessment_result.scores if assessment_result else None,
                "overall_score": app.overall_score,
                "recommendation": assessment_result.recommendation if assessment_result else None
            })

        return jsonify(result), 200

    except Exception as e:
        current_app.logger.error(f"Admin get applications error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500
    
# =====================================================
# 🔄 UPDATE INTERVIEW STATUS (Completed, No-show, etc.)
# =====================================================
@admin_bp.route("/interviews/<int:interview_id>/status", methods=["PATCH", "PUT"])
@role_required(["admin", "hiring_manager", "hr"])
def update_interview_status(interview_id):
    """
    Update interview status:
    - scheduled → completed
    - scheduled → no_show
    - scheduled → cancelled_by_candidate
    - scheduled → feedback_pending (when interview done, feedback needed)
    - feedback_pending → feedback_submitted
    """
    try:
        interview = Interview.query.get_or_404(interview_id)
        data = request.get_json()
        new_status = data.get("status")
        notes = data.get("notes", "")
        
        # Valid status transitions
        valid_statuses = ["scheduled", "completed", "no_show", 
                         "cancelled_by_candidate", "feedback_pending", 
                         "feedback_submitted", "cancelled"]
        
        if not new_status or new_status not in valid_statuses:
            return jsonify({
                "error": f"Invalid status. Must be one of: {', '.join(valid_statuses)}"
            }), 400
        
        # Store old status for audit
        old_status = interview.status
        interview.status = new_status
        
        # Add status change notes if provided
        if notes:
            # Create or update interview notes
            interview_notes = InterviewNote.query.filter_by(interview_id=interview_id).first()
            if not interview_notes:
                interview_notes = InterviewNote(interview_id=interview_id)
                db.session.add(interview_notes)
            
            # Append status change note with timestamp
            timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
            status_note = f"\n[{timestamp}] Status changed: {old_status} → {new_status}"
            if notes:
                status_note += f" - {notes}"
            
            if interview_notes.notes:
                interview_notes.notes += status_note
            else:
                interview_notes.notes = status_note
        
        # Special handling for specific statuses
        if new_status == "completed":
            # Automatically move to feedback_pending if not already
            interview.status = "feedback_pending"
            
            # Create notification for hiring manager to submit feedback
            notif = Notification(
                user_id=interview.hiring_manager_id,
                message=f"Interview with {interview.candidate.full_name} marked as completed. "
                       f"Please submit your feedback.",
                type="feedback_reminder",
                interview_id=interview_id
            )
            db.session.add(notif)
            
            # Send email to candidate thanking them
            if interview.candidate and interview.candidate.user:
                EmailService.send_interview_completion_email(
                    email=interview.candidate.user.email,
                    candidate_name=interview.candidate.full_name,
                    interview_date=interview.scheduled_time.strftime("%A, %d %B %Y")
                )
        
        elif new_status == "no_show":
            # Create notification for admin
            notif = Notification(
                user_id=interview.hiring_manager_id,
                message=f"Candidate {interview.candidate.full_name} was a no-show for interview.",
                type="warning",
                interview_id=interview_id
            )
            db.session.add(notif)
            
            # Update candidate's application status if needed
            application = interview.application
            if application:
                application.status = "interview_no_show"
                application.last_updated = datetime.utcnow()
        
        elif new_status == "cancelled_by_candidate":
            # Update Google Calendar if event exists
            if current_app.config.get('GOOGLE_CALENDAR_ENABLED') and interview.google_calendar_event_id:
                try:
                    from app.services.google_calendar_service import GoogleCalendarService
                    calendar_service = GoogleCalendarService()
                    calendar_service.cancel_interview_event(
                        event_id=interview.google_calendar_event_id,
                        reason="Cancelled by candidate"
                    )
                except Exception as e:
                    current_app.logger.error(f"Failed to update Google Calendar: {e}")
            
            # Update application status
            application = interview.application
            if application:
                application.status = "interview_cancelled_by_candidate"
                application.last_updated = datetime.utcnow()
        
        elif new_status == "feedback_submitted":
            # Mark interview as fully complete
            interview.feedback_submitted_at = datetime.utcnow()
            
            # Create notification for next steps
            if interview.candidate:
                notif = Notification(
                    user_id=interview.candidate.user_id,
                    message="Interview feedback has been submitted. You'll hear back soon regarding next steps.",
                    type="info"
                )
                db.session.add(notif)
        
        # Update last modified timestamp
        interview.updated_at = datetime.utcnow()
        db.session.commit()
        
        # Audit log
        current_user_id = get_jwt_identity()
        AuditService.record_action(
            admin_id=current_user_id,
            action=f"Interview Status Updated to {new_status}",
            target_user_id=interview.candidate_id,
            details=f"Interview {interview_id}: {old_status} → {new_status}"
        )
        
        return jsonify({
            "message": f"Interview status updated to {new_status}",
            "interview": {
                "id": interview.id,
                "status": interview.status,
                "candidate_name": interview.candidate.full_name if interview.candidate else None,
                "scheduled_time": interview.scheduled_time.isoformat() if interview.scheduled_time else None,
                "feedback_submitted_at": interview.feedback_submitted_at.isoformat() if interview.feedback_submitted_at else None
            }
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Update interview status error: {e}", exc_info=True)
        db.session.rollback()
        return jsonify({"error": "Internal server error"}), 500
    
# =====================================================
# 📝 SUBMIT INTERVIEW FEEDBACK
# =====================================================
@admin_bp.route("/interviews/<int:interview_id>/feedback", methods=["POST"])
@role_required(["admin", "hiring_manager", "hr"])
def submit_interview_feedback(interview_id):
    """
    Submit structured interview feedback with ratings
    """
    try:
        interview = Interview.query.get_or_404(interview_id)
        
        # Check if interview is ready for feedback
        if interview.status not in ["completed", "feedback_pending"]:
            return jsonify({
                "error": f"Cannot submit feedback for interview with status: {interview.status}"
            }), 400
        
        data = request.get_json()
        
        # Required fields
        required_fields = ["overall_rating", "recommendation"]
        for field in required_fields:
            if field not in data:
                return jsonify({"error": f"Missing required field: {field}"}), 400
        
        # Validate ratings (1-5)
        rating_fields = ["overall_rating", "technical_skills", "communication", 
                        "culture_fit", "problem_solving", "experience_relevance"]
        for field in rating_fields:
            if field in data:
                rating = data[field]
                if not isinstance(rating, int) or rating < 1 or rating > 5:
                    return jsonify({"error": f"{field} must be an integer between 1-5"}), 400
        
        # Validate recommendation
        valid_recommendations = ["strong_hire", "hire", "no_hire", "strong_no_hire", "not_sure"]
        if data["recommendation"] not in valid_recommendations:
            return jsonify({
                "error": f"Invalid recommendation. Must be one of: {', '.join(valid_recommendations)}"
            }), 400
        
        # Get current user (feedback submitter)
        user_id = get_jwt_identity()
        user = User.query.get(user_id)
        
        # Create or update feedback
        feedback = InterviewFeedback.query.filter_by(
            interview_id=interview_id,
            interviewer_id=user_id
        ).first()
        
        if not feedback:
            feedback = InterviewFeedback(
                interview_id=interview_id,
                interviewer_id=user_id,
                interviewer_name=user.full_name if user else "Unknown",
                interviewer_email=user.email if user else None
            )
            db.session.add(feedback)
        
        # Update feedback fields
        feedback.overall_rating = data["overall_rating"]
        feedback.recommendation = data["recommendation"]
        
        # Optional ratings
        feedback.technical_skills = data.get("technical_skills")
        feedback.communication = data.get("communication")
        feedback.culture_fit = data.get("culture_fit")
        feedback.problem_solving = data.get("problem_solving")
        feedback.experience_relevance = data.get("experience_relevance")
        
        # Text feedback
        feedback.strengths = data.get("strengths", "")
        feedback.weaknesses = data.get("weaknesses", "")
        feedback.additional_notes = data.get("additional_notes", "")
        feedback.private_notes = data.get("private_notes", "")  # Only visible to hiring team
        
        # Calculate average score if multiple ratings provided
        ratings = [
            data.get("technical_skills"),
            data.get("communication"),
            data.get("culture_fit"),
            data.get("problem_solving"),
            data.get("experience_relevance")
        ]
        valid_ratings = [r for r in ratings if r is not None]
        if valid_ratings:
            feedback.average_rating = sum(valid_ratings) / len(valid_ratings)
        
        feedback.submitted_at = datetime.utcnow()
        feedback.is_submitted = True
        
        # Update interview status
        interview.status = "feedback_submitted"
        interview.feedback_submitted_at = datetime.utcnow()
        interview.updated_at = datetime.utcnow()
        
        # Update candidate's overall score if needed
        candidate = interview.candidate
        if candidate and interview.application:
            # Get all feedback for this candidate across interviews
            all_feedback = InterviewFeedback.query.join(
                Interview, Interview.id == InterviewFeedback.interview_id
            ).filter(
                Interview.candidate_id == candidate.id,
                InterviewFeedback.is_submitted == True
            ).all()
            
            if all_feedback:
                # Calculate average across all interviews
                total_avg = sum([fb.average_rating or fb.overall_rating for fb in all_feedback])
                candidate.overall_interview_score = total_avg / len(all_feedback)
                
                # Update application score
                application = interview.application
                if application:
                    # Combine CV score (if exists) with interview score
                    cv_weight = 0.3  # 30% CV, 70% interview
                    interview_weight = 0.7
                    
                    cv_score = application.cv_score or 0
                    interview_score = candidate.overall_interview_score or 0
                    
                    application.overall_score = (
                        (cv_score * cv_weight) + 
                        (interview_score * interview_weight)
                    )
        
        # Create notification for hiring manager/admin
        notif = Notification(
            user_id=interview.hiring_manager_id,
            message=f"Feedback submitted for interview with {interview.candidate.full_name}",
            type="feedback_received",
            interview_id=interview_id
        )
        db.session.add(notif)
        
        db.session.commit()
        
        # Send confirmation email to interviewer
        if user and user.email:
            EmailService.send_feedback_confirmation(
                email=user.email,
                interviewer_name=user.full_name,
                candidate_name=interview.candidate.full_name if interview.candidate else "Candidate",
                interview_date=interview.scheduled_time.strftime("%A, %d %B %Y") if interview.scheduled_time else "N/A"
            )
        
        return jsonify({
            "message": "Feedback submitted successfully",
            "feedback": {
                "id": feedback.id,
                "interview_id": feedback.interview_id,
                "interviewer_name": feedback.interviewer_name,
                "overall_rating": feedback.overall_rating,
                "average_rating": feedback.average_rating,
                "recommendation": feedback.recommendation,
                "submitted_at": feedback.submitted_at.isoformat()
            },
            "interview": {
                "status": interview.status,
                "feedback_submitted_at": interview.feedback_submitted_at.isoformat()
            }
        }), 201
        
    except Exception as e:
        current_app.logger.error(f"Submit feedback error: {e}", exc_info=True)
        db.session.rollback()
        return jsonify({"error": "Internal server error"}), 500


# =====================================================
# 📊 GET INTERVIEW FEEDBACK
# =====================================================
@admin_bp.route("/interviews/<int:interview_id>/feedback", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def get_interview_feedback(interview_id):
    """
    Get all feedback for an interview
    """
    try:
        interview = Interview.query.get_or_404(interview_id)
        
        feedback_list = InterviewFeedback.query.filter_by(
            interview_id=interview_id,
            is_submitted=True
        ).all()
        
        feedback_data = []
        for fb in feedback_list:
            feedback_data.append({
                "id": fb.id,
                "interviewer_id": fb.interviewer_id,
                "interviewer_name": fb.interviewer_name,
                "interviewer_email": fb.interviewer_email,
                "overall_rating": fb.overall_rating,
                "technical_skills": fb.technical_skills,
                "communication": fb.communication,
                "culture_fit": fb.culture_fit,
                "problem_solving": fb.problem_solving,
                "experience_relevance": fb.experience_relevance,
                "average_rating": fb.average_rating,
                "recommendation": fb.recommendation,
                "strengths": fb.strengths,
                "weaknesses": fb.weaknesses,
                "additional_notes": fb.additional_notes,
                "submitted_at": fb.submitted_at.isoformat() if fb.submitted_at else None
                # private_notes intentionally omitted from GET response
            })
        
        # Calculate aggregate scores
        if feedback_data:
            overall_avg = sum([fb["overall_rating"] for fb in feedback_data]) / len(feedback_data)
            recommendations = [fb["recommendation"] for fb in feedback_data]
        else:
            overall_avg = None
            recommendations = []
        
        return jsonify({
            "interview_id": interview_id,
            "candidate_name": interview.candidate.full_name if interview.candidate else None,
            "scheduled_time": interview.scheduled_time.isoformat() if interview.scheduled_time else None,
            "status": interview.status,
            "feedback_count": len(feedback_data),
            "overall_average_rating": overall_avg,
            "recommendations": recommendations,
            "feedback": feedback_data
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Get feedback error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500
    
# =====================================================
# 🔔 INTERVIEW REMINDERS SYSTEM
# =====================================================
@admin_bp.route("/interviews/reminders/schedule", methods=["POST"])
@role_required(["admin", "hiring_manager", "hr"])
def schedule_interview_reminders():
    """
    Schedule automated reminders for upcoming interviews
    """
    try:
        data = request.get_json()
        interview_id = data.get("interview_id")
        
        if interview_id:
            # Schedule reminders for specific interview
            interviews = [Interview.query.get_or_404(interview_id)]
        else:
            # Schedule for all upcoming interviews
            now = datetime.utcnow()
            upcoming_cutoff = now + timedelta(days=2)  # Next 48 hours
            interviews = Interview.query.filter(
                Interview.scheduled_time > now,
                Interview.scheduled_time <= upcoming_cutoff,
                Interview.status == "scheduled"
            ).all()
        
        results = []
        for interview in interviews:
            try:
                # Check if reminders already scheduled
                existing_reminders = InterviewReminder.query.filter_by(
                    interview_id=interview.id
                ).count()
                
                if existing_reminders == 0:
                    # Schedule 24-hour reminder
                    reminder_24h = InterviewReminder(
                        interview_id=interview.id,
                        reminder_type="24_hours_before",
                        scheduled_time=interview.scheduled_time - timedelta(hours=24),
                        status="pending"
                    )
                    db.session.add(reminder_24h)
                    
                    # Schedule 1-hour reminder
                    reminder_1h = InterviewReminder(
                        interview_id=interview.id,
                        reminder_type="1_hour_before",
                        scheduled_time=interview.scheduled_time - timedelta(hours=1),
                        status="pending"
                    )
                    db.session.add(reminder_1h)
                    
                    results.append({
                        "interview_id": interview.id,
                        "candidate_name": interview.candidate.full_name if interview.candidate else None,
                        "scheduled_time": interview.scheduled_time.isoformat(),
                        "reminders_scheduled": True,
                        "24h_reminder": reminder_24h.scheduled_time.isoformat(),
                        "1h_reminder": reminder_1h.scheduled_time.isoformat()
                    })
                else:
                    results.append({
                        "interview_id": interview.id,
                        "reminders_scheduled": False,
                        "message": "Reminders already scheduled"
                    })
                    
            except Exception as e:
                current_app.logger.error(f"Failed to schedule reminders for interview {interview.id}: {e}")
                results.append({
                    "interview_id": interview.id,
                    "reminders_scheduled": False,
                    "error": str(e)
                })
        
        db.session.commit()
        
        return jsonify({
            "message": "Reminders scheduled successfully",
            "results": results,
            "total_interviews": len(interviews),
            "reminders_scheduled": len([r for r in results if r.get("reminders_scheduled")])
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Schedule reminders error: {e}", exc_info=True)
        db.session.rollback()
        return jsonify({"error": "Internal server error"}), 500


# =====================================================
# ⚙️ BACKGROUND TASK: SEND REMINDERS
# =====================================================
def send_interview_reminders():
    """
    Background task to send scheduled reminders
    Run this via cron job every 5 minutes
    """
    try:
        now = datetime.utcnow()
        upcoming = now + timedelta(minutes=5)  # Check next 5 minutes
        
        # Find reminders due to be sent
        pending_reminders = InterviewReminder.query.filter(
            InterviewReminder.scheduled_time >= now,
            InterviewReminder.scheduled_time <= upcoming,
            InterviewReminder.status == "pending"
        ).all()
        
        sent_count = 0
        for reminder in pending_reminders:
            try:
                interview = Interview.query.get(reminder.interview_id)
                if not interview or interview.status != "scheduled":
                    reminder.status = "cancelled"
                    continue
                
                # Send reminders based on type
                if reminder.reminder_type == "24_hours_before":
                    send_24_hour_reminder(interview)
                elif reminder.reminder_type == "1_hour_before":
                    send_1_hour_reminder(interview)
                
                # Update reminder status
                reminder.status = "sent"
                reminder.sent_at = datetime.utcnow()
                sent_count += 1
                
                current_app.logger.info(f"Sent {reminder.reminder_type} reminder for interview {interview.id}")
                
            except Exception as e:
                current_app.logger.error(f"Failed to send reminder {reminder.id}: {e}")
                reminder.status = "failed"
                reminder.error_message = str(e)
        
        db.session.commit()
        current_app.logger.info(f"Sent {sent_count} interview reminders")
        
    except Exception as e:
        current_app.logger.error(f"Send reminders background task error: {e}", exc_info=True)


def send_24_hour_reminder(interview):
    """Send 24-hour reminder to candidate and interviewer"""
    # Send to candidate
    if interview.candidate and interview.candidate.user:
        EmailService.send_interview_reminder(
            email=interview.candidate.user.email,
            candidate_name=interview.candidate.full_name,
            interview_date=interview.scheduled_time.strftime("%A, %d %B %Y at %H:%M"),
            interview_type=interview.interview_type,
            meeting_link=interview.meeting_link,
            reminder_type="24_hours",
            timezone="UTC"  # TODO: Get from user profile
        )
    
    # Send to hiring manager
    hiring_manager = User.query.get(interview.hiring_manager_id)
    if hiring_manager:
        EmailService.send_interviewer_reminder(
            email=hiring_manager.email,
            interviewer_name=hiring_manager.full_name,
            candidate_name=interview.candidate.full_name if interview.candidate else "Candidate",
            interview_date=interview.scheduled_time.strftime("%A, %d %B %Y at %H:%M"),
            interview_type=interview.interview_type,
            meeting_link=interview.meeting_link,
            reminder_type="24_hours",
            timezone="UTC"
        )
    
    # Send in-app notification
    notif_candidate = Notification(
        user_id=interview.candidate_id,
        message=f"Reminder: Your interview is tomorrow at {interview.scheduled_time.strftime('%H:%M')}. Please be prepared.",
        type="reminder",
        interview_id=interview.id
    )
    db.session.add(notif_candidate)
    
    notif_interviewer = Notification(
        user_id=interview.hiring_manager_id,
        message=f"Reminder: Interview with {interview.candidate.full_name} tomorrow at {interview.scheduled_time.strftime('%H:%M')}",
        type="reminder",
        interview_id=interview.id
    )
    db.session.add(notif_interviewer)


def send_1_hour_reminder(interview):
    """Send 1-hour reminder to candidate and interviewer"""
    # Send to candidate
    if interview.candidate and interview.candidate.user:
        EmailService.send_interview_reminder(
            email=interview.candidate.user.email,
            candidate_name=interview.candidate.full_name,
            interview_date=interview.scheduled_time.strftime("%A, %d %B %Y at %H:%M"),
            interview_type=interview.interview_type,
            meeting_link=interview.meeting_link,
            reminder_type="1_hour",
            timezone="UTC"
        )
    
    # Send to hiring manager
    hiring_manager = User.query.get(interview.hiring_manager_id)
    if hiring_manager:
        EmailService.send_interviewer_reminder(
            email=hiring_manager.email,
            interviewer_name=hiring_manager.full_name,
            candidate_name=interview.candidate.full_name if interview.candidate else "Candidate",
            interview_date=interview.scheduled_time.strftime("%A, %d %B %Y at %H:%M"),
            interview_type=interview.interview_type,
            meeting_link=interview.meeting_link,
            reminder_type="1_hour",
            timezone="UTC"
        )
    
    # Send in-app notification
    notif_candidate = Notification(
        user_id=interview.candidate_id,
        message=f"Your interview starts in 1 hour: {interview.scheduled_time.strftime('%H:%M')}. Join: {interview.meeting_link}",
        type="reminder_urgent",
        interview_id=interview.id
    )
    db.session.add(notif_candidate)
    
    notif_interviewer = Notification(
        user_id=interview.hiring_manager_id,
        message=f"Interview with {interview.candidate.full_name} in 1 hour. Join: {interview.meeting_link}",
        type="reminder_urgent",
        interview_id=interview.id
    )
    db.session.add(notif_interviewer)


# =====================================================
# 📋 GET SCHEDULED REMINDERS
# =====================================================
@admin_bp.route("/interviews/<int:interview_id>/reminders", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def get_interview_reminders(interview_id):
    """Get all reminders for an interview"""
    try:
        reminders = InterviewReminder.query.filter_by(
            interview_id=interview_id
        ).order_by(InterviewReminder.scheduled_time).all()
        
        reminder_data = []
        for reminder in reminders:
            reminder_data.append({
                "id": reminder.id,
                "reminder_type": reminder.reminder_type,
                "scheduled_time": reminder.scheduled_time.isoformat() if reminder.scheduled_time else None,
                "sent_at": reminder.sent_at.isoformat() if reminder.sent_at else None,
                "status": reminder.status,
                "error_message": reminder.error_message
            })
        
        return jsonify({
            "interview_id": interview_id,
            "total_reminders": len(reminder_data),
            "reminders": reminder_data
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Get reminders error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500
    
@admin_bp.route("/applications/all", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def get_all_applications():
    applications = Application.query.all()
    result = []

    for app in applications:
        result.append({
            "application_id": app.id,
            "candidate_name": app.candidate.full_name if app.candidate else None,
            "job_title": app.requisition.title if app.requisition else None,
            "status": app.status,
            "applied_date": app.created_at.isoformat() if app.created_at else None
        })

    return jsonify(result), 200


@admin_bp.route("/interviews/all", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def get_all_interviews():
    """
    Fetch all interviews with pagination, search, and filters.
    Accessible to admin and hiring_manager roles.
    """
    try:
        # ---------------- Query Params ----------------
        page = request.args.get("page", 1, type=int)
        per_page = request.args.get("per_page", 10, type=int)
        search = request.args.get("search", type=str)
        status = request.args.get("status", type=str)
        interview_type = request.args.get("interview_type", type=str)
        sort_by = request.args.get("sort_by", "created_at")
        sort_order = request.args.get("sort_order", "desc")

        # ---------------- Base Query ----------------
        query = Interview.query.join(Interview.candidate).join(Interview.hiring_manager).outerjoin(Interview.application)

        # ---------------- Filters ----------------
        if status:
            query = query.filter(Interview.status.ilike(f"%{status}%"))
        if interview_type:
            query = query.filter(Interview.interview_type.ilike(f"%{interview_type}%"))
        if search:
            search_pattern = f"%{search}%"
            query = query.filter(
                db.or_(
                    Candidate.full_name.ilike(search_pattern),
                    getattr(User, "first_name", "").ilike(search_pattern),
                    getattr(User, "last_name", "").ilike(search_pattern),
                    Interview.meeting_link.ilike(search_pattern)
                )
            )

        # ---------------- Sorting ----------------
        sort_column = getattr(Interview, sort_by, Interview.created_at)
        if sort_order.lower() == "desc":
            sort_column = sort_column.desc()
        query = query.order_by(sort_column)

        # ---------------- Pagination ----------------
        pagination = query.paginate(page=page, per_page=per_page, error_out=False)
        interviews = pagination.items

        # ---------------- Response ----------------
        enriched = []
        for i in interviews:
            # Safe candidate name
            candidate_name = i.candidate.full_name if i.candidate and hasattr(i.candidate, "full_name") else None

            # Safe hiring manager name
            hiring_manager_name = None
            if i.hiring_manager:
                first = getattr(i.hiring_manager, "first_name", "")
                last = getattr(i.hiring_manager, "last_name", "")
                hiring_manager_name = f"{first} {last}".strip() or None

            enriched.append({
                "id": i.id,
                "candidate_id": i.candidate_id,
                "candidate_name": candidate_name,
                "hiring_manager_id": i.hiring_manager_id,
                "hiring_manager_name": hiring_manager_name,
                "application_id": i.application_id,
                "job_title": (
                    i.application.requisition.title
                    if i.application and hasattr(i.application, "requisition") and i.application.requisition
                    else None
                ),
                "scheduled_time": i.scheduled_time.isoformat() if i.scheduled_time else None,
                "interview_type": i.interview_type,
                "meeting_link": i.meeting_link,
                "status": i.status,
                "created_at": i.created_at.isoformat() if i.created_at else None,
            })

        return jsonify({
            "page": page,
            "per_page": per_page,
            "total": pagination.total,
            "pages": pagination.pages,
            "interviews": enriched
        }), 200

    except Exception as e:
        current_app.logger.error(f"Error fetching all interviews: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500


    
@admin_bp.route("/recent-activities", methods=["GET"])
@jwt_required()
@role_required("admin")
def recent_activities():
    try:
        activities = []

        # Recent job applications
        applications = Application.query.order_by(Application.created_at.desc()).limit(5).all()
        for app in applications:
            user_profile = app.candidate.user.profile or {}
            candidate_name = f"{user_profile.get('first_name', '')} {user_profile.get('last_name', '')}".strip() or "Unknown"
            job_title = app.requisition.title if app.requisition else "Unknown Position"
            activities.append(f"{candidate_name} submitted CV for {job_title}")

        # Recent job postings
        requisitions = Requisition.query.order_by(Requisition.created_at.desc()).limit(5).all()
        for req in requisitions:
            activities.append(f"New job posted: {req.title}")

        # Recent interviews (FIXED: scheduled_time)
        interviews = Interview.query.order_by(Interview.scheduled_time.desc()).limit(5).all()
        for i in interviews:
            user_profile = i.candidate.user.profile or {}
            candidate_name = f"{user_profile.get('first_name', '')} {user_profile.get('last_name', '')}".strip() or "Unknown"
            activities.append(f"Interview scheduled: {candidate_name}")

        # Recent CV reviews
        reviews = AssessmentResult.query.order_by(AssessmentResult.created_at.desc()).limit(5).all()
        for r in reviews:
            user_profile = r.application.candidate.user.profile or {}
            candidate_name = f"{user_profile.get('first_name', '')} {user_profile.get('last_name', '')}".strip() or "Unknown"
            activities.append(f"CV review completed: {candidate_name}")

        # Recent notifications
        notifications = Notification.query.order_by(Notification.created_at.desc()).limit(5).all()
        for n in notifications:
            activities.append(f"Notification: {n.message}")

        return jsonify({"recentActivities": activities}), 200

    except Exception as e:
        current_app.logger.error(f"Error fetching recent activities: {str(e)}", exc_info=True)
        return jsonify({"error": str(e)}), 500

# ==========================
# Power BI Data & Status
# ==========================

@admin_bp.route("/powerbi/data", methods=["GET"])
@role_required(["admin"])
def powerbi_data():
    """
    Flattened data for Power BI with optional filters:
    - job_id
    - candidate_id
    - status
    - start_date, end_date (ISO format)
    """
    try:
        # --- Get filters from query params ---
        job_id = request.args.get("job_id", type=int)
        candidate_id = request.args.get("candidate_id", type=int)
        status = request.args.get("status", type=str)
        start_date_str = request.args.get("start_date")
        end_date_str = request.args.get("end_date")

        # --- Build base query ---
        query = Application.query

        if job_id:
            query = query.filter_by(requisition_id=job_id)
        if candidate_id:
            query = query.filter_by(candidate_id=candidate_id)
        if status:
            query = query.filter_by(status=status)

        if start_date_str:
            try:
                start_date = datetime.fromisoformat(start_date_str)
                query = query.filter(Application.created_at >= start_date)
            except ValueError:
                return jsonify({"error": "Invalid start_date format. Use YYYY-MM-DD or ISO format"}), 400

        if end_date_str:
            try:
                end_date = datetime.fromisoformat(end_date_str)
                query = query.filter(Application.created_at <= end_date)
            except ValueError:
                return jsonify({"error": "Invalid end_date format. Use YYYY-MM-DD or ISO format"}), 400

        applications = query.all()
        data = []

        for app in applications:
            candidate = app.candidate
            user = candidate.user if candidate else None
            job = app.requisition
            assessment = AssessmentResult.query.filter_by(application_id=app.id).first()
            interviews = Interview.query.filter_by(application_id=app.id).all()

            data.append({
                "application_id": app.id,
                "application_status": app.status,
                "cv_score": app.cv_score,
                "assessment_score": app.assessment_score,
                "overall_score": app.overall_score,
                "recommendation": assessment.recommendation if assessment else None,
                "candidate_id": candidate.id if candidate else None,
                "candidate_name": candidate.full_name if candidate else None,
                "candidate_email": user.email if user else None,
                "candidate_verified": user.is_verified if user else None,
                "job_id": job.id if job else None,
                "job_title": job.title if job else None,
                "job_category": job.category if job else None,
                "interview_count": len(interviews),
                "interview_dates": [i.scheduled_time.isoformat() for i in interviews]
            })

        return jsonify(data), 200

    except Exception as e:
        current_app.logger.error(f"Power BI filtered data error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500


@admin_bp.route("/powerbi/status", methods=["GET"])
@role_required(["admin"])
def powerbi_status():
    """
    Simple status check for admin dashboard:
    - Returns connection success and latest update timestamp
    """
    try:
        latest_application = Application.query.order_by(Application.created_at.desc()).first()
        latest_update = latest_application.created_at.isoformat() if latest_application else None

        return jsonify({
            "connected": True,
            "latest_update": latest_update,
            "message": "Power BI data endpoint reachable."
        }), 200

    except Exception as e:
        current_app.logger.error(f"Power BI status check error: {e}", exc_info=True)
        return jsonify({
            "connected": False,
            "message": "Unable to reach Power BI data endpoint."
        }), 500


@admin_bp.route("/applications/<int:application_id>/download-cv", methods=["GET", "OPTIONS"])
@role_required(["admin", "hiring_manager", "hr"])
def download_application_cv(application_id):
    """
    Returns the CV URL for the given application.
    Handles CORS preflight OPTIONS request.
    """
    # Handle preflight CORS
    if request.method == "OPTIONS":
        return '', 200

    # Fetch application
    application = Application.query.get_or_404(application_id)

    # Check if CV is uploaded
    if not application.resume_url:
        return jsonify({"error": "CV not uploaded"}), 404

    return jsonify({
        "application_id": application.id,
        "candidate_name": application.candidate.full_name,  # via relationship
        "cv_url": application.resume_url
    }), 200

    
@admin_bp.route("/candidates/all", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def get_all_candidates():
    """
    Fetch all candidates with their profile info.
    """
    try:
        candidates = Candidate.query.all()
        enriched = [c.to_dict() for c in candidates]

        return jsonify({
            "total": len(enriched),
            "candidates": enriched
        }), 200
    except Exception as e:
        current_app.logger.error(f"Error fetching candidates: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500
    
@admin_bp.route('/api/auth/enroll_mfa/<int:user_id>', methods=['POST'])
@jwt_required()
def enroll_mfa(user_id):
    current_user_id = get_jwt_identity()
    current_user = User.query.get(current_user_id)

    # ------------------- Admin check -------------------
    if current_user.role.lower() != "admin":
        return jsonify({"error": "Only admins can enroll MFA"}), 403

    # ------------------- Target user -------------------
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404

    # ------------------- Generate MFA secret -------------------
    if not user.mfa_secret:
        user.mfa_secret = pyotp.random_base32()

    user.mfa_enabled = True
    db.session.commit()

    # ------------------- Audit log -------------------
    AuditService.log(
        user_id=current_user.id,
        action=f"enrolled_mfa_for_user_{user.id}"
    )

    # ------------------- Generate QR code URI -------------------
    totp = pyotp.TOTP(user.mfa_secret)
    otp_uri = totp.provisioning_uri(name=user.email, issuer_name="YourAppName")

    return jsonify({
        'message': 'MFA enrollment successful',
        'otp_uri': otp_uri,
        'secret': user.mfa_secret
    }), 200
    
# ============================================================
# SHARED NOTES & MEETINGS MANAGEMENT (ADMIN + HIRING MANAGER)
# ============================================================


# -------------------- SHARED NOTES --------------------
@admin_bp.route('/shared-notes', methods=['GET'])
@role_required(["admin", "hiring_manager"])
def get_shared_notes():
    """Get all shared notes with pagination and filtering"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 20, type=int)
        search = request.args.get('search', '', type=str)
        author_id = request.args.get('author_id', type=int)
        
        # Base query
        query = SharedNote.query
        
        # Apply filters
        if search:
            query = query.filter(
                or_(
                    SharedNote.title.ilike(f'%{search}%'),
                    SharedNote.content.ilike(f'%{search}%')
                )
            )
        
        if author_id:
            query = query.filter(SharedNote.author_id == author_id)
        
        # Order and paginate
        notes = query.order_by(SharedNote.created_at.desc()).paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        return jsonify({
            'notes': [note.to_dict() for note in notes.items],
            'total': notes.total,
            'pages': notes.pages,
            'current_page': page,
            'per_page': per_page
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Error fetching shared notes: {str(e)}")
        return jsonify({"error": "Failed to fetch shared notes"}), 500


@admin_bp.route('/shared-notes/<int:note_id>', methods=['GET'])
@role_required(["admin", "hiring_manager"])
def get_shared_note(note_id):
    """Get a specific shared note"""
    try:
        note = SharedNote.query.get_or_404(note_id)
        return jsonify(note.to_dict()), 200
    except Exception as e:
        current_app.logger.error(f"Error fetching note {note_id}: {str(e)}")
        return jsonify({"error": "Failed to fetch note"}), 500


def sanitize_html(content):
    """Sanitize HTML content to prevent XSS"""
    allowed_tags = ['p', 'br', 'strong', 'em', 'u', 'ul', 'ol', 'li', 'h1', 'h2', 'h3', 'h4']
    allowed_attributes = {
        'a': ['href', 'title'],
        'img': ['src', 'alt', 'width', 'height']
    }
    return bleach.clean(
        content, 
        tags=allowed_tags, 
        attributes=allowed_attributes,
        strip=True
    )


@admin_bp.route('/shared-notes', methods=['POST'])
@role_required(["admin", "hiring_manager"])
def create_shared_note():
    """Create a new shared note"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400
            
        user_id = get_jwt_identity()
        title = data.get("title", "").strip()
        content = data.get("content", "").strip()
        tags = data.get("tags", [])
        is_pinned = data.get("is_pinned", False)

        # Validation
        if not title or not content:
            return jsonify({"error": "Title and content are required"}), 400
            
        if len(title) > 255:
            return jsonify({"error": "Title too long (max 255 characters)"}), 400
            
        if len(content) > 10000:
            return jsonify({"error": "Content too long (max 10,000 characters)"}), 400

        # Sanitize content
        sanitized_content = sanitize_html(content)
        
        # Create note
        note = SharedNote(
            title=title, 
            content=sanitized_content, 
            author_id=user_id,
            tags=tags,
            is_pinned=is_pinned
        )
        
        db.session.add(note)
        db.session.commit()

        AuditService.record_action(admin_id=user_id, action="create_shared_note", details=f"Created note '{title}'")
        return jsonify({
            "message": "Note created successfully", 
            "note": note.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Error creating shared note: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500


@admin_bp.route('/shared-notes/<int:note_id>', methods=['PUT'])
@role_required(["admin", "hiring_manager"])
def update_shared_note(note_id):
    """Update an existing shared note"""
    try:
        user_id = get_jwt_identity()
        note = SharedNote.query.get_or_404(note_id)
        
        # Authorization check - only author or admin can edit
        user_roles = get_jwt().get("roles", [])
        if note.author_id != user_id and "admin" not in user_roles:
            return jsonify({"error": "Not authorized to edit this note"}), 403

        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400
            
        # Update fields
        if "title" in data:
            title = data.get("title", "").strip()
            if not title:
                return jsonify({"error": "Title cannot be empty"}), 400
            if len(title) > 255:
                return jsonify({"error": "Title too long (max 255 characters)"}), 400
            note.title = title
            
        if "content" in data:
            content = data.get("content", "").strip()
            if not content:
                return jsonify({"error": "Content cannot be empty"}), 400
            if len(content) > 10000:
                return jsonify({"error": "Content too long (max 10,000 characters)"}), 400
            note.content = sanitize_html(content)
            
        if "tags" in data:
            note.tags = data.get("tags", [])
            
        if "is_pinned" in data:
            note.is_pinned = data.get("is_pinned", False)

        note.updated_at = datetime.utcnow()
        db.session.commit()

        AuditService.record_action(admin_id=user_id, action="update_shared_note", details=f"Updated note '{note.title}'")
        return jsonify({
            "message": "Note updated successfully", 
            "note": note.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Error updating shared note {note_id}: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500


@admin_bp.route('/shared-notes/<int:note_id>', methods=['DELETE'])
@role_required(["admin", "hiring_manager"])
def delete_shared_note(note_id):
    """Delete a shared note"""
    try:
        user_id = get_jwt_identity()
        note = SharedNote.query.get_or_404(note_id)
        
        # Authorization check - only author or admin can delete
        user_roles = get_jwt_claims().get("roles", [])
        if note.author_id != user_id and "admin" not in user_roles:
            return jsonify({"error": "Not authorized to delete this note"}), 403

        note_title = note.title
        db.session.delete(note)
        db.session.commit()

        AuditService.record_action(admin_id=user_id, action="delete_shared_note", details=f"Deleted note '{note_title}'")
        return jsonify({"message": "Note deleted successfully"}), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Error deleting shared note {note_id}: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500


# -------------------- MEETINGS --------------------
def validate_meeting_times(start_time, end_time):
    """Validate meeting time logic"""
    if start_time >= end_time:
        return False, "End time must be after start time"
    
    if start_time < datetime.now():
        return False, "Meeting cannot be scheduled in the past"
        
    # Check if meeting is too long (more than 8 hours)
    meeting_duration = end_time - start_time
    if meeting_duration.total_seconds() > 8 * 3600:
        return False, "Meeting duration cannot exceed 8 hours"
        
    return True, None


def validate_participants(participants):
    """Validate participant email addresses"""
    import re
    email_pattern = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
    
    for email in participants:
        if not email_pattern.match(email):
            return False, f"Invalid email format: {email}"
            
    return True, None


@admin_bp.route('/meetings', methods=['GET'])
@role_required(["admin", "hiring_manager"])
def get_meetings():
    """Get all meetings with filtering and pagination"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 20, type=int)
        status = request.args.get('status', type=str)  # upcoming, past, cancelled
        search = request.args.get('search', '', type=str)
        
        # Base query
        query = Meeting.query
        
        # Apply filters
        if search:
            query = query.filter(
                or_(
                    Meeting.title.ilike(f'%{search}%'),
                    Meeting.description.ilike(f'%{search}%')
                )
            )
        
        now = datetime.now()
        if status == 'upcoming':
            query = query.filter(
                and_(
                    Meeting.start_time > now,
                    Meeting.cancelled == False
                )
            )
        elif status == 'past':
            query = query.filter(
                and_(
                    Meeting.end_time < now,
                    Meeting.cancelled == False
                )
            )
        elif status == 'cancelled':
            query = query.filter(Meeting.cancelled == True)
        elif status == 'active':
            query = query.filter(
                and_(
                    Meeting.start_time <= now,
                    Meeting.end_time >= now,
                    Meeting.cancelled == False
                )
            )
        # If status is None (All), show all meetings including cancelled
        
        # Order and paginate
        meetings = query.order_by(Meeting.start_time.desc()).paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        return jsonify({
            'meetings': [m.to_dict() for m in meetings.items],
            'total': meetings.total,
            'pages': meetings.pages,
            'current_page': page,
            'per_page': per_page
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Error fetching meetings: {str(e)}")
        return jsonify({"error": "Failed to fetch meetings"}), 500


@admin_bp.route('/meetings/<int:meeting_id>', methods=['GET'])
@role_required(["admin", "hiring_manager"])
def get_meeting(meeting_id):
    """Get a specific meeting"""
    try:
        meeting = Meeting.query.get_or_404(meeting_id)
        return jsonify(meeting.to_dict()), 200
    except Exception as e:
        current_app.logger.error(f"Error fetching meeting {meeting_id}: {str(e)}")
        return jsonify({"error": "Failed to fetch meeting"}), 500


@admin_bp.route('/meetings', methods=['POST'])
@role_required(["admin", "hiring_manager"])
def create_meeting():
    """Create a new meeting"""
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400

        # Required fields
        title = data.get("title", "").strip()
        start_time_str = data.get("start_time")
        end_time_str = data.get("end_time")
        
        if not title or not start_time_str or not end_time_str:
            return jsonify({"error": "Title, start_time, and end_time are required"}), 400

        # Parse and validate times
        try:
            # Handle timezone indicators
            start_time_str_clean = start_time_str.replace('Z', '+00:00') if 'Z' in start_time_str else start_time_str
            end_time_str_clean = end_time_str.replace('Z', '+00:00') if 'Z' in end_time_str else end_time_str
            start_time = datetime.fromisoformat(start_time_str_clean)
            end_time = datetime.fromisoformat(end_time_str_clean)
        except (ValueError, AttributeError) as e:
            current_app.logger.error(f"Datetime parsing error: {e}, start_time_str: {start_time_str}, end_time_str: {end_time_str}")
            return jsonify({"error": f"Invalid datetime format. Use ISO format. Error: {str(e)}"}), 400

        # Validate meeting times
        is_valid, error_msg = validate_meeting_times(start_time, end_time)
        if not is_valid:
            return jsonify({"error": error_msg}), 400

        # Optional fields
        description = data.get("description", "").strip()
        participants = data.get("participants", [])
        meeting_link = data.get("meeting_link", "").strip()
        location = data.get("location", "").strip()
        meeting_type = data.get("meeting_type", "general")

        # Validate participants
        if participants:
            is_valid, error_msg = validate_participants(participants)
            if not is_valid:
                return jsonify({"error": error_msg}), 400

        # Check for scheduling conflicts
        conflicting_meeting = Meeting.query.filter(
            Meeting.organizer_id == user_id,
            Meeting.cancelled == False,
            Meeting.start_time < end_time,
            Meeting.end_time > start_time
        ).first()
        
        if conflicting_meeting:
            return jsonify({
                "error": "Scheduling conflict detected",
                "conflicting_meeting": conflicting_meeting.to_dict()
            }), 409

        # Create meeting
        meeting = Meeting(
            title=title,
            description=description,
            start_time=start_time,
            end_time=end_time,
            organizer_id=user_id,
            participants=participants,
            meeting_link=meeting_link,
            location=location,
            meeting_type=meeting_type
        )

        db.session.add(meeting)
        db.session.commit()

        # Send email notifications (if enabled)
        if participants and current_app.config.get('SEND_MEETING_EMAILS', True):
            try:
                for participant in participants:
                    EmailService.send_meeting_invitation(
                        email=participant,
                        meeting_title=title,
                        meeting_date=start_time,
                        meeting_description=description,
                        meeting_link=meeting_link,
                        location=location,
                        organizer_id=user_id
                    )
            except Exception as e:
                current_app.logger.warning(f"Failed to send meeting invite emails: {e}")
                # Don't fail the request if emails fail

        AuditService.record_action(admin_id=user_id, action="create_meeting", details=f"Created meeting '{title}'")
        return jsonify({
            "message": "Meeting created successfully", 
            "meeting": meeting.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Error creating meeting: {str(e)}", exc_info=True)
        return jsonify({"error": f"Internal server error: {str(e)}"}), 500


@admin_bp.route('/meetings/<int:meeting_id>', methods=['PUT'])
@role_required(["admin", "hiring_manager"])
def update_meeting(meeting_id):
    """Update meeting details"""
    try:
        user_id = get_jwt_identity()
        meeting = Meeting.query.get_or_404(meeting_id)
        
        # Authorization check
        user_roles = get_jwt_claims().get("roles", [])
        if meeting.organizer_id != user_id and "admin" not in user_roles:
            return jsonify({"error": "Not authorized to edit this meeting"}), 403

        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400

        # Update fields
        if "title" in data:
            meeting.title = data.get("title", "").strip()
            if not meeting.title:
                return jsonify({"error": "Title cannot be empty"}), 400

        if "description" in data:
            meeting.description = data.get("description", "").strip()

        if "participants" in data:
            participants = data.get("participants", [])
            is_valid, error_msg = validate_participants(participants)
            if not is_valid:
                return jsonify({"error": error_msg}), 400
            meeting.participants = participants

        if "meeting_link" in data:
            meeting.meeting_link = data.get("meeting_link", "").strip()

        if "location" in data:
            meeting.location = data.get("location", "").strip()

        if "meeting_type" in data:
            meeting.meeting_type = data.get("meeting_type", "general")

        # Handle time updates with validation
        start_time_changed = "start_time" in data
        end_time_changed = "end_time" in data
        
        if start_time_changed or end_time_changed:
            new_start_time = datetime.fromisoformat(data["start_time"].replace('Z', '+00:00')) if start_time_changed else meeting.start_time
            new_end_time = datetime.fromisoformat(data["end_time"].replace('Z', '+00:00')) if end_time_changed else meeting.end_time
            
            is_valid, error_msg = validate_meeting_times(new_start_time, new_end_time)
            if not is_valid:
                return jsonify({"error": error_msg}), 400
                
            # Check for scheduling conflicts (excluding current meeting)
            conflicting_meeting = Meeting.query.filter(
                Meeting.organizer_id == user_id,
                Meeting.cancelled == False,
                Meeting.id != meeting_id,
                Meeting.start_time < new_end_time,
                Meeting.end_time > new_start_time
            ).first()
            
            if conflicting_meeting:
                return jsonify({
                    "error": "Scheduling conflict detected",
                    "conflicting_meeting": conflicting_meeting.to_dict()
                }), 409

            meeting.start_time = new_start_time
            meeting.end_time = new_end_time

        meeting.updated_at = datetime.utcnow()
        db.session.commit()

        AuditService.record_action(admin_id=user_id, action="update_meeting", details=f"Updated meeting '{meeting.title}'")
        return jsonify({
            "message": "Meeting updated successfully", 
            "meeting": meeting.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Error updating meeting {meeting_id}: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500


@admin_bp.route('/meetings/<int:meeting_id>/cancel', methods=['POST'])
@role_required(["admin", "hiring_manager"])
def cancel_meeting(meeting_id):
    """Cancel a meeting"""
    try:
        user_id = get_jwt_identity()
        meeting = Meeting.query.get_or_404(meeting_id)
        
        # Authorization check
        user_roles = get_jwt_claims().get("roles", [])
        if meeting.organizer_id != user_id and "admin" not in user_roles:
            return jsonify({"error": "Not authorized to cancel this meeting"}), 403

        if meeting.cancelled:
            return jsonify({"error": "Meeting is already cancelled"}), 400

        meeting.cancelled = True
        meeting.cancelled_at = datetime.utcnow()
        meeting.cancelled_by = user_id
        db.session.commit()

        # Send cancellation emails
        if meeting.participants and current_app.config.get('SEND_MEETING_EMAILS', True):
            try:
                for participant in meeting.participants:
                    EmailService.send_meeting_cancellation(
                        email=participant,
                        meeting_title=meeting.title,
                        meeting_date=meeting.start_time,
                        cancellation_reason="Meeting cancelled by organizer"
                    )
            except Exception as e:
                current_app.logger.warning(f"Failed to send meeting cancellation emails: {e}")

        AuditService.record_action(admin_id=user_id, action="cancel_meeting", details=f"Cancelled meeting '{meeting.title}'")
        return jsonify({"message": "Meeting cancelled successfully"}), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Error cancelling meeting {meeting_id}: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500


@admin_bp.route('/meetings/<int:meeting_id>', methods=['DELETE'])
@role_required(["admin", "hiring_manager"])
def delete_meeting(meeting_id):
    """Delete a meeting"""
    try:
        user_id = get_jwt_identity()
        meeting = Meeting.query.get_or_404(meeting_id)
        
        # Authorization check
        user_roles = get_jwt_claims().get("roles", [])
        if meeting.organizer_id != user_id and "admin" not in user_roles:
            return jsonify({"error": "Not authorized to delete this meeting"}), 403

        meeting_title = meeting.title
        db.session.delete(meeting)
        db.session.commit()

        AuditService.record_action(admin_id=user_id, action="delete_meeting", details=f"Deleted meeting '{meeting_title}'")
        return jsonify({"message": "Meeting deleted successfully"}), 200
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Error deleting meeting {meeting_id}: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500


@admin_bp.route('/meetings/upcoming', methods=['GET'])
@jwt_required()
@role_required(["admin", "hiring_manager"])
def get_upcoming_meetings():
    """
    Get upcoming meetings for the current user with pagination, optional filters.
    Filters:
        - start_date, end_date (YYYY-MM-DD)
        - keyword (search in title or description)
    Pagination:
        - limit (default 10)
        - offset (default 0)
    """
    try:
        # --- Get user info from JWT ---
        user_id = get_jwt_identity()
        user = User.query.get(user_id)
        if not user:
            return jsonify({"error": "User not found"}), 404
        user_email = user.email

        # --- Pagination ---
        limit = request.args.get('limit', 10, type=int)
        offset = request.args.get('offset', 0, type=int)

        # --- Optional filters ---
        start_date_str = request.args.get("start_date")
        end_date_str = request.args.get("end_date")
        keyword = request.args.get("keyword", "").strip()

        query = Meeting.query.filter(Meeting.start_time > datetime.now())

        # cancelled filter if column exists
        if hasattr(Meeting, "cancelled"):
            query = query.filter(Meeting.cancelled == False)

        # user is organizer OR participant
        from sqlalchemy.dialects.postgresql import JSONB
        query = query.filter(
            or_(
                Meeting.organizer_id == user_id,
                Meeting.participants.cast(JSONB).contains([user_email])
            )
        )

        # filter by date range
        if start_date_str:
            try:
                start_date = datetime.strptime(start_date_str, "%Y-%m-%d")
                query = query.filter(Meeting.start_time >= start_date)
            except ValueError:
                return jsonify({"error": "Invalid start_date format, use YYYY-MM-DD"}), 400

        if end_date_str:
            try:
                end_date = datetime.strptime(end_date_str, "%Y-%m-%d")
                query = query.filter(Meeting.start_time <= end_date)
            except ValueError:
                return jsonify({"error": "Invalid end_date format, use YYYY-MM-DD"}), 400

        # keyword search
        if keyword:
            query = query.filter(
                or_(
                    Meeting.title.ilike(f"%{keyword}%"),
                    Meeting.description.ilike(f"%{keyword}%")
                )
            )

        total_count = query.count()

        meetings = (
            query.order_by(Meeting.start_time.asc())
                 .offset(offset)
                 .limit(limit)
                 .all()
        )

        # --- Serialize meetings safely ---
        meetings_data = []
        for m in meetings:
            participants_list = m.participants if isinstance(m.participants, list) else []
            meetings_data.append({
                "id": m.id,
                "title": m.title,
                "description": m.description,
                "start_time": m.start_time.isoformat(),
                "end_time": m.end_time.isoformat() if m.end_time else None,
                "organizer_id": m.organizer_id,
                "participants": participants_list,
                "meeting_link": m.meeting_link,
                "cancelled": m.cancelled if hasattr(m, "cancelled") else False
            })

        return jsonify({
            "total": total_count,
            "limit": limit,
            "offset": offset,
            "meetings": meetings_data
        }), 200

    except Exception as e:
        current_app.logger.error(f"Error fetching upcoming meetings: {str(e)}")
        return jsonify({"error": "Failed to fetch upcoming meetings"}), 500

@admin_bp.route("/candidates/ready-for-offer", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def get_candidates_ready_for_offer():
    try:
        min_interviews = request.args.get('min_interviews', 2, type=int)
        min_avg_rating = request.args.get('min_rating', 3.5, type=float)
        limit = request.args.get('limit', 50, type=int)

        params = {
            "min_interviews": min_interviews,
            "min_rating": min_avg_rating,
            "limit": limit
        }

        # Corrected query: removed current_stage, added u.email to GROUP BY
        base_query = """
        SELECT
            c.id AS candidate_id,
            c.full_name AS candidate_name,
            u.email,
            COUNT(fb.id) AS feedback_count,
            ROUND(AVG(fb.overall_rating), 2) AS avg_overall_rating,
            ROUND(AVG(fb.technical_skills), 2) AS avg_technical,
            ROUND(AVG(fb.communication), 2) AS avg_communication,
            ROUND(AVG(fb.culture_fit), 2) AS avg_culture_fit,
            ROUND(AVG(fb.problem_solving), 2) AS avg_problem_solving,
            ROUND(AVG(fb.experience_relevance), 2) AS avg_experience,
            SUM(CASE WHEN fb.recommendation = 'strong_hire' THEN 1 ELSE 0 END) AS strong_hire_count,
            SUM(CASE WHEN fb.recommendation = 'hire' THEN 1 ELSE 0 END) AS hire_count,
            SUM(CASE WHEN fb.recommendation = 'no_hire' THEN 1 ELSE 0 END) AS no_hire_count,
            SUM(CASE WHEN fb.recommendation = 'strong_no_hire' THEN 1 ELSE 0 END) AS strong_no_hire_count,
            SUM(CASE WHEN fb.recommendation = 'not_sure' THEN 1 ELSE 0 END) AS not_sure_count
        FROM candidates c
        JOIN users u ON u.id = c.user_id
        JOIN interviews i ON c.id = i.candidate_id
        JOIN interview_feedback fb ON i.id = fb.interview_id
        WHERE fb.is_submitted = true
        GROUP BY c.id, u.email
        HAVING COUNT(fb.id) >= :min_interviews
            AND AVG(fb.overall_rating) >= :min_rating
        ORDER BY
            (
                SUM(CASE WHEN fb.recommendation = 'strong_hire' THEN 1 ELSE 0 END) * 2 +
                SUM(CASE WHEN fb.recommendation = 'hire' THEN 1 ELSE 0 END) -
                SUM(CASE WHEN fb.recommendation = 'no_hire' THEN 1 ELSE 0 END) -
                SUM(CASE WHEN fb.recommendation = 'strong_no_hire' THEN 1 ELSE 0 END) * 2
            ) DESC,
            AVG(fb.overall_rating) DESC,
            COUNT(fb.id) DESC
        LIMIT :limit
        """

        result = db.session.execute(db.text(base_query), params)

        candidates = []
        for row in result:
            total = (
                row.strong_hire_count +
                row.hire_count +
                row.no_hire_count +
                row.strong_no_hire_count +
                row.not_sure_count
            )

            recommendation_score = (
                (
                    row.strong_hire_count * 2 +
                    row.hire_count -
                    row.no_hire_count -
                    row.strong_no_hire_count * 2
                ) / total
            ) if total else 0

            if recommendation_score >= 1:
                decision = "STRONG HIRE"
            elif recommendation_score >= 0.5:
                decision = "HIRE"
            elif recommendation_score >= 0:
                decision = "CONSIDER"
            elif recommendation_score >= -0.5:
                decision = "REVIEW CAREFULLY"
            else:
                decision = "PROBABLY NOT"

            culture_fit_score = (
                float(row.avg_culture_fit)
                if row.avg_culture_fit is not None
                else None
            )

            candidate = {
                "candidateId": row.candidate_id,
                "candidateName": row.candidate_name,
                "email": row.email,

                # ✅ REQUIRED BY FRONTEND
                "cultureFitScore": culture_fit_score,

                "statistics": {
                    "feedbackCount": row.feedback_count,
                    "averageOverallRating": float(row.avg_overall_rating) if row.avg_overall_rating else None,
                    "averageTechnical": float(row.avg_technical) if row.avg_technical else None,
                    "averageCommunication": float(row.avg_communication) if row.avg_communication else None,
                    "averageCultureFit": culture_fit_score,
                    "averageProblemSolving": float(row.avg_problem_solving) if row.avg_problem_solving else None,
                    "averageExperience": float(row.avg_experience) if row.avg_experience else None
                },

                "decision": decision,
                "recommendationScore": round(recommendation_score, 2),
                "readyForOffer": decision in ["STRONG HIRE", "HIRE"],
                "nextSteps": []
            }

            if row.feedback_count < 3:
                candidate["nextSteps"].append("Collect more interview feedback")
            if culture_fit_score is not None and culture_fit_score < 3:
                candidate["nextSteps"].append("Culture fit risk")

            candidates.append(candidate)

        ready = [c for c in candidates if c["readyForOffer"]]

        return jsonify({
            "success": True,
            "summary": {
                "totalCandidates": len(candidates),
                "readyForOffer": len(ready),
                "needsReview": len(candidates) - len(ready)
            },
            "candidates": candidates,
            "topRecommendations": ready[:10],
            "generatedAt": datetime.utcnow().isoformat()
        }), 200

    except Exception as e:
        current_app.logger.error("Ready-for-offer failed", exc_info=True)
        return jsonify({
            "success": False,
            "error": "Failed to evaluate candidates",
            "details": str(e)
        }), 500

#------------------------------------------------------------------------------------------------------------
@admin_bp.route("/pipeline/stats", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def get_pipeline_stats():
    """
    Get statistics for the recruitment pipeline header
    """
    try:
        # Active jobs (where requisition has status 'active' - you might need to add this field)
        # For now, assuming all requisitions are active
        active_jobs = Requisition.query.count()
        
        # Total applications
        total_applications = Application.query.count()
        
        # Offers sent (status = 'sent' in Offer model)
        offers_sent = Offer.query.filter_by(status=OfferStatus.SENT).count()
        
        # Today's interviews
        today = datetime.utcnow().date()
        today_interviews = Interview.query.filter(
            db.func.date(Interview.scheduled_time) == today,
            Interview.status == 'scheduled'
        ).count()
        
        # Applications by pipeline stage (using Application.status)
        stages = ['screening', 'assessment', 'interview', 'offer', 'hired', 'rejected']
        apps_by_stage = {}
        
        for stage in stages:
            count = Application.query.filter_by(status=stage).count()
            apps_by_stage[stage] = count
        
        # Add pending interviews count
        pending_interviews = Interview.query.filter(
            Interview.status == 'scheduled'
        ).count()
        
        return jsonify({
            "active_jobs": active_jobs,
            "total_candidates": total_applications,
            "offers_sent": offers_sent,
            "today_interviews": today_interviews,
            "pending_interviews": pending_interviews,
            "applications_by_stage": apps_by_stage,
            "total_requisitions": Requisition.query.count(),
            "total_interviews": Interview.query.count(),
            "total_offers": Offer.query.count()
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Pipeline stats error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500
    
@admin_bp.route("/applications/filtered", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def get_filtered_applications():
    """
    Get applications with advanced filtering and search
    """
    try:
        # Get query parameters
        status = request.args.get("status", "all")
        job_id = request.args.get("job_id", type=int)
        search = request.args.get("search", "")
        sort_by = request.args.get("sort_by", "created_at")
        sort_order = request.args.get("sort_order", "desc")
        page = request.args.get("page", 1, type=int)
        per_page = request.args.get("per_page", 20, type=int)
        
        # Base query
        query = Application.query.join(Candidate).join(Requisition)
        
        # Apply filters
        if status and status != 'all':
            query = query.filter(Application.status == status)
        
        if job_id:
            query = query.filter(Application.requisition_id == job_id)
        
        if search:
            search_pattern = f"%{search}%"
            query = query.filter(
                db.or_(
                    Candidate.full_name.ilike(search_pattern),
                    Requisition.title.ilike(search_pattern)
                )
            )
        
        # Apply sorting
        if sort_by == "name":
            sort_field = Candidate.full_name
        elif sort_by == "score":
            sort_field = Application.overall_score
        elif sort_by == "date":
            sort_field = Application.created_at
        elif sort_by == "job":
            sort_field = Requisition.title
        else:
            sort_field = Application.created_at
        
        if sort_order.lower() == "asc":
            query = query.order_by(sort_field.asc())
        else:
            query = query.order_by(sort_field.desc())
        
        # Pagination
        pagination = query.paginate(page=page, per_page=per_page, error_out=False)
        applications = pagination.items
        
        result = []
        for app in applications:
            candidate = app.candidate
            job = app.requisition
            
            # Get next scheduled interview
            next_interview = Interview.query.filter_by(
                application_id=app.id,
                status='scheduled'
            ).order_by(Interview.scheduled_time).first()
            
            # Get assessment result
            assessment = AssessmentResult.query.filter_by(
                application_id=app.id
            ).first()
            
            # Get latest interview feedback
            latest_interview = Interview.query.filter_by(
                application_id=app.id
            ).order_by(Interview.scheduled_time.desc()).first()
            
            feedback_score = None
            if latest_interview:
                feedback = InterviewFeedback.query.filter_by(
                    interview_id=latest_interview.id
                ).first()
                if feedback:
                    feedback_score = feedback.average_rating
            
            result.append({
                "id": app.id,
                "candidate_name": candidate.full_name if candidate else "Unknown",
                "candidate_id": app.candidate_id,
                "candidate_email": candidate.user.email if candidate and candidate.user else None,
                "requisition_title": job.title if job else "Unknown",
                "job_id": app.requisition_id,
                "status": app.status,
                "cv_score": app.cv_score or 0,
                "assessment_score": app.assessment_score or 0,
                "overall_score": app.overall_score or 0,
                "feedback_score": feedback_score,
                "applied_date": app.created_at.isoformat() if app.created_at else None,
                "recommendation": assessment.recommendation if assessment else 'moderate',
                "next_interview": next_interview.scheduled_time.isoformat() if next_interview else None,
                "stage_progress": app.status,
                "last_updated": app.created_at.isoformat() if app.created_at else None,
                "interview_status": app.interview_status,
                "has_resume": bool(app.resume_url)
            })
        
        return jsonify({
            "applications": result,
            "total": pagination.total,
            "pages": pagination.pages,
            "page": page,
            "per_page": per_page
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Filtered applications error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500
    
@admin_bp.route("/jobs/with-stats", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def get_jobs_with_stats():
    """
    Get all jobs with their statistics
    """
    try:
        jobs = Requisition.query.all()
        result = []
        
        for job in jobs:
            # Count applications for this job
            total_apps = Application.query.filter_by(requisition_id=job.id).count()
            
            # Count by status
            status_counts = {}
            statuses = ['screening', 'assessment', 'interview', 'offer', 'hired', 'rejected']
            
            for status in statuses:
                count = Application.query.filter_by(
                    requisition_id=job.id,
                    status=status
                ).count()
                status_counts[status] = count
            
            # Count hired candidates
            hired_count = Application.query.filter_by(
                requisition_id=job.id,
                status='hired'
            ).count()
            
            # Calculate progress percentage
            progress = 0
            if job.vacancy and job.vacancy > 0:
                progress = min(100, (hired_count / job.vacancy) * 100)
            
            # Get recent applications (last 7 days)
            week_ago = datetime.utcnow() - timedelta(days=7)
            recent_apps = Application.query.filter(
                Application.requisition_id == job.id,
                Application.created_at >= week_ago
            ).count()
            
            result.append({
                "id": job.id,
                "title": job.title,
                "category": job.category or "Uncategorized",
                "description": job.description,
                "vacancy": job.vacancy or 0,
                "created_at": job.created_at.isoformat() if job.created_at else None,
                "published_on": job.published_on.isoformat() if job.published_on else None,
                "applications_count": total_apps,
                "recent_applications": recent_apps,
                "status": "active",  # You might want to add a status field to Requisition
                "progress": round(progress, 1),
                "hired_count": hired_count,
                "status_breakdown": status_counts,
                "required_skills": job.required_skills or [],
                "min_experience": job.min_experience or 0,
                "created_by": job.created_by
            })
        
        return jsonify({"jobs": result}), 200
        
    except Exception as e:
        current_app.logger.error(f"Jobs with stats error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500
    
@admin_bp.route("/interviews/dashboard/<string:timeframe>", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def get_interviews_by_timeframe(timeframe):
    """
    Get interviews by timeframe: today, upcoming, past, week, month
    """
    try:
        now = datetime.utcnow()
        
        # Define timeframe filters
        if timeframe == "today":
            start_date = now.date()
            end_date = start_date + timedelta(days=1)
            query_filter = db.and_(
                Interview.scheduled_time >= start_date,
                Interview.scheduled_time < end_date
            )
        elif timeframe == "upcoming":
            start_date = now
            end_date = now + timedelta(days=7)
            query_filter = db.and_(
                Interview.scheduled_time > start_date,
                Interview.scheduled_time <= end_date
            )
        elif timeframe == "past":
            query_filter = Interview.scheduled_time < now
        elif timeframe == "week":
            start_date = now - timedelta(days=7)
            query_filter = Interview.scheduled_time >= start_date
        elif timeframe == "month":
            start_date = now - timedelta(days=30)
            query_filter = Interview.scheduled_time >= start_date
        else:
            return jsonify({"error": "Invalid timeframe"}), 400
        
        # Query interviews
        interviews = Interview.query.filter(query_filter).order_by(
            Interview.scheduled_time
        ).all()
        
        result = []
        for i in interviews:
            candidate = i.candidate
            application = i.application
            job = application.requisition if application else None
            hiring_manager = i.hiring_manager
            
            # Get feedback stats
            feedback_stats = {
                "count": 0,
                "average_rating": 0
            }
            
            feedbacks = InterviewFeedback.query.filter_by(
                interview_id=i.id,
                is_submitted=True
            ).all()
            
            if feedbacks:
                feedback_stats["count"] = len(feedbacks)
                ratings = [fb.overall_rating for fb in feedbacks if fb.overall_rating]
                if ratings:
                    feedback_stats["average_rating"] = sum(ratings) / len(ratings)
            
            result.append({
                "id": i.id,
                "candidate_name": candidate.full_name if candidate else "Unknown",
                "candidate_id": i.candidate_id,
                "candidate_email": candidate.user.email if candidate and candidate.user else None,
                "application_id": i.application_id,
                "job_title": job.title if job else "Unknown",
                "job_id": job.id if job else None,
                "interview_type": i.interview_type,
                "scheduled_time": i.scheduled_time.isoformat() if i.scheduled_time else None,
                "status": i.status,
                "meeting_link": i.meeting_link,
                "interviewer_name": hiring_manager.profile.get("full_name") if hiring_manager and hiring_manager.profile else hiring_manager.email if hiring_manager else None,
                "interviewer_email": hiring_manager.email if hiring_manager else None,
                "interviewer_id": i.hiring_manager_id,
                "google_calendar_event_link": i.google_calendar_event_link,
                "google_calendar_hangout_link": i.google_calendar_hangout_link,
                "feedback_stats": feedback_stats,
                "duration_minutes": 60,  # Default or calculate from start/end if you have end_time
                "created_at": i.created_at.isoformat() if i.created_at else None
            })
        
        return jsonify({
            "timeframe": timeframe,
            "count": len(result),
            "interviews": result
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Interviews by timeframe error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500
    
from sqlalchemy import func

@admin_bp.route("/pipeline/stages/count", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def get_pipeline_stages_count():
    """
    Get count of candidates in each pipeline stage
    """
    try:
        stages = [
            {"id": "screening", "name": "Screening", "icon": "filter_list", "color": "#4285F4"},
            {"id": "assessment", "name": "Assessment", "icon": "assessment", "color": "#FBBC04"},
            {"id": "interview", "name": "Interview", "icon": "video_call", "color": "#34A853"},
            {"id": "offer", "name": "Offer", "icon": "work_outline", "color": "#EA4335"},
            {"id": "hired", "name": "Hired", "icon": "check_circle", "color": "#673AB7"},
        ]

        result = []

        for stage in stages:
            # Base count by application status
            count = (
                db.session.query(func.count(Application.id))
                .filter(Application.status == stage["id"])
                .scalar()
            )

            if stage["id"] == "interview":
                # Count DISTINCT application IDs with scheduled interviews
                interview_apps = (
                    db.session.query(func.count(func.distinct(Application.id)))
                    .join(Interview, Application.id == Interview.application_id)
                    .filter(Interview.status == "scheduled")
                    .scalar()
                )

                # Preserve your original intent
                count = max(count, interview_apps or 0)

            result.append({
                **stage,
                "count": count or 0,
                "percentage": 0
            })

        total = sum(stage["count"] for stage in result)

        if total > 0:
            for stage in result:
                stage["percentage"] = round((stage["count"] / total) * 100, 1)

        return jsonify({
            "stages": result,
            "total": total,
            "updated_at": datetime.utcnow().isoformat()
        }), 200

    except Exception as e:
        current_app.logger.error(
            f"Pipeline stages count error: {e}",
            exc_info=True
        )
        return jsonify({"error": "Internal server error"}), 500

    
@admin_bp.route("/pipeline/quick-stats", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def get_pipeline_quick_stats():
    """
    Get quick statistics for dashboard cards
    """
    try:
        now = datetime.utcnow()
        today = now.date()
        week_ago = now - timedelta(days=7)
        month_ago = now - timedelta(days=30)

        # Core stats
        active_jobs = Requisition.query.count()
        total_applications = Application.query.count()
        offers_sent = Offer.query.filter_by(status=OfferStatus.SENT).count()

        today_interviews = Interview.query.filter(
            db.func.date(Interview.scheduled_time) == today,
            Interview.status == "scheduled"
        ).count()

        # Time to hire (avg days from application creation to now for hired)
        time_to_hire_query = db.session.query(
            db.func.avg(
                db.func.extract(
                    "epoch",
                    db.func.now() - Application.created_at
                ) / 86400
            )
        ).filter(Application.status == "hired").scalar()

        time_to_hire = round(time_to_hire_query or 28, 1)

        # Offer acceptance rate
        total_offers = Offer.query.filter_by(status=OfferStatus.SENT).count()
        accepted_offers = Offer.query.filter_by(status=OfferStatus.SIGNED).count()
        acceptance_rate = (
            round((accepted_offers / total_offers) * 100, 1)
            if total_offers > 0 else 0
        )

        # Recent activity
        recent_applications = Application.query.filter(
            Application.created_at >= week_ago
        ).count()

        recent_interviews = Interview.query.filter(
            Interview.created_at >= week_ago
        ).count()

        # Stage distribution
        stages = ["screening", "assessment", "interview", "offer", "hired"]
        stage_distribution = {
            stage: Application.query.filter_by(status=stage).count()
            for stage in stages
        }

        # Interview completion rate
        total_interviews = Interview.query.count()
        completed_interviews = Interview.query.filter_by(status="completed").count()
        interview_completion_rate = (
            round((completed_interviews / total_interviews) * 100, 1)
            if total_interviews > 0 else 0
        )

        # Hires in last 30 days (using created_at as proxy)
        hires_last_30_days = Application.query.filter(
            Application.status == "hired",
            Application.created_at >= month_ago
        ).count()

        return jsonify({
            "active_jobs": active_jobs,
            "total_candidates": total_applications,
            "offers_sent": offers_sent,
            "today_interviews": today_interviews,
            "pending_reviews": Application.query.filter_by(status="screening").count(),

            "performance_metrics": {
                "time_to_hire_days": time_to_hire,
                "offer_acceptance_rate": acceptance_rate,
                "interview_completion_rate": interview_completion_rate,
                "application_to_interview_rate": 0,
                "interview_to_offer_rate": 0
            },

            "recent_activity": {
                "applications_last_7_days": recent_applications,
                "interviews_last_7_days": recent_interviews,
                "offers_last_7_days": Offer.query.filter(
                    Offer.created_at >= week_ago
                ).count(),
                "hires_last_30_days": hires_last_30_days
            },

            "stage_distribution": stage_distribution,
            "total_interviews": total_interviews,
            "upcoming_interviews": Interview.query.filter(
                Interview.scheduled_time > now,
                Interview.status == "scheduled"
            ).count(),
            "offers_pending_response": Offer.query.filter_by(
                status=OfferStatus.SENT
            ).count(),

            "updated_at": now.isoformat()
        }), 200

    except Exception as e:
        current_app.logger.error(
            f"Quick stats error: {e}",
            exc_info=True
        )
        return jsonify({"error": "Internal server error"}), 500

    
@admin_bp.route("/applications/<int:application_id>/status", methods=["PATCH"])
@role_required(["admin", "hiring_manager", "hr"])
def update_application_status(application_id):
    """
    Update application pipeline status
    """
    try:
        application = Application.query.get_or_404(application_id)
        data = request.get_json()
        new_status = data.get("status")
        
        if not new_status:
            return jsonify({"error": "Status is required"}), 400
        
        # Validate status transition
        valid_statuses = ['screening', 'assessment', 'interview', 'offer', 'hired', 'rejected']
        if new_status not in valid_statuses:
            return jsonify({
                "error": f"Invalid status. Must be one of: {', '.join(valid_statuses)}"
            }), 400
        
        old_status = application.status
        application.status = new_status
        application.updated_at = datetime.utcnow()
        
        # If moving to interview stage, ensure there's an interview scheduled
        if new_status == 'interview' and old_status != 'interview':
            # Check if interview already exists
            existing_interview = Interview.query.filter_by(
                application_id=application_id,
                status='scheduled'
            ).first()
            
            if not existing_interview:
                # Create a placeholder interview or notification
                notification = Notification(
                    user_id=application.candidate.user_id if application.candidate and application.candidate.user_id else None,
                    message=f"Your application for {application.requisition.title if application.requisition else 'the position'} has moved to interview stage.",
                    type="status_update"
                )
                db.session.add(notification)
        
        # If moving to hired stage, update vacancy count
        if new_status == 'hired' and old_status != 'hired':
            job = application.requisition
            if job and job.vacancy and job.vacancy > 0:
                # You might want to decrement vacancy count
                # job.vacancy -= 1
                pass
        
        db.session.commit()
        
        # Audit log
        current_user_id = get_jwt_identity()
        AuditLog(
            admin_id=current_user_id,
            action=f"Updated application status from {old_status} to {new_status}",
            target_user_id=application.candidate.user_id if application.candidate else None,
            details=f"Application {application_id} status updated",
            extra_data={
                "application_id": application_id,
                "old_status": old_status,
                "new_status": new_status,
                "job_title": application.requisition.title if application.requisition else None
            }
        )
        db.session.commit()
        
        return jsonify({
            "message": f"Application status updated to {new_status}",
            "application": {
                "id": application.id,
                "status": application.status,
                "candidate_name": application.candidate.full_name if application.candidate else None,
                "job_title": application.requisition.title if application.requisition else None,
                "updated_at": application.updated_at.isoformat() if application.updated_at else None
            }
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Update application status error: {e}", exc_info=True)
        db.session.rollback()
        return jsonify({"error": "Internal server error"}), 500
    
@admin_bp.route("/search", methods=["GET"])
@role_required(["admin", "hiring_manager", "hr"])
def search_all():
    """
    Global search across candidates, jobs, applications
    """
    try:
        query = request.args.get("q", "").strip()
        if not query or len(query) < 2:
            return jsonify({
                "candidates": [],
                "jobs": [],
                "applications": [],
                "interviews": []
            }), 200
        
        search_pattern = f"%{query}%"
        
        # Search candidates
        candidates = Candidate.query.filter(
            db.or_(
                Candidate.full_name.ilike(search_pattern),
                Candidate.email.ilike(search_pattern) if hasattr(Candidate, 'email') else False,
                Candidate.phone.ilike(search_pattern)
            )
        ).limit(10).all()
        
        # Search jobs
        jobs = Requisition.query.filter(
            db.or_(
                Requisition.title.ilike(search_pattern),
                Requisition.description.ilike(search_pattern),
                Requisition.category.ilike(search_pattern)
            )
        ).limit(10).all()
        
        # Search applications (through candidates and jobs)
        applications = Application.query.join(Candidate).join(Requisition).filter(
            db.or_(
                Candidate.full_name.ilike(search_pattern),
                Requisition.title.ilike(search_pattern)
            )
        ).limit(10).all()
        
        # Search interviews
        interviews = Interview.query.join(Candidate).filter(
            Candidate.full_name.ilike(search_pattern)
        ).limit(10).all()
        
        return jsonify({
            "candidates": [{
                "id": c.id,
                "name": c.full_name,
                "email": c.user.email if c.user else None,
                "type": "candidate",
                "score": c.cv_score
            } for c in candidates],
            
            "jobs": [{
                "id": j.id,
                "title": j.title,
                "category": j.category,
                "type": "job",
                "applications_count": Application.query.filter_by(requisition_id=j.id).count()
            } for j in jobs],
            
            "applications": [{
                "id": a.id,
                "candidate_name": a.candidate.full_name if a.candidate else None,
                "job_title": a.requisition.title if a.requisition else None,
                "status": a.status,
                "type": "application",
                "score": a.overall_score
            } for a in applications],
            
            "interviews": [{
                "id": i.id,
                "candidate_name": i.candidate.full_name if i.candidate else None,
                "scheduled_time": i.scheduled_time.isoformat() if i.scheduled_time else None,
                "type": "interview",
                "status": i.status
            } for i in interviews],
            
            "query": query,
            "total_results": len(candidates) + len(jobs) + len(applications) + len(interviews)
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Search error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500