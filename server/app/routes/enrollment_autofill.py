# app/routes/enrollment_autofill.py
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from werkzeug.utils import secure_filename
import os

from app.services.enrollment_service import EnrollmentService
from app.services.analysis_service_client import AnalysisServiceClient

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
        
        filename = secure_filename(cv_file.filename)
        cv_file.stream.seek(0)
        file_content = cv_file.read()
        if not file_content:
            return {"error": "Uploaded CV file is empty"}, 400

        job_description = request.form.get(
            "job_description",
            "General candidate profile analysis for enrollment autofill",
        )

        # Submit original file to HF (single source of extraction) then poll for result
        submit = AnalysisServiceClient.submit_cv_file(
            file_content,
            filename,
            job_description=job_description,
        )
        external_analysis_id = (submit or {}).get("analysis_id")
        if not external_analysis_id:
            return {"error": "Failed to submit CV to analysis service"}, 502

        result_payload = AnalysisServiceClient.wait_for_result(
            external_analysis_id,
            timeout_seconds=300,
            poll_interval_seconds=5,
        )
        if not result_payload:
            return {"error": "CV analysis did not complete"}, 502

        # Map to form fields
        form_fields = EnrollmentService.map_cv_analysis_to_form_fields(result_payload)

        return {
            "success": True,
            "source": "huggingface",
            "analysis_id": external_analysis_id,
            "cv_analysis": result_payload,
            "form_fields": form_fields,
            "message": "CV analyzed successfully with HuggingFace AI",
        }, 200
                
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
