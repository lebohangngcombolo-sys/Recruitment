"""
Comprehensive Certification Detection Service
Provides advanced certification detection with authority verification and level classification.
"""

import re
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


class ComprehensiveCertificationDetector:
    """Advanced certification detection with authority verification and classification."""
    
    def __init__(self):
        # Comprehensive certification database
        self.certification_database = {
            # Technology Certifications
            'aws': {
                'certifications': {
                    'AWS Certified Solutions Architect - Associate': {'level': 'associate', 'authority': 'Amazon Web Services', 'category': 'cloud'},
                    'AWS Certified Solutions Architect - Professional': {'level': 'professional', 'authority': 'Amazon Web Services', 'category': 'cloud'},
                    'AWS Certified Developer - Associate': {'level': 'associate', 'authority': 'Amazon Web Services', 'category': 'cloud'},
                    'AWS Certified DevOps Engineer - Professional': {'level': 'professional', 'authority': 'Amazon Web Services', 'category': 'cloud'},
                    'AWS Certified Data Analytics - Specialty': {'level': 'specialty', 'authority': 'Amazon Web Services', 'category': 'data'},
                    'AWS Certified Machine Learning - Specialty': {'level': 'specialty', 'authority': 'Amazon Web Services', 'category': 'ai'},
                    'AWS Certified Security - Specialty': {'level': 'specialty', 'authority': 'Amazon Web Services', 'category': 'security'},
                    'AWS Certified Cloud Practitioner': {'level': 'foundation', 'authority': 'Amazon Web Services', 'category': 'cloud'},
                },
                'keywords': ['aws', 'amazon web services'],
                'confidence': 0.9
            },
            'microsoft': {
                'certifications': {
                    'Microsoft Certified: Azure Administrator Associate': {'level': 'associate', 'authority': 'Microsoft', 'category': 'cloud'},
                    'Microsoft Certified: Azure Developer Associate': {'level': 'associate', 'authority': 'Microsoft', 'category': 'cloud'},
                    'Microsoft Certified: Azure Solutions Architect Expert': {'level': 'expert', 'authority': 'Microsoft', 'category': 'cloud'},
                    'Microsoft Certified: Azure Fundamentals': {'level': 'foundation', 'authority': 'Microsoft', 'category': 'cloud'},
                    'Microsoft 365 Certified: Modern Desktop Administrator Associate': {'level': 'associate', 'authority': 'Microsoft', 'category': 'productivity'},
                    'Microsoft Certified: Power Platform Fundamentals': {'level': 'foundation', 'authority': 'Microsoft', 'category': 'productivity'},
                },
                'keywords': ['microsoft', 'ms', 'azure'],
                'confidence': 0.9
            },
            'google': {
                'certifications': {
                    'Google Cloud Certified - Associate Cloud Engineer': {'level': 'associate', 'authority': 'Google Cloud', 'category': 'cloud'},
                    'Google Cloud Certified - Professional Cloud Architect': {'level': 'professional', 'authority': 'Google Cloud', 'category': 'cloud'},
                    'Google Cloud Certified - Professional Data Engineer': {'level': 'professional', 'authority': 'Google Cloud', 'category': 'data'},
                    'Google Cloud Certified - Professional Cloud Developer': {'level': 'professional', 'authority': 'Google Cloud', 'category': 'cloud'},
                    'Google Cloud Certified - Cloud Digital Leader': {'level': 'foundation', 'authority': 'Google Cloud', 'category': 'cloud'},
                },
                'keywords': ['google', 'gcp', 'google cloud'],
                'confidence': 0.9
            },
            'compTIA': {
                'certifications': {
                    'CompTIA A+': {'level': 'foundation', 'authority': 'CompTIA', 'category': 'hardware'},
                    'CompTIA Network+': {'level': 'foundation', 'authority': 'CompTIA', 'category': 'networking'},
                    'CompTIA Security+': {'level': 'intermediate', 'authority': 'CompTIA', 'category': 'security'},
                    'CompTIA Cloud+': {'level': 'intermediate', 'authority': 'CompTIA', 'category': 'cloud'},
                    'CompTIA Linux+': {'level': 'intermediate', 'authority': 'CompTIA', 'category': 'linux'},
                    'CompTIA Project+': {'level': 'intermediate', 'authority': 'CompTIA', 'category': 'project_management'},
                    'CompTIA CySA+': {'level': 'intermediate', 'authority': 'CompTIA', 'category': 'security'},
                    'CompTIA PenTest+': {'level': 'intermediate', 'authority': 'CompTIA', 'category': 'security'},
                },
                'keywords': ['comptia'],
                'confidence': 0.85
            },
            'cisco': {
                'certifications': {
                    'CCNA (Cisco Certified Network Associate)': {'level': 'associate', 'authority': 'Cisco', 'category': 'networking'},
                    'CCNP (Cisco Certified Network Professional)': {'level': 'professional', 'authority': 'Cisco', 'category': 'networking'},
                    'CCIE (Cisco Certified Internetwork Expert)': {'level': 'expert', 'authority': 'Cisco', 'category': 'networking'},
                    'CCENT (Cisco Certified Entry Network Technician)': {'level': 'entry', 'authority': 'Cisco', 'category': 'networking'},
                },
                'keywords': ['cisco', 'ccna', 'ccnp', 'ccie'],
                'confidence': 0.85
            },
            'oracle': {
                'certifications': {
                    'Oracle Certified Associate (OCA)': {'level': 'associate', 'authority': 'Oracle', 'category': 'database'},
                    'Oracle Certified Professional (OCP)': {'level': 'professional', 'authority': 'Oracle', 'category': 'database'},
                    'Oracle Certified Master (OCM)': {'level': 'expert', 'authority': 'Oracle', 'category': 'database'},
                    'Oracle Database SQL Certified Associate': {'level': 'associate', 'authority': 'Oracle', 'category': 'database'},
                },
                'keywords': ['oracle', 'oca', 'ocp', 'ocm'],
                'confidence': 0.85
            },
            # Data Science & Analytics
            'data_science': {
                'certifications': {
                    'Data Science Certificate': {'level': 'intermediate', 'authority': 'Various', 'category': 'data_science'},
                    'Google Data Analytics Certificate': {'level': 'intermediate', 'authority': 'Google', 'category': 'data'},
                    'IBM Data Science Certificate': {'level': 'intermediate', 'authority': 'IBM', 'category': 'data_science'},
                    'Microsoft Certified: Data Analyst Associate': {'level': 'associate', 'authority': 'Microsoft', 'category': 'data'},
                    'Tableau Desktop Specialist': {'level': 'foundation', 'authority': 'Tableau', 'category': 'visualization'},
                    'Tableau Certified Associate': {'level': 'associate', 'authority': 'Tableau', 'category': 'visualization'},
                    'Power BI Data Analyst Associate': {'level': 'associate', 'authority': 'Microsoft', 'category': 'visualization'},
                },
                'keywords': ['data science', 'data analytics', 'tableau', 'power bi'],
                'confidence': 0.8
            },
            # Development & Programming
            'development': {
                'certifications': {
                    'Certified Java Programmer': {'level': 'associate', 'authority': 'Oracle', 'category': 'programming'},
                    'Python Institute Certifications': {'level': 'intermediate', 'authority': 'Python Institute', 'category': 'programming'},
                    'Certified ScrumMaster (CSM)': {'level': 'intermediate', 'authority': 'Scrum Alliance', 'category': 'agile'},
                    'Certified Scrum Product Owner (CSPO)': {'level': 'intermediate', 'authority': 'Scrum Alliance', 'category': 'agile'},
                    'Professional Scrum Master (PSM)': {'level': 'intermediate', 'authority': 'Scrum.org', 'category': 'agile'},
                    'Certified Kubernetes Administrator (CKA)': {'level': 'professional', 'authority': 'CNCF', 'category': 'devops'},
                    'Certified Kubernetes Application Developer (CKAD)': {'level': 'associate', 'authority': 'CNCF', 'category': 'devops'},
                },
                'keywords': ['java', 'python', 'scrum', 'agile', 'kubernetes', 'devops'],
                'confidence': 0.8
            },
            # Security
            'security': {
                'certifications': {
                    'Certified Information Systems Security Professional (CISSP)': {'level': 'professional', 'authority': 'ISC²', 'category': 'security'},
                    'Certified Ethical Hacker (CEH)': {'level': 'intermediate', 'authority': 'EC-Council', 'category': 'security'},
                    'Certified Information Security Manager (CISM)': {'level': 'professional', 'authority': 'ISACA', 'category': 'security'},
                    'Certified Information Systems Auditor (CISA)': {'level': 'professional', 'authority': 'ISACA', 'category': 'security'},
                    'GIAC Certifications': {'level': 'intermediate', 'authority': 'GIAC', 'category': 'security'},
                    'Offensive Security Certified Professional (OSCP)': {'level': 'professional', 'authority': 'Offensive Security', 'category': 'security'},
                },
                'keywords': ['security', 'cissp', 'cism', 'cisa', 'ceh', 'gisc'],
                'confidence': 0.85
            },
            # Project Management
            'project_management': {
                'certifications': {
                    'Project Management Professional (PMP)': {'level': 'professional', 'authority': 'PMI', 'category': 'project_management'},
                    'Certified Associate in Project Management (CAPM)': {'level': 'associate', 'authority': 'PMI', 'category': 'project_management'},
                    'PRINCE2 Foundation': {'level': 'foundation', 'authority': 'AXELOS', 'category': 'project_management'},
                    'PRINCE2 Practitioner': {'level': 'practitioner', 'authority': 'AXELOS', 'category': 'project_management'},
                    'Agile Certified Practitioner (PMI-ACP)': {'level': 'professional', 'authority': 'PMI', 'category': 'agile'},
                },
                'keywords': ['pmp', 'capm', 'prince2', 'project management'],
                'confidence': 0.85
            }
        }
        
        # Certification level hierarchy
        self.level_hierarchy = {
            'entry': 1,
            'foundation': 2,
            'associate': 3,
            'intermediate': 4,
            'professional': 5,
            'practitioner': 5,
            'expert': 6,
            'master': 7,
            'specialty': 4
        }
        
        # Common certification patterns
        self.certification_patterns = [
            r'(?i)certified\s+([^.]+)',
            r'(?i)certificate\s+in\s+([^.]+)',
            r'(?i)certification\s+in\s+([^.]+)',
            r'(?i)(?:aws|azure|gcp|google|microsoft|oracle|cisco|comptia)\s+certified\s+([^.]+)',
            r'(?i)(?:pmp|capm|prince2|cissp|cisa|cism|ceh)\s+([^.]*)',
            r'(?i)(?:ccna|ccnp|ccie|cka|ckad)\s+([^.]*)',
        ]
        
        # Date patterns for certification dates
        self.date_patterns = [
            r'(?:issued|earned|completed|obtained)\s+(?:in\s+)?((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4})',
            r'(?:issued|earned|completed|obtained)\s+(?:in\s+)?(\d{1,2}/\d{4})',
            r'(\d{4})',
        ]
        
        # Expiration patterns
        self.expiration_patterns = [
            r'(?:expires|valid until|valid thru)\s+((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4})',
            r'(?:expires|valid until|valid thru)\s+(\d{1,2}/\d{4})',
        ]
    
    def detect_certifications(self, text: str, context_data: Dict[str, Any] = None) -> List[Dict[str, Any]]:
        """
        Detect certifications from text with comprehensive analysis.
        
        Args:
            text: CV text to analyze
            context_data: Additional context from other extraction methods
            
        Returns:
            List of enhanced certification objects with authority and level
        """
        if not text or not isinstance(text, str):
            return []
        
        detected_certifications = []
        
        # 1. Database matching
        database_matches = self._match_against_database(text)
        detected_certifications.extend(database_matches)
        
        # 2. Pattern-based detection
        pattern_matches = self._extract_from_patterns(text)
        detected_certifications.extend(pattern_matches)
        
        # 3. Context-based detection
        if context_data:
            context_matches = self._extract_from_context(text, context_data)
            detected_certifications.extend(context_matches)
        
        # 4. Education-based certification inference
        education_matches = self._infer_from_education(text, context_data)
        detected_certifications.extend(education_matches)
        
        # 5. Deduplicate and enhance
        enhanced_certifications = self._enhance_and_deduplicate(detected_certifications, text)
        
        # 6. Sort by relevance and authority
        sorted_certifications = sorted(
            enhanced_certifications,
            key=lambda x: (x.get('authority_confidence', 0), x.get('level_score', 0), x.get('confidence', 0)),
            reverse=True
        )
        
        return sorted_certifications[:20]  # Return top 20 certifications
    
    def _match_against_database(self, text: str) -> List[Dict[str, Any]]:
        """Match certifications against the comprehensive database."""
        matches = []
        text_lower = text.lower()
        
        for provider, provider_data in self.certification_database.items():
            # Check if provider keywords are present
            provider_present = any(keyword.lower() in text_lower for keyword in provider_data['keywords'])
            
            for cert_name, cert_info in provider_data['certifications'].items():
                cert_lower = cert_name.lower()
                
                # Check for exact or partial matches
                if cert_lower in text_lower:
                    confidence = self._calculate_certification_confidence(cert_name, text, provider_data)
                    
                    # Extract additional information
                    issue_date = self._extract_certification_date(cert_name, text)
                    expiration_date = self._extract_expiration_date(cert_name, text)
                    
                    matches.append({
                        'name': cert_name,
                        'authority': cert_info['authority'],
                        'level': cert_info['level'],
                        'category': cert_info['category'],
                        'confidence': confidence,
                        'authority_confidence': provider_data['confidence'],
                        'level_score': self.level_hierarchy.get(cert_info['level'], 3),
                        'issue_date': issue_date,
                        'expiration_date': expiration_date,
                        'detection_method': 'database_match',
                        'context_snippet': self._get_certification_context(cert_name, text)
                    })
        
        return matches
    
    def _extract_from_patterns(self, text: str) -> List[Dict[str, Any]]:
        """Extract certifications using pattern matching."""
        matches = []
        
        for pattern in self.certification_patterns:
            pattern_matches = re.finditer(pattern, text)
            
            for match in pattern_matches:
                cert_text = match.group(1) if match.groups() else match.group(0)
                
                # Try to match against database
                cert_info = self._find_certification_info(cert_text)
                
                if cert_info:
                    matches.append({
                        'name': cert_info['name'],
                        'authority': cert_info['authority'],
                        'level': cert_info['level'],
                        'category': cert_info['category'],
                        'confidence': 0.7,
                        'authority_confidence': 0.6,
                        'level_score': self.level_hierarchy.get(cert_info['level'], 3),
                        'detection_method': 'pattern_match',
                        'context_snippet': match.group(0)
                    })
                else:
                    # Generic certification
                    matches.append({
                        'name': cert_text.strip(),
                        'authority': 'Unknown',
                        'level': 'intermediate',
                        'category': 'other',
                        'confidence': 0.5,
                        'authority_confidence': 0.3,
                        'level_score': 3,
                        'detection_method': 'pattern_match',
                        'context_snippet': match.group(0)
                    })
        
        return matches
    
    def _extract_from_context(self, text: str, context_data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Extract certifications from contextual data."""
        matches = []
        
        # Check education section for certifications
        if 'structured_data' in context_data:
            structured = context_data['structured_data']
            if isinstance(structured, dict):
                education_data = structured.get('education', [])
                for edu in education_data:
                    if isinstance(edu, dict):
                        # Look for certifications in education descriptions
                        description = edu.get('description', '')
                        if description:
                            cert_matches = self._detect_certifications(description)
                            matches.extend(cert_matches)
        
        return matches
    
    def _infer_from_education(self, text: str, context_data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Infer certifications from education information."""
        matches = []
        
        # Look for degree-related certifications
        degree_patterns = [
            r'(?:bachelor|master|phd|doctorate)[^.]*certified',
            r'(?:computer science|data science|information technology)[^.]*certification'
        ]
        
        for pattern in degree_patterns:
            pattern_matches = re.finditer(pattern, text, re.IGNORECASE)
            
            for match in pattern_matches:
                matches.append({
                    'name': 'Academic Certification',
                    'authority': 'Educational Institution',
                    'level': 'intermediate',
                    'category': 'academic',
                    'confidence': 0.4,
                    'authority_confidence': 0.3,
                    'level_score': 3,
                    'detection_method': 'education_inference',
                    'context_snippet': match.group(0)
                })
        
        return matches
    
    def _calculate_certification_confidence(self, cert_name: str, text: str, provider_data: Dict[str, Any]) -> float:
        """Calculate confidence score for certification detection."""
        base_confidence = provider_data['confidence']
        
        # Boost confidence if certification appears in dedicated section
        if re.search(r'certifications?:?\s*([^\n]+)', text, re.IGNORECASE):
            cert_section_match = re.search(r'certifications?:?\s*([^\n]+)', text, re.IGNORECASE)
            if cert_section_match and cert_name.lower() in cert_section_match.group(1).lower():
                base_confidence += 0.1
        
        # Boost confidence if full certification name is present
        if cert_name.lower() in text.lower():
            base_confidence += 0.05
        
        # Boost confidence if authority is mentioned nearby
        authority = provider_data.get('keywords', [''])[0]
        if authority and authority.lower() in text.lower():
            # Check if authority is close to certification
            cert_context = self._get_certification_context(cert_name, text, 100)
            if authority.lower() in cert_context.lower():
                base_confidence += 0.05
        
        return min(base_confidence, 1.0)
    
    def _find_certification_info(self, cert_text: str) -> Optional[Dict[str, Any]]:
        """Find certification information from partial text."""
        cert_lower = cert_text.lower().strip()
        
        # Search through database
        for provider, provider_data in self.certification_database.items():
            for cert_name, cert_info in provider_data['certifications'].items():
                cert_name_lower = cert_name.lower()
                
                # Check for partial matches
                if (cert_lower in cert_name_lower or 
                    cert_name_lower in cert_lower or
                    any(word in cert_lower for word in cert_name_lower.split())):
                    return {
                        'name': cert_name,
                        'authority': cert_info['authority'],
                        'level': cert_info['level'],
                        'category': cert_info['category']
                    }
        
        return None
    
    def _extract_certification_date(self, cert_name: str, text: str) -> Optional[str]:
        """Extract certification issue date."""
        # Look for date patterns near certification mention
        cert_context = self._get_certification_context(cert_name, text, 150)
        
        for pattern in self.date_patterns:
            match = re.search(pattern, cert_context)
            if match:
                return self._normalize_certification_date(match.group(1))
        
        return None
    
    def _extract_expiration_date(self, cert_name: str, text: str) -> Optional[str]:
        """Extract certification expiration date."""
        cert_context = self._get_certification_context(cert_name, text, 150)
        
        for pattern in self.expiration_patterns:
            match = re.search(pattern, cert_context)
            if match:
                return self._normalize_certification_date(match.group(1))
        
        return None
    
    def _normalize_certification_date(self, date_str: str) -> str:
        """Normalize certification date to standard format."""
        if not date_str:
            return ''
        
        date_str = date_str.strip()
        
        # Handle month year format
        month_year_match = re.match(r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{4})', date_str, re.IGNORECASE)
        if month_year_match:
            month, year = month_year_match.groups()
            months = {'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
                     'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12}
            month_num = months.get(month[:3].lower(), 1)
            return f"{year}-{month_num:02d}"
        
        # Handle MM/YYYY format
        mm_yyyy_match = re.match(r'(\d{1,2})/(\d{4})', date_str)
        if mm_yyyy_match:
            month, year = mm_yyyy_match.groups()
            return f"{year}-{month.zfill(2)}"
        
        # Handle year only
        year_match = re.match(r'(\d{4})', date_str)
        if year_match:
            return year_match.group(1)
        
        return date_str
    
    def _get_certification_context(self, cert_name: str, text: str, context_length: int = 100) -> str:
        """Get context around certification mention."""
        cert_pattern = re.compile(rf'{re.escape(cert_name)}', re.IGNORECASE)
        match = cert_pattern.search(text)
        
        if match:
            start = max(0, match.start() - context_length)
            end = min(len(text), match.end() + context_length)
            return text[start:end].strip()
        
        return ''
    
    def _enhance_and_deduplicate(self, certifications: List[Dict[str, Any]], text: str) -> List[Dict[str, Any]]:
        """Enhance certifications and remove duplicates."""
        cert_map = {}
        
        for cert in certifications:
            name = cert.get('name', '').lower().strip()
            if not name:
                continue
            
            existing = cert_map.get(name)
            if existing:
                # Keep the one with higher confidence
                if cert.get('confidence', 0) > existing.get('confidence', 0):
                    cert_map[name] = cert
            else:
                cert_map[name] = cert
        
        # Calculate final scores
        enhanced_certs = []
        for cert in cert_map.values():
            # Calculate overall relevance score
            authority_weight = 0.4
            level_weight = 0.3
            confidence_weight = 0.3
            
            overall_score = (
                cert.get('authority_confidence', 0) * authority_weight +
                (cert.get('level_score', 3) / 7) * level_weight +  # Normalize level score
                cert.get('confidence', 0) * confidence_weight
            )
            
            cert['overall_score'] = overall_score
            enhanced_certs.append(cert)
        
        return enhanced_certs
    
    def verify_authority(self, certification: Dict[str, Any]) -> Dict[str, Any]:
        """Verify certification authority and provide additional metadata."""
        authority = certification.get('authority', '').lower()
        
        # Known authorities with verification status
        verified_authorities = {
            'amazon web services': {'verified': True, 'verification_url': 'https://aws.amazon.com/verification/'},
            'microsoft': {'verified': True, 'verification_url': 'https://www.microsoft.com/learning/verify.aspx'},
            'google cloud': {'verified': True, 'verification_url': 'https://cloud.google.com/certification'},
            'comptia': {'verified': True, 'verification_url': 'https://certification.comptia.org/verify'},
            'cisco': {'verified': True, 'verification_url': 'https://www.cisco.com/go/verify'},
            'oracle': {'verified': True, 'verification_url': 'https://education.oracle.com/verification/'},
            'isc²': {'verified': True, 'verification_url': 'https://www.isc2.org/verify-certification/'},
            'pmi': {'verified': True, 'verification_url': 'https://www.pmi.org/registry'},
            'isaca': {'verified': True, 'verification_url': 'https://www.isaca.org/credential/verify'},
        }
        
        verification_info = verified_authorities.get(authority, {'verified': False})
        
        certification['verification'] = verification_info
        return certification
