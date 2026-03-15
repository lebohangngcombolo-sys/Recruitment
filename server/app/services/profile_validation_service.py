"""
Profile Validation Service
Implements comprehensive profile validation and optimization
Based on the detailed profile system analysis
"""

import re
import json
import logging
from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime

logger = logging.getLogger(__name__)


class ProfileValidator:
    """Comprehensive profile data validation with security considerations"""
    
    @staticmethod
    def validate_profile_data(data: Dict[str, Any]) -> Dict[str, str]:
        """
        Validate profile data with comprehensive checks
        Returns dictionary of field errors
        """
        errors = {}
        
        # Name validation
        if 'full_name' in data:
            name = data['full_name'].strip()
            if len(name) < 2:
                errors['full_name'] = 'Name must be at least 2 characters'
            elif len(name) > 100:
                errors['full_name'] = 'Name must be less than 100 characters'
            elif not re.match(r'^[a-zA-Z\s\-\'\.]+$', name):
                errors['full_name'] = 'Name contains invalid characters'
        
        # Phone validation
        if 'phone' in data:
            phone = re.sub(r'[^\d+]', '', data['phone'])
            if len(phone) < 10:
                errors['phone'] = 'Phone number must be at least 10 digits'
            elif not re.match(r'^\+?[\d\s\-\(\)]+$', data['phone']):
                errors['phone'] = 'Invalid phone number format'
        
        # Email validation
        if 'email' in data:
            email = data['email'].strip()
            if not re.match(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$', email):
                errors['email'] = 'Invalid email format'
        
        # Title validation
        if 'title' in data and data['title']:
            title = data['title'].strip()
            if len(title) > 100:
                errors['title'] = 'Title must be less than 100 characters'
            elif not re.match(r'^[a-zA-Z\s\-\.\,]+$', title):
                errors['title'] = 'Title contains invalid characters'
        
        # Bio validation
        if 'bio' in data and data['bio']:
            bio = data['bio'].strip()
            if len(bio) > 500:
                errors['bio'] = 'Bio must be less than 500 characters'
        
        # LinkedIn URL validation
        if 'linkedin' in data and data['linkedin']:
            linkedin = data['linkedin'].strip()
            linkedin_pattern = r'^(https?:\/\/)?(www\.)?linkedin\.com\/in\/[a-zA-Z0-9\-_\/]+$'
            if not re.match(linkedin_pattern, linkedin, re.IGNORECASE):
                errors['linkedin'] = 'Invalid LinkedIn URL format'
        
        # GitHub URL validation
        if 'github' in data and data['github']:
            github = data['github'].strip()
            github_pattern = r'^(https?:\/\/)?(www\.)?github\.com\/[a-zA-Z0-9\-_]+$'
            if not re.match(github_pattern, github, re.IGNORECASE):
                errors['github'] = 'Invalid GitHub URL format'
        
        # Portfolio URL validation
        if 'portfolio' in data and data['portfolio']:
            portfolio = data['portfolio'].strip()
            portfolio_pattern = r'^(https?:\/\/)?(www\.)?[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}(\/.*)?$'
            if not re.match(portfolio_pattern, portfolio, re.IGNORECASE):
                errors['portfolio'] = 'Invalid portfolio URL format'
        
        # JSON field validation
        json_fields = ['education', 'skills', 'work_experience', 'certifications', 'languages']
        for field in json_fields:
            if field in data:
                if isinstance(data[field], str):
                    try:
                        parsed = json.loads(data[field])
                        if not isinstance(parsed, (list, dict)):
                            errors[field] = f'{field} must be a valid JSON array or object'
                    except json.JSONDecodeError:
                        errors[field] = f'{field} contains invalid JSON'
                elif not isinstance(data[field], (list, dict)):
                    errors[field] = f'{field} must be a JSON array or object'
        
        return errors
    
    @staticmethod
    def sanitize_profile_data(data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Sanitize profile data to prevent XSS and injection attacks
        """
        sanitized = {}
        
        for key, value in data.items():
            if isinstance(value, str):
                # Remove potentially harmful characters
                sanitized_value = re.sub(r'[<>"\']', '', value.strip())
                sanitized[key] = sanitized_value
            elif isinstance(value, (list, dict)):
                # Recursively sanitize nested structures
                if isinstance(value, list):
                    sanitized[key] = [
                        ProfileValidator._sanitize_string(item) if isinstance(item, str) else item
                        for item in value
                    ]
                else:  # dict
                    sanitized[key] = {
                        k: ProfileValidator._sanitize_string(v) if isinstance(v, str) else v
                        for k, v in value.items()
                    }
            else:
                sanitized[key] = value
        
        return sanitized
    
    @staticmethod
    def _sanitize_string(value: str) -> str:
        """Sanitize individual string value"""
        if not isinstance(value, str):
            return value
        # Remove HTML tags and potentially harmful characters
        return re.sub(r'[<>"\']', '', value.strip())


class PIIMasker:
    """PII masking for logging and analytics"""
    
    @staticmethod
    def mask_email(email: str) -> str:
        """Mask email for logging: john.doe@example.com -> j***.***@example.com"""
        if not email or '@' not in email:
            return email
        
        local, domain = email.split('@', 1)
        if len(local) <= 2:
            masked_local = '*' * len(local)
        else:
            masked_local = local[0] + '*' * (len(local) - 2) + local[-1]
        
        return f"{masked_local}@{domain}"
    
    @staticmethod
    def mask_phone(phone: str) -> str:
        """Mask phone for logging: +27810256782 -> +27******782"""
        if not phone or len(phone) < 4:
            return phone
        
        return phone[:3] + '*' * (len(phone) - 6) + phone[-3:]
    
    @staticmethod
    def mask_id_number(id_number: str) -> str:
        """Mask ID number for logging"""
        if not id_number or len(id_number) < 4:
            return '***'
        
        return id_number[:2] + '*' * (len(id_number) - 4) + id_number[-2:]
    
    @staticmethod
    def hash_sensitive_data(data: str) -> str:
        """Hash sensitive data for comparison"""
        import hashlib
        return hashlib.sha256(data.encode()).hexdigest()[:16]


class ProfileSyncService:
    """Handles synchronization between User.profile and Candidate models"""
    
    @staticmethod
    def sync_user_to_candidate(user_id: int, session) -> bool:
        """Sync User.profile to Candidate fields"""
        try:
            from app.models import User, Candidate
            
            user = session.query(User).get(user_id)
            if not user or not user.candidates:
                return False
            
            candidate = user.candidates[0]
            user_profile = user.profile or {}
            
            # Sync basic fields
            if 'full_name' in user_profile:
                candidate.full_name = user_profile['full_name']
            
            # Sync preferences
            if 'preferences' in user_profile:
                prefs = user_profile['preferences']
                candidate.dark_mode = prefs.get('theme') == 'dark'
                candidate.notifications_email = prefs.get('notifications', {}).get('email', True)
                candidate.notifications_push = prefs.get('notifications', {}).get('push', False)
            
            # Sync avatar
            if 'avatar_url' in user_profile:
                candidate.profile_picture = user_profile['avatar_url']
            
            session.commit()
            logger.info(f"Synced user profile to candidate for user {user_id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to sync user to candidate for user {user_id}: {e}")
            session.rollback()
            return False
    
    @staticmethod
    def sync_candidate_to_user(candidate_id: int, session) -> bool:
        """Sync Candidate fields to User.profile"""
        try:
            from app.models import Candidate, User
            
            candidate = session.query(Candidate).get(candidate_id)
            if not candidate:
                return False
            
            user = candidate.user
            if not user:
                return False
            
            existing_profile = dict(user.profile) if user.profile else {}
            
            # Merge candidate data into user profile
            user.profile = {
                **existing_profile,
                "full_name": candidate.full_name or existing_profile.get("full_name"),
                "avatar_url": candidate.profile_picture or existing_profile.get("avatar_url"),
                "preferences": {
                    **existing_profile.get("preferences", {}),
                    "theme": "dark" if candidate.dark_mode else "light",
                    "notifications": {
                        **existing_profile.get("notifications", {}),
                        "email": candidate.notifications_email,
                        "push": candidate.notifications_push,
                    }
                },
                "updated_at": datetime.utcnow().isoformat()
            }
            
            session.commit()
            logger.info(f"Synced candidate to user profile for candidate {candidate_id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to sync candidate to user for candidate {candidate_id}: {e}")
            session.rollback()
            return False


class ProfileCompletionCalculator:
    """Calculate profile completion percentage"""
    
    @staticmethod
    def calculate_completion(candidate_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Calculate profile completion percentage
        Returns completion data with breakdown by section
        """
        essential_fields = ['full_name', 'phone', 'email']
        professional_fields = ['title', 'bio', 'linkedin', 'github', 'portfolio']
        structured_fields = ['education', 'skills', 'work_experience', 'certifications', 'languages']
        
        completion_data = {
            'overall_percentage': 0,
            'sections': {
                'essential': {'completed': 0, 'total': len(essential_fields), 'percentage': 0},
                'professional': {'completed': 0, 'total': len(professional_fields), 'percentage': 0},
                'structured': {'completed': 0, 'total': len(structured_fields), 'percentage': 0}
            },
            'suggestions': []
        }
        
        # Check essential fields
        for field in essential_fields:
            if candidate_data.get(field) and str(candidate_data[field]).strip():
                completion_data['sections']['essential']['completed'] += 1
        
        # Check professional fields
        for field in professional_fields:
            if candidate_data.get(field) and str(candidate_data[field]).strip():
                completion_data['sections']['professional']['completed'] += 1
        
        # Check structured fields
        for field in structured_fields:
            value = candidate_data.get(field)
            if value:
                if isinstance(value, list) and len(value) > 0:
                    completion_data['sections']['structured']['completed'] += 1
                elif isinstance(value, dict) and len(value) > 0:
                    completion_data['sections']['structured']['completed'] += 1
        
        # Calculate percentages for each section
        total_completed = 0
        total_fields = 0
        
        for section_name, section_data in completion_data['sections'].items():
            if section_data['total'] > 0:
                section_data['percentage'] = int((section_data['completed'] / section_data['total']) * 100)
                total_completed += section_data['completed']
                total_fields += section_data['total']
        
        # Calculate overall percentage
        if total_fields > 0:
            completion_data['overall_percentage'] = int((total_completed / total_fields) * 100)
        
        # Generate suggestions
        completion_data['suggestions'] = ProfileCompletionCalculator._generate_suggestions(
            completion_data['sections']
        )
        
        return completion_data
    
    @staticmethod
    def _generate_suggestions(sections: Dict[str, Dict[str, int]]) -> List[str]:
        """Generate improvement suggestions based on completion data"""
        suggestions = []
        
        if sections['essential']['percentage'] < 100:
            suggestions.append("Complete your essential information (name, phone, email)")
        
        if sections['professional']['percentage'] < 80:
            suggestions.append("Add your professional title and links to your profiles")
        
        if sections['structured']['percentage'] < 60:
            suggestions.append("Add your education, skills, and work experience")
        
        if sections['structured']['percentage'] < 100:
            suggestions.append("Complete your profile by adding certifications and languages")
        
        return suggestions


class ProfileFileValidator:
    """File validation for profile uploads"""
    
    ALLOWED_IMAGE_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.webp', '.gif'}
    ALLOWED_IMAGE_MIME_TYPES = {
        'image/png', 'image/jpeg', 'image/webp', 'image/gif'
    }
    MAX_IMAGE_SIZE = 5 * 1024 * 1024  # 5MB
    
    ALLOWED_DOCUMENT_EXTENSIONS = {'.pdf', '.doc', '.docx'}
    ALLOWED_DOCUMENT_MIME_TYPES = {
        'application/pdf', 
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    }
    MAX_DOCUMENT_SIZE = 10 * 1024 * 1024  # 10MB
    
    @staticmethod
    def validate_image_file(file) -> Tuple[bool, str]:
        """Validate profile image file"""
        if not file or not file.filename:
            return False, "No file provided"
        
        # Check file extension
        file_ext = file.filename.lower().split('.')[-1]
        if f'.{file_ext}' not in ProfileFileValidator.ALLOWED_IMAGE_EXTENSIONS:
            return False, f"Image type .{file_ext} not allowed"
        
        # Check MIME type
        if hasattr(file, 'mimetype') and file.mimetype not in ProfileFileValidator.ALLOWED_IMAGE_MIME_TYPES:
            return False, f"MIME type {file.mimetype} not allowed"
        
        # Check file size
        if hasattr(file, 'content_length') and file.content_length > ProfileFileValidator.MAX_IMAGE_SIZE:
            return False, f"Image size exceeds {ProfileFileValidator.MAX_IMAGE_SIZE // (1024*1024)}MB limit"
        
        return True, "Image validation passed"
    
    @staticmethod
    def validate_document_file(file) -> Tuple[bool, str]:
        """Validate document file"""
        if not file or not file.filename:
            return False, "No file provided"
        
        # Check file extension
        file_ext = file.filename.lower().split('.')[-1]
        if f'.{file_ext}' not in ProfileFileValidator.ALLOWED_DOCUMENT_EXTENSIONS:
            return False, f"Document type .{file_ext} not allowed"
        
        # Check MIME type
        if hasattr(file, 'mimetype') and file.mimetype not in ProfileFileValidator.ALLOWED_DOCUMENT_MIME_TYPES:
            return False, f"MIME type {file.mimetype} not allowed"
        
        # Check file size
        if hasattr(file, 'content_length') and file.content_length > ProfileFileValidator.MAX_DOCUMENT_SIZE:
            return False, f"Document size exceeds {ProfileFileValidator.MAX_DOCUMENT_SIZE // (1024*1024)}MB limit"
        
        return True, "Document validation passed"
    
    @staticmethod
    def sanitize_filename(filename: str) -> str:
        """Sanitize filename for secure storage"""
        import os
        
        # Remove path separators
        filename = os.path.basename(filename)
        
        # Remove special characters
        filename = re.sub(r'[^\w\-_\.]', '_', filename)
        
        # Limit length
        if len(filename) > 100:
            name, ext = os.path.splitext(filename)
            filename = name[:100-len(ext)] + ext
        
        return filename


class ProfileAuditService:
    """Audit logging for profile operations"""
    
    @staticmethod
    def log_profile_update(user_id: int, updated_fields: List[str], session) -> None:
        """Log profile update with PII masking"""
        try:
            from app.models import User, AuditLog
            
            user = session.query(User).get(user_id)
            if not user:
                return
            
            # Mask PII for logging
            masked_data = {
                "updated_fields": updated_fields,
                "field_count": len(updated_fields),
                "email": PIIMasker.mask_email(user.email),
            }
            
            audit_log = AuditLog(
                user_id=user_id,
                action="profile_updated",
                details=json.dumps(masked_data),
                timestamp=datetime.utcnow()
            )
            
            session.add(audit_log)
            session.commit()
            
        except Exception as e:
            logger.error(f"Failed to log profile update for user {user_id}: {e}")
    
    @staticmethod
    def log_file_upload(user_id: int, file_type: str, file_size: int, session) -> None:
        """Log file upload operation"""
        try:
            from app.models import AuditLog
            
            audit_log = AuditLog(
                user_id=user_id,
                action=f"{file_type}_uploaded",
                details=json.dumps({
                    "file_type": file_type,
                    "file_size_bytes": file_size,
                    "file_size_mb": round(file_size / (1024 * 1024), 2)
                }),
                timestamp=datetime.utcnow()
            )
            
            session.add(audit_log)
            session.commit()
            
        except Exception as e:
            logger.error(f"Failed to log file upload for user {user_id}: {e}")


class ProfileCacheService:
    """Caching service for profile data"""
    
    @staticmethod
    def get_cache_key(user_id: int, suffix: str = "") -> str:
        """Generate cache key for profile data"""
        return f"profile:{user_id}:{suffix}"
    
    @staticmethod
    def cache_profile_data(user_id: int, profile_data: Dict[str, Any], redis_client, ttl: int = 3600) -> None:
        """Cache profile data in Redis"""
        try:
            cache_key = ProfileCacheService.get_cache_key(user_id)
            redis_client.setex(cache_key, ttl, json.dumps(profile_data))
            logger.debug(f"Cached profile data for user {user_id}")
        except Exception as e:
            logger.warning(f"Failed to cache profile data for user {user_id}: {e}")
    
    @staticmethod
    def get_cached_profile_data(user_id: int, redis_client) -> Optional[Dict[str, Any]]:
        """Get cached profile data"""
        try:
            cache_key = ProfileCacheService.get_cache_key(user_id)
            cached_data = redis_client.get(cache_key)
            if cached_data:
                return json.loads(cached_data)
        except Exception as e:
            logger.warning(f"Failed to get cached profile data for user {user_id}: {e}")
        
        return None
    
    @staticmethod
    def invalidate_profile_cache(user_id: int, redis_client) -> None:
        """Invalidate cached profile data"""
        try:
            # Delete all profile-related cache keys
            pattern = f"profile:{user_id}:*"
            keys = redis_client.keys(pattern)
            if keys:
                redis_client.delete(*keys)
                logger.debug(f"Invalidated profile cache for user {user_id}")
        except Exception as e:
            logger.warning(f"Failed to invalidate profile cache for user {user_id}: {e}")
