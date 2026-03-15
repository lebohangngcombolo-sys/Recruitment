import pytest
from unittest.mock import Mock, patch, MagicMock
from app.services.analysis_service_client import AnalysisServiceClient
from app.services.data_merger import DataMerger
from app.models import CVAnalysis, Application, Candidate
from app import create_app, db
import json

class TestAnalysisServiceIntegration:
    
    @patch('requests.post')
    def test_submit_cv_success(self, mock_post):
        """Test successful CV submission to external service."""
        mock_post.return_value.json.return_value = {'analysis_id': 'ext-123'}
        mock_post.return_value.raise_for_status.return_value = None
        mock_post.return_value.status_code = 202
        
        with patch('flask.current_app') as mock_app:
            mock_app.config = {
                'ANALYSIS_SERVICE_URL': 'http://test.com',
                'ANALYSIS_SERVICE_API_KEY': 'test-key'
            }
            
            result = AnalysisServiceClient.submit_cv(1, 'http://cv.url', 'job description')
            assert result['analysis_id'] == 'ext-123'
            mock_post.assert_called_once()
    
    @patch('requests.get')
    def test_get_analysis_status(self, mock_get):
        """Test getting analysis status from external service."""
        mock_get.return_value.json.return_value = {'status': 'completed'}
        mock_get.return_value.raise_for_status.return_value = None
        
        with patch('flask.current_app') as mock_app:
            mock_app.config = {
                'ANALYSIS_SERVICE_URL': 'http://test.com',
                'ANALYSIS_SERVICE_API_KEY': 'test-key'
            }
            
            result = AnalysisServiceClient.get_analysis_status('ext-123')
            assert result['status'] == 'completed'
            mock_get.assert_called_once()
    
    @patch('requests.get')
    def test_get_analysis_result(self, mock_get):
        """Test getting analysis result from external service."""
        mock_result = {
            'match_analysis': {
                'overall_score': 85,
                'evidence': {
                    'skills': [{'skill': 'Python', 'confidence': 0.95}],
                    'education': [{'institution': 'MIT', 'degree': 'BS', 'confidence': 0.9}]
                },
                'missing_skills': ['AWS'],
                'suggestions': ['Highlight AWS experience']
            }
        }
        mock_get.return_value.json.return_value = mock_result
        mock_get.return_value.raise_for_status.return_value = None
        
        with patch('flask.current_app') as mock_app:
            mock_app.config = {
                'ANALYSIS_SERVICE_URL': 'http://test.com',
                'ANALYSIS_SERVICE_API_KEY': 'test-key'
            }
            
            result = AnalysisServiceClient.get_analysis_result('ext-123')
            assert result['match_analysis']['overall_score'] == 85
            mock_get.assert_called_once()

class TestDataMerger:
    
    def test_merge_skills_with_confidence(self):
        """Test skills merging with confidence threshold."""
        # Create mock candidate
        candidate = Mock()
        candidate.skills = 'Python, SQL'
        
        # Mock external result with high and low confidence skills
        external_result = {
            'match_analysis': {
                'evidence': {
                    'skills': [
                        {'skill': 'JavaScript', 'confidence': 0.95},  # Should be added
                        {'skill': 'Python', 'confidence': 0.95},      # Duplicate, should not be added
                        {'skill': 'Ruby', 'confidence': 0.8}          # Below threshold, should not be added
                    ]
                }
            }
        }
        
        # Test the merge logic
        DataMerger._merge_candidate_profile(candidate, external_result)
        
        # Check that JavaScript was added but Ruby was not
        skills_list = [s.strip() for s in candidate.skills.split(',')]
        assert 'JavaScript' in skills_list
        assert 'Ruby' not in skills_list
    
    def test_merge_education_with_confidence(self):
        """Test education merging with confidence threshold."""
        candidate = Mock()
        candidate.education = 'BS Computer Science at University A'
        
        external_result = {
            'match_analysis': {
                'evidence': {
                    'education': [
                        {'institution': 'MIT', 'degree': 'MS', 'confidence': 0.95},  # Should be added
                        {'institution': 'MIT', 'degree': 'BS', 'confidence': 0.85}   # Below threshold
                    ]
                }
            }
        }
        
        DataMerger._merge_candidate_profile(candidate, external_result)
        
        # Check that high confidence education was added
        assert 'MS at MIT' in candidate.education
        assert 'BS at MIT' not in candidate.education

if __name__ == '__main__':
    pytest.main([__file__])
