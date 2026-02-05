from app.extensions import db
from datetime import datetime
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.mutable import MutableDict, MutableList
import enum

# ------------------- USER -------------------
class User(db.Model):
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(150), unique=True, nullable=False)
    password = db.Column(db.String(200), nullable=False)
    role = db.Column(db.String(50), default='candidate')

    profile = db.Column(JSON, default=lambda: {})
    settings = db.Column(JSON, default=lambda: {})

    is_verified = db.Column(db.Boolean, default=False)
    enrollment_completed = db.Column(db.Boolean, default=False)
    dark_mode = db.Column(db.Boolean, default=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    first_login = db.Column(db.Boolean, default=True)

    # MFA Fields
    mfa_secret = db.Column(db.String(32), nullable=True)
    mfa_enabled = db.Column(db.Boolean, default=False)
    mfa_verified = db.Column(db.Boolean, default=False)
    mfa_backup_codes = db.Column(db.JSON, nullable=True)

    # 🔗 Relationships
    candidates = db.relationship('Candidate', back_populates='user', lazy=True)
    notifications = db.relationship('Notification', back_populates='user', lazy=True)
    oauth_connections = db.relationship('OAuthConnection', back_populates='user', lazy=True)
    presence = db.relationship('UserPresence', back_populates='user', uselist=False, lazy=True)

    # ✅ FIXED: Interviews where user is the hiring manager
    managed_interviews = db.relationship(
        'Interview',
        foreign_keys='Interview.hiring_manager_id',
        back_populates='hiring_manager',
        lazy=True
    )

    # ✅ REQUIRED: Interviews cancelled by this user
    cancelled_interviews = db.relationship(
        'Interview',
        foreign_keys='Interview.cancelled_by',
        back_populates='cancelled_by_user',
        lazy=True
    )
    
    job_activity_logs = db.relationship(
        'JobActivityLog',
        back_populates='user_relation',  # must match the name in JobActivityLog
        lazy=True,
        cascade='all, delete-orphan'
    )
    
    @property
    def full_name(self):
        """
        Returns a safe display name for UI and audit logs.
        Priority:
        1. profile['full_name']
        2. profile['first_name'] + profile['last_name']
        3. email
        """
        if self.profile:
            full_name = self.profile.get("full_name")
            if full_name:
                return full_name.strip()

            first = self.profile.get("first_name")
            last = self.profile.get("last_name")
            if first or last:
                return f"{first or ''} {last or ''}".strip()

        return self.email


    def to_dict(self):
        return {
            "id": self.id,
            "email": self.email,
            "role": self.role,
            "profile": self.profile,
            "settings": self.settings,
            "is_verified": self.is_verified,
            "enrollment_completed": self.enrollment_completed,
            "dark_mode": self.dark_mode,
            "is_active": self.is_active,
            "created_at": self.created_at.isoformat(),
            "first_login": self.first_login,
            "mfa_enabled": self.mfa_enabled
        }

    def to_dict_with_presence(self):
        user_dict = self.to_dict()
        user_dict['presence'] = self.get_presence() if hasattr(self, 'get_presence') else {
            'status': 'offline',
            'last_seen': None
        }
        return user_dict
    

class OAuthConnection(db.Model):
    __tablename__ = 'oauth_connections'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    provider = db.Column(db.String(50), nullable=False)
    provider_user_id = db.Column(db.String(255), nullable=False)
    access_token = db.Column(db.String(512), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    user = db.relationship('User', back_populates='oauth_connections')
    
    __table_args__ = (
        db.UniqueConstraint('provider', 'provider_user_id', name='uq_provider_user'),
    )
    
    def to_dict(self):
        return {
            'id': self.id,
            'provider': self.provider,
            'provider_user_id': self.provider_user_id,
            'created_at': self.created_at.isoformat()
        }


# ------------------- JOB ACTIVITY LOG -------------------
class JobActivityLog(db.Model):
    """Audit trail for job/requisition activities"""
    __tablename__ = 'job_activity_logs'
    
    id = db.Column(db.Integer, primary_key=True)
    job_id = db.Column(db.Integer, db.ForeignKey('requisitions.id'), nullable=False, index=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)
    action = db.Column(db.String(50), nullable=False)  # 'CREATE', 'UPDATE', 'DELETE', 'VIEW', 'VIEW_DETAILED', 'RESTORE'
    details = db.Column(JSON, default={})
    ip_address = db.Column(db.String(45))
    user_agent = db.Column(db.Text)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    
    # Relationships
    job = db.relationship('Requisition', backref=db.backref('activity_logs', lazy=True, cascade='all, delete-orphan'))
    user_relation = db.relationship('User', foreign_keys=[user_id], back_populates='job_activity_logs')
    
    def to_dict(self):
        """Serialize for API responses"""
        user_name = None
        if self.user_relation:
            user_name = self.user_relation.full_name
        
        return {
            'id': self.id,
            'job_id': self.job_id,
            'user_id': self.user_id,
            'user_name': user_name,
            'user_email': self.user_relation.email if self.user_relation else None,
            'action': self.action,
            'details': self.details,
            'ip_address': self.ip_address,
            'user_agent': self.user_agent,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None
        }


# ------------------- REQUISITION -------------------
class Requisition(db.Model):
    __tablename__ = 'requisitions'
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(150), nullable=False)
    description = db.Column(db.Text)
    job_summary = db.Column(db.Text, default="")
    responsibilities = db.Column(JSON, default=[])
    company_details = db.Column(db.Text, default="")
    qualifications = db.Column(JSON, default=[])
    category = db.Column(db.String(100), default="")
    required_skills = db.Column(JSON, default=[])
    min_experience = db.Column(db.Float, default=0)
    knockout_rules = db.Column(JSON, default=[])
    weightings = db.Column(JSON, default={'cv': 60, 'assessment': 40})
    assessment_pack = db.Column(JSON, default={"questions": []})
    created_by = db.Column(db.Integer, db.ForeignKey('users.id'))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    published_on = db.Column(db.DateTime, default=datetime.utcnow)
    vacancy = db.Column(db.Integer, default=1)
    
    # NEW FIELDS FOR ENHANCED CRUD
    is_active = db.Column(db.Boolean, default=True, nullable=False)
    deleted_at = db.Column(db.DateTime, nullable=True)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Display fields for job listing (explore category / candidate view)
    location = db.Column(db.String(150), default="", nullable=True)
    employment_type = db.Column(db.String(80), default="Full Time", nullable=True)  # e.g. Full Time, Contract
    salary_range = db.Column(db.String(100), default="", nullable=True)  # e.g. R850k - R1.2m
    application_deadline = db.Column(db.DateTime, nullable=True)
    company = db.Column(db.String(200), default="", nullable=True)
    banner = db.Column(db.String(500), nullable=True)  # company logo / image URL

    applications = db.relationship('Application', back_populates='requisition', lazy=True)

    def to_dict(self):
        return {
            "id": self.id,
            "title": self.title,
            "description": self.description,
            "job_summary": self.job_summary,
            "responsibilities": self.responsibilities,
            "company_details": self.company_details,
            "qualifications": self.qualifications,
            "category": self.category,
            "required_skills": self.required_skills,
            "min_experience": self.min_experience,
            "knockout_rules": self.knockout_rules,
            "weightings": self.weightings,
            "assessment_pack": self.assessment_pack,
            "created_by": self.created_by,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "published_on": self.published_on.isoformat(),
            "vacancy": self.vacancy,
            "is_active": self.is_active,
            "deleted_at": self.deleted_at.isoformat() if self.deleted_at else None,
            "location": self.location or "",
            "employment_type": self.employment_type or "Full Time",
            "salary_range": self.salary_range or "",
            "application_deadline": self.application_deadline.isoformat() if self.application_deadline else None,
            "company": self.company or "",
            "banner": self.banner,
        }
    
    def to_dict_with_stats(self):
        """Return job data with application statistics"""
        from . import Application
        
        base_dict = self.to_dict()
        
        # Get application statistics
        applications = Application.query.filter_by(requisition_id=self.id).all()
        total_applications = len(applications)
        
        # Status breakdown
        status_counts = {}
        for app in applications:
            status_counts[app.status] = status_counts.get(app.status, 0) + 1
        
        base_dict.update({
            "statistics": {
                "total_applications": total_applications,
                "applications_by_status": status_counts,
                "created_at": self.created_at.isoformat() if self.created_at else None,
                "updated_at": self.updated_at.isoformat() if self.updated_at else None,
                "days_active": (datetime.utcnow() - self.created_at).days if self.created_at else 0
            }
        })
        
        return base_dict

# ------------------- CANDIDATE -------------------
class Candidate(db.Model):
    __tablename__ = 'candidates'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    full_name = db.Column(db.String(150))
    phone = db.Column(db.String(50))
    dob = db.Column(db.Date)
    address = db.Column(db.String(250))
    gender = db.Column(db.String(50), nullable=True)
    bio = db.Column(db.Text, nullable=True)
    title = db.Column(db.String(100), nullable=True)
    location = db.Column(db.String(150), nullable=True)
    nationality = db.Column(db.String(100), nullable=True)
    id_number = db.Column(db.String(100), nullable=True)       # ✅ added
    linkedin = db.Column(db.String(250), nullable=True)        # ✅ added
    github = db.Column(db.String(250), nullable=True)          # ✅ added
    cv_url = db.Column(db.String(500))
    cv_text = db.Column(db.Text)
    portfolio = db.Column(db.String(500))
    cover_letter = db.Column(db.Text)
    profile_picture = db.Column(db.String(1024), nullable=True)

    # Structured sections
    education = db.Column(MutableList.as_mutable(JSON), default=list)
    skills = db.Column(MutableList.as_mutable(JSON), default=list)
    work_experience = db.Column(MutableList.as_mutable(JSON), default=list)
    certifications = db.Column(MutableList.as_mutable(JSON), default=list)
    languages = db.Column(MutableList.as_mutable(JSON), default=list)
    documents = db.Column(MutableList.as_mutable(JSON), default=list)
    profile = db.Column(MutableDict.as_mutable(JSON), default=dict)
    overall_interview_score = db.Column(db.Float, default=0.0)

    cv_score = db.Column(db.Integer, default=0)
    dark_mode = db.Column(db.Boolean, default=False)
    notifications_email = db.Column(db.Boolean, default=True)
    notifications_push = db.Column(db.Boolean, default=False)

    # 🔗 Relationships
    user = db.relationship('User', back_populates='candidates')
    applications = db.relationship('Application', back_populates='candidate', lazy=True)
    interviews = db.relationship('Interview', back_populates='candidate', lazy=True)
    assessments = db.relationship('AssessmentResult', back_populates='candidate', lazy=True)
    analyses = db.relationship('CVAnalysis', back_populates='candidate', lazy=True)

    def to_dict(self):
        """Return candidate data for API responses."""
        return {
            "id": self.id,
            "user_id": self.user_id,
            "full_name": self.full_name,
            "phone": self.phone,
            "dob": self.dob.isoformat() if self.dob else None,
            "address": self.address,
            "gender": self.gender,
            "bio": self.bio,
            "title": self.title,
            "location": self.location,
            "nationality": self.nationality,
            "id_number": self.id_number,
            "linkedin": self.linkedin,
            "github": self.github,
            "cv_url": self.cv_url,
            "cv_text": self.cv_text,
            "portfolio": self.portfolio,
            "cover_letter": self.cover_letter,
            "profile_picture": self.profile_picture,
            "education": self.education,
            "skills": self.skills,
            "work_experience": self.work_experience,
            "certifications": self.certifications,
            "languages": self.languages,
            "documents": self.documents,
            "profile": self.profile,
            "cv_score": self.cv_score,
            "dark_mode": self.dark_mode,
            "notifications_email": self.notifications_email,
            "notifications_push": self.notifications_push,
            "overall_interview_score": self.overall_interview_score,  # Add this
        }

# ------------------- APPLICATION -------------------
class Application(db.Model):
    __tablename__ = 'applications'
    id = db.Column(db.Integer, primary_key=True)
    candidate_id = db.Column(db.Integer, db.ForeignKey('candidates.id'))
    requisition_id = db.Column(db.Integer, db.ForeignKey('requisitions.id'))
    status = db.Column(db.String(50), default='applied')  # could be 'draft', 'applied', 'reviewed', etc.
    is_draft = db.Column(db.Boolean, default=False)
    draft_data = db.Column(JSON, nullable=True)  # store partial info before submission
    resume_url = db.Column(db.String(500))
    cv_score = db.Column(db.Float, default=0)
    cv_parser_result = db.Column(JSON, default={})
    assessment_score = db.Column(db.Float, default=0)
    overall_score = db.Column(db.Float, default=0)
    recommendation = db.Column(db.String(50))
    assessed_date = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_saved_screen = db.Column(db.String(50))
    saved_at = db.Column(db.DateTime)
    last_interview_date = db.Column(db.DateTime, nullable=True)
    interview_status = db.Column(db.String(50), default='not_scheduled')  # not_scheduled, scheduled, completed, no_show, cancelled
    interview_feedback_score = db.Column(db.Float, default=0.0)

    candidate = db.relationship('Candidate', back_populates='applications')
    requisition = db.relationship('Requisition', back_populates='applications')
    interviews = db.relationship('Interview', back_populates='application', lazy=True)
    assessment_results = db.relationship('AssessmentResult', back_populates='application', lazy=True)

    def to_dict(self):
        return {
            "id": self.id,
            "candidate_id": self.candidate_id,
            "requisition_id": self.requisition_id,
            "status": self.status,
            "is_draft": self.is_draft,
            "draft_data": self.draft_data,
            "resume_url": self.resume_url,
            "cv_score": self.cv_score,
            "cv_parser_result": self.cv_parser_result,
            "assessment_score": self.assessment_score,
            "overall_score": self.overall_score,
            "recommendation": self.recommendation,
            "assessed_date": self.assessed_date.isoformat() if self.assessed_date else None,
            "created_at": self.created_at.isoformat(),
            "assessment_results": [ar.to_dict() for ar in self.assessment_results],
            "last_saved_screen": self.last_saved_screen,
            "saved_at": self.saved_at.isoformat() if self.saved_at else None,
            "last_interview_date": self.last_interview_date.isoformat() if self.last_interview_date else None,
            "interview_status": self.interview_status,
            "interview_feedback_score": self.interview_feedback_score,
        }


# ------------------- ASSESSMENT RESULT -------------------
class AssessmentResult(db.Model):
    __tablename__ = 'assessment_results'
    id = db.Column(db.Integer, primary_key=True)
    application_id = db.Column(db.Integer, db.ForeignKey('applications.id'), nullable=False)
    candidate_id = db.Column(db.Integer, db.ForeignKey('candidates.id'), nullable=False)
    answers = db.Column(JSON, default={})
    scores = db.Column(JSON, default={})
    total_score = db.Column(db.Float, default=0)
    percentage_score = db.Column(db.Float, default=0)
    recommendation = db.Column(db.String(50))
    assessed_at = db.Column(db.DateTime, default=datetime.utcnow)
    created_at = db.Column(db.DateTime, default=datetime.utcnow) 

    application = db.relationship('Application', back_populates='assessment_results')
    candidate = db.relationship('Candidate', back_populates='assessments')
    
    def to_dict(self):
        return {
            "id": self.id,
            "application_id": self.application_id,
            "candidate_id": self.candidate_id,
            "answers": self.answers,
            "scores": self.scores,
            "total_score": self.total_score,
            "percentage_score": self.percentage_score,
            "recommendation": self.recommendation,
            "assessed_at": self.assessed_at.isoformat() if self.assessed_at else None
        }


# ------------------- INTERVIEW -------------------
class Interview(db.Model):
    __tablename__ = 'interviews'
    id = db.Column(db.Integer, primary_key=True)
    candidate_id = db.Column(db.Integer, db.ForeignKey('candidates.id'), nullable=False)
    hiring_manager_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    application_id = db.Column(db.Integer, db.ForeignKey('applications.id'), nullable=True)
    scheduled_time = db.Column(db.DateTime, nullable=False)
    interview_type = db.Column(db.String(50), nullable=True)
    meeting_link = db.Column(db.String(255), nullable=True)
    status = db.Column(db.String(50), default='scheduled')  # Add this line if not present
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)  # Add this
    
    # Google Calendar Integration Fields
    google_calendar_event_id = db.Column(db.String(255), nullable=True, index=True)
    google_calendar_event_link = db.Column(db.String(500), nullable=True)
    google_calendar_hangout_link = db.Column(db.String(500), nullable=True)
    last_calendar_sync = db.Column(db.DateTime, nullable=True)
    
    # Add these new fields for lifecycle enhancements
    feedback_submitted_at = db.Column(db.DateTime, nullable=True)
    cancelled_reason = db.Column(db.Text, nullable=True)
    cancelled_by = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    no_show_reason = db.Column(db.Text, nullable=True)
    completed_at = db.Column(db.DateTime, nullable=True)
    
    candidate = db.relationship('Candidate', back_populates='interviews')
    application = db.relationship('Application', back_populates='interviews')
    hiring_manager = db.relationship('User', foreign_keys=[hiring_manager_id], back_populates='managed_interviews')

    cancelled_by_user = db.relationship('User', foreign_keys=[cancelled_by], back_populates='cancelled_interviews')


    def to_dict(self):
        result = {
            "id": self.id,
            "candidate_id": self.candidate_id,
            "hiring_manager_id": self.hiring_manager_id,
            "application_id": self.application_id,
            "scheduled_time": self.scheduled_time.isoformat() if self.scheduled_time else None,
            "interview_type": self.interview_type,
            "meeting_link": self.meeting_link,
            "status": self.status,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "google_calendar_event_id": self.google_calendar_event_id,
            "google_calendar_event_link": self.google_calendar_event_link,
            "google_calendar_hangout_link": self.google_calendar_hangout_link,
            "last_calendar_sync": self.last_calendar_sync.isoformat() if self.last_calendar_sync else None,
            
            # New fields
            "feedback_submitted_at": self.feedback_submitted_at.isoformat() if self.feedback_submitted_at else None,
            "cancelled_reason": self.cancelled_reason,
            "cancelled_by": self.cancelled_by,
            "no_show_reason": self.no_show_reason,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
            
            "candidate": {
                "id": self.candidate.id,
                "full_name": self.candidate.full_name if hasattr(self.candidate, "full_name") else self.candidate.user.profile.get("full_name") if self.candidate.user else None,
                "email": self.candidate.user.email if self.candidate.user else None,
                "profile_picture": self.candidate.profile_picture
            } if self.candidate else None,
            "hiring_manager": {
                "id": self.hiring_manager.id,
                "full_name": f"{self.hiring_manager.profile.get('first_name', '')} {self.hiring_manager.profile.get('last_name', '')}".strip() if self.hiring_manager.profile else None,
                "email": self.hiring_manager.email
            } if self.hiring_manager else None,
        }
        return result
    
    def update_calendar_info(self, calendar_data):
        """Update interview with Google Calendar information"""
        if calendar_data:
            self.google_calendar_event_id = calendar_data.get('event_id')
            self.google_calendar_event_link = calendar_data.get('html_link')
            self.google_calendar_hangout_link = calendar_data.get('hangout_link')
            self.last_calendar_sync = datetime.utcnow()
            
            # Update meeting link with Google Meet if not already set
            if not self.meeting_link and calendar_data.get('conference_link'):
                self.meeting_link = calendar_data.get('conference_link')
    
    def enrich_with_feedback_stats(self):
        """Add feedback statistics to interview dict"""
        from app.models import InterviewFeedback
        
        feedback_stats = {
            "feedback_count": 0,
            "average_rating": 0,
            "recommendations": []
        }
        
        feedbacks = InterviewFeedback.query.filter_by(
            interview_id=self.id,
            is_submitted=True
        ).all()
        
        if feedbacks:
            feedback_stats["feedback_count"] = len(feedbacks)
            
            # Calculate average rating
            ratings = [fb.overall_rating for fb in feedbacks if fb.overall_rating]
            if ratings:
                feedback_stats["average_rating"] = sum(ratings) / len(ratings)
            
            # Get recommendations
            feedback_stats["recommendations"] = [fb.recommendation for fb in feedbacks if fb.recommendation]
        
        return feedback_stats

# ------------------- CV ANALYSIS -------------------
class CVAnalysis(db.Model):
    __tablename__ = "cv_analyses"
    id = db.Column(db.Integer, primary_key=True)
    candidate_id = db.Column(db.Integer, db.ForeignKey('candidates.id'), nullable=False)
    job_description = db.Column(db.Text)
    cv_text = db.Column(db.Text)
    result = db.Column(JSON, default={})
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    candidate = db.relationship('Candidate', back_populates='analyses')


# ------------------- NOTIFICATION -------------------
class Notification(db.Model):
    __tablename__ = 'notifications'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)

    # Core content
    message = db.Column(db.String(500), nullable=False)

    # 🆕 Classification
    type = db.Column(db.String(50), nullable=False, default="info")

    # 🆕 Context linking
    interview_id = db.Column(db.Integer, db.ForeignKey('interviews.id'), nullable=True)

    # State
    is_read = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # Relationships
    user = db.relationship('User', back_populates='notifications')
    interview = db.relationship('Interview', backref='notifications')

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "message": self.message,
            "type": self.type,
            "interview_id": self.interview_id,
            "is_read": self.is_read,
            "created_at": self.created_at.isoformat()
        }

# ------------------- VERIFICATION CODE -------------------
class VerificationCode(db.Model):
    __tablename__ = 'verification_codes'
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(150), nullable=False)
    code = db.Column(db.String(10), nullable=False)
    is_used = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    expires_at = db.Column(db.DateTime, nullable=False)

    def is_valid(self):
        return not self.is_used and datetime.utcnow() < self.expires_at

    def to_dict(self):
        return {
            "id": self.id,
            "email": self.email,
            "code": self.code,
            "is_used": self.is_used,
            "created_at": self.created_at.isoformat(),
            "expires_at": self.expires_at.isoformat()
        }
        
class Conversation(db.Model):
    __tablename__ = "conversations"
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    user_message = db.Column(db.Text)
    assistant_message = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', backref=db.backref('conversations', lazy=True))

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "user_message": self.user_message,
            "assistant_message": self.assistant_message,
            "created_at": self.created_at.isoformat()
        }
        
class AuditLog(db.Model):
    __tablename__ = 'audit_logs'

    id = db.Column(db.Integer, primary_key=True)
    admin_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=True)
    action = db.Column(db.String(255), nullable=False)
    target_user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=True)
    details = db.Column(db.Text, nullable=True)
    ip_address = db.Column(db.String(100), nullable=True)
    user_agent = db.Column(db.String(500), nullable=True)
    extra_data = db.Column(JSON, nullable=True)  # <- renamed from metadata
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "admin_id": self.admin_id,
            "action": self.action,
            "target_user_id": self.target_user_id,
            "details": self.details,
            "ip_address": self.ip_address,
            "user_agent": self.user_agent,
            "extra_data": self.extra_data,  # <- updated here too
            "timestamp": self.timestamp.isoformat(),
        }

# ------------------- SHARED NOTE -------------------
class SharedNote(db.Model):
    __tablename__ = "shared_notes"

    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(255), nullable=False)
    content = db.Column(db.Text, nullable=False)
    author_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    tags = db.Column(db.String(255))
    author = db.relationship("User", backref=db.backref("shared_notes", lazy=True))
    is_pinned = db.Column(db.Boolean, default=False)  # <-- add this

    def to_dict(self):
        return {
            "id": self.id,
            "title": self.title,
            "content": self.content,
            "author_id": self.author_id,
            "author": {
                "id": self.author.id,
                "email": self.author.email,
                "profile": self.author.profile
            } if self.author else None,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat()
        }


# ------------------- MEETING -------------------
class Meeting(db.Model):
    __tablename__ = "meetings"

    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text)
    start_time = db.Column(db.DateTime, nullable=False)
    end_time = db.Column(db.DateTime, nullable=False)
    organizer_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    participants = db.Column(JSONB, nullable=False, default=[])  # list of user emails or IDs
    meeting_link = db.Column(db.String(500))
    location = db.Column(db.String(500))
    meeting_type = db.Column(db.String(50), default="general")
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    cancelled = db.Column(db.Boolean, default=False)
    cancelled_at = db.Column(db.DateTime, nullable=True)
    cancelled_by = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=True)

    organizer = db.relationship("User", backref=db.backref("organized_meetings", lazy=True), foreign_keys=[organizer_id])

    def to_dict(self):
        return {
            "id": self.id,
            "title": self.title,
            "description": self.description,
            "start_time": self.start_time.isoformat(),
            "end_time": self.end_time.isoformat(),
            "organizer_id": self.organizer_id,
            "organizer": {
                "id": self.organizer.id,
                "email": self.organizer.email,
                "profile": self.organizer.profile
            } if self.organizer else None,
            "participants": self.participants if isinstance(self.participants, list) else [],
            "meeting_link": self.meeting_link,
            "location": self.location,
            "meeting_type": self.meeting_type,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "cancelled": self.cancelled,
            "cancelled_at": self.cancelled_at.isoformat() if self.cancelled_at else None,
            "cancelled_by": self.cancelled_by
        }

# ------------------- CHAT FEATURE MODELS -------------------

# Association table for chat participants
chat_participants = db.Table(
    'chat_participants',
    db.Column('user_id', db.Integer, db.ForeignKey('users.id'), primary_key=True),
    db.Column('chat_thread_id', db.Integer, db.ForeignKey('chat_threads.id'), primary_key=True),
    db.Column('joined_at', db.DateTime, default=datetime.utcnow),
    db.Column('is_admin', db.Boolean, default=False),
    db.Column('muted_until', db.DateTime, nullable=True),

    # Indexes
    db.Index('idx_chat_user', 'user_id'),
    db.Index('idx_chat_thread', 'chat_thread_id')
)


class ChatThread(db.Model):
    __tablename__ = 'chat_threads'
    
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    entity_type = db.Column(db.String(50), default='general')  # 'general', 'candidate', 'requisition'
    entity_id = db.Column(db.String(100), nullable=True)  # ID of candidate/requisition
    created_by = db.Column(db.Integer, db.ForeignKey('users.id'))
    is_active = db.Column(db.Boolean, default=True)
    is_archived = db.Column(db.Boolean, default=False)
    last_message_at = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    participants = db.relationship('User', secondary=chat_participants, 
                                 backref=db.backref('chat_threads', lazy='dynamic'))
    messages = db.relationship('ChatMessage', backref='thread', lazy='dynamic',
                             cascade='all, delete-orphan', order_by='desc(ChatMessage.created_at)')
    
    def to_dict(self):
        """Return thread data for API responses."""
        return {
            'id': self.id,
            'title': self.title,
            'entity_type': self.entity_type,
            'entity_id': self.entity_id,
            'created_by': self.created_by,
            'participant_count': len(self.participants) if self.participants else 0,
            'last_message_at': self.last_message_at.isoformat() if self.last_message_at else None,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'is_active': self.is_active,
            'is_archived': self.is_archived
        }
    
    def to_dict_detailed(self):
        """Return thread data with participants."""
        thread_dict = self.to_dict()
        
        # Add participants information
        if self.participants:
            thread_dict['participants'] = [{
                'user_id': user.id,
                'name': user.profile.get('full_name') if user.profile else user.email,
                'email': user.email,
                'role': user.role,
                'avatar_url': user.profile.get('profile_picture') if user.profile else None,
            } for user in self.participants]
        else:
            thread_dict['participants'] = []
        
        return thread_dict


class ChatMessage(db.Model):
    __tablename__ = 'chat_messages'
    
    id = db.Column(db.Integer, primary_key=True)
    thread_id = db.Column(db.Integer, db.ForeignKey('chat_threads.id'), nullable=False)
    sender_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    content = db.Column(db.Text, nullable=False)
    message_type = db.Column(db.String(20), default='text')  # 'text', 'file', 'system'
    message_metadata = db.Column(JSON, nullable=True)  # FIXED NAME
    is_edited = db.Column(db.Boolean, default=False)
    is_deleted = db.Column(db.Boolean, default=False)
    parent_message_id = db.Column(db.Integer, db.ForeignKey('chat_messages.id'), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Self-referential for replies
    parent = db.relationship('ChatMessage', remote_side=[id], backref='replies')
    
    def to_dict(self):
        """Return message data for API responses."""
        from . import User
        sender = User.query.get(self.sender_id)
        
        sender_info = None
        if sender:
            sender_info = {
                'user_id': sender.id,
                'name': sender.profile.get('full_name') if sender.profile else sender.email,
                'role': sender.role,
                'avatar_url': sender.profile.get('profile_picture') if sender.profile else None
            }
        
        return {
            'id': self.id,
            'thread_id': self.thread_id,
            'sender': sender_info,
            'content': '[Message deleted]' if self.is_deleted else self.content,
            'message_type': self.message_type,
            'metadata': self.message_metadata or {},  # UPDATED REFERENCE
            'is_edited': self.is_edited,
            'is_deleted': self.is_deleted,
            'parent_message_id': self.parent_message_id,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }



class MessageReadStatus(db.Model):
    __tablename__ = 'message_read_status'
    
    id = db.Column(db.Integer, primary_key=True)
    message_id = db.Column(db.Integer, db.ForeignKey('chat_messages.id'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    read_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Composite unique constraint
    __table_args__ = (
        db.UniqueConstraint('message_id', 'user_id', name='uq_message_user'),
    )
    
    def to_dict(self):
        return {
            'message_id': self.message_id,
            'user_id': self.user_id,
            'read_at': self.read_at.isoformat() if self.read_at else None
        }


class UserPresence(db.Model):
    __tablename__ = 'user_presence'
    
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), primary_key=True)
    status = db.Column(db.String(20), default='offline')  # 'online', 'away', 'offline'
    last_seen = db.Column(db.DateTime, default=datetime.utcnow)
    is_typing = db.Column(db.Boolean, default=False)
    typing_in_thread = db.Column(db.Integer, nullable=True)
    socket_id = db.Column(db.String(100), nullable=True)
    
    # Relationship
    user = db.relationship('User', backref=db.backref('user_presence', uselist=False))

    
    def to_dict(self):
        return {
            'user_id': self.user_id,
            'status': self.status,
            'last_seen': self.last_seen.isoformat() if self.last_seen else None,
            'is_typing': self.is_typing,
            'typing_in_thread': self.typing_in_thread
        }
        
class OfferStatus(enum.Enum):
    DRAFT = "draft"
    REVIEWED = "reviewed"
    APPROVED = "approved"
    SENT = "sent"
    SIGNED = "signed"
    REJECTED = "rejected"
    EXPIRED = "expired"
    WITHDRAWN = "withdrawn"



class Offer(db.Model):
    __tablename__ = "offers"

    id = db.Column(db.Integer, primary_key=True)

    # Core linkage
    application_id = db.Column(
        db.Integer,
        db.ForeignKey("applications.id"),
        nullable=False,
        index=True
    )

    # Actors
    drafted_by = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    hiring_manager_id = db.Column(db.Integer, db.ForeignKey("users.id"))
    hr_id = db.Column(db.Integer, db.ForeignKey("users.id"))
    approved_by = db.Column(db.Integer, db.ForeignKey("users.id"))
    signed_by = db.Column(db.Integer, db.ForeignKey("users.id"))

    # Compensation
    base_salary = db.Column(db.Numeric(12, 2), nullable=True)
    allowances = db.Column(JSONB, default=dict, nullable=False)
    bonuses = db.Column(JSONB, default=dict, nullable=False)

    # Contract details
    contract_type = db.Column(db.String(50))
    start_date = db.Column(db.Date)
    work_location = db.Column(db.String(255))

    # Offer lifecycle
    status = db.Column(
        db.Enum(OfferStatus, name="offer_status"),
        default=OfferStatus.DRAFT,
        nullable=False,
        index=True
    )

    # Document management
    pdf_url = db.Column(db.String(500))
    pdf_public_id = db.Column(db.String(255))
    pdf_generated_at = db.Column(db.DateTime)

    # Candidate acceptance metadata
    signed_at = db.Column(db.DateTime)
    candidate_ip = db.Column(db.String(45))
    candidate_user_agent = db.Column(db.String(255))

    # Notes & versioning
    notes = db.Column(db.Text)
    offer_version = db.Column(db.Integer, default=1, nullable=False)

    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    updated_at = db.Column(
        db.DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False
    )

    # Relationships
    application = db.relationship("Application", backref=db.backref("offers", lazy="dynamic"))

    drafted_by_user = db.relationship("User", foreign_keys=[drafted_by])
    hiring_manager = db.relationship("User", foreign_keys=[hiring_manager_id])
    hr_user = db.relationship("User", foreign_keys=[hr_id])
    approved_by_user = db.relationship("User", foreign_keys=[approved_by])
    signed_by_user = db.relationship("User", foreign_keys=[signed_by])

    __table_args__ = (
        db.UniqueConstraint("application_id", name="uq_offer_application"),
    )

    # ---------------- Serialization ----------------
    def to_dict(self, include_users=False):
        data = {
            "id": self.id,
            "application_id": self.application_id,
            "base_salary": str(self.base_salary) if self.base_salary else None,
            "allowances": self.allowances,
            "bonuses": self.bonuses,
            "contract_type": self.contract_type,
            "start_date": self.start_date.isoformat() if self.start_date else None,
            "work_location": self.work_location,
            "status": self.status.value,
            "pdf_url": self.pdf_url,
            "notes": self.notes,
            "offer_version": self.offer_version,
            "signed_at": self.signed_at.isoformat() if self.signed_at else None,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
        }

        if include_users:
            data.update({
                "drafted_by": self.drafted_by_user.to_dict() if self.drafted_by_user else None,
                "hiring_manager": self.hiring_manager.to_dict() if self.hiring_manager else None,
                "hr_user": self.hr_user.to_dict() if self.hr_user else None,
                "approved_by": self.approved_by_user.to_dict() if self.approved_by_user else None,
                "signed_by": self.signed_by_user.to_dict() if self.signed_by_user else None,
            })

        return data
    
# Add these after your existing models

# =====================================================
# 📝 INTERVIEW ENHANCEMENT MODELS
# =====================================================

class InterviewNote(db.Model):
    """Interview notes and status change history"""
    __tablename__ = 'interview_notes'
    
    id = db.Column(db.Integer, primary_key=True)
    interview_id = db.Column(db.Integer, db.ForeignKey('interviews.id'), nullable=False)
    notes = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    interview = db.relationship('Interview', backref=db.backref('interview_notes', lazy=True, cascade='all, delete-orphan'))

    def to_dict(self):
        return {
            "id": self.id,
            "interview_id": self.interview_id,
            "notes": self.notes,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None
        }


class InterviewFeedback(db.Model):
    """Structured interview feedback"""
    __tablename__ = 'interview_feedback'
    
    id = db.Column(db.Integer, primary_key=True)
    interview_id = db.Column(db.Integer, db.ForeignKey('interviews.id'), nullable=False)
    interviewer_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    interviewer_name = db.Column(db.String(200))
    interviewer_email = db.Column(db.String(200))
    
    # Ratings (1-5 scale)
    overall_rating = db.Column(db.Integer, nullable=False)  # 1-5
    technical_skills = db.Column(db.Integer)  # 1-5
    communication = db.Column(db.Integer)  # 1-5
    culture_fit = db.Column(db.Integer)  # 1-5
    problem_solving = db.Column(db.Integer)  # 1-5
    experience_relevance = db.Column(db.Integer)  # 1-5
    average_rating = db.Column(db.Float)  # Calculated average
    
    # Recommendation
    recommendation = db.Column(db.String(50), nullable=False)  # strong_hire, hire, no_hire, strong_no_hire, not_sure
    
    # Text feedback
    strengths = db.Column(db.Text)
    weaknesses = db.Column(db.Text)
    additional_notes = db.Column(db.Text)
    private_notes = db.Column(db.Text)  # Only visible to hiring team
    
    # Status
    is_submitted = db.Column(db.Boolean, default=False)
    submitted_at = db.Column(db.DateTime)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    interview = db.relationship('Interview', backref=db.backref('feedbacks', lazy=True, cascade='all, delete-orphan'))
    interviewer = db.relationship('User', backref=db.backref('interview_feedbacks', lazy=True))
    
    __table_args__ = (
        db.UniqueConstraint('interview_id', 'interviewer_id', name='unique_interviewer_feedback'),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "interview_id": self.interview_id,
            "interviewer_id": self.interviewer_id,
            "interviewer_name": self.interviewer_name,
            "interviewer_email": self.interviewer_email,
            "overall_rating": self.overall_rating,
            "technical_skills": self.technical_skills,
            "communication": self.communication,
            "culture_fit": self.culture_fit,
            "problem_solving": self.problem_solving,
            "experience_relevance": self.experience_relevance,
            "average_rating": self.average_rating,
            "recommendation": self.recommendation,
            "strengths": self.strengths,
            "weaknesses": self.weaknesses,
            "additional_notes": self.additional_notes,
            "private_notes": self.private_notes,  # Only include in admin responses
            "is_submitted": self.is_submitted,
            "submitted_at": self.submitted_at.isoformat() if self.submitted_at else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None
        }


class InterviewReminder(db.Model):
    """Scheduled interview reminders"""
    __tablename__ = 'interview_reminders'
    
    id = db.Column(db.Integer, primary_key=True)
    interview_id = db.Column(db.Integer, db.ForeignKey('interviews.id'), nullable=False)
    reminder_type = db.Column(db.String(50), nullable=False)  # 24_hours_before, 1_hour_before, custom
    scheduled_time = db.Column(db.DateTime, nullable=False)
    sent_at = db.Column(db.DateTime)
    status = db.Column(db.String(20), default='pending')  # pending, sent, failed, cancelled
    error_message = db.Column(db.Text)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    interview = db.relationship('Interview', backref=db.backref('reminders', lazy=True, cascade='all, delete-orphan'))
    
    __table_args__ = (
        db.UniqueConstraint('interview_id', 'reminder_type', name='unique_reminder_type'),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "interview_id": self.interview_id,
            "reminder_type": self.reminder_type,
            "scheduled_time": self.scheduled_time.isoformat() if self.scheduled_time else None,
            "sent_at": self.sent_at.isoformat() if self.sent_at else None,
            "status": self.status,
            "error_message": self.error_message,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None
        }