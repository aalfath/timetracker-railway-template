"""Railway bootstrap for TimeTracker.

Runs upstream's /app/start.py unchanged (wait for DB, Alembic migrations under a Postgres
advisory lock, default rows, then exec gunicorn) and adds two first-boot steps after the
default admin user is created:

1. Upstream creates the ADMIN_USERNAMES users with no password, and the first person who logs
   in as one of them with any 8+ character password sets it. On a public URL that would hand
   the instance to whoever comes first. We set the password from ADMIN_PASSWORD (a generated
   template variable) for every admin that has none yet. Later password changes in the UI are
   kept: we never overwrite an existing password.
2. The first-run setup wizard (/setup) needs no login, so a stranger could complete it first
   and switch on self-registration. We mark setup complete on first boot; the deployer sets
   company details, timezone and currency in Admin > Settings after logging in.

Any failure exits non-zero so Railway restarts the service.
"""
import importlib.util
import os
import sys

spec = importlib.util.spec_from_file_location("tt_start", "/app/start.py")
start = importlib.util.module_from_spec(spec)
spec.loader.exec_module(start)

_orig_ensure_default_data = start.ensure_default_data


def _ensure_default_data(app):
    _orig_ensure_default_data(app)
    try:
        from app import db
        from app.models import User

        password = os.getenv("ADMIN_PASSWORD", "")
        names = [u.strip().lower() for u in os.getenv("ADMIN_USERNAMES", "admin").split(",") if u.strip()][:5]
        with app.app_context():
            for name in names:
                user = User.query.filter_by(username=name).first()
                if user is None:
                    start.log(f"[railway] admin user '{name}' missing after seeding", "ERROR")
                    sys.exit(1)
                if user.has_password:
                    continue
                if len(password) < 8:
                    start.log("[railway] ADMIN_PASSWORD must be set (8+ characters) so the admin "
                              "account is not left open to the first visitor", "ERROR")
                    sys.exit(1)
                user.set_password(password)
                db.session.add(user)
                start.log(f"[railway] password set for admin user '{name}' from ADMIN_PASSWORD", "INFO")
            db.session.commit()

        from app.utils.installation import get_installation_config

        inst = get_installation_config()
        if not inst.is_setup_complete():
            inst.mark_setup_complete(telemetry_enabled=False)
            start.log("[railway] first-run wizard marked complete (configure in Admin > Settings)", "INFO")
    except SystemExit:
        raise
    except Exception as e:  # pragma: no cover - fail closed
        start.log(f"[railway] admin bootstrap failed: {e}", "ERROR")
        sys.exit(1)
    return True


start.ensure_default_data = _ensure_default_data
start.main()
# start.main() ends in os.execv(gunicorn); reaching here means it failed.
sys.exit(1)
