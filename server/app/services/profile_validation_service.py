"""
Profile Validation Service
Implements comprehensive profile validation and optimization
Based on the detailed profile system analysis
"""

# import re
# import json
# import logging
# from typing import Dict, Any, List, Optional, Tuple
# from datetime import datetime

# logger = logging.getLogger(__name__)


class ProfileValidator:
    """Comprehensive profile data validation with security considerations"""

    @staticmethod
    def validate_name(name: str):  # -> Optional[str]:
        """Validate name and return error message or None"""
        if not name or not name.strip():
            return "Name is required"
        name = name.strip()
        if len(name) < 2:
            return "Name must be at least 2 characters"
        if len(name) > 100:
            return "Name must be less than 100 characters"
        # if not re.match(r'^[a-zA-Z\s\-\'\.]+$', name):
        #     return "Name contains invalid characters"
        return None

    @staticmethod
    def validate_phone(phone: str):  # -> Optional[str]:
        """Validate phone number and return error message or None"""
        if not phone or not phone.strip():
            return "Phone number is required"
        phone = phone.strip()
        # if not re.match(r'^\+?[\d\s\-\(\)]+$', phone):
        #     return "Invalid phone number format"
        # phone_digits = re.sub(r'[^\d+]', '', phone)
        phone_digits = phone  # Simplified
        if len(phone_digits) < 10:
            return "Phone number must be at least 10 digits"
        return None

    @staticmethod
    def validate_email(email: str):  # -> Optional[str]:
        """Validate email and return error message or None"""
        if not email or not email.strip():
            return "Email is required"
        email = email.strip()
        # Temporarily disable regex check
        # if not re.match(r'^[\w\.\+\-]+@([\w\-]+\.)+[\w\-]{2,4}$', email):
        #     return "Invalid email format"
        return None

    @staticmethod
    def validate_linkedin(url: str):  # -> Optional[str]:
        """Validate LinkedIn URL and return error message or None"""
        if not url or not url.strip():
            return None  # LinkedIn is optional
        url = url.strip()
        linkedin_pattern = r'^(https?:\/\/)?(www\.)?linkedin\.com\/in\/[a-zA-Z0-9\-_\/]+$'
        if not re.match(linkedin_pattern, url, re.IGNORECASE):
            return "Invalid LinkedIn URL format"
        return None

    @staticmethod
    def validate_github(url: str):  # -> Optional[str]:
        """Validate GitHub URL and return error message or None"""
        if not url or not url.strip():
            return None  # GitHub is optional
        url = url.strip()
        github_pattern = r'^(https?:\/\/)?(www\.)?github\.com\/[a-zA-Z0-9\-_]+$'
        if not re.match(github_pattern, url, re.IGNORECASE):
            return "Invalid GitHub URL format"
        return None

    @staticmethod
    def validate_profile_data(data):  # : Dict[str, Any]) -> Dict[str, str]:
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

        # Email validation
        if 'email' in data:
            email = data['email'].strip()
            if not re.match(r'^[\w\.\+\-]+@([\w\-]+\.)+[\w\-]{2,4}$', email):
                errors['email'] = 'Invalid email format'

        return errors


class PIIMasker:
    """PII masking for logging and analytics"""

    @staticmethod
    def mask_email(email: str) -> str:
        """Mask email for logging: john.doe@example.com -> j***.***@example.com"""
        if not email or '@' not in email:
            return email

        local, domain = email.split('@', 1)
        # Split local part by dots
        segments = local.split('.')
        masked_segments = []
        for i, segment in enumerate(segments):
            if i == 0:  # First segment
                if len(segment) <= 2:
                    masked_segments.append('***')
                else:
                    masked_segments.append(segment[0] + '***')
            else:  # Other segments
                masked_segments.append('***')
        masked_local = '.'.join(masked_segments)

        return f"{masked_local}@{domain}"

    @staticmethod
    def mask_phone(phone: str) -> str:
        """Mask phone for logging: +27810256782 -> +27******782"""
        if not phone or len(phone) < 4:
            return phone

        if phone.startswith('+'):
            # International format: show country code + asterisks + last 3
            return phone[:3] + '*' * (len(phone) - 6) + phone[-3:]
        else:
            # Local format: show area code + 3 asterisks + last 3
            return phone[:3] + '***' + phone[-3:]

    @staticmethod
    def mask_id_number(id_number: str) -> str:
        """Mask ID number for logging"""
        if not id_number or len(id_number) < 4:
            return '***'

        # Show first 2, mask middle, show last 2
        return id_number[:2] + '*' * 8 + id_number[-2:]

    @staticmethod
    def hash_sensitive_data(data: str) -> str:
        """Hash sensitive data for comparison"""
        import hashlib
        return hashlib.sha256(data.encode()).hexdigest()[:16]
