#!/usr/bin/env python3
"""
Dump all jobs (requisitions), test packs, and assessments from the database
for building a realistic assessment library and AI reference.
Output: assessment_library_export.json + assessment_library_report.md
"""
import os
import sys
import json
from datetime import datetime, date, timezone
from decimal import Decimal
from urllib.parse import urlparse

# Run from server directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SERVER_DIR = os.path.dirname(SCRIPT_DIR)
os.chdir(SERVER_DIR)
sys.path.insert(0, SERVER_DIR)

# Load .env manually so we don't need Flask
def load_dotenv(path=None):
    path = path or os.path.join(SERVER_DIR, ".env")
    if not os.path.isfile(path):
        return
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                os.environ[k.strip()] = v.strip().strip('"').strip("'")


load_dotenv()
DATABASE_URL = os.environ.get("DATABASE_URL")
if not DATABASE_URL:
    print("ERROR: DATABASE_URL not set in .env")
    sys.exit(1)

# Normalize URL (remove ?sslmode=require from path if present)
parsed = urlparse(DATABASE_URL)
conn_params = {
    "host": parsed.hostname,
    "port": parsed.port or 5432,
    "database": parsed.path.lstrip("/").split("?")[0],
    "user": parsed.username,
    "password": parsed.password,
}
if "sslmode=require" in (parsed.query or "") or (parsed.hostname and "render.com" in parsed.hostname):
    conn_params["sslmode"] = "require"

try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
except ImportError:
    print("ERROR: psycopg2 required. Run: pip install psycopg2-binary")
    sys.exit(1)


def json_serial(obj):
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError(f"Type {type(obj)} not serializable")


def run():
    conn = psycopg2.connect(**conn_params)
    conn.autocommit = True
    cur = conn.cursor(cursor_factory=RealDictCursor)

    out = {
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "database": conn_params["database"],
        "test_packs": [],
        "requisitions": [],
        "assessment_results_summary": [],
        "assessment_results_full": [],
        "stats": {},
    }

    # ---- TEST PACKS (all, including deleted for reference) ----
    cur.execute("""
        SELECT id, name, category, description, questions,
               created_at, updated_at, deleted_at
        FROM test_packs
        ORDER BY id
    """)
    rows = cur.fetchall()
    for r in rows:
        row = dict(r)
        if row.get("questions") and isinstance(row["questions"], str):
            try:
                row["questions"] = json.loads(row["questions"])
            except Exception:
                pass
        out["test_packs"].append(row)

    out["stats"]["test_packs_total"] = len(out["test_packs"])
    out["stats"]["test_packs_active"] = sum(1 for p in out["test_packs"] if not p.get("deleted_at"))

    # ---- REQUISITIONS (jobs) with assessment_pack and test_pack_id ----
    cur.execute("""
        SELECT id, title, description, company, location,
               category, employment_type, required_skills, min_experience,
               qualifications, responsibilities, weightings, knockout_rules,
               assessment_pack, test_pack_id, created_at, updated_at,
               is_active, deleted_at, salary_min, salary_max, salary_currency,
               salary_range, job_summary
        FROM requisitions
        ORDER BY id
    """)
    rows = cur.fetchall()
    for r in rows:
        row = dict(r)
        for key in ("required_skills", "qualifications", "responsibilities", "weightings", "knockout_rules", "assessment_pack"):
            val = row.get(key)
            if val is not None and isinstance(val, str):
                try:
                    row[key] = json.loads(val)
                except Exception:
                    pass
        out["requisitions"].append(row)

    out["stats"]["requisitions_total"] = len(out["requisitions"])
    out["stats"]["requisitions_active"] = sum(1 for r in out["requisitions"] if r.get("is_active") and not r.get("deleted_at"))
    out["stats"]["jobs_with_test_pack"] = sum(1 for r in out["requisitions"] if r.get("test_pack_id"))
    inline_qs = 0
    for r in out["requisitions"]:
        ap = r.get("assessment_pack") or {}
        qs = ap.get("questions") if isinstance(ap, dict) else []
        if qs:
            inline_qs += 1
    out["stats"]["jobs_with_inline_assessment"] = inline_qs

    # ---- ASSESSMENT RESULTS (with job and candidate context) ----
    cur.execute("""
        SELECT ar.id, ar.application_id, ar.candidate_id,
               ar.answers, ar.scores, ar.total_score, ar.percentage_score,
               ar.recommendation, ar.assessed_at, ar.created_at,
               a.requisition_id, a.status AS application_status,
               r.title AS job_title, r.test_pack_id,
               c.full_name AS candidate_name
        FROM assessment_results ar
        JOIN applications a ON a.id = ar.application_id
        JOIN requisitions r ON r.id = a.requisition_id
        JOIN candidates c ON c.id = ar.candidate_id
        ORDER BY ar.assessed_at DESC NULLS LAST, ar.id DESC
    """)
    rows = cur.fetchall()
    for r in rows:
        row = dict(r)
        for key in ("answers", "scores"):
            val = row.get(key)
            if val is not None and isinstance(val, str):
                try:
                    row[key] = json.loads(val)
                except Exception:
                    pass
        out["assessment_results_full"].append(row)
        out["assessment_results_summary"].append({
            "id": row["id"],
            "job_title": row["job_title"],
            "job_id": row["requisition_id"],
            "candidate_name": row["candidate_name"],
            "total_score": row["total_score"],
            "percentage_score": row["percentage_score"],
            "recommendation": row["recommendation"],
            "assessed_at": row["assessed_at"].isoformat() if row.get("assessed_at") else None,
        })

    out["stats"]["assessment_results_count"] = len(out["assessment_results_full"])

    cur.close()
    conn.close()

    # Write JSON export
    export_path = os.path.join(SERVER_DIR, "assessment_library_export.json")
    with open(export_path, "w", encoding="utf-8") as f:
        json.dump(out, f, default=json_serial, indent=2, ensure_ascii=False)
    print(f"Written: {export_path}")

    # Build markdown report
    report_path = os.path.join(SERVER_DIR, "assessment_library_report.md")
    lines = [
        "# Assessment Library & Jobs – Database Export Report",
        "",
        f"**Exported:** {out['exported_at']}",
        f"**Database:** {out['database']}",
        "",
        "## Summary statistics",
        "",
        f"- **Test packs (total):** {out['stats']['test_packs_total']}",
        f"- **Test packs (active, not deleted):** {out['stats']['test_packs_active']}",
        f"- **Requisitions / jobs (total):** {out['stats']['requisitions_total']}",
        f"- **Requisitions (active):** {out['stats']['requisitions_active']}",
        f"- **Jobs linked to a test pack:** {out['stats']['jobs_with_test_pack']}",
        f"- **Jobs with inline assessment_pack questions:** {out['stats']['jobs_with_inline_assessment']}",
        f"- **Assessment results (candidate submissions):** {out['stats']['assessment_results_count']}",
        "",
        "---",
        "",
        "## 1. Test packs",
        "",
    ]

    for p in out["test_packs"]:
        deleted = " *(deleted)*" if p.get("deleted_at") else ""
        lines.append(f"### Pack #{p['id']}: {p.get('name', 'N/A')}{deleted}")
        lines.append(f"- **Category:** {p.get('category', 'N/A')}")
        lines.append(f"- **Description:** {p.get('description') or 'N/A'}")
        lines.append(f"- **Question count:** {len(p.get('questions') or [])}")
        lines.append("")
        questions = p.get("questions") or []
        for i, q in enumerate(questions):
            if isinstance(q, dict):
                text = q.get("question_text") or q.get("question") or str(q)[:200]
                opts = q.get("options") or []
                correct = q.get("correct_option") if "correct_option" in q else q.get("answer")
                lines.append(f"  **Q{i+1}** {text[:120]}{'...' if len(str(text)) > 120 else ''}")
                lines.append(f"  - Options: {len(opts)} | Correct index: {correct}")
            else:
                lines.append(f"  Q{i+1}: (raw) {str(q)[:100]}")
        lines.append("")

    lines.extend([
        "---",
        "",
        "## 2. Jobs (requisitions)",
        "",
    ])

    for r in out["requisitions"]:
        deleted = " *(deleted)*" if r.get("deleted_at") else ""
        inactive = " *(inactive)*" if not r.get("is_active") else ""
        lines.append(f"### Job #{r['id']}: {r.get('title', 'N/A')}{deleted}{inactive}")
        lines.append(f"- **Company:** {r.get('company') or 'N/A'}")
        lines.append(f"- **Location:** {r.get('location') or 'N/A'}")
        lines.append(f"- **Category:** {r.get('category') or 'N/A'}")
        lines.append(f"- **Employment type:** {r.get('employment_type') or 'N/A'}")
        lines.append(f"- **Test pack ID:** {r.get('test_pack_id') or 'None (inline assessment)'}")
        ap = r.get("assessment_pack") or {}
        qs = ap.get("questions", []) if isinstance(ap, dict) else []
        lines.append(f"- **Inline assessment questions:** {len(qs)}")
        if r.get("required_skills"):
            lines.append(f"- **Required skills:** {r['required_skills']}")
        if qs:
            for i, q in enumerate(qs[:5]):
                if isinstance(q, dict):
                    text = q.get("question_text") or q.get("question") or str(q)[:100]
                    lines.append(f"  - Q{i+1}: {text[:80]}...")
            if len(qs) > 5:
                lines.append(f"  - ... and {len(qs) - 5} more")
        lines.append("")

    lines.extend([
        "---",
        "",
        "## 3. Assessment results (summary)",
        "",
    ])
    for s in out["assessment_results_summary"][:50]:
        lines.append(f"- **{s.get('candidate_name')}** -> {s.get('job_title')}: {s.get('percentage_score')}% (score {s.get('total_score')}) – {s.get('recommendation') or 'N/A'} ({s.get('assessed_at')})")
    if len(out["assessment_results_summary"]) > 50:
        lines.append(f"- *... and {len(out['assessment_results_summary']) - 50} more (see JSON export)*")
    lines.append("")

    with open(report_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"Written: {report_path}")

    return out


if __name__ == "__main__":
    run()
    print("Done.")
