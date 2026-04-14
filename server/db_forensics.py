import pathlib
import re
import sys

import psycopg2
from psycopg2.extras import RealDictCursor


def _read_env_var(path: pathlib.Path, key: str) -> str:
    content = path.read_text(encoding="utf-8")
    m = re.search(rf"^{re.escape(key)}=(.*)$", content, re.M)
    if not m:
        raise RuntimeError(f"{key} not found in {path}")
    return m.group(1).strip()


def main() -> int:
    env_path = pathlib.Path(__file__).resolve().parent / ".env"
    db_url = _read_env_var(env_path, "ANALYSER_DATABASE_URL")

    print("DB:", db_url.split("@")[1].split("/")[0] if "@" in db_url else "(no host)")

    conn = psycopg2.connect(db_url)
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)

        cur.execute(
            """
            select id::text,
                   record_id::text,
                   status,
                   (result is null) as result_is_null,
                   jsonb_typeof(result) as result_type,
                   created_at,
                   updated_at,
                   started_at,
                   finished_at,
                   warnings
            from cv_analyser.cv_analyses
            order by created_at desc
            limit 12
            """
        )
        rows = cur.fetchall()
        print("\nLatest cv_analyser.cv_analyses rows:", len(rows))
        for r in rows:
            print("\n---")
            print("id:", r["id"])
            print("record_id:", r["record_id"])
            print("status:", r["status"], "result_is_null:", r["result_is_null"], "result_type:", r["result_type"])
            print("created:", r["created_at"], "updated:", r["updated_at"], "started:", r["started_at"], "finished:", r["finished_at"])
            print("warnings:", r["warnings"])

        cur.execute(
            """
            select count(*) as cnt
            from cv_analyser.cv_analyses
            where status = 'completed' and result is null
            """
        )
        print("\ncompleted_missing_result_count:", cur.fetchone()["cnt"])

        cur.execute(
            """
            select action, count(*) as cnt
            from cv_analyser.cv_audit_logs
            group by action
            order by cnt desc
            """
        )
        print("\ncv_audit_logs action counts:")
        for r in cur.fetchall():
            print(r["action"], r["cnt"])

        cur.execute(
            """
            select action, count(*) as cnt
            from cv_analyser.cv_workflow_audit_logs
            group by action
            order by cnt desc
            """
        )
        print("\ncv_workflow_audit_logs action counts:")
        for r in cur.fetchall():
            print(r["action"], r["cnt"])

        cur.close()
        return 0
    finally:
        conn.close()


if __name__ == "__main__":
    raise SystemExit(main())
