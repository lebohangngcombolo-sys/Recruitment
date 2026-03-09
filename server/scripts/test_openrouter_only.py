#!/usr/bin/env python3
"""Quick test of OpenRouter API key only (no Gemini)."""
import os
import sys
from pathlib import Path

_server_root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_server_root))
_env = _server_root / ".env"
if _env.exists():
    from dotenv import load_dotenv
    load_dotenv(_env)

import requests

def main():
    key = os.environ.get("OPENROUTER_API_KEY", "").strip()
    if not key:
        print("OPENROUTER_API_KEY not set in .env")
        return 1
    url = "https://openrouter.ai/api/v1/chat/completions"
    model = os.environ.get("OPENROUTER_MODEL", "openai/gpt-4o-mini")
    resp = requests.post(
        url,
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"},
        json={
            "model": model,
            "messages": [{"role": "user", "content": "Reply with exactly: OK"}],
            "max_tokens": 10,
        },
        timeout=30,
    )
    if resp.status_code == 200:
        text = resp.json().get("choices", [{}])[0].get("message", {}).get("content", "")
        print("OpenRouter OK. Response:", text[:80])
        return 0
    print("OpenRouter FAILED:", resp.status_code, resp.text[:300])
    return 1

if __name__ == "__main__":
    sys.exit(main())
