# FastAPI CV Analysis Service Integration Plan

## Executive Summary

This document outlines the complete migration plan to replace the current Celery-based CV analysis system with a new external FastAPI analysis service. The migration involves:

1. **Database schema changes** - Adding `external_analysis_id` column to `cv_analyses` table
2. **Backend endpoint modifications** - Updating resume upload to communicate with external service
3. **Background polling implementation** - Creating mechanism to fetch analysis results
4. **Data transformation logic** - Merging external results into local database
5. **Frontend compatibility** - Ensuring Flutter UI continues to work seamlessly

## Current Architecture Overview

### Existing Flow
```
Flutter Frontend → Flask Upload Resume → Cloudinary Storage → CVAnalysis Record → Celery Task → AI Analysis → Database Update → HM UI
```

### Key Components
- **Upload Endpoint**: `/api/candidate/upload_resume/<application_id>` (candidate_routes.py)
- **Celery Task**: `analyze_cv_task` (cv_tasks.py) 
- **HM Reviews Endpoint**: `/api/admin/notification-preferences` PUT (admin_routes.py)
- **Database Tables**: `applications`, `candidates`, `cv_analyses`

## Target Architecture

### New Flow
```
Flutter Frontend → Flask Upload Resume → Cloudinary Storage → CVAnalysis Record → FastAPI Service → Background Polling → Data Merge → Database Update → HM UI
```

### Key Changes
- Replace Celery task with synchronous HTTP call to FastAPI service
- Store external analysis ID for polling
- Implement background polling mechanism (Celery beat or dedicated worker)
- Add data transformation logic to merge results

## Implementation Plan

### Phase 1: Database Schema Changes

#### 1.1 Add External Analysis ID Column
**File**: `server/migrations/versions/` (new migration file)
```python
def upgrade():
    op.add_column('cv_analyses', sa.Column('external_analysis_id', sa.String(length=255), nullable=True))
    op.create_index('ix_cv_analyses_external_analysis_id', 'cv_analyses', ['external_analysis_id'])
    op.create_index('ix_cv_analyses_status', 'cv_analyses', ['status'])

def downgrade():
    op.drop_index('ix_cv_analyses_status', table_name='cv_analyses')
    op.drop_index('ix_cv_analyses_external_analysis_id', table_name='cv_analyses')
    op.drop_column('cv_analyses', 'external_analysis_id')
```

#### 1.2 Update CVAnalysis Model
**File**: `server/app/models.py`
```python
class CVAnalysis(db.Model):
    # ... existing columns ...
    external_analysis_id = db.Column(db.String(255), nullable=True, index=True)
    # ... existing columns ...
```

### Phase 2: Configuration Updates

#### 2.1 Add External Service Configuration
**File**: `server/app/config.py`
```python
class Config:
    # ... existing config ...
    ANALYSIS_SERVICE_URL = os.environ.get('ANALYSIS_SERVICE_URL', 'http://localhost:8000')
    ANALYSIS_SERVICE_API_KEY = os.environ.get('ANALYSIS_SERVICE_API_KEY', '')
```

#### 2.2 Environment Variables
Add to `.env` or `render.env`:
```
ANALYSIS_SERVICE_URL=https://your-fastapi-service.com
ANALYSIS_SERVICE_API_KEY=your-secret-api-key
```

### Phase 3: Backend Endpoint Modifications

#### 3.1 Update Resume Upload Endpoint
**File**: `server/app/routes/candidate_routes.py`

**Current Logic**:
- Extract text from CV
- Upload to Cloudinary
- Create CVAnalysis record
- Queue Celery task

**New Logic**:
- Extract text from CV
- Upload to Cloudinary
- Create CVAnalysis record with status 'pending'
- Send CV and job description to FastAPI service
- Store external analysis ID
- Handle service failures gracefully

```python
@candidate_bp.route("/upload_resume/<int:application_id>", methods=["POST", "OPTIONS"])
@role_required(["candidate"])
def upload_resume(application_id):
    # ... existing validation and file processing ...
    
    # Create CVAnalysis record
    cv_analysis = CVAnalysis(
        candidate_id=candidate.id,
        application_id=application.id,
        requisition_id=job.id,
        job_description=JobService.build_job_spec_for_cv(job),
        cv_text=resume_text or "",
        result={"extraction_metadata": ocr_result.get("metadata", {})},
        status="pending"
    )
    db.session.add(cv_analysis)
    db.session.commit()
    
    # Send to external analysis service
    try:
        external_result = send_to_analysis_service(cv_analysis.id, resume_url, job_spec)
        cv_analysis.external_analysis_id = external_result.get('analysis_id')
        cv_analysis.status = 'submitted'
        db.session.commit()
    except Exception as e:
        cv_analysis.status = 'failed'
        cv_analysis.result = {"error": str(e)}
        db.session.commit()
        return jsonify({"error": "Failed to submit CV for analysis"}), 500
    
    return jsonify({
        "message": "Resume uploaded and submitted for analysis",
        "cv_analysis_id": cv_analysis.id
    }), 200
```

#### 3.2 Add External Service Communication
**File**: `server/app/services/analysis_service_client.py`

```python
import requests
from flask import current_app
from app.models import CVAnalysis, db

class AnalysisServiceClient:
    @staticmethod
    def submit_cv(cv_analysis_id: int, cv_url: str, job_description: str):
        """Submit CV to external analysis service"""
        url = f"{current_app.config['ANALYSIS_SERVICE_URL']}/upload"
        headers = {
            'Authorization': f"Bearer {current_app.config['ANALYSIS_SERVICE_API_KEY']}",
            'Content-Type': 'application/json'
        }
        
        payload = {
            'cv_url': cv_url,
            'job_description': job_description,
            'callback_url': None  # We'll use polling instead
        }
        
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        response.raise_for_status()
        return response.json()
    
    @staticmethod
    def get_analysis_status(external_analysis_id: str):
        """Get analysis status from external service"""
        url = f"{current_app.config['ANALYSIS_SERVICE_URL']}/analyses/{external_analysis_id}/status"
        headers = {
            'Authorization': f"Bearer {current_app.config['ANALYSIS_SERVICE_API_KEY']}"
        }
        
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        return response.json()
    
    @staticmethod
    def get_analysis_result(external_analysis_id: str):
        """Get analysis result from external service"""
        url = f"{current_app.config['ANALYSIS_SERVICE_URL']}/analyses/{external_analysis_id}/result"
        headers = {
            'Authorization': f"Bearer {current_app.config['ANALYSIS_SERVICE_API_KEY']}"
        }
        
        response = requests.get(url, headers=headers, timeout=30)
        response.raise_for_status()
        return response.json()
```

### Phase 4: Background Polling Implementation

#### 4.1 Create Polling Task
**File**: `server/app/tasks/polling_tasks.py`

```python
from celery import Celery
from app import create_app, db
from app.models import CVAnalysis
from app.services.analysis_service_client import AnalysisServiceClient
from app.services.data_merger import DataMerger
import logging

logger = logging.getLogger(__name__)

@celery.task(bind=True, max_retries=3, default_retry_delay=60)
def poll_cv_analysis_results(self):
    """Poll for pending CV analysis results"""
    app = create_app()
    with app.app_context():
        # Get pending analyses with external IDs
        pending_analyses = CVAnalysis.query.filter(
            CVAnalysis.status.in_(['submitted', 'processing']),
            CVAnalysis.external_analysis_id.isnot(None)
        ).limit(50).all()
        
        for cv_analysis in pending_analyses:
            try:
                # Check status
                status_result = AnalysisServiceClient.get_analysis_status(cv_analysis.external_analysis_id)
                external_status = status_result.get('status')
                
                if external_status == 'completed':
                    # Fetch full result
                    result = AnalysisServiceClient.get_analysis_result(cv_analysis.external_analysis_id)
                    DataMerger.update_local_database(cv_analysis.id, result)
                    logger.info(f"Updated CV analysis {cv_analysis.id} with external result")
                    
                elif external_status == 'failed':
                    cv_analysis.status = 'failed'
                    cv_analysis.result = {"error": status_result.get('error', 'External analysis failed')}
                    cv_analysis.finished_at = datetime.utcnow()
                    db.session.commit()
                    logger.warning(f"External analysis failed for CV analysis {cv_analysis.id}")
                    
                elif external_status in ['submitted', 'processing']:
                    cv_analysis.status = external_status
                    db.session.commit()
                    
            except Exception as exc:
                logger.error(f"Error polling CV analysis {cv_analysis.id}: {str(exc)}")
                # Continue with next analysis
                
        return f"Polled {len(pending_analyses)} analyses"
```

#### 4.2 Configure Periodic Polling
**File**: `server/celery_worker.py` (or create celery beat config)

```python
from celery.schedules import crontab
from app.tasks.polling_tasks import poll_cv_analysis_results

# Configure Celery Beat to poll every 2 minutes
CELERYBEAT_SCHEDULE = {
    'poll-cv-analysis-results': {
        'task': 'app.tasks.polling_tasks.poll_cv_analysis_results',
        'schedule': crontab(minute='*/2'),  # Every 2 minutes
    },
}
```

### Phase 5: Data Merging Logic

#### 5.1 Create Data Merger Service
**File**: `server/app/services/data_merger.py`

```python
from app import db
from app.models import CVAnalysis, Application, Candidate
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

class DataMerger:
    @staticmethod
    def update_local_database(cv_analysis_id: int, external_result: dict):
        """Merge external analysis result into local database"""
        cv_analysis = CVAnalysis.query.get(cv_analysis_id)
        if not cv_analysis:
            logger.error(f"CV Analysis {cv_analysis_id} not found")
            return
        
        application = Application.query.get(cv_analysis.application_id)
        candidate = Candidate.query.get(cv_analysis.candidate_id)
        
        try:
            # Update Application with scores and recommendation
            if application:
                application.cv_score = external_result.get('match_score', 0)
                application.recommendation = external_result.get('recommendation', '')
                application.cv_parser_result = external_result
                db.session.add(application)
            
            # Update Candidate profile with merged data
            if candidate:
                DataMerger._merge_candidate_profile(candidate, external_result)
                db.session.add(candidate)
            
            # Update CVAnalysis record
            cv_analysis.result = external_result
            cv_analysis.status = 'completed'
            cv_analysis.finished_at = datetime.utcnow()
            db.session.add(cv_analysis)
            
            db.session.commit()
            logger.info(f"Successfully merged external result for CV analysis {cv_analysis_id}")
            
        except Exception as e:
            db.session.rollback()
            logger.error(f"Failed to merge external result for CV analysis {cv_analysis_id}: {str(e)}")
            raise
    
    @staticmethod
    def _merge_candidate_profile(candidate: Candidate, external_result: dict):
        """Intelligently merge external analysis data into candidate profile"""
        parsed_cv = external_result.get('parsed_cv', {})
        
        # Merge skills (avoid duplicates)
        external_skills = parsed_cv.get('skills', [])
        if external_skills and candidate.skills:
            existing_skills = set(skill.strip().lower() for skill in candidate.skills.split(','))
            new_skills = [skill for skill in external_skills 
                         if skill.strip().lower() not in existing_skills]
            if new_skills:
                candidate.skills = candidate.skills + ', ' + ', '.join(new_skills)
        elif external_skills:
            candidate.skills = ', '.join(external_skills)
        
        # Merge education (append if different)
        external_education = parsed_cv.get('education', [])
        if external_education:
            # Simple append strategy - could be made more sophisticated
            existing_education = candidate.education or ''
            for edu in external_education:
                edu_str = f"{edu.get('degree', '')} at {edu.get('institution', '')}"
                if edu_str not in existing_education:
                    candidate.education = existing_education + '\n' + edu_str if existing_education else edu_str
        
        # Merge experience (append if different)
        external_experience = parsed_cv.get('experience', [])
        if external_experience:
            existing_experience = candidate.experience or ''
            for exp in external_experience:
                exp_str = f"{exp.get('position', '')} at {exp.get('company', '')}"
                if exp_str not in existing_experience:
                    candidate.experience = existing_experience + '\n' + exp_str if existing_experience else exp_str
        
        # Merge certifications
        external_certifications = parsed_cv.get('certifications', [])
        if external_certifications:
            existing_certs = candidate.certifications or ''
            for cert in external_certifications:
                if cert not in existing_certs:
                    candidate.certifications = existing_certs + '\n' + cert if existing_certs else cert
        
        # Merge languages
        external_languages = parsed_cv.get('languages', [])
        if external_languages:
            existing_langs = candidate.languages or ''
            for lang in external_languages:
                if lang not in existing_langs:
                    candidate.languages = existing_langs + '\n' + lang if existing_langs else lang
```

### Phase 6: Remove Legacy Celery CV Analysis

#### 6.1 Remove CV Analysis Task
**File**: `server/app/tasks/cv_tasks.py`
- Remove `analyze_cv_task` function
- Remove related imports and dependencies

#### 6.2 Update Upload Route
**File**: `server/app/routes/candidate_routes.py`
- Remove `analyze_cv_task.delay()` call
- Remove import of `analyze_cv_task`

### Phase 7: Testing Strategy

#### 7.1 Unit Tests
**File**: `server/tests/test_analysis_service_integration.py`

```python
import pytest
from unittest.mock import Mock, patch
from app.services.analysis_service_client import AnalysisServiceClient
from app.services.data_merger import DataMerger
from app.models import CVAnalysis, Application, Candidate

class TestAnalysisServiceClient:
    @patch('requests.post')
    def test_submit_cv_success(self, mock_post):
        mock_post.return_value.json.return_value = {'analysis_id': 'ext-123'}
        mock_post.return_value.raise_for_status.return_value = None
        
        result = AnalysisServiceClient.submit_cv(1, 'cv_url', 'job_desc')
        assert result['analysis_id'] == 'ext-123'
    
    @patch('requests.get')
    def test_get_analysis_status(self, mock_get):
        mock_get.return_value.json.return_value = {'status': 'completed'}
        mock_get.return_value.raise_for_status.return_value = None
        
        result = AnalysisServiceClient.get_analysis_status('ext-123')
        assert result['status'] == 'completed'

class TestDataMerger:
    def test_update_local_database(self):
        # Test database update logic with mock data
        pass
    
    def test_merge_candidate_profile(self):
        # Test candidate profile merging logic
        pass
```

#### 7.2 Integration Tests
**File**: `server/tests/test_cv_analysis_integration.py`

```python
def test_end_to_end_cv_analysis(client, auth_headers):
    # Test complete flow: upload -> submit -> poll -> update
    pass

def test_external_service_failure_handling(client, auth_headers):
    # Test graceful handling when external service fails
    pass
```

#### 7.3 End-to-End Tests
- Test Flutter frontend can still view CV analysis results
- Test polling mechanism works correctly
- Test error handling and recovery scenarios

### Phase 8: Deployment & Monitoring

#### 8.1 Deployment Steps
1. Run database migration
2. Deploy backend code changes
3. Update environment variables
4. Restart Celery workers with beat scheduler
5. Monitor initial polling cycles

#### 8.2 Monitoring Requirements
- Log external service API calls and responses
- Monitor polling task execution and failures
- Track analysis completion times
- Alert on high failure rates

#### 8.3 Rollback Plan
- Keep `analyze_cv_task` code commented out for initial deployment
- Database migration is backward compatible
- Can switch back to Celery by updating upload route

## API Contract with FastAPI Service

### Submit CV for Analysis
```
POST /upload
Authorization: Bearer <api_key>
Content-Type: application/json

{
  "cv_url": "https://cloudinary.com/...",
  "job_description": "Job requirements text...",
  "callback_url": null
}

Response:
{
  "analysis_id": "ext-123",
  "status": "submitted",
  "estimated_completion": "2024-01-01T12:00:00Z"
}
```

### Get Analysis Status
```
GET /analyses/{analysis_id}/status
Authorization: Bearer <api_key>

Response:
{
  "analysis_id": "ext-123",
  "status": "completed|processing|failed",
  "progress": 100,
  "error": null
}
```

### Get Analysis Result
```
GET /analyses/{analysis_id}/result
Authorization: Bearer <api_key>

Response:
{
  "analysis_id": "ext-123",
  "status": "completed",
  "match_score": 85,
  "recommendation": "Strong candidate...",
  "parsed_cv": {
    "skills": ["Python", "SQL"],
    "experience": [...],
    "education": [...],
    "certifications": [...],
    "languages": [...]
  },
  "analysis_details": {
    "strengths": [...],
    "weaknesses": [...],
    "suggestions": [...]
  }
}
```

## Frontend Compatibility

### Flutter UI Changes Required
**None** - The existing Flutter code will continue to work as the `/api/admin/notification-preferences` endpoint will maintain the same response format.

### Data Transformation
The existing admin route will transform external analysis results to match the expected format:

```python
# In admin_routes.py - list_cv_reviews function
if cv_analysis:
    result = cv_analysis.result or {}
    cv_analysis_data = {
        "id": cv_analysis.id,
        "status": cv_analysis.status,
        "match_score": result.get("match_score"),
        "recommendation": result.get("recommendation"),
        "strengths": result.get("analysis_details", {}).get("strengths", []),
        "weaknesses": result.get("analysis_details", {}).get("weaknesses", []),
        "suggestions": result.get("analysis_details", {}).get("suggestions", []),
        "parsed_cv": result.get("parsed_cv", {}),
        "created_at": cv_analysis.created_at.isoformat() if cv_analysis.created_at else None,
        "finished_at": cv_analysis.finished_at.isoformat() if cv_analysis.finished_at else None,
    }
```

## Risk Assessment & Mitigation

### High Risk Items
1. **External Service Availability**: Mitigate with retry logic and fallback to local analysis
2. **Data Format Mismatches**: Implement robust data transformation and validation
3. **Polling Performance**: Optimize query and limit batch size

### Medium Risk Items
1. **Migration Complexity**: Use phased approach with thorough testing
2. **Performance Impact**: Monitor external service response times

### Low Risk Items
1. **Frontend Compatibility**: No changes required
2. **Database Migration**: Simple column addition with backward compatibility

## Timeline Estimate

- **Phase 1-2** (Database + Config): 1 day
- **Phase 3-4** (Backend + Polling): 2-3 days  
- **Phase 5** (Data Merging): 1-2 days
- **Phase 6** (Cleanup): 0.5 day
- **Phase 7** (Testing): 2-3 days
- **Phase 8** (Deployment): 1 day

**Total Estimated Time**: 7-10 days

## Success Criteria

1. ✅ CV upload successfully submits to external service
2. ✅ Background polling retrieves analysis results
3. ✅ Local database updated with external results
4. ✅ Candidate profiles enriched with merged data
5. ✅ HM UI displays analysis results correctly
6. ✅ Error handling works gracefully
7. ✅ Performance meets requirements (< 2 min total analysis time)

## Next Steps

1. Review and approve this implementation plan
2. Set up FastAPI service endpoint and API keys
3. Begin Phase 1 implementation
4. Conduct thorough testing at each phase
5. Deploy with monitoring and rollback plan ready

---

*This plan ensures minimal disruption to existing functionality while enabling the new FastAPI analysis service integration.*
