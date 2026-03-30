# app/services/enhanced_cv_parser.py
"""
Enhanced CV Parser with quality feedback and confidence scoring
Optimized for Render deployment with lightweight dependencies
"""

import os
import logging
from typing import Dict, Any, Optional
from app.services.ai_cv_parser import AIParser
from app.services.lightweight_perfect_ocr import LightweightPerfectOCR

logger = logging.getLogger(__name__)

class EnhancedCVParser:
    """Enhanced CV parser with quality assessment and feedback"""
    
    def __init__(self):
        self.ocr_service = LightweightPerfectOCR()
        
    def parse_cv_with_quality_feedback(self, cv_file, job_id: int = 0) -> Dict[str, Any]:
        """
        Parse CV with comprehensive quality feedback
        Returns structured data with quality metrics
        """
        try:
            # Step 1: Extract text with quality assessment
            filename = getattr(cv_file, "filename", "cv").strip()
            _, ext = os.path.splitext(filename)
            ext = (ext or "").lower().lstrip(".")
            
            # Save temporarily for processing
            import tempfile
            with tempfile.NamedTemporaryFile(delete=False, suffix=f".{ext}" if ext else "") as tmp:
                temp_path = tmp.name
            
            try:
                cv_file.save(temp_path)
                
                # Extract with quality metrics
                ocr_result = self.ocr_service.extract_text_with_metadata(temp_path, ext)
                cv_text = ocr_result.get("text", "")
                extraction_method = ocr_result.get("extraction_method", "unknown")
                confidence = ocr_result.get("confidence", 0.0)
                quality_metrics = ocr_result.get("quality_metrics", {})
                
                if not cv_text.strip():
                    logger.warning("CV text empty after extraction")
                    return self._create_error_result("No text could be extracted from CV")
                
                # Step 2: AI Analysis with fallback
                ai_data = self._run_ai_analysis(cv_text, cv_file, job_id)
                
                # Step 3: Merge quality metrics with AI results
                enhanced_result = self._merge_results_with_quality(
                    ai_data, cv_text, extraction_method, confidence, quality_metrics
                )
                
                return enhanced_result
                
            finally:
                # Cleanup
                try:
                    os.unlink(temp_path)
                except Exception:
                    pass
                    
        except Exception as e:
            logger.exception(f"Enhanced CV parsing failed: {e}")
            return self._create_error_result(f"CV parsing failed: {str(e)}")
    
    def _run_ai_analysis(self, cv_text: str, cv_file, job_id: int) -> Dict[str, Any]:
        """Run AI analysis with fallback mechanisms"""
        try:
            # Try local AI parser first
            ai_data = AIParser.extract_cv_data(cv_file, job_id)
            if ai_data and ai_data.get("full_name"):
                return ai_data
        except Exception as e:
            logger.warning(f"Local AI parser failed: {e}")
        
        # Fallback to pattern matching
        try:
            from app.services.cv_pattern_matcher import CVPatternMatcher
            matcher = CVPatternMatcher()
            pattern_data = matcher.extract_all(cv_text)
            
            # Ensure all expected keys exist
            fallback_data = {
                "full_name": pattern_data.get("full_name", ""),
                "email": pattern_data.get("email", ""),
                "phone": pattern_data.get("phone", ""),
                "address": pattern_data.get("address", ""),
                "dob": pattern_data.get("dob", ""),
                "linkedin": pattern_data.get("linkedin", ""),
                "github": pattern_data.get("github", ""),
                "portfolio": pattern_data.get("portfolio", ""),
                "education": pattern_data.get("education", []),
                "skills": pattern_data.get("skills", []),
                "certifications": pattern_data.get("certifications", []),
                "languages": pattern_data.get("languages", []),
                "experience": pattern_data.get("experience", ""),
                "position": pattern_data.get("position", ""),
                "previous_companies": pattern_data.get("previous_companies", []),
                "bio": pattern_data.get("bio", ""),
                "cv_text": cv_text,
            }
            return fallback_data
        except Exception as e:
            logger.warning(f"Pattern matching failed: {e}")
            
        # Final fallback
        return {
            "full_name": "", "email": "", "phone": "", "address": "", "dob": "",
            "linkedin": "", "github": "", "portfolio": "", "education": [],
            "skills": [], "certifications": [], "languages": [], "experience": "",
            "position": "", "previous_companies": [], "bio": "", "cv_text": cv_text,
        }
    
    def _merge_results_with_quality(self, ai_data: Dict, cv_text: str, 
                                 extraction_method: str, confidence: float, 
                                 quality_metrics: Dict) -> Dict[str, Any]:
        """Merge AI results with quality metrics"""
        
        # Calculate field-specific confidence scores
        field_confidence = self._calculate_field_confidence(ai_data, quality_metrics)
        
        # Add quality metadata
        enhanced_result = {
            **ai_data,
            "extraction_metadata": {
                "extraction_method": extraction_method,
                "overall_confidence": confidence,
                "quality_metrics": quality_metrics,
                "field_confidence": field_confidence,
                "text_length": len(cv_text),
                "processing_quality": self._assess_processing_quality(quality_metrics, ai_data)
            }
        }
        
        # Add user-friendly quality indicators
        enhanced_result["quality_indicators"] = self._generate_quality_indicators(
            confidence, field_confidence, ai_data
        )
        
        return enhanced_result
    
    def _calculate_field_confidence(self, ai_data: Dict, quality_metrics: Dict) -> Dict[str, float]:
        """Calculate confidence scores for individual fields"""
        field_confidence = {}
        
        # Base confidence from overall quality
        base_confidence = quality_metrics.get('confidence', 0.5)
        
        # Personal information confidence
        if ai_data.get("full_name"):
            field_confidence["full_name"] = min(base_confidence + 0.2, 1.0)
        else:
            field_confidence["full_name"] = 0.0
            
        if ai_data.get("email"):
            field_confidence["email"] = min(base_confidence + 0.15, 1.0)
        else:
            field_confidence["email"] = 0.0
            
        if ai_data.get("phone"):
            field_confidence["phone"] = min(base_confidence + 0.15, 1.0)
        else:
            field_confidence["phone"] = 0.0
        
        # Structured data confidence
        if ai_data.get("education") and len(ai_data["education"]) > 0:
            field_confidence["education"] = min(base_confidence + 0.1, 1.0)
        else:
            field_confidence["education"] = 0.0
            
        if ai_data.get("skills") and len(ai_data["skills"]) > 0:
            field_confidence["skills"] = min(base_confidence + 0.1, 1.0)
        else:
            field_confidence["skills"] = 0.0
            
        if ai_data.get("experience") and len(ai_data["experience"]) > 50:
            field_confidence["experience"] = min(base_confidence + 0.1, 1.0)
        else:
            field_confidence["experience"] = 0.0
        
        return field_confidence
    
    def _assess_processing_quality(self, quality_metrics: Dict, ai_data: Dict) -> str:
        """Assess overall processing quality"""
        confidence = quality_metrics.get('confidence', 0.0)
        text_length = quality_metrics.get('text_length', 0)
        pattern_score = quality_metrics.get('pattern_score', 0.0)
        
        # Count successfully extracted fields
        extracted_fields = sum(1 for field in ["full_name", "email", "phone", "education", "skills"] 
                             if ai_data.get(field))
        
        if confidence > 0.8 and text_length > 500 and extracted_fields >= 4:
            return "excellent"
        elif confidence > 0.6 and text_length > 200 and extracted_fields >= 3:
            return "good"
        elif confidence > 0.4 and text_length > 100 and extracted_fields >= 2:
            return "fair"
        else:
            return "poor"
    
    def _generate_quality_indicators(self, overall_confidence: float, 
                                   field_confidence: Dict, ai_data: Dict) -> Dict:
        """Generate user-friendly quality indicators"""
        
        processing_quality = self._assess_processing_quality(
            {"confidence": overall_confidence}, ai_data
        )
        
        indicators = {
            "overall_quality": processing_quality,
            "confidence_percentage": round(overall_confidence * 100, 1),
            "fields_extracted": len([k for k, v in ai_data.items() if v]),
            "high_confidence_fields": len([k for k, v in field_confidence.items() if v > 0.7]),
            "warnings": [],
            "recommendations": []
        }
        
        # Add warnings for low confidence fields
        for field, confidence in field_confidence.items():
            if confidence < 0.3 and ai_data.get(field):
                indicators["warnings"].append(f"Low confidence in {field.replace('_', ' ')}")
        
        # Add recommendations
        if overall_confidence < 0.5:
            indicators["recommendations"].append("Please review all extracted fields carefully")
        
        if not ai_data.get("full_name"):
            indicators["recommendations"].append("Name could not be extracted - please enter manually")
            
        if not ai_data.get("email") and not ai_data.get("phone"):
            indicators["recommendations"].append("Contact information missing - please add manually")
        
        return indicators
    
    def _create_error_result(self, error_message: str) -> Dict[str, Any]:
        """Create error result with proper structure"""
        return {
            "error": error_message,
            "full_name": "", "email": "", "phone": "", "address": "", "dob": "",
            "linkedin": "", "github": "", "portfolio": "", "education": [],
            "skills": [], "certifications": [], "languages": [], "experience": "",
            "position": "", "previous_companies": [], "bio": "", "cv_text": "",
            "extraction_metadata": {
                "extraction_method": "error",
                "overall_confidence": 0.0,
                "processing_quality": "failed"
            },
            "quality_indicators": {
                "overall_quality": "failed",
                "confidence_percentage": 0.0,
                "fields_extracted": 0,
                "high_confidence_fields": 0,
                "warnings": [error_message],
                "recommendations": ["Please try uploading a different file format"]
            }
        }
