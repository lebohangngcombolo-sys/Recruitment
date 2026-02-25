import os
import re
import requests
import json
import logging
import time
from typing import Dict, Any, Optional
from dotenv import load_dotenv


# ----------------------------
# Environment & Logging Setup
# ----------------------------
load_dotenv()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY")
OPENROUTER_URL = os.environ.get(
    "OPENROUTER_URL", "https://openrouter.ai/api/v1/chat/completions"
)
DEFAULT_MODEL = os.environ.get("OPENROUTER_MODEL", "openai/gpt-4o-mini")
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.0-flash")


class AIService:
    def __init__(
        self,
        api_key: Optional[str] = None,
        model: Optional[str] = None,
        timeout: int = 60,
        retries: int = 3,
        backoff: int = 5,
    ):
        self.api_key = api_key or OPENROUTER_API_KEY
        self.model = model or DEFAULT_MODEL
        self.timeout = timeout
        self.retries = retries
        self.backoff = backoff

        if not self.api_key:
            logger.warning(
                "No OPENROUTER_API_KEY found in environment. AI calls will fail without a key."
            )

    def _call_generation(
        self, prompt: str, temperature: float = 0.7, max_output_tokens: int = 512
    ) -> str:
        if not self.api_key:
            raise RuntimeError("OPENROUTER_API_KEY not set")

        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
        }

        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": "You are an expert recruitment assistant."},
                {"role": "user", "content": prompt},
            ],
            "temperature": temperature,
            "max_tokens": max_output_tokens,
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
                    "Timeout on attempt %d/%d, retrying in %d seconds...",
                    attempt,
                    self.retries,
                    self.backoff,
                )
                time.sleep(self.backoff)
            except requests.exceptions.RequestException as e:
                logger.error(
                    "RequestException on attempt %d/%d: %s", attempt, self.retries, e
                )
                time.sleep(self.backoff)
            except Exception as e:
                logger.exception(
                    "Unexpected error on attempt %d/%d: %s", attempt, self.retries, e
                )
                time.sleep(self.backoff)

        raise RuntimeError("Failed to call OpenRouter API after multiple retries")

    def _call_gemini(
        self, prompt: str, temperature: float = 0.7, max_output_tokens: int = 1024
    ) -> str:
        """Call Google Gemini API (Firebase/Google AI). Retries on 429 quota errors."""
        if not GEMINI_API_KEY or not GEMINI_API_KEY.strip():
            raise RuntimeError("GEMINI_API_KEY not set (cannot use Gemini fallback)")
        import google.generativeai as genai
        genai.configure(api_key=GEMINI_API_KEY)
        model = genai.GenerativeModel(GEMINI_MODEL)
        try:
            config = genai.GenerationConfig(
                temperature=temperature,
                max_output_tokens=max_output_tokens,
            )
        except (AttributeError, TypeError):
            config = None

        last_error = None
        for attempt in range(1, self.retries + 1):
            try:
                if config is not None:
                    response = model.generate_content(prompt, generation_config=config)
                else:
                    response = model.generate_content(prompt)
                if not response or not response.text:
                    raise RuntimeError("Empty response from Gemini")
                return response.text.strip()
            except Exception as e:
                last_error = e
                err_str = str(e)
                # 429 quota exceeded: wait and retry
                if "429" in err_str or "quota" in err_str.lower() or "retry" in err_str.lower():
                    delay = self.backoff + (attempt * 10)
                    if "retry in" in err_str.lower():
                        import re as _re
                        match = _re.search(r"retry in (\d+)\.?\d*s", err_str, _re.I)
                        if match:
                            delay = int(float(match.group(1))) + 5
                    logger.warning(
                        "Gemini quota/429 (attempt %d/%d), retrying in %ds...",
                        attempt, self.retries, delay,
                    )
                    time.sleep(min(delay, 60))
                else:
                    logger.warning("Gemini failed: %s", e)
                    raise RuntimeError(f"Gemini fallback failed: {e}") from e
        raise RuntimeError(f"Gemini fallback failed after retries: {last_error}") from last_error

    def _call_ai(
        self, prompt: str, temperature: float = 0.7, max_output_tokens: int = 512
    ) -> str:
        """Use Firebase/Gemini first when GEMINI_API_KEY is set; fall back to OpenRouter otherwise."""
        # Prefer Gemini (Firebase AI / Google AI) when configured
        if GEMINI_API_KEY and GEMINI_API_KEY.strip():
            try:
                return self._call_gemini(
                    prompt, temperature=temperature, max_output_tokens=max_output_tokens
                )
            except RuntimeError as e:
                logger.warning("Gemini (Firebase) failed (%s), trying OpenRouter", e)
                # Fall through to OpenRouter
        # Use OpenRouter when no Gemini or Gemini failed
        try:
            if self.api_key:
                return self._call_generation(
                    prompt, temperature=temperature, max_output_tokens=max_output_tokens
                )
        except RuntimeError as e:
            err_str = str(e).lower()
            if (
                "401" in err_str or "403" in err_str or "503" in err_str
                or "openrouter api error" in err_str
                or "not set" in err_str
                or "user not found" in err_str
                or "failed to call openrouter" in err_str
            ) and GEMINI_API_KEY and GEMINI_API_KEY.strip():
                logger.info("OpenRouter failed (%s), retrying Gemini fallback", e)
                return self._call_gemini(
                    prompt, temperature=temperature, max_output_tokens=max_output_tokens
                )
            raise
        if GEMINI_API_KEY and GEMINI_API_KEY.strip():
            logger.info("No OpenRouter key; using Gemini")
            return self._call_gemini(
                prompt, temperature=temperature, max_output_tokens=max_output_tokens
            )
        raise RuntimeError("No AI provider configured (set GEMINI_API_KEY or OPENROUTER_API_KEY)")

    def chat(self, message: str, temperature: float = 0.2) -> str:
        prompt = f"User:\n{message}\n\nAssistant:"
        return self._call_generation(prompt, temperature=temperature, max_output_tokens=400)

    def analyze_cv_vs_job(
        self, cv_text: str, job_description: str, want_json: bool = True
    ) -> Dict[str, Any]:
        prompt = f"""
You are a hiring assistant specializing in parsing resumes and comparing them to job descriptions.
Please analyze the candidate CV below and the job description below.

JOB DESCRIPTION:
\"\"\"{job_description}\"\"\"

CANDIDATE CV:
\"\"\"{cv_text}\"\"\"

Task:
1) Compare candidate qualifications with the job description. Produce:
 - a numeric match_score (0-100).
 - a list "missing_skills".
 - a list "suggestions".
 - a list "interview_questions".

Return the response strictly as JSON.
"""
        out = self._call_ai(prompt, temperature=0.0, max_output_tokens=700)

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
        out = self._call_ai(prompt, temperature=0.7, max_output_tokens=1024)
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
        out = self._call_ai(prompt, temperature=0.7, max_output_tokens=1024)
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
