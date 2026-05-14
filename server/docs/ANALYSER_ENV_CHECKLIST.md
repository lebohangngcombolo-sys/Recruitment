# Analyser integration environment checklist

Use this when wiring the Recruitment Flask backend to the Hugging Face FastAPI cv-analyser and when validating database access.

## HTTP integration (production path)

| Variable | Role |
|----------|------|
| `ANALYSIS_SERVICE_URL` | Base URL of the analyser with no trailing path segment, e.g. `https://dzunisani007-cv-analyser.hf.space`. Flask `AnalysisServiceClient` (`server/app/services/analysis_service_client.py`) appends `api/v1/analyze`, `api/v1/analyze/{id}/status`, `api/v1/analyze/{id}/result`. |
| `ANALYSIS_SERVICE_API_KEY` | Optional Bearer token if the Space requires auth. Must match what the Space validates. |

Wrong values cause 404 (double prefix in URL) or 401/403 on protected routes.

## Forensic / sync database access (optional)

| Variable | Role |
|----------|------|
| `ANALYSER_DATABASE_URL` | PostgreSQL URL for the **same** database the cv-analyser Space uses (`DATABASE_URL` on HF). Used by Flask `SQLALCHEMY_BINDS['analyser']` for scripts and debugging—not required for normal HTTP flow. |

If `ANALYSER_DATABASE_URL` points to a different host or database than the Space, local SQL checks will not match production analysis rows.

## Hugging Face Space (analyser service)

| Variable | Role |
|----------|------|
| `DATABASE_URL` | Primary Postgres for `cv_analyser` schema (analyses, records). |
| `HF_API_TOKEN` / `HF_TOKEN` | For external Inference API fallback in structured extraction. |
| `SIGNING_SECRET` | Shared secret for proxy Bearer auth from Recruitment if configured. |
| `HF_COMMIT_ID` / `GIT_COMMIT` / `COMMIT_SHA` / `SOURCE_COMMIT` | Injected commit SHA; exposed at `GET /api/v1/build` and `GET /health` under `build.git_sha` for deployment verification. |

## Verification

1. `GET https://<space>/api/v1/build` — confirm `git_sha` matches the commit you pushed.
2. `GET https://<space>/health` — includes `build.app_version` and `build.git_sha`.
3. From Recruitment, ensure `ANALYSIS_SERVICE_URL` matches the Space URL exactly (no duplicate `/api/v1` in the env value).
