#!/usr/bin/env python3
"""
Generate APP_VERSION string: Ver.YYYY.MM.XYZ.ENV
- YYYY.MM = year, month
- X = week-of-month letter A-F
- Y = day-of-week letter A-G (Mon-Sun)
- Z = number of commits on dev_main for the current calendar day (local time)
- ENV = APP_ENV (default DEV)

Run from repo root or from khono_recruite/; uses git from repo root.
"""
import os
import subprocess
import sys
from datetime import datetime


def get_repo_root() -> str:
    """Return repo root; run from script dir or cwd so git sees the repo."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # From scripts/ we are under khono_recruite/; repo root is parent of khono_recruite
    start = script_dir
    for _ in range(2):  # scripts -> khono_recruite -> repo root
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            cwd=start,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
        start = os.path.dirname(start)
        if not start or start == os.path.dirname(start):
            break
    return os.getcwd()


def get_commit_count_today(repo_root: str, today_iso: str) -> str:
    """
    Count commits on dev_main for the current calendar day.
    Prefer origin/dev_main so any branch that has pulled from dev_main gets
    the same version as dev_main. Uses --since and --until for local-day bounds.
    """
    since = f"{today_iso} 00:00:00"
    until = f"{today_iso} 23:59:59"
    for ref in ("origin/dev_main", "dev_main", "HEAD"):
        try:
            out = subprocess.run(
                [
                    "git",
                    "rev-list",
                    "--count",
                    ref,
                    f"--since={since}",
                    f"--until={until}",
                ],
                capture_output=True,
                text=True,
                cwd=repo_root,
                timeout=10,
            )
            if out.returncode == 0 and out.stdout.strip().isdigit():
                return out.stdout.strip()
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue
    return "0"


def main() -> None:
    now = datetime.now()
    year = now.strftime("%Y")
    month = now.strftime("%m")
    day_of_month = int(now.strftime("%d"))
    dow_num = now.isoweekday()  # 1=Mon .. 7=Sun
    today_iso = now.strftime("%Y-%m-%d")

    # Week of month: 1->A .. 6->F
    week_num = min(6, (day_of_month - 1) // 7 + 1)
    week_letter = chr(64 + week_num)
    # Day of week: 1=Mon -> A .. 7=Sun -> G
    day_letter = chr(64 + dow_num)

    repo_root = get_repo_root()
    commit_count = get_commit_count_today(repo_root, today_iso)
    env = os.environ.get("APP_ENV", "DEV")

    version = f"Ver.{year}.{month}.{week_letter}{day_letter}{commit_count}.{env}"
    print(version)


if __name__ == "__main__":
    main()
    sys.exit(0)
