from app import db
from app.models import CVAnalysis, Application, Candidate
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

class DataMerger:
    """Service for merging external analysis results into local database."""
    
    @staticmethod
    def update_local_database(cv_analysis_id: int, external_result: dict):
        """Merge external analysis result into local database."""
        cv_analysis = CVAnalysis.query.get(cv_analysis_id)
        if not cv_analysis:
            logger.error(f"CV Analysis {cv_analysis_id} not found")
            return
        
        application = Application.query.get(cv_analysis.application_id)
        candidate = Candidate.query.get(cv_analysis.candidate_id)
        
        try:
            # Update Application with scores and recommendation
            if application:
                match_analysis = external_result.get('match_analysis', {})
                # NEW: overall_score might be at root or inside match_analysis
                overall_score = external_result.get('overall_score')
                if overall_score is None:
                    overall_score = match_analysis.get('overall_score', 0)
                
                application.cv_score = overall_score
                application.cv_parser_result = external_result
                application.recommendation = match_analysis.get('suggestions', [''])[0] if match_analysis.get('suggestions') else ''
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
        """Intelligently merge external analysis data into candidate profile."""
        # NEW: Canonical schema uses 'structured_data' directly
        structured = external_result.get('structured_data', {})
        
        # LEGACY: Old service used 'match_analysis.evidence'
        match_analysis = external_result.get('match_analysis', {})
        evidence = match_analysis.get('evidence', {})

        def _as_list(value):
            if value is None:
                return []
            if isinstance(value, list):
                return value
            return [value]

        def _norm_skill(item):
            if item is None:
                return None, 0.0
            if isinstance(item, dict):
                return (item.get('skill') or item.get('name') or item.get('value')), float(item.get('confidence', 1.0) or 1.0)
            return str(item), 1.0

        def _merge_unique_list(existing, new_items, *, key_fn=lambda x: str(x).strip().lower()):
            existing_list = list(existing) if isinstance(existing, list) else []
            seen = {key_fn(x) for x in existing_list if x is not None and str(x).strip()}
            for x in new_items:
                if x is None:
                    continue
                k = key_fn(x)
                if not k:
                    continue
                if k not in seen:
                    existing_list.append(x)
                    seen.add(k)
            return existing_list

        # --- Personal Details ---
        personal = structured.get('personal_details', {})
        if personal:
            if personal.get('full_name') and not candidate.full_name:
                candidate.full_name = personal['full_name']
            if personal.get('phone') and not candidate.phone:
                candidate.phone = personal['phone']
            if personal.get('linkedin') and not candidate.linkedin:
                candidate.linkedin = personal['linkedin']
            if personal.get('portfolio') and not candidate.portfolio:
                candidate.portfolio = personal['portfolio']
        
        # --- Skills ---
        external_skills = structured.get('skills') or evidence.get('skills', [])
        if external_skills:
            existing = candidate.skills if isinstance(candidate.skills, list) else []
            new_skills = []
            for item in _as_list(external_skills):
                skill, confidence = _norm_skill(item)
                if skill and confidence > 0.8: # Lowered threshold slightly for AI parser
                    new_skills.append(str(skill).strip())
            if new_skills:
                candidate.skills = _merge_unique_list(existing, new_skills)
        
        # --- Education ---
        external_education = structured.get('education') or evidence.get('education', [])
        if external_education:
            existing = candidate.education if isinstance(candidate.education, list) else []
            new_items = []
            for edu in _as_list(external_education):
                if isinstance(edu, dict):
                    if float(edu.get('confidence', 1.0) or 1.0) < 0.9:
                        continue
                    degree = (edu.get('degree') or '').strip()
                    institution = (edu.get('institution') or '').strip()
                    if degree or institution:
                        new_items.append({
                            "degree": degree or None, 
                            "institution": institution or None,
                            "start_date": edu.get('start_date'),
                            "end_date": edu.get('end_date')
                        })
                else:
                    s = str(edu).strip()
                    if s:
                        new_items.append({"value": s})
            if new_items:
                candidate.education = _merge_unique_list(
                    existing,
                    new_items,
                    key_fn=lambda x: (
                        f"{(x.get('degree') or x.get('value') or '').strip().lower()}|{(x.get('institution') or '').strip().lower()}"
                        if isinstance(x, dict)
                        else str(x).strip().lower()
                    ),
                )
        
        # --- Experience ---
        external_experience = structured.get('work_experience') or evidence.get('experience', [])
        if external_experience:
            existing = candidate.work_experience if isinstance(candidate.work_experience, list) else []
            new_items = []
            for exp in _as_list(external_experience):
                if isinstance(exp, dict):
                    if float(exp.get('confidence', 1.0) or 1.0) <= 0.8:
                        continue
                    position = (exp.get('position') or exp.get('title') or '').strip()
                    company = (exp.get('company') or '').strip()
                    if position or company:
                        new_items.append({
                            "title": position or None, 
                            "company": company or None,
                            "start_date": exp.get('start_date'),
                            "end_date": exp.get('end_date'),
                            "description": exp.get('description')
                        })
                else:
                    s = str(exp).strip()
                    if s:
                        new_items.append({"value": s})
            if new_items:
                candidate.work_experience = _merge_unique_list(
                    existing,
                    new_items,
                    key_fn=lambda x: (
                        f"{(x.get('title') or x.get('value') or '').strip().lower()}|{(x.get('company') or '').strip().lower()}"
                        if isinstance(x, dict)
                        else str(x).strip().lower()
                    ),
                )
        
        # Merge certifications
        external_certifications = evidence.get('certifications', [])
        if external_certifications:
            existing = candidate.certifications if isinstance(candidate.certifications, list) else []
            new_items = []
            for cert in _as_list(external_certifications):
                if isinstance(cert, dict):
                    if float(cert.get('confidence', 1.0) or 0.0) <= 0.9:
                        continue
                    name = (cert.get('name') or cert.get('certification') or '').strip()
                    if name:
                        new_items.append(name)
                else:
                    s = str(cert).strip()
                    if s:
                        new_items.append(s)
            if new_items:
                candidate.certifications = _merge_unique_list(existing, new_items)
        
        # Merge languages
        external_languages = evidence.get('languages', [])
        if external_languages:
            existing = candidate.languages if isinstance(candidate.languages, list) else []
            new_items = []
            for lang in _as_list(external_languages):
                if isinstance(lang, dict):
                    if float(lang.get('confidence', 1.0) or 0.0) <= 0.9:
                        continue
                    name = (lang.get('language') or lang.get('name') or '').strip()
                    if name:
                        new_items.append(name)
                else:
                    s = str(lang).strip()
                    if s:
                        new_items.append(s)
            if new_items:
                candidate.languages = _merge_unique_list(existing, new_items)
