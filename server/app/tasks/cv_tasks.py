from celery_worker import celery
from app import create_app
from app.services.ai_cv_parser import analyzer  # singleton instance
from app.extensions import db

try:
    from app.services.cv_extraction_orchestrator import CVExtractionOrchestrator
except ImportError:
    CVExtractionOrchestrator = None
from app.models import CVAnalysis, Application, Notification, User
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
            # Run analysis using singleton analyzer
            resume_text = cv.cv_text or ""
            result = analyzer.analyse(resume_text, appn.requisition_id)

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

            # Normalize and persist results
            match_score = int(result.get("match_score", 0) or 0)
            if match_score < 0:
                match_score = 0
            if match_score > 100:
                match_score = 100

            appn.cv_score = match_score
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

