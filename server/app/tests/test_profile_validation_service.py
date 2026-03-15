"""
Test suite for Profile Validation Service
Implements comprehensive testing based on the detailed analysis
"""

import pytest
import json
from datetime import datetime
from unittest.mock import Mock, patch, MagicMock
from app.services.profile_validation_service import (
    ProfileValidator,
    PIIMasker,
    ProfileSyncService,
    ProfileCompletionCalculator,
    ProfileFileValidator,
    ProfileAuditService,
    ProfileCacheService
)


class TestProfileValidator:
    """Test comprehensive profile validation"""
    
    def test_validate_name_success(self):
        """Test valid name validation"""
        assert ProfileValidator.validate_name("John Doe") is None
        assert ProfileValidator.validate_name("Mary-Jane Smith") is None
        assert ProfileValidator.validate_name("Dr. John A. Smith Jr.") is None
    
    def test_validate_name_errors(self):
        """Test name validation errors"""
        assert ProfileValidator.validate_name("") == "Name is required"
        assert ProfileValidator.validate_name("A") == "Name must be at least 2 characters"
        long_name = "A" * 101
        assert ProfileValidator.validate_name(long_name) == "Name must be less than 100 characters"
        assert ProfileValidator.validate_name("John123") == "Name contains invalid characters"
        assert ProfileValidator.validate_name("John@Doe") == "Name contains invalid characters"
    
    def test_validate_phone_success(self):
        """Test valid phone validation"""
        assert ProfileValidator.validate_phone("+27810256782") is None
        assert ProfileValidator.validate_phone("0820256782") is None
        assert ProfileValidator.validate_phone("(27) 82 025 6782") is None
        assert ProfileValidator.validate_phone("+1-555-123-4567") is None
    
    def test_validate_phone_errors(self):
        """Test phone validation errors"""
        assert ProfileValidator.validate_phone("") == "Phone number is required"
        assert ProfileValidator.validate_phone("123") == "Phone number must be at least 10 digits"
        assert ProfileValidator.validate_phone("abc123") == "Invalid phone number format"
    
    def test_validate_email_success(self):
        """Test valid email validation"""
        assert ProfileValidator.validate_email("john.doe@example.com") is None
        assert ProfileValidator.validate_email("user.name+tag@domain.co.uk") is None
        assert ProfileValidator.validate_email("user123@sub.domain.com") is None
    
    def test_validate_email_errors(self):
        """Test email validation errors"""
        assert ProfileValidator.validate_email("") == "Email is required"
        assert ProfileValidator.validate_email("invalid-email") == "Invalid email format"
        assert ProfileValidator.validate_email("@domain.com") == "Invalid email format"
        assert ProfileValidator.validate_email("user@") == "Invalid email format"
    
    def test_validate_linkedin_success(self):
        """Test valid LinkedIn URL validation"""
        assert ProfileValidator.validate_linkedin("https://linkedin.com/in/johndoe") is None
        assert ProfileValidator.validate_linkedin("http://www.linkedin.com/in/jane-doe") is None
        assert ProfileValidator.validate_linkedin("linkedin.com/in/username") is None
    
    def test_validate_linkedin_errors(self):
        """Test LinkedIn URL validation errors"""
        assert ProfileValidator.validate_linkedin("https://facebook.com/johndoe") == "Invalid LinkedIn URL format"
        assert ProfileValidator.validate_linkedin("https://linkedin.com/company/abc") == "Invalid LinkedIn URL format"
    
    def test_validate_complete_profile(self):
        """Test complete profile validation"""
        valid_data = {
            "full_name": "John Doe",
            "phone": "+27810256782",
            "email": "john.doe@example.com",
            "title": "Software Engineer",
            "linkedin": "https://linkedin.com/in/johndoe",
            "skills": ["Python", "JavaScript"]
        }
        
        errors = ProfileValidator.validate_profile_data(valid_data)
        assert len(errors) == 0
        
        # Test with invalid data
        invalid_data = {
            "full_name": "A",
            "phone": "123",
            "email": "invalid-email",
            "linkedin": "invalid-url"
        }
        
        errors = ProfileValidator.validate_profile_data(invalid_data)
        assert len(errors) == 4
        assert "full_name" in errors
        assert "phone" in errors
        assert "email" in errors
        assert "linkedin" in errors
    
    def test_sanitize_profile_data(self):
        """Test profile data sanitization"""
        data_with_xss = {
            "full_name": "John<script>alert('xss')</script>",
            "bio": "Hello <b>world</b> & 'quotes'",
            "skills": ["Python", "JavaScript<iframe>"]
        }
        
        sanitized = ProfileValidator.sanitize_profile_data(data_with_xss)
        
        assert sanitized["full_name"] == "Johnalert('xss')"
        assert sanitized["bio"] == "Hello world & 'quotes'"
        assert sanitized["skills"][1] == "JavaScriptiframe"


class TestPIIMasker:
    """Test PII masking functionality"""
    
    def test_mask_email(self):
        """Test email masking"""
        assert PIIMasker.mask_email("john.doe@example.com") == "j***.***@example.com"
        assert PIIMasker.mask_email("a@domain.com") == "***@domain.com"
        assert PIIMasker.mask_email("") == ""
        assert PIIMasker.mask_email("invalid") == "invalid"
    
    def test_mask_phone(self):
        """Test phone masking"""
        assert PIIMasker.mask_phone("+27810256782") == "+27******782"
        assert PIIMasker.mask_phone("0820256782") == "082***782"
        assert PIIMasker.mask_phone("123") == "123"
        assert PIIMasker.mask_phone("") == ""
    
    def test_mask_id_number(self):
        """Test ID number masking"""
        assert PIIMasker.mask_id_number("9001011234567") == "90********67"
        assert PIIMasker.mask_id_number("123") == "123"
        assert PIIMasker.mask_id_number("") == "***"
    
    def test_hash_sensitive_data(self):
        """Test sensitive data hashing"""
        data1 = "sensitive_data"
        data2 = "sensitive_data"
        data3 = "different_data"
        
        hash1 = PIIMasker.hash_sensitive_data(data1)
        hash2 = PIIMasker.hash_sensitive_data(data2)
        hash3 = PIIMasker.hash_sensitive_data(data3)
        
        assert hash1 == hash2  # Same data should produce same hash
        assert hash1 != hash3  # Different data should produce different hash
        assert len(hash1) == 16  # Hash should be 16 characters


class TestProfileCompletionCalculator:
    """Test profile completion calculation"""
    
    def test_calculate_completion_complete_profile(self):
        """Test completion calculation for complete profile"""
        complete_data = {
            "full_name": "John Doe",
            "phone": "+27810256782",
            "email": "john.doe@example.com",
            "title": "Software Engineer",
            "bio": "Experienced developer",
            "linkedin": "https://linkedin.com/in/johndoe",
            "github": "https://github.com/johndoe",
            "portfolio": "https://johndoe.com",
            "education": [{"degree": "BSc", "institution": "University"}],
            "skills": ["Python", "JavaScript"],
            "work_experience": [{"company": "Tech Corp", "position": "Developer"}],
            "certifications": [{"name": "AWS Certified"}],
            "languages": [{"name": "English", "level": "Fluent"}]
        }
        
        result = ProfileCompletionCalculator.calculate_completion(complete_data)
        
        assert result["overall_percentage"] == 100
        assert result["sections"]["essential"]["percentage"] == 100
        assert result["sections"]["professional"]["percentage"] == 100
        assert result["sections"]["structured"]["percentage"] == 100
        assert len(result["suggestions"]) == 0
    
    def test_calculate_completion_partial_profile(self):
        """Test completion calculation for partial profile"""
        partial_data = {
            "full_name": "John Doe",
            "phone": "+27810256782",
            "email": "john.doe@example.com",
            "title": "Software Engineer",
            # Missing bio, social profiles, and structured data
        }
        
        result = ProfileCompletionCalculator.calculate_completion(partial_data)
        
        assert result["overall_percentage"] == 40  # 4 out of 10 fields
        assert result["sections"]["essential"]["percentage"] == 100
        assert result["sections"]["professional"]["percentage"] == 20  # 1 out of 5
        assert result["sections"]["structured"]["percentage"] == 0
        assert len(result["suggestions"]) > 0
    
    def test_generate_suggestions(self):
        """Test suggestion generation"""
        sections = {
            "essential": {"percentage": 100},
            "professional": {"percentage": 40},
            "structured": {"percentage": 20}
        }
        
        suggestions = ProfileCompletionCalculator._generate_suggestions(sections)
        
        assert len(suggestions) == 2  # Should suggest professional and structured improvements
        assert any("professional" in s.lower() for s in suggestions)
        assert any("education" in s.lower() or "skills" in s.lower() for s in suggestions)


class TestProfileFileValidator:
    """Test file validation functionality"""
    
    def test_validate_image_file_success(self):
        """Test valid image file validation"""
        mock_file = Mock()
        mock_file.filename = "profile.jpg"
        mock_file.mimetype = "image/jpeg"
        mock_file.content_length = 1024 * 1024  # 1MB
        
        is_valid, message = ProfileFileValidator.validate_image_file(mock_file)
        
        assert is_valid is True
        assert message == "Image validation passed"
    
    def test_validate_image_file_invalid_extension(self):
        """Test invalid image file extension"""
        mock_file = Mock()
        mock_file.filename = "profile.exe"
        mock_file.mimetype = "application/octet-stream"
        
        is_valid, message = ProfileFileValidator.validate_image_file(mock_file)
        
        assert is_valid is False
        assert "Image type .exe not allowed" in message
    
    def test_validate_image_file_too_large(self):
        """Test image file size validation"""
        mock_file = Mock()
        mock_file.filename = "profile.jpg"
        mock_file.mimetype = "image/jpeg"
        mock_file.content_length = 10 * 1024 * 1024 + 1  # Over 10MB
        
        is_valid, message = ProfileFileValidator.validate_image_file(mock_file)
        
        assert is_valid is False
        assert "exceeds" in message and "limit" in message
    
    def test_validate_document_file_success(self):
        """Test valid document file validation"""
        mock_file = Mock()
        mock_file.filename = "resume.pdf"
        mock_file.mimetype = "application/pdf"
        mock_file.content_length = 2 * 1024 * 1024  # 2MB
        
        is_valid, message = ProfileFileValidator.validate_document_file(mock_file)
        
        assert is_valid is True
        assert message == "Document validation passed"
    
    def test_sanitize_filename(self):
        """Test filename sanitization"""
        assert ProfileFileValidator.sanitize_filename("normal_file.jpg") == "normal_file.jpg"
        assert ProfileFileValidator.sanitize_filename("file with spaces.pdf") == "file_with_spaces.pdf"
        assert ProfileFileValidator.sanitize_filename("file<script>.docx") == "file_script_.docx"
        assert ProfileFileValidator.sanitize_filename("a" * 200 + ".pdf") == "a" * 96 + ".pdf"  # Truncated


class TestProfileSyncService:
    """Test profile synchronization functionality"""
    
    @patch('app.services.profile_validation_service.User')
    @patch('app.services.profile_validation_service.Candidate')
    def test_sync_user_to_candidate_success(self, mock_candidate, mock_user):
        """Test successful user to candidate sync"""
        # Setup mocks
        mock_user_instance = Mock()
        mock_user_instance.profile = {
            "full_name": "John Doe",
            "preferences": {
                "theme": "dark",
                "notifications": {"email": True, "push": False}
            }
        }
        mock_user.query.get.return_value = mock_user_instance
        
        mock_candidate_instance = Mock()
        mock_candidate_instance.candidates = [mock_candidate_instance]
        mock_user.query.get.return_value = mock_candidate_instance
        
        mock_session = Mock()
        
        # Test sync
        result = ProfileSyncService.sync_user_to_candidate(1, mock_session)
        
        assert result is True
        assert mock_candidate_instance.full_name == "John Doe"
        assert mock_candidate_instance.dark_mode is True
        assert mock_candidate_instance.notifications_email is True
        assert mock_candidate_instance.notifications_push is False
        mock_session.commit.assert_called_once()
    
    @patch('app.services.profile_validation_service.User')
    @patch('app.services.profile_validation_service.Candidate')
    def test_sync_candidate_to_user_success(self, mock_candidate, mock_user):
        """Test successful candidate to user sync"""
        # Setup mocks
        mock_candidate_instance = Mock()
        mock_candidate_instance.full_name = "Jane Doe"
        mock_candidate_instance.profile_picture = "https://example.com/avatar.jpg"
        mock_candidate_instance.dark_mode = True
        mock_candidate_instance.notifications_email = False
        mock_candidate_instance.notifications_push = True
        mock_candidate_instance.user = Mock()
        
        mock_candidate.query.get.return_value = mock_candidate_instance
        
        mock_session = Mock()
        
        # Test sync
        result = ProfileSyncService.sync_candidate_to_user(1, mock_session)
        
        assert result is True
        mock_candidate_instance.user.profile["full_name"] == "Jane Doe"
        mock_candidate_instance.user.profile["avatar_url"] == "https://example.com/avatar.jpg"
        mock_candidate_instance.user.profile["preferences"]["theme"] == "dark"
        mock_session.commit.assert_called_once()


class TestProfileAuditService:
    """Test profile audit functionality"""
    
    @patch('app.services.profile_validation_service.User')
    @patch('app.services.profile_validation_service.AuditLog')
    def test_log_profile_update(self, mock_audit_log, mock_user):
        """Test profile update logging"""
        # Setup mocks
        mock_user_instance = Mock()
        mock_user_instance.email = "test@example.com"
        mock_user.query.get.return_value = mock_user_instance
        
        mock_session = Mock()
        
        # Test logging
        ProfileAuditService.log_profile_update(1, ["full_name", "phone"], mock_session)
        
        # Verify audit log creation
        mock_session.add.assert_called_once()
        mock_session.commit.assert_called_once()
        
        # Get the audit log that was added
        added_audit_log = mock_session.add.call_args[0][0]
        assert added_audit_log.user_id == 1
        assert added_audit_log.action == "profile_updated"
        
        # Verify PII masking in details
        details = json.loads(added_audit_log.details)
        assert details["email"] == "t***@example.com"
        assert details["updated_fields"] == ["full_name", "phone"]
    
    @patch('app.services.profile_validation_service.AuditLog')
    def test_log_file_upload(self, mock_audit_log):
        """Test file upload logging"""
        mock_session = Mock()
        
        # Test logging
        ProfileAuditService.log_file_upload(1, "profile_picture", 1024 * 1024, mock_session)
        
        # Verify audit log creation
        mock_session.add.assert_called_once()
        mock_session.commit.assert_called_once()
        
        # Get the audit log that was added
        added_audit_log = mock_session.add.call_args[0][0]
        assert added_audit_log.user_id == 1
        assert added_audit_log.action == "profile_picture_uploaded"
        
        details = json.loads(added_audit_log.details)
        assert details["file_type"] == "profile_picture"
        assert details["file_size_bytes"] == 1024 * 1024
        assert details["file_size_mb"] == 1.0


class TestProfileCacheService:
    """Test profile caching functionality"""
    
    def test_get_cache_key(self):
        """Test cache key generation"""
        key = ProfileCacheService.get_cache_key(123, "completion")
        assert key == "profile:123:completion"
        
        key_no_suffix = ProfileCacheService.get_cache_key(456)
        assert key_no_suffix == "profile:456:"
    
    def test_cache_profile_data(self):
        """Test profile data caching"""
        mock_redis = Mock()
        profile_data = {"full_name": "John Doe", "completion": 85}
        
        ProfileCacheService.cache_profile_data(1, profile_data, mock_redis, 3600)
        
        mock_redis.setex.assert_called_once_with(
            "profile:1:",
            3600,
            json.dumps(profile_data)
        )
    
    def test_get_cached_profile_data(self):
        """Test getting cached profile data"""
        mock_redis = Mock()
        cached_json = json.dumps({"full_name": "John Doe"})
        mock_redis.get.return_value = cached_json
        
        result = ProfileCacheService.get_cached_profile_data(1, mock_redis)
        
        assert result == {"full_name": "John Doe"}
        mock_redis.get.assert_called_once_with("profile:1:")
    
    def test_get_cached_profile_data_miss(self):
        """Test cache miss"""
        mock_redis = Mock()
        mock_redis.get.return_value = None
        
        result = ProfileCacheService.get_cached_profile_data(1, mock_redis)
        
        assert result is None
    
    def test_invalidate_profile_cache(self):
        """Test cache invalidation"""
        mock_redis = Mock()
        mock_redis.keys.return_value = ["profile:1:", "profile:1:completion"]
        
        ProfileCacheService.invalidate_profile_cache(1, mock_redis)
        
        mock_redis.keys.assert_called_once_with("profile:1:*")
        mock_redis.delete.assert_called_once_with("profile:1:", "profile:1:completion")


class TestIntegration:
    """Integration tests for the complete profile validation service"""
    
    def test_complete_profile_validation_flow(self):
        """Test complete profile validation and processing flow"""
        # Input data with various issues
        input_data = {
            "full_name": "John<script>alert('xss')</script>",
            "phone": "+27810256782",
            "email": "john.doe@example.com",
            "title": "Software Engineer",
            "bio": "Hello <b>world</b>",
            "linkedin": "https://linkedin.com/in/johndoe",
            "skills": '["Python", "JavaScript", "john.doe@example.com"]',  # JSON string with reference
        }
        
        # Step 1: Validate data
        errors = ProfileValidator.validate_profile_data(input_data)
        assert len(errors) == 0  # Should pass validation
        
        # Step 2: Sanitize data
        sanitized_data = ProfileValidator.sanitize_profile_data(input_data)
        assert sanitized_data["full_name"] == "Johnalert('xss')"
        assert sanitized_data["bio"] == "Hello world"
        
        # Step 3: Parse JSON fields
        if isinstance(sanitized_data["skills"], str):
            sanitized_data["skills"] = json.loads(sanitized_data["skills"])
        
        # Step 4: Calculate completion
        completion = ProfileCompletionCalculator.calculate_completion(sanitized_data)
        assert completion["overall_percentage"] > 0
        
        # Step 5: Mask PII for logging
        masked_email = PIIMasker.mask_email(sanitized_data["email"])
        assert masked_email == "j***.***@example.com"
    
    def test_file_upload_validation_flow(self):
        """Test complete file upload validation flow"""
        # Mock file upload
        mock_file = Mock()
        mock_file.filename = "../../../etc/passwd.jpg"
        mock_file.mimetype = "image/jpeg"
        mock_file.content_length = 2 * 1024 * 1024  # 2MB
        
        # Step 1: Validate file
        is_valid, message = ProfileFileValidator.validate_image_file(mock_file)
        assert is_valid is True
        
        # Step 2: Sanitize filename
        sanitized_name = ProfileFileValidator.sanitize_filename(mock_file.filename)
        assert ".." not in sanitized_name
        assert sanitized_name.endswith(".jpg")
        
        # Step 3: Log upload (mock)
        mock_session = Mock()
        ProfileAuditService.log_file_upload(1, "profile_picture", mock_file.content_length, mock_session)
        assert mock_session.add.called
    
    @patch('app.services.profile_validation_service.User')
    @patch('app.services.profile_validation_service.Candidate')
    def test_profile_sync_flow(self, mock_candidate, mock_user):
        """Test complete profile synchronization flow"""
        # Setup mock data
        mock_user_instance = Mock()
        mock_user_instance.profile = {
            "full_name": "John Doe",
            "preferences": {"theme": "dark"}
        }
        mock_user.query.get.return_value = mock_user_instance
        
        mock_candidate_instance = Mock()
        mock_candidate_instance.full_name = "Jane Doe"
        mock_candidate_instance.user = mock_user_instance
        mock_candidate.query.get.return_value = mock_candidate_instance
        
        mock_session = Mock()
        
        # Test bidirectional sync
        # User to Candidate
        result1 = ProfileSyncService.sync_user_to_candidate(1, mock_session)
        assert result1 is True
        
        # Candidate to User
        result2 = ProfileSyncService.sync_candidate_to_user(1, mock_session)
        assert result2 is True
        
        # Verify both commits were called
        assert mock_session.commit.call_count == 2


if __name__ == "__main__":
    pytest.main([__file__])
