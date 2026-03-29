# app/routes/enrollment_autofill.py
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from werkzeug.utils import secure_filename
import os
import tempfile

from app.services.enrollment_service import EnrollmentService

enrollment_autofill_bp = Blueprint('enrollment_autofill', __name__)

@enrollment_autofill_bp.route('/api/enrollment/analyze-cv', methods=['POST'])
@jwt_required()
def analyze_cv_for_autofill():
    """
    Analyze CV file and return structured data for form autofill
    """
    try:
        user_id = get_jwt_identity()
        
        # Check if CV file is uploaded
        if 'cv_file' not in request.files:
            return {"error": "No CV file uploaded"}, 400
            
        cv_file = request.files['cv_file']
        if cv_file.filename == '':
            return {"error": "No file selected"}, 400
            
        # Validate file type
        allowed_extensions = {'pdf', 'doc', 'docx', 'txt'}
        if not ('.' in cv_file.filename and 
                cv_file.filename.rsplit('.', 1)[1].lower() in allowed_extensions):
            return {"error": "Invalid file type. Allowed: PDF, DOC, DOCX, TXT"}, 400
        
        # Save file temporarily
        filename = secure_filename(cv_file.filename)
        temp_path = os.path.join(tempfile.gettempdir(), f"cv_{user_id}_{filename}")
        cv_file.save(temp_path)
        
        try:
            # Extract CV text
            from app.services.ai_cv_parser import AIParser
            cv_text = AIParser.read_cv_file(temp_path)
            
            if not cv_text or not cv_text.strip():
                return {"error": "Could not extract text from CV"}, 400
            
            # Analyze with HuggingFace
            cv_analysis_data = EnrollmentService.analyze_cv_with_hf(cv_text)
            
            if cv_analysis_data:
                # Map to form fields
                form_fields = EnrollmentService.map_cv_analysis_to_form_fields(cv_analysis_data)
                
                return {
                    "success": True,
                    "source": "huggingface",
                    "cv_analysis": cv_analysis_data,
                    "form_fields": form_fields,
                    "message": "CV analyzed successfully with HuggingFace AI"
                }, 200
            else:
                # Fallback to local parser
                ai_data = AIParser.extract_cv_data(temp_path) or {}
                
                # Map local results to form fields
                form_fields = {}
                if ai_data:
                    form_fields = {
                        "full_name": ai_data.get("full_name", ""),
                        "phone": ai_data.get("phone", ""),
                        "address": ai_data.get("address", ""),
                        "email": ai_data.get("email", ""),
                        "linkedin": ai_data.get("linkedin", ""),
                        "github": ai_data.get("github", ""),
                        "education": ai_data.get("education", ""),
                        "skills": ", ".join(ai_data.get("skills", [])) if ai_data.get("skills") else "",
                        "experience": ai_data.get("experience", ""),
                        "position": ai_data.get("position", ""),
                        "previous_companies": ", ".join(ai_data.get("previous_companies", [])) if ai_data.get("previous_companies") else "",
                        "certifications": ", ".join(ai_data.get("certifications", [])) if ai_data.get("certifications") else "",
                        "languages": ", ".join(ai_data.get("languages", [])) if ai_data.get("languages") else ""
                    }
                
                return {
                    "success": True,
                    "source": "local_parser",
                    "cv_analysis": ai_data,
                    "form_fields": form_fields,
                    "message": "CV analyzed with local parser (HuggingFace unavailable)"
                }, 200
                
        finally:
            # Clean up temporary file
            if os.path.exists(temp_path):
                os.remove(temp_path)
                
    except Exception as e:
        return {"error": f"CV analysis failed: {str(e)}"}, 500

@enrollment_autofill_bp.route('/api/enrollment/cv-analysis-status', methods=['GET'])
@jwt_required()
def get_cv_analysis_status():
    """
    Check if HuggingFace CV analyser service is available
    """
    try:
        import requests
        
        # Test health endpoint
        response = requests.get("https://dzunisani007-cv-analyser.hf.space/health", timeout=10)
        
        if response.status_code == 200:
            health_data = response.json()
            return {
                "available": True,
                "health": health_data,
                "message": "HuggingFace CV analyser is available"
            }, 200
        else:
            return {
                "available": False,
                "error": f"Service returned {response.status_code}",
                "message": "HuggingFace CV analyser is not available"
            }, 200
            
    except Exception as e:
        return {
            "available": False,
            "error": str(e),
            "message": "HuggingFace CV analyser is not available"
        }, 200
