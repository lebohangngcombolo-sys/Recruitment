"""
Autofill Mapper Service
Converts extracted CV data to autofill format for recruitment app integration.
"""

import re
from typing import List, Dict, Any, Optional
from datetime import datetime

from app.schemas.autofill_schema import AutofillData, PersonalInfo, EducationInfo, ExperienceInfo
from app.services.enhanced_skills_extractor import EnhancedSkillsExtractor
from app.services.advanced_experience_parser import AdvancedExperienceParser
from app.services.comprehensive_certification_detector import ComprehensiveCertificationDetector


class AutofillMapper:
    """Maps extracted CV data to autofill format for recruitment app."""
    
    def __init__(self):
        # Initialize enhanced extraction services
        self.skills_extractor = EnhancedSkillsExtractor()
        self.experience_parser = AdvancedExperienceParser()
        self.certification_detector = ComprehensiveCertificationDetector()
        
        # Legacy skills library for backward compatibility
        self.skills_library = {
            'programming': [
                'python', 'java', 'javascript', 'typescript', 'c++', 'c#', 'go', 'rust',
                'php', 'ruby', 'swift', 'kotlin', 'scala', 'perl', 'r', 'matlab'
            ],
            'web_development': [
                'html', 'css', 'react', 'vue', 'angular', 'node.js', 'express', 'django',
                'flask', 'fastapi', 'spring', 'laravel', 'rails', 'next.js', 'gatsby'
            ],
            'databases': [
                'sql', 'mysql', 'postgresql', 'mongodb', 'redis', 'elasticsearch',
                'oracle', 'sql server', 'sqlite', 'cassandra', 'dynamodb'
            ],
            'cloud_devops': [
                'aws', 'azure', 'google cloud', 'gcp', 'docker', 'kubernetes', 'jenkins',
                'gitlab ci', 'github actions', 'terraform', 'ansible', 'puppet', 'chef'
            ],
            'data_science': [
                'pandas', 'numpy', 'scikit-learn', 'tensorflow', 'pytorch', 'keras',
                'jupyter', 'spark', 'hadoop', 'tableau', 'power bi', 'excel', 'sas'
            ],
            'mobile': [
                'ios', 'android', 'react native', 'flutter', 'swift', 'kotlin',
                'xamarin', 'cordova', 'ionic'
            ],
            'tools': [
                'git', 'svn', 'jira', 'confluence', 'slack', 'trello', 'asana',
                'vs code', 'intellij', 'eclipse', 'vim', 'emacs'
            ]
        }
        
        # Common certification keywords
        self.certification_keywords = [
            'certified', 'certificate', 'certification', 'specialty', 'associate',
            'professional', 'expert', 'master', 'architect', 'engineer', 'developer'
        ]
    
    def map_to_autofill(self, extracted_data: Dict[str, Any]) -> AutofillData:
        """
        Convert extracted CV data to autofill format.
        
        Args:
            extracted_data: Raw extracted data from NER and parsing
            
        Returns:
            AutofillData object ready for recruitment app
        """
        autofill = AutofillData()
        
        # Ensure raw_text is available for enhanced extraction
        if 'raw_text' not in extracted_data:
            # Try to extract raw text from various sources
            raw_text = ''
            if 'cv_text' in extracted_data:
                raw_text = extracted_data['cv_text']
            elif 'text' in extracted_data:
                raw_text = extracted_data['text']
            extracted_data['raw_text'] = raw_text
        
        # Map personal information
        autofill.personal = self._map_personal_info(extracted_data)
        
        # Map education
        autofill.education = self._map_education(extracted_data)
        
        # Map and enhance skills
        autofill.skills = self._map_skills(extracted_data)
        
        # Map experience
        autofill.experience = self._map_experience(extracted_data)
        
        # Map certifications
        autofill.certifications = self._map_certifications(extracted_data)
        
        # Map languages
        autofill.languages = self._map_languages(extracted_data)
        
        return autofill
    
    def _map_personal_info(self, data: Dict[str, Any]) -> PersonalInfo:
        """Map personal information from extracted data."""
        personal = PersonalInfo()
        
        # 🔥 FIX: Use structured_data as primary source
        structured_data = data.get('structured_data', {})
        if isinstance(structured_data, dict):
            personal_details = structured_data.get('personal_details', {})
            if isinstance(personal_details, dict):
                personal.full_name = personal_details.get('full_name')
                personal.email = personal_details.get('email')
                personal.phone = personal_details.get('phone')
                personal.linkedin = personal_details.get('linkedin')
                personal.github = personal_details.get('github')
                personal.portfolio = personal_details.get('portfolio')
                personal.address = personal_details.get('address')
                personal.dob = personal_details.get('dob')
                personal.gender = personal_details.get('gender')
        
        # 🔥 ENHANCED FALLBACK: Try multiple sources for missing fields
        # Source 1: entities.personal_details
        entities = data.get('entities', {})
        if isinstance(entities, dict):
            entity_personal = entities.get('personal_details', {})
            if isinstance(entity_personal, dict):
                if not personal.full_name:
                    personal.full_name = entity_personal.get('full_name')
                if not personal.email:
                    personal.email = entity_personal.get('email')
                if not personal.phone:
                    personal.phone = entity_personal.get('phone')
                if not personal.linkedin:
                    personal.linkedin = entity_personal.get('linkedin')
                if not personal.github:
                    personal.github = entity_personal.get('github')
                if not personal.portfolio:
                    personal.portfolio = entity_personal.get('portfolio')
                if not personal.address:
                    personal.address = entity_personal.get('address')
                if not personal.dob:
                    personal.dob = entity_personal.get('dob')
                if not personal.gender:
                    personal.gender = entity_personal.get('gender')
        
        # Source 2: raw_entities (from NER pipeline)
        raw_entities = data.get('raw_entities', {})
        if isinstance(raw_entities, dict):
            if not personal.full_name:
                names = raw_entities.get('names', [])
                if names and len(names) > 0:
                    personal.full_name = names[0]
        
        # Source 3: Extract from raw text using patterns
        raw_text = data.get('raw_text', '') or data.get('text', '') or data.get('cv_text', '')
        if raw_text:
            if not personal.full_name:
                personal.full_name = self._extract_full_name_from_text(raw_text)
            if not personal.gender:
                personal.gender = self._extract_gender_from_text(raw_text)
            if not personal.dob:
                personal.dob = self._extract_dob_from_text(raw_text)
            if not personal.linkedin:
                personal.linkedin = self._extract_linkedin_from_text(raw_text)
            if not personal.github:
                personal.github = self._extract_github_from_text(raw_text)
            if not personal.portfolio:
                personal.portfolio = self._extract_portfolio_from_text(raw_text)
        
        # Source 4: Extract address from text
        if not personal.address:
            address = self._extract_address(data)
            if address:
                personal.address = address
        
        # Source 5: Extract email and phone if still missing
        if raw_text:
            if not personal.email:
                email_match = re.search(r'[\w\.-]+@[\w\.-]+\.\w+', raw_text)
                if email_match:
                    personal.email = email_match.group(0)
            if not personal.phone:
                phone_match = re.search(r'(\+?\d[\d\s-]{8,}\d)', raw_text)
                if phone_match:
                    personal.phone = phone_match.group(0)

        # Normalize phone number format
        if personal.phone:
            personal.phone = self._normalize_phone(personal.phone)
        
        # Normalize URLs
        if personal.linkedin:
            personal.linkedin = self._normalize_url(personal.linkedin)
        if personal.github:
            personal.github = self._normalize_url(personal.github)
        if personal.portfolio:
            personal.portfolio = self._normalize_url(personal.portfolio)
        
        return personal
    
    def _map_education(self, data: Dict[str, Any]) -> List[EducationInfo]:
        """Map education information."""
        education_list = []
        
        # Get education from different possible locations
        education_data = []
        
        # DEBUG data keys
        print(f"DEBUG MAPPER: data keys: {list(data.keys())}")
        
        # From structured_data.education
        structured_data = data.get('structured_data', {})
        if isinstance(structured_data, dict):
            education_data.extend(structured_data.get('education', []))
        
        # From education_details.education
        education_details = data.get('education_details', {})
        if isinstance(education_details, dict):
            education_data.extend(education_details.get('education', []))
        
        # From raw entities
        entities = data.get('entities', {})
        if isinstance(entities, dict):
            edu_details = entities.get('education_details', {})
            if isinstance(edu_details, dict):
                education_data.extend(edu_details.get('education', []))
        
        print(f"DEBUG: education_data count: {len(education_data)}")
        for edu in education_data:
            if not isinstance(edu, dict):
                continue
            
            education_info = EducationInfo()
            
            # Map degree and institution
            degree = edu.get('degree') or edu.get('qualification')
            institution = edu.get('institution') or edu.get('university') or edu.get('school')
            field = edu.get('field') or edu.get('specialization')

            # 🛡️ FIELD EXTRACTION FIX: If field is empty, try to extract it from the degree/institution string first
            # (before we split them and potentially lose the "in [Field]" part)
            if not field:
                combined_text = degree or institution
                if combined_text:
                    new_degree, extracted_field = self._extract_field_from_degree(combined_text)
                    print(f"DEBUG: _extract_field_from_degree('{combined_text}') -> '{new_degree}', '{extracted_field}'")
                    if extracted_field:
                        field = extracted_field
                        if degree:
                            degree = new_degree
                        elif institution:
                            institution = new_degree

            # Try to separate degree and institution if they're combined
            if degree and not institution:
                old_degree = degree
                degree, institution = self._split_degree_institution(degree)
                print(f"DEBUG: _split_degree_institution('{old_degree}') -> '{degree}', '{institution}'")
            elif institution and not degree:
                old_inst = institution
                degree, institution = self._split_degree_institution(institution)
                print(f"DEBUG: _split_degree_institution('{old_inst}') -> '{degree}', '{institution}'")
            
            print(f"DEBUG FINAL MAPPING: {degree=}, {institution=}, {field=}")
            education_info.degree = degree
            education_info.university = institution
            education_info.field = field
            
            # Extract year from date fields
            year = self._extract_year(edu.get('end_date') or edu.get('start_date') or edu.get('date'))
            education_info.year = year
            
            if education_info.degree or education_info.university:
                education_list.append(education_info)
        
        return education_list
    
    def _map_skills(self, data: Dict[str, Any]) -> List[str]:
        """
        Enhanced skills mapping using the advanced skills extractor.
        
        Args:
            data: Raw extracted data from NER and parsing
            
        Returns:
            Enhanced list of skills with confidence scoring
        """
        # Get raw text for enhanced extraction
        raw_text = data.get('raw_text', '')
        
        # Use enhanced skills extractor
        enhanced_skills = self.skills_extractor.extract_skills(raw_text, data)
        
        # Convert to simple list for compatibility
        skill_names = []
        for skill in enhanced_skills:
            if isinstance(skill, dict):
                skill_name = skill.get('name', '')
                if skill_name:
                    skill_names.append(skill_name)
            elif isinstance(skill, str):
                skill_names.append(skill)
        
        # Remove duplicates while preserving order
        seen = set()
        unique_skills = []
        for skill in skill_names:
            skill_lower = skill.lower().strip()
            if skill_lower and skill_lower not in seen:
                seen.add(skill_lower)
                unique_skills.append(skill)
        
        return unique_skills[:50]  # Return top 50 skills
    
    def _process_skill(self, skill: str, data: Dict[str, Any]) -> List[str]:
        """
        Process a single skill with context awareness and enhancement.
        
        Args:
            skill: Raw skill string
            data: Full extracted data for context
            
        Returns:
            List of enhanced skill variations
        """
        enhanced_skills = []
        
        # Basic skill normalization
        base_skill = skill.lower().strip()
        if not base_skill:
            return enhanced_skills
        
        # Check against skills library for categorization
        for category, category_skills in self.skills_library.items():
            if base_skill in [s.lower() for s in category_skills]:
                # Add category context
                enhanced_skills.append({
                    'name': base_skill,
                    'category': category,
                    'relevance_score': 0.8,  # High relevance for library match
                    'confidence': 0.9
                })
                break
        
        # If not in library, still include with lower relevance
        if not enhanced_skills:
            enhanced_skills.append({
                'name': base_skill,
                'category': 'other',
                'relevance_score': 0.5,
                'confidence': 0.7
            })
        
        return enhanced_skills
    
    def _deduplicate_skills(self, skills: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Remove duplicate skills while preserving highest confidence and relevance.
        
        Args:
            skills: List of skill dictionaries with name, confidence, relevance_score
            
        Returns:
            Deduplicated list of skills
        """
        skill_map = {}
        
        for skill in skills:
            name = skill.get('name', '').lower().strip()
            if not name:
                continue
                
            existing = skill_map.get(name)
            if existing:
                # Keep the one with higher confidence and relevance
                existing_conf = existing.get('confidence', 0)
                existing_rel = existing.get('relevance_score', 0)
                new_conf = skill.get('confidence', 0)
                new_rel = skill.get('relevance_score', 0)
                
                if new_conf > existing_conf or (new_conf == existing_conf and new_rel > existing_rel):
                    skill_map[name] = skill
            else:
                skill_map[name] = skill
        
        return list(skill_map.values())
    
    def _sort_skills_by_relevance(self, skills: List[Dict[str, Any]]) -> List[str]:
        """
        Sort skills by relevance score and confidence, then by commonality.
        
        Args:
            skills: List of skill dictionaries
            
        Returns:
            Sorted list of skill names
        """
        # Sort by relevance_score (descending), then confidence (descending)
        sorted_skills = sorted(
            skills,
            key=lambda x: (x.get('relevance_score', 0), x.get('confidence', 0)),
            reverse=True
        )
        
        # Return just the skill names for compatibility
        return [skill.get('name', '') for skill in sorted_skills]
    
    def _map_experience(self, data: Dict[str, Any]) -> List[ExperienceInfo]:
        """
        Map work experience using structured data as primary source, with advanced parser as fallback.
        """
        experience_list = []
        seen_entries = set() # For deduplication: (title, company)
        from app.services.fallback_parsers import validate_experience_entry
        
        # Helper to normalize for deduplication
        def _norm_key(title, company):
            t = str(title or "").lower().strip()
            c = str(company or "").lower().strip()
            # Basic fuzzy match: remove common suffixes for comparison
            c = re.sub(r'\b(inc|ltd|llc|corp|group)\b', '', c).strip()
            return (t, c)

        # 🟢 STEP 1: Use the cleaned structured_data
        structured_data = data.get('structured_data', {})
        if isinstance(structured_data, dict):
            raw_experience = structured_data.get('experience', []) or structured_data.get('work_experience', [])
            if isinstance(raw_experience, list) and raw_experience:
                for exp in raw_experience:
                    if not isinstance(exp, dict):
                        continue
                        
                    # 🛡️ VALIDATION GATE: Filter out noisy LLM output
                    if not validate_experience_entry(exp):
                        continue
                        
                    title = exp.get('title')
                    company = exp.get('company')
                    key = _norm_key(title, company)
                    
                    if key in seen_entries:
                        continue
                    seen_entries.add(key)
                        
                    exp_info = ExperienceInfo()
                    exp_info.title = title
                    exp_info.company = company
                    
                    # Format period from start/end dates
                    start = exp.get('start_date') or exp.get('from')
                    end = exp.get('end_date') or exp.get('to') or 'Present'
                    if start:
                        exp_info.period = f"{start} - {end}"
                    elif exp.get('period'):
                        exp_info.period = exp.get('period')
                        
                    exp_info.description = exp.get('description')
                    exp_info.location = exp.get('location')
                    
                    if exp_info.title or exp_info.company:
                        experience_list.append(exp_info)
        
        # 🟡 STEP 2: Use advanced parser if structured data is empty or sparse
        # We also check if the existing experience_list is too short
        if len(experience_list) < 3:
            raw_text = data.get('raw_text', '') or data.get('text', '') or data.get('cv_text', '')
            parsed_experiences = []
            if raw_text:
                parsed_experiences = self.experience_parser.parse_experience_from_text(raw_text)
            
            for exp in parsed_experiences:
                # 🛡️ SAFETY GATE: Run rogue results through the Scrubber
                if not validate_experience_entry(exp):
                    continue
                
                title = exp.get('title', '')
                company = exp.get('company', '')
                key = _norm_key(title, company)
                
                if key in seen_entries:
                    continue
                seen_entries.add(key)
                    
                exp_info = ExperienceInfo()
                exp_info.title = title
                exp_info.company = company
                
                start_date = exp.get('start_date', '')
                end_date = exp.get('end_date', '')
                if start_date and end_date:
                    exp_info.period = f"{start_date} - {end_date}"
                elif start_date:
                    exp_info.period = f"{start_date} - Present"
                
                exp_info.description = exp.get('description', '')
                exp_info.location = exp.get('location', '')
                
                if exp_info.title or exp_info.company:
                    experience_list.append(exp_info)
        
        return experience_list[:10]
    
    def _extract_job_title(self, exp: Dict[str, Any]) -> str:
        """Extract job title with advanced pattern matching."""
        # Implementation for job title extraction
        return exp.get('title', '').strip()
    
    def _extract_company(self, exp: Dict[str, Any]) -> str:
        """Extract company name with fuzzy matching."""
        # Implementation for company extraction
        return exp.get('company', '').strip()
    
    def _parse_experience_dates(self, exp: Dict[str, Any]) -> tuple:
        """Parse dates with multiple format support."""
        start_date = exp.get('start_date')
        end_date = exp.get('end_date')
        return start_date, end_date
    
    def _parse_experience_from_text(self, text: str) -> List[Dict[str, Any]]:
        """Parse experience entries from raw text."""
        # Implementation for text parsing
        return []
    
    def _map_certifications(self, data: Dict[str, Any]) -> List[str]:
        """
        Enhanced certification mapping using the comprehensive certification detector.
        
        Args:
            data: Raw extracted data from NER and parsing
            
        Returns:
            List of enhanced certification information
        """
        # Get raw text for comprehensive detection
        raw_text = data.get('raw_text', '')
        
        # Use comprehensive certification detector
        detected_certifications = self.certification_detector.detect_certifications(raw_text, data)
        
        # Convert to simple list for compatibility
        cert_names = []
        for cert in detected_certifications:
            if isinstance(cert, dict):
                cert_name = cert.get('name', '')
                if cert_name:
                    cert_names.append(cert_name)
            elif isinstance(cert, str):
                cert_names.append(cert)
        
        # Remove duplicates while preserving order
        seen = set()
        unique_certs = []
        for cert in cert_names:
            cert_lower = cert.lower().strip()
            if cert_lower and cert_lower not in seen:
                seen.add(cert_lower)
                unique_certs.append(cert)
        
        return unique_certs[:20]  # Return top 20 certifications
    
    def _enhance_certification(self, cert: str) -> str:
        """Enhance certification with authority verification."""
        return cert.strip()
    
    def _parse_certifications_from_text(self, text: str) -> List[str]:
        """Parse certifications from raw text using patterns."""
        return []
    
    def _deduplicate_certifications(self, certifications: List[str]) -> List[str]:
        """Remove duplicate certifications."""
        seen = set()
        unique_certs = []
        for cert in certifications:
            cert_lower = cert.lower().strip()
            if cert_lower and cert_lower not in seen:
                seen.add(cert_lower)
                unique_certs.append(cert)
        return unique_certs
    
    def _sort_certifications_by_relevance(self, certifications: List[str]) -> List[str]:
        """Sort certifications by relevance and authority."""
        # Simple sorting by length (longer names often more specific)
        return sorted(certifications, key=len, reverse=True)
    
    def _map_languages(self, data: Dict[str, Any]) -> List[str]:
        """Map languages from extracted data with comprehensive detection."""
        languages = []
        
        # From structured_data (primary source)
        structured_data = data.get('structured_data', {})
        if isinstance(structured_data, dict):
            langs = structured_data.get('languages', [])
            if isinstance(langs, list):
                languages.extend([str(lang).strip() for lang in langs if lang])
        
        # From raw data languages field
        if 'languages' in data:
            langs = data['languages']
            if isinstance(langs, list):
                languages.extend([str(lang).strip() for lang in langs if lang])
        
        # 🔥 ENHANCED: Extract from raw text if still empty
        if not languages:
            raw_text = data.get('raw_text', '') or data.get('text', '') or data.get('cv_text', '')
            if raw_text:
                text_langs = self._extract_languages_from_text(raw_text)
                languages.extend(text_langs)
        
        # Remove duplicates while preserving order
        seen = set()
        unique_langs = []
        for lang in languages:
            lang_lower = lang.lower()
            if lang_lower and lang_lower not in seen:
                seen.add(lang_lower)
                unique_langs.append(lang)
        
        return unique_langs[:10]  # Return top 10 languages
    
    def _extract_address(self, data: Dict[str, Any]) -> Optional[str]:
        """Extract address from data using patterns."""
        text_content = self._get_full_text(data)
        
        # Common address patterns
        address_patterns = [
            r'[\w\s]+,\s*[\w\s]+,\s*[A-Z]{2}\s*\d{5}',
            r'[\w\s]+,\s*[\w\s]+,\s*[A-Za-z\s]+',
            r'📍\s*([^\n]+)',  # Location emoji pattern
        ]
        
        for pattern in address_patterns:
            matches = re.findall(pattern, text_content, re.IGNORECASE)
            if matches:
                return matches[0].strip()
        
        return None
    
    def _normalize_phone(self, phone: str) -> str:
        """Normalize phone number format."""
        if not phone:
            return phone
        
        # Remove all non-numeric characters except +
        cleaned = re.sub(r'[^\d+]', '', phone)
        
        # Add country code if missing (assuming South Africa)
        if not cleaned.startswith('+') and len(cleaned) == 10:
            cleaned = '+27' + cleaned[1:]
        
        return cleaned
    
    def _normalize_url(self, url: str) -> str:
        """Normalize URL format."""
        if not url:
            return url
        
        url = url.strip()
        
        # Add protocol if missing
        if not url.startswith(('http://', 'https://')):
            url = 'https://' + url
        
        return url
    
    def _split_degree_institution(self, text: str) -> tuple[str, str]:
        """Try to split combined degree and institution text."""
        if not text:
            return None, None
        
        # Don't split if the text is clearly just a field description (e.g. "Computer Science")
        # unless it looks like an institution name.
        field_keywords = {
            'science', 'engineering', 'arts', 'commerce', 'business', 'law', 'medicine',
            'technology', 'management', 'economics', 'accounting', 'finance', 'nursing'
        }
        words = set(text.lower().split())
        if words.intersection(field_keywords) and not any(kw in text.lower() for kw in ['university', 'college', 'school', 'institute']):
             # If it looks like a field but has no institution keyword, don't misidentify it as an institution
             return text, None

        # Common patterns
        patterns = [
            r'(.+?)\s+(?:at|in)\s+(.+)', # Preserve "from" for field extraction if it follows Bachelor/Master
            r'(.+?)\s+from\s+(?!science|arts|commerce|engineering|law|medicine)(.+)', # Split at from only if NOT followed by a field
            r'(.+?)\s*-\s*(.+)',
            r'(.+?)\s*,\s*(.+)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                degree, institution = match.groups()
                return degree.strip(), institution.strip()
        
        return text, None

    def _extract_field_from_degree(self, text: str) -> tuple[str, str]:
        """
        Extract field of study from a degree string.
        E.g. "Bachelor of Science in Data Science" -> ("Bachelor of Science", "Data Science")
        """
        if not text:
            return None, None
            
        patterns = [
            r'(.+?)\s+(?:in|of|from|major(?:ing)?\s+in|specializ(?:ing|ation)?\s+in)\s+(.+)',
            r'(.+?)\s+\((.+)\)', # Bachelor of Science (Computer Science)
            r'([A-Z][a-z\.]+)\s+(?:of|in|from)\s+(.+)', # B.Sc. in Data Science
        ]
        
        # Check for common degree prefixes to avoid greedy matching
        degree_prefixes = [
            'Bachelor', 'Master', 'Doctorate', 'B.Sc', 'BSc', 'M.Sc', 'MSc', 
            'B.A', 'BA', 'M.A', 'MA', 'Ph.D', 'PhD', 'Diploma', 'Certificate'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                deg_part, field_part = match.groups()
                
                # Verify deg_part contains a degree-like word
                if any(p.lower() in deg_part.lower() for p in degree_prefixes):
                    # 🛡️ HEURISTIC: If field_part contains an institution keyword, it might be combined.
                    # e.g. "Data Science University of Cape Town"
                    # We should only take the part BEFORE "University" as the field.
                    institution_keywords = [r'University', r'College', r'School', r'Institute', r'Academy']
                    for kw in institution_keywords:
                        inst_match = re.search(fr'(.+?)\s+(?:at|of|,)?\s*({kw}.+)', field_part, re.IGNORECASE)
                        if inst_match:
                            field_part = inst_match.group(1).strip()
                            break
                    
                    return deg_part.strip(), field_part.strip()
                    
        return text, None
    
    def _extract_year(self, date_str: Optional[str]) -> Optional[str]:
        """Extract year from date string."""
        if not date_str:
            return None
        
        year_match = re.search(r'\b(19|20)\d{2}\b', date_str)
        return year_match.group(0) if year_match else None
    
    def _format_period(self, start_date: Optional[str], end_date: Optional[str]) -> str:
        """Format employment period."""
        start_year = self._extract_year(start_date) if start_date else None
        end_year = self._extract_year(end_date) if end_date else "Present"
        
        if start_year and end_year:
            return f"{start_year} - {end_year}"
        elif start_year:
            return f"{start_year} - Present"
        elif end_year:
            return f"Until {end_year}"
        else:
            return ""
    
    def _get_full_text(self, data: Dict[str, Any]) -> str:
        """Get full text content from data for analysis."""
        text_parts = []
        
        # Add various text fields
        if 'raw_text' in data:
            text_parts.append(data['raw_text'])
        
        # Add professional summary
        structured_data = data.get('structured_data', {})
        if isinstance(structured_data, dict):
            summary = structured_data.get('professional_summary')
            if summary:
                text_parts.append(summary)
        
        # Add experience descriptions
        entities = data.get('entities', {})
        if isinstance(entities, dict):
            prof_details = entities.get('professional_details', {})
            if isinstance(prof_details, dict):
                experience = prof_details.get('experience', [])
                for exp in experience:
                    if isinstance(exp, dict):
                        desc = exp.get('description')
                        if desc:
                            text_parts.append(desc)
        
        return ' '.join(text_parts)
    
    def _extract_categorized_skills(self, text: str) -> List[str]:
        """Extract skills using categorized keyword matching."""
        found_skills = []
        text_lower = text.lower()
        
        for category, skills in self.skills_library.items():
            for skill in skills:
                # Check for exact skill match
                if skill in text_lower:
                    found_skills.append(skill)
                # Check for variations
                variations = self._get_skill_variations(skill)
                for variation in variations:
                    if variation in text_lower and skill not in found_skills:
                        found_skills.append(skill)
                        break
        
        return found_skills
    
    def _get_skill_variations(self, skill: str) -> List[str]:
        """Get common variations of skill names."""
        variations = {
            'node.js': ['nodejs', 'node js'],
            'react': ['reactjs', 'react js'],
            'vue': ['vuejs', 'vue js'],
            'angular': ['angularjs', 'angular js'],
            'aws': ['amazon web services', 'amazon'],
            'gcp': ['google cloud platform', 'google cloud'],
            'sql server': ['mssql', 'ms sql'],
            'c++': ['cpp'],
            'c#': ['csharp', 'c sharp'],
        }
        return variations.get(skill, [])
    
    def _sort_skills_by_relevance(self, skills: List[str]) -> List[str]:
        """Sort skills by relevance (common skills first)."""
        # Define priority categories
        high_priority = ['python', 'java', 'javascript', 'aws', 'docker', 'kubernetes', 'sql']
        medium_priority = ['react', 'node.js', 'angular', 'azure', 'gcp', 'git', 'linux']
        
        sorted_skills = []
        
        # Add high priority skills first
        for skill in high_priority:
            if skill in skills:
                sorted_skills.append(skill)
                skills.remove(skill)
        
        # Add medium priority skills
        for skill in medium_priority:
            if skill in skills:
                sorted_skills.append(skill)
                skills.remove(skill)
        
        # Add remaining skills alphabetically
        sorted_skills.extend(sorted(skills))
        
        return sorted_skills
    
    def _is_certification(self, text: str) -> bool:
        """Check if text looks like a certification."""
        text_lower = text.lower()
        return any(keyword in text_lower for keyword in self.certification_keywords)
    
    def _extract_full_name_from_text(self, text: str) -> Optional[str]:
        """Extract full name from CV text using patterns."""
        if not text:
            return None
        
        # Pattern 1: Name at the very beginning of CV (common format)
        lines = text.strip().split('\n')
        for i, line in enumerate(lines[:10]):  # Check first 10 lines
            line = line.strip()
            # Skip empty lines, contact info markers
            if not line or line.lower() in ['contact', 'personal', 'profile', 'summary']:
                continue
            # Look for 2-3 word names (First Last or First Middle Last)
            words = line.split()
            if 1 <= len(words) <= 4:
                # Check if it looks like a name (no special chars, reasonable length)
                # Allow all caps names like BOB MABENA
                cleaned = re.sub(r'[^\w\s-]', '', line)
                if cleaned and all(w[0].isupper() for w in cleaned.split() if w):
                    return cleaned.strip()
        
        return None
    
    def _extract_gender_from_text(self, text: str) -> Optional[str]:
        """Extract gender from CV text."""
        if not text:
            return None
        
        text_lower = text.lower()
        
        # Look for explicit gender mentions
        patterns = [
            (r'\bmale\b', 'Male'),
            (r'\bfemale\b', 'Female'),
            (r'\bgender:\s*(male|female)\b', None),  # Will capture group 1
            (r'\b(he/him|she/her|they/them)\b', None),
        ]
        
        for pattern, default in patterns:
            match = re.search(pattern, text_lower)
            if match:
                if default:
                    return default
                # If pattern has capture group, use that
                if match.groups():
                    gender = match.group(1).capitalize()
                    if gender in ['Male', 'Female']:
                        return gender
        
        return None
    
    def _extract_dob_from_text(self, text: str) -> Optional[str]:
        """Extract date of birth from CV text."""
        if not text:
            return None
        
        text_lower = text.lower()
        
        # Look for DOB patterns
        patterns = [
            r'(?:date of birth|dob|birth date|born)[:\s]*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
            r'(?:date of birth|dob|birth date|born)[:\s]*(\d{4}[/-]\d{1,2}[/-]\d{1,2})',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text_lower)
            if match:
                return match.group(1)
        
        return None
    
    def _extract_languages_from_text(self, text: str) -> List[str]:
        """Extract languages from CV text."""
        if not text:
            return []
        
        text_lower = text.lower()
        found_languages = []
        
        # Common languages to look for
        common_languages = [
            'english', 'afrikaans', 'zulu', 'xhosa', 'sotho', 'tswana', 'venda',
            'tsonga', 'swati', 'ndebele', 'pedi', 'french', 'german', 'spanish',
            'portuguese', 'italian', 'dutch', 'chinese', 'japanese', 'korean',
            'arabic', 'hindi', 'russian', 'swahili', 'shona'
        ]
        
        # Look for "languages" section
        lang_section_pattern = r'(?:languages?|language proficiency)[:\s]*([\s\S]{0,500})'
        match = re.search(lang_section_pattern, text_lower)
        
        if match:
            section = match.group(1)
            # Extract languages mentioned in the section
            for lang in common_languages:
                if lang in section:
                    found_languages.append(lang.title())
        
        # Also check entire text for language mentions with context
        for lang in common_languages:
            # Look for language with word boundaries
            if re.search(r'\b' + lang + r'\b', text_lower):
                if lang.title() not in found_languages:
                    found_languages.append(lang.title())
        
        return found_languages

    def _extract_linkedin_from_text(self, text: str) -> Optional[str]:
        """Extract LinkedIn profile URL from text."""
        patterns = [
            r'linkedin\.com/in/[\w-]+',
            r'linkedin\.com/pub/[\w-]+',
            r'\b(?:linkedin|li)[:\s]*([\w/-]+)',
        ]
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                url = match.group(0) if 'linkedin.com' in match.group(0) else f"linkedin.com/in/{match.group(1)}"
                return url
        return None

    def _extract_github_from_text(self, text: str) -> Optional[str]:
        """Extract GitHub profile URL from text."""
        patterns = [
            r'github\.com/[\w-]+',
            r'\b(?:github|gh)[:\s]*([\w/-]+)',
        ]
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                url = match.group(0) if 'github.com' in match.group(0) else f"github.com/{match.group(1)}"
                return url
        return None

    def _extract_portfolio_from_text(self, text: str) -> Optional[str]:
        """Extract portfolio URL from text."""
        patterns = [
            r'(?:portfolio|website|website/portfolio)[:\s]*([^\s,\|]+)',
            r'behance\.net/[\w-]+',
            r'dribbble\.com/[\w-]+',
        ]
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return match.group(1) if len(match.groups()) > 0 else match.group(0)
        return None
