import os
import time
from pathlib import Path

import requests
import jwt


def load_env(path: str = ".env") -> None:
    p = Path(path)
    if not p.exists():
        return
    for raw in p.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip())


def env(name: str, default: str | None = None) -> str | None:
    v = os.getenv(name)
    return v if v is not None and v != "" else default


def upload(session: requests.Session, base: str, headers: dict, file_path: Path, attempts: int = 3):
    for attempt in range(1, attempts + 1):
        try:
            with file_path.open("rb") as f:
                r = session.post(
                    f"{base}/upload",
                    headers=headers,
                    files={"file": (file_path.name, f, "application/pdf")},
                    timeout=(30, 300),
                )
            try:
                payload = r.json()
            except Exception:
                payload = {"detail": r.text}
            return r.status_code, payload
        except requests.exceptions.ReadTimeout:
            print(f"Upload timeout attempt {attempt}/{attempts}; retrying...")
            time.sleep(min(10 * attempt, 30))

    return None, {"detail": "upload timed out"}


def poll_status(session: requests.Session, base: str, headers: dict, analysis_id: str, timeout_s: int = 900):
    start = time.time()
    delay = 2
    while time.time() - start < timeout_s:
        r = session.get(
            f"{base}/analyses/{analysis_id}/status",
            headers=headers,
            timeout=(10, 60),
        )
        try:
            st = r.json()
        except Exception:
            st = {"detail": r.text}

        status = st.get("status") if isinstance(st, dict) else None
        if status in ("completed", "failed"):
            return status, st

        time.sleep(delay)
        delay = min(delay * 2, 30)

    return "timeout", {"detail": f"timed out after {timeout_s}s"}


def get_result(session: requests.Session, base: str, headers: dict, analysis_id: str):
    r = session.get(
        f"{base}/analyses/{analysis_id}/result",
        headers=headers,
        timeout=(10, 120),
    )
    try:
        payload = r.json()
    except Exception:
        payload = {"detail": r.text}
    return r.status_code, payload


def main():
    load_env(".env")

    base = (env("CV_ANALYSER_BASE_URL") or env("ANALYSIS_SERVICE_URL") or "https://cv-analyser-kt1u.onrender.com").rstrip("/")
    secret = env("CV_ANALYSER_SIGNING_SECRET") or env("SIGNING_SECRET")

    if not secret:
        raise SystemExit("Missing CV_ANALYSER_SIGNING_SECRET or SIGNING_SECRET")

    now = int(time.time())
    token = jwt.encode(
        {
            "sub": "local-smoke-test",
            "iat": now,
            "exp": now + 60 * 5,
        },
        secret,
        algorithm="HS256",
    )

    session = requests.Session()
    headers_jwt = {"Authorization": f"Bearer {token}"}
    headers_raw = {"Authorization": f"Bearer {secret}"}
    headers_none = {}

    headers_ok = None

    # Health
    h = session.get(f"{base}/health", headers=headers_jwt, timeout=60)
    try:
        h_payload = h.json()
    except Exception:
        h_payload = h.text
    print("Health:", h.status_code, h_payload)

    # Batch PDFs
    files_to_test = [
        "Bob Mabena CV.pdf",
        "Dzunisani-Mabundas-Resume-Cv-Qualifications.pdf",
        "KATEKO ROSE MABUNDA CV_KMR N6.pdf",
        "Lebohang_Junior_Analyst_Resume.pdf",
        "senior dev.pdf",
    ]

    # Smoke upload (diagnose auth expectation) using a real PDF if available.
    smoke_candidate = next((Path(n) for n in files_to_test if Path(n).exists()), None)
    if smoke_candidate is None:
        smoke_candidate = Path("__smoke_test__.pdf")
        smoke_candidate.write_bytes(b"%PDF-1.4\n%EOF\n")

    created_smoke = smoke_candidate.name == "__smoke_test__.pdf"
    try:
        for label, hdrs in (
            ("no_auth", headers_none),
            ("raw_secret", headers_raw),
            ("jwt", headers_jwt),
        ):
            code, payload = upload(session, base, hdrs, smoke_candidate)
            print(f"Smoke upload ({label}):", code, payload)

        for hdrs in (headers_raw, headers_jwt):
            code, payload = upload(session, base, hdrs, smoke_candidate)
            if code in (200, 202):
                headers_ok = hdrs
                break

        if headers_ok is None:
            raise SystemExit("Smoke upload failed; cannot continue batch")
    finally:
        if created_smoke:
            try:
                smoke_candidate.unlink()
            except Exception:
                pass

    for name in files_to_test:
        fp = Path(name)
        if not fp.exists():
            print(f"\n[SKIP] Missing file: {fp}")
            continue

        print(f"\n==== {fp.name} ====")
        code, up = upload(session, base, headers_ok, fp)
        print("Upload:", code, up)
        if code not in (200, 202) or not isinstance(up, dict):
            continue

        analysis_id = up.get("analysis_id")
        if not analysis_id:
            print("No analysis_id returned")
            continue

        st, status_payload = poll_status(session, base, headers_ok, str(analysis_id))
        print("Status:", st)
        if isinstance(status_payload, dict) and status_payload.get("match_score") is not None:
            print("match_score:", status_payload.get("match_score"))
        if st != "completed":
            print("status_payload:", status_payload)
            continue

        rcode, res = get_result(session, base, headers_ok, str(analysis_id))
        print("Result:", rcode)
        if rcode == 200 and isinstance(res, dict):
            print("overall_score:", res.get("overall_score"))
            print("component_scores:", res.get("component_scores"))
            ev = res.get("evidence") or {}
            missing = (ev.get("missing_skills") or []) if isinstance(ev, dict) else []
            print("missing_skills_count:", len(missing))
        else:
            print(res)


if __name__ == "__main__":
    main()
