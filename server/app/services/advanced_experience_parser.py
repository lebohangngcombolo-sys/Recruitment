"""
Advanced Experience Parser Service
Provides intelligent parsing of work experience with company recognition, title extraction, and date parsing.
"""

import re
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)


class AdvancedExperienceParser:
    """Advanced work experience parsing with NLP-enhanced extraction."""
    
    def __init__(self):
        # 🛡️ Blacklist of words that should never be a company or title (headers, noise)
        self.blacklist = {
            "professional experience", "work experience", "employment history", "experience",
            "work history", "career summary", "summary", "profile", "contact", "education",
            "skills", "certifications", "projects", "languages", "personal details", "references",
            "curriculum vitae", "resume", "page", "of", "the", "and", "details", "awards", 
            "hobbies", "interests", "aim", "objective", "profile summary"
        }

        # Curated job titles for scanning
        self.job_titles = [
            "Software Engineer", "Senior Software Engineer", "Frontend Developer", "Backend Developer", 
            "Full Stack Developer", "Data Scientist", "Data Analyst", "Project Manager", "Product Manager", 
            "UI/UX Designer", "DevOps Engineer", "Cloud Architect", "Systems Administrator", "QA Engineer", 
            "Mobile Developer", "Machine Learning Engineer", "Solutions Architect", "Data Engineer"
        ]
        
        # Company name patterns and indicators
        self.company_indicators = [
            r'\b(?:Inc|LLC|Ltd|Corp|Corporation|Company|Co|Group|Holdings|Solutions|Services|Technologies|Systems|Consulting|Partners)\b',
            r'\b(?:Pty|Ltd|Pty Ltd|Proprietary)\b',
            r'\b(?:GmbH|AG|SA|SAS|SRL|BV|NV|PLC|LLP|LP)\b'
        ]
        
        # Date patterns for various formats
        self.date_range_pattern = re.compile(
            r'((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|January|February|March|April|May|June|July|August|September|October|November|December|\d{1,2}/\d{4}|\d{4}))\s*(?:-|–|to|until|—|at)\s*((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|January|February|March|April|May|June|July|August|September|October|November|December|\d{1,2}/\d{4}|\d{4}|Present|Current|Now|Today))',
            re.IGNORECASE
        )
        
        # Location patterns
        self.location_patterns = [
            r'\b[A-Z][a-z]+,\s*[A-Z]{2}\b',  # City, State
            r'\b[A-Z][a-z]+,\s*[A-Z][a-z]+\b',  # City, Country
            r'\b(?:Remote|On-site|Hybrid|Virtual)\b',  # Work mode
        ]

    def parse_experience_from_text(self, text: str) -> List[Dict[str, Any]]:
        if not text or not isinstance(text, str):
            return []
            
        # 1. Isolate the "Experience" section
        experience_section = self._get_experience_section(text)
        if not experience_section:
            experience_section = text
            
        # 2. Split into blocks using dates as anchors
        job_blocks = self._split_into_blocks(experience_section)
        
        experiences = []
        for block in job_blocks:
            parsed = self._parse_single_experience(block)
            if parsed:
                experiences.append(parsed)
                
        return experiences[:10]

    def _get_experience_section(self, text: str) -> str:
        patterns = [
            r'(?i)(?:Work Experience|Professional Experience|Employment History|Experience|Work History):?\s*(.*?)(?=\n\n|\n[A-Z\s]{5,}|\nEDUCATION|\nSKILLS|\nPROJECTS|\nCERTIFICATIONS|$)',
            r'(?i)(?:Experience):?\s*(.*?)(?=\n\n|\n[A-Z\s]{5,}|\nEDUCATION|\nSKILLS|\nPROJECTS|\nCERTIFICATIONS|$)'
        ]
        text_norm = text.replace('\r\n', '\n')
        for p in patterns:
            match = re.search(p, text_norm, re.DOTALL)
            if match:
                return match.group(1).strip()
        return text_norm # Fallback to full text

    def _split_into_blocks(self, section_text: str) -> List[str]:
        # Anchor points: Date ranges or likely job start lines
        anchors = list(self.date_range_pattern.finditer(section_text))
        
        # If no dates, split by significant chunks
        if not anchors:
            return [s.strip() for s in section_text.split('\n\n') if len(s.strip()) > 20]
        
        blocks = []
        last_pos = 0
        for i, match in enumerate(anchors):
            # The actual start of the job might be a few lines above the date
            # We look for the previous newline or start of section
            anchor_start = match.start()
            
            # Look back to find where the previous job ended or a new job starts
            # Usually job blocks are separated by double newlines or have a clear structure
            if i == 0:
                block_start = 0
            else:
                block_start = last_pos
            
            if i + 1 < len(anchors):
                block_end = anchors[i+1].start() - 5 # Give some buffer
            else:
                block_end = len(section_text)
                
            blocks.append(section_text[block_start:block_end].strip())
            last_pos = block_end
            
        return [b for b in blocks if len(b) > 10]

    def _parse_single_experience(self, block: str) -> Optional[Dict[str, Any]]:
        lines = [l.strip() for l in block.split('\n') if l.strip()]
        if not lines: return None
        
        entry = {
            "title": None,
            "company": None,
            "start_date": None,
            "end_date": None,
            "description": block.strip(),
            "location": None
        }
        
        # 1. Dates (mandatory for high confidence fallback)
        date_match = self.date_range_pattern.search(block)
        if date_match:
            entry["start_date"] = date_match.group(1).strip()
            entry["end_date"] = date_match.group(2).strip()
        
        # 2. Title and Company - often in the first few lines of the block or around the date
        date_line_idx = -1
        for idx, line in enumerate(lines):
            if date_match and date_match.group(0) in line:
                date_line_idx = idx
                break
        
        # Candidate lines for title/company: around the date line or the first line
        candidates = []
        if date_line_idx != -1:
            # Check the line itself (e.g. "Amazon | Jan 2020 - Present")
            candidates.append(lines[date_line_idx])
            # Check line before
            if date_line_idx > 0: candidates.append(lines[date_line_idx-1])
            # Check line after
            if date_line_idx < len(lines)-1: candidates.append(lines[date_line_idx+1])
        
        # If still no candidates, use the first 2 lines
        if not candidates:
            candidates = lines[:2]
            
        for cand in candidates:
            cand_clean = cand.strip('-–—•● ').strip()
            if not cand_clean or cand_clean.lower() in self.blacklist: continue
            
            # Title extraction
            if not entry["title"]:
                for jt in self.job_titles:
                    if re.search(rf'\b{re.escape(jt)}\b', cand_clean, re.I):
                        entry["title"] = jt
                        break
                # Fallback to general keywords if specific list fails
                if not entry["title"]:
                    kw_match = re.search(r'\b(engineer|developer|analyst|manager|specialist|consultant|architect|lead|assistant)\b', cand_clean, re.I)
                    if kw_match:
                        entry["title"] = cand_clean
            
            # Company extraction
            if not entry["company"]:
                if any(re.search(p, cand_clean, re.I) for p in self.company_indicators):
                    entry["company"] = cand_clean
                elif entry["title"] and entry["title"].lower() in cand_clean.lower():
                     # If it's a line like "Software Engineer at Google"
                     if " at " in cand_clean.lower():
                         parts = re.split(r'\b(at|@|for)\b', cand_clean, flags=re.I)
                         if len(parts) >= 3:
                             entry["company"] = parts[-1].strip()
                elif cand_clean != entry["title"] and len(cand_clean) < 50 and not self.date_range_pattern.search(cand_clean):
                     # Likely the company name line
                     entry["company"] = cand_clean
        
        # Clean up description (remove the lines we used for title/company/date)
        entry["description"] = "\n".join(lines[min(3, len(lines)):])
        
        if entry["title"] or entry["company"]:
            return entry
        return None
    
    def _extract_company_name(self, text: str) -> Optional[str]:
        """Extract company name with enhanced recognition."""
        lines = text.split('\n')
        
        for line in lines[:3]:  # Usually in first few lines
            line = line.strip()
            
            # Check against company database
            for db_name, canonical_name in self.company_database.items():
                if db_name.lower() in line.lower():
                    # Extract the full company name
                    company_match = self._extract_full_company_name(line, canonical_name)
                    if company_match:
                        return company_match
            
            # Look for company indicators
            for pattern in self.company_indicators:
                if re.search(pattern, line, re.IGNORECASE):
                    # Extract potential company name
                    company_name = self._clean_company_name(line)
                    if company_name and len(company_name) > 2:
                        return company_name
        
        return None
    
    def _extract_full_company_name(self, text: str, canonical_name: str) -> Optional[str]:
        """Extract the full company name from text containing a known company."""
        # Look for the company name with surrounding context
        pattern = rf'.{{0,50}}{re.escape(canonical_name)}.{{0,50}}'
        match = re.search(pattern, text, re.IGNORECASE)
        
        if match:
            context = match.group(0).strip()
            # Try to extract just the company name
            company_name = self._clean_company_name(context)
            if company_name:
                return company_name
        
        return canonical_name
    
    def _clean_company_name(self, text: str) -> Optional[str]:
        """Clean and normalize company name."""
        # Remove common prefixes and suffixes
        text = re.sub(r'^(?:at|for|in|with)\s+', '', text, flags=re.IGNORECASE)
        text = re.sub(r'\s+(?:Inc|LLC|Ltd|Corp|etc\.?)$', '', text, flags=re.IGNORECASE)
        
        # Remove extra whitespace and punctuation
        text = re.sub(r'\s+', ' ', text.strip())
        text = re.sub(r'^[^\w]+|[^\w]+$', '', text)
        
        # Return if it looks like a company name
        if len(text) >= 2 and re.search(r'[A-Za-z]', text):
            return text
        
        return None
    
    def _extract_job_title(self, text: str) -> Optional[str]:
        """Extract job title with enhanced patterns."""
        lines = text.split('\n')
        
        for line in lines[:3]:  # Usually in first few lines
            line = line.strip()
            
            # Look for title patterns
            for pattern in self.title_patterns:
                if re.search(pattern, line, re.IGNORECASE):
                    # Extract potential title
                    title = self._clean_job_title(line)
                    if title and len(title) > 2:
                        return title
        
        return None
    
    def _clean_job_title(self, text: str) -> Optional[str]:
        """Clean and normalize job title."""
        # Remove company names and locations
        for pattern in self.company_indicators:
            text = re.sub(pattern, '', text, flags=re.IGNORECASE)
        
        # Remove dates
        for pattern in self.date_patterns:
            text = re.sub(pattern, '', text, flags=re.IGNORECASE)
        
        # Remove location patterns
        for pattern in self.location_patterns:
            text = re.sub(pattern, '', text, flags=re.IGNORECASE)
        
        # Clean up
        text = re.sub(r'\s+', ' ', text.strip())
        text = re.sub(r'^[^\w]+|[^\w]+$', '', text)
        
        # Return if it looks like a job title
        if len(text) >= 2 and re.search(r'[A-Za-z]', text):
            return text
        
        return None
    
    def _extract_dates(self, text: str) -> Tuple[Optional[str], Optional[str]]:
        """Extract start and end dates with multiple format support."""
        # Look for date ranges
        for pattern in self.date_patterns:
            matches = re.findall(pattern, text, re.IGNORECASE)
            if matches:
                if len(matches) >= 2:
                    return self._normalize_date(matches[0]), self._normalize_date(matches[1])
                elif len(matches) == 1:
                    # Check if it's a range pattern
                    range_match = re.search(rf'{pattern}\s*[-–—]\s*(?:Present|Current|Now|{pattern})', text, re.IGNORECASE)
                    if range_match:
                        range_text = range_match.group(0)
                        date_matches = re.findall(pattern, range_text, re.IGNORECASE)
                        if len(date_matches) >= 2:
                            return self._normalize_date(date_matches[0]), self._normalize_date(date_matches[1])
                        elif 'present' in range_text.lower() or 'current' in range_text.lower():
                            return self._normalize_date(date_matches[0]), 'Present'
                    else:
                        # Single date (might be start date only)
                        return self._normalize_date(matches[0]), None
        
        return None, None
    
    def _normalize_date(self, date_str: str) -> str:
        """Normalize date to standard format."""
        if not date_str:
            return ''
        
        date_str = date_str.strip()
        
        # Handle "Present", "Current", etc.
        if date_str.lower() in ['present', 'current', 'now', 'ongoing']:
            return 'Present'
        
        # Try to parse and reformat
        try:
            # Month Year format
            month_year_match = re.match(r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{4})', date_str, re.IGNORECASE)
            if month_year_match:
                month, year = month_year_match.groups()
                month_num = self._get_month_number(month)
                return f"{year}-{month_num:02d}"
            
            # MM/YYYY format
            mm_yyyy_match = re.match(r'(\d{1,2})/(\d{4})', date_str)
            if mm_yyyy_match:
                month, year = mm_yyyy_match.groups()
                return f"{year}-{month.zfill(2)}"
            
            # Year only
            year_match = re.match(r'(\d{4})', date_str)
            if year_match:
                return year_match.group(1)
            
        except Exception as e:
            logger.warning(f"Date normalization failed for '{date_str}': {e}")
        
        return date_str  # Return original if normalization fails
    
    def _get_month_number(self, month_name: str) -> int:
        """Get month number from month name."""
        months = {
            'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
            'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
        }
        return months.get(month_name[:3].lower(), 1)
    
    def _extract_location(self, text: str) -> Optional[str]:
        """Extract location information."""
        for pattern in self.location_patterns:
            match = re.search(pattern, text)
            if match:
                location = match.group(0).strip()
                # Clean up location
                location = re.sub(r'\s+', ' ', location)
                return location
        
        return None
    
    def _extract_description(self, text: str) -> Optional[str]:
        """Extract job description/responsibilities."""
        lines = text.split('\n')
        
        # Skip first few lines (usually title, company, dates)
        description_lines = []
        for line in lines[3:]:
            line = line.strip()
            if line and not self._is_metadata_line(line):
                description_lines.append(line)
        
        if description_lines:
            return ' '.join(description_lines)
        
        return None
    
    def _is_metadata_line(self, line: str) -> bool:
        """Check if line contains metadata (dates, locations, etc.)."""
        # Check for dates
        for pattern in self.date_patterns:
            if re.search(pattern, line):
                return True
        
        # Check for locations
        for pattern in self.location_patterns:
            if re.search(pattern, line):
                return True
        
        # Check for company indicators
        for pattern in self.company_indicators:
            if re.search(pattern, line):
                return True
        
        return False
    
    def enhance_experience_entry(self, experience: Dict[str, Any]) -> Dict[str, Any]:
        """Enhance an existing experience entry with additional parsing."""
        enhanced = experience.copy()
        
        # If we have raw text, parse it
        if 'raw_text' in enhanced:
            parsed = self._parse_single_experience(enhanced['raw_text'])
            if parsed:
                # Merge with existing data, preferring parsed data
                for key, value in parsed.items():
                    if value and not enhanced.get(key):
                        enhanced[key] = value
        
        # Calculate duration if we have dates
        if enhanced.get('start_date') and enhanced.get('end_date') and enhanced['end_date'] != 'Present':
            try:
                duration = self._calculate_duration(enhanced['start_date'], enhanced['end_date'])
                enhanced['duration_months'] = duration
            except Exception:
                pass
        
        return enhanced
    
    def _calculate_duration(self, start_date: str, end_date: str) -> int:
        """Calculate duration in months between two dates."""
        try:
            # Parse dates (assuming YYYY-MM format)
            start_parts = start_date.split('-')
            end_parts = end_date.split('-')
            
            if len(start_parts) >= 2 and len(end_parts) >= 2:
                start_year, start_month = int(start_parts[0]), int(start_parts[1])
                end_year, end_month = int(end_parts[0]), int(end_parts[1])
                
                start_dt = datetime(start_year, start_month, 1)
                end_dt = datetime(end_year, end_month, 1)
                
                duration = (end_dt.year - start_dt.year) * 12 + (end_dt.month - start_dt.month)
                return max(0, duration)
        except Exception as e:
            logger.warning(f"Duration calculation failed: {e}")
        
        return 0
