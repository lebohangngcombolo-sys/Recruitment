from celery_worker import celery
from app import create_app
from app.services.ai_cv_parser import analyzer  # singleton instance
from app.extensions import db

try:
    from app.services.cv_extraction_orchestrator import CVExtractionOrchestrator
except ImportError:
    CVExtractionOrchestrator = None
from app.models import CVAnalysis, Application, Notification, User, Requisition
from app.services.job_service import JobService
from app.services.cv_analysis_utils import apply_cv_score_baseline
from app.services.assessment_service import AssessmentService
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

_flask_app = None


def _get_flask_app():
    global _flask_app
    if _flask_app is None:
        _flask_app = create_app()
    return _flask_app


@celery.task(bind=True, max_retries=2, default_retry_delay=30)
def analyze_cv_task(self, cv_analysis_id: int, application_id: int):
    app = _get_flask_app()
    with app.app_context():
        try:
            cv = CVAnalysis.query.get(cv_analysis_id)
            appn = Application.query.get(application_id)
            if not cv or not appn:
                logger.warning(
                    "Missing CVAnalysis or Application for ids %s %s",
                    cv_analysis_id,
                    application_id,
                )
                return {"status": "missing"}

            # Mark started
            cv.status = "processing"
            cv.started_at = datetime.utcnow()
            db.session.add(cv)
            db.session.commit()
            resume_text = cv.cv_text or ""
            requisition = Requisition.query.get(appn.requisition_id)
            job_spec = JobService.build_job_spec_for_cv(requisition) if requisition else ""

            # Try Gemini (AIService) first, then OpenRouter (HybridResumeAnalyzer), then offline
            result = None
            try:
                from app.services.ai_service import AIService
                ai = AIService()
                result = ai.analyze_cv_vs_job(cv_text=resume_text, job_description=job_spec)
                if result and result.get("match_score") is not None:
                    pass  # use result
                else:
                    result = None
            except Exception as e:
                logger.warning("AIService CV analysis failed, falling back to HybridResumeAnalyzer: %s", e)
                result = None

            if result is None:
                result = analyzer.analyse(resume_text, appn.requisition_id)

            # Apply baseline floor to score
            raw_score = int(result.get("match_score", 0) or 0)
            match_score = apply_cv_score_baseline(raw_score)
            result["match_score"] = match_score
            if result.get("raw_score") is None:
                result["raw_score"] = raw_score

            # Build structured extraction output for prepopulation/review UI (optional)
            orch_out = None
            if CVExtractionOrchestrator is not None:
                try:
                    extraction_metadata = {}
                    if isinstance(cv.result, dict):
                        extraction_metadata = cv.result.get("extraction_metadata") or {}
                    orch = CVExtractionOrchestrator()
                    orch_out = orch.extract(resume_text, extraction_metadata=extraction_metadata)
                except Exception:
                    logger.exception("Failed to build structured extraction output")
                    orch_out = None

            # Persist results (match_score already has baseline applied above)
            appn.cv_score = match_score
            AssessmentService.recompute_application_scores(appn)
            appn.cv_parser_result = result
            appn.recommendation = result.get("recommendation", "")
            db.session.add(appn)

            final_cv_result = result
            if isinstance(cv.result, dict) and cv.result.get("extraction_metadata"):
                # keep any existing metadata captured at upload time
                final_cv_result = {**cv.result, **result}

            if orch_out is not None:
                # Store orchestrator output alongside analyzer output
                final_cv_result["structured_data"] = orch_out.structured_data
                final_cv_result["confidence_scores"] = orch_out.confidence_scores
                final_cv_result["warnings"] = orch_out.warnings
                final_cv_result["suggestions"] = orch_out.suggestions

                # Map extracted data to Candidate so information is stored in the right places
                try:
                    from app.services.cv_to_candidate_mapper import map_extraction_to_candidate, extraction_user_fields
                    from app.models import User

                    structured = orch_out.structured_data
                    work_structured = None
                    raw_exp = (structured.get("experience") or "") if isinstance(structured.get("experience"), str) else ""
                    if raw_exp and len(raw_exp.strip()) > 20:
                        try:
                            from app.services.ai_service import AIService
                            ai = AIService()
                            work_structured = ai.structure_cv_experience(
                                raw_exp,
                                position_hint=structured.get("position") or "",
                                companies_hint=structured.get("previous_companies") if isinstance(structured.get("previous_companies"), list) else None,
                            )
                        except Exception:
                            work_structured = None

                    candidate_updates = map_extraction_to_candidate(structured, work_experience_structured=work_structured)
                    cand = appn.candidate
                    if cand and candidate_updates:
                        for key, value in candidate_updates.items():
                            if hasattr(cand, key):
                                if key == "dob" and isinstance(value, str):
                                    from app.services.enrollment_service import EnrollmentService
                                    parsed_dob = EnrollmentService._parse_dob(value)
                                    if parsed_dob:
                                        setattr(cand, key, parsed_dob)
                                else:
                                    setattr(cand, key, value)
                        db.session.add(cand)

                        user_fields = extraction_user_fields(structured)
                        if user_fields.get("full_name") and cand.user_id:
                            user = User.query.get(cand.user_id)
                            if user and user.profile is not None:
                                profile = dict(user.profile)
                                profile["full_name"] = user_fields["full_name"]
                                parts = user_fields["full_name"].split(None, 1)
                                profile["first_name"] = parts[0] if parts else ""
                                profile["last_name"] = parts[1] if len(parts) > 1 else ""
                                user.profile = profile
                                db.session.add(user)
                except Exception as e:
                    logger.warning("Failed to map CV extraction to candidate: %s", e, exc_info=True)

            cv.result = final_cv_result
            cv.status = "completed"
            cv.finished_at = datetime.utcnow()
            db.session.add(cv)
            db.session.commit()

            # Notify admins
            try:
                admins = User.query.filter_by(role="admin").all()
                for admin in admins:
                    notif = Notification(
                        user_id=admin.id,
                        message=f"CV analysis ready for application {application_id}",
                    )
                    db.session.add(notif)
                db.session.commit()
            except Exception:
                logger.exception("Failed to notify admins after CV analysis")

            return {"status": "ok", "match_score": match_score}
        except Exception as exc:
            logger.exception("CV analysis failed: %s", exc)
            try:
                cv = CVAnalysis.query.get(cv_analysis_id)
                if cv:
                    cv.result = {"error": str(exc)}
                    cv.status = "failed"
                    cv.finished_at = datetime.utcnow()
                    db.session.add(cv)
                    db.session.commit()
            except Exception:
                logger.exception("Failed to mark CVAnalysis failed")
            raise self.retry(exc=exc)

