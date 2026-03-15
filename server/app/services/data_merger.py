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
                application.cv_score = match_analysis.get('overall_score', 0)
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
        match_analysis = external_result.get('match_analysis', {})
        evidence = match_analysis.get('evidence', {})
        
        # Merge skills with confidence threshold
        external_skills = evidence.get('skills', [])
        if external_skills:
            existing_skills = set(skill.strip().lower() for skill in (candidate.skills or '').split(',')) if candidate.skills else set()
            new_skills = []
            for item in external_skills:
                if isinstance(item, dict):
                    skill = item.get('skill')
                    confidence = item.get('confidence', 1.0)
                else:
                    skill = item
                    confidence = 1.0
                
                if skill and confidence > 0.9 and skill.lower() not in existing_skills:
                    new_skills.append(skill)
                    existing_skills.add(skill.lower())
            
            if new_skills:
                candidate.skills = ((candidate.skills or '') + ', ' + ', '.join(new_skills)).strip(', ')
        
        # Merge education
        external_education = evidence.get('education', [])
        if external_education:
            existing_education = candidate.education or ''
            for edu in external_education:
                if isinstance(edu, dict) and edu.get('confidence', 1.0) > 0.9:
                    edu_str = f"{edu.get('degree', '')} at {edu.get('institution', '')}"
                    if edu_str and edu_str not in existing_education:
                        candidate.education = existing_education + '\n' + edu_str if existing_education else edu_str
        
        # Merge experience
        external_experience = evidence.get('experience', [])
        if external_experience:
            existing_experience = candidate.experience or ''
            for exp in external_experience:
                if isinstance(exp, dict) and exp.get('confidence', 1.0) > 0.9:
                    exp_str = f"{exp.get('position', '')} at {exp.get('company', '')}"
                    if exp_str and exp_str not in existing_experience:
                        candidate.experience = existing_experience + '\n' + exp_str if existing_experience else exp_str
        
        # Merge certifications
        external_certifications = evidence.get('certifications', [])
        if external_certifications:
            existing_certs = candidate.certifications or ''
            for cert in external_certifications:
                if isinstance(cert, dict) and cert.get('confidence', 1.0) > 0.9:
                    cert_name = cert.get('name') or cert.get('certification', '')
                    if cert_name and cert_name not in existing_certs:
                        candidate.certifications = existing_certs + '\n' + cert_name if existing_certs else cert_name
        
        # Merge languages
        external_languages = evidence.get('languages', [])
        if external_languages:
            existing_langs = candidate.languages or ''
            for lang in external_languages:
                if isinstance(lang, dict) and lang.get('confidence', 1.0) > 0.9:
                    lang_name = lang.get('language') or lang.get('name', '')
                    if lang_name and lang_name not in existing_langs:
                        candidate.languages = existing_langs + '\n' + lang_name if existing_langs else lang_name
