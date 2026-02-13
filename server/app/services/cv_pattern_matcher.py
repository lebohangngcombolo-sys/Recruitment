import re
from typing import Any, Dict, List


class CVPatternMatcher:
    def extract_all(self, text: str, metadata: Dict[str, Any] | None = None) -> Dict[str, Any]:
        t = self._preprocess_text(text or "")
        t = self._strip_attachment_blocks(t)

        # Extract personal details
        personal_details = self._extract_personal_details(t)
        
        # Extract social profiles
        linkedin = self._first(
            r"(?:https?://)?(?:www\.)?linkedin\.com/(?:in|company)/[^\s)]+",
            t,
        )
        github = personal_details.get("github", self._first(
            r"(?:https?://)?(?:www\.)?github\.com/[A-Za-z0-9_\-]+",
            t,
        ))
        
        portfolio = personal_details.get("portfolio", self._extract_portfolio_url(t, linkedin=linkedin, github=github))
        
        # Extract languages
        languages = self._extract_languages_from_kv(t)
        if not languages:
            languages = self._extract_tokens_section(
                t,
                ["languages", "language"],
                limit=15,
            )

        if languages:
            languages = self._dedupe_list_case_insensitive(languages)

        # Extract skills
        skills = self._extract_tokens_section(
            t,
            [
                "technical skills",
                "core skills",
                "key skills",
                "skills",
                "technologies",
                "tools & technologies",
                "tools and technologies",
                "tools",
            ],
            limit=75,
        )
        
        # Fallback for skills if empty
        if not skills:
            skills = self._extract_skills_fallback(t, limit=30)
        
        # Extract experience
        exp = self._extract_section_text(
            t,
            [
                "work experience",
                "professional experience",
                "employment",
                "employment history",
                "experience",
                "work history",
            ],
            stop_words=[
                "education",
                "educational qualifications",
                "skills",
                "core skills",
                "key skills",
                "technical skills",
                "projects",
                "project highlights",
                "tools & technologies",
                "tools and technologies",
                "certifications",
                "certificates",
                "licenses",
                "languages",
                "references",
            ],
        )
        
        # Extract position and companies from experience
        position, previous_companies = self._extract_position_and_companies(t)
        
        return {
            "full_name": personal_details.get("full_name", self._guess_name(t)),
            "email": self._first(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", t),
            "phone": self._first(r"\+?\d[\d\s\-\(\)]{7,}\d", t),
            "linkedin": linkedin,
            "github": github,
            "portfolio": portfolio,
            "address": personal_details.get("address", ""),
            "dob": personal_details.get("dob", ""),
            "gender": personal_details.get("gender", ""),
            "nationality": personal_details.get("nationality", ""),
            "id_number": personal_details.get("id_number", ""),
            "education": self._extract_education(t),
            "skills": skills,
            "certifications": self._extract_list_section(
                t,
                ["certifications", "certificates", "licenses", "credentials"],
                limit=25,
            ),
            "languages": languages,
            "experience": exp,
            "position": position,
            "previous_companies": previous_companies,
            "bio": self._extract_bio(t),
        }

    def _extract_personal_details(self, t: str) -> Dict[str, str]:
        """Extract personal details from CV"""
        details = {
            "full_name": "",
            "dob": "",
            "gender": "",
            "nationality": "",
            "id_number": "",
            "address": "",
            "github": "",
            "portfolio": ""
        }
        
        # Extract date of birth
        dob_match = re.search(
            r'(?:Date\s*of\s*Birth|DOB|Birth\s*Date)[:\-]?\s*([\d\-\./]{8,12})',
            t, re.I
        )
        if dob_match:
            details["dob"] = dob_match.group(1).strip()
        
        # Extract gender
        gender_match = re.search(
            r'(?:Gender|Sex)[:\-]?\s*(Male|Female|Other|M|F)',
            t, re.I
        )
        if gender_match:
            details["gender"] = gender_match.group(1).strip()
        
        # Extract nationality
        nationality_match = re.search(
            r'(?:Nationality|Citizenship|Country)[:\-]?\s*([A-Za-z\s]{2,30})',
            t, re.I
        )
        if nationality_match:
            details["nationality"] = nationality_match.group(1).strip()
        
        # Extract ID number (South African format)
        id_match = re.search(
            r'(?:ID|Identity\s*Number|ID\s*No|ID\s*Number)[:\-]?\s*(\d{13})',
            t, re.I
        )
        if id_match:
            details["id_number"] = id_match.group(1).strip()
        
        # Extract address (multi-line)
        address_match = re.search(
            r'(?:Address|Location|Residence)[:\-]?\s*([^\n]{10,200})(?=\n\s*[A-Z]|\n\n)',
            t, re.I
        )
        if address_match:
            details["address"] = address_match.group(1).strip()
        
        # Extract GitHub
        github = self._first(
            r"(?:https?://)?(?:www\.)?github\.com/[A-Za-z0-9_\-]+",
            t,
        )
        if github:
            details["github"] = github
        
        # Extract portfolio (excluding GitHub/LinkedIn)
        portfolio_match = re.search(
            r'(?:Portfolio|Website|Site)[:\-]?\s*((?:https?://)?[^\s]{5,100})',
            t, re.I
        )
        if portfolio_match and "github.com" not in portfolio_match.group(1).lower():
            details["portfolio"] = portfolio_match.group(1).strip()
        
        return details

    def _first(self, pattern: str, t: str) -> str:
        m = re.search(pattern, t, re.I)
        return (m.group(0) or "").strip() if m else ""

    def _guess_name(self, t: str) -> str:
        lines = [ln.strip() for ln in (t or "").splitlines() if ln.strip()]
        for ln in lines[:10]:
            if re.search(r"@|\d", ln):
                continue
            parts = ln.split()
            if 2 <= len(parts) <= 4 and sum(1 for p in parts if p[:1].isupper()) >= 2:
                return ln
        m = re.search(r"\b([A-Z][a-z]+\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\b", t)
        return m.group(1) if m else ""

    def _extract_section_text(self, t: str, headers: List[str], stop_words: List[str]) -> str:
        """Extract text between section headers"""
        lower = t.lower()
        start = None
        
        # Find the start of the section
        for h in headers:
            # Look for header with optional colon, dash, or at line start
            pattern = rf"(?i)^\s*{re.escape(h)}[:\-]?\s*$"
            m = re.search(pattern, t, re.M)
            if m:
                start = m.end()
                break
        
        # Also try inline headers (header on same line as content)
        if start is None:
            for h in headers:
                pattern = rf"(?i)^\s*{re.escape(h)}[:\-]?\s*(.*)$"
                m = re.search(pattern, t, re.M)
                if m and m.group(1).strip():
                    return m.group(1).strip()
        
        if start is None:
            return ""
        
        # Extract everything until next section header
        tail = t[start:]
        
        # Look for next uppercase header (common in CVs)
        next_header_match = re.search(r'^\s*[A-Z][A-Z\s&]{3,50}(?:[:\-]|$)', tail, re.M)
        if next_header_match:
            return tail[:next_header_match.start()].strip()
        
        # Fallback: use stop words
        for sw in stop_words:
            pattern = rf'(?i)^\s*{re.escape(sw)}[:\-]?\s*'
            m2 = re.search(pattern, tail, re.M)
            if m2:
                return tail[:m2.start()].strip()
        
        return tail.strip()

    def _extract_skills_fallback(self, t: str, limit: int) -> List[str]:
        lower = (t or "").lower()
        skill_map = {
            "power bi": "Power BI",
            "powerbi": "Power BI",
            "tableau": "Tableau",
            "excel": "Excel",
            "sql": "SQL",
            "python": "Python",
            "r": "R",
            "sas": "SAS",
            "google analytics": "Google Analytics",
            "aws": "AWS",
            "azure": "Azure",
            "gcp": "GCP",
            "docker": "Docker",
            "kubernetes": "Kubernetes",
            "git": "Git",
        }

        out: List[str] = []
        seen = set()

        m = re.search(r"(?i)\b(proficient\s+in|skills\s+include|experienced\s+in)\b\s*([^\n]{0,200})", t)
        if m:
            tail = m.group(2) or ""
            for tok in re.split(r"[,;/]|\band\b", tail, flags=re.I):
                s = tok.strip(" \t-•.()")
                if not s:
                    continue
                key = s.lower()
                if key in skill_map:
                    val = skill_map[key]
                    if val.lower() not in seen:
                        seen.add(val.lower())
                        out.append(val)
                if len(out) >= limit:
                    return out

        for k, val in skill_map.items():
            if re.search(rf"\b{re.escape(k)}\b", lower, re.I):
                lk = val.lower()
                if lk in seen:
                    continue
                seen.add(lk)
                out.append(val)
                if len(out) >= limit:
                    break

        return out

    def _extract_list_section(self, t: str, headers: List[str], limit: int) -> List[str]:
        """Extract list items from a section (education, certifications, etc.)"""
        # First, try to get the full section text
        stop_words = [
            "experience", "work experience", "professional experience", "employment",
            "skills", "core skills", "key skills", "technical skills",
            "projects", "project highlights", "certifications", "certificates",
            "licenses", "languages", "references", "tools & technologies",
            "tools and technologies", "education", "educational qualifications",
            "tertiary qualifications", "work history", "awards", "publications"
        ]
        
        # Remove current section from stop words
        stop_words = [sw for sw in stop_words if sw.lower() not in {h.lower() for h in headers}]
        
        sec = self._extract_section_text(t, headers, stop_words=stop_words)
        
        if not sec:
            return []
        
        # Split into lines
        lines = [ln.strip(" \t-•") for ln in sec.splitlines() if ln.strip()]
        
        # Filter out lines that are actually other section headers
        filtered_lines = []
        for line in lines:
            line_lower = line.lower()
            # Skip if line is a section header
            if any(sw.lower() in line_lower for sw in stop_words):
                continue
            # Skip if line contains too many colons (likely skill categories)
            if line.count(':') > 1:
                continue
            filtered_lines.append(line)
        
        return filtered_lines[:limit]

    def _extract_tokens_section(self, t: str, headers: List[str], limit: int) -> List[str]:
        stop_words = [
            "experience",
            "work experience",
            "professional experience",
            "employment",
            "education",
            "educational qualifications",
            "tertiary qualifications",
            "projects",
            "project highlights",
            "certifications",
            "certificates",
            "licenses",
            "languages",
            "references",
            "tools & technologies",
            "tools and technologies",
            "skills",
            "core skills",
            "key skills",
        ]
        stop_words = [sw for sw in stop_words if sw.lower() not in {h.lower() for h in headers}]
        sec = self._extract_section_text(t, headers, stop_words=stop_words)
        if not sec:
            return []
        toks = re.split(r"[\n,;/•]+", sec)
        out: List[str] = []
        seen = set()
        for tok in toks:
            s = tok.strip(" \t-•")
            if ":" in s and len(s) > 4:
                s = s.split(":", 1)[-1].strip()
            if self._is_skill_heading(s):
                continue
            # Filter out single word category headers
            if s.lower() in ["technical", "soft", "data", "analytics", "business", "professional"]:
                continue
            if len(s) < 2 or len(s) > 40:
                continue
            # Handle compound terms like "Agile/Scrum Collaboration"
            if "/" in s and len(s.split("/")) == 2:
                # Keep as is if it's a legitimate compound term
                pass
            k = s.lower()
            if k in seen:
                continue
            seen.add(k)
            out.append(s)
            if len(out) >= limit:
                break
        return out

    def _extract_languages_from_kv(self, t: str) -> List[str]:
        """Extract languages from various CV formats"""
        languages = []
        
        # Pattern 1: Simple LANGUAGES: English, Zulu, etc.
        lang_match = re.search(
            r'(?i)^\s*LANGUAGES[:\-]?\s*(.*?)(?=\n\s*[A-Z][A-Z\s&]{3,}|$)',
            t, re.M | re.DOTALL
        )
        
        if lang_match:
            lang_text = lang_match.group(1).strip()
            # Extract comma/separated languages
            if lang_text:
                lang_items = re.split(r'[,;/•\-]|\band\b', lang_text)
                for item in lang_items:
                    item = item.strip()
                    if 2 <= len(item) <= 30 and not any(c.isdigit() for c in item):
                        languages.append(item)
        
        # Pattern 2: Home Language / Other Languages format
        if not languages:
            matches = re.findall(r'^\s*(?:Home\s+Language|Other\s+Languages)[:\-]?\s*(.*)$', t, re.I | re.M)
            for match in matches:
                if match:
                    items = re.split(r'[,;/]', match)
                    languages.extend([item.strip() for item in items if item.strip()])
        
        # Pattern 3: Bullet points under Languages
        if not languages:
            lines = t.split('\n')
            in_languages_section = False
            for line in lines:
                if re.search(r'(?i)^\s*LANGUAGES[:\-]?\s*$', line):
                    in_languages_section = True
                    continue
                if in_languages_section:
                    if re.search(r'(?i)^\s*[A-Z][A-Z\s&]{3,}[:\-]?\s*$', line):
                        break
                    lang_items = re.split(r'[,;/•\-]', line)
                    for item in lang_items:
                        item = item.strip()
                        if item and 2 <= len(item) <= 30:
                            languages.append(item)
        
        # Filter out non-language entries
        blacklist = {'work', 'experience', 'education', 'skills', 'certifications'}
        languages = [
            lang for lang in languages 
            if lang.lower() not in blacklist and len(lang) > 1
        ]
        
        return languages[:10] if languages else []

    def _preprocess_text(self, t: str) -> str:
        replacements = {
            "\u2022": "- ",
            "•": "- ",
            "●": "- ",
            "○": "- ",
            "▪": "- ",
            "■": "- ",
            "": "- ",
        }
        for old, new in replacements.items():
            t = t.replace(old, new)

        for ch in ["\u200b", "\ufeff", "\u2060", "\u200c", "\u200d", "\uf0b7", "\u2023", "\u25e6", "\u2043", "\u00a0", "​"]:
            t = t.replace(ch, "")

        t = re.sub(r"[ \t]+", " ", t)
        t = t.replace("\r\n", "\n").replace("\r", "\n")
        t = re.sub(r"\n\s*\n+", "\n\n", t)

        t = self._normalize_inline_headers(t)
        return t

    def _normalize_inline_headers(self, t: str) -> str:
        inline_headers = [
            r"EDUCATION",
            r"EDUCATIONAL QUALIFICATIONS",
            r"TERTIARY QUALIFICATIONS",
            r"KEY SKILLS",
            r"CORE SKILLS",
            r"SKILLS",
            r"PROFESSIONAL EXPERIENCE",
            r"WORK EXPERIENCE",
            r"EXPERIENCE",
            r"CERTIFICATIONS",
            r"LANGUAGES",
            r"PROFESSIONAL SUMMARY",
            r"SUMMARY",
            r"PROFILE",
            r"OBJECTIVE",
        ]

        lines = t.split("\n")
        out_lines: List[str] = []
        for line in lines:
            done = False
            for h in inline_headers:
                m = re.search(rf"\b{h}\b\s*[:\.]?\s*", line, re.I)
                if not m:
                    continue

                before = line[: m.start()].rstrip()
                header_and_tail = line[m.start() :].lstrip()

                tail = header_and_tail[m.end() - m.start() :].strip()

                if m.start() > 0:
                    if before:
                        out_lines.append(before)
                    out_lines.append(header_and_tail)
                    done = True
                    break

                if m.start() == 0 and tail:
                    header_only = header_and_tail[: m.end() - m.start()].strip()
                    if header_only:
                        out_lines.append(header_only)
                    out_lines.append(tail)
                    done = True
                    break
            if not done:
                out_lines.append(line)

        return "\n".join(out_lines)

    def _extract_portfolio_url(self, t: str, linkedin: str = "", github: str = "") -> str:
        candidates = re.findall(
            r"(?<!@)\b(?:https?://)?(?:www\.)?[A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z]{2,}(?:/[^\s)]*)?\b",
            t,
            re.I,
        )
        email_providers = ["gmail.com", "yahoo.com", "outlook.com", "hotmail.com", "live.com", "icloud.com"]
        context_kw = re.compile(r"(portfolio|website|site|blog)", re.I)
        for c in candidates:
            c = c.strip().rstrip(".,;)")
            if "@" in c:
                continue
            lc = c.lower()
            if any(p in lc for p in email_providers):
                continue
            if any(d in lc for d in ["linkedin.com", "github.com", "twitter.com", "facebook.com", "instagram.com"]):
                continue
            if re.search(r"\.(pdf|doc|docx|jpg|jpeg|png|zip)$", lc):
                continue

            # Avoid random domain mentions being treated as portfolio.
            # Accept only if the candidate is an explicit URL-like token or appears close to a portfolio keyword.
            explicit = bool(re.match(r"^(?:https?://|www\.)", c, re.I))
            if not explicit:
                has_kw_context = False
                for m in re.finditer(re.escape(c), t, re.I):
                    left = max(0, m.start() - 60)
                    right = min(len(t), m.end() + 20)
                    window = t[left:right]
                    if context_kw.search(window):
                        has_kw_context = True
                        break
                if not has_kw_context:
                    continue

            escaped = re.escape(c)
            if re.search(rf"{escaped}@", t, re.I) or re.search(rf"@{escaped}", t, re.I):
                continue
            return c

        return ""

    def _is_skill_heading(self, s: str) -> bool:
        if not s:
            return False
        ss = s.strip()
        if re.match(r"(?i)^(data\s+analysis\s*&\s*tools|analytics\s*&\s*reporting|business\s*&\s*collaboration)$", ss):
            return True
        if re.match(r"(?i)^[A-Za-z][A-Za-z\s&]{0,38}:$", ss):
            return True
        if re.match(r"(?i)^(technical|soft|business|professional)\s+[A-Za-z\s&]{2,}$", ss):
            return True
        return False

    def _dedupe_list_case_insensitive(self, items: List[str]) -> List[str]:
        out: List[str] = []
        seen = set()
        for it in items:
            s = (it or "").strip()
            if not s:
                continue
            k = s.lower()
            if k in seen:
                continue
            seen.add(k)
            out.append(s)
        return out

    def _strip_attachment_blocks(self, t: str) -> str:
        keywords = [
            "republic of south africa",
            "department:",
            "department of higher education",
            "certificate of achievement",
            "statement of results",
            "identity number",
            "serial number",
            "issued by authority",
            "umalusi",
            "this certificate is printed",
            "please hold up to the light",
        ]

        lower = t.lower()
        indices = []
        for kw in keywords:
            idx = lower.find(kw)
            if idx != -1:
                indices.append(idx)

        if not indices:
            return t

        cut = min(indices)
        if cut > 600:
            return t[:cut].strip()
        return t

    def _extract_education(self, t: str) -> List[str]:
        """Extract education details"""
        education = self._extract_list_section(
            t,
            [
                "education",
                "academics",
                "qualifications",
                "educational qualifications",
                "tertiary qualifications",
            ],
            limit=15,
        )
        
        # Clean up education entries
        cleaned_education = []
        for entry in education:
            # Remove skill lists from education entries
            cleaned = re.sub(r'(?:Technical,? Skills:|Data & Analytics:|Soft Skills:).*', '', entry, flags=re.I)
            cleaned = cleaned.strip()
            if cleaned:
                cleaned_education.append(cleaned)
        
        return cleaned_education if cleaned_education else education

    def _extract_position_and_companies(self, t: str) -> tuple[str, List[str]]:
        """Extract position and previous companies from work experience"""
        position = ""
        companies = []
        
        # Look for position pattern: "Data Analyst" at start of experience section
        exp_section = self._extract_section_text(
            t,
            ["work experience", "professional experience", "experience"],
            stop_words=["education", "skills", "projects", "certifications"]
        )
        
        if exp_section:
            # Extract first job title
            lines = exp_section.split('\n')
            if lines:
                # First line should be the position
                title_match = re.search(r'^\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\s*(?:Analyst|Engineer|Developer|Manager|Specialist))', 
                                       lines[0], re.I)
                if title_match:
                    position = title_match.group(1).strip()
            
            # Look for company name on second line (pattern: Company — Location)
            if len(lines) > 1:
                company_line = lines[1]
                company_match = re.search(r'^([A-Za-z\s&\.\(\)(Pty)\s*Ltd]+)\s*—', company_line)
                if company_match:
                    companies.append(company_match.group(1).strip())
        
        # Deduplicate companies
        unique_companies = []
        seen = set()
        for comp in companies:
            comp_lower = comp.lower()
            if comp_lower not in seen:
                seen.add(comp_lower)
                unique_companies.append(comp)
        
        return position, unique_companies[:5]

    def _extract_bio(self, t: str) -> str:
        """Extract bio/summary section"""
        bio_sections = [
            "professional summary",
            "summary",
            "profile",
            "bio",
            "about",
            "objective"
        ]
        
        for section in bio_sections:
            bio = self._extract_section_text(
                t,
                [section],
                stop_words=["education", "work experience", "skills", "projects"]
            )
            if bio:
                # Limit bio length
                if len(bio) > 500:
                    bio = bio[:497] + "..."
                return bio
        
        return ""
