#!/usr/bin/env python3
"""
Test AI APIs (OpenRouter / Gemini) used for job details and assessment questions.
Loads server/.env and calls AIService directly (no HTTP auth).

Usage (from server/):
  python scripts/test_ai_api.py
"""

import os
import sys
from pathlib import Path

# Ensure server root is on path and load .env
_server_root = Path(__file__).resolve().parent.parent
if str(_server_root) not in sys.path:
    sys.path.insert(0, str(_server_root))
_env = _server_root / ".env"
if _env.exists():
    try:
        from dotenv import load_dotenv
        load_dotenv(_env)
    except Exception:
        pass


def main():
    from app.services.ai_service import AIService

    ai = AIService()
    print("Testing AI APIs (job details + assessment questions)")
    print("OPENROUTER_API_KEY:", "set" if os.environ.get("OPENROUTER_API_KEY") else "not set")
    print("GEMINI_API_KEY:", "set" if os.environ.get("GEMINI_API_KEY") else "not set")
    print()

    # 1) Generate job details
    print("1) generate_job_details('Software Engineer')")
    try:
        out = ai.generate_job_details("Software Engineer")
        print("   OK. Keys:", list(out.keys()))
        print("   description (first 120 chars):", (out.get("description") or "")[:120], "...")
    except Exception as e:
        print("   FAILED:", e)

    # 2) Generate assessment questions
    print()
    print("2) generate_assessment_questions('Software Engineer', 'Medium', 3)")
    try:
        questions = ai.generate_assessment_questions("Software Engineer", "Medium", 3)
        print("   OK. Count:", len(questions))
        if questions:
            q = questions[0]
            print("   First question keys:", list(q.keys()))
    except Exception as e:
        print("   FAILED:", e)

    print()
    print("Done.")


if __name__ == "__main__":
    main()
