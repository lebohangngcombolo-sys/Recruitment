import os
import re
import requests
import json
import logging
import time
from typing import Dict, Any, Optional
from dotenv import load_dotenv

from app.services.cv_analysis_utils import truncate_for_cv_prompt


# ----------------------------
# Environment & Logging Setup
# ----------------------------
load_dotenv()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Gemini AI (Google Generative AI). Use GEMINI_MODEL for model id (e.g. gemini-2.0-flash, gemini-1.5-flash).
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.0-flash")
GEMINI_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"

# OpenRouter
OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY")
OPENROUTER_URL = os.environ.get(
    "OPENROUTER_URL", "https://openrouter.ai/api/v1/chat/completions"
)
DEFAULT_MODEL = os.environ.get("OPENROUTER_MODEL", "openai/gpt-4o-mini")

# DeepSeek
DEEPSEEK_API_KEY = os.environ.get("DEEPSEEK_API_KEY")
DEEPSEEK_URL = "https://api.deepseek.com/v1/chat/completions"

# Cap max_tokens for providers with tight credit limits (e.g. OpenRouter free tier)
AI_MAX_OUTPUT_TOKENS = int(os.environ.get("AI_MAX_OUTPUT_TOKENS", "800"))
# Safe fallback limit to avoid hitting free-tier caps
AI_SAFE_OUTPUT_TOKENS = int(os.environ.get("AI_SAFE_OUTPUT_TOKENS", "600"))

# Provider-specific overrides (fall back to safe limit if unset)
OPENROUTER_MAX_OUTPUT_TOKENS = int(
    os.environ.get("OPENROUTER_MAX_OUTPUT_TOKENS", str(AI_SAFE_OUTPUT_TOKENS))
)
DEEPSEEK_MAX_OUTPUT_TOKENS = int(
    os.environ.get("DEEPSEEK_MAX_OUTPUT_TOKENS", str(AI_SAFE_OUTPUT_TOKENS))
)


class AIService:
    def __init__(
        self,
        timeout: int = 60,
        retries: int = 3,
        backoff: int = 5,
    ):
        self.timeout = timeout
        self.retries = retries
        self.backoff = backoff

        # Check API keys
        self.gemini_available = bool(GEMINI_API_KEY)
        self.openrouter_available = bool(OPENROUTER_API_KEY)
        self.deepseek_available = bool(DEEPSEEK_API_KEY)

        if not any([self.gemini_available, self.openrouter_available, self.deepseek_available]):
            logger.warning(
                "No AI API keys found in environment. AI calls will fail without keys."
            )

    def _call_gemini(
        self, prompt: str, temperature: float = 0.7, max_output_tokens: int = 512
    ) -> str:
        """Call Gemini AI API"""
        if not self.gemini_available:
            raise RuntimeError("GEMINI_API_KEY not set")

        headers = {
            "Content-Type": "application/json",
        }

        payload = {
            "contents": [{
                "parts": [{"text": prompt}]
            }],
            "generationConfig": {
                "temperature": temperature,
                "maxOutputTokens": max_output_tokens,
            }
        }

        for attempt in range(1, self.retries + 1):
            try:
                url = f"{GEMINI_URL}?key={GEMINI_API_KEY}"
                resp = requests.post(url, headers=headers, json=payload, timeout=self.timeout)
                
                if resp.status_code != 200:
                    logger.error(
                        "Gemini API error [%s]: %s", resp.status_code, resp.text
                    )
                    raise RuntimeError(
                        f"Gemini API error: {resp.status_code} {resp.text}"
                    )
                
                data = resp.json()
                return data["candidates"][0]["content"]["parts"][0]["text"]
                
            except requests.exceptions.Timeout:
                logger.warning(
                    "Gemini timeout on attempt %d/%d, retrying in %d seconds...",
                    attempt, self.retries, self.backoff,
                )
                time.sleep(self.backoff)
            except requests.exceptions.RequestException as e:
                logger.error(
                    "Gemini RequestException on attempt %d/%d: %s", attempt, self.retries, e
                )
                time.sleep(self.backoff)
            except Exception as e:
                logger.exception(
                    "Gemini unexpected error on attempt %d/%d: %s", attempt, self.retries, e
                )
                time.sleep(self.backoff)

        raise RuntimeError("Failed to call Gemini API after multiple retries")

    def _call_openrouter(
        self, prompt: str, temperature: float = 0.7, max_output_tokens: int = 512
    ) -> str:
        """Call OpenRouter API"""
        if not self.openrouter_available:
            raise RuntimeError("OPENROUTER_API_KEY not set")

        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        }

        capped_tokens = min(max_output_tokens, OPENROUTER_MAX_OUTPUT_TOKENS, AI_MAX_OUTPUT_TOKENS)
        payload = {
            "model": DEFAULT_MODEL,
            "messages": [
                {"role": "system", "content": "You are an expert recruitment assistant."},
                {"role": "user", "content": prompt},
            ],
            "temperature": temperature,
            "max_tokens": capped_tokens,
        }

        for attempt in range(1, self.retries + 1):
            try:
                resp = requests.post(
                    OPENROUTER_URL, headers=headers, json=payload, timeout=self.timeout
                )
                if resp.status_code != 200:
                    logger.error(
                        "OpenRouter API error [%s]: %s", resp.status_code, resp.text
                    )
                    raise RuntimeError(
                        f"OpenRouter API error: {resp.status_code} {resp.text}"
                    )
                data = resp.json()
                return data["choices"][0]["message"]["content"]
            except requests.exceptions.Timeout:
                logger.warning(
                    "OpenRouter timeout on attempt %d/%d, retrying in %d seconds...",
                    attempt, self.retries, self.backoff,
                )
                time.sleep(self.backoff)
            except requests.exceptions.RequestException as e:
                logger.error(
                    "OpenRouter RequestException on attempt %d/%d: %s", attempt, self.retries, e
                )
                time.sleep(self.backoff)
            except Exception as e:
                logger.exception(
                    "OpenRouter unexpected error on attempt %d/%d: %s", attempt, self.retries, e
                )
                time.sleep(self.backoff)

        raise RuntimeError("Failed to call OpenRouter API after multiple retries")

    def _call_deepseek(
        self, prompt: str, temperature: float = 0.7, max_output_tokens: int = 512
    ) -> str:
        """Call DeepSeek API"""
        if not self.deepseek_available:
            raise RuntimeError("DEEPSEEK_API_KEY not set")

        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
        }

        capped_tokens = min(max_output_tokens, DEEPSEEK_MAX_OUTPUT_TOKENS, AI_MAX_OUTPUT_TOKENS)
        payload = {
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": "You are an expert recruitment assistant."},
                {"role": "user", "content": prompt},
            ],
            "temperature": temperature,
            "max_tokens": capped_tokens,
        }

        for attempt in range(1, self.retries + 1):
            try:
                resp = requests.post(
                    DEEPSEEK_URL, headers=headers, json=payload, timeout=self.timeout
                )
                if resp.status_code != 200:
                    logger.error(
                        "DeepSeek API error [%s]: %s", resp.status_code, resp.text
                    )
                    raise RuntimeError(
                        f"DeepSeek API error: {resp.status_code} {resp.text}"
                    )
                data = resp.json()
                return data["choices"][0]["message"]["content"]
            except requests.exceptions.Timeout:
                logger.warning(
                    "DeepSeek timeout on attempt %d/%d, retrying in %d seconds...",
                    attempt, self.retries, self.backoff,
                )
                time.sleep(self.backoff)
            except requests.exceptions.RequestException as e:
                logger.error(
                    "DeepSeek RequestException on attempt %d/%d: %s", attempt, self.retries, e
                )
                time.sleep(self.backoff)
            except Exception as e:
                logger.exception(
                    "DeepSeek unexpected error on attempt %d/%d: %s", attempt, self.retries, e
                )
                time.sleep(self.backoff)

        raise RuntimeError("Failed to call DeepSeek API after multiple retries")

    def _call_generation(
        self, prompt: str, temperature: float = 0.7, max_output_tokens: int = 512
    ) -> str:
        """Try AI services in priority order: Gemini -> OpenRouter -> DeepSeek"""
        
        # Try Gemini first
        if self.gemini_available:
            try:
                logger.info("Attempting to use Gemini AI")
                return self._call_gemini(prompt, temperature, max_output_tokens)
            except Exception as e:
                logger.warning(f"Gemini AI failed: {e}")
        
        # Fallback to OpenRouter
        if self.openrouter_available:
            try:
                logger.info("Falling back to OpenRouter")
                return self._call_openrouter(prompt, temperature, max_output_tokens)
            except Exception as e:
                logger.warning(f"OpenRouter failed: {e}")
        
        # Fallback to DeepSeek
        if self.deepseek_available:
            try:
                logger.info("Falling back to DeepSeek")
                return self._call_deepseek(prompt, temperature, max_output_tokens)
            except Exception as e:
                logger.warning(f"DeepSeek failed: {e}")
        
        raise RuntimeError("All AI services failed")

    def _call_ai(self, prompt: str, temperature: float = 0.7, max_output_tokens: int = 512) -> str:
        """Alias for _call_generation for backward compatibility (e.g. Celery worker cache)."""
        return self._call_generation(prompt, temperature, max_output_tokens)

    def generate_job_details(self, job_title: str) -> Dict[str, Any]:
        """Generate comprehensive job details using AI hierarchy: Gemini -> OpenRouter -> DeepSeek"""
        prompt = f'''
        First, determine the most appropriate category for the job titled "$job_title" from the following options: Engineering, Marketing, Sales, HR, Finance, Operations, Customer Service, Product, Design, Data Science. Base this on the job title and typical responsibilities.

        Then, generate comprehensive job details in JSON format with the following structure:
        {{
          "description": "Detailed job description (2-3 paragraphs) that clearly explains the role, its purpose, and what the candidate will be doing day-to-day",
          "responsibilities": ["List of 5-7 specific, actionable key responsibilities as separate string items in the array"],
          "qualifications": ["List of 5-7 required qualifications including education, experience, and specific skills"],
          "company": "Khonology",
          "company_details": "Khonology is a South African digital services company founded in 2013, specializing in digital enablement, data solutions, and cloud services with B-BBEE Level 2 status. The company focuses on empowering African businesses through custom software, data analytics, and cloud migration, while also addressing the digital skills gap via the Khonology Academy.",
          "category": "Choose the most appropriate category from: Engineering, Marketing, Sales, HR, Finance, Operations, Customer Service, Product, Design, Data Science, based on the job title, description, and responsibilities.",
          "required_skills": ["List of 7 technical/professional skills that are essential for this role"],
          "min_experience": "Minimum years of experience as a number (0-15+)",
          "salary_min": "Minimum monthly salary in ZAR (e.g., 25000)",
          "salary_max": "Maximum monthly salary in ZAR (e.g., 45000)",
          "salary_currency": "ZAR",
          "salary_period": "monthly",
          "evaluation_weightings": {{
            "cv": 60,
            "assessment": 30,
            "interview": 10,
            "references": 0
          }}
        }}
        
        IMPORTANT FORMATTING INSTRUCTIONS:
        - Responsibilities MUST be an array of separate strings, each representing one bullet point
        - Do NOT combine responsibilities into a single paragraph
        - Each responsibility should be a complete, actionable statement starting with a verb
        - Example format: ["Lead development projects", "Design scalable solutions", "Mentor junior developers"]
        - Qualifications MUST be an array of separate strings, each representing one bullet point
        - Do NOT combine qualifications into a single paragraph or comma-separated string
        - Each qualification should be a complete statement (e.g., "Bachelor's degree in Computer Science", "3+ years of experience in software development")
        - Required skills MUST be an array of separate strings, each representing one bullet point
        - Do NOT combine skills into a single paragraph
        - Example format: ["JavaScript", "React", "Node.js"]
        - Salary should be realistic for South African market (ZAR currency)
        - Evaluation weightings MUST total exactly 100% (cv + assessment + interview + references = 100)
        - Do not generate weightings that don't sum to 100%
        
        Guidelines:
        - Make the description compelling and detailed
        - Responsibilities should be specific, measurable, and formatted as separate bullet points
        - Qualifications should be realistic but selective
        - Company details should be professional and appealing
        - Choose the most appropriate category
        - Include the determined category in the 'category' field of the JSON
        - Skills should be current and relevant
        - Experience should match the seniority level of the role
        - Salary range should be appropriate for the role and experience level
        - Evaluation weightings should reflect the importance of each assessment component AND MUST SUM TO EXACTLY 100%
        
        CRITICAL: Double-check that cv + assessment + interview + references = 100 before returning the response.
        Make sure the response is valid JSON and all fields are filled appropriately for the job title.
        '''
        
        try:
            response = self._call_generation(prompt, temperature=0.7, max_output_tokens=2000)
            
            # Try to parse JSON response
            import re
            match = re.search(r"(\{.*\})", response, flags=re.DOTALL)
            json_text = match.group(1) if match else response
            parsed = json.loads(json_text)
            
            # Ensure all fields are present and validated
            return self._ensure_job_details_complete(parsed, job_title)
            
        except Exception as e:
            logger.exception(f"Failed to generate job details for {job_title}")
            return self._get_fallback_job_details(job_title)

    def _ensure_job_details_complete(self, job_details: Dict[str, Any], job_title: str) -> Dict[str, Any]:
        """Ensure all required fields are present and valid"""
        # Default structure
        defaults = {
            "description": f"We are seeking a talented {job_title} to join our dynamic team.",
            "responsibilities": [f"Perform core responsibilities related to {job_title}"],
            "qualifications": [f"Relevant experience in {job_title} or similar roles"],
            "company_details": "We are a forward-thinking organization committed to innovation and excellence.",
            "category": "Engineering",
            "required_skills": ["Communication", "Teamwork", "Problem Solving"],
            "min_experience": "2",
            "salary_min": "25000",
            "salary_max": "40000",
            "salary_currency": "ZAR",
            "salary_period": "monthly",
            "evaluation_weightings": {
                "cv": 60,
                "assessment": 30,
                "interview": 10,
                "references": 0
            }
        }
        
        # Merge with provided data
        for key, value in defaults.items():
            if key not in job_details or job_details[key] is None:
                job_details[key] = value
        
        # Validate weightings sum to 100
        if "evaluation_weightings" in job_details:
            weightings = job_details["evaluation_weightings"]
            if isinstance(weightings, dict):
                total = sum(weightings.values())
                if total != 100:
                    # Normalize to 100
                    factor = 100.0 / total
                    for k in weightings:
                        weightings[k] = round(weightings[k] * factor)
                    
                    # Adjust rounding errors
                    total = sum(weightings.values())
                    if total != 100:
                        diff = 100 - total
                        weightings["cv"] = weightings.get("cv", 0) + diff
        
        return job_details

    def _get_fallback_job_details(self, job_title: str) -> Dict[str, Any]:
        """Fallback job details when AI fails"""
        return {
            "description": f"We are seeking a talented {job_title} to join our dynamic team. This role offers an exciting opportunity to contribute to innovative projects and grow professionally in a collaborative environment.",
            "responsibilities": [
                f"Perform core responsibilities related to {job_title}",
                "Collaborate with cross-functional teams to achieve project goals",
                "Contribute to planning and execution of key initiatives"
            ],
            "qualifications": [
                f"Relevant experience in {job_title} or similar roles",
                "Strong problem-solving and analytical skills",
                "Excellent communication and teamwork abilities"
            ],
            "company_details": "We are a forward-thinking organization committed to innovation and excellence. Our team thrives on collaboration and continuous growth.",
            "category": "Engineering",
            "required_skills": ["Communication", "Teamwork", "Problem Solving", "Time Management"],
            "min_experience": "2",
            "salary_min": "25000",
            "salary_max": "40000",
            "salary_currency": "ZAR",
            "salary_period": "monthly",
            "evaluation_weightings": {
                "cv": 60,
                "assessment": 30,
                "interview": 10,
                "references": 0
            }
        }

    def analyze_cv_vs_job(
        self, cv_text: str, job_description: str, want_json: bool = True
    ) -> Dict[str, Any]:
        cv_text, job_description = truncate_for_cv_prompt(cv_text or "", job_description or "")
        prompt = f"""
You are a hiring assistant specializing in parsing resumes and comparing them to job requirements.
Analyze the candidate CV against the full JOB SPEC below. The job spec may include: Role, Description, Responsibilities, Qualifications, Required skills, Minimum experience, and Category. Consider all sections when scoring.

JOB SPEC (description, responsibilities, qualifications, required skills, minimum experience):
\"\"\"{job_description}\"\"\"

CANDIDATE CV:
\"\"\"{cv_text}\"\"\"

Task:
1) Compare the candidate against the job spec. Consider skills match, qualifications, experience level, and relevance of responsibilities.
2) Produce:
   - a numeric match_score (0-100).
   - a list "missing_skills" (skills/qualifications from the job spec that are not clearly present in the CV).
   - a list "suggestions" (concrete improvements for the candidate).
   - a list "interview_questions" (2-4 questions to explore fit).

Return the response strictly as JSON.
"""
        out = self._call_generation(prompt, temperature=0.0, max_output_tokens=700)

        # Try to parse JSON safely

        try:
            match = re.search(r"(\{.*\})", out, flags=re.DOTALL)
            json_text = match.group(1) if match else out
            parsed = json.loads(json_text)
        except Exception:
            logger.exception("Failed to parse JSON, returning raw text")
            parsed = {
                "match_score": 0,
                "missing_skills": [],
                "suggestions": [],
                "interview_questions": [],
                "raw_output": out,
            }

        # Normalize match_score
        try:
            ms = parsed.get("match_score", parsed.get("score", 0))
            parsed["match_score"] = max(0, min(100, int(round(float(ms)))))
        except Exception:
            parsed["match_score"] = 0

        for key in ("missing_skills", "suggestions", "interview_questions"):
            if key not in parsed or not isinstance(parsed[key], list):
                parsed[key] = []

        return parsed

    def generate_job_details(self, job_title: str) -> Dict[str, Any]:
        """Generate job description, responsibilities, qualifications, etc. from job title."""
        prompt = f'''
Based on the job title "{job_title}", generate comprehensive job details in JSON format with the following structure:
{{
  "description": "Detailed job description (2-3 paragraphs) that clearly explains the role, its purpose, and what the candidate will be doing day-to-day",
  "responsibilities": ["List of 5-7 specific, actionable key responsibilities as separate string items in the array"],
  "qualifications": ["List of 5-7 required qualifications including education, experience, and specific skills"],
  "company_details": "Professional company overview (2-3 sentences) that describes the company culture, mission, and what makes it an attractive workplace",
  "category": "One of: Engineering, Marketing, Sales, HR, Finance, Operations, Customer Service, Product, Design, Data Science, Management",
  "required_skills": ["List of 5-8 technical/professional skills that are essential for this role"],
  "min_experience": "Minimum years of experience as a number (0-15+)"
}}

IMPORTANT: Return only valid JSON. Responsibilities and qualifications must be arrays of strings. category must be one of the listed values. min_experience must be a number.
'''
        out = self._call_generation(prompt, temperature=0.7, max_output_tokens=1024)
        import re
        try:
            match = re.search(r"(\{.*\})", out, flags=re.DOTALL)
            json_text = match.group(1) if match else out
            parsed = json.loads(json_text)
        except Exception:
            logger.exception("Failed to parse job details JSON")
            raise RuntimeError("AI returned invalid JSON for job details")
        # Normalize to match Flutter expectations
        if "min_experience" in parsed and isinstance(parsed["min_experience"], (int, float)):
            parsed["min_experience"] = str(int(parsed["min_experience"]))
        for key in ("responsibilities", "qualifications", "required_skills"):
            if key not in parsed or not isinstance(parsed[key], list):
                parsed[key] = []
        return parsed

    def generate_assessment_questions(
        self, job_title: str, difficulty: str, question_count: int
    ) -> list:
        """Generate assessment questions for a job role."""
        prompt = f'''
Generate {question_count} assessment questions for a "{job_title}" position with {difficulty} difficulty level.

Return the response in JSON format with this structure:
{{
  "questions": [
    {{
      "question": "Clear, specific question text",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "answer": 2,
      "weight": 1
    }}
  ]
}}

Requirements:
- Questions should be relevant to the job role
- Difficulty level: {difficulty} (easy, medium, or hard)
- Each question must have exactly 4 options
- "answer" field should be the index (0-3) of the correct option
- Questions should test practical knowledge and skills
- Make questions specific to {job_title} responsibilities

Return only valid JSON.
'''
        out = self._call_generation(prompt, temperature=0.7, max_output_tokens=1024)
        import re
        try:
            match = re.search(r"(\{.*\})", out, flags=re.DOTALL)
            json_text = match.group(1) if match else out
            parsed = json.loads(json_text)
        except Exception:
            logger.exception("Failed to parse questions JSON")
            raise RuntimeError("AI returned invalid JSON for questions")
        questions = parsed.get("questions") or []
        if not isinstance(questions, list):
            questions = []
        return questions

    def structure_cv_experience(
        self, raw_experience_text: str, position_hint: str = "", companies_hint: Optional[list] = None
    ) -> list:
        """
        Use AI to turn raw CV experience text into a structured list of work_experience entries
        so they can be stored correctly in Candidate.work_experience.
        Returns list of dicts with keys: title, company, duration, description.
        """
        raw = (raw_experience_text or "").strip()
        if not raw and not position_hint:
            return []
        companies = companies_hint or []
        prompt = f"""Convert the following CV experience information into a structured JSON list.
Raw experience text:
\"\"\"{raw[:3000]}\"\"\"
Current job title (if known): {position_hint or "unknown"}
Companies mentioned: {companies[:10] if companies else "none"}

Return a JSON object with a single key "work_experience" whose value is an array of job entries.
Each entry must have: "title" (job title), "company" (employer name), "duration" (e.g. "2020 - Present" or "2 years"), "description" (optional, brief summary).
Extract each distinct role into its own object. If only one block of text is given, produce one or more entries from it.
Return only valid JSON, no markdown.
Example: {{ "work_experience": [ {{ "title": "Software Engineer", "company": "Acme Inc", "duration": "2021-Present", "description": "..." }} ] }}
"""
        try:
            out = self._call_generation(prompt, temperature=0.2, max_output_tokens=min(1024, AI_MAX_OUTPUT_TOKENS))
            match = re.search(r"(\{.*\})", out, flags=re.DOTALL)
            json_text = match.group(1) if match else out
            parsed = json.loads(json_text)
            work = parsed.get("work_experience")
            if isinstance(work, list):
                return work[:30]
            return []
        except Exception as e:
            logger.warning("AI structure_cv_experience failed: %s", e)
            return []
