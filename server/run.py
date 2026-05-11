import os
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FutureTimeoutError

# Load .env from server directory so DATABASE_URL is set even when run from repo root
_env_path = Path(__file__).resolve().parent / ".env"
if _env_path.exists():
    from dotenv import load_dotenv
    load_dotenv(_env_path)

from app import create_app
from app.extensions import db, socketio

app = create_app()

def _is_true(name: str, default: str = "false") -> bool:
    return os.getenv(name, default).strip().lower() in {"1", "true", "yes", "on"}


def _print_db_help() -> None:
    print("\n*** Database connection failed ***")
    print("Check DATABASE_URL in server/.env")
    print("  - For local Postgres: postgresql://USER:PASSWORD@localhost:5432/DBNAME")
    print("  - Ensure Postgres is running and USER/PASSWORD are correct.")
    print("  - Or use your Render DB URL (with ?sslmode=require) for remote DB.\n")


def _try_initialize_db() -> None:
    """
    Attempt DB bootstrap without blocking server startup forever.
    - DB_AUTO_CREATE=false (default): skip create_all for faster/dev-safe boot.
    - DB_AUTO_CREATE=true: run create_all with timeout (DB_INIT_TIMEOUT_SECONDS).
    - STRICT_DB_STARTUP=true: fail hard instead of continuing.
    """
    strict = _is_true("STRICT_DB_STARTUP", "false")
    auto_create = _is_true("DB_AUTO_CREATE", "false")
    timeout_seconds = int(os.getenv("DB_INIT_TIMEOUT_SECONDS", "8"))

    if not auto_create:
        print("Skipping db.create_all() (DB_AUTO_CREATE=false).")
        return

    with app.app_context():
        try:
            with ThreadPoolExecutor(max_workers=1) as executor:
                future = executor.submit(db.create_all)
                future.result(timeout=timeout_seconds)
            print("Database initialized successfully.")
        except FutureTimeoutError:
            _print_db_help()
            print(
                f"db.create_all() timed out after {timeout_seconds}s. "
                "Continuing without DB initialization."
            )
            if strict:
                raise RuntimeError("DB initialization timeout and STRICT_DB_STARTUP=true")
        except Exception as e:
            if "OperationalError" in type(e).__name__ or "connection" in str(e).lower():
                _print_db_help()
            if strict:
                raise
            print("Continuing without DB initialized (STRICT_DB_STARTUP=false).")


_try_initialize_db()

if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=5000)
