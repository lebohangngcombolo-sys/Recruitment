"""
Recruitee API Client with rate limiting and retry logic.
"""
from __future__ import annotations

import time
import logging
from typing import Any, Dict, Optional
from threading import Lock

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from flask import current_app

logger = logging.getLogger(__name__)


class RecruiteeAPIError(Exception):
    """Custom exception for Recruitee API errors"""
    def __init__(self, message: str, status_code: int = None, response_body: str = None):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.response_body = response_body


class RateLimiter:
    """Simple rate limiter: 900 requests per hour (100 buffer below 1000 limit)"""
    def __init__(self, max_calls: int = 900, period: int = 3600):
        self.max_calls = max_calls
        self.period = period
        self.calls = []
        self.lock = Lock()

    def acquire(self):
        with self.lock:
            now = time.time()
            # Remove old calls outside the time window
            self.calls = [t for t in self.calls if now - t < self.period]
            
            if len(self.calls) >= self.max_calls:
                sleep_time = self.calls[0] + self.period - now
                if sleep_time > 0:
                    logger.warning(f"Rate limit hit. Sleeping for {sleep_time:.1f}s")
                    time.sleep(sleep_time)
                return self.acquire()
            
            self.calls.append(now)


class RecruiteeClient:
    """HTTP client for Recruitee API with automatic rate limiting and retries"""
    
    def __init__(self, company_id: Optional[str] = None, api_token: Optional[str] = None, 
                 timeout: int = 30):
        # Get from Flask config if not provided directly
        self.company_id = company_id or current_app.config.get('RECRUITEE_COMPANY_ID')
        self.api_token = api_token or current_app.config.get('RECRUITEE_API_TOKEN')
        self.timeout = timeout
        
        if not self.company_id or not self.api_token:
            raise ValueError("RECRUITEE_COMPANY_ID and RECRUITEE_API_TOKEN are required")
        
        self.base_url = f"https://api.recruitee.com/c/{self.company_id}"
        self.session = requests.Session()
        
        # Configure retries for transient failures
        retry = Retry(
            total=3,
            connect=3,
            read=3,
            status=3,
            backoff_factor=0.5,
            status_forcelist=(429, 500, 502, 503, 504),
            allowed_methods=("GET", "POST", "PUT", "PATCH", "DELETE"),
        )
        adapter = HTTPAdapter(max_retries=retry)
        self.session.mount("https://", adapter)
        self.session.mount("http://", adapter)
        
        # Set default headers
        self.session.headers.update({
            "Authorization": f"Bearer {self.api_token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        })
        
        # Initialize rate limiter
        self.rate_limiter = RateLimiter()
    
    def _request(self, method: str, path: str, **kwargs) -> Any:
        """Make an HTTP request with rate limiting and error handling"""
        self.rate_limiter.acquire()
        
        url = f"{self.base_url}{path}"
        
        try:
            response = self.session.request(
                method=method,
                url=url,
                timeout=self.timeout,
                **kwargs
            )
            
            # Handle rate limit response with Retry-After
            if response.status_code == 429:
                retry_after = int(response.headers.get("Retry-After", 5))
                logger.warning(f"Rate limited by Recruitee. Retrying after {retry_after}s")
                time.sleep(retry_after)
                return self._request(method, path, **kwargs)
            
            # Handle other errors
            if not response.ok:
                error_body = response.text[:1000] if response.text else "No response body"
                request_body = kwargs.get('json', kwargs.get('data', 'No request body'))
                logger.error(f"Recruitee API Error {response.status_code}:")
                logger.error(f"  Request: {method} {url}")
                logger.error(f"  Request body: {request_body}")
                logger.error(f"  Response: {error_body}")
                raise RecruiteeAPIError(
                    f"{method} {path} failed: {response.status_code} - {error_body}",
                    status_code=response.status_code,
                    response_body=error_body
                )
            
            # Return None for 204 No Content
            if response.status_code == 204:
                return None
            
            # Parse JSON response
            try:
                return response.json()
            except ValueError:
                return response.text
                
        except requests.exceptions.Timeout:
            raise RecruiteeAPIError(f"Request timeout: {method} {path}")
        except requests.exceptions.ConnectionError as e:
            raise RecruiteeAPIError(f"Connection error: {method} {path} - {str(e)}")
        except requests.exceptions.RequestException as e:
            raise RecruiteeAPIError(f"Request failed: {method} {path} - {str(e)}")
    
    # ==================== OFFERS / JOBS ====================
    
    def get_offers(self, status: Optional[str] = None, limit: int = 100) -> Dict[str, Any]:
        """Fetch job offers from Recruitee
        
        Args:
            status: Filter by status (published, closed, draft, archived, internal)
            limit: Number of offers to fetch (max 100)
        """
        params = {"limit": limit}
        if status:
            params["status"] = status
        return self._request("GET", "/offers", params=params)
    
    def get_offer(self, offer_id: str) -> Dict[str, Any]:
        """Fetch a single offer by ID"""
        return self._request("GET", f"/offers/{offer_id}")
    
    def create_offer(self, offer_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new job offer in Recruitee
        
        Required fields in offer_data:
        - title: str
        
        Optional fields:
        - description: str
        - location: str
        - department: str
        - status: str (published, closed, draft)
        - employment_type: str (full_time, part_time, contract, internship, temporary)
        - external_id: str
        """
        return self._request("POST", "/offers", json={"offer": offer_data})
    
    def update_offer(self, offer_id: str, offer_data: Dict[str, Any]) -> Dict[str, Any]:
        """Update an existing offer"""
        return self._request("PATCH", f"/offers/{offer_id}", json={"offer": offer_data})
    
    def close_offer(self, offer_id: str) -> Dict[str, Any]:
        """Close/archived an offer"""
        return self.update_offer(offer_id, {"status": "closed"})
    
    # ==================== CANDIDATES ====================
    
    def get_candidates(self, offer_id: Optional[str] = None, 
                       query: Optional[str] = None,
                       limit: int = 100) -> Dict[str, Any]:
        """Fetch candidates from Recruitee
        
        Args:
            offer_id: Filter by offer
            query: Search query (email, name, etc.)
            limit: Number of candidates to fetch
        """
        params = {"limit": limit}
        if offer_id:
            params["offer_id"] = offer_id
        if query:
            params["q"] = query
        return self._request("GET", "/candidates", params=params)
    
    def get_candidate(self, candidate_id: str) -> Dict[str, Any]:
        """Fetch a single candidate by ID"""
        return self._request("GET", f"/candidates/{candidate_id}")
    
    def create_candidate(self, candidate_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new candidate in Recruitee
        
        Required fields:
        - name: str
        - email: str
        
        Optional fields:
        - phone: str
        - cv_data: str (base64 encoded CV)
        - cv_url: str (URL to CV file)
        - source: str
        - external_id: str
        - placements: list of {offer_id: str}
        """
        return self._request("POST", "/candidates", json={"candidate": candidate_data})
    
    def update_candidate(self, candidate_id: str, 
                       candidate_data: Dict[str, Any]) -> Dict[str, Any]:
        """Update an existing candidate"""
        return self._request("PATCH", f"/candidates/{candidate_id}", 
                           json={"candidate": candidate_data})
    
    def add_candidate_to_offer(self, candidate_id: str, offer_id: str) -> Dict[str, Any]:
        """Add a candidate to a specific job offer"""
        return self._request("POST", f"/candidates/{candidate_id}/placements",
                           json={"placement": {"offer_id": offer_id}})
    
    # ==================== UTILITY ====================
    
    def test_connection(self) -> bool:
        """Test API connection by fetching offers"""
        try:
            self.get_offers(limit=1)
            return True
        except RecruiteeAPIError:
            return False
