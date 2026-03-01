from app.extensions import db
from app.models import Requisition, Application, AssessmentResult
from datetime import datetime


def get_questions_for_requisition(requisition):
    """
    Return list of questions for this requisition: from linked TestPack or from assessment_pack JSON.
    Each question: at least question_text, options; correct_option (0-based) or correct_answer (0-3).
    """
    if not requisition:
        return []
    if requisition.test_pack_id and requisition.test_pack and not requisition.test_pack.deleted_at:
        return list(requisition.test_pack.questions or [])
    pack = requisition.assessment_pack or {}
    return list(pack.get("questions") or [])


class AssessmentService:

    @staticmethod
    def recompute_application_scores(application):
        """
        Recompute and assign overall_score + scoring_breakdown from current application fields.
        This is used when cv_score/assessment_score/interview_score change asynchronously.
        """
        weightings = (application.requisition.weightings if application.requisition else None) or {
            "cv": 60,
            "assessment": 40,
            "interview": 0,
            "references": 0
        }
        cv_score = application.cv_score or 0
        assessment_score = application.assessment_score or 0
        interview_score = application.interview_feedback_score or 0
        references_score = 0
        overall_score = (
            (cv_score * weightings.get("cv", 0) / 100) +
            (assessment_score * weightings.get("assessment", 0) / 100) +
            (interview_score * weightings.get("interview", 0) / 100) +
            (references_score * weightings.get("references", 0) / 100)
        )
        application.overall_score = overall_score
        application.scoring_breakdown = {
            "cv": cv_score,
            "assessment": assessment_score,
            "interview": interview_score,
            "references": references_score,
            "weightings": weightings,
            "overall": overall_score
        }
        return overall_score, application.scoring_breakdown

    @staticmethod
    def create_assessment(requisition_id, questions):
        """
        Add or update MCQ assessment for a requisition/job (inline questions only).
        `questions` is a list of dicts:
        {"question_text": str, "options": list[str], "correct_option": int}
        When a job uses a test pack, questions are resolved via get_questions_for_requisition; this is for custom questions.
        """
        requisition = Requisition.query.get(requisition_id)
        if not requisition:
            raise ValueError("Requisition not found")
        
        requisition.assessment_pack = {"questions": questions}
        db.session.commit()
        return requisition.assessment_pack

    @staticmethod
    def submit_candidate_assessment(application_id, candidate_answers):
        """
        candidate_answers: [{"question_index": int, "selected_option": int}]
        Calculates raw score and percentage, then stores in AssessmentResult.
        """
        application = Application.query.get(application_id)
        if not application:
            raise ValueError("Application not found")

        questions = get_questions_for_requisition(application.requisition)
        if not questions:
            raise ValueError("No assessment found for this requisition")

        # prevent duplicate submissions
        existing = AssessmentResult.query.filter_by(application_id=application.id).first()
        if existing:
            raise ValueError("Candidate has already submitted this assessment")

        score = 0
        detailed_scores = []

        for ans in candidate_answers:
            q_index = ans.get("question_index")
            selected = ans.get("selected_option")

            if q_index is None or selected is None:
                raise ValueError("Each answer must include question_index and selected_option")

            if q_index < 0 or q_index >= len(questions):
                raise ValueError(f"Invalid question index: {q_index}")

            q = questions[q_index]
            correct = q.get("correct_option", q.get("correct_answer", 0))
            if correct is None:
                correct = 0
            correct = int(correct)
            is_correct = selected == correct
            if is_correct:
                score += 1

            detailed_scores.append({
                "question_index": q_index,
                "selected_option": selected,
                "correct_option": correct,
                "is_correct": is_correct
            })

        total_questions = len(questions)
        percentage_score = (score / total_questions) * 100 if total_questions > 0 else 0

        # store assessment result
        result = AssessmentResult(
            application_id=application.id,
            candidate_id=application.candidate_id,
            answers=candidate_answers,
            scores=detailed_scores,
            total_score=score,
            percentage_score=percentage_score,
            assessed_at=datetime.utcnow()
        )
        db.session.add(result)

        # also update the application for shortlisting
        application.assessment_score = percentage_score

        AssessmentService.recompute_application_scores(application)
        db.session.commit()

        # return clean dict instead of ORM object
        return {
            "application_id": application.id,
            "total_score": score,
            "percentage": percentage_score,
            "submitted_at": result.assessed_at.isoformat()
        }

    @staticmethod
    def get_candidate_assessment(application_id):
        return AssessmentResult.query.filter_by(application_id=application_id).first()

    @staticmethod
    def shortlist_candidates(requisition_id, cv_weight=60, assessment_weight=40):
        """
        Calculate overall score based on CV and assessment.
        Returns candidates sorted by overall_score descending.
        """
        applications = Application.query.filter_by(requisition_id=requisition_id).all()
        shortlisted = []
        for app in applications:
            weightings = (app.requisition.weightings if app.requisition else None) or {
                "cv": cv_weight,
                "assessment": assessment_weight,
                "interview": 0,
                "references": 0
            }
            cv_score = app.cv_score if app.cv_score is not None else (app.candidate.cv_score or 0)
            overall = (
                (cv_score * weightings.get("cv", 0) / 100) +
                (app.assessment_score * weightings.get("assessment", 0) / 100) +
                (app.interview_feedback_score * weightings.get("interview", 0) / 100)
            )
            app.overall_score = overall
            db.session.commit()
            shortlisted.append(app)
        return sorted(shortlisted, key=lambda x: x.overall_score, reverse=True)
