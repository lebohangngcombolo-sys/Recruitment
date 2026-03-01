"""
Shared helpers for CV analysis: token-safe input truncation and score baseline.
Used by cv_parser_service, ai_service, cv_tasks, and ai_routes.
"""
import os

# ~4 chars per token; reserve space for system message and output (e.g. 2k tokens = 8k chars for input)
CV_ANALYSIS_MAX_INPUT_TOKENS = int(os.environ.get("CV_ANALYSIS_MAX_INPUT_TOKENS", "6000"))
CHARS_PER_TOKEN = 4
# Total input budget in chars (resume + job spec share this)
CV_ANALYSIS_MAX_INPUT_CHARS = (CV_ANALYSIS_MAX_INPUT_TOKENS * CHARS_PER_TOKEN)
# Resume gets 60%, job spec 40%
CV_RESUME_MAX_CHARS = int(CV_ANALYSIS_MAX_INPUT_CHARS * 0.6)
CV_JOB_SPEC_MAX_CHARS = int(CV_ANALYSIS_MAX_INPUT_CHARS * 0.4)

CV_SCORE_BASELINE = int(os.environ.get("CV_SCORE_BASELINE", "30"))


def truncate_for_cv_prompt(resume_text: str, job_spec: str):
    """
    Truncate resume and job spec so the combined prompt stays within token budget.
    Returns (resume_text, job_spec) with each truncated to its max chars.
    """
    resume = (resume_text or "").strip()
    job = (job_spec or "").strip()
    if len(resume) > CV_RESUME_MAX_CHARS:
        resume = resume[: CV_RESUME_MAX_CHARS] + "\n[... truncated for length]"
    if len(job) > CV_JOB_SPEC_MAX_CHARS:
        job = job[: CV_JOB_SPEC_MAX_CHARS] + "\n[... truncated for length]"
    return resume, job


def apply_cv_score_baseline(raw_score, baseline=None):
    """
    Apply baseline floor to CV match score. Final score = max(baseline, raw_score).
    raw_score: 0-100 from AI or offline analyser.
    baseline: optional override; defaults to CV_SCORE_BASELINE env (default 30).
    Returns int 0-100.
    """
    if baseline is None:
        baseline = CV_SCORE_BASELINE
    try:
        raw = int(round(float(raw_score)))
    except (TypeError, ValueError):
        raw = 0
    raw = max(0, min(100, raw))
    return max(baseline, raw)
